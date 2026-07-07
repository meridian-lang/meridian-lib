import Foundation
import Testing
@testable import MeridianCore

@Suite("Per-production expression grammar — branch coverage")
struct ProductionGrammarBranchCoverageTests {
    private static let config = """
    === vocabulary ===
    A user is a kind of thing.
    A user has a name, which is a String.
    A page is a kind of thing.
    A page has an owner, which is a String.
    A page has a summary, which is a String.
    A page has a status, which is a String.
    A task is a kind of thing.
    A task has an assignee, which is a String.
    A foo task is a kind of thing.
    A deal is a kind of thing.
    A deal has an amount, which is Number.
    Ownership relates one user to various pages.
    Ownership is read from the page's owner.
    The verb to own (it owns, it is owned) means the ownership relation.
    Assignment relates one task to one user.
    Assignment is read from the task's assignee.
    The verb to assign (it assigns, it is assigned) means the assignment relation.

    === constants ===
    The default currency is "USD".

    === instances ===
    There is a user called primary with name = "Hari"
    """

    private func symbols() throws -> SymbolTable {
        let cfg = try MerConfigParser(trace: .silent()).parse(Self.config, file: "branch.merconfig")
        return SymbolTable.build(from: cfg)
    }

    private func parser(_ symbols: SymbolTable? = nil) -> ExpressionParser {
        ExpressionParser(symbols: symbols, trace: .silent())
    }

    private func atom(_ text: String) -> ExpressionAST {
        ExpressionParser(trace: .silent()).parseAtom(text)
    }

    private func descriptionGrammar(_ symbols: SymbolTable?) -> DescriptionGrammar {
        DescriptionGrammar(lexicon: .default, symbols: symbols, atom: atom, recurse: parser(symbols).parse)
    }

    private func sentinel(_ body: String, lang: String = "plain") -> String {
        codeBlockSentinelPrefix + lang + ":" + Data(body.utf8).base64EncodedString()
    }

