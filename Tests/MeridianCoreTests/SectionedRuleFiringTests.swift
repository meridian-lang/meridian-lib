import Testing
import Foundation
@testable import MeridianCore

// Phase 0B coverage: Phase-8 rule sugar (`must not` / `may` [+ bounded `up to
// N`] / `must be … by … before` / `When …, …`) now fires inside executable
// sections of a sectioned (heading-bearing) skill document, exactly like it
// already did at the top level of a heading-less `.meridian`/`.meri` file.
// Prose stays prose only when it is explicitly opted out via
// `(( role: reference ))` / `(( inert ))` or a `#`/`>` comment — never
// inferred from "looks like a rule".

@Suite("Sectioned rule firing (Phase 0B)")
struct SectionedRuleFiringTests {

    private func parse(_ source: String, file: String = "skill.meri") throws -> MeridianFile {
        try MeridianParser(symbols: SymbolTable(), trace: .silent()).parse(source, file: file)
    }

    // MARK: - Extraction: each rule shape is mined from an executable section

    @Test("must not → extracted as a rule from a Phases section, not left as a procedure statement")
    func mustNotExtractedFromProcedureSection() throws {
        let ast = try parse("""
        ## Phases
        A customer with status suspended must not place orders.
        complete.
        """)
        #expect(ast.rules.count == 1)
        #expect(ast.rules.first?.text.contains("must not place orders") == true)
        // The rule text must NOT also survive as a procedure statement — it
        // attaches once via RuleInjector, not twice.
        #expect(ast.workflows.first?.body.statements.count == 1)
    }

    @Test("may (bounded, up to N) → extracted as a rule from a Phases section")
    func boundedMayExtractedFromProcedureSection() throws {
        let ast = try parse("""
        ## Phases
        An account manager may approve any order whose total amount is at most $10000.
        complete.
        """)
        #expect(ast.rules.count == 1)
        #expect(ast.rules.first?.text.lowercased().contains("may approve") == true)
    }

    @Test("must be … by … before → extracted as a rule from an invariants-role section")
    func approvalBeforeExtractedFromInvariantsSection() throws {
        let ast = try parse("""
        ## Contract
        An order with total amount more than the high value threshold must be approved by an account manager before fulfillment.

        ## Phases
        complete.
        """)
        #expect(ast.rules.count == 1)
        #expect(ast.rules.first?.text.contains("must be approved by") == true)
    }

    @Test("When …, … → extracted as a trigger rule, statement position always wins")
    func whenTriggerExtractedFromProcedureSection() throws {
        let ast = try parse("""
        ## Phases
        When an order has been on hold for more than 7 days, escalate the order.
        complete.
        """)
        #expect(ast.rules.count == 1)
        #expect(ast.rules.first?.text.hasPrefix("When ") == true)
    }

    // MARK: - Precision guard: ordinary narrative is never hijacked

    @Test("ordinary narrative statement is not hijacked as a rule")
    func ordinaryNarrativeNotHijacked() throws {
        let ast = try parse("""
        ## Phases
        An audit note about the page.
        complete.
        """)
        #expect(ast.rules.isEmpty)
        #expect(ast.workflows.first?.body.statements.count == 2)
    }

    @Test("inline if/unless/only-when conditionals are not rules — only statement-position When…, is")
    func inlineConditionalsAreNotRules() throws {
        let ast = try parse("""
        ## Phases
        If the order total is more than 100, apply a discount.
        complete.
        """)
        #expect(ast.rules.isEmpty, "an 'If …,' inline conditional must stay an ordinary statement, not a rule")
    }

    @Test("applicability dispatch-phrase bullets starting with When are not hijacked as triggers")
    func applicabilityWhenBulletNotHijacked() throws {
        // A `## When To Use` bullet is a dispatch-phrase FRAGMENT (no action
        // clause) — trialing it against RuleAnalyzer would false-positive
        // match the "When …," trigger shape and swallow legitimate dispatch
        // phrase mining. Confirmed against the gbrain blast-radius spike
        // (eiirp.meri "## When to Use" — see IMPLEMENTATION_LOG.md).
        let ast = try parse("""
        ## When to Use
        - When the user says "organize this", "clean this up", "make this tidy".

        ## Phases
        complete.
        """)
        #expect(ast.rules.isEmpty)
        let whenToUse = try #require(ast.skillSections.first { $0.heading == "When to Use" })
        #expect(whenToUse.role == "applicability")
        #expect(whenToUse.executes)
    }

    @Test("a section wrapped in 'use judgment to follow … guidance:' never yields rules, even with a When-shaped guidance bullet")
    func judgmentWrappedGuidanceNotHijacked() throws {
        // `collectUntilNextHeading` swallows every following line (regardless
        // of indentation) as guidance text for the single judgment step. A
        // same-indent "When …," guidance bullet must stay guidance prose, not
        // become an independent trigger (confirmed against the gbrain
        // blast-radius spike — query.meri "## Citation in Answers").
        let ast = try parse("""
        ## Citation Guidance (( role: reference ))
        Ignored narrative.

        ## Steps
        use judgment to follow the Citation Guidance guidance:
        - When you synthesize across multiple pages, cite all sources.

        ## Phases
        complete.
        """)
        #expect(ast.rules.isEmpty)
    }

