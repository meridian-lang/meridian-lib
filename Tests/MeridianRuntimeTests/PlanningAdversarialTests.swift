import MeridianTestKit
import Testing
@testable import MeridianRuntime

@Suite("Planning adversarial coverage")
struct PlanningAdversarialTests {

    private struct OneBadActionPlanner: Planner {
        let toolID: String
        func plan(_ context: PlanContext) async throws -> PlanProposal {
            PlanProposal(actions: [ProposedAction(toolID: toolID)])
        }
    }

    @Test("planner cannot invoke unregistered or out-of-scope tools")
    func rejectsSixteenAdversarialTools() async throws {
        let adversarialIDs = (0..<16).map { "attacker.tool.\($0)" }
        for toolID in adversarialIDs {
            let runtime = Runtime(
                toolRegistry: ToolRegistry(),
                observer: InMemoryObserver(),
                planner: OneBadActionPlanner(toolID: toolID)
            )
            await #expect(throws: MeridianRuntimeError.self) {
                _ = try await runtime.executeProsePlan(
                    prose: "try to escape",
                    snapshot: State().snapshot(),
                    scopedTools: ["allowed.tool"]
                )
            }
        }
    }

    @Test("plan fuzzer creates deterministic proposal corpus")
    func planFuzzerDeterministic() {
        let first = PlanFuzzer(seed: 42).proposals(toolIDs: ["a", "b", "c"], count: 8)
        let second = PlanFuzzer(seed: 42).proposals(toolIDs: ["a", "b", "c"], count: 8)
        #expect(first.map(\.actions) == second.map(\.actions))
    }

    @Test("JSONL replay canonicalization is deterministic")
    func jsonlReplay() {
        let jsonl = """
        {"kind":"invoke.end","seq":2}
        {"kind":"invoke.start","seq":1}
        """
        #expect(JSONLReplay.eventKinds(from: jsonl) == ["invoke.end", "invoke.start"])
        #expect(JSONLReplay.canonicalize(jsonl).first?.contains("invoke.end") == true)
    }

    @Test("clock harness builds deterministic runtimes")
    func clockHarnessRuntime() async throws {
        let harness = ClockHarness()
        let registry = ToolRegistry()
        await registry.register(tool: "demo.tool", .closure { _ in .string("ok") })
        let runtime = harness.runtime(
            registry: registry,
            observer: InMemoryObserver(),
            planner: MockPlanner(actions: [ProposedAction(toolID: "demo.tool", resultBinding: "value")])
        )
        let result = try await runtime.executeProsePlan(
            prose: "go",
            snapshot: State().snapshot(),
            scopedTools: ["demo.tool"]
        )
        #expect(result["value"] == .string("ok"))
    }

    @Test("different hosts can install different planner backends")
    func multiHostBackends() async throws {
        let registryA = ToolRegistry()
        let registryB = ToolRegistry()
        await registryA.register(tool: "tool.a", .closure { _ in .string("a") })
        await registryB.register(tool: "tool.b", .closure { _ in .string("b") })

        let hostA = Runtime.Builder()
            .setToolRegistry(registryA)
            .setObserver(InMemoryObserver())
            .setPlanner(MockPlanner(actions: [ProposedAction(toolID: "tool.a", resultBinding: "value")]))
            .build()
        let hostB = Runtime.Builder()
            .setToolRegistry(registryB)
            .setObserver(InMemoryObserver())
            .setPlanner(MockPlanner(actions: [ProposedAction(toolID: "tool.b", resultBinding: "value")]))
            .build()

        let a = try await hostA.executeProsePlan(prose: "go", snapshot: State().snapshot(), scopedTools: ["tool.a"])
        let b = try await hostB.executeProsePlan(prose: "go", snapshot: State().snapshot(), scopedTools: ["tool.b"])
        #expect(a["value"] == .string("a"))
        #expect(b["value"] == .string("b"))
    }
}
