import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

/// Batch 3 (pure-helper slice): drives the small shared lowering/parsing helpers
/// to 100% — the empty-input/edge arms of Suggester, the Inform phase parser's
/// malformed-rule guards, the leaf literal/operator maps, the action-matcher
/// empty-stem short-circuit, the condition classifier's not/marker arms, the
/// section-role marker path, the frontmatter fence scanner, the markdown
/// importer fence body, and the verbose superlative trace rendering.

@Suite("Reachable coverage — batch 3 (pure helpers)")
struct ReachableCoverageBatch3Tests {

    @Test("Suggester edge arms: empty target, empty candidates, empty levenshtein operand")
    func suggesterEdges() {
        let s = Suggester()
        #expect(s.closest("", among: ["x"]) == nil)                 // empty target
        #expect(s.closest("abc", among: ["", "abd"]) == "abd")      // empty candidate skipped
        #expect(s.ranked("abc", among: ["", "abd"]) == ["abd"])     // empty candidate dropped
        #expect(Suggester.levenshtein("ab", "") == 2)               // empty second operand
        #expect(Suggester.levenshtein("", "ab") == 2)               // empty first operand
    }

    @Test("InformRulebook rejects phase rules lacking a colon or with empty action/body")
    func informRulebookGuards() {
        let rb = InformRulebookParser()
        #expect(rb.parse(RuleAST(text: "before something happens")) == nil)  // no colon
        #expect(rb.parse(RuleAST(text: "before : do thing")) == nil)          // empty action
        #expect(rb.parse(RuleAST(text: "before x:")) == nil)                  // empty body
        #expect(rb.parse(RuleAST(text: "nonphase action: body")) == nil)      // no phase prefix
        #expect(rb.parse(RuleAST(text: "before placing an order: check funds")) != nil)
    }

    @Test("LiteralLowering boolean literal + withinPast/withinFuture operator maps")
    func literalLowering() {
        if case .boolean(true) = LiteralLowering.toIRLiteral(.boolean(true)) {} else { Issue.record("bool") }
        #expect(LiteralLowering.mapComparisonOp(.withinPast) == .withinPast)
        #expect(LiteralLowering.mapComparisonOp(.withinFuture) == .withinFuture)
        #expect(LiteralLowering.mapLogicalOp(.not) == .not)
    }

    @Test("WorkflowActionMatcher returns 0 when the action has no content stems")
    func actionMatcherEmptyStems() {
        let wf = IRWorkflow(name: "process order", parameters: [], body: IRBlock(statements: []))
        #expect(WorkflowActionMatcher.overlap(
            action: "the of a an", workflow: wf, scope: .nameOnly, lexicon: .default) == 0)
    }

    @Test("ConditionClassifier: negated checkable predicate + comparison-marker condition")
    func conditionClassifier() {
        let cc = ConditionClassifier(symbols: nil, lexicon: .default, trace: .silent())
        let cmp = ExpressionAST.comparison(.literal(.integer(1)), .greaterThan, .literal(.integer(5)))
        #expect(cc.isCheckable(.logical(.not, [cmp])))         // .not arm (non-empty)
        #expect(cc.isCheckable(.logical(.not, [])) == false)   // .not arm (empty → ?? false)
        #expect(cc.readsAsCondition("amount more than 5"))     // comparison-marker arm (no copula)
    }

    @Test("SectionRoleResolver: authoritative executable marker decides executes")
    func sectionRoleResolver() {
        let marker = SkillSectionRole.SectionMarker(inert: false, role: .procedure)
        let d = SectionRoleResolver.decide(marker: marker, derivedRole: nil)
        #expect(d.executes)
        #expect(d.fromMarker)
        #expect(d.recordedRole == SkillSectionRole.procedure.rawValue)
        // Non-executable role marker → executes evaluates role?.isExecutable == false.
        let inertMarker = SkillSectionRole.SectionMarker(inert: false, role: .template)
        #expect(SectionRoleResolver.decide(marker: inertMarker, derivedRole: nil).executes == false)
    }

    @Test("FrontmatterScanner: leading-blank skip + missing-close-fence guard")
    func frontmatterScanner() {
        let withBlanks = ["", "  ", "---", "name: x", "---", "body"]
        #expect(FrontmatterScanner.locate(withBlanks, skipLeadingBlanks: true)?.open == 2)
        #expect(FrontmatterScanner.locate(["---", "name: x"], skipLeadingBlanks: false) == nil)  // no close
        #expect(FrontmatterScanner.locate(["nope"], skipLeadingBlanks: false) == nil)
    }

    @Test("SkillMarkdownImporter keeps meridian fence body lines")
    func markdownImporter() {
        // meridian + bare fences are kept; a non-meridian fence body is dropped.
        let md = "## Title\n```meridian\ndo the thing\n```\n```bash\nrm -rf /\n```\n```\nbare kept\n```\nplain\n"
        let out = SkillMarkdownImporter().preview(md)
        #expect(out.contains("do the thing"))
        #expect(out.contains("bare kept"))
        #expect(!out.contains("rm -rf"))
    }

    @Test("ExpressionTraceDescription renders verbose superlative")
    func superlativeTrace() {
        let maxSup = SuperlativeAST(
            description: DescriptionAST(noun: "pages"), property: "updatedAt", ascending: false)
        let maxDesc = ExpressionAST.superlative(maxSup).traceDescription(detail: .verbose)
        #expect(maxDesc.contains("max"))
        #expect(maxDesc.contains("updatedAt"))
        // ascending → the "min" sub-branch.
        let minSup = SuperlativeAST(
            description: DescriptionAST(noun: "pages"), property: "createdAt", ascending: true)
        #expect(ExpressionAST.superlative(minSup).traceDescription(detail: .verbose).contains("min"))
    }
}
