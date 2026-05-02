import MeridianTestKit
import Testing
@testable import MeridianRuntime

@Suite("Planning resource limits")
struct PlanningResourceLimitTests {

    @Test("oversized prose is rejected with telemetry")
    func rejectsOversizedProse() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime.Builder()
            .setObserver(observer)
            .setPlanningLimits(PlanningResourceLimits(maxProseBytes: 4))
            .build()

        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await runtime.executeProsePlan(
                prose: "too long",
                snapshot: State().snapshot(),
                scopedTools: []
            )
        }
        let events = await observer.events
        #expect(events.contains { $0.kind == EventKind.planRejected })
    }

    @Test("oversized tool arguments are rejected before invocation")
    func rejectsOversizedToolArguments() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "demo.tool", .closure { _ in .string("should not run") })
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setObserver(InMemoryObserver())
            .setPlanningLimits(PlanningResourceLimits(maxToolArgumentBytes: 4))
            .setPlanner(MockPlanner(actions: [
                ProposedAction(toolID: "demo.tool", arguments: ["payload": .string("too long")])
            ]))
            .build()

        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await runtime.executeProsePlan(
                prose: "ok",
                snapshot: State().snapshot(),
                scopedTools: ["demo.tool"]
            )
        }
    }
}
