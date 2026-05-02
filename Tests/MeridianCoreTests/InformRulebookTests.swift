import Testing
@testable import MeridianCore

@Suite("Inform-style rulebooks")
struct InformRulebookTests {

    @Test("representative Inform phases parse with deterministic order")
    func parseRulebookPhases() {
        let rules = [
            RuleAST(text: "report taking inventory: say what was found; continue.", sourceLine: 6),
            RuleAST(text: "before taking inventory: prepare the inventory list; continue.", sourceLine: 1),
            RuleAST(text: "instead of taking inventory: stop.", sourceLine: 2),
            RuleAST(text: "check taking inventory: fail if the inventory is locked.", sourceLine: 3),
            RuleAST(text: "carry out taking inventory: collect items; success.", sourceLine: 4),
            RuleAST(text: "after taking inventory: emit inventory.done; continue.", sourceLine: 5)
        ]

        let parsed = InformRulebookParser().parse(rules)
        #expect(parsed.map(\.phase) == [.before, .instead, .check, .carryOut, .after, .report])
        #expect(parsed[1].outcome == .stopRulebook)
        #expect(parsed[2].outcome == .failure)
        #expect(parsed[3].outcome == .success)
    }

    @Test("non-rulebook rules are ignored by clean-room parser")
    func ignoresOtherRules() {
        let parsed = InformRulebookParser().parse([
            RuleAST(text: "An order must not be charged when blocked.", sourceLine: 1)
        ])
        #expect(parsed.isEmpty)
    }
}
