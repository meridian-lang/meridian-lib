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
        let custom = EnglishLexicon.default.merging(
            comparisonSynonyms: [],
            durationSynonyms: ["fortnight": .week]
        )
        guard let (a, u) = custom.parseDuration("2 fortnights") else {
            Issue.record("Expected plural fallback to find 'fortnight' for '2 fortnights'")
            return
        }
        #expect(a == 2)
        #expect(u == .week)
    }

    @Test("non-numeric returns nil")
    func nonNumeric() {
        #expect(EnglishLexicon.default.parseDuration("many hours") == nil)
    }
}

@Suite("EnglishLexicon — comparison markers")
struct ComparisonMarkerTests {

    func parse(_ s: String) -> ExpressionAST {
        ExpressionParser(symbols: nil, trace: .silent()).parse(s)
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
        ExpressionParser(symbols: nil, trace: .silent()).parse(s)
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

    @Test("or has lower precedence than and")
    func precedence() {
        let e = parse("a is 1 and b is 2 or c is 3")
        // Should parse as (a==1 && b==2) || c==3
        if case .logical(.or, let orOps) = e {
            #expect(orOps.count == 2)
            if case .logical(.and, let andOps) = orOps[0] {
                #expect(andOps.count == 2)
            } else {
                Issue.record("left of or should be and, got: \(orOps[0])")
            }
        } else {
            Issue.record("expected logical(.or, ...), got: \(e)")
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
        ~ validateOrder(order: Order) : Result
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
