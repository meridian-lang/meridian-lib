import Testing
@testable import MeridianRuntime

@Suite("Prose runtime executor")
struct ProseRuntimeTests {

    private struct ScriptedPlanner: Planner {
        func plan(_ context: PlanContext) async throws -> PlanProposal {
            PlanProposal(actions: [
                ProposedAction(toolID: "demo.tool", arguments: ["input": .string(context.prose)], resultBinding: "answer")
            ])
        }
    }

    private struct BadPlanner: Planner {
        func plan(_ context: PlanContext) async throws -> PlanProposal {
            PlanProposal(actions: [
                ProposedAction(toolID: "unregistered.tool")
            ])
        }
    }

    private struct GuidanceCapturingPlanner: Planner {
        let captured: CapturedGuidance
        func plan(_ context: PlanContext) async throws -> PlanProposal {
            await captured.set(context.guidance)
            return PlanProposal(actions: [])
        }
    }

    private actor CapturedGuidance {
        private(set) var value: String?
        func set(_ v: String?) { value = v }
    }

    @Test("executeProsePlan routes proposed actions through registered tools")
    func executeProsePlan() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "demo.tool", .closure { args in
            args["input"] ?? .null
        })
        let runtime = Runtime(toolRegistry: registry, observer: InMemoryObserver(), planner: ScriptedPlanner())

        let results = try await runtime.executeProsePlan(
            prose: "do useful work",
            snapshot: State().snapshot(),
            scopedTools: ["demo.tool"]
        )

        #expect(results["answer"] == .string("do useful work"))
    }

    @Test("executeProsePlan rejects planner actions outside the scoped tools")
    func executeProsePlanRejectsOutOfScopeTool() async throws {
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: InMemoryObserver(), planner: BadPlanner())

        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await runtime.executeProsePlan(
                prose: "do useful work",
                snapshot: State().snapshot(),
                scopedTools: ["demo.tool"]
            )
        }
    }

    @Test("executeProsePlan threads guidance into PlanContext; nil when omitted")
    func executeProsePlanThreadsGuidance() async throws {
        let captured = CapturedGuidance()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: InMemoryObserver(), planner: GuidanceCapturingPlanner(captured: captured))

        _ = try await runtime.executeProsePlan(
            prose: "do useful work",
            snapshot: State().snapshot(),
            scopedTools: [],
            guidance: "carry this section's narrative"
        )
        #expect(await captured.value == "carry this section's narrative")

        _ = try await runtime.executeProsePlan(
            prose: "do useful work",
            snapshot: State().snapshot(),
            scopedTools: []
        )
        #expect(await captured.value == nil)
    }
}
