import Foundation

// MARK: - ExpressionParser
//
// Parses a single-line expression string into ExpressionAST.
// Called from MerConfigParser and MeridianParser when an expression is needed.
//
// A thin orchestrator: it holds `symbols`/`trace`/`lexicon` and dispatches to
// one independent unit per `GrammarTable` production — each either a real
// `pegex` grammar (`Productions/*Grammar.swift`) or a dedicated hand-written
// Swift function (`Productions/*Parser.swift`), chosen per-production for
// whichever is clearer (see `IMPLEMENTATION_LOG.md`, "Per-production
// expression grammar"). There is no alternate fallback or rollout flag — this
// is the only expression-parsing implementation.
//
// Dispatch is NESTED, not a flat list of alternatives — this is the one
// structural detail that matters for combined expressions. `parse(_:)` is the
// `boolean` production (not/either/and/or, `it is not the case that …`).
// `boolean`'s fundamental atom, tried at *every* leaf position it recurses to
// (the top of the expression, an `either`'s body, each and/or operand), is
// `parseClause`: quantifier → emptiness/temporal-window → active-verb →
// comparison → atom, in that order. `parseClause`'s final fallback,
// `parseAtom`, tries literal → table-lookup → (with symbols) aggregate →
// superlative → scalar-navigation → description → undeclared-passive-verb
// error → possessive-chain → bare identifier, in that order. So a bare
// quantifier/description/etc. with no `and`/`or` in it still flows through
// the same `parseClause` step as a combined `A and B` expression's operands —
// there is no separate top-level branch for the uncombined case.
public struct ExpressionParser {

    public let symbols: SymbolTable?
    public let trace: ParserTrace
    private let lexicon: EnglishLexicon
    private let screen: NonterminalScreen
    /// Benchmarking-only escape hatch (`ParserBenchmark`'s unscreened arm).
    /// Always `true` in every production call site; when `false`, `isEligible`
    /// always returns true so every `clause`/`atom` alternative is tried
    /// unconditionally, measuring the cost `NonterminalScreen` saves.
    private let useScreen: Bool

    public init(symbols: SymbolTable? = nil, trace: ParserTrace = .shared, lexicon: EnglishLexicon = .default) {
        self.init(symbols: symbols, trace: trace, lexicon: lexicon, useScreen: true)
    }

    init(symbols: SymbolTable?, trace: ParserTrace, lexicon: EnglishLexicon, useScreen: Bool) {
        self.symbols = symbols
        self.trace = trace
        self.lexicon = lexicon
        self.screen = NonterminalScreen(table: PegexSurfaceGrammar(lexicon: lexicon).table)
        self.useScreen = useScreen
    }

    public func parse(_ raw: String) -> ExpressionAST {
        let s = raw.trimmingCharacters(in: .whitespaces)
        trace.log(.expression, "parse.start(\"\(s)\")")
        let result = BooleanGrammar(lexicon: lexicon, recurse: parse, clause: parseClause).parse(s)
        trace.log(.expression, "parse(\"\(s)\") → \(result.traceDescription(detail: .verbose))")
        return result
    }

    // MARK: - Clause (boolean's leaf atom)

    /// quantifier → emptiness/temporal-window → active-verb → comparison →
    /// atom, in that order (mirrors the pre-rewrite `parseComparison` order).
    ///
    /// `quantifier` and `comparison` are gated by `NonterminalScreen` as a
    /// live pre-filter — their anchor vocabularies (quantifier determiners;
    /// comparison markers) are closed, lexicon-derived keyword sets that fully
    /// cover what each production actually matches on, so skipping the call
    /// when no anchor is present is provably equivalent to calling it and
    /// getting `nil`, just faster. `emptiness`/`temporal-window`/`active-verb`
    /// are NOT screened: `active-verb`'s trigger set is the domain's declared
    /// verbs (open-ended, not a lexicon table), and screening either of the
    /// other two on their current anchor lists would be unsafe without a
    /// wider anchor audit (e.g. emptiness's bare `is empty`/`is not empty`
    /// suffix forms) — always trying them is strictly no less correct than
    /// the pre-rewrite parser, just without the (currently unverified) speedup.
    private func parseClause(_ raw: String) -> ExpressionAST {
        let t = raw.trimmingCharacters(in: .whitespaces)

        if isEligible("quantifier", for: t),
           let q = QuantifierGrammar(lexicon: lexicon, description: descriptionGrammar, recurse: parse).parse(t) {
            trace.log(.expression, "clause(\"\(t)\") → quantifier")
            return q
        }
        if let e = EmptinessTemporalGrammar(lexicon: lexicon, atom: parseAtom).parse(t) {
            trace.log(.expression, "clause(\"\(t)\") → emptiness/temporal-window")
            return e
        }
        if let v = ActiveVerbParser(lexicon: lexicon, symbols: symbols, atom: parseAtom).parse(t) {
            trace.log(.expression, "clause(\"\(t)\") → active-verb")
            return v
        }
        if isEligible("comparison", for: t),
           let c = ComparisonGrammar(lexicon: lexicon, atom: parseAtom).parse(t) {
            trace.log(.expression, "clause(\"\(t)\") → comparison")
            return c
        }
        trace.log(.expression, "clause(\"\(t)\") → atom (no clause production matched)")
        return parseAtom(t)
    }

    // MARK: - Atom
    //
    // Module-internal (not private): `StatementParser` calls this directly at
    // 3 call sites for code-block-sentinel handling.

