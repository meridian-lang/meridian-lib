public struct PlanningResourceLimits: Sendable, Equatable {
    public let maxProseBytes: Int
    public let maxSnapshotBytes: Int
    public let maxHistoryBytes: Int
    public let maxProposalBytes: Int
    public let maxActions: Int
    public let maxToolArgumentBytes: Int

    public init(
        maxProseBytes: Int = 32_768,
        maxSnapshotBytes: Int = 131_072,
        maxHistoryBytes: Int = 131_072,
        maxProposalBytes: Int = 65_536,
        maxActions: Int = 32,
        maxToolArgumentBytes: Int = 16_384
    ) {
        self.maxProseBytes = maxProseBytes
        self.maxSnapshotBytes = maxSnapshotBytes
        self.maxHistoryBytes = maxHistoryBytes
        self.maxProposalBytes = maxProposalBytes
        self.maxActions = maxActions
        self.maxToolArgumentBytes = maxToolArgumentBytes
    }

    public static let `default` = PlanningResourceLimits()
}
