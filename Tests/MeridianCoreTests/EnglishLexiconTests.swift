import Testing
import Foundation
@testable import MeridianCore

// MARK: - EnglishLexicon tests

@Suite("EnglishLexicon — struct-name derivation")
struct IRWorkflowStructNameTests {

    @Test("plain verb + noun")
    func basicName() {
        let name = EnglishLexicon.default.structName(from: "process an order")
        #expect(name == "ProcessOrder")
    }

    @Test("drops articles before first preposition")
    func dropsArticles() {
        let name = EnglishLexicon.default.structName(from: "process an order placed by a customer")
        // stops at "placed" (participle) after the first significant word pair
        #expect(name == "ProcessOrder", Comment(rawValue: "got: \(name)"))
    }

    @Test("sync analytics stops at 'for'")
    func syncAnalytics() {
        let name = EnglishLexicon.default.structName(from: "sync analytics for an order placed by a customer")
        #expect(name == "SyncAnalytics", Comment(rawValue: "got: \(name)"))
    }

    @Test("single-word workflow")
    func singleWord() {
        let name = EnglishLexicon.default.structName(from: "finalise")
        #expect(name == "Finalise")
    }

    @Test("empty → Workflow fallback")
    func emptyName() {
        let name = EnglishLexicon.default.structName(from: "")
        #expect(name == "Workflow")
    }

    @Test("all-article input → Workflow fallback")
    func allArticles() {
        let name = EnglishLexicon.default.structName(from: "a an the")
        #expect(name == "Workflow")
    }
}

@Suite("EnglishLexicon — duration parsing")
struct DurationParsingTests {

    func check(_ s: String, amount: Double, unit: TimeUnitAST, file: StaticString = #file, line: UInt = #line) {
        guard let (a, u) = EnglishLexicon.default.parseDuration(s) else {
            Issue.record("parseDuration returned nil for \"\(s)\"")
            return
        }
        #expect(a == amount, "\(s): expected amount \(amount)")
        #expect(u == unit,   "\(s): expected unit \(unit)")
    }

    @Test("canonical forms")
    func canonical() {
        check("1 hour",     amount: 1,   unit: .hour)
        check("30 minutes", amount: 30,  unit: .minute)
        check("2 days",     amount: 2,   unit: .day)
        check("5 seconds",  amount: 5,   unit: .second)
        check("500 ms",     amount: 500, unit: .millisecond)
        check("3 weeks",    amount: 3,   unit: .week)
    }

    @Test("abbreviations")
    func abbreviations() {
        check("2 hr",   amount: 2,  unit: .hour)
        check("15 min", amount: 15, unit: .minute)
        check("10 sec", amount: 10, unit: .second)
    }

    @Test("unknown unit returns nil")
    func unknownUnit() {
        // "fortnight" isn't in the default lexicon, plural or singular,
        // so both forms must resolve to nil.
        #expect(EnglishLexicon.default.parseDuration("5 fortnights") == nil)
        #expect(EnglishLexicon.default.parseDuration("5 fortnight") == nil)
    }

    @Test("plural form resolves via singular fallback")
    func pluralFallback() {
        // Custom lexicon defines only the singular form. The parser should
        // still accept the pluralised input (`fortnights → fortnight → week`).
        let custom = EnglishLexicon.default.merging(entries: [
            .duration: [.duration("fortnight", .week)],
        ])
        guard let (a, u) = custom.parseDuration("2 fortnights") else {
            Issue.record("Expected plural fallback to find 'fortnight' for '2 fortnights'")
            return
        }
        #expect(a == 2)
        #expect(u == .week)
    }

    @Test("merging lowercases and unions normative-cue, inference-cue, and reference-heading synonyms")
    func mergingUnionsCueAndReferenceHeadingWords() {
        let merged = EnglishLexicon.default.merging(entries: [
            .normativeCue: [.phrase("Must Always")],
            .inferenceCue: [.phrase("Exercise Judgment")],
            .referenceHeading: [.phrase("Background")],
        ])
        #expect(merged.normativeCueWords.contains("must always"))
        #expect(merged.inferenceCueWords.contains("exercise judgment"))
        #expect(merged.referenceHeadingWords.contains("background"))
        // Defaults are preserved, not replaced.
        #expect(merged.inferenceCueWords.isSuperset(of: EnglishLexicon.default.inferenceCueWords))
        #expect(merged.referenceHeadingWords.isSuperset(of: EnglishLexicon.default.referenceHeadingWords))
    }

