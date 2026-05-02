import Testing
@testable import MeridianRuntime

@Suite("Autonomy runtime executor")
struct AutonomyRuntimeTests {

    private struct OneActionActPlanner: ActPlanner {
        func act(_ context: ActContext) async throws -> ActProposal {
            context.observations.isEmpty
                ? .action(ProposedAction(toolID: "demo.tool", arguments: ["x": .string("ok")], resultBinding: "value"))
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
            $0.kind == .autonomyEnd && $0.payload["reason"] == .string("until_condition_met")
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
}
