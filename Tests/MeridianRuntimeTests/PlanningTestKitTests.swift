import MeridianTestKit
import Testing
@testable import MeridianRuntime

@Suite("Planning test kit helpers")
struct PlanningTestKitTests {

    @Test("Runtime.Builder installs mock planning hooks")
    func builderInstallsMocks() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "demo.tool", .closure { _ in .string("ok") })
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setObserver(InMemoryObserver())
            .setPlanner(MockPlanner(actions: [
                ProposedAction(toolID: "demo.tool", resultBinding: "value")
            ]))
            .setActPlanner(MockActPlanner([.done(reason: "done")]))
            .setDiscretion(MockDiscretion(true))
            .build()

        let decision = try await runtime.discretion.decide(.init(
            question: "ship?",
            snapshot: State().snapshot()
        ))
        #expect(decision)

        let results = try await runtime.executeProsePlan(
            prose: "do it",
            snapshot: State().snapshot(),
            scopedTools: ["demo.tool"]
        )
        #expect(results["value"] == .string("ok"))
    }
}