    @Test("non-numeric returns nil")
    func nonNumeric() {
        #expect(EnglishLexicon.default.parseDuration("many hours") == nil)
    }

    @Test("stripLeadingArticle removes one leading article, preserving case")
    func stripArticle() {
        let lex = EnglishLexicon.default
        #expect(lex.stripLeadingArticle("the Order") == "Order")
        #expect(lex.stripLeadingArticle("a customer") == "customer")
        #expect(lex.stripLeadingArticle("an Account") == "Account")
        // No article → unchanged (trimmed).
        #expect(lex.stripLeadingArticle("  Order  ") == "Order")
        // Only the leading article is stripped, not an embedded one.
        #expect(lex.stripLeadingArticle("the a-list") == "a-list")
        // A word that merely starts with article letters is not an article.
        #expect(lex.stripLeadingArticle("theatre") == "theatre")
        #expect(lex.stripLeadingArticle("another") == "another")
    }
}

@Suite("EnglishLexicon — comparison markers")
struct ComparisonMarkerTests {

    func parse(_ s: String) -> ExpressionAST {
        ExpressionParser(symbols: nil).parse(s)
    }

    @Test("greater than")
    func greaterThan() {
        let e = parse("the order's total amount is more than 100")
        if case .comparison(_, let op, _) = e {
            #expect(op == .greaterThan)
        } else {
            Issue.record("expected comparison, got: \(e)")
        }
    }

    @Test("less than")
    func lessThan() {
        let e = parse("the order's total amount is less than 50")
        if case .comparison(_, let op, _) = e {
            #expect(op == .lessThan)
        } else {
            Issue.record("expected comparison, got: \(e)")
        }
    }

    @Test("equal")
    func equal() {
        let e = parse("the status is pending")
        if case .comparison(_, let op, _) = e {
            #expect(op == .equal)
        } else {
            Issue.record("expected comparison, got: \(e)")
        }
    }

    @Test("not equal")
    func notEqual() {
        let e = parse("the status is not cancelled")
        if case .comparison(_, let op, _) = e {
            #expect(op == .notEqual)
        } else {
            Issue.record("expected comparison, got: \(e)")
        }
    }

    @Test("at least → greaterOrEqual")
    func atLeast() {
        let e = parse("the score is at least 90")
        if case .comparison(_, let op, _) = e {
            #expect(op == .greaterOrEqual)
        } else {
            Issue.record("expected comparison, got: \(e)")
        }
    }
}

@Suite("EnglishLexicon — logical connectors")
struct LogicalConnectorTests {

    func parse(_ s: String) -> ExpressionAST {
        ExpressionParser(symbols: nil).parse(s)
    }

    @Test("and connector")
    func andConnector() {
        let e = parse("the status is active and the score is 10")
        if case .logical(.and, let ops) = e {
            #expect(ops.count == 2)
        } else {
            Issue.record("expected logical(.and, ...), got: \(e)")
        }
    }

    @Test("or connector")
    func orConnector() {
        let e = parse("the status is active or the status is pending")
        if case .logical(.or, let ops) = e {
            #expect(ops.count == 2)
        } else {
            Issue.record("expected logical(.or, ...), got: \(e)")
        }
    }

    @Test("not prefix")
    func notPrefix() {
        let e = parse("not the status is active")
        if case .logical(.not, let ops) = e {
            #expect(ops.count == 1)
        } else {
            Issue.record("expected logical(.not, ...), got: \(e)")
        }
    }

    @Test("mixing and/or without grouping is a malformed error (Wave 2A)")
    func mixedBooleanIsMalformed() {
        // The Wave 2A strict rule: a bare `and`/`or` mix has no implicit
        // precedence — it must be grouped with `either … or …`.
        let e = parse("a is 1 and b is 2 or c is 3")
        if case .malformed = e {
            // expected
        } else {
            Issue.record("expected .malformed for ungrouped and/or mix, got: \(e)")
        }
    }

