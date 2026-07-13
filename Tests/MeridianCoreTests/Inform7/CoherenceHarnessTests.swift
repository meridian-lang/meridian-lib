import Foundation
import MeridianRuntime
import Testing
@testable import MeridianCore

@Suite("Coherence harness (Wave 9C / SEM-8-01)")
struct CoherenceHarnessTests {
    private let cfg = """
    === vocabulary ===
    A customer is a kind of thing.
    A service is a kind of thing.
    A service has a text called the status.
    """

    private func compileDocument(mer: String, file: String = "test.meridian") throws -> ObligationDocument {
        let compiler = Compiler(options: .init(trace: .silent()))
        let model = try compiler.compileToModel(
            meridianSource: mer,
            meridianFile: file,
            vocabularies: [.init(name: "test", file: "test.merconfig", source: cfg)]
        )
        return try ObligationDocumentBuilder.build(from: model)
    }

    private func context(runID: String = "run-1", skill: String = "test", at: TimeInterval = 100) -> TraceEvaluationContext {
        TraceEvaluationContext(
            runID: runID,
            skillName: skill,
            evaluationInstant: date(at),
            sampleFloor: 0
        )
    }

    @Test("SEM_8_01 prevented invoke coherence — no invoked, evaluator compliant")
    func sem801PreventedInvokeCoherence() async throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let document = try compileDocument(mer: mer)
        let prohibition = try #require(document.obligations.first { $0.kind == .unreachability })

        let store = InMemoryTraceStore()
        try await store.append(violationRecord(
            id: "V1",
            at: 10,
            obligationId: prohibition.id,
            disposition: "prevented",
            toolID: "timeNow",
            subject: "timeNow"
        ))

        let evaluation = try await ObligationEvaluator.evaluate(
            artifact: prohibition,
            document: document,
            store: store,
            context: context()
        )
        #expect(evaluation.compliance == .compliant)

