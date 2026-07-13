import Foundation

enum TraceStoreHelpers {
    static func prepareForAppend(
        _ event: TraceRecord,
        supportedSchemaVersions: [Int],
        previousHash: String?,
        configuration: TraceConfiguration,
        nextIngestOrder: inout Int
    ) throws -> TraceRecord {
        guard supportedSchemaVersions.contains(event.schemaVersion) else {
            throw TraceStoreError.unsupportedSchemaVersion(event.schemaVersion)
        }

        let ingestOrder: Int
        if event.ingestOrder > 0 {
            ingestOrder = event.ingestOrder
        } else {
            ingestOrder = nextIngestOrder
            nextIngestOrder += 1
        }
        let staged = TraceRecord(
            schemaVersion: event.schemaVersion,
            id: event.id,
            at: event.at,
            ingestOrder: ingestOrder,
            run: event.run,
            step: event.step,
            skillName: event.skillName,
            skillVersionHash: event.skillVersionHash,
            tag: event.tag,
            subject: event.subject,
            subjectKey: event.subjectKey,
            payload: event.payload,
            payloadHash: event.payloadHash,
            outcome: event.outcome,
            witness: event.witness,
            previousHash: event.previousHash,
            recordHash: event.recordHash,
            operationalDetail: event.operationalDetail,
            legacyKind: event.legacyKind
        )
        return try HashChain.apply(
            to: staged,
            previousHash: previousHash,
            payloadLimit: configuration.payloadLimit,
            hashChaining: configuration.hashChaining
        )
    }

    static func filterAndSort<S: Sequence>(
        _ records: S,
        scope: TraceScope,
        scopeSkills: [String] = [],
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) -> [TraceRecord] where S.Element == TraceRecord {
        let filtered = records.filter { record in
            if !TraceStoreHelpers.matchesScope(
                record,
                scope: scope,
                scopeSkills: scopeSkills,
                runID: runID,
                skillName: skillName
            ) {
                return false
            }
            if let window, !window.contains(record.at) {
                return false
            }
            if let pattern, !pattern.matches(record) {
                return false
            }
            return true
        }

        switch scope {
        case .currentRun:
            return filtered.sorted(by: TraceRecordOrdering.runLocal)
        case .acrossAllRuns, .acrossSkills:
            return filtered.sorted(by: TraceRecordOrdering.crossRun)
        }
    }

    static func matchesScope(
        _ record: TraceRecord,
        scope: TraceScope,
        scopeSkills: [String],
        runID: String?,
        skillName: String?
    ) -> Bool {
        switch scope {
        case .currentRun:
            if let runID, record.run != runID { return false }
            if let skillName, record.skillName != skillName { return false }
            return true
        case .acrossAllRuns:
            if let skillName, record.skillName != skillName { return false }
            return true
        case .acrossSkills:
            let allowed = Set(scopeSkills.map { $0.lowercased() })
            return allowed.contains(record.skillName.lowercased())
        }
    }
}

enum TraceRecordOrdering {
    static func runLocal(_ lhs: TraceRecord, _ rhs: TraceRecord) -> Bool {
        if lhs.ingestOrder != rhs.ingestOrder {
            return lhs.ingestOrder < rhs.ingestOrder
        }
        if lhs.at != rhs.at {
            return lhs.at < rhs.at
        }
        return lhs.id < rhs.id
    }

    static func crossRun(_ lhs: TraceRecord, _ rhs: TraceRecord) -> Bool {
        if lhs.at != rhs.at {
            return lhs.at < rhs.at
        }
        if lhs.ingestOrder != rhs.ingestOrder {
            return lhs.ingestOrder < rhs.ingestOrder
        }
        return lhs.id < rhs.id
    }
}