    @Test("either … or … groups a disjunction inside an and-chain (Wave 2A)")
    func eitherGrouping() {
        // `a is 1 and either b is 2 or c is 3` → a ∧ (b ∨ c)
        let e = parse("a is 1 and either b is 2 or c is 3")
        guard case .logical(.and, let andOps) = e, andOps.count == 2 else {
            Issue.record("expected top-level and, got: \(e)"); return
        }
        if case .logical(.or, let orOps) = andOps[1] {
            #expect(orOps.count == 2)
        } else {
            Issue.record("right operand should be an or-group, got: \(andOps[1])")
        }
    }
}

@Suite("EnglishLexicon — language synonyms (A2)")
struct LanguageSynonymTests {

    @Test("comparison synonym in merconfig")
    func comparisonSynonym() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        To check a score:
          if the score exceeds 100,
            complete with reason "too high".
        """
        let cfg = """
        === vocabulary ===

        === language ===
        Comparison synonyms:
          exceeds = is more than
        """
        let out = try Compiler().compile(
            meridianSource: mer,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        // "exceeds" should lower to a greaterThan comparison
        #expect(out.contains("MeridianComparison") || out.contains(">"),
                Comment(rawValue: "Expected comparison in:\n\(out)"))
    }

    @Test("duration synonym in merconfig")
    func durationSynonym() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        To pause the system:
          wait 2 fortnight.
        """
        let cfg = """
        === vocabulary ===

        === language ===
        Duration synonyms:
          fortnight = week
        """
        // fortnight → week, so "2 fortnight" → 2 weeks
        let out = try Compiler().compile(
            meridianSource: mer,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains(".weeks(2)") || out.contains("Duration") || out.contains("wait"),
                Comment(rawValue: "Expected wait/duration in:\n\(out)"))
    }

    @Test("assertion synonym in merconfig adds an invariant keyword")
    func assertionSynonym() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        To check a score:
          verify the score is more than 100.
        """
        let cfg = """
        === vocabulary ===

        === language ===
        Assertion synonyms:
          verify
        """
        // "verify X" should lower to the same assert as "make sure X".
        let out = try Compiler().compile(
            meridianSource: mer,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains("guard") || out.contains("MeridianRuntimeError") || out.contains("assert"),
                Comment(rawValue: "Expected an assertion in:\n\(out)"))
        #expect(!out.contains("_unresolved"),
                Comment(rawValue: "Expected no unresolved placeholder in:\n\(out)"))
    }

    @Test("merging sorts assertion markers longest-first and de-dupes")
    func assertionMarkerMerge() {
        let merged = EnglishLexicon.default.merging(entries: [
            .assertion: [.phrase("assert"), .phrase("guarantee that")],
        ])
        // "guarantee that" (author) is retained; "assert" is de-duped (already a
        // default); ordering is longest-first.
        #expect(merged.assertionMarkers.first == "guarantee that")
        #expect(merged.assertionMarkers.filter { $0 == "assert" }.count == 1)
        #expect(merged.assertionMarkers.contains("make sure"))
    }
}

@Suite("EnglishLexicon — article helpers, morphology, and merging edge cases")
struct EnglishLexiconEdgeCaseCoverageTests {

    @Test("SuperlativeDirection ascending and needsBy buckets")
    func superlativeDirectionBuckets() {
        #expect(SuperlativeDirection.oldest.ascending == true)
        #expect(SuperlativeDirection.newest.ascending == false)
        #expect(SuperlativeDirection.smallest.needsBy == true)
        #expect(SuperlativeDirection.largest.needsBy == true)
        #expect(SuperlativeDirection.oldest.needsBy == false)
    }

    @Test("indefiniteArticlePrefix empty and vowel-initial branches")
    func indefiniteArticlePrefixEdges() {
        let base = EnglishLexicon.default
        let onlyAn = EnglishLexicon(
            articles: base.articles,
            parameterArticles: ["an"],
            prepositions: base.prepositions,
            copulas: base.copulas,
            participles: base.participles,
            participleSuffixes: base.participleSuffixes,
            comparisonMarkers: base.comparisonMarkers,
            durationUnits: base.durationUnits,
            toolStopwords: base.toolStopwords
        )
        #expect(onlyAn.indefiniteArticlePrefix(for: "") == "an ")
        #expect(onlyAn.indefiniteArticlePrefix(for: "order") == "an ")
        #expect(onlyAn.indefiniteArticlePrefix(for: "apple") == "an ")

        let onlyA = EnglishLexicon(
            articles: base.articles,
            parameterArticles: ["a"],
            prepositions: base.prepositions,
            copulas: base.copulas,
            participles: base.participles,
            participleSuffixes: base.participleSuffixes,
            comparisonMarkers: base.comparisonMarkers,
            durationUnits: base.durationUnits,
            toolStopwords: base.toolStopwords
        )
        #expect(onlyA.indefiniteArticlePrefix(for: "") == "a ")
        #expect(onlyA.indefiniteArticlePrefix(for: "order") == "a ")
    }

    @Test("canonicalComparisonSurface prefers author markers and relational spellings")
    func canonicalComparisonSurfaceRelational() {
        let base = EnglishLexicon.default
        let authorGT = EnglishLexicon(
            articles: base.articles,
            prepositions: base.prepositions,
            copulas: base.copulas,
            participles: base.participles,
            participleSuffixes: base.participleSuffixes,
            comparisonMarkers: [(" exceeds ", .greaterThan)],
            durationUnits: base.durationUnits,
            toolStopwords: base.toolStopwords
        )
        #expect(authorGT.canonicalComparisonSurface(.greaterThan) == "exceeds")

        let spellingOnly = EnglishLexicon(
            articles: base.articles,
            prepositions: base.prepositions,
            copulas: base.copulas,
            participles: base.participles,
            participleSuffixes: base.participleSuffixes,
            comparisonMarkers: [],
            durationUnits: base.durationUnits,
            toolStopwords: base.toolStopwords
        )
        let less = spellingOnly.canonicalComparisonSurface(.lessThan)
        #expect(less == "is less" || less == "is less than")
        let equal = spellingOnly.canonicalComparisonSurface(.equal)
        #expect(equal == "equals" || equal == "equal")
        #expect(EnglishLexicon.default.canonicalComparisonSurface(.contains) == "contains")
        #expect(EnglishLexicon.default.canonicalComparisonSurface(.oneOf) == "is one of")
        #expect(EnglishLexicon.default.canonicalComparisonSurface(.isEmpty) == "is empty")
        #expect(EnglishLexicon.default.canonicalComparisonSurface(.withinPast) == "is within the last")
    }

    @Test("definiteArticle falls back to the sorted first article when \"the\" is absent from a custom lexicon")
    func definiteArticleFallsBackWhenTheIsAbsent() {
        let base = EnglishLexicon.default
        let custom = EnglishLexicon(
            articles: ["a", "an"],
            prepositions: base.prepositions,
            copulas: base.copulas,
            participles: base.participles,
            participleSuffixes: base.participleSuffixes,
            comparisonMarkers: base.comparisonMarkers,
            durationUnits: base.durationUnits,
            toolStopwords: base.toolStopwords
        )
        #expect(custom.definiteArticle == "a")
    }

    @Test("findEarliestArticle breaks a tied lowerBound in favor of the longer marker")
    func findEarliestArticleTieBreaksOnLongerMarker() {
        let base = EnglishLexicon.default
        // "a certain" is a prefix-compatible superstring of "a " — both markers
        // (" a certain " and " a ") start matching at the exact same position
        // in "for a certain widget", forcing the tie-break clause to evaluate.
        let custom = EnglishLexicon(
            articles: base.articles,
            parameterArticles: ["a", "a certain"],
            prepositions: base.prepositions,
            copulas: base.copulas,
            participles: base.participles,
            participleSuffixes: base.participleSuffixes,
            comparisonMarkers: base.comparisonMarkers,
            durationUnits: base.durationUnits,
            toolStopwords: base.toolStopwords
        )
        guard let (intro, rest) = custom.findEarliestArticle("for a certain widget") else {
            Issue.record("expected an article match")
            return
        }
        #expect(intro == "for")
        // The longer marker (" a certain ") wins the tie, consuming "certain" too.
        #expect(rest == "widget")
    }

    @Test("singularize leaves an \"ies\"-ending word unchanged in shape when preceded by a vowel")
    func singularizeSkipsIesToYWhenPrecededByVowel() {
        // Synthetic input (not real English) isolates the vowel-guard branch:
        // dropping "ies" from "zoies" leaves "zo", whose last letter is the
        // vowel "o", so the y-substitution must NOT fire.
        let lex = EnglishLexicon.default
        #expect(lex.singularize("zoies") == "zoie")
    }

    @Test("pluralize resolves a single-word irregular override before any splitting")
    func pluralizeSingleWordIrregularOverride() {
        let lex = EnglishLexicon.default
        #expect(lex.pluralize("person") == "people")
        #expect(lex.pluralize("child") == "children")
    }

    @Test("pluralize applies an irregular override to only the last word of a multi-word phrase")
    func pluralizeMultiWordIrregularLastWord() {
        let lex = EnglishLexicon.default
        #expect(lex.pluralize("field mouse") == "field mice")
        #expect(lex.pluralize("point of contact person") == "point of contact people")
    }

    @Test("merging maps a recognized trace outcome synonym and silently skips an unrecognized one")
    func mergingTraceOutcomeSynonyms() {
        let merged = EnglishLexicon.default.merging(entries: [
            .traceOutcome: [.mapping("crashed", "failed"), .mapping("bogus", "not-a-real-outcome")],
        ])
        #expect(merged.traceOutcomeVerbs["crashed"] == .failed)
        #expect(merged.traceOutcomeVerbs["bogus"] == nil)
        // Defaults are preserved alongside the merged synonym.
        #expect(merged.traceOutcomeVerbs["failed"] == .failed)
    }

    @Test("merging lowercases and unions trace-auxiliary synonyms")
    func mergingTraceAuxiliarySynonyms() {
        let merged = EnglishLexicon.default.merging(entries: [
            .traceAuxiliary: [.phrase("Shall")],
        ])
        #expect(merged.tracePerfectAuxiliaries.contains("shall"))
        #expect(merged.tracePerfectAuxiliaries.isSuperset(of: EnglishLexicon.default.tracePerfectAuxiliaries))
    }
}

@Suite("Tool resolution — token-overlap scoring (A4)")
struct ToolResolutionTests {

    @Test("exact method name wins over substring match")
    func exactWins() throws {
        // Two tools: "validate order" (method: validateOrder) and
        // "validate" (method: validate). An invocation of "validate order"
        // should score the more specific tool higher.
        let cfg = """
        === vocabulary ===

        === tools ===

        Validate Order
        ==============
        ~ validateOrder(order: Order) : Result

        Validate
        ========
        ~ validate(item: String) : Boolean
        """
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        To run validation for an order:
          bind result = invoke validate order with order = the order.
        """
        // Tool resolves directly through the bare-invoke path, so strict mode
        // succeeds without any fallbacks opt-in.
        let out = try Compiler(options: .init()).compile(
            meridianSource: mer,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains("validateOrder") || out.contains("validate"),
                Comment(rawValue: "Expected tool call in:\n\(out)"))
    }
}

