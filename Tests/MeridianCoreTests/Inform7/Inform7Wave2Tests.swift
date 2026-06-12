import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Coverage for the Wave 2 semantic core: boolean composition (2A), checkable
// adjective definitions (2B), the shared condition grammar (emptiness +
// temporal), and quantifiers over descriptions (2C).

// MARK: - 2A. Boolean composition

@Suite("Wave 2A — boolean composition")
struct BooleanCompositionTests {

    private func parse(_ s: String) -> ExpressionAST {
        ExpressionParser(trace: .silent()).parse(s)
    }

    @Test("pure and-chain")
    func andChain() {
        guard case .logical(.and, let ops) = parse("a is 1 and b is 2 and c is 3") else {
            Issue.record("expected and"); return
        }
        #expect(ops.count == 3)
    }

    @Test("pure or-chain")
    func orChain() {
        guard case .logical(.or, let ops) = parse("a is 1 or b is 2 or c is 3") else {
            Issue.record("expected or"); return
        }
        #expect(ops.count == 3)
    }

    @Test("not negates the following comparison")
    func notClause() {
        guard case .logical(.not, let ops) = parse("not a is 1") else {
            Issue.record("expected not"); return
        }
        #expect(ops.count == 1)
    }

    @Test("it is not the case that … negates a clause")
    func itIsNotTheCaseThat() {
        guard case .logical(.not, _) = parse("it is not the case that a is 1") else {
            Issue.record("expected not"); return
        }
    }

    @Test("ungrouped and/or mix is malformed")
    func mixedIsMalformed() {
        guard case .malformed = parse("a is 1 and b is 2 or c is 3") else {
            Issue.record("expected malformed"); return
        }
    }

    @Test("either … or … groups a disjunction within an and-chain")
    func eitherGroupsDisjunction() {
        guard case .logical(.and, let andOps) = parse("a is 1 and either b is 2 or c is 3"),
              andOps.count == 2 else {
            Issue.record("expected top-level and"); return
        }
        guard case .logical(.or, let orOps) = andOps[1], orOps.count == 2 else {
            Issue.record("expected or group on the right"); return
        }
    }

    @Test("leading either … or … is a disjunction")
    func leadingEither() {
        guard case .logical(.or, let ops) = parse("either a is 1 or b is 2 or c is 3") else {
            Issue.record("expected or"); return
        }
        #expect(ops.count == 3)
    }

    @Test("Oxford comma before and/or is tolerated")
    func commaTolerance() {
        guard case .logical(.and, let ops) = parse("a is 1, and b is 2") else {
            Issue.record("expected and"); return
        }
        #expect(ops.count == 2)
    }

    @Test("and/or markers inside quoted strings are not split")
    func quotedNotSplit() {
        // The only top-level operator is the trailing `and`.
        guard case .logical(.and, let ops) = parse("note is \"x and y or z\" and b is 2") else {
            Issue.record("expected and"); return
        }
        #expect(ops.count == 2)
    }

