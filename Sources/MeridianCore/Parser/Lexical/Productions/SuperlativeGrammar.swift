import Foundation

/// `superlative` (`GrammarTable`, `.pegex`): `the <gradable> <desc> [by
/// <property>]`. Timestamp gradables (`oldest`/`newest`/`most recent`) default
/// to the lexicon's timestamp property; magnitude gradables (`smallest`/
/// `largest`) require an explicit `by <property>`.
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
                return .malformed("superlative `\(gradable)` needs a `by <property>` (e.g. `the \(gradable) \(desc.noun) by amount`).")
            }
            prop = p
        } else {
            prop = property ?? lexicon.timestampProperty
        }
        return .superlative(SuperlativeAST(description: desc, property: prop, ascending: dir.ascending))
    }
}
