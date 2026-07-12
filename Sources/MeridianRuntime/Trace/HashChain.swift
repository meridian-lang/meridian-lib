import Foundation

public enum TraceChainFailureReason: String, Sendable, Equatable {
    case missingRecordHash
    case previousHashMismatch
    case recordHashMismatch
}

public struct TraceChainVerificationFailure: Sendable, Equatable {
    public let recordID: String
    public let index: Int
    public let reason: TraceChainFailureReason

    public init(recordID: String, index: Int, reason: TraceChainFailureReason) {
        self.recordID = recordID
        self.index = index
        self.reason = reason
    }
}

public struct TraceChainVerificationResult: Sendable, Equatable {
    public let runID: String
    public let verifiedCount: Int
    public let isValid: Bool
    public let failure: TraceChainVerificationFailure?

    public init(runID: String, verifiedCount: Int, isValid: Bool, failure: TraceChainVerificationFailure?) {
        self.runID = runID
        self.verifiedCount = verifiedCount
        self.isValid = isValid
        self.failure = failure
    }
}

public enum HashChain {
    public static func apply(
        to record: TraceRecord,
        previousHash: String?,
        payloadLimit: Int?,
        hashChaining: Bool
    ) throws -> TraceRecord {
        let persistedPayload = try limitedPayload(record.payload, payloadLimit: payloadLimit)
        let chainedRecord = TraceRecord(
            schemaVersion: record.schemaVersion,
            id: record.id,
            at: record.at,
            ingestOrder: record.ingestOrder,
            run: record.run,
            step: record.step,
            skillName: record.skillName,
            skillVersionHash: record.skillVersionHash,
            tag: record.tag,
            subject: record.subject,
            subjectKey: record.subjectKey,
            payload: persistedPayload,
            payloadHash: record.payloadHash,
            outcome: record.outcome,
            witness: record.witness,
            previousHash: hashChaining ? previousHash : nil,
            recordHash: nil,
            operationalDetail: record.operationalDetail,
            legacyKind: record.legacyKind
        )
        let recordHash = try CanonicalJSON.sha256Hex(for: chainedRecord, excludingRecordHash: true)
        return TraceRecord(
            schemaVersion: chainedRecord.schemaVersion,
            id: chainedRecord.id,
            at: chainedRecord.at,
            ingestOrder: chainedRecord.ingestOrder,
            run: chainedRecord.run,
            step: chainedRecord.step,
            skillName: chainedRecord.skillName,
            skillVersionHash: chainedRecord.skillVersionHash,
            tag: chainedRecord.tag,
            subject: chainedRecord.subject,
            subjectKey: chainedRecord.subjectKey,
            payload: chainedRecord.payload,
            payloadHash: chainedRecord.payloadHash,
            outcome: chainedRecord.outcome,
            witness: chainedRecord.witness,
            previousHash: chainedRecord.previousHash,
            recordHash: recordHash,
            operationalDetail: chainedRecord.operationalDetail,
            legacyKind: chainedRecord.legacyKind
        )
    }

    public static func verify(records: [TraceRecord], runID: String) -> TraceChainVerificationResult {
        let ordered = records
            .filter { $0.run == runID }
            .sorted { lhs, rhs in
                if lhs.ingestOrder != rhs.ingestOrder {
                    return lhs.ingestOrder < rhs.ingestOrder
                }
                if lhs.at != rhs.at {
                    return lhs.at < rhs.at
                }
                return lhs.id < rhs.id
            }

        var previousHash: String?
        for (index, record) in ordered.enumerated() {
            guard let recordHash = record.recordHash else {
                return TraceChainVerificationResult(
                    runID: runID,
                    verifiedCount: index,
                    isValid: false,
                    failure: TraceChainVerificationFailure(recordID: record.id, index: index, reason: .missingRecordHash)
                )
            }
            if record.previousHash != previousHash {
                return TraceChainVerificationResult(
                    runID: runID,
                    verifiedCount: index,
                    isValid: false,
                    failure: TraceChainVerificationFailure(recordID: record.id, index: index, reason: .previousHashMismatch)
                )
            }
            let expectedHash = try? CanonicalJSON.sha256Hex(for: record, excludingRecordHash: true)
            if expectedHash != recordHash {
                return TraceChainVerificationResult(
                    runID: runID,
                    verifiedCount: index,
                    isValid: false,
                    failure: TraceChainVerificationFailure(recordID: record.id, index: index, reason: .recordHashMismatch)
                )
            }
            previousHash = recordHash
        }

        return TraceChainVerificationResult(runID: runID, verifiedCount: ordered.count, isValid: true, failure: nil)
    }

    private static func limitedPayload(_ payload: [String: Value]?, payloadLimit: Int?) throws -> [String: Value]? {
        guard let payload, let payloadLimit else {
            return payload
        }
        let size = try CanonicalJSON.data(for: payload).count
        return size > payloadLimit ? nil : payload
    }
}
