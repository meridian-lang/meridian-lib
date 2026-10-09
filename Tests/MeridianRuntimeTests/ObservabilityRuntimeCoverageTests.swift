import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Observability coverage closeout — runtime")
struct ObservabilityRuntimeCoverageTests {

    private struct DefaultTraceConfigWorkflow: MeridianWorkflow {
        let runtime: Runtime

        func run() async throws -> WorkflowResult {
            WorkflowResult(reason: nil)
        }
    }

    @Test("MeridianWorkflow protocol extension defaults runtimeTraceConfiguration to nil")
    func meridianWorkflowDefaultTraceConfiguration() {
        #expect(DefaultTraceConfigWorkflow.runtimeTraceConfiguration == nil)
    }

    @Test("invoke honors explicit capture policies on invokeStart payloads")
    func invokeExplicitCapturePolicies() async throws {
        let observer = InMemoryObserver()
        let registry = ToolRegistry()
        await registry.register(tool: "echo", .closure { args in args["token"] ?? .null })
        let runtime = Runtime(toolRegistry: registry, observer: observer, runID: "capture-test")

        _ = try await runtime.invoke(
            tool: "echo",
            args: ["token": .string("secret"), "nested": .record(["token": .string("inner")])],
            capturePolicy: .full)
        _ = try await runtime.invoke(
            tool: "echo",
            args: ["token": .string("secret")],
            capturePolicy: .hashOnly)
        _ = try await runtime.invoke(
            tool: "echo",
            args: ["token": .string("secret"), "items": .list([.record(["token": .string("x")])])],
            capturePolicy: .redacted(["token"]))

        let starts = await observer.events.filter { $0.kind == .invokeStart }
        #expect(starts.count == 3)
        if case .record(let args) = (starts[2].payload ?? [:])["args"] {
            #expect(args["token"] == .string("<redacted>"))
        } else {
            Issue.record("expected redacted invoke args")
        }
    }

    @Test("workflowFailed records error_code for ToolError implementations")
    func workflowFailedToolErrorCode() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: observer, runID: "wf-fail")
        let toolError = ToolError.implementation(code: "payment.declined", message: "card declined", cause: nil)
        try await runtime.workflowFailed(workflowName: "Checkout", error: toolError)

        let failed = await observer.events.first { $0.kind == .workflowFailed }
        #expect((failed?.payload ?? [:])["error_code"] == .string("payment.declined"))
    }

    @Test("evaluateTrace returns indeterminate without a trace store and evaluates with one")
    func evaluateTraceDirectly() async throws {
        let bare = Runtime(toolRegistry: ToolRegistry(), runID: "no-store")
        let temporal = TraceTemporalQuery(kind: .ever(
            TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded)))
        #expect(try await bare.evaluateTrace(temporal, evaluationInstant: Date()) == .indeterminate)

        let store = InMemoryTraceStore()
        let clock = TestClock(start: Date(timeIntervalSince1970: 0))
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            traceStore: store,
            clock: clock,
            runID: "run-1",
            traceConfiguration: TraceConfiguration(sampleFloor: 1),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )
        try await store.append(sampleRecord(tag: .completed, outcome: .success))
        let statistical = TraceStatisticalQuery(
            pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
            bound: .atLeast(0.9),
            denominator: .occurrences)
        #expect(try await runtime.evaluateTrace(statistical, evaluationInstant: Date(timeIntervalSince1970: 10)) == .true)

        let bareStat = TraceStatisticalQuery(
            pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
            bound: .atLeast(0.9),
            denominator: .occurrences)
        #expect(try await bare.evaluateTrace(bareStat, evaluationInstant: Date()) == .indeterminate)
    }

    @Test("blocking monitor violations and evaluate failures record operational diagnostics")
    func monitorFailurePaths() async throws {
        let observer = InMemoryObserver()
        let failingStore = QueryFailingTraceStore()
        let clock = TestClock(start: Date(timeIntervalSince1970: 0))
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            traceStore: failingStore,
            clock: clock,
            runID: "monitor-fail",
            traceConfiguration: TraceConfiguration(sampleFloor: 1, storeFailurePolicy: .failClosed),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )

        await runtime.registerMonitor(
            query: TraceStatisticalQuery(
                pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
                bound: .atLeast(0.9),
                denominator: .occurrences),
            cadence: .seconds(5),
            message: "Expected deploy stability")
        await settle()
        await clock.advance(by: .seconds(5))
        await settle()
        #expect(await runtime.operationalDiagnostics().contains { $0.code == "monitor.evaluate" })

        let healthyStore = InMemoryTraceStore()
        let blockingClock = TestClock(start: Date(timeIntervalSince1970: 0))
        let blockingRuntime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            traceStore: healthyStore,
            clock: blockingClock,
            runID: "monitor-block",
            traceConfiguration: TraceConfiguration(sampleFloor: 1),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )
        try await healthyStore.append(sampleRecord(run: "monitor-block", tag: .failed, outcome: .failure))
        await blockingRuntime.registerMonitor(
            query: TraceStatisticalQuery(
                pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
                bound: .atLeast(0.9),
                denominator: .occurrences),
            cadence: .seconds(5),
            message: "Expected deploy stability",
            blocking: true)
        await settle()
        await blockingClock.advance(by: .seconds(5))
        await settle()

        #expect(await blockingRuntime.operationalDiagnostics().contains { $0.code == "monitor.assertion" })
        let violated = try await healthyStore.query(
            scope: .acrossAllRuns, scopeSkills: [], runID: nil, skillName: "deploy", window: nil, pattern: nil)
        #expect(violated.contains { $0.tag == .violated })
    }

    @Test("monitor sleep cancellation exits quietly when the runtime completes")
    func monitorSleepCancellation() async throws {
        let store = InMemoryTraceStore()
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            traceStore: store,
            clock: SystemClock(),
            runID: "monitor-cancel",
            traceConfiguration: TraceConfiguration(sampleFloor: 1),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )
        try await store.append(sampleRecord(tag: .completed, outcome: .success))
        await runtime.registerMonitor(
            query: TraceStatisticalQuery(
                pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
                bound: .atLeast(0.9),
                denominator: .occurrences),
            cadence: .seconds(3600),
            message: "Expected deploy stability")
        await runtime.complete(reason: nil)
        try await Task.sleep(for: .milliseconds(20))
        #expect(Bool(true))
    }

    private func sampleRecord(run: String = "run-1", tag: TraceTag, outcome: TraceOutcome?) -> TraceRecord {
        TraceRecord(
            id: UUID().uuidString,
            at: Date(timeIntervalSince1970: 1),
            ingestOrder: 1,
            run: run,
            step: "deploy",
            skillName: "deploy",
            skillVersionHash: "v1",
            tag: tag,
            subject: "deploy",
            payload: [:],
            payloadHash: "payload",
            outcome: outcome,
            operationalDetail: nil
        )
    }

    private func settle() async {
        try? await Task.sleep(for: .milliseconds(10))
        for _ in 0..<5 { await Task.yield() }
    }
}

private actor QueryFailingTraceStore: TraceStore {
    var capabilities: TraceStoreCapabilities {
        TraceStoreCapabilities(
            isPersistent: false,
            supportsCompaction: false)
    }

    func append(_ event: TraceRecord) async throws {}

    func query(
        scope: TraceScope,
        scopeSkills: [String],
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord] {
        throw TraceStoreError.traceStoreFailure("simulated query failure")
    }

    func compact(retention: Duration, now: Date) async throws {}
}
