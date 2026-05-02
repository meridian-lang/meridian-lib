import Foundation

public protocol Planner: Sendable {
    func plan(_ context: PlanContext) async throws -> PlanProposal
}

public struct PlanContext: Sendable {
    public let prose: String
    public let snapshot: StateSnapshot
    public let tools: [ToolSchema]
    public let maxActions: Int

    public init(
        prose: String,
        snapshot: StateSnapshot,
        tools: [ToolSchema],
        maxActions: Int = 32
    ) {
        self.prose = prose
        self.snapshot = snapshot
        self.tools = tools
        self.maxActions = maxActions
    }
}

public struct PlanProposal: Sendable {
    public let actions: [ProposedAction]
    public let rationale: String?

    public init(actions: [ProposedAction], rationale: String? = nil) {
        self.actions = actions
        self.rationale = rationale
    }
}

public struct ProposedAction: Sendable, Equatable {
    public let toolID: String
    public let arguments: [String: Value]
    public let resultBinding: String?

    public init(toolID: String, arguments: [String: Value] = [:], resultBinding: String? = nil) {
        self.toolID = toolID
        self.arguments = arguments
        self.resultBinding = resultBinding
    }
}

public struct NoopPlanner: Planner {
    public init() {}

    public func plan(_ context: PlanContext) async throws -> PlanProposal {
        PlanProposal(actions: [])
    }
}
