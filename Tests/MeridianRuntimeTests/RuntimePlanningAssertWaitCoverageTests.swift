import Testing
import Foundation
@testable import MeridianRuntime

@Suite("Runtime+Wait coverage")
struct RuntimeWaitCoverageTests {
    private func makeRuntime() -> Runtime {
        Runtime(toolRegistry: ToolRegistry())
    }

    @Test("deliverSignal resumes a parked wait(.signal)")
    func deliverSignalResumes() async throws {
        let runtime = makeRuntime()
        async let waiter: Void = runtime.wait(.signal("go"), timeout: .seconds(2), sourceRange: nil)
        try await Task.sleep(nanoseconds: 20_000_000)
        await runtime.deliverSignal("go")
        try await waiter
    }

    @Test("deliverChoice + consumeChoiceSelection round-trip")
    func deliverChoiceRoundTrip() async throws {
        let runtime = makeRuntime()
        async let waiter: Void = runtime.wait(
            .choice(prompt: "pick", options: ["a", "b"]),
            timeout: .seconds(2),
            sourceRange: nil
        )
        try await Task.sleep(nanoseconds: 20_000_000)
        await runtime.deliverChoice("b")
        try await waiter
        let selection = await runtime.consumeChoiceSelection()
        #expect(selection == "b")
    }

    @Test("waitStartPayload encodes condition kind")
    func waitStartPayloadKinds() async {
        let runtime = makeRuntime()
        let duration = await runtime.waitStartPayload(.duration(.seconds(1)))
        #expect(duration["kind"] == .string("duration"))
        let signal = await runtime.waitStartPayload(.signal("x"))
        #expect(signal["kind"] == .string("signal"))
        #expect(signal["name"] == .string("x"))
    }
}

@Suite("Runtime+Planning coverage")
struct RuntimePlanningCoverageTests {
    @Test("scopedToolPayload sorts and wraps tool ids")
    func scopedToolPayload() async {
        let runtime = Runtime(toolRegistry: ToolRegistry())
        let payload = await runtime.scopedToolPayload(["b", "a"])
        guard case .list(let items) = payload else {
            Issue.record("expected list"); return
        }
        #expect(items.map(\.scalarDescription) == ["a", "b"])
    }

    @Test("judgmentPayloadHash is stable for equal bindings")
    func judgmentPayloadHashStable() async throws {
        let runtime = Runtime(toolRegistry: ToolRegistry())
        let a = await runtime.judgmentPayloadHash(["x": .string("1")])
        let b = await runtime.judgmentPayloadHash(["x": .string("1")])
        #expect(a == b)
        guard case .string(let hash) = a else {
            Issue.record("expected string hash"); return
        }
        #expect(!hash.isEmpty)
    }
}

@Suite("Runtime+Assert coverage")
struct RuntimeAssertCoverageTests {
    @Test("recordBranchTaken emits without throwing")
    func recordBranchTaken() async throws {
        let runtime = Runtime(toolRegistry: ToolRegistry())
        try await runtime.recordBranchTaken(condition: "c", into: "then", step: "s1")
    }

    @Test("recordIterateStart/Iteration/End emit without throwing")
    func recordIterateLifecycle() async throws {
        let runtime = Runtime(toolRegistry: ToolRegistry())
        try await runtime.recordIterateStart(over: "items", step: "loop")
        try await runtime.recordIterateIteration(index: 0, step: "loop")
        try await runtime.recordIterateEnd(over: "items", count: 1, step: "loop")
    }

    @Test("assert(indeterminate) emits assertPassed with indeterminate outcome")
    func assertIndeterminate() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: observer, runID: "assert-indet")
        try await runtime.assert(.indeterminate, message: "maybe", step: "s")
        let passed = await observer.events.first { $0.kind == .assertPassed }
        #expect(passed?.payload["outcome"] == .string(TruthValue.indeterminate.rawValue))
    }

    @Test("recordViolation non-blocking emits violated without throwing")
    func recordViolationNonBlocking() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: observer, runID: "viol-obs")
        try await runtime.recordViolation(
            normID: "obl-1",
            disposition: "observed",
            blocking: false,
            toolID: "t1"
        )
        let hit = await observer.events.first { $0.kind == .violated }
        #expect(hit?.payload["norm_id"] == .string("obl-1"))
        #expect(hit?.payload["tool_id"] == .string("t1"))
    }

    @Test("recordRecoverEngaged emits recoverEngaged")
    func recordRecoverEngaged() async throws {
        let runtime = Runtime(toolRegistry: ToolRegistry())
        try await runtime.recordRecoverEngaged(pattern: "timeout", step: "r1")
    }
}