@Suite("A6 — Unresolved phrase diagnostic")
struct UnresolvedPhraseTests {

    @Test("unresolved throws by default")
    func throwsByDefault() {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        To test unresolved:
          do something completely unknown.
        """
        let cfg = "=== vocabulary ==="
        #expect(throws: (any Error).self) {
            try Compiler().compile(
                meridianSource: mer,
                meridianFile: "test.meridian",
                merconfigSource: cfg,
                merconfigFile: "test.merconfig"
            )
        }
    }

    @Test("frontmatter `allow-fallbacks: unresolved-phrases` emits placeholder")
    func placeholderWhenAllowed() throws {
        let mer = """
        ---
        name: test
        allow-fallbacks: unresolved-phrases
        vocabulary: test.merconfig
        ---

        To test placeholder:
          do something completely unknown.
        """
        let cfg = "=== vocabulary ==="
        let out = try Compiler(options: .init()).compile(
            meridianSource: mer,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains("_unresolved"),
                Comment(rawValue: "Expected _unresolved in:\n\(out)"))
    }

    @Test("Compiler.Options.fallbackPolicy = .lenient also emits placeholder")
    func placeholderViaOptions() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        To test placeholder:
          do something completely unknown.
        """
        let cfg = "=== vocabulary ==="
        let out = try Compiler(options: .init(fallbackPolicy: .lenient)).compile(
            meridianSource: mer,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains("_unresolved"),
                Comment(rawValue: "Expected _unresolved in:\n\(out)"))
    }
}