    /// literal → table-lookup → (with symbols) aggregate → superlative →
    /// scalar-navigation → description → undeclared-passive-verb error →
    /// possessive-chain → bare identifier, in that order (mirrors the
    /// pre-rewrite `parseAtom` order). `aggregate`/`superlative` are screened for the same
    /// reason `comparison` is above (closed, lexicon-derived introducer/
    /// gradable vocabularies); `scalar-navigation`/`description`/
    /// `possessive-chain` are not (dynamic symbol-table dependence or
    /// deliberately unconditional per AGENTS.md's possessive-without-article
    /// sharp edge).
    func parseAtom(_ s: String) -> ExpressionAST {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty {
            trace.log(.expression, "atom(\"\") → malformed (empty expression)")
            return .malformed("empty expression")
        }

        // B6/B7: Fenced code-block sentinel — decode base64 body, then parse
        // for `{{ expr }}` / `[if]` / `[for each]` interpolation markers.
        if t.hasPrefix(codeBlockSentinelPrefix) {
            if let (_, body) = decodeCodeBlockSentinel(t) {
                let lowerBody = body.lowercased()
                if body.contains("{{")
                    || lowerBody.contains(lexicon.grammar.templateDirectives.ifPrefix)
                    || lowerBody.contains(lexicon.grammar.templateDirectives.forEachPrefix) {
                    let segs = TemplateInterpolationParser(lexicon: lexicon, recurse: parse).parseSegments(body)
                    // Collapse a single literal-only segment to a plain string literal.
                    if segs.count == 1, case .literal(let plain) = segs[0] {
                        return .literal(.string(plain))
                    }
                    return .interpolatedString(segs)
                }
                return .literal(.string(body))
            }
            trace.log(.expression, "atom(codeblock) → malformed (corrupt sentinel)")
            return .malformed("corrupt or truncated code-block sentinel")
        }

        if let lit = LiteralGrammar(lexicon: lexicon).parse(t) {
            trace.log(.expression, "atom(\"\(t)\") → literal")
            return lit
        }
        if let lookup = TableLookupGrammar(lexicon: lexicon, recurse: parse).parse(t) {
            trace.log(.expression, "atom(\"\(t)\") → table-lookup")
            return lookup
        }

        // 3C: relational value atoms (need the symbol table to resolve kinds /
        // verbs). A bare plural kind with no restriction is NOT a description
        // and falls through to an identifier.
        if symbols != nil {
            if isEligible("aggregate", for: t),
               let agg = AggregateGrammar(lexicon: lexicon, description: descriptionGrammar).parse(t) {
                trace.log(.expression, "atom(\"\(t)\") → aggregate")
                return agg
            }
            if isEligible("superlative", for: t),
               let sup = SuperlativeGrammar(lexicon: lexicon, symbols: symbols, description: descriptionGrammar).parse(t) {
                trace.log(.expression, "atom(\"\(t)\") → superlative")
                return sup
            }
            if let nav = ScalarNavigationParser(lexicon: lexicon, symbols: symbols, atom: parseAtom).parse(t) {
                trace.log(.expression, "atom(\"\(t)\") → scalar-navigation")
                return nav
            }
            if let desc = descriptionGrammar.parse(t) {
                trace.log(.expression, "atom(\"\(t)\") → description")
                return .description(desc)
            }
            if let bad = descriptionGrammar.undeclaredPassiveVerbError(t) {
                trace.log(.expression, "atom(\"\(t)\") → undeclared-passive-verb error")
                return bad
            }
        }

        // possessive chain: "the customer's account manager's email" — also
        // handles bare possessives like "order's id" (after text substitution
        // strips the leading article). AGENTS.md #3: must be detected even
        // without a leading article.
        let hasArticlePrefix = lexicon.articles.sorted(by: { $0.count > $1.count })
            .contains { t.lowercased().hasPrefix($0 + " ") }
        if hasArticlePrefix || t.contains("'s ") || t.hasSuffix("'s") {
            trace.log(.expression, "atom(\"\(t)\") → possessive-chain")
            return PossessiveChainParser(lexicon: lexicon, symbols: symbols).parse(t)
        }

        // bare identifier / enum value (e.g. "invalid", "denied", "succeeded")
        trace.log(.expression, "atom(\"\(t)\") → bare identifier")
        return .identifierRef(t)
    }

    /// Thin forward to the `template-conditional`/`template-loop`/
    /// `template-formatter` production, exposed on `ExpressionParser` itself
    /// (rather than only reachable via `parseAtom`'s code-block-sentinel path)
    /// because it is exercised directly by `Inform7Wave4Tests`/
    /// `Phase6B6B7Tests` against a raw (non-sentinel-wrapped) body string.
    func parseInterpolationSegments(_ body: String) -> [InterpolationSegment] {
        TemplateInterpolationParser(lexicon: lexicon, recurse: parse).parseSegments(body)
    }

    // MARK: - Shared production wiring

    private var descriptionGrammar: DescriptionGrammar {
        DescriptionGrammar(lexicon: lexicon, symbols: symbols, atom: parseAtom, recurse: parse)
    }

    private func isEligible(_ productionName: String, for text: String) -> Bool {
        guard useScreen else { return true }
        let admitted = screen.candidates(for: text).contains { $0.name == productionName }
        trace.log(.expression,
                  "screen(\"\(productionName)\", \"\(text)\") → \(admitted ? "admitted" : "skipped (no anchor match)")")
        return admitted
    }
}
