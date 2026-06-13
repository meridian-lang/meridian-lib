import Foundation

/// Names of compile-time fallbacks the user can opt into via the
/// `.meridian` frontmatter `allow-fallbacks:` key. By default every kind
/// is treated as a hard error: the compiler refuses to silently substitute
/// a placeholder when something cannot be resolved.
public enum FallbackKind: String, Sendable, CaseIterable, Hashable {
    /// A phrase invocation that does not match any phrase or workflow.
    /// When allowed, an `_unresolved` BindIR placeholder is emitted instead
    /// of throwing.
    case unresolvedPhrases = "unresolved-phrases"

    /// A `RuleAST` whose text the `RuleAnalyzer` could not classify into one
    /// of `invariant`, `parameterGuard`, `precondition`, `trigger`, or
    /// `permission`. When allowed, the rule is dropped from IR (it still
    /// appears in the manifest).
    case unparseableRules = "unparseable-rules"

    /// A `RuleAST` that parsed cleanly but did not match any workflow's
    /// action surface (e.g. a `must not` rule whose verb doesn't appear in
    /// any workflow name or parameter kind). When allowed, the rule is
    /// dropped (still in manifest).
    case unattachedRules = "unattached-rules"

    /// A `When … , do X` trigger whose action text does not lower to any
    /// real phrase invocation. When allowed, the trigger workflow body
    /// records a documenting BindIR comment instead of executing.
    case unresolvedTriggerActions = "unresolved-trigger-actions"

    /// An `invoke` whose tool ID matches no built-in, vocabulary `=== tools
    /// ===` declaration, frontmatter `tools:` scoped tool, or workflow
    /// reference. When allowed, the unrecognized tool ID is emitted as-is
    /// (for host-provided tools registered only at runtime).
    case unknownTools = "unknown-tools"
}

/// What a Meridian file allows to silently fall back. Constructed from the
/// frontmatter `allow-fallbacks:` key (comma-separated list of kinds) and
/// the `Compiler.Options.allowedFallbacks` test escape hatch.
public struct FallbackPolicy: Sendable {
    public let allowed: Set<FallbackKind>

    public init(allowed: Set<FallbackKind> = []) {
        self.allowed = allowed
    }

    /// Strict policy — every fallback raises a hard error. Default.
    public static let strict = FallbackPolicy(allowed: [])

    /// Lenient policy — every fallback is allowed. Useful for early authoring
    /// or test fixtures with intentional gaps.
    public static let lenient = FallbackPolicy(allowed: Set(FallbackKind.allCases))

    public func allows(_ kind: FallbackKind) -> Bool { allowed.contains(kind) }

    /// Build a policy from a frontmatter `allow-fallbacks` value (a
    /// comma-separated list, e.g. `"unresolved-phrases, unattached-rules"`).
    /// Unknown tokens are reported via `unknown` so callers can surface a
    /// diagnostic.
    public static func parse(_ value: String) -> (policy: FallbackPolicy, unknown: [String]) {
        var allowed: Set<FallbackKind> = []
        var unknown: [String] = []
        for raw in value.split(separator: ",") {
            let token = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if token.isEmpty { continue }
            if token == "all" || token == "*" || token == "lenient" {
                allowed = Set(FallbackKind.allCases)
                continue
            }
            if let kind = FallbackKind(rawValue: token) {
                allowed.insert(kind)
            } else {
                unknown.append(token)
            }
        }
        return (FallbackPolicy(allowed: allowed), unknown)
    }

    /// Merge two policies — the resulting policy allows a fallback if either
    /// of the inputs does.
    public func merging(_ other: FallbackPolicy) -> FallbackPolicy {
        FallbackPolicy(allowed: allowed.union(other.allowed))
    }
}
