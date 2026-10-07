import Foundation

public actor JSONLTraceStore: TraceStore, ArtifactWarningSource {
    private struct LineEnvelope: Codable {
        let record: TraceRecord
        let checksum: String
    }

    public let fileURL: URL
    private let configuration: TraceConfiguration
    private var records: [TraceRecord] = []
    private var runIndex: [String: [Int]] = [:]
    private var tagIndex: [TraceTag: [Int]] = [:]
    private var subjectIndex: [String: [Int]] = [:]
    private var timeIndex: [Int] = []
    private var nextIngestOrder: Int = 1
    private var hasLoaded = false
    private var pendingReadWarnings: [RuntimeArtifactWarning] = []
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL, configuration: TraceConfiguration = .default) throws {
        self.fileURL = fileURL.standardizedFileURL
        self.configuration = configuration
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        try FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: self.fileURL.path) {
            FileManager.default.createFile(atPath: self.fileURL.path, contents: nil)
        }
    }

    public var capabilities: TraceStoreCapabilities {
        TraceStoreCapabilities(
            isPersistent: true,
            supportsCompaction: true,
            payloadRetention: true
        )
    }

    public func append(_ event: TraceRecord) async throws {
        try await ensureLoaded()
        let normalized = try TraceStoreHelpers.prepareForAppend(
            event,
            configuration: configuration,
            nextIngestOrder: &nextIngestOrder
        )
        let envelope = try makeEnvelope(for: normalized)
        var lineData = try encoder.encode(envelope)
        lineData.append(Data("\n".utf8))

        try withAdvisoryLock {
            try appendDurably(data: lineData)
        }

        storeInMemory(normalized)
    }

    public func query(
        scope: TraceScope,
        scopeSkills: [String],
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord] {
        try await ensureLoaded()

        let candidateIndices: [Int]
        if scope == .currentRun, let runID, let indexed = runIndex[runID] {
            candidateIndices = indexed
        } else if let pattern, let tags = pattern.tags, tags.count == 1, let tag = tags.first {
            candidateIndices = tagIndex[tag] ?? []
        } else if let pattern, let subject = pattern.subject, let indexed = subjectIndex[subject] {
            candidateIndices = indexed
        } else {
            candidateIndices = (scope == .acrossAllRuns || scope == .acrossSkills) ? timeIndex : Array(records.indices)
        }

        return TraceStoreHelpers.filterAndSort(
            candidateIndices.lazy.map { self.records[$0] },
            scope: scope,
            scopeSkills: scopeSkills,
            runID: runID,
            skillName: skillName,
            window: window,
            pattern: pattern
        )
    }

    public func compact(retention: Duration, now: Date) async throws {
        try await ensureLoaded()
        let cutoff = now.addingTimeInterval(-retention.timeInterval)
        let retained = records.filter { $0.at >= cutoff }
        try withAdvisoryLock {
            try rewriteFile(with: retained)
        }
        replaceInMemory(with: retained)
    }

    public func consumeArtifactWarnings() async -> [RuntimeArtifactWarning] {
        let warnings = pendingReadWarnings
        pendingReadWarnings = []
        return warnings
    }

    private func ensureLoaded() async throws {
        guard !hasLoaded else {
            return
        }
        try withAdvisoryLock {
            try loadFromDisk()
        }
        hasLoaded = true
    }

    private func loadFromDisk() throws {
        records = []
        runIndex = [:]
        tagIndex = [:]
        subjectIndex = [:]
        timeIndex = []
        nextIngestOrder = 1

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            return
        }

        let text = String(decoding: data, as: UTF8.self)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" {
            lines.removeLast()
        }

        var parsedRecords: [TraceRecord] = []
        var validLineCount = lines.count
        for (index, line) in lines.enumerated() {
            do {
                let envelope = try decoder.decode(LineEnvelope.self, from: Data(line.utf8))
                let expected = try checksum(for: envelope.record)
                guard expected == envelope.checksum else {
                    throw TraceStoreError.invalidLineChecksum
                }
                parsedRecords.append(envelope.record)
            } catch {
                guard index == lines.indices.last else {
                    throw TraceStoreError.corruptedLine(line)
                }
                validLineCount = index
                try quarantineTornFinalLine(line)
                recordReadWarning(
                    code: "trace-store.read",
                    message: "quarantined torn final JSONL line in \(fileURL.lastPathComponent)",
                    runID: parsedRecords.last?.run ?? "unknown"
                )
                break
            }
        }

        if validLineCount != lines.count {
            try rewriteFile(with: parsedRecords)
        }
        replaceInMemory(with: parsedRecords)
    }

    private func quarantineTornFinalLine(_ line: String) throws {
        let stamp = ISO8601DateFormatter.meridianFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let quarantineURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(fileURL.lastPathComponent + ".quarantine-\(stamp)")
        try Data(line.utf8).write(to: quarantineURL, options: .atomic)
    }

    private func recordReadWarning(code: String, message: String, runID: String) {
        let warning = RuntimeArtifactWarning(
            code: code,
            message: message,
            runID: runID,
            artifactPath: fileURL.path
        )
        pendingReadWarnings.append(warning)
        let redacted = RuntimeSecretRedaction.redact(warning.message)
        fputs("meridian-runtime[\(warning.code)] run=\(runID): \(redacted)\n", stderr)
    }

    private func replaceInMemory(with newRecords: [TraceRecord]) {
        records = newRecords
        runIndex = [:]
        tagIndex = [:]
        subjectIndex = [:]
        nextIngestOrder = 1
        timeIndex = Array(records.indices)

        for (index, record) in records.enumerated() {
            runIndex[record.run, default: []].append(index)
            tagIndex[record.tag, default: []].append(index)
            if let subject = record.subject {
                subjectIndex[subject, default: []].append(index)
            }
            nextIngestOrder = max(nextIngestOrder, record.ingestOrder + 1)
        }

        timeIndex.sort { lhs, rhs in
            TraceRecordOrdering.crossRun(records[lhs], records[rhs])
        }
    }

    private func storeInMemory(_ record: TraceRecord) {
        let index = records.count
        records.append(record)
        runIndex[record.run, default: []].append(index)
        tagIndex[record.tag, default: []].append(index)
        if let subject = record.subject {
            subjectIndex[subject, default: []].append(index)
        }
        insertIntoTimeIndex(index)
        nextIngestOrder = max(nextIngestOrder, record.ingestOrder + 1)
    }

    private func insertIntoTimeIndex(_ index: Int) {
        var low = 0
        var high = timeIndex.count
        while low < high {
            let mid = (low + high) / 2
            if TraceRecordOrdering.crossRun(records[timeIndex[mid]], records[index]) {
                low = mid + 1
            } else {
                high = mid
            }
        }
        timeIndex.insert(index, at: low)
    }

    private func makeEnvelope(for record: TraceRecord) throws -> LineEnvelope {
        LineEnvelope(record: record, checksum: try checksum(for: record))
    }

    private func checksum(for record: TraceRecord) throws -> String {
        try CanonicalJSON.sha256Hex(for: record)
    }

    private func rewriteFile(with records: [TraceRecord]) throws {
        let tempURL = fileURL.appendingPathExtension("tmp")
        var data = Data()
        for record in records {
            let envelope = try makeEnvelope(for: record)
            data.append(try encoder.encode(envelope))
            data.append(Data("\n".utf8))
        }
        try data.write(to: tempURL, options: [])
        try fsyncFile(at: tempURL)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        try fsyncDirectory(at: fileURL.deletingLastPathComponent())
    }

    private func appendDurably(data: Data) throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } else {
            try data.write(to: fileURL, options: [.atomic])
        }
        try fsyncFile(at: fileURL)
        try fsyncDirectory(at: fileURL.deletingLastPathComponent())
    }

    private func lockURL() -> URL {
        fileURL.appendingPathExtension("lock")
    }

    private func withAdvisoryLock(body: () throws -> Void) throws {
        let lockPath = lockURL().path
        let fd = Darwin.open(lockPath, O_CREAT | O_WRONLY, mode_t(0o644))
        guard fd >= 0 else {
            try body()
            return
        }
        defer { Darwin.close(fd) }
        lockf(fd, F_LOCK, 0)
        defer { lockf(fd, F_ULOCK, 0) }
        try body()
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
}