    // assertNoMalformed: a parse-time `.malformed` carrier must surface as a
    // sourced compile error rather than silently lowering to a placeholder.
    @Test("a malformed boolean in a conditional aborts compilation")
    func malformedConditionAborts() {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has a status, which is text.
        """
        #expect(throws: (any Error).self) {
            _ = try Compiler().compile(
                meridianSource: """
                ---
                name: review
                parameters: page
                vocabulary: t.merconfig
                ---
                To review a page:
                  if a is 1 and b is 2 or c is 3,
                    complete with reason "x".
                """,
                meridianFile: "t.meridian",
                merconfigSource: cfg, merconfigFile: "t.merconfig")
        }
    }
}

// MARK: - 2B. Checkable adjective definitions

@Suite("Wave 2B — definitions")
struct DefinitionTests {

    private let cfg = """
    === vocabulary ===
    A page is a kind of thing.
    A page has a summary, a body, and a last reviewed.
    """

    private func compile(_ mer: String) throws -> String {
        try Compiler().compile(
            meridianSource: mer, meridianFile: "t.meridian",
            merconfigSource: cfg, merconfigFile: "t.merconfig"
        )
    }

    @Test("a definition emits a meridianDef_ helper")
    func emitsHelper() throws {
        let out = try compile("""
        ---
        name: review
        parameters: page
        vocabulary: t.merconfig
        ---
        Definition: a page is stale if it has no summary.

        To review a page:
          if the page is stale,
            complete with reason "needs work".
        """)
        #expect(out.contains("private func meridianDef_Page_stale(_ __subjectValue: Value?) -> Bool"),
                Comment(rawValue: out))
        #expect(out.contains("MeridianComparison.isEmpty(__subject.member(\"summary\"))"),
                Comment(rawValue: out))
    }

    @Test("using an adjective in subject position emits a definition-predicate call")
    func adjectiveCallSite() throws {
        let out = try compile("""
        ---
        name: review
        parameters: page
        vocabulary: t.merconfig
        ---
        Definition: a page is stale if it has no summary.

        To review a page:
          if the page is stale,
            complete with reason "needs work".
        """)
        #expect(out.contains("meridianDef_Page_stale(state.get(\"page\")"), Comment(rawValue: out))
    }

    @Test("is not <adj> negates the predicate")
    func negatedAdjective() throws {
        let out = try compile("""
        ---
        name: review
        parameters: page
        vocabulary: t.merconfig
        ---
        Definition: a page is stale if it has no summary.

        To review a page:
          if the page is not stale,
            complete with reason "ok".
        """)
        #expect(out.contains("!(meridianDef_Page_stale("), Comment(rawValue: out))
    }

    @Test("definitions can reference other definitions (non-recursive)")
    func compositeDefinition() throws {
        let out = try compile("""
        ---
        name: review
        parameters: page
        vocabulary: t.merconfig
        ---
        Definition: a page is empty if it has no body.
        Definition: a page is stale if it is empty.

        To review a page:
          if the page is stale,
            complete with reason "x".
        """)
        #expect(out.contains("meridianDef_Page_stale"), Comment(rawValue: out))
        #expect(out.contains("meridianDef_Page_empty"), Comment(rawValue: out))
    }

    @Test("a recursive definition is a hard error")
    func recursionRejected() {
        #expect(throws: (any Error).self) {
            _ = try compile("""
            ---
            name: review
            parameters: page
            vocabulary: t.merconfig
            ---
            Definition: a page is stale if it is stale.

            To review a page:
              if the page is stale, complete with reason "x".
            """)
        }
    }

    @Test("an unknown property in a definition body is a hard error")
    func unknownPropertyRejected() {
        #expect(throws: (any Error).self) {
            _ = try compile("""
            ---
            name: review
            parameters: page
            vocabulary: t.merconfig
            ---
            Definition: a page is stale if it has no nonexistent.

            To review a page:
              if the page is stale, complete with reason "x".
            """)
        }
    }

    @Test("definitions are recorded under meridian_definitions in the manifest")
    func manifestRecordsDefinitions() throws {
        let (_, input) = try Compiler().compileWithManifest(
            meridianSource: """
            ---
            name: review
            parameters: page
            vocabulary: t.merconfig
            ---
            Definition: a page is stale if it has no summary.

            To review a page:
              if the page is stale,
                complete with reason "needs work".
            """,
            meridianFile: "t.meridian",
            vocabularies: [.init(name: "t", file: "t.merconfig", source: cfg)])
        let json = try ManifestEmitter().emit(input)
        #expect(json.contains("meridian_definitions"), Comment(rawValue: json))
        #expect(json.contains("\"adjective\" : \"stale\""), Comment(rawValue: json))
        #expect(json.contains("\"function\" : \"meridianDef_Page_stale\""), Comment(rawValue: json))
    }
}

// MARK: - Shared condition grammar (emptiness + temporal)

@Suite("Wave 2 — condition grammar")
struct ConditionGrammarTests {

    private func parse(_ s: String) -> ExpressionAST {
        ExpressionParser(trace: .silent()).parse(s)
    }

    @Test("X has no Y → isEmpty over a property access")
    func hasNo() {
        guard case .comparison(let lhs, .isEmpty, _) = parse("page has no summary") else {
            Issue.record("expected isEmpty comparison"); return
        }
        guard case .propertyAccess(_, let prop) = lhs else {
            Issue.record("expected property access lhs"); return
        }
        #expect(prop == "summary")
    }

    @Test("X has a Y → isNotEmpty over a property access")
    func hasA() {
        guard case .comparison(_, .isNotEmpty, _) = parse("page has a summary") else {
            Issue.record("expected isNotEmpty comparison"); return
        }
    }

    @Test("X is empty / is not empty")
    func bareEmptiness() {
        guard case .comparison(_, .isEmpty, _) = parse("results is empty") else {
            Issue.record("expected isEmpty"); return
        }
        guard case .comparison(_, .isNotEmpty, _) = parse("results is not empty") else {
            Issue.record("expected isNotEmpty"); return
        }
    }

    @Test("within the last N days → withinPast")
    func withinPast() {
        guard case .comparison(_, .withinPast, let rhs) = parse("page's last reviewed within the last 7 days") else {
            Issue.record("expected withinPast"); return
        }
        guard case .literal(.duration) = rhs else {
            Issue.record("expected duration literal"); return
        }
    }

    @Test("in the next N days → withinFuture")
    func withinFuture() {
        guard case .comparison(_, .withinFuture, _) = parse("deadline in the next 3 days") else {
            Issue.record("expected withinFuture"); return
        }
    }

    @Test("emptiness comparison op lowers to the runtime helper")
    func emptinessEmission() throws {
        let cfg = """
        === vocabulary ===
        A note is a kind of thing.
        A note has a body, which is text.
        """
        let out = try Compiler().compile(
            meridianSource: """
            ---
            name: check
            parameters: note
            vocabulary: t.merconfig
            ---
            To check a note:
              if the note's body is empty,
                complete with reason "blank".
            """,
            meridianFile: "t.meridian", merconfigSource: cfg, merconfigFile: "t.merconfig")
        #expect(out.contains("MeridianComparison.isEmpty("), Comment(rawValue: out))
    }
}

// MARK: - 2C. Quantifiers

@Suite("Wave 2C — quantifiers")
struct QuantifierTests {

    private let cfg = """
    === vocabulary ===
    A page is a kind of thing.
    A page has a summary, which is text.
    A page has a status, which is text.
    """

    private func parse(_ s: String, symbols: SymbolTable? = nil) -> ExpressionAST {
        ExpressionParser(symbols: symbols, trace: .silent()).parse(s)
    }

    private func symbolsForPages() throws -> SymbolTable {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        return SymbolTable.build(from: config)
    }

    @Test("all <kind> have <prop> parses to a quantifier with a body")
    func allParses() throws {
        let sym = try symbolsForPages()
        guard case .quantified(let q) = parse("all pages have a summary", symbols: sym) else {
            Issue.record("expected quantifier"); return
        }
        #expect(q.kind == .all)
        #expect(q.description.noun == "pages")
        #expect(q.body != nil)
    }

    @Test("at least N parses the count")
    func atLeastParses() throws {
        let sym = try symbolsForPages()
        guard case .quantified(let q) = parse("at least 2 pages have a summary", symbols: sym) else {
            Issue.record("expected quantifier"); return
        }
        #expect(q.kind == .atLeast(2))
    }

    @Test("at most N parses the count")
    func atMostParses() throws {
        let sym = try symbolsForPages()
        guard case .quantified(let q) = parse("at most 3 pages have a summary", symbols: sym) else {
            Issue.record("expected quantifier"); return
        }
        #expect(q.kind == .atMost(3))
    }

    @Test("exactly N parses the count")
    func exactlyParses() throws {
        let sym = try symbolsForPages()
        guard case .quantified(let q) = parse("exactly 1 page has a summary", symbols: sym) else {
            Issue.record("expected quantifier"); return
        }
        #expect(q.kind == .exactly(1))
    }

    @Test("no <kind> whose <pred> parses as none with a where clause")
    func noneWithWhere() throws {
        let sym = try symbolsForPages()
        guard case .quantified(let q) = parse("no pages whose status is \"draft\"", symbols: sym) else {
            Issue.record("expected quantifier"); return
        }
        #expect(q.kind == .none)
        #expect(q.description.wherePredicate != nil)
    }

    @Test("adjectives are split off the kind head")
    func adjectivesSplit() throws {
        let sym = try symbolsForPages()
        guard case .quantified(let q) = parse("any stale pages", symbols: sym) else {
            Issue.record("expected quantifier"); return
        }
        #expect(q.description.adjectives == ["stale"])
        #expect(q.description.noun == "pages")
    }

    private func compile(_ mer: String) throws -> String {
        try Compiler().compile(
            meridianSource: mer, meridianFile: "t.meridian",
            merconfigSource: cfg, merconfigFile: "t.merconfig")
    }

    @Test("all … emits an allSatisfy reducer")
    func allEmits() throws {
        let out = try compile("""
        ---
        name: audit
        parameters: pages
        vocabulary: t.merconfig
        ---
        To audit the pages:
          if all pages have a summary,
            complete with reason "ok".
        """)
        #expect(out.contains(".allSatisfy"), Comment(rawValue: out))
        #expect(out.contains("?.asList ?? []"), Comment(rawValue: out))
    }

    @Test("at least N emits a count >= N reducer")
    func atLeastEmits() throws {
        let out = try compile("""
        ---
        name: audit
        parameters: pages
        vocabulary: t.merconfig
        ---
        To audit the pages:
          if at least 2 pages whose status is "published" have a summary,
            complete with reason "ok".
        """)
        #expect(out.contains(".count >= 2"), Comment(rawValue: out))
    }

    @Test("at most N emits a count <= N reducer")
    func atMostEmits() throws {
        let out = try compile("""
        ---
        name: audit
        parameters: pages
        vocabulary: t.merconfig
        ---
        To audit the pages:
          if at most 3 pages whose status is "draft",
            complete with reason "ok".
        """)
        #expect(out.contains(".count <= 3"), Comment(rawValue: out))
    }

    @Test("exactly N emits a count == N reducer")
    func exactlyEmits() throws {
        let out = try compile("""
        ---
        name: audit
        parameters: pages
        vocabulary: t.merconfig
        ---
        To audit the pages:
          if exactly 1 page whose status is "published",
            complete with reason "ok".
        """)
        #expect(out.contains(".count == 1"), Comment(rawValue: out))
    }

    @Test("no … emits an empty-set reducer")
    func noneEmits() throws {
        let out = try compile("""
        ---
        name: audit
        parameters: pages
        vocabulary: t.merconfig
        ---
        To audit the pages:
          if no pages whose status is "draft",
            complete with reason "clean".
        """)
        #expect(out.contains(".isEmpty"), Comment(rawValue: out))
    }
}

// MARK: - End-to-end .meridian.test specs (2A / 2B / 2C)

@Suite("Wave 2 — .meridian.test specs")
struct Wave2SpecTests {

    /// `Tests/MeridianCoreTests/Inform7/Inform7Wave2Tests.swift`
    ///  → `Tests/MeridianCoreTests/MeridianTestSpecs`.
    private func specURL(_ file: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Inform7
            .deletingLastPathComponent()   // MeridianCoreTests
            .appendingPathComponent("MeridianTestSpecs")
            .appendingPathComponent(file)
    }

    @Test("each Wave 2 spec compiles and satisfies its assertions",
          arguments: [
            "wave2_2a_boolean.meridian.test",
            "wave2_2b_definitions.meridian.test",
            "wave2_2c_quantifiers.meridian.test",
          ])
    func specPasses(_ file: String) throws {
        let spec = try MeridianTestRunner().loadSpec(specURL(file))
        switch MeridianTestRunner().run(spec) {
        case .success:
            break
        case .failure(let reasons):
            Issue.record(Comment(rawValue: "\(file) failed:\n\(reasons.joined(separator: "\n"))"))
        case .skipped(let reason):
            Issue.record(Comment(rawValue: "\(file) was skipped: \(reason ?? "")"))
        }
    }
}
