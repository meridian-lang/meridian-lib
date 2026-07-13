import Foundation
import Testing
@testable import MeridianCore

@Suite("Final Wave SEM-2 foundation (SEM-2-01..07)")
struct FinalWaveSEM2FoundationTests {
    private static let wave3Vocab = """
    === vocabulary ===
    A user is a kind of thing.
    A page is a kind of thing.
    A page has an owner, which is String.
    A task is a kind of thing.
    A task has an assignee, which is String.
    Ownership relates one user to various pages.
    Ownership is read from the page's owner.
    The verb to own (it owns, it is owned) means the ownership relation.
    Assignment relates one user to one task.
    Assignment is read from the task's assignee.
    The verb to assign (it assigns, it is assigned) means the assignment relation.
    Mentioning relates various pages to various entities.
    Mentioning is read via the link tool.

    === tools ===
    Link Tool
    =========
    ~ link(entity: String, page: Page) : Boolean

    Escalate Tool
    =============
    ~ escalate(task: Task) : User
    """

    private func compile(_ mer: String) throws -> String {
        try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: mer,
            meridianFile: "sem2.meridian",
            merconfigSource: Self.wave3Vocab,
            merconfigFile: "sem2.merconfig"
        )
    }

    @Test("SEM_2_01 tool-backed quantifier hoists a single fetch invoke")
    func sem201SingleFetch() throws {
        let out = try compile("""
        ---
        name: audit
        parameters: user
        vocabulary: sem2.merconfig
        ---
        To audit a user:
          bind pages = invoke link with entity = the user's id.
          if no pages owned by the user,
            complete with reason "orphaned".
        """)
        let invokeCount = out.components(separatedBy: "tool: \"link\"").count - 1
        #expect(invokeCount == 1, Comment(rawValue: "expected one link fetch, got \(invokeCount) in:\n\(out)"))
    }

    @Test("SEM_2_02 property access lowers to member projection, not a default")
    func sem202PropertyAccessProjection() throws {
        let out = try compile("""
        ---
        name: review
        parameters: page
        vocabulary: sem2.merconfig
        ---
        To review a page:
          if the page's owner equals "alice",
            complete with reason "owned".
        """)
        #expect(out.contains("page.owner"), Comment(rawValue: out))
        #expect(!out.contains("?? .string(\"alice\")"), Comment(rawValue: "must not silently default missing values"))
    }

    @Test("SEM_2_03 decimal literals lower through exact Decimal arithmetic")
    func sem203ExactDecimalArithmetic() throws {
        let out = try compile("""
        ---
        name: check
        vocabulary: sem2.merconfig
        ---
        To check decimals:
          bind left = 0.1.
          bind right = 0.2.
          bind sum = 0.3.
          if left + right equals sum,
            complete with reason "exact".
        """)
        #expect(out.contains("Decimal(\"0.1\")") || out.contains("Decimal(0.1)"), Comment(rawValue: out))
        #expect(out.contains("MeridianComparison"), Comment(rawValue: out))
    }

    @Test("SEM_2_04 mixed and/or without grouping is ill-formed")
    func sem204MixedBooleanIllFormed() {
        let parsed = ExpressionParser(symbols: nil, trace: .silent(), lexicon: .default)
            .parse("a is 1 and b is 2 or c is 3")
        if case .malformed = parsed {
            // expected
        } else {
            Issue.record("expected malformed AST for mixed and/or, got \(parsed)")
        }
    }

    @Test("SEM_2_05 recursive definition is a hard error")
    func sem205AcyclicDefinitions() {
        #expect(throws: (any Error).self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: """
                ---
                name: review
                parameters: page
                vocabulary: t.merconfig
                ---
                Definition: a page is stale if it is stale.

                To review a page:
                  if the page is stale,
                    complete with reason "x".
                """,
                meridianFile: "cycle.meridian",
                merconfigSource: """
                === vocabulary ===
                A page is a kind of thing.
                """,
                merconfigFile: "t.merconfig"
            )
        }
    }

    @Test("SEM_2_06 subkind inherits parent adjective definitions")
    func sem206InheritanceShadowing() throws {
        let out = try compile("""
        ---
        name: review
        parameters: blog page
        vocabulary: sem2.merconfig
        ---
        Definition: a page is stale if its owner is empty.

        To review a blog page:
          if the blog page is stale,
            complete with reason "stale".
        """)
        #expect(out.contains("meridianDef_Page_stale"), Comment(rawValue: out))
    }

    @Test("SEM_2_07 unbacked relation is ill-formed at compile time")
    func sem207UnbackedRelationRejected() {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        Ownership relates one user to various pages.
        The verb to own (it owns, it is owned) means the ownership relation.
        """
        #expect(throws: (any Error).self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: """
                ---
                name: audit
                parameters: user
                vocabulary: t.merconfig
                ---
                To audit a user:
                  if the user owns a page,
                    complete with reason "ok".
                """,
                meridianFile: "unbacked.meridian",
                merconfigSource: cfg,
                merconfigFile: "t.merconfig"
            )
        }
    }

}