    @Test("boolean either-prefix branches are all explicit")
    func booleanEitherBranches() {
        let p = parser()

        #expect(p.parse("it is not the case that a is 1").traceDescription(detail: .verbose).contains("logical(not"))
        #expect(p.parse("a is 1 or either b is 2 or c is 3").traceDescription(detail: .verbose).contains("logical(or"))
        #expect(p.parse("a is 1 or d is 4 or either b is 2 or c is 3").traceDescription(detail: .verbose).contains("logical(or"))
        #expect(p.parse("a is 1 either b is 2 or c is 3").traceDescription(detail: .verbose).contains("logical(and"))
        #expect(p.parse("either a is 1").traceDescription(detail: .verbose) == "(id(a) equal 1)")
        #expect(p.parse("a is 1 and b is 2 or either c is 3 or d is 4").traceDescription(detail: .verbose).contains("malformed("))
        #expect(!p.parse("neither either a is 1 or b is 2").traceDescription(detail: .verbose).isEmpty)
        #expect(!p.parse("xeither either a is 1 or b is 2").traceDescription(detail: .verbose).isEmpty)

        // stripTrailingConnector's non-suffix branch: "and" appears at the top
        // level of the prefix but not at its trailing edge.
        #expect(p.parse("a is 1 and b is 2 either c is 3 or d is 4")
            .traceDescription(detail: .verbose).contains("logical(and") == true)
        // combineAnd's flattening branch: the recursively-parsed prefix is
        // already a `.logical(.and, …)`, so joining the either-clause must
        // append to it rather than nest a new pair.
        let flattened = p.parse("a is 1 and b is 2 and either c is 3 or d is 4").traceDescription(detail: .verbose)
        #expect(flattened.components(separatedBy: "logical(and").count == 2, Comment(rawValue: flattened))
    }

    @Test("literal keyword validation covers false branches")
    func literalAndComparisonKeywordBranches() {
        let p = parser()

        #expect(p.parse("nowish").traceDescription(detail: .verbose) == "id(nowish)")
        #expect(p.parse("true story").traceDescription(detail: .verbose) == "id(true story)")

        let lexicon = EnglishLexicon.default.merging(
            comparisonSynonyms: [("x-y", .equal)],
            durationSynonyms: [:]
        )
        let comparison = ComparisonGrammar(lexicon: lexicon, atom: atom)
        #expect(comparison.parse("a x-y b")?.traceDescription(detail: .verbose) == "(id(a) equal id(b))")
    }

    @Test("table lookup guard branches reject malformed shapes")
    func tableLookupGuardBranches() {
        let lookup = TableLookupGrammar(lexicon: .default, recurse: parser().parse)

        #expect(lookup.parse("price corresponding to the sku \"SKU\" in the table") == nil)
        #expect(lookup.parse("the corresponding to the sku \"SKU\" in the table") == nil)
        #expect(lookup.parse("the price corresponding to the \"SKU\" in the table") == nil)
        #expect(lookup.parse("the price corresponding to sku in the table") == nil)
        // Nothing between "corresponding to the" and "in the" — empty key phrase.
        #expect(lookup.parse("the price corresponding to the in the table") == nil)
        // Nothing after "in the" — empty table name.
        #expect(lookup.parse("the price corresponding to the sku \"SKU\" in the ") == nil)
        // Unquoted single-word key — splitKeyPhrase's no-quote branch with count <= 1,
        // yielding an empty key column, rejected by the keyColumn/keyText guard.
        #expect(lookup.parse("the price corresponding to the sku in the table") == nil)
        // Unquoted multi-word key — splitKeyPhrase's no-quote branch takes the
        // last word as the key and the rest as the column name.
        let unquoted = lookup.parse("the price corresponding to the order id 42 in the orders table")
        guard case .tableLookup(let table, let keyColumn, _, let valueColumn) = unquoted else {
            Issue.record("expected a tableLookup AST for an unquoted multi-word key")
            return
        }
        #expect(table == "orders table")
        #expect(keyColumn == "order id")
        #expect(valueColumn == "price")
    }

    @Test("aggregate and superlative malformed branches")
    func aggregateAndSuperlativeBranches() throws {
        let symbols = try symbols()
        let desc = descriptionGrammar(symbols)

        #expect(AggregateGrammar(lexicon: .default, description: desc).parse("the number of widgets") == nil)
        #expect(SuperlativeGrammar(lexicon: .default, symbols: nil, description: desc).parse("the largest deal by amount") == nil)
        #expect(SuperlativeGrammar(lexicon: .default, symbols: symbols, description: desc).parse("the median deal") == nil)
        #expect(SuperlativeGrammar(lexicon: .default, symbols: symbols, description: desc)
            .parse("the largest deal")?.traceDescription(detail: .verbose).contains("malformed(") == true)
    }

    @Test("emptiness and temporal guard branches")
    func emptinessTemporalBranches() {
        let grammar = EmptinessTemporalGrammar(lexicon: .default, atom: atom)

        #expect(grammar.parse("updated within the last 1 day")?.traceDescription(detail: .verbose).contains("updatedAt") == true)
        #expect(grammar.parse("deadline within the last 1") == nil)
        #expect(grammar.parse("deadline within the last many days") == nil)

        // "<subject> is not within the last N <unit>" negates the whole
        // window comparison instead of misparsing "<subject> is not" as a
        // literal property name (the pre-fix behavior).
        guard case .logical(.not, let negated) = grammar.parse("rotated at is not within the last 90 days") else {
            Issue.record("expected a negated temporal-window comparison"); return
        }
        guard case .comparison(let lhs, .withinPast, _) = negated.first else {
            Issue.record("expected the negated clause to wrap a withinPast comparison"); return
        }
        #expect(lhs.traceDescription(detail: .verbose).contains("rotated at") == true)
    }

    @Test("quantifier malformed determiner and body branches")
    func quantifierBranches() throws {
        let symbols = try symbols()
        let grammar = QuantifierGrammar(
            lexicon: .default,
            description: descriptionGrammar(symbols),
            recurse: parser(symbols).parse
        )

        #expect(grammar.parse("all ")?.traceDescription(detail: .verbose).contains("malformed(") == true)
        #expect(grammar.parse("all whose")?.traceDescription(detail: .verbose).contains("malformed(") == true)
        #expect(grammar.parse("all whose status is draft")?.traceDescription(detail: .verbose).contains("malformed(") == true)
        #expect(grammar.parse("all pages whose")?.traceDescription(detail: .verbose).contains("malformed(") == true)
        #expect(grammar.parse("at least many pages") == nil)
        #expect(grammar.parse("at least ") == nil)
        #expect(grammar.parse("at most many pages") == nil)
        #expect(grammar.parse("exactly many pages") == nil)
        #expect(grammar.parse("some whosever pages")?.traceDescription(detail: .verbose).contains("quant(any") == true)

        // matchDeterminer's `at least/most/exactly N` branch: nothing follows
        // the number, so the remainder is empty — falls through to the
        // "missing a description" malformed path.
        #expect(grammar.parse("at least 3")?.traceDescription(detail: .verbose).contains("malformed(") == true)

        // splitDescriptionAndBody's earliest-marker scan: a later-iterated
        // marker (" is ") occurring *before* an earlier-iterated one
        // (" have ") must win, exercising the `r.lowerBound < earliest!.lowerBound`
        // comparison (not just the `earliest == nil` first-hit case).
        if case .quantified(let q)? = grammar.parse("all pages is active and deals have status") {
            #expect(q.description.noun == "pages")
        } else {
            Issue.record("expected a quantified AST for an out-of-order body-verb match")
        }
    }

    @Test("description branches for ascending sorts, bare plurals, and object-gap clauses")
    func descriptionBranches() throws {
        let symbols = try symbols()
        let grammar = descriptionGrammar(symbols)

        let sorted = try #require(grammar.parse("pages sorted by status ascending"))
        #expect(sorted.sort?.ascending == true)
        #expect(grammar.parse("pages") == nil)
        #expect(grammar.parseOrBare("") == nil)
        #expect(DescriptionGrammar(lexicon: .default, symbols: nil, atom: atom, recurse: parser().parse).parseOrBare("pages") == nil)
        #expect(grammar.parseOrBare("widgets") == nil)
        let objectGap = try #require(grammar.parse("pages that the user owns"))
        #expect(objectGap.verbClauses.first?.elementIsSubject == false)
        #expect(grammar.parse("pages that") == nil)
        #expect(grammar.parse("pages that own") == nil)
        #expect(grammar.parse("foo task assigned by") == nil)
        #expect(grammar.undeclaredPassiveVerbError("frobnicated by the user") == nil)
        #expect(grammar.undeclaredPassiveVerbError("pages frobnicate by the user") == nil)
        #expect(grammar.undeclaredPassiveVerbError("pages owned by the user") == nil)
        #expect(grammar.undeclaredPassiveVerbError("page frobnicated by the user") == nil)
        // nil symbols short-circuits undeclaredPassiveVerbError to nil.
        #expect(DescriptionGrammar(lexicon: .default, symbols: nil, atom: atom, recurse: parser().parse)
            .undeclaredPassiveVerbError("pages frobnicated by the user") == nil)
        // parseThatClause's own empty-words guard (reachable directly; the
        // full `grammar.parse("pages that")` path never gets an all-
        // whitespace clause body since the relative-clause marker itself
        // consumes the trailing text).
        #expect(grammar.parseThatClause("   ", symbols: symbols) == nil)
    }

    @Test("dynamic verb and scalar-navigation guard branches")
    func dynamicVerbBranches() throws {
        let symbols = try symbols()
        let p = parser(symbols)

        #expect(p.parse("\"the user owns the page\"").traceDescription(detail: .verbose) == "\"the user owns the page\"")
        #expect(p.parse("the user owns to the page").traceDescription(detail: .verbose).contains("verb("))
        #expect(p.parse("the widget assigned to the user").traceDescription(detail: .verbose) == "id(widget assigned to the user)")
        #expect(p.parse("the foo task assigned to").traceDescription(detail: .verbose) == "id(foo task assigned to)")

        // ActiveVerbParser: a negation contraction directly before the matched
        // verb at idx==1 drives subjectEnd to 0, yielding an empty subject —
        // the guard must reject it (continue scanning) rather than emit a
        // predicate with no subject.
        let av = ActiveVerbParser(lexicon: .default, symbols: symbols, atom: atom)
        #expect(av.parse("doesn't owns the page") == nil)

        // ScalarNavigationParser: nil symbols short-circuits to nil, and a
        // resolved past-participle verb followed by a non-connector word
        // (neither "to" nor "by") must fall through (continue), not match.
        let scalarNoSymbols = ScalarNavigationParser(lexicon: .default, symbols: nil, atom: atom)
        #expect(scalarNoSymbols.parse("the foo task assigned to the user") == nil)
        let scalar = ScalarNavigationParser(lexicon: .default, symbols: symbols, atom: atom)
        #expect(scalar.parse("the foo task assigned oddly here") == nil)
    }

    @Test("possessive base resolution covers constants and instances")
    func possessiveBaseResolutionBranches() throws {
        let symbols = try symbols()
        let p = parser(symbols)

        #expect(p.parse("the default currency's code").traceDescription(detail: .verbose).hasPrefix("const(default currency)"))
        #expect(p.parse("the primary's name").traceDescription(detail: .verbose).hasPrefix("inst(primary)"))
    }

    @Test("template parser malformed directive and fallback branches")
    func templateBranches() {
        let p = parser()

        #expect(!p.parseInterpolationSegments("[if a is 1]yes[end if]").isEmpty)
        #expect(p.parseInterpolationSegments("[if a is 1").contains { if case .literal(let s) = $0 { return s == "[if a is 1" }; return false })
        #expect(p.parseInterpolationSegments("[for each row in rows").contains { if case .literal(let s) = $0 { return s == "[for each row in rows" }; return false })
        #expect(p.parseInterpolationSegments("[otherwise]").contains { if case .literal(let s) = $0 { return s == "[otherwise]" }; return false })
        #expect(!p.parseInterpolationSegments("[for each rows]x[end for]").isEmpty)
        #expect(!p.parseInterpolationSegments("{{ x as a }}").isEmpty)
        #expect(p.parseInterpolationSegments("{{ }}").isEmpty)
        // splitForEachHeader: an " in " marker with nothing before it (an
        // extra space right after "each") leaves an empty variable name,
        // which must default to "item" rather than binding an empty name.
        let segs = p.parseInterpolationSegments("[for each  in rows]x[end for]")
        #expect(segs.contains { if case .forEach(let v, _, _) = $0 { return v == "item" }; return false },
                Comment(rawValue: "\(segs)"))
    }

    @Test("code-block sentinel branches collapse literal-only interpolation and malformed sentinels")
    func codeBlockSentinelBranches() {
        let p = parser()

        #expect(p.parseAtom(sentinel("{{ unclosed")).traceDescription(detail: .verbose) == "\"{{ unclosed\"")
        #expect(p.parseAtom(codeBlockSentinelPrefix + "plain:not-base64").traceDescription(detail: .verbose)
                == "malformed(corrupt or truncated code-block sentinel)")
    }

    @Test("nonterminal screen keeps overflow productions correct")
    func nonterminalScreenOverflowBranches() {
        let fillers = (0..<128).map { i in
            GrammarProduction(
                name: "filler-\(i)",
                category: .expression,
                implementation: .pegex,
                canonicalExample: "`f\(i)`",
                summary: "Filler.",
                anchors: ["anchor\(i)"]
            )
        }
        let overflow = GrammarProduction(
            name: "overflow",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`overflow`",
            summary: "Past the mask budget.",
            anchors: ["anchor128"]
        )
        let screen = NonterminalScreen(table: GrammarTable(productions: fillers + [overflow]))

        #expect(screen.anchorCount == 128)
        #expect(screen.anchorMask(for: overflow) == 0)
        #expect(screen.candidates(for: "no matching anchor").contains { $0.name == "overflow" })
        let unknown = GrammarProduction(
            name: "unknown",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`unknown`",
            summary: "Not in table.",
            anchors: ["unknown"]
        )
        #expect(screen.anchorMask(for: unknown) == 0)
    }
}
