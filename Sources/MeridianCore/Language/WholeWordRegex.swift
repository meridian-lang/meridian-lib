import Foundation

/// Whole-word, case-insensitive regex utilities.
///
/// The `\b<needle>\b` pattern — built from an *escaped literal* needle and used
/// for token-safe substitution and membership checks — was copy-pasted across
/// the lowerer (`ASTToIR.wholeWordReplace`), the definition parser, the anaphora
/// resolver, and the linter. This collapses them into one place (house
/// single-source rule) and, just as importantly, collapses the duplicated
/// "impossible compile failure" guard into a single line.
///
/// Because the pattern always comes from `NSRegularExpression.escapedPattern`,
/// it is always a valid regex; the compile can only fail on a Foundation bug,
/// never on caller input. That `else` is therefore genuinely unreachable and is
/// the codebase's single sanctioned "can't happen" precondition for this
/// construct (it cannot be deleted — Swift forces the `try?` branch and `!` is
/// banned by the house rules — so it is documented as a permanent coverage
/// exception in `docs/coverage/coverage-exclusions.md`).
enum WholeWordRegex {

    /// Compile the whole-word, case-insensitive matcher for `needle`. Returns
    /// nil for an empty needle (callers treat that as a no-op).
    private static func compiled(_ needle: String) -> NSRegularExpression? {
        guard !needle.isEmpty else { return nil }
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: needle))\\b"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            preconditionFailure("internal: constant whole-word regex failed to compile: \(pattern)")
        }
        return re
    }

    /// Replace every whole-word, case-insensitive occurrence of `needle` with
    /// `replacement`. The replacement is escaped, so `$`/`\` in it are treated
    /// literally (never as template back-references). Empty needle → unchanged.
    static func replace(_ haystack: String, of needle: String, with replacement: String) -> String {
        guard let re = compiled(needle) else { return haystack }
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        return re.stringByReplacingMatches(
            in: haystack, options: [], range: range,
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement))
    }

    /// Whether `needle` appears as a whole word (case-insensitive) in `haystack`.
    /// Empty needle → false.
    static func contains(_ needle: String, in haystack: String) -> Bool {
        guard let re = compiled(needle) else { return false }
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        return re.firstMatch(in: haystack, options: [], range: range) != nil
    }
}
