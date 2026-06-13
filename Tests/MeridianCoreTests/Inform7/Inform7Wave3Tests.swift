import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Coverage for the Wave 3 relational layer: relations + evaluation backing (3A),
// verbs (3B), and descriptions / aggregates / superlatives / scalar navigation
// plus the `let … be …` binder (3C). Parser-level tests assert AST shape;
// compile tests assert the lowered Swift query-plan; the spec driver and the
// examples round-trip exercise the whole pipeline end to end.

// Shared vocabulary for every Wave 3 suite: two property-backed relations
// (ownership / assignment), one tool-backed relation (mentioning), the verbs
// that name them, a checkable adjective, and the candidate-collection tools.
private let wave3Vocab = """
=== vocabulary ===
A user is a kind of thing.
A user has a name, which is a String.
A user has a task, which is a String.

A task is a kind of thing.
A task has a title, which is a String.

A page is a kind of thing.
A page has a title, which is a String.
A page has an owner, which is a String.
A page has a view count, which is a Number.
A page has an updated at, which is a Date.

An entity is a kind of thing.
An entity has a name, which is a String.

A deal is a kind of thing.
A deal has an amount, which is Money.
A deal has an owner, which is a String.

Ownership relates one user to various pages.
Ownership is read from the page's owner.
The verb to own (it owns, it is owned) means the ownership relation.

Assignment relates one user to one task.
Assignment is read from the user's task.
The verb to assign (it assigns, it is assigned) means the assignment relation.

Mentioning relates various pages to various entities.
Mentioning is read via the link tool.
The verb to mention (it mentions, it is mentioned) means the mentioning relation.

Escalation relates one task to one user.
Escalation is read via the escalate tool.
The verb to escalate (it escalates, it is escalated) means the escalation relation.

Definition: a page is popular if its view count is more than 1000.

=== tools ===

List Pages
==========
~ listPages(owner: String) : List

List Deals
==========
~ listDeals(owner: String) : List

Link
====
~ link(entity: String) : List

Escalate
========
~ escalate(task: String) : Record
"""

private func wave3Symbols() throws -> SymbolTable {
    let cfg = try MerConfigParser(trace: .silent()).parse(wave3Vocab, file: "w3.merconfig")
    return SymbolTable.build(from: cfg)
}

private func wave3Compile(_ mer: String) throws -> String {
    try Compiler().compile(
        meridianSource: mer, meridianFile: "w3.meridian",
        merconfigSource: wave3Vocab, merconfigFile: "w3.merconfig")
}

// MARK: - 3A. Relations + evaluation backing

@Suite("Wave 3A — relations + backing")
struct RelationBackingTests {

    @Test("a property backing is registered against its relation")
    func propertyBackingRegistered() throws {
        let sym = try wave3Symbols()
        guard case .property(let kind, let path)? = sym.backing(forRelation: "ownership") else {
            Issue.record("expected property backing for ownership"); return
        }
        #expect(kind == "page")
        #expect(path == "owner")
    }

    @Test("a tool backing is registered against its relation")
    func toolBackingRegistered() throws {
        let sym = try wave3Symbols()
        guard case .tool(let toolID)? = sym.backing(forRelation: "mentioning") else {
            Issue.record("expected tool backing for mentioning"); return
        }
        #expect(toolID == "link")
    }

    @Test("`various` is accepted as a many-cardinality and the kind is singularized")
    func variousIsMany() throws {
        let sym = try wave3Symbols()
        // Ownership relates one user to various pages — the relation resolves and
        // its backing references the singular `page` kind.
        #expect(sym.relation(named: "ownership") != nil)
        guard case .property(let kind, _)? = sym.backing(forRelation: "ownership") else {
            Issue.record("expected property backing"); return
        }
        #expect(kind == "page")   // `pages` → `page`, not `pag`
    }

