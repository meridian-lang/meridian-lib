public protocol PlanPolicy: Sendable {
    func permits(_ action: ProposedAction) async -> Bool
}

public struct AllowAllPlanPolicy: PlanPolicy {
    public init() {}
    public func permits(_ action: ProposedAction) async -> Bool { true }
}

public struct DenyListPlanPolicy: PlanPolicy {
    private let deniedToolIDs: Set<String>

    public init(deniedToolIDs: Set<String>) {
        self.deniedToolIDs = deniedToolIDs
    }

    public func permits(_ action: ProposedAction) async -> Bool {
        !deniedToolIDs.contains(action.toolID)
    }
}
