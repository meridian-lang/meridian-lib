import Foundation

public protocol ActPlanner: Sendable {
    func act(_ context: ActContext) async throws -> ActProposal
}

public struct ActContext: Sendable {
    public let prose: String
    public let snapshot: StateSnapshot
    public let tools: [ToolSchema]
    public let observations: [ObservationTurn]
    public let remainingSteps: Int

    public init(
        prose: String,
        snapshot: StateSnapshot,
        tools: [ToolSchema],
        observations: [ObservationTurn] = [],
        remainingSteps: Int
    ) {
        self.prose = prose
        self.snapshot = snapshot
        self.tools = tools
        self.observations = observations
        self.remainingSteps = remainingSteps
    }
}

public enum ActProposal: Sendable, Equatable {
    case action(ProposedAction)
    case done(reason: String?)
}

public struct ObservationTurn: Sendable, Equatable {
    public let action: ProposedAction?
    public let outcome: ActionOutcome

    public init(action: ProposedAction?, outcome: ActionOutcome) {
        self.action = action
        self.outcome = outcome
    }
}

public enum ActionOutcome: Sendable, Equatable {
    case success(Value)
    case failure(String)
}

public struct NoopActPlanner: ActPlanner {
    public init() {}

    public func act(_ context: ActContext) async throws -> ActProposal {
        .done(reason: "noop")
    }
}
