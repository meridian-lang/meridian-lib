import Foundation

/// Actor that stores and evaluates named permissions.
/// Permissions are keyed by their `actionDisplayName` (lowercased) and
/// evaluated in registration order. When no permissions are registered for
/// an action, the action is allowed by default.
public actor PermissionRegistry: Sendable {
    private var permissions: [String: [Permission]] = [:]
    private var toolPatterns: [String: [ToolPermissionPattern]] = [:]

    public static let empty = PermissionRegistry()

    public init() {}

    public func register(_ permission: Permission) {
        let key = permission.actionDisplayName.lowercased()
        permissions[key, default: []].append(permission)
    }

    public func register(toolPattern: ToolPermissionPattern) {
        let key = toolPattern.toolID.lowercased()
        toolPatterns[key, default: []].append(toolPattern)
    }

    public var hasToolPatterns: Bool {
        !toolPatterns.isEmpty
    }

    public func evaluate(action: String, scope: PermissionScope) -> Bool {
        let key = action.lowercased()
        guard let perms = permissions[key], !perms.isEmpty else {
            return true
        }
        return perms.contains { $0.evaluate(scope) }
    }

    /// When argument-conditioned patterns are registered for a tool, the
    /// proposed action must satisfy at least one pattern. Tools with no
    /// registered patterns pass through (bare `scopedTools` still applies).
    public func permitsPlannedAction(_ action: ProposedAction) -> Bool {
        let key = action.toolID.lowercased()
        guard let patterns = toolPatterns[key], !patterns.isEmpty else {
            return true
        }
        return patterns.contains { pattern in
            pattern.argumentConstraints.allSatisfy { constraint in
                guard let actual = action.arguments[constraint.path] else { return false }
                return actual == constraint.expected
            }
        }
    }
}
