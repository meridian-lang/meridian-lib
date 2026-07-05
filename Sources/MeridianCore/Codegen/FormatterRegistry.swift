import Foundation

/// B7: the closed set of `{{ expr as a <formatter> }}` template formatters —
/// the single source of truth for both compile-time validation (`ASTToIR`,
/// `RuleInjector`) and codegen (`SwiftEmitter.meridianFormat`, which must stay
/// in lockstep with `isValid`/`available`). These are fixed technical
/// identifiers analogous to comparison operators, not English-surface
/// vocabulary, so they are not routed through `EnglishLexicon`/`=== language
/// ===` (AGENTS.md "no hardcoded English-surface vocabulary" governs surface
/// synonyms an author might rename, not a closed formatter-name syntax).
public enum FormatterRegistry {
    /// Fixed (non-parametric) formatter names, lowercase.
    public static let fixedNames: [String] = ["integer", "short date", "long date"]

    /// Parametric formatter: `decimal(<N>)` for a fixed fraction-digit count.
    private static let decimalPrefix = "decimal("
    private static let decimalSuffix = ")"

    /// Every formatter name for diagnostics/docs — the fixed names plus a
    /// canonical placeholder for the parametric one.
    public static let available: [String] = fixedNames + ["decimal(N)"]

    /// Whether `formatter` (as written, case-insensitive) names a real
    /// formatter — either one of `fixedNames` or `decimal(<integer>)`.
    public static func isValid(_ formatter: String) -> Bool {
        let f = formatter.lowercased()
        if fixedNames.contains(f) { return true }
        guard f.hasPrefix(decimalPrefix), f.hasSuffix(decimalSuffix) else { return false }
        let inner = f.dropFirst(decimalPrefix.count).dropLast(decimalSuffix.count)
        return Int(inner) != nil
    }
}
