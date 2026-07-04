import Foundation

/// `possessive-chain` (`GrammarTable`, `.hand-written`): `the order's id`,
/// `the customer's account manager's email`.
///
/// A trivial `'s`-split + base-identifier resolution. Simple enough that
/// forcing a grammar buys nothing; carries a documented sharp edge (AGENTS.md
/// §6.3 — possessive recognition without a leading article, e.g. `order's id`
/// after argument-substitution strips the article) which this preserves
/// exactly: the caller decides *whether* to route text here (on an article
/// prefix, a `'s ` occurrence, or a trailing `'s`), not this parser.
struct PossessiveChainParser {
    let lexicon: EnglishLexicon
    let symbols: SymbolTable?

    func parse(_ s: String) -> ExpressionAST {
        let stripped = lexicon.stripLeadingArticle(s)
        let parts = stripped.components(separatedBy: "'s")

        let base = parts[0].trimmingCharacters(in: .whitespaces)
        var expr = resolveBase(base)
        for part in parts.dropFirst() {
            let prop = part.trimmingCharacters(in: .whitespaces)
            if !prop.isEmpty {
                expr = .propertyAccess(expr, prop)
            }
        }
        return expr
    }

    private func resolveBase(_ name: String) -> ExpressionAST {
        if let sym = symbols {
            if sym.instances[name] != nil { return .instanceRef(name) }
            if sym.constants[name] != nil { return .constantRef(name) }
        }
        return .identifierRef(name)
    }
}
