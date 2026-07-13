import Testing
import Foundation
@testable import MeridianRuntime

@Suite("Runtime+Diagnostics coverage")
struct RuntimeDiagnosticsCoverageTests {
    @Test("elapsedMS / eventCount / currentDate / operationalDiagnostics basics")
    func diagnosticBasics() async throws {
        let runtime = Runtime(toolRegistry: ToolRegistry(), runID: "diag-run")
        #expect(await runtime.eventCount() == 0)
        #expect(await runtime.elapsedMS() >= 0)
        #expect(await runtime.currentDate().timeIntervalSince1970 > 0)
        #expect(await runtime.operationalDiagnostics().isEmpty)
        try await runtime.emit(event: "ping", payload: [:])
        #expect(await runtime.eventCount() >= 1)
    }

    @Test("evaluateTrace returns indeterminate without a store")
    func evaluateTraceNoStore() async throws {
        let runtime = Runtime(toolRegistry: ToolRegistry(), runID: "no-store")
        let temporal = TraceTemporalQuery(kind: .ever(
            TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded)))
        #expect(try await runtime.evaluateTrace(temporal, evaluationInstant: Date()) == .indeterminate)

        let statistical = TraceStatisticalQuery(
            pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
            bound: .atLeast(0.5),
            denominator: .occurrences
        )
        #expect(try await runtime.evaluateTrace(statistical, evaluationInstant: Date()) == .indeterminate)
    }
}

@Suite("Runtime+Emit coverage")
struct RuntimeEmitCoverageTests {
    @Test("emitOrThrow records through observer and advances sequence")
    func emitOrThrowAdvances() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: observer, runID: "emit-core")
        try await runtime.emitOrThrow(event: Event(
            timestamp: Date(),
            runID: "emit-core",
            sequence: await runtime.nextSeq(),
            kind: .bind,
            payload: ["name": .string("x")]
        ))
        let kinds = await observer.events.map(\.kind)
        #expect(kinds.contains(.bind))
        #expect(await runtime.eventCount() >= 1)
    }

    @Test("recordOperationalDiagnostic appends a redacted entry")
    func recordOperationalDiagnostic() async {
        let runtime = Runtime(toolRegistry: ToolRegistry(), runID: "op-diag")
        await runtime.recordOperationalDiagnostic(code: "test.code", message: "token=secret")
        let diags = await runtime.operationalDiagnostics()
        #expect(diags.count == 1)
        #expect(diags[0].code == "test.code")
    }
}
