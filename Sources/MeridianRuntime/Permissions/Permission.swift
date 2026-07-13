import Foundation

/// A static argument constraint for planner-time permission checks (`only where …`).
public struct ToolArgumentConstraint: Sendable {
    public let path: String
    public let expected: Value

    public init(path: String, expected: Value) {
        self.path = path
        self.expected = expected
    }
}

/// A tool permission pattern registered for planner validation. When patterns
/// exist for a tool, proposed actions must satisfy at least one pattern's
/// static argument constraints. Tools with no registered patterns keep the
/// legacy bare `scopedTools` membership check only.
public struct ToolPermissionPattern: Sendable {
    public let toolID: String
    public let argumentConstraints: [ToolArgumentConstraint]

    public init(toolID: String, argumentConstraints: [ToolArgumentConstraint] = []) {
        self.toolID = toolID
        self.argumentConstraints = argumentConstraints
    }
}

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