    // MARK: - Prose opt-out: (( role: reference )), (( inert )), #, >

    @Test("(( role: reference )) section content is never classified as a rule")
    func referenceMarkedSectionIsNotARule() throws {
        let ast = try parse("""
        ## Anti-Patterns (( role: reference ))
        A customer with status suspended must not place orders.

        ## Phases
        complete.
        """)
        #expect(ast.rules.isEmpty)
    }

    @Test("(( inert )) section content is never classified as a rule")
    func inertMarkedSectionIsNotARule() throws {
        let ast = try parse("""
        ## Background (( inert ))
        When an order has been on hold for more than 7 days, escalate the order.

        ## Phases
        complete.
        """)
        #expect(ast.rules.isEmpty)
    }

    @Test("a #-commented rule-shaped line is never classified as a rule")
    func hashCommentedRuleIsNotARule() throws {
        let ast = try parse("""
        ## Phases
        # A customer with status suspended must not place orders.
        complete.
        """)
        #expect(ast.rules.isEmpty)
    }

    @Test("a >-blockquoted rule-shaped line is never classified as a rule")
    func blockquotedRuleIsNotARule() throws {
        let ast = try parse("""
        ## Phases
        > A customer with status suspended must not place orders.
        complete.
        """)
        #expect(ast.rules.isEmpty)
    }

    // MARK: - Full pipeline: extracted rules attach and lower to the right IR

    private let vocab = """
    === vocabulary ===
    customer is a kind of thing.
    customer has properties:
      status: Text.
    order is a kind of thing.
    order has properties:
      total_amount: Money.
    account manager is a kind of thing.
    """

    @Test("must not (sectioned) injects an AssertIR into the matching implicit workflow")
    func mustNotSectionedInjectsAssert() throws {
        let mer = """
        ---
        name: place order
        parameters: customer
        vocabulary: test.merconfig
        ---
        ## Phases
        A customer with status suspended must not place orders.
        complete.
        """
        let out = try Compiler(options: .init()).compile(
            meridianSource: mer, meridianFile: "test.meri",
            merconfigSource: vocab, merconfigFile: "test.merconfig"
        )
        #expect(out.contains("assert") || out.contains("Assert"),
                Comment(rawValue: "Expected an assert in:\n\(String(out.prefix(3000)))"))
    }

    @Test("bounded permission (sectioned) injects an AssertIR gate into the matching workflow")
    func boundedPermissionSectionedInjectsGate() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        ## Phases
        An account manager may approve any order whose total amount is at most $10000.
        complete.

        To approve an order:
          complete with reason "approved".
        """
        let out = try Compiler(options: .init()).compile(
            meridianSource: mer, meridianFile: "test.meri",
            merconfigSource: vocab, merconfigFile: "test.merconfig"
        )
        #expect(out.contains("runtime.assert"),
                Comment(rawValue: "Expected a runtime.assert (gate) in:\n\(String(out.prefix(3000)))"))
        #expect(out.contains("10000") || out.contains("10_000"),
                Comment(rawValue: "Expected the $10000 cap to appear in:\n\(String(out.prefix(3000)))"))
        #expect(out.contains("Permission required"),
                Comment(rawValue: "Expected 'Permission required' message in:\n\(String(out.prefix(3000)))"))
    }

    @Test("When …, … (sectioned) synthesizes a trigger workflow with a WaitIR")
    func whenTriggerSectionedSynthesizesWorkflow() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        ## Phases
        When a refund is requested, notify the customer.
        complete.

        To notify a customer:
          complete.
        """
        let out = try Compiler(options: .init()).compile(
            meridianSource: mer, meridianFile: "test.meri",
            merconfigSource: vocab, merconfigFile: "test.merconfig"
        )
        #expect(out.contains("wait") || out.contains("Wait"),
                Comment(rawValue: "Expected wait in:\n\(String(out.prefix(3000)))"))
        #expect(out.contains("NotifyCustomer") || out.contains("notify"),
                Comment(rawValue: "Expected trigger to lower notify-action in:\n\(String(out.prefix(3000)))"))
    }

    @Test("a non-trigger rule with no matching implicit workflow raises unattachedRule")
    func unattachedRuleRaisesStrictError() {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        ## Phases
        A customer with status suspended must not levitate.
        complete.
        """
        #expect(throws: (any Error).self) {
            try Compiler(options: .init()).compile(
                meridianSource: mer, meridianFile: "test.meri",
                merconfigSource: self.vocab, merconfigFile: "test.merconfig"
            )
        }
    }
}
