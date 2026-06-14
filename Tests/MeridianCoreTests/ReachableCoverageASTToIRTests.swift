import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Phase 3: ASTToIR lowering coverage. Each cluster is a crafted compile —
// valid-but-rare lowering shapes plus malformed inputs that exercise the
// semantic-error guards (relation/verb validation, malformed-expression
// detection, Wave-3 relational lowering). These are the dominant remaining
// gap in the lowering layer.

@Suite("Reachable coverage — ASTToIR lowering")
struct ReachableCoverageASTToIRTests {

    private func compile(_ mer: String, _ cfg: String, trace: ParserTrace = .silent()) throws -> String {
        try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: trace
        )).compile(
            meridianSource: mer, meridianFile: "t.meridian",
            merconfigSource: cfg, merconfigFile: "t.merconfig"
        )
    }

    private func expectThrows(_ mer: String, _ cfg: String, _ label: String) {
        do {
            _ = try compile(mer, cfg)
            Issue.record("\(label): expected the compile to throw")
        } catch {
            // expected
        }
    }

    private let trivialWorkflow = """
    ---
    vocabulary: t.merconfig
    ---
    To run:
      complete with reason "ok".
    """

    // MARK: Fallback policy — lenient drop branches + describeRule/ruleLine

    @Test("allow-fallbacks lenient mode logs unparseable + unattached rules")
    func fallbackLenient() throws {
        let cap = ParserTrace.capturing()
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        A customer is a kind of thing.
        """
        // An unattached invariant (its noun matches no workflow) + a trigger
        // whose action doesn't resolve. With the policy relaxed both become
        // logged drops rather than hard errors.
        let mer = """
        ---
        vocabulary: t.merconfig
        allow-fallbacks: unattached-rules, unresolved-trigger-actions, unresolved-phrases
        ---
        An order must not be tampered.
        When a refund is requested, process the refund.

        To greet a customer:
          complete with reason "hi".
        """
        _ = try compile(mer, cfg, trace: cap.trace)
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("did not attach") || $0.contains("allow-fallbacks") })
    }

    // MARK: Relation / verb validation errors (validateRelationsAndVerbs)

    @Test("backing for an undeclared relation is a hard error")
    func backingUndeclaredRelation() {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page has an owner, which is a String.
        Ownership is read from the page's owner.
        """
        expectThrows(trivialWorkflow, cfg, "backing-undeclared-relation")
    }

    @Test("verb naming an undeclared relation is a hard error")
    func verbUndeclaredRelation() {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        The verb to own (it owns, it is owned) means the ownership relation.
        """
        expectThrows(trivialWorkflow, cfg, "verb-undeclared-relation")
    }

    @Test("verb on a relation with no backing is a hard error")
    func verbNoBacking() {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        Ownership relates one user to various pages.
        The verb to own (it owns, it is owned) means the ownership relation.
        """
        expectThrows(trivialWorkflow, cfg, "verb-no-backing")
    }

    @Test("backing reading an undeclared property is a hard error")
    func backingUnknownProperty() {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.
        Ownership relates one user to various pages.
        Ownership is read from the page's nonexistent.
        """
        expectThrows(trivialWorkflow, cfg, "backing-unknown-property")
    }

    @Test("backing read from a kind that is not a relation side is a hard error")
    func backingWrongKind() {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A deal is a kind of thing.
        A deal has an owner, which is a String.
        Ownership relates one user to various pages.
        Ownership is read from the deal's owner.
        """
        expectThrows(trivialWorkflow, cfg, "backing-wrong-kind")
    }

    @Test("tool-backed relation with an undeclared tool is a hard error")
    func toolBackingUndeclared() {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        An entity is a kind of thing.
        Mentioning relates various pages to various entities.
        Mentioning is read via the link tool.
        """
        expectThrows(trivialWorkflow, cfg, "tool-backing-undeclared")
    }

    // MARK: Wave-3 relational lowering — inline-position errors

    private let relCfg = """
    === vocabulary ===
    A user is a kind of thing.
    A user has a name, which is a String.
    A user has a task, which is a String.
    A page is a kind of thing.
    A page has an owner, which is a String.
    A page has a view count, which is a Number.
    An entity is a kind of thing.
    An entity has a name, which is a String.
    Ownership relates one user to various pages.
    Ownership is read from the page's owner.
    The verb to own (it owns, it is owned) means the ownership relation.
    Assignment relates one user to one task.
    Assignment is read from the user's task.
    The verb to assign (it assigns, it is assigned) means the assignment relation.
    Mentioning relates various pages to various entities.
    Mentioning is read via the link tool.
    The verb to mention (it mentions, it is mentioned) means the mentioning relation.
    Definition: a page is stale if its view count is less than 100.
    === tools ===
    Link
    ====
    ~ link(entity: String) : List
    """

    @Test("a relation operand out of scope is a hard error")
    func operandOutOfScope() {
        // `the user` is never a parameter or bind here → operand-scope guard.
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run:
          let owned be the pages owned by the user.
          emit x.done with pages = owned.
        """
        expectThrows(mer, relCfg, "operand-out-of-scope")
    }

    @Test("a tool-backed description in inline position is a hard error")
    func toolBackedInline() {
        // `the pages that mention the entity` is tool-backed (Mentioning via
        // link) → cannot be used inline in a condition; must be a bind/let.
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To find for an entity:
          if the number of pages that mention the entity is more than 5,
            complete with reason "many".
        """
        expectThrows(mer, relCfg, "tool-backed-inline")
    }

    @Test("Wave-3 relational workflow lowers descriptions, aggregates, superlatives")
    func wave3WorkflowLowers() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To audit a page for a user:
          let owned be the pages owned by the user.
          let count be the number of stale pages.
          let recent be the most recent page.
          let assigned be the task assigned to the user.
          if the user owns the page,
            emit ownership.confirmed with owner = the user's name.
        """
        let swift = try compile(mer, relCfg)
        #expect(swift.contains("struct"))
    }

    // MARK: firstMalformed — malformed sub-expression inside containers

    @Test("malformed predicate inside a description where-clause aborts lowering")
    func malformedInDescription() {
        // Mixed top-level and/or without `either` → `.malformed`, nested inside
        // the description's where-predicate → firstMalformedInDescription path.
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          let owned be the pages whose owner is "a" and owner is "b" or owner is "c".
          emit x.done with pages = owned.
        """
        expectThrows(mer, relCfg, "malformed-in-description")
    }

    // MARK: Phrase inlining — substituteArgs / subExpr / subDescription over Wave-3

    @Test("inlining a Wave-3 phrase substitutes through descriptions/aggregates/superlatives")
    func wave3PhraseInlining() throws {
        // A phrase whose body uses passive descriptions, an aggregate, a
        // superlative, scalar nav, and a possessive — invoked with a parameter
        // so substituteArgs/subExpr/subDescription recurse over each form.
        // Phrase definitions live inside `=== vocabulary ===` (there is no
        // separate phrases section), so the phrase must precede `=== tools ===`.
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A user has a name, which is a String.
        A user has a task, which is a String.
        A page is a kind of thing.
        A page has an owner, which is a String.
        A page has a view count, which is a Number.
        Ownership relates one user to various pages.
        Ownership is read from the page's owner.
        The verb to own (it owns, it is owned) means the ownership relation.
        Assignment relates one user to one task.
        Assignment is read from the user's task.
        The verb to assign (it assigns, it is assigned) means the assignment relation.
        Definition: a page is stale if its view count is less than 100.

        To summarize the activity of a user:
          let owned be the pages owned by the user.
          let count be the number of stale pages.
          let recent be the most recent page.
          let assigned be the task assigned to the user.
          emit summary.done with owner = the user's name, total = count.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run for a user:
          summarize the activity of the user.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("summary.done") || swift.contains("struct"))
    }

    @Test("while/until loops and recover handlers lower")
    func loopsAndRecover() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        An order has a total, which is Money.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run an order:
          while the total is more than 0,
            rebind total = 0.
          until the total is 0,
            rebind total = 0.
          complete with reason "x".
          recover from "x.failed":
            complete with reason "recovered".
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("struct"))
    }

    @Test("malformed condition inside a branch aborts lowering")
    func malformedInBranch() {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        An order has a total, which is Money.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run an order:
          if the total is 1 and the total is 2 or the total is 3,
            complete with reason "x".
        """
        expectThrows(mer, cfg, "malformed-in-branch")
    }
}