        let report = try await CoherenceHarness.check(
            document: document,
            store: store,
            context: context()
        )
        #expect(report.isCoherent)
        #expect(report.disagreements.isEmpty)
    }

    @Test("SEM_8_01 observed obligation failure coherence")
    func sem801ObservedObligationFailureCoherence() async throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A service is healthy must hold.

        To inspect a service:
          commit.
          complete.
        """
        let document = try compileDocument(mer: mer)
        let obligation = try #require(document.obligations.first { $0.kind == .invariant })

        let store = InMemoryTraceStore()
        try await store.append(violationRecord(
            id: "V2",
            at: 20,
            obligationId: obligation.id,
            disposition: "observed",
            toolID: nil,
            subject: "inspect"
        ))

        let evaluation = try await ObligationEvaluator.evaluate(
            artifact: obligation,
            document: document,
            store: store,
            context: context()
        )
        #expect(evaluation.compliance == .violated)
        #expect(evaluation.disposition == "observed")

        let report = try await CoherenceHarness.check(
            document: document,
            store: store,
            context: context()
        )
        #expect(report.isCoherent)
    }

    @Test("SEM_8_01 prohibition invoke without runtime witness is incoherent")
    func sem801ProhibitionInvokeIncoherent() async throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let document = try compileDocument(mer: mer)
        let prohibition = try #require(document.obligations.first { $0.kind == .unreachability })

        let store = InMemoryTraceStore()
        try await store.append(invokeRecord(id: "I1", at: 5, toolID: "timeNow"))

        let evaluation = try await ObligationEvaluator.evaluate(
            artifact: prohibition,
            document: document,
            store: store,
            context: context()
        )
        #expect(evaluation.compliance == .violated)

        let report = try await CoherenceHarness.check(
            document: document,
            store: store,
            context: context()
        )
        #expect(!report.isCoherent)
        let disagreement = try #require(report.disagreements.first)
        #expect(disagreement.obligationId == prohibition.id)
        #expect(disagreement.message.contains(prohibition.id))
    }

    @Test("SEM_8_01 in-memory trace store round-trip")
    func sem801InMemoryStore() async throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let document = try compileDocument(mer: mer)
        let prohibition = try #require(document.obligations.first { $0.kind == .unreachability })

        let store = InMemoryTraceStore()
        try await store.append(violationRecord(
            id: "V3",
            at: 12,
            obligationId: prohibition.id,
            disposition: "prevented",
            toolID: "timeNow",
            subject: "timeNow"
        ))

        let report = try await CoherenceHarness.check(
            document: document,
            store: store,
            context: context()
        )
        #expect(report.isCoherent)
    }

    @Test("SEM_8_01 JSONL trace store coherence")
    func sem801JSONLStore() async throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let document = try compileDocument(mer: mer)
        let prohibition = try #require(document.obligations.first { $0.kind == .unreachability })

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sem801-\(UUID().uuidString).jsonl")
        let store = try JSONLTraceStore(fileURL: fileURL)
        try await store.append(violationRecord(
            id: "V4",
            at: 15,
            obligationId: prohibition.id,
            disposition: "prevented",
            toolID: "timeNow",
            subject: "timeNow"
        ))

        let report = try await CoherenceHarness.check(
            document: document,
            store: store,
            context: context()
        )
        #expect(report.isCoherent)
    }

    @Test("SEM_8_01 commit and recover witnesses do not falsify invariants alone")
    func sem801CommitRecoverSmoke() async throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A service is healthy must hold.

        To inspect a service:
          commit.
          complete.
        """
        let document = try compileDocument(mer: mer)
        let obligation = try #require(document.obligations.first { $0.kind == .invariant })

        let store = InMemoryTraceStore()
        try await store.append(TraceRecord(
            id: "C1",
            at: date(8),
            ingestOrder: 1,
            run: "run-1",
            step: "inspect",
            skillName: "test",
            skillVersionHash: "v1",
            tag: .committed,
            subject: "inspect",
            payload: nil,
            payloadHash: "commit-1"
        ))
        try await store.append(TraceRecord(
            id: "R1",
            at: date(9),
            ingestOrder: 2,
            run: "run-1",
            step: "inspect",
            skillName: "test",
            skillVersionHash: "v1",
            tag: .recovered,
            subject: "inspect",
            payload: nil,
            payloadHash: "recover-1"
        ))
        try await store.append(TraceRecord(
            id: "A1",
            at: date(10),
            ingestOrder: 3,
            run: "run-1",
            step: "inspect",
            skillName: "test",
            skillVersionHash: "v1",
            tag: .asserted,
            subject: "inspect",
            payload: [
                "message": .string(obligation.canonicalEnglish),
                "outcome": .string("true"),
            ],
            payloadHash: "assert-1"
        ))

        let evaluation = try await ObligationEvaluator.evaluate(
            artifact: obligation,
            document: document,
            store: store,
            context: context()
        )
        #expect(evaluation.compliance == .compliant)

        let report = try await CoherenceHarness.check(
            document: document,
            store: store,
            context: context()
        )
        #expect(report.isCoherent)
    }

    @Test("SEM_8_01 disagreement message names obligation id and event ids")
    func sem801DisagreementMessageShape() async throws {
        let artifact = ObligationArtifact(
            id: "OBL-deadbeefcafebabe",
            sourceSpan: .init(file: "t.meridian", line: 4, column: 1),
            scope: .init(kind: "skill", name: nil, stablePath: nil),
            kind: .unreachability,
            status: .active,
            blocking: false,
            canonicalEnglish: "A customer must not invoke time.now.",
            canonicalIRHash: "abc",
            conditionProofIR: nil,
            actionProofIR: "{\"tool_id\":\"timeNow\",\"argument_constraints\":[]}",
            discharge: .placeholder,
            traceEventTags: ["invoked", "violated", "prevented"]
        )
        let document = ObligationDocument(
            schemaVersion: OBLIGATION_ARTIFACT_SCHEMA_VERSION,
            semanticsVersion: OBLIGATION_SEMANTICS_VERSION,
            proofIRVersion: PROOF_IR_VERSION,
            identity: .init(skillName: "test", skillVersionHash: nil, sourceFile: "t.meridian", compilerIRVersion: MERIDIAN_IR_VERSION),
            obligations: [artifact]
        )

        let store = InMemoryTraceStore()
        try await store.append(invokeRecord(id: "I9", at: 3, toolID: "timeNow"))

        let report = try await CoherenceHarness.check(
            document: document,
            store: store,
            context: context()
        )
        #expect(!report.isCoherent)
        let disagreement = try #require(report.disagreements.first)
        #expect(disagreement.obligationId == "OBL-deadbeefcafebabe")
        #expect(disagreement.message.contains("OBL-deadbeefcafebabe"))
        #expect(disagreement.message.contains("violated"))
    }

    // MARK: - Fixtures

    private func violationRecord(
        id: String,
        at seconds: TimeInterval,
        obligationId: String,
        disposition: String,
        toolID: String?,
        subject: String
    ) -> TraceRecord {
        var payload: [String: Value] = [
            "obligation_id": .string(obligationId),
            "disposition": .string(disposition),
            "blocking": .boolean(false),
        ]
        if let toolID {
            payload["tool_id"] = .string(toolID)
        }
        return TraceRecord(
            id: id,
            at: date(seconds),
            ingestOrder: Int(seconds),
            run: "run-1",
            step: subject,
            skillName: "test",
            skillVersionHash: "v1",
            tag: .violated,
            subject: subject,
            payload: payload,
            payloadHash: "payload-\(id)",
            operationalDetail: disposition == "prevented" ? "prevented" : nil
        )
    }

    private func invokeRecord(id: String, at seconds: TimeInterval, toolID: String) -> TraceRecord {
        TraceRecord(
            id: id,
            at: date(seconds),
            ingestOrder: Int(seconds),
            run: "run-1",
            step: toolID,
            skillName: "test",
            skillVersionHash: "v1",
            tag: .invoked,
            subject: toolID,
            payload: ["tool_id": .string(toolID)],
            payloadHash: "payload-\(id)"
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }
}
