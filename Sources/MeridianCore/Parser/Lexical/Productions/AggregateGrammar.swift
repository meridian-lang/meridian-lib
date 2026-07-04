import Foundation

/// `aggregate` (`GrammarTable`, `.pegex`): `the number of <desc>` / `the count
/// of <desc>` / `the list of <desc>`. Requires a symbol table (the inner
/// description resolves a declared kind).
struct AggregateGrammar {
    let lexicon: EnglishLexicon
    let description: DescriptionGrammar

    func parse(_ raw: String) -> ExpressionAST? {
        let s = lexicon.stripLeadingArticle(raw)
        for (kw, kind) in lexicon.aggregateIntroducers where s.lowercased().hasPrefix(kw) {
            let inner = String(s.dropFirst(kw.count)).trimmingCharacters(in: .whitespaces)
            guard let desc = description.parseOrBare(inner) else { return nil }
            return .aggregate(kind, desc)
        }
        return nil
    }
}