    @Test("a verb that names a backing-less relation is a hard error")
    func verbNeedsBackedRelation() {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.
        Ownership relates one user to various pages.
        The verb to own (it owns, it is owned) means the ownership relation.
        """
        #expect(throws: (any Error).self) {
            _ = try Compiler().compile(
                meridianSource: """
                ---
                name: t
                parameters: user
                vocabulary: t.merconfig
                ---
                To handle a user:
                  complete with reason "x".
                """,
                meridianFile: "t.meridian", merconfigSource: cfg, merconfigFile: "t.merconfig")
        }
    }

    @Test("a property backing onto an unknown property is a hard error")
    func propertyBackingUnknownProperty() {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.
        Ownership relates one user to various pages.
        Ownership is read from the page's nonexistent.
        The verb to own (it owns, it is owned) means the ownership relation.
        """
        #expect(throws: (any Error).self) {
            _ = try Compiler().compile(
                meridianSource: """
                ---
                name: t
                parameters: user
                vocabulary: t.merconfig
                ---
                To handle a user:
                  complete with reason "x".
                """,
                meridianFile: "t.meridian", merconfigSource: cfg, merconfigFile: "t.merconfig")
        }
    }

    @Test("a tool backing naming an undeclared tool is a hard error")
    func toolBackingUnknownTool() {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        An entity is a kind of thing.
        Mentioning relates various pages to various entities.
        Mentioning is read via the nosuchtool tool.
        The verb to mention (it mentions, it is mentioned) means the mentioning relation.
        """
        #expect(throws: (any Error).self) {
            _ = try Compiler().compile(
                meridianSource: """
                ---
                name: t
                parameters: entity
                vocabulary: t.merconfig
                ---
                To handle an entity:
                  complete with reason "x".
                """,
                meridianFile: "t.meridian", merconfigSource: cfg, merconfigFile: "t.merconfig")
        }
    }

    @Test("relations and verbs are recorded in the manifest")
    func manifestRecordsRelationsAndVerbs() throws {
        let (_, input) = try Compiler().compileWithManifest(
            meridianSource: """
            ---
            name: verify
            parameters: user, page
            vocabulary: w3.merconfig
            ---
            To verify a page for a user:
              if the user owns the page,
                complete with reason "ok".
            """,
            meridianFile: "w3.meridian",
            vocabularies: [.init(name: "w3", file: "w3.merconfig", source: wave3Vocab)])
        let json = try ManifestEmitter().emit(input)
        #expect(json.contains("meridian_relations"), Comment(rawValue: json))
        #expect(json.contains("meridian_verbs"), Comment(rawValue: json))
        #expect(json.contains("\"ownership\""), Comment(rawValue: json))
    }
}

// MARK: - 3B. Verbs

@Suite("Wave 3B — verbs")
struct VerbTests {

    @Test("a verb declares all three conjugations")
    func verbForms() throws {
        let sym = try wave3Symbols()
        guard let v = sym.verbs["own"] else { Issue.record("expected verb to own"); return }
        #expect(v.thirdPerson == "owns")
        #expect(v.pastParticiple == "owned")
        #expect(v.relation == "ownership")
    }

    @Test("resolveVerbForm maps each conjugation to its role")
    func resolveForms() throws {
        let sym = try wave3Symbols()
        #expect(sym.resolveVerbForm("own")?.role == .base)
        #expect(sym.resolveVerbForm("owns")?.role == .thirdPerson)
        #expect(sym.resolveVerbForm("owned")?.role == .pastParticiple)
        #expect(sym.resolveVerbForm("unrelated") == nil)
    }

    @Test("an active verb condition parses to a verbPredicate")
    func activeVerbParses() throws {
        let sym = try wave3Symbols()
        let expr = ExpressionParser(symbols: sym, trace: .silent()).parse("the user owns the page")
        guard case .verbPredicate(_, let verb, _) = expr else {
            Issue.record("expected verbPredicate, got \(expr)"); return
        }
        #expect(verb == "owns")
    }

    @Test("a relativizer before a verb is NOT a top-level active predicate")
    func relativizerIsNotActive() throws {
        let sym = try wave3Symbols()
        // `pages that mention …` is a description's relative clause, not a
        // subject-verb-object condition.
        let expr = ExpressionParser(symbols: sym, trace: .silent()).parse("the pages that mention the entity")
        if case .verbPredicate = expr {
            Issue.record("relative clause should not be a verbPredicate")
        }
    }

    @Test("a property-backed active verb lowers to MeridianComparison.identifies")
    func activeVerbEmitsIdentifies() throws {
        let out = try wave3Compile("""
        ---
        name: verify
        parameters: user, page
        vocabulary: w3.merconfig
        ---
        To verify a page for a user:
          if the user owns the page,
            complete with reason "ok".
        """)
        #expect(out.contains("MeridianComparison.identifies(state.get(\"page.owner\"), state.get(\"user\"))"),
                Comment(rawValue: out))
    }

    @Test("a negated active verb (`does not own`) parses to not(verbPredicate)")
    func negatedActiveVerbParses() throws {
        let sym = try wave3Symbols()
        let expr = ExpressionParser(symbols: sym, trace: .silent()).parse("the user does not own the page")
        guard case .logical(let op, let operands) = expr, op == .not, operands.count == 1,
              case .verbPredicate(_, let verb, _) = operands[0] else {
            Issue.record("expected not(verbPredicate), got \(expr)"); return
        }
        #expect(verb == "own")
    }

    @Test("a negated property-backed verb in a branch emits a negated identifies guard")
    func negatedActiveVerbEmitsGuard() throws {
        let out = try wave3Compile("""
        ---
        name: verify
        parameters: user, page
        vocabulary: w3.merconfig
        ---
        To verify a page for a user:
          if the user does not own the page,
            complete with reason "no".
        """)
        #expect(out.contains("!(MeridianComparison.identifies(state.get(\"page.owner\"), state.get(\"user\")))"),
                Comment(rawValue: out))
    }

    @Test("a tool-backed active verb used inline is a hard error")
    func toolBackedActiveVerbInlineRejected() {
        #expect(throws: (any Error).self) {
            _ = try wave3Compile("""
            ---
            name: check
            parameters: page, entity
            vocabulary: w3.merconfig
            ---
            To check a page against an entity:
              if the page mentions the entity,
                complete with reason "x".
            """)
        }
    }
}

// MARK: - 3C. Descriptions, aggregates, superlatives, scalar navigation, let

@Suite("Wave 3C — descriptions & friends")
struct DescriptionTests3C {

    private func parse(_ s: String) throws -> ExpressionAST {
        ExpressionParser(symbols: try wave3Symbols(), trace: .silent()).parse(s)
    }

    @Test("a passive relation clause restricts a described collection")
    func passiveDescription() throws {
        guard case .description(let d) = try parse("the pages owned by the user") else {
            Issue.record("expected description"); return
        }
        #expect(d.noun == "pages")
        #expect(d.verbClauses.count == 1)
        #expect(d.verbClauses[0].elementIsSubject == false)
        #expect(d.verbClauses[0].verbForm == "owned")
    }

    @Test("a that-clause with an active verb is a subject-gap restriction")
    func thatClauseSubjectGap() throws {
        guard case .description(let d) = try parse("the pages that mention the entity") else {
            Issue.record("expected description"); return
        }
        #expect(d.verbClauses.count == 1)
        #expect(d.verbClauses[0].elementIsSubject == true)
    }

    @Test("the number of <desc> is a count aggregate")
    func countAggregate() throws {
        guard case .aggregate(.count, let d) = try parse("the number of popular pages") else {
            Issue.record("expected count aggregate"); return
        }
        #expect(d.adjectives == ["popular"])
    }

    @Test("the list of <desc> is a list aggregate")
    func listAggregate() throws {
        guard case .aggregate(.list, _) = try parse("the list of popular pages") else {
            Issue.record("expected list aggregate"); return
        }
    }

    @Test("a timestamp superlative defaults to the timestamp property")
    func timestampSuperlative() throws {
        guard case .superlative(let s) = try parse("the most recent page") else {
            Issue.record("expected superlative"); return
        }
        #expect(s.ascending == false)         // newest = max
        #expect(s.description.noun == "page")
    }

    @Test("a magnitude superlative requires a by-property")
    func magnitudeSuperlative() throws {
        guard case .superlative(let s) = try parse("the largest deal by amount") else {
            Issue.record("expected superlative"); return
        }
        #expect(s.property == "amount")
        #expect(s.ascending == false)
    }

    @Test("first N … sorted by … is a description with take and sort")
    func takeAndSort() throws {
        guard case .description(let d) = try parse("the first 3 pages sorted by view count descending") else {
            Issue.record("expected description"); return
        }
        #expect(d.take == 3)
        #expect(d.sort?.ascending == false)
    }

    @Test("scalar relation navigation parses to a relationTraversal")
    func scalarNav() throws {
        guard case .relationTraversal(_, let rel, _) = try parse("the task assigned to the user") else {
            Issue.record("expected relationTraversal"); return
        }
        #expect(rel == "assigned")
    }

    // --- emission ---

    @Test("a passive description lowers to a filtered list pipeline")
    func descriptionEmitsFilter() throws {
        let out = try wave3Compile("""
        ---
        name: audit
        parameters: user
        vocabulary: w3.merconfig
        ---
        To audit content for a user:
          bind pages = invoke list pages with owner = the user's id.
          let owned be the pages owned by the user.
          complete with reason "ok".
        """)
        #expect(out.contains(".filter { __e in"), Comment(rawValue: out))
        #expect(out.contains("MeridianComparison.identifies(__e.member(\"owner\")"), Comment(rawValue: out))
    }

    @Test("a superlative lowers to a sorted-then-first reduction")
    func superlativeEmitsSortedFirst() throws {
        let out = try wave3Compile("""
        ---
        name: rank
        parameters: user
        vocabulary: w3.merconfig
        ---
        To rank deals for a user:
          bind deals = invoke list deals with owner = the user's id.
          let biggest be the largest deal by amount.
          complete with reason "ok".
        """)
        #expect(out.contains(".sorted { __a, __b in MeridianComparison.orderedBefore(__a.member(\"amount\"), __b.member(\"amount\"), ascending: false) }.first"),
                Comment(rawValue: out))
    }

    @Test("a count aggregate emits a Decimal-wrapped count so it compares numerically")
    func countEmitsDecimal() throws {
        let out = try wave3Compile("""
        ---
        name: audit
        parameters: user
        vocabulary: w3.merconfig
        ---
        To audit content for a user:
          bind pages = invoke list pages with owner = the user's id.
          if the number of popular pages is more than 5,
            complete with reason "many".
        """)
        #expect(out.contains("Decimal(") && out.contains(".count)"), Comment(rawValue: out))
    }

    @Test("a tool-backed description hoists a prelude invoke before the bind")
    func toolBackedHoistsInvoke() throws {
        let out = try wave3Compile("""
        ---
        name: mentions
        parameters: entity
        vocabulary: w3.merconfig
        ---
        To find mentions for an entity:
          let mentioned be the pages that mention the entity.
          complete with reason "ok".
        """)
        // The link tool is invoked once and bound to a synthetic name, which the
        // description then reads.
        #expect(out.contains("runtime.invoke(") && out.contains("tool: \"link\""), Comment(rawValue: out))
        #expect(out.contains("state.bind(\"mentioned\""), Comment(rawValue: out))
    }

    @Test("let <name> be <value> lowers to a bind")
    func letBinder() throws {
        let out = try wave3Compile("""
        ---
        name: review
        parameters: user
        vocabulary: w3.merconfig
        ---
        To review the task of a user:
          let assigned be the task assigned to the user.
          complete with reason "ok".
        """)
        #expect(out.contains("state.bind(\"assigned\", state.get(\"user.task\"))"), Comment(rawValue: out))
    }

    @Test("a relation operand that is not in scope is a sourced error listing in-scope names")
    func operandOutOfScopeRejected() {
        // `the owner` is neither a parameter nor an earlier bind — it must be a
        // compile error, not a silent `state.get("owner") -> null` at runtime.
        let err = #expect(throws: CompilerError.self) {
            _ = try wave3Compile("""
            ---
            name: verify
            parameters: page
            vocabulary: w3.merconfig
            ---
            To verify a page:
              if the owner owns the page,
                complete with reason "ok".
            """)
        }
        if case .semanticError(let message, _)? = err {
            #expect(message.contains("not in scope"), Comment(rawValue: message))
            #expect(message.contains("In-scope names"), Comment(rawValue: message))
        }
    }

    @Test("an in-scope operand (parameter or earlier bind) passes validation")
    func operandInScopeAccepted() throws {
        let out = try wave3Compile("""
        ---
        name: verify
        parameters: user, page
        vocabulary: w3.merconfig
        ---
        To verify a page for a user:
          if the user owns the page,
            complete with reason "ok".
        """)
        #expect(out.contains("MeridianComparison.identifies("), Comment(rawValue: out))
    }

    @Test("an unknown verb suggests the nearest declared form")
    func unknownVerbSuggestsNearest() {
        // `owns` is declared; `owened` is a near-miss typo of the participle.
        let err = #expect(throws: CompilerError.self) {
            _ = try wave3Compile("""
            ---
            name: verify
            parameters: user, page
            vocabulary: w3.merconfig
            ---
            To verify a page for a user:
              let bad be the pages owened by the user.
              complete with reason "ok".
            """)
        }
        if case .semanticError(let message, _)? = err {
            #expect(message.contains("did you mean"), Comment(rawValue: message))
        }
    }

    @Test("tool-backed scalar navigation in a let hoists a single fetch invoke")
    func toolBackedScalarNavHoists() throws {
        let out = try wave3Compile("""
        ---
        name: escalate
        parameters: task
        vocabulary: w3.merconfig
        ---
        To escalate a task:
          let owner be the user escalated to the task.
          complete with reason "ok".
        """)
        // The escalate tool is invoked once, keyed by the operand kind (task),
        // and its single result is bound as the navigated-to value.
        #expect(out.contains("tool: \"escalate\""), Comment(rawValue: out))
        #expect(out.contains("state.bind(\"owner\""), Comment(rawValue: out))
    }
}

// MARK: - examples/relations round-trip

@Suite("Wave 3 — examples/relations round-trip")
struct RelationsExampleTests {

    private func exampleURL(_ file: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Inform7
            .deletingLastPathComponent()   // MeridianCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("examples")
            .appendingPathComponent(file)
    }

    @Test("examples/relations.meridian compiles cleanly with no _unresolved")
    func compiles() throws {
        let mer = try String(contentsOf: exampleURL("relations.meridian"), encoding: .utf8)
        let cfg = try String(contentsOf: exampleURL("relations.merconfig"), encoding: .utf8)
        let out = try Compiler().compile(
            meridianSource: mer, meridianFile: "relations.meridian",
            merconfigSource: cfg, merconfigFile: "relations.merconfig")
        #expect(!out.contains("_unresolved"), Comment(rawValue: out))
        #expect(out.contains("MeridianComparison.identifies("), Comment(rawValue: out))
        #expect(out.contains(".sorted { __a, __b in"), Comment(rawValue: out))
    }
}

// MARK: - End-to-end .meridian.test specs (3A / 3B / 3C)

@Suite("Wave 3 — .meridian.test specs")
struct Wave3SpecTests {

    private func specURL(_ file: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Inform7
            .deletingLastPathComponent()   // MeridianCoreTests
            .appendingPathComponent("MeridianTestSpecs")
            .appendingPathComponent(file)
    }

    @Test("each Wave 3 spec compiles and satisfies its assertions",
          arguments: [
            "wave3_3a_relations.meridian.test",
            "wave3_3b_verbs.meridian.test",
            "wave3_3c_descriptions.meridian.test",
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
