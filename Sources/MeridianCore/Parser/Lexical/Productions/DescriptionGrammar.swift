import Foundation

/// `description` (`GrammarTable`, `.pegex` shell): `[first N] [adjectives]
/// <plural kind> [whose … | that <verb clause> | <participle> by <operand>]
/// [sorted by <property> [ascending|descending]]`.
///
/// The fixed structure (determiners, `whose`/`that`/`sorted by`/`first N`) is
/// a marker-shape grammar; the noun/adjective head resolution against
/// `sym.kinds` (`splitAdjectivesAndNoun`) is a plain Swift closure over
/// symbol-table state, invoked as the shell's "kind" atom — dictionary lookups
/// aren't grammar. This hybrid shape is the plan's sanctioned `quantifier`/
/// `description` pattern.
///
/// Returns `nil` unless the head is a plural declared kind carrying at least
/// one restriction/adjective/sort/take (a bare plural kind with no
/// restriction is not a description — it falls through to an identifier).
struct DescriptionGrammar {
    let lexicon: EnglishLexicon
    let symbols: SymbolTable?
    let atom: (String) -> ExpressionAST
    /// Recurses the full grammar for `whose`/`sorted by` sub-expressions.
    let recurse: (String) -> ExpressionAST

    func parse(_ raw: String) -> DescriptionAST? {
        guard let sym = symbols else { return nil }
        var s = lexicon.stripLeadingArticle(raw)

        var take: Int?
        let leading = s.split(separator: " ").map(String.init)
        let first = lexicon.grammar.iterationMarkers.firstPrefix.trimmingCharacters(in: .whitespaces)
        if leading.count >= 2, leading[0].lowercased() == first, let n = Int(leading[1]) {
            take = n
            s = leading[2...].joined(separator: " ")
        }

        var sort: (property: String, ascending: Bool)?
        if let r = lexicon.sortByMarkers.lazy.compactMap({ QuoteAwareScanner.rangeOfMarker($0, in: s, caseInsensitive: true) }).first {
            var tail = String(s[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            var asc = true
            if let m = lexicon.descendingMarkers.first(where: { tail.lowercased().hasSuffix(" " + $0) }) {
                asc = false; tail = String(tail.dropLast((" " + m).count))
            } else if let m = lexicon.ascendingMarkers.first(where: { tail.lowercased().hasSuffix(" " + $0) }) {
                tail = String(tail.dropLast((" " + m).count))
            }
            sort = (property: tail.trimmingCharacters(in: .whitespaces).lowercased(), ascending: asc)
            s = String(s[s.startIndex..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        var wherePred: ExpressionAST?
        var verbClauses: [VerbClauseAST] = []
        var descPart = s

        if let wr = QuoteAwareScanner.rangeOfMarker(lexicon.grammar.iterationMarkers.whoseMarker, in: s, caseInsensitive: true) {
            descPart = String(s[s.startIndex..<wr.lowerBound]).trimmingCharacters(in: .whitespaces)
            wherePred = recurse(String(s[wr.upperBound...]))
        } else if let tr = lexicon.grammar.relativeClauseMarkers.lazy
            .compactMap({ QuoteAwareScanner.rangeOfMarker($0, in: s, caseInsensitive: true) }).first {
            descPart = String(s[s.startIndex..<tr.lowerBound]).trimmingCharacters(in: .whitespaces)
            guard let vc = parseThatClause(String(s[tr.upperBound...]), symbols: sym) else { return nil }
            verbClauses.append(vc)
        } else if let vc = parsePassiveClauseSuffix(&descPart, symbols: sym) {
            verbClauses.append(vc)
        }

        let (adjectives, noun) = splitAdjectivesAndNoun(descPart)
        guard !noun.isEmpty else { return nil }
        let singular = lexicon.singularize(noun.lowercased())
        guard sym.kinds[singular] != nil, noun.lowercased() != singular else { return nil }
        if wherePred == nil, verbClauses.isEmpty, adjectives.isEmpty, sort == nil, take == nil {
            return nil
        }
        return DescriptionAST(noun: noun, adjectives: adjectives, wherePredicate: wherePred,
                              verbClauses: verbClauses, sort: sort, take: take)
    }

    /// A description, or (failing that) a bare plural declared kind with no
    /// restriction (used as an aggregate/superlative source).
    func parseOrBare(_ inner: String) -> DescriptionAST? {
        if let d = parse(inner) { return d }
        guard let sym = symbols else { return nil }
        let s = lexicon.stripLeadingArticle(inner)
        let (adjectives, noun) = splitAdjectivesAndNoun(s)
        guard !noun.isEmpty else { return nil }
        let singular = lexicon.singularize(noun.lowercased())
        guard sym.kinds[singular] != nil else { return nil }
        return DescriptionAST(noun: noun, adjectives: adjectives)
    }

    /// 3B: a high-confidence "you meant a relation verb here" error. Fires ONLY
    /// when the text is unambiguously shaped like a passive relation clause —
    /// `<plural declared kind> <participle-looking word> by <operand>` — but the
    /// participle word names no declared verb.
    func undeclaredPassiveVerbError(_ raw: String) -> ExpressionAST? {
        guard let sym = symbols else { return nil }
        let s = lexicon.stripLeadingArticle(raw)
        guard let (hw, operand) = splitByClause(s) else { return nil }
        guard hw.count >= 2, !operand.isEmpty, let cand = hw.last?.lowercased() else { return nil }
        let looksParticiple = lexicon.grammar.pastParticipleSuffixes.contains { cand.hasSuffix($0) }
        guard looksParticiple, sym.resolveVerbForm(cand) == nil else { return nil }
        let noun = hw[hw.count - 2].lowercased()
        let singular = lexicon.singularize(noun)
        guard sym.kinds[singular] != nil, noun != singular else { return nil }
        let suggestion = sym.verbFormSuggestion(for: cand)
        return .malformed(
            "unknown relation verb \"\(cand)\". Declare it with `The verb to <base> (it <3rd>, it is \(cand)) means the <relation> relation.`",
            suggestion: suggestion)
    }

    /// Split `[adjectives] <kind plural>` into the raw adjective list and the
    /// head noun. Prefers the longest trailing run that resolves to a declared
    /// kind (singular form); falls back to the last word as the noun. Shared
    /// with `QuantifierGrammar`.
    func splitAdjectivesAndNoun(_ s: String) -> (adjectives: [String], noun: String) {
        let words = s.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return ([], "") }
        if let sym = symbols {
            for i in 0..<words.count {
                let candidate = words[i...].joined(separator: " ")
                if sym.kinds[lexicon.singularize(candidate)] != nil
                    || sym.kinds[candidate.lowercased()] != nil {
                    return (Array(words[0..<i]).map { $0.lowercased() }, candidate)
                }
            }
        }
        return (Array(words.dropLast()).map { $0.lowercased() }, words.last!)
    }

    /// Parse a `that …` relative clause into a verb clause. Subject-gap
    /// (`that mention the entity`) has the verb first; object-gap (`that the
    /// user owns`) has the verb last.
    private func parseThatClause(_ raw: String, symbols sym: SymbolTable) -> VerbClauseAST? {
        let words = raw.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        guard !words.isEmpty else { return nil }
        if let r = sym.resolveVerbForm(words[0].lowercased()), r.role != .pastParticiple {
            let operand = words[1...].joined(separator: " ")
            guard !operand.isEmpty else { return nil }
            return VerbClauseAST(verbForm: words[0].lowercased(), operand: atom(operand), elementIsSubject: true)
        }
        if words.count >= 2, let r = sym.resolveVerbForm(words.last!.lowercased()), r.role != .pastParticiple {
            let operand = words[0..<(words.count - 1)].joined(separator: " ")
            guard !operand.isEmpty else { return nil }
            return VerbClauseAST(verbForm: words.last!.lowercased(), operand: atom(operand), elementIsSubject: false)
        }
        return nil
    }

    /// Split a passive-clause fragment on the first top-level ` by ` marker
    /// (quote-aware). Shared prelude of `parsePassiveClauseSuffix` and
    /// `undeclaredPassiveVerbError`, which otherwise stay intentionally
    /// divergent (one requires the head's last word to resolve as a
    /// participle; the other requires it to NOT resolve).
    private func splitByClause(_ text: String) -> (head: [String], operand: String)? {
        guard let byR = QuoteAwareScanner.rangeOfMarker(lexicon.grammar.passiveByMarker, in: text, caseInsensitive: true) else { return nil }
        let head = String(text[text.startIndex..<byR.lowerBound]).trimmingCharacters(in: .whitespaces)
        let operand = String(text[byR.upperBound...]).trimmingCharacters(in: .whitespaces)
        return (head.split(separator: " ").map(String.init), operand)
    }

    /// Detect a trailing passive clause `<participle> by <operand>` on
    /// `descPart`, removing it and returning the verb clause (element = object).
    private func parsePassiveClauseSuffix(_ descPart: inout String, symbols sym: SymbolTable) -> VerbClauseAST? {
        guard let (hw, operand) = splitByClause(descPart) else { return nil }
        guard let last = hw.last,
              let r = sym.resolveVerbForm(last.lowercased()), r.role == .pastParticiple,
              !operand.isEmpty else { return nil }
        descPart = hw[0..<(hw.count - 1)].joined(separator: " ")
        return VerbClauseAST(verbForm: last.lowercased(), operand: atom(operand), elementIsSubject: false)
    }
}
