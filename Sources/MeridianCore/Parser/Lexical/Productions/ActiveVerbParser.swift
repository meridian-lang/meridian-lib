import Foundation

/// `active-verb` (`GrammarTable`, `.hand-written`): `<subject> <verb> <object>`
/// (`the user owns the page`).
///
/// A dynamic scan over declared-verb state, not a fixed grammar: verbs are
/// domain-declared (`sym.resolveVerbForm`), so there is no closed keyword set
/// to build a `pegex` production from. Splits on the earliest non-initial word
/// that is an active (third-person / base) form of a declared verb; past
/// participles are skipped (they're passive description clauses, handled by
/// `DescriptionGrammar`, not active predicates).
struct ActiveVerbParser {
    let lexicon: EnglishLexicon
    let symbols: SymbolTable?
    let atom: (String) -> ExpressionAST

    func parse(_ s: String) -> ExpressionAST? {
        guard let sym = symbols, !sym.verbs.isEmpty else { return nil }
        guard !s.contains("\"") else { return nil }
        let words = s.split(separator: " ").map(String.init)
        guard words.count >= 3 else { return nil }
        let relativizers = lexicon.grammar.relativizers
        // Do-support auxiliaries that carry the negation in front of a base verb
        // (`the entity does not link …`); contractions fuse the negator (`doesn't`).
        let auxiliaries = lexicon.grammar.negationAuxiliaries
        let negContractions = lexicon.grammar.negationContractions
        for idx in 1..<(words.count - 1) {
            let w = words[idx].lowercased()
            guard let resolved = sym.resolveVerbForm(w), resolved.role != .pastParticiple else { continue }
            // A verb immediately preceded by a relativizer is a relative-clause
            // predicate inside a description (`pages that mention …`), not a
            // top-level active-verb condition. Let the atom/description
            // productions own it.
            if relativizers.contains(words[idx - 1].lowercased()) { continue }
            var subjectEnd = idx
            var negated = false
            let prev = words[idx - 1].lowercased()
            let notKeyword = lexicon.grammar.booleanConnectors.notPrefix.trimmingCharacters(in: .whitespaces)
            if prev == notKeyword, idx >= 2, auxiliaries.contains(words[idx - 2].lowercased()) {
                subjectEnd = idx - 2
                negated = true
            } else if negContractions.contains(prev) {
                subjectEnd = idx - 1
                negated = true
            }
            let subject = words[0..<subjectEnd].joined(separator: " ")
            let object = stripLeadingPreposition(words[(idx + 1)...].joined(separator: " "))
            guard !subject.isEmpty, !object.isEmpty else { continue }
            let predicate: ExpressionAST = .verbPredicate(subject: atom(subject), verb: w, object: atom(object))
            return negated ? .logical(.not, [predicate]) : predicate
        }
        return nil
    }

    /// Strip a single leading preposition token (`link to the input` → `the
    /// input`). Verbs that govern a preposition (`link to`, `report to`) carry
    /// it between verb and object; objects of bare-transitive verbs are
    /// unaffected.
    private func stripLeadingPreposition(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard let first = t.split(separator: " ").first.map({ String($0).lowercased() }),
              lexicon.prepositions.contains(first) else { return t }
        return String(t.dropFirst(first.count)).trimmingCharacters(in: .whitespaces)
    }
}
