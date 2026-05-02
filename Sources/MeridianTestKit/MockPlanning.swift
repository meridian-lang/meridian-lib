import Foundation
import MeridianRuntime

public struct MockPlanner: Planner {
    private let proposals: [PlanProposal]

    public init(_ proposals: [PlanProposal]) {
        self.proposals = proposals
    }

    public init(actions: [ProposedAction]) {
        self.proposals = [PlanProposal(actions: actions)]
    }

    public func plan(_ context: PlanContext) async throws -> PlanProposal {
        proposals.first ?? PlanProposal(actions: [])
    }
}

public actor ScriptedPlanner: Planner {
    private var proposals: [PlanProposal]

    public init(_ proposals: [PlanProposal]) {
        self.proposals = proposals
    }

    public func plan(_ context: PlanContext) async throws -> PlanProposal {
        guard !proposals.isEmpty else { return PlanProposal(actions: []) }
        return proposals.removeFirst()
    }
}

public struct MockActPlanner: ActPlanner {
    private let proposals: [ActProposal]

    public init(_ proposals: [ActProposal]) {
        self.proposals = proposals
    }

    public func act(_ context: ActContext) async throws -> ActProposal {
        guard context.observations.count < proposals.count else {
            return .done(reason: "script exhausted")
        }
        return proposals[context.observations.count]
    }
}

public struct MockDiscretion: Discretion {
    private let decision: Bool

    public init(_ decision: Bool) {
        self.decision = decision
    }

    public func decide(_ context: DiscretionContext) async throws -> Bool {
        decision
    }
}
