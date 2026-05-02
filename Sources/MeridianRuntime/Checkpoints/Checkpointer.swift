import Foundation

// MARK: - Checkpoint

public struct Checkpoint: Codable, Sendable {
    public let runID: String
    public let sequence: Int
    public let timestamp: Date
    public let label: String?
    public let stateSnapshot: StateSnapshot
    public let sourceRange: SourceRange?
}

// MARK: - Checkpointer protocol

public protocol Checkpointer: Sendable {
    func write(_ checkpoint: Checkpoint) async throws
    func readAll(forRun runID: String) async throws -> [Checkpoint]
    func latest(forRun runID: String) async throws -> Checkpoint?
    func clear(forRun runID: String) async throws
}

// MARK: - InMemoryCheckpointer

public actor InMemoryCheckpointer: Checkpointer {
    private var store: [String: [Checkpoint]] = [:]

    public init() {}

    public func write(_ checkpoint: Checkpoint) async throws {
        var list = store[checkpoint.runID] ?? []
        list.append(checkpoint)
        store[checkpoint.runID] = list
    }

    public func readAll(forRun runID: String) async throws -> [Checkpoint] {
        store[runID] ?? []
    }

    public func latest(forRun runID: String) async throws -> Checkpoint? {
        store[runID]?.last
    }

    public func clear(forRun runID: String) async throws {
        store[runID] = nil
    }
}

// MARK: - Convenience static factories

public extension InMemoryCheckpointer {
    nonisolated static var inMemory: InMemoryCheckpointer { InMemoryCheckpointer() }
}

// MARK: - FilesystemCheckpointer

/// Disk-backed `Checkpointer`. Each checkpoint is one JSON file under
/// `<root>/<runID>/<sequence>.json`; `latest` reads the highest-numbered
/// file. Writes are durable:
///
/// 1. Data is encoded to a temporary `.tmp` sibling.
/// 2. The temp file is `fsync`-ed so kernel buffers are flushed to storage.
/// 3. The temp file is atomically renamed to the final path (`rename(2)`).
/// 4. The parent directory is `fsync`-ed so the new directory entry is durable.
///
/// A per-run advisory lock file (`<root>/<runID>/.lock`) guards concurrent
/// writers from different processes. Processes using the same `Runtime` actor
/// are already serialised by the actor; the lock primarily protects
/// external tools (e.g. `meridian resume`) running alongside a live workflow.
///
/// `actor` isolation serialises all operations from a single process.
public actor FilesystemCheckpointer: Checkpointer {

    public let rootURL: URL

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootURL: URL) throws {
        self.rootURL = rootURL.standardizedFileURL
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        try FileManager.default.createDirectory(
            at: self.rootURL,
            withIntermediateDirectories: true
        )
    }

    /// Convenience: persist checkpoints under `~/Library/Caches/meridian-checkpoints/`.
    public init() throws {
        let caches = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try self.init(rootURL: caches.appendingPathComponent("meridian-checkpoints", isDirectory: true))
    }

    public func write(_ checkpoint: Checkpoint) async throws {
        let runDir = rootURL.appendingPathComponent(checkpoint.runID, isDirectory: true)
        try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

        let target = runDir.appendingPathComponent(filename(for: checkpoint.sequence))
        let temp   = runDir.appendingPathComponent(filename(for: checkpoint.sequence) + ".tmp")
        let data = try encoder.encode(checkpoint)

        try withAdvisoryLock(runDir: runDir) {
            try durableWrite(data: data, to: target, temp: temp, runDir: runDir)
        }
    }

    public func readAll(forRun runID: String) async throws -> [Checkpoint] {
        let runDir = rootURL.appendingPathComponent(runID, isDirectory: true)
        guard FileManager.default.fileExists(atPath: runDir.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(at: runDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { (lhs, rhs) in
                (sequence(of: lhs) ?? Int.max) < (sequence(of: rhs) ?? Int.max)
            }
        return try urls.compactMap { url -> Checkpoint? in
            let data = try Data(contentsOf: url)
            return try? decoder.decode(Checkpoint.self, from: data)
        }
    }

    public func latest(forRun runID: String) async throws -> Checkpoint? {
        try await readAll(forRun: runID).last
    }

    public func clear(forRun runID: String) async throws {
        let runDir = rootURL.appendingPathComponent(runID, isDirectory: true)
        if FileManager.default.fileExists(atPath: runDir.path) {
            try FileManager.default.removeItem(at: runDir)
        }
    }

    // MARK: - Durability helpers

    /// Write `data` durably to `target` via a `temp` sibling, fsyncing both
    /// the file and the parent directory so a crash after the call leaves either
    /// the old file untouched or the new file fully in place.
    private func durableWrite(data: Data, to target: URL, temp: URL, runDir: URL) throws {
        // 1. Write to temp, overwriting any leftover .tmp from a previous crash.
        try data.write(to: temp, options: [])

        // 2. fsync the temp file — ensures bytes reach storage before rename.
        try fsyncFile(at: temp)

        // 3. Atomic rename: on POSIX this is a single rename(2) syscall.
        _ = try FileManager.default.replaceItemAt(target, withItemAt: temp)

        // 4. fsync the directory so the new dirent is durable.
        try fsyncDirectory(at: runDir)
    }

    private func fsyncFile(at url: URL) throws {
        let fd = Darwin.open(url.path, O_RDONLY)
        guard fd >= 0 else { return }
        defer { Darwin.close(fd) }
        Darwin.fsync(fd)
    }

    private func fsyncDirectory(at url: URL) throws {
        let fd = Darwin.open(url.path, O_RDONLY)
        guard fd >= 0 else { return }
        defer { Darwin.close(fd) }
        Darwin.fsync(fd)
    }

    // MARK: - Advisory lock helpers

    /// Lock file path: `<runDir>/.lock`
    private func lockURL(for runDir: URL) -> URL {
        runDir.appendingPathComponent(".lock")
    }

    /// Acquire a POSIX advisory write lock on the run directory's `.lock` file,
    /// execute `body`, then release. Uses `lockf(3)` which is unambiguous with
    /// the Darwin `flock` struct. The lock is automatically released when the
    /// process exits, so there is no stale-lock risk from crashes.
    private func withAdvisoryLock(runDir: URL, body: () throws -> Void) throws {
        let lockPath = lockURL(for: runDir).path
        let fd = Darwin.open(lockPath, O_CREAT | O_WRONLY, mode_t(0o644))
        guard fd >= 0 else {
            // If we can't open the lock file, proceed without locking (best-effort).
            try body()
            return
        }
        defer { Darwin.close(fd) }
        // F_LOCK: acquire exclusive lock, blocking until available.
        lockf(fd, F_LOCK, 0)
        defer { lockf(fd, F_ULOCK, 0) }
        try body()
    }

    // MARK: - Filename helpers

    private func filename(for sequence: Int) -> String {
        // Zero-pad to 9 digits so naive lexicographic sort still matches
        // numeric sort for any run that fits in a billion checkpoints.
        String(format: "%09d.json", sequence)
    }

    private func sequence(of url: URL) -> Int? {
        Int(url.deletingPathExtension().lastPathComponent)
    }
}
