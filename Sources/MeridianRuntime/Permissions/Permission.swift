import Foundation

/// Contextual snapshot passed to a permission predicate when evaluating
/// whether a subject is allowed to perform an action.
public struct PermissionScope: Sendable {
    public let parameters: [String: Value]
    public let actor: Value?

    public init(parameters: [String: Value] = [:], actor: Value? = nil) {
        self.parameters = parameters
        self.actor = actor
    }
}

/// A declarative permission that gates an action on a predicate closure.
public struct Permission: Sendable {
    public let subjectKind: String
    public let actionDisplayName: String
    public let description: String
    public let isBounded: Bool
    public let predicate: @Sendable (PermissionScope) -> Bool

    public init(
        subjectKind: String,
        actionDisplayName: String,
        description: String,
        isBounded: Bool = false,
        predicate: @escaping @Sendable (PermissionScope) -> Bool
    ) {
        self.subjectKind = subjectKind
        self.actionDisplayName = actionDisplayName
        self.description = description
        self.isBounded = isBounded
        self.predicate = predicate
    }

    public func evaluate(_ scope: PermissionScope) -> Bool {
        predicate(scope)
    }
}
