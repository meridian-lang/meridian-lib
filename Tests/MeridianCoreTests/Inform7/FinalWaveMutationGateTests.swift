import Foundation
import MeridianRuntime
import Testing
@testable import MeridianCore

/// Controlled mutations on test-only fixtures proving critical Final Wave gates
/// fail when regressed. Each test documents the gate under test.
@Suite("Final Wave mutation gate smoke")
struct FinalWaveMutationGateTests {
    private let cfg = """
    === vocabulary ===
    A customer is a kind of thing.
    A service is a kind of thing.
    """

    // MARK: - Verbalizer template gate

    @Test("mutation gate: malformed IR fails verbalizer validation (MER4002)")
    func verbalizerTemplateGateRejectsMalformedIR() {
        do {
            try IRValidator.validate(IRExpression.logical(.and, []), sourceFile: "mutated.ir")
            Issue.record("expected invalidIR gate to fail")
        } catch IRValidationError.diagnostics(let diagnostics) {
            #expect(diagnostics.contains { $0.code == .invalidIR })
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("mutation gate: suffix unless must not rewrite to if not")
    func verbalizerAuthoredFormGate() throws {
        let unlessSource = """
        ---
        vocabulary: test.merconfig
        ---
        To guard a page:
          complete with reason "ok" unless the page's status equals "blocked".
        """
        let (_, canonical, _) = try VerbalizerTestSupport.canonicalRoundTrip(unlessSource)
        let mutated = canonical.replacingOccurrences(of: "unless", with: "if not")
        #expect(mutated != canonical, Comment(rawValue: "mutation must differ from canonical"))
        #expect(canonical.contains("unless"))
        #expect(!canonical.contains("if not"))
    }

    // MARK: - Deontic guard / coherence gate

    @Test("mutation gate: invoke without prevented witness fails coherence harness")
    func deonticGuardCoherenceGate() async throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let compiler = Compiler(options: .init(trace: .silent()))
        let model = try compiler.compileToModel(
            meridianSource: mer,
            meridianFile: "mutated.meridian",
            vocabularies: [.init(name: "test", file: "test.merconfig", source: cfg)]
        )
        let document = try ObligationDocumentBuilder.build(from: model)
        let prohibition = try #require(document.obligations.first)

        let store = InMemoryTraceStore()
        try await store.append(TraceRecord(
            id: "mut-invoke",
            at: Date(timeIntervalSince1970: 10),
            ingestOrder: 10,
            run: "run-1",
            step: "timeNow",
            skillName: "test",
            skillVersionHash: "v1",
            tag: .invoked,
            subject: "timeNow",
            payload: ["tool_id": .string("timeNow")],
            payloadHash: "payload-mut-invoke"
        ))

        let report = try await CoherenceHarness.check(
            document: document,
            store: store,
            context: TraceEvaluationContext(
                runID: "run-1",
                skillName: "test",
                evaluationInstant: Date(timeIntervalSince1970: 100),
                sampleFloor: 0
            )
        )
        #expect(!report.isCoherent, Comment(rawValue: "mutated trace must trip coherence gate"))
    }

    // MARK: - Obligation id gate

    @Test("mutation gate: semantic norm edit changes obligation id")
    func obligationIdGate() throws {
        let baseline = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let mutated = baseline.replacingOccurrences(of: "time.now", with: "shell.run")
        #expect(mutated != baseline)

        let compiler = Compiler(options: .init(trace: .silent()))
        func id(for mer: String) throws -> String {
            let model = try compiler.compileToModel(
                meridianSource: mer,
                meridianFile: "mutated.meridian",
                vocabularies: [.init(name: "test", file: "test.merconfig", source: cfg)]
            )
            return try #require(ObligationDocumentBuilder.build(from: model).obligations.first?.id)
        }
        #expect(try id(for: baseline) != id(for: mutated))
    }

    // MARK: - Witness field gate

    @Test("mutation gate: redacted witness must not leak PII field")
    func witnessRedactionGate() throws {
        let full = try WitnessCapture.buildEnvelope(
            body: ["email": .string("leak@corp.com")],
            mode: .full,
            redactedFields: []
        )
        var mutatedBody = full.body ?? [:]
        mutatedBody["email"] = .string("leak@corp.com")
        let redacted = try WitnessCapture.buildEnvelope(
            body: mutatedBody,
            mode: .redacted,
            redactedFields: ["email"]
        )
        #expect(redacted.body?["email"] == .string("<redacted>"))
        #expect(redacted.witnessHash == full.witnessHash)
        #expect(redacted.body?["email"] != mutatedBody["email"])
    }

    // MARK: - Wilson gate

    @Test("mutation gate: Wilson lower bound gate fails on mutated success count")
    func wilsonConfidenceGate() {
        let baseline = WilsonScore.interval(successes: 18, sampleSize: 20, confidencePercent: 95)
        let mutated = WilsonScore.interval(successes: 10, sampleSize: 20, confidencePercent: 95)
        guard let baseline, let mutated else {
            Issue.record("expected Wilson intervals")
            return
        }
        #expect(baseline.lower > mutated.lower)
        #expect(mutated.lower < 0.9, Comment(rawValue: "mutated sample must fail 90% usually gate"))
    }

    // MARK: - Migration gate

    @Test("mutation gate: normative migrator output without inference cue hard-errors")
    func migrationNormativeHardErrorGate() async throws {
        let skillMD = """
        ## Phases

        1. Load calendar. Check today's meetings.
        2. Compile prep briefing.
        """
        let result = try await SkillMigrator(
            compiler: Compiler(options: .init(trace: .silent())),
            vocabularies: [],
            options: .init(routeFuzzy: false)
        ).migrate(skillMD)
        #expect(!result.compiledOK, Comment(rawValue: result.meriSource))
    }

    // MARK: - Redaction gate

    @Test("mutation gate: shell.run redaction strips command from invoke args")
    func runtimeRedactionGate() async throws {
        let observer = InMemoryObserver()
        let registry = ToolRegistry()
        await registry.register(tool: "shell.run", .closure { _ in .string("secret-output") })
        let runtime = Runtime(toolRegistry: registry, observer: observer, runID: "redact-mut")

        _ = try await runtime.invoke(
            tool: "shell.run",
            args: ["command": .string("secret-cmd"), "cwd": .string("/tmp")],
            capturePolicy: .redacted(["command"])
        )

        let starts = await observer.events.filter { $0.kind == .invokeStart }
        let ends = await observer.events.filter { $0.kind == .invokeEnd }
        #expect(starts.count == 1)
        #expect(ends.count == 1)
        if case .record(let args) = starts[0].payload["args"] {
            #expect(args["command"] == .string("<redacted>"))
            #expect(args["cwd"] == .string("/tmp"))
        } else {
            Issue.record("expected invoke args record")
        }
        #expect(ends[0].payload["output_summary"] == .string("<redacted>"))
    }
}
