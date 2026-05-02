import Testing
@testable import MeridianRuntime

@Suite("Planning protocol boundary")
struct PlannerProtocolTests {

    private struct AlwaysYesDiscretion: Discretion {
        func decide(_ context: DiscretionContext) async throws -> Bool { true }
    }

    private struct StaticPlanner: Planner {
        func plan(_ context: PlanContext) async throws -> PlanProposal {
            PlanProposal(actions: [
                ProposedAction(toolID: "demo.tool", arguments: ["x": .string("y")], resultBinding: "result")
            ])
        }
    }

    @Test("default discretion is deterministic false")
    func defaultDiscretionFalse() async throws {
        let result = try await DefaultDiscretion().decide(.init(
            question: "ship?",
            snapshot: State().snapshot()
        ))
        #expect(result == false)
    }

    @Test("runtime accepts a Discretion implementation separate from tools")
    func runtimeDiscretionSlot() async throws {
        let runtime = Runtime(toolRegistry: ToolRegistry(), discretion: AlwaysYesDiscretion())
        let result = try await runtime.discretion.decide(.init(
            question: "ship?",
            snapshot: State().snapshot()
        ))
        #expect(result == true)
    }

    @Test("planner proposals are pure values")
    func plannerProposalShape() async throws {
        let proposal = try await StaticPlanner().plan(.init(
            prose: "do the thing",
            snapshot: State().snapshot(),
            tools: [ToolSchema(id: "demo.tool")],
            maxActions: 4
        ))
        #expect(proposal.actions == [
            ProposedAction(toolID: "demo.tool", arguments: ["x": .string("y")], resultBinding: "result")
        ])
    }

    @Test("tool registry exposes schemas for scoped tool IDs")
    func toolRegistrySchemas() async {
        let registry = ToolRegistry()
        await registry.register(tool: "demo.tool", .closure { _ in .null })
        let schemas = await registry.schemas(Set(["demo.tool", "missing.tool"]))
        #expect(schemas == [ToolSchema(id: "demo.tool")])
    }
}
