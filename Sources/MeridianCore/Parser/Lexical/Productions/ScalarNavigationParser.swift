import Foundation

/// `scalar-navigation` (`GrammarTable`, `.hand-written`): `the <kind>
/// <participle> {to|by} <operand>` (`the task assigned to the user`).
///
/// Same reasoning as `ActiveVerbParser`: a dynamic scan over declared-verb
/// state, not a fixed grammar. The head must be a singular declared kind; a
/// plural head is a passive description clause, handled by
/// `DescriptionGrammar`.
struct ScalarNavigationParser {
    let lexicon: EnglishLexicon
    let symbols: SymbolTable?
    let atom: (String) -> ExpressionAST

    func parse(_ raw: String) -> ExpressionAST? {
        guard let sym = symbols else { return nil }
        let s = lexicon.stripLeadingArticle(raw)
        let words = s.split(separator: " ").map(String.init)
        guard words.count >= 4 else { return nil }
        for idx in 1..<(words.count - 1) {
            let w = words[idx].lowercased()
            guard let resolved = sym.resolveVerbForm(w), resolved.role == .pastParticiple else { continue }
            let conn = words[idx + 1].lowercased()
            guard lexicon.grammar.scalarNavConnectors.contains(conn) else { continue }
            let head = words[0..<idx].joined(separator: " ").lowercased()
            guard sym.kinds[head] != nil else { return nil }
            guard idx + 2 < words.count else { return nil }
            let operand = words[(idx + 2)...].joined(separator: " ")
            guard !operand.isEmpty else { return nil }
            return .relationTraversal(atom(operand), relation: w, navKind: head)
        }
        return nil
    }
}
