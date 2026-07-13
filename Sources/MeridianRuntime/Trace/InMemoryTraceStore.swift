import Foundation

public actor InMemoryTraceStore: TraceStore {
    private let configuration: TraceConfiguration
    private var records: [TraceRecord] = []
    private var nextIngestOrder: Int = 1
    private var tailHashByRun: [String: String] = [:]

    public init(configuration: TraceConfiguration = .default) {
        self.configuration = configuration
    }

    public var capabilities: TraceStoreCapabilities {
        TraceStoreCapabilities(
            isPersistent: false,
            supportsHashChaining: configuration.hashChaining,
            supportsCompaction: true,
            payloadRetention: true,
            indexedFields: ["run", "tag", "subject", "at"],
            supportedSchemaVersions: [TraceRecord.currentSchemaVersion, TraceRecord.currentSchemaVersion - 1]
        )
    }

    public func append(_ event: TraceRecord) async throws {
        let normalized = try TraceStoreHelpers.prepareForAppend(
            event,
            supportedSchemaVersions: capabilities.supportedSchemaVersions,
            previousHash: tailHashByRun[event.run],
            configuration: configuration,
            nextIngestOrder: &nextIngestOrder
        )
        records.append(normalized)
        nextIngestOrder = max(nextIngestOrder, normalized.ingestOrder + 1)
        if let recordHash = normalized.recordHash {
            tailHashByRun[normalized.run] = recordHash
        }
    }

    public func query(
        scope: TraceScope,
        scopeSkills: [String],
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord] {
        TraceStoreHelpers.filterAndSort(
            records,
            scope: scope,
            scopeSkills: scopeSkills,
            runID: runID,
            skillName: skillName,
            window: window,
            pattern: pattern
        )
    }

    public func compact(retention: Duration, now: Date) async throws {
        let cutoff = now.addingTimeInterval(-retention.timeInterval)
        records = records.filter { $0.at >= cutoff }
        rebuildTailHashes()
    }

    public func verifyChain(runID: String) async throws -> TraceChainVerificationResult {
        HashChain.verify(records: records, runID: runID)
    }

    private func rebuildTailHashes() {
        tailHashByRun = [:]
        nextIngestOrder = 1
        for record in records.sorted(by: TraceRecordOrdering.runLocal) {
            nextIngestOrder = max(nextIngestOrder, record.ingestOrder + 1)
            if let recordHash = record.recordHash {
                tailHashByRun[record.run] = recordHash
            }
        }
    }
}
