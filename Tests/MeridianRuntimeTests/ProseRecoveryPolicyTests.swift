import MeridianTestKit
import Testing
@testable import MeridianRuntime

@Suite("Prose recovery and host policy")
struct ProseRecoveryPolicyTests {

    @Test("host policy denies planner action before invocation")
    func hostPolicyDeniesAction() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "danger.tool", .closure { _ in .string("bad") })
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setObserver(InMemoryObserver())
            .setPlanPolicy(DenyListPlanPolicy(deniedToolIDs: ["danger.tool"]))
            .setPlanner(MockPlanner(actions: [ProposedAction(toolID: "danger.tool")]))
            .build()

        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await runtime.executeProsePlan(
                prose: "try danger",
                snapshot: State().snapshot(),
                scopedTools: ["danger.tool"]
            )
        }
    }

    @Test("prose action writes replay checkpoint")
    func proseActionCheckpoint() async throws {
        let checkpointer = InMemoryCheckpointer()
        let registry = ToolRegistry()
        await registry.register(tool: "safe.tool", .closure { _ in .string("ok") })
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setObserver(InMemoryObserver())
            .setCheckpointer(checkpointer)
            .setRunID("prose-checkpoint")
            .setPlanner(MockPlanner(actions: [
                ProposedAction(toolID: "safe.tool", resultBinding: "value")
            ]))
            .build()

        _ = try await runtime.executeProsePlan(
            prose: "safe work",
            snapshot: State().snapshot(),
            scopedTools: ["safe.tool"]
        )

        let latest = try await checkpointer.latest(forRun: "prose-checkpoint")
        #expect(latest?.label == "prose.plan.action.safe.tool")
    }

    @Test("autonomy checkpoint captures action bindings for resume")
    func autonomyCheckpointCapturesBindings() async throws {
        let checkpointer = InMemoryCheckpointer()
        let registry = ToolRegistry()
        await registry.register(tool: "safe.tool", .closure { _ in .string("checkpointed") })
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setObserver(InMemoryObserver())
            .setCheckpointer(checkpointer)
            .setRunID("autonomy-checkpoint")
            .setActPlanner(MockActPlanner([
                .action(ProposedAction(toolID: "safe.tool", resultBinding: "value")),
                .done(reason: "done")
            ]))
            .build()

        _ = try await runtime.executeAutonomousLoop(
            prose: "safe work",
            snapshot: State().snapshot(),
            scopedTools: ["safe.tool"],
            maxSteps: 4
        )

        let latest = try #require(try await checkpointer.latest(forRun: "autonomy-checkpoint"))
        #expect(latest.label == "autonomy.action.safe.tool")
        #expect(latest.stateSnapshot.asValues["value"] == .string("checkpointed"))

        let resumeContext = try await runtime.prepareResume(runID: "autonomy-checkpoint")
        #expect(resumeContext.restoredState.asValues["value"] == .string("checkpointed"))
    }
}
