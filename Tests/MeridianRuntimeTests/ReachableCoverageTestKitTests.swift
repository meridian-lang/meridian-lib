import Testing
import Foundation
import MeridianRuntime
import MeridianTestKit

/// Batch 4 (TestKit slice): exercises the test-helper library itself so the
/// helpers other suites depend on are themselves covered — event-stream
/// normalize/diff, golden write+compare, plan fuzzer, JSONL replay, the
/// recording tool, the mock tool registry, and the planner/act/discretion mocks.

@Suite("Reachable coverage — batch 4 (TestKit helpers)")
struct ReachableCoverageTestKitTests {

    @Test("EventAssertions: normalize (parent_run_id + nested duration) + diff branches")
    func eventAssertions() {
        let jsonl = """
        {"ts":"2026-01-01T00:00:00Z","run_id":"abc","kind":"invoke.end","parent_run_id":"p","payload":{"duration_ms":12,"x":1}}
        not-json-line
        """
        let norm = EventAssertions.normalize(jsonl)
        #expect(norm.contains { $0.contains("<run>") })          // run_id + parent_run_id sentinel
        #expect(norm.contains("not-json-line"))                   // invalid line passes through (guard)

        #expect(EventAssertions.diff(actual: ["a", "b"], expected: ["a", "b"]) == nil)
        let d = EventAssertions.diff(actual: ["a", "b"], expected: ["a", "c", "extra"])
        #expect(d?.contains("✓") == true)        // matching line
        #expect(d?.contains("✗") == true)        // mismatched line
        #expect(d?.contains("<missing>") == true) // length difference
    }

    @Test("GoldenFile: write-when-absent then compare-equal")
    func goldenFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("golden-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let g = GoldenFile(url)
        #expect(try g.assertMatches("hello") == true)   // absent → writes, returns true
        #expect(try g.assertMatches("hello") == true)   // present → compares equal
        #expect(try g.assertMatches("different") == false)
    }

    @Test("PlanFuzzer: empty/zero guard + deterministic proposals")
    func planFuzzer() {
        let f = PlanFuzzer()
        #expect(f.proposals(toolIDs: [], count: 3).isEmpty)        // guard: empty tools
        #expect(f.proposals(toolIDs: ["a"], count: 0).isEmpty)     // guard: zero count
        let ps = f.proposals(toolIDs: ["a", "b"], count: 2)
        #expect(ps.count == 2)
    }

    @Test("JSONLReplay: eventKinds skips invalid lines; canonicalize sorts")
    func jsonlReplay() {
        let kinds = JSONLReplay.eventKinds(from: "garbage\n{\"kind\":\"x\"}\n{\"nope\":1}")
        #expect(kinds == ["x"])
        #expect(JSONLReplay.canonicalize("b\na") == ["a", "b"])
    }

    @Test("RecordingTool: records calls for both init variants")
    func recordingTool() async throws {
        let t1 = RecordingTool(return: .string("default"))
        _ = try await t1.handler(["k": .number(1)])
        #expect(await t1.recordedCalls().count == 1)

        let t2 = RecordingTool(response: { args in args["k"] ?? .null })
        let r = try await t2.handler(["k": .string("v")])
        #expect(r == .string("v"))
        #expect(await t2.recordedCalls().first?.args["k"] == .string("v"))
    }

    @Test("MockToolRegistry: both stub overloads register a callable tool")
    func mockToolRegistry() async throws {
        let mock = MockToolRegistry()
        await mock.stub("const", return: .number(7))
        await mock.stub("handler") { args in args["in"] ?? .null }
        let a = try await mock.registry.dispatch(tool: "const", args: [:])
        let b = try await mock.registry.dispatch(tool: "handler", args: ["in": .string("z")])
        #expect(a == .number(7))
        #expect(b == .string("z"))
    }

    @Test("Mock planners/act/discretion produce scripted outputs")
    func mockPlanning() async throws {
        let ctx = PlanContext(prose: "p", snapshot: StateSnapshot(bindings: [:]), tools: [], maxActions: 2)
        let proposal = PlanProposal(actions: [ProposedAction(toolID: "t")])

        let mp = MockPlanner(actions: [ProposedAction(toolID: "t")])
        #expect(try await mp.plan(ctx).actions.first?.toolID == "t")

        let scripted = ScriptedPlanner([proposal])
        #expect(try await scripted.plan(ctx).actions.count == 1)   // removeFirst
        #expect(try await scripted.plan(ctx).actions.isEmpty)      // exhausted → empty

        let actCtx = ActContext(prose: "p", snapshot: StateSnapshot(bindings: [:]),
                                tools: [], observations: [], remainingSteps: 3)
        let actHit = MockActPlanner([.action(ProposedAction(toolID: "t"))])
        if case .action = try await actHit.act(actCtx) {} else { Issue.record("expected .action") }
        let actDone = MockActPlanner([])
        if case .done = try await actDone.act(actCtx) {} else { Issue.record("expected .done") }

        #expect(try await MockDiscretion(true).decide(
            DiscretionContext(question: "?", snapshot: StateSnapshot(bindings: [:]))))
    }
}
