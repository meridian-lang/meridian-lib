import Testing
@testable import MeridianRuntime
import MeridianTestKit

@Suite("Autonomy runtime executor")
struct AutonomyRuntimeTests {

    private struct OneActionActPlanner: ActPlanner {
        func act(_ context: ActContext) async throws -> ActProposal {
            context.observations.isEmpty
                ? .action(ProposedAction(toolID: "demo.tool", arguments: ["x": .string("ok")], resultBinding: "value"))
                : .done(reason: "done")
        }
    }

    private struct FailOnceActPlanner: ActPlanner {
        func act(_ context: ActContext) async throws -> ActProposal {
            context.observations.isEmpty
                ? .action(ProposedAction(toolID: "flaky.tool", resultBinding: "attempt"))
                : .done(reason: "done")
        }
    }

    private actor CountingActPlanner: ActPlanner {
        private(set) var calls = 0
        private let action: ProposedAction

        init(action: ProposedAction = ProposedAction(toolID: "demo.tool", resultBinding: "done")) {
            self.action = action
        }

        func act(_ context: ActContext) async throws -> ActProposal {
            calls += 1
            return .action(action)
        }
    }

    @Test("executeAutonomousLoop runs planner actions and returns bindings")
    func executeAutonomousLoop() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "demo.tool", .closure { args in args["x"] ?? .null })
        let runtime = Runtime(toolRegistry: registry, observer: InMemoryObserver(), actPlanner: OneActionActPlanner())

        let results = try await runtime.executeAutonomousLoop(
            prose: "fix it",
            snapshot: State().snapshot(),
            scopedTools: ["demo.tool"],
            maxSteps: 4,
            replanAfterFailures: 2
        )

        #expect(results["value"] == .string("ok"))
    }

    @Test("executeAutonomousLoop stops immediately when until predicate is already true")
    func untilPredicateStopsBeforePlanning() async throws {
        var state = State()
        state.bind("done", Value.boolean(true))
        let planner = CountingActPlanner()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: InMemoryObserver(), actPlanner: planner)

        let results = try await runtime.executeAutonomousLoop(
            prose: "fix it",
            snapshot: state.snapshot(),
            scopedTools: [],
            maxSteps: 4,
            until: { $0.asValues["done"] == .boolean(true) }
        )

        #expect(results.isEmpty)
        #expect(await planner.calls == 0)
    }

    @Test("executeAutonomousLoop stops after an action when until predicate becomes true")
    func untilPredicateSeesActionBindings() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "demo.tool", .closure { _ in .boolean(true) })
        let planner = CountingActPlanner()
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: registry, observer: observer, actPlanner: planner)

        let results = try await runtime.executeAutonomousLoop(
            prose: "fix it",
            snapshot: State().snapshot(),
            scopedTools: ["demo.tool"],
            maxSteps: 4,
            until: { $0.asValues["done"] == .boolean(true) }
        )

        #expect(results["done"] == .boolean(true))
        #expect(await planner.calls == 1)
        let events = await observer.events
        #expect(events.contains {
            $0.kind == .autonomyEnd && ($0.payload ?? [:])["reason"] == .string("until_condition_met")
        })
    }

    @Test("executeAutonomousLoop aborts immediately when unless predicate is true")
    func unlessPredicateStopsBeforePlanning() async throws {
        var state = State()
        state.bind("blocked", Value.boolean(true))
        let planner = CountingActPlanner()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: InMemoryObserver(), actPlanner: planner)

        _ = try await runtime.executeAutonomousLoop(
            prose: "fix it",
            snapshot: state.snapshot(),
            scopedTools: [],
            maxSteps: 4,
            unless: { $0.asValues["blocked"] == .boolean(true) }
        )

        #expect(await planner.calls == 0)
    }

    @Test("a tool failure past the replan threshold falls back to the Planner and continues")
    func replanAfterConsecutiveFailuresRecovers() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "flaky.tool", .closure { _ in
            throw ToolError.implementation(code: "boom", message: "always fails", cause: nil)
        })
        await registry.register(tool: "fallback.tool", .closure { _ in .string("recovered-value") })
        let replanner = ScriptedPlanner([
            PlanProposal(actions: [ProposedAction(toolID: "fallback.tool", resultBinding: "recovered")])
        ])
        let runtime = Runtime(
            toolRegistry: registry,
            observer: InMemoryObserver(),
            planner: replanner,
            actPlanner: FailOnceActPlanner()
        )

        let results = try await runtime.executeAutonomousLoop(
            prose: "fix it",
            snapshot: State().snapshot(),
            scopedTools: ["flaky.tool", "fallback.tool"],
            maxSteps: 4,
            replanAfterFailures: 1
        )

        #expect(results["recovered"] == .string("recovered-value"))
    }

    // MARK: - judgment witnessing (autonomy dispatch path)

    @Test("autonomyStart/autonomyEnd carry a matching input_payload_hash and the declared output_kind")
    func autonomyEventsCarryInputHashAndOutputKind() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "demo.tool", .closure { args in args["x"] ?? .null })
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: registry, observer: observer, actPlanner: OneActionActPlanner())

        _ = try await runtime.executeAutonomousLoop(
            prose: "fix it",
            snapshot: State().snapshot(),
            scopedTools: ["demo.tool"],
            maxSteps: 4,
            outputKind: "text"
        )

        let events = await observer.events
        let start = try #require(events.first { $0.kind == .autonomyStart })
        let end = try #require(events.first { $0.kind == .autonomyEnd })

        let startHash = try #require((start.payload ?? [:])["input_payload_hash"])
        guard case .string(let startHashValue) = startHash, !startHashValue.isEmpty else {
            Issue.record("expected a non-empty string input_payload_hash, got \(startHash)")
            return
        }
        #expect((end.payload ?? [:])["input_payload_hash"] == startHash)
        #expect((start.payload ?? [:])["output_kind"] == .string("text"))
        #expect((end.payload ?? [:])["output_kind"] == .string("text"))

        let outputHash = try #require((end.payload ?? [:])["output_payload_hash"])
        guard case .string(let outputHashValue) = outputHash, !outputHashValue.isEmpty else {
            Issue.record("expected a non-empty string output_payload_hash, got \(outputHash)")
            return
        }
    }

    @Test("autonomyEnd's output_payload_hash reflects the empty bindings when the loop stops before acting")
    func autonomyEndHashesEmptyBindingsWhenStoppedEarly() async throws {
        var state = State()
        state.bind("blocked", Value.boolean(true))
        let planner = CountingActPlanner()
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: observer, actPlanner: planner)

        _ = try await runtime.executeAutonomousLoop(
            prose: "fix it",
            snapshot: state.snapshot(),
            scopedTools: [],
            maxSteps: 4,
            unless: { $0.asValues["blocked"] == .boolean(true) }
        )

        let end = try #require(await observer.events.first { $0.kind == .autonomyEnd })
        #expect((end.payload ?? [:])["output_kind"] == .string("record"))
        #expect((end.payload ?? [:])["output_payload_hash"] != nil)
        #expect(await planner.calls == 0)
    }
}
