import Testing
import Foundation
@testable import MeridianRuntime

// MARK: - FilesystemCheckpointer durability tests

@Suite("FilesystemCheckpointer — durability")
struct CheckpointerDurabilityTests {

    private func makeTempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-dur-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeSnapshot(_ bindings: [String: Value] = [:]) -> StateSnapshot {
        StateSnapshot(bindings: bindings.mapValues(AnyCodable.init))
    }

    @Test("no leftover .tmp files after successful write")
    func noTempFilesAfterWrite() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cp = try FilesystemCheckpointer(rootURL: root)
        try await cp.write(Checkpoint(
            runID: "dur-A", sequence: 1, timestamp: Date(),
            label: "test", stateSnapshot: makeSnapshot(["k": .string("v")]),
            sourceRange: nil
        ))
        let runDir = root.appendingPathComponent("dur-A")
        let contents = try FileManager.default.contentsOfDirectory(
            at: runDir, includingPropertiesForKeys: nil)
        let tmpFiles = contents.filter { $0.lastPathComponent.hasSuffix(".tmp") }
        #expect(tmpFiles.isEmpty, Comment(rawValue: "Leftover .tmp files: \(tmpFiles)"))
    }

    @Test("lock file is created alongside checkpoints")
    func lockFileCreated() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cp = try FilesystemCheckpointer(rootURL: root)
        try await cp.write(Checkpoint(
            runID: "dur-B", sequence: 1, timestamp: Date(),
            label: nil, stateSnapshot: makeSnapshot(), sourceRange: nil
        ))
        let lockPath = root.appendingPathComponent("dur-B/.lock").path
        #expect(FileManager.default.fileExists(atPath: lockPath),
                Comment(rawValue: "Expected .lock file at \(lockPath)"))
    }

    @Test("concurrent writes from multiple actor instances produce consistent latest")
    func concurrentMultiInstanceWrites() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        // Two independent FilesystemCheckpointer actors writing to the same run.
        let cp1 = try FilesystemCheckpointer(rootURL: root)
        let cp2 = try FilesystemCheckpointer(rootURL: root)

        let snap = makeSnapshot(["concurrent": .boolean(true)])

        // Write interleaved sequences from both instances.
        try await withThrowingTaskGroup(of: Void.self) { group in
            for seq in stride(from: 1, through: 10, by: 2) {
                let s = seq
                group.addTask {
                    try await cp1.write(Checkpoint(
                        runID: "dur-C", sequence: s, timestamp: Date(),
                        label: "cp1-\(s)", stateSnapshot: snap, sourceRange: nil
                    ))
                }
                group.addTask {
                    try await cp2.write(Checkpoint(
                        runID: "dur-C", sequence: s + 1, timestamp: Date(),
                        label: "cp2-\(s+1)", stateSnapshot: snap, sourceRange: nil
                    ))
                }
            }
            try await group.waitForAll()
        }

        // All 10 checkpoints should be readable and valid.
        let all = try await cp1.readAll(forRun: "dur-C")
        #expect(all.count == 10, Comment(rawValue: "Expected 10 checkpoints, got \(all.count)"))

        // latest must be sequence 10.
        let latest = try await cp1.latest(forRun: "dur-C")
        #expect(latest?.sequence == 10)
    }

    @Test("clear removes lock file too")
    func clearRemovesLock() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cp = try FilesystemCheckpointer(rootURL: root)
        try await cp.write(Checkpoint(
            runID: "dur-D", sequence: 1, timestamp: Date(),
            label: nil, stateSnapshot: makeSnapshot(), sourceRange: nil
        ))
        try await cp.clear(forRun: "dur-D")
        let runDir = root.appendingPathComponent("dur-D")
        #expect(!FileManager.default.fileExists(atPath: runDir.path))
    }

    @Test("write is idempotent for the same sequence (overwrite produces valid checkpoint)")
    func idempotentWrite() async throws {
        let root = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cp = try FilesystemCheckpointer(rootURL: root)

        // Write sequence 1 twice with different labels.
        try await cp.write(Checkpoint(
            runID: "dur-E", sequence: 1, timestamp: Date(),
            label: "first", stateSnapshot: makeSnapshot(["v": .number(1)]), sourceRange: nil
        ))
        try await cp.write(Checkpoint(
            runID: "dur-E", sequence: 1, timestamp: Date(),
            label: "second", stateSnapshot: makeSnapshot(["v": .number(2)]), sourceRange: nil
        ))
        let latest = try await cp.latest(forRun: "dur-E")
        #expect(latest?.label == "second")
        #expect(latest?.stateSnapshot.asValues["v"] == .number(2))
    }
}
