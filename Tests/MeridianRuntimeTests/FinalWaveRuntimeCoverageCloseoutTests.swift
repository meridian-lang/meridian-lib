import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Final Wave runtime coverage closeout")
struct FinalWaveRuntimeCoverageCloseoutTests {

    @Test("WilsonScore interval and z lookup arms")
    func wilsonScore() {
        #expect(WilsonScore.zScore(forConfidencePercent: 90) == 1.645)
        #expect(WilsonScore.zScore(forConfidencePercent: 95) == 1.96)
        #expect(WilsonScore.zScore(forConfidencePercent: 99) == 2.576)
        let custom = WilsonScore.zScore(forConfidencePercent: 92.5)
        #expect(custom > 1.6 && custom < 2.0)

        let interval = WilsonScore.interval(successes: 8, sampleSize: 10, confidencePercent: 95)
        #expect(interval != nil)
        #expect(interval!.lower < interval!.upper)
        #expect(WilsonScore.interval(successes: -1, sampleSize: 10, confidencePercent: 95) == nil)
    }

    @Test("BoundedFutureCondition decodes event and state shapes")
    func boundedFutureCondition() {
        let event = BoundedFutureCondition.decode("""
        {"kind":"event","subject":{"type":"step","name":"deploy"},"outcome":"failed"}
        """)
        #expect(event != nil)
        let state = BoundedFutureCondition.decode("""
        {"kind":"state","fields":{"status":"ready"}}
        """)
        if case .state(let fields) = state {
            #expect(fields["status"] == .string("ready"))
        } else {
            Issue.record("expected state decode")
        }
    }

    @Test("TraceStoreHelpers filter, sort, and prepare append")
    func traceStoreHelpers() throws {
        let base = Date(timeIntervalSince1970: 1_000)
        let record = TraceRecord(
            id: "r1",
            at: base,
            ingestOrder: 0,
            run: "run-a",
            step: "deploy",
            skillName: "Skill",
            skillVersionHash: "v1",
            tag: .completed,
            subject: "deploy",
            payload: ["k": .string("v")],
            payloadHash: "h",
            outcome: .success
        )
        var next = 1
        let prepared = try TraceStoreHelpers.prepareForAppend(
            record,
            configuration: .default,
            nextIngestOrder: &next
        )
        #expect(prepared.ingestOrder == 1)

        let sorted = TraceStoreHelpers.filterAndSort(
            [record],
            scope: .currentRun,
            runID: "run-a",
            skillName: "Skill",
            window: nil,
            pattern: nil
        )
        #expect(sorted.count == 1)
    }

    @Test("MeridianRuntimeError description paths")
    func meridianRuntimeErrorDescriptions() {
        let range = SourceRange(file: "t.meridian", line: 1, column: 1)
        let cases: [MeridianRuntimeError] = [
            .toolError(.timeout(.seconds(1)), sourceRange: range),
            .assertion(message: "bad", sourceRange: range),
            .assertionFailed(message: "failed"),
            .timeout(condition: .duration(.seconds(1)), sourceRange: range),
            .stateError(.missing(key: "x"), sourceRange: range),
            .recoveryExhausted(originalError: NSError(domain: "t", code: 1), handlerError: NSError(domain: "t", code: 2)),
            .checkpointFailed("disk", sourceRange: range),
            .instanceNotFound(name: "x"),
            .toolNotFound(id: "missing"),
            .nestingLimitExceeded(maxDepth: 3),
            .cancelled,
            .traceStoreFailure("io"),
            .observerFailure("write"),
            .violation(message: "blocked", sourceRange: range),
            .approvalDenied(role: "manager", sourceRange: range),
        ]
        for err in cases {
            #expect(!String(describing: err).isEmpty)
        }
    }

    @Test("ShellHoleRedaction masks sensitive shell fragments")
    func shellHoleRedaction() {
        let redacted = ShellHoleRedaction.redactInvokeArgs(
            toolID: "shell.run",
            args: ["command": .string("curl secret")],
            capturePolicy: nil
        )
        #expect(redacted["command"] == .string("<redacted>"))
    }

    @Test("shell.run invoke uses default shell-hole redaction without capture policy")
    func shellInvokeDefaultRedaction() async throws {
        let observer = InMemoryObserver()
        let registry = ToolRegistry()
        await registry.register(tool: "shell.run", .closure { _ in .string("ok") })
        let runtime = Runtime(toolRegistry: registry, observer: observer, runID: "shell-default-redact")
        _ = try await runtime.invoke(
            tool: "shell.run",
            args: ["command": .string("echo secret")]
        )
        let start = await observer.events.first { $0.kind == .invokeStart }
        if case .record(let args) = start?.payload["args"] {
            #expect(args["command"] == .string("<redacted>"))
        } else {
            Issue.record("expected invoke args record")
        }
    }

    @Test("ValueCoercion date bridge")
    func valueCoercionResidual() throws {
        let date = Date(timeIntervalSince1970: 42)
        #expect(try Value.date(date).coerce(to: Date.self) == date)
    }
}
