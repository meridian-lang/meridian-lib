import Foundation

/// Actor that stores and evaluates named permissions.
/// Permissions are keyed by their `actionDisplayName` (lowercased) and
/// evaluated in registration order. When no permissions are registered for
/// an action, the action is allowed by default.
public actor PermissionRegistry: Sendable {
    private var permissions: [String: [Permission]] = [:]

    public static let empty = PermissionRegistry()

    public init() {}

    public func register(_ permission: Permission) {
        let key = permission.actionDisplayName.lowercased()
        permissions[key, default: []].append(permission)
    }

    public func evaluate(action: String, scope: PermissionScope) -> Bool {
        let key = action.lowercased()
        guard let perms = permissions[key], !perms.isEmpty else {
            return true
        }
        return perms.contains { $0.evaluate(scope) }
    }
}
