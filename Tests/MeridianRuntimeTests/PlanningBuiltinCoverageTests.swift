import Testing
@testable import MeridianRuntime

@Suite("Planning builtins — noop planners and context carriers")
struct PlanningBuiltinCoverageTests {

    @Test("NoopPlanner returns an empty proposal")
    func noopPlanner() async throws {
        let proposal = try await NoopPlanner().plan(.init(
            prose: "do nothing",
            snapshot: State().snapshot(),
            tools: [],
            maxActions: 2,
            guidance: "extra narrative"
        ))
        #expect(proposal.actions.isEmpty)
        #expect(proposal.rationale == nil)
    }

    @Test("NoopActPlanner returns done")
    func noopActPlanner() async throws {
        let turn = ObservationTurn(
            action: ProposedAction(toolID: "demo.tool"),
            outcome: .success(.string("ok"))
        )
        let proposal = try await NoopActPlanner().act(.init(
            prose: "observe",
            snapshot: State().snapshot(),
            tools: [],
            observations: [turn],
            remainingSteps: 1,
            guidance: "hint"
        ))
        guard case .done(let reason) = proposal else {
            Issue.record("expected .done, got \(proposal)")
            return
        }
        #expect(reason == "noop")
    }

    @Test("ActionOutcome failure carries a message")
    func actionOutcomeFailure() {
        let outcome = ActionOutcome.failure("boom")
        guard case .failure(let message) = outcome else {
            Issue.record("expected failure outcome")
            return
        }
        #expect(message == "boom")
    }
}
