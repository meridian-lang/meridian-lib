import Foundation

/// `superlative` (`GrammarTable`, `.pegex`): `the <gradable> <desc> [by
/// <property>]`. Timestamp gradables (`oldest`/`newest`/`most recent`) default
/// to the lexicon's timestamp property; magnitude gradables (`smallest`/
/// `largest`) require an explicit `by <property>`.
///
/// When a checkable adjective is declared in `=== language ===`
/// `Gradable adjectives:`, `the most <adj> <kind>` / `the least <adj> <kind>`
/// infer the sort property without `by <property>`.
///
/// Gradables are tried longest-first (`lexicon.superlativeGradables.keys`,
/// ties broken alphabetically) so `most recent` matches before a hypothetical
/// shorter prefix. Requires a symbol table.
struct SuperlativeGrammar {
    let lexicon: EnglishLexicon
    let symbols: SymbolTable?
    let description: DescriptionGrammar

    func parse(_ raw: String) -> ExpressionAST? {
        guard symbols != nil else { return nil }
        let s = lexicon.stripLeadingArticle(raw)
        if let gradableAdj = parseGradableAdjectiveSuperlative(s) { return gradableAdj }

        let lower = s.lowercased()
        let gradables = lexicon.superlativeGradables.keys.sorted {
            $0.count == $1.count ? $0 < $1 : $0.count > $1.count
        }
        guard let gradable = gradables.first(where: { lower == $0 || lower.hasPrefix($0 + " ") }) else {
            return nil
        }
        let restStart = s.index(s.startIndex, offsetBy: gradable.count)
        var rest = String(s[restStart...]).trimmingCharacters(in: .whitespaces)
        guard let dir = lexicon.superlativeGradables[gradable.lowercased()] else { return nil }

        var property: String?
        if let r = QuoteAwareScanner.rangeOfMarker(lexicon.grammar.passiveByMarker, in: rest, caseInsensitive: true) {
            property = String(rest[r.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()
            rest = String(rest[rest.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        guard let desc = description.parseOrBare(rest) else { return nil }
        let prop: String
        if dir.needsBy {
            guard let p = property else {
                return .malformed(
                    "superlative `\(gradable)` needs a `by <property>` (e.g. `the \(gradable) \(desc.noun) by amount`), or declare the adjective under `Gradable adjectives:` in `=== language ===`.",
                    code: .descriptionSuperlativeNeedsProperty,
                    help: "Add `by <property>` or declare a measurable backing for the adjective.")
            }
            prop = p
        } else {
            prop = property ?? lexicon.timestampProperty
        }
        return .superlative(SuperlativeAST(description: desc, property: prop, ascending: dir.ascending))
    }

    /// `the most <declared-gradable-adj> <kind>` / `the least …` using metadata
    /// from `=== language ===` `Gradable adjectives:`.
    private func parseGradableAdjectiveSuperlative(_ text: String) -> ExpressionAST? {
        let lower = text.lowercased()
        let least: Bool
        let rest: String
        if lower.hasPrefix("most ") {
            least = false
            rest = String(text.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        } else if lower.hasPrefix("least ") {
            least = true
            rest = String(text.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else {
            return nil
        }
        guard let desc = description.parseOrBare(rest),
              let adj = desc.adjectives.first?.lowercased(),
              desc.adjectives.count == 1,
              let meta = lexicon.gradableAdjectives[adj] else {
            return nil
        }
        let ascending = least ? !meta.ascending : meta.ascending
        return .superlative(SuperlativeAST(description: desc, property: meta.property, ascending: ascending))
    }
}
