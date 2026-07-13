import Foundation
import SQLite3

public actor SQLiteTraceStore: TraceStore {
    private let database: SQLiteTraceDatabase
    private let configuration: TraceConfiguration
    private var records: [TraceRecord] = []
    private var runIndex: [String: [Int]] = [:]
    private var tagIndex: [TraceTag: [Int]] = [:]
    private var subjectIndex: [String: [Int]] = [:]
    private var timeIndex: [Int] = []
    private var nextIngestOrder: Int = 1
    private var tailHashByRun: [String: String] = [:]
    private var hasLoaded = false

    public let fileURL: URL

    public init(fileURL: URL, configuration: TraceConfiguration = .default) throws {
        self.fileURL = fileURL.standardizedFileURL
        self.configuration = configuration
        try FileManager.default.createDirectory(
            at: self.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        self.database = try SQLiteTraceDatabase(fileURL: self.fileURL)
    }

    public var capabilities: TraceStoreCapabilities {
        TraceStoreCapabilities(
            isPersistent: true,
            supportsHashChaining: configuration.hashChaining,
            supportsCompaction: true,
            payloadRetention: true,
            indexedFields: ["run", "tag", "subject", "at"],
            supportedSchemaVersions: [TraceRecord.currentSchemaVersion, TraceRecord.currentSchemaVersion - 1]
        )
    }

    public func append(_ event: TraceRecord) async throws {
        try await ensureLoaded()
        let normalized = try TraceStoreHelpers.prepareForAppend(
            event,
            supportedSchemaVersions: capabilities.supportedSchemaVersions,
            previousHash: tailHashByRun[event.run],
            configuration: configuration,
            nextIngestOrder: &nextIngestOrder
        )
        let checksum = try CanonicalJSON.sha256Hex(for: normalized)
        try database.append(record: normalized, checksum: checksum)
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
        try database.deleteRecords(before: cutoff)
        let retained = records.filter { $0.at >= cutoff }
        replaceInMemory(with: retained)
    }

    public func verifyChain(runID: String) async throws -> TraceChainVerificationResult {
        try await ensureLoaded()
        return HashChain.verify(records: records, runID: runID)
    }

    private func ensureLoaded() async throws {
        guard !hasLoaded else { return }
        let loaded = try database.loadAllRecords()
        replaceInMemory(with: loaded)
        hasLoaded = true
    }

    private func replaceInMemory(with newRecords: [TraceRecord]) {
        records = newRecords
        runIndex = [:]
        tagIndex = [:]
        subjectIndex = [:]
        tailHashByRun = [:]
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

        for record in records.sorted(by: TraceRecordOrdering.runLocal) {
            if let recordHash = record.recordHash {
                tailHashByRun[record.run] = recordHash
            }
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
        if let recordHash = record.recordHash {
            tailHashByRun[record.run] = recordHash
        }
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
}
