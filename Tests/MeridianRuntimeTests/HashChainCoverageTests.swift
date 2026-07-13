import Foundation
import Testing
@testable import MeridianRuntime

@Suite("HashChain coverage")
struct HashChainCoverageTests {

    private func baseRecord(
        id: String,
        ingestOrder: Int,
        payload: [String: Value]? = ["x": .string("1")],
        previousHash: String? = nil,
        recordHash: String? = nil
    ) throws -> TraceRecord {
        let payloadHash = try CanonicalJSON.sha256Hex(for: payload ?? [:])
        return TraceRecord(
            id: id,
            at: Date(timeIntervalSince1970: Double(ingestOrder)),
            ingestOrder: ingestOrder,
            run: "run-1",
            step: "step",
            skillName: "skill",
            skillVersionHash: "hash",
            tag: .emitted,
            subject: "subject",
            payload: payload,
            payloadHash: payloadHash,
            outcome: .success,
            previousHash: previousHash,
            recordHash: recordHash
        )
    }

    @Test("apply with hashChaining false clears previousHash and stamps recordHash")
    func applyWithoutChaining() throws {
        let raw = try baseRecord(id: "a", ingestOrder: 0, previousHash: "prev")
        let applied = try HashChain.apply(
            to: raw,
            previousHash: "prev",
            payloadLimit: nil,
            hashChaining: false
        )
        #expect(applied.previousHash == nil)
        #expect(applied.recordHash != nil)
    }

    @Test("apply with payloadLimit drops oversized payloads")
    func applyPayloadLimit() throws {
        let large = try baseRecord(
            id: "big",
            ingestOrder: 0,
            payload: ["blob": .string(String(repeating: "x", count: 200))]
        )
        let applied = try HashChain.apply(
            to: large,
            previousHash: nil,
            payloadLimit: 8,
            hashChaining: true
        )
        #expect(applied.payload == nil)
        #expect(applied.previousHash == nil)
        #expect(applied.recordHash != nil)
    }

    @Test("verify reports missingRecordHash / previousHashMismatch / recordHashMismatch")
    func verifyFailureReasons() throws {
        let missing = try baseRecord(id: "m", ingestOrder: 0, recordHash: nil)
        let missingResult = HashChain.verify(records: [missing], runID: "run-1")
        #expect(missingResult.isValid == false)
        #expect(missingResult.failure?.reason == .missingRecordHash)

        let first = try HashChain.apply(
            to: try baseRecord(id: "1", ingestOrder: 0),
            previousHash: nil,
            payloadLimit: nil,
            hashChaining: true
        )
        var brokenLink = try HashChain.apply(
            to: try baseRecord(id: "2", ingestOrder: 1),
            previousHash: first.recordHash,
            payloadLimit: nil,
            hashChaining: true
        )
        brokenLink = TraceRecord(
            schemaVersion: brokenLink.schemaVersion,
            id: brokenLink.id,
            at: brokenLink.at,
            ingestOrder: brokenLink.ingestOrder,
            run: brokenLink.run,
            step: brokenLink.step,
            skillName: brokenLink.skillName,
            skillVersionHash: brokenLink.skillVersionHash,
            tag: brokenLink.tag,
            subject: brokenLink.subject,
            subjectKey: brokenLink.subjectKey,
            payload: brokenLink.payload,
            payloadHash: brokenLink.payloadHash,
            outcome: brokenLink.outcome,
            witness: brokenLink.witness,
            previousHash: "wrong-prev",
            recordHash: brokenLink.recordHash,
            operationalDetail: brokenLink.operationalDetail,
            legacyKind: brokenLink.legacyKind
        )
        let prevResult = HashChain.verify(records: [first, brokenLink], runID: "run-1")
        #expect(prevResult.failure?.reason == .previousHashMismatch)

        let tampered = TraceRecord(
            schemaVersion: first.schemaVersion,
            id: first.id,
            at: first.at,
            ingestOrder: first.ingestOrder,
            run: first.run,
            step: first.step,
            skillName: first.skillName,
            skillVersionHash: first.skillVersionHash,
            tag: first.tag,
            subject: first.subject,
            subjectKey: first.subjectKey,
            payload: ["x": .string("tampered")],
            payloadHash: first.payloadHash,
            outcome: first.outcome,
            witness: first.witness,
            previousHash: first.previousHash,
            recordHash: first.recordHash,
            operationalDetail: first.operationalDetail,
            legacyKind: first.legacyKind
        )
        let hashResult = HashChain.verify(records: [tampered], runID: "run-1")
        #expect(hashResult.failure?.reason == .recordHashMismatch)

        let ok = HashChain.verify(records: [first], runID: "run-1")
        #expect(ok.isValid)
        #expect(ok.verifiedCount == 1)
    }
}
