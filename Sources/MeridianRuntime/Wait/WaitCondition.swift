// MARK: - WaitCondition

public enum WaitCondition: Sendable {
    case duration(Duration)
    case signal(String)
    case approval(of: Value, by: RoleRef)
    /// `matching` is `nil` when any event with the given id should wake the workflow.
    case event(String, matching: (@Sendable (Event) -> Bool)?)
}

// MARK: - RoleRef

public struct RoleRef: Sendable, Hashable {
    public let identifier: String

    public static let accountManager = RoleRef(identifier: "account_manager")
    public static let admin = RoleRef(identifier: "admin")
    public static let supervisor = RoleRef(identifier: "supervisor")

    public init(_ identifier: String) {
        self.identifier = identifier
    }

    public init(identifier: String) {
        self.identifier = identifier
    }
}

// MARK: - RuntimeApprovalVerdict
//
// Two-case enum for *delivery* of approvals (runtime.deliverApproval).
// Distinct from the domain ApprovalVerdict (3 cases: approved/denied/deferred)
// which is codegen'd from vocabulary.
// See IMPLEMENTATION_LOG.md DECISION 2026-04-29 06:27.

public enum RuntimeApprovalVerdict: String, Codable, Sendable {
    case approved
    case denied
}
