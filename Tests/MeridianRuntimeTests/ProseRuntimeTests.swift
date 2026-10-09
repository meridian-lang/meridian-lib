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
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: registry, observer: observer, planner: ScriptedPlanner())

        let results = try await runtime.executeProsePlan(
            prose: "do useful work",
            snapshot: State().snapshot(),
            scopedTools: ["demo.tool"]
        )

        #expect(results["answer"] == .string("do useful work"))
        let planStart = try #require(await observer.events.first { $0.kind == .planStart })
        #expect((planStart.payload ?? [:])["scoped_tools"] == .list([.string("demo.tool")]))
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

    // MARK: - judgment witnessing (input/output hash + declared kind)

    @Test("planStart/planEnd carry a stable, matching input_payload_hash and the declared output_kind")
    func judgmentEventsCarryInputHashAndOutputKind() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "demo.tool", .closure { args in args["input"] ?? .null })
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: registry, observer: observer, planner: ScriptedPlanner())

        _ = try await runtime.executeProsePlan(
            prose: "do useful work",
            snapshot: State().snapshot(),
            scopedTools: ["demo.tool"],
            outputKind: "text"
        )

        let events = await observer.events
        let planStart = try #require(events.first { $0.kind == .planStart })
        let planEnd = try #require(events.first { $0.kind == .planEnd })

        let startHash = try #require((planStart.payload ?? [:])["input_payload_hash"])
        guard case .string(let startHashValue) = startHash, !startHashValue.isEmpty else {
            Issue.record("expected a non-empty string input_payload_hash, got \(startHash)")
            return
        }
        #expect((planEnd.payload ?? [:])["input_payload_hash"] == startHash)
        #expect((planStart.payload ?? [:])["output_kind"] == .string("text"))
        #expect((planEnd.payload ?? [:])["output_kind"] == .string("text"))

        let outputHash = try #require((planEnd.payload ?? [:])["output_payload_hash"])
        guard case .string(let outputHashValue) = outputHash, !outputHashValue.isEmpty else {
            Issue.record("expected a non-empty string output_payload_hash, got \(outputHash)")
            return
        }
    }

    @Test("input_payload_hash changes when the snapshot bound into the judgment changes")
    func inputHashReflectsSnapshotContent() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: observer, planner: GuidanceCapturingPlanner(captured: CapturedGuidance()))

        var stateA = State()
        stateA.bind("x", Value.string("a"))
        _ = try await runtime.executeProsePlan(prose: "goal", snapshot: stateA.snapshot(), scopedTools: [])

        var stateB = State()
        stateB.bind("x", Value.string("b"))
        _ = try await runtime.executeProsePlan(prose: "goal", snapshot: stateB.snapshot(), scopedTools: [])

        let starts = await observer.events.filter { $0.kind == .planStart }
        #expect(starts.count == 2)
        #expect((starts[0].payload ?? [:])["input_payload_hash"] != (starts[1].payload ?? [:])["input_payload_hash"])
    }

    @Test("output_kind defaults to record when the judgment step declares no explicit output kind")
    func outputKindDefaultsToRecord() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime(toolRegistry: ToolRegistry(), observer: observer, planner: GuidanceCapturingPlanner(captured: CapturedGuidance()))

        _ = try await runtime.executeProsePlan(prose: "goal", snapshot: State().snapshot(), scopedTools: [])

        let planStart = try #require(await observer.events.first { $0.kind == .planStart })
        #expect((planStart.payload ?? [:])["output_kind"] == .string("record"))
    }
}
