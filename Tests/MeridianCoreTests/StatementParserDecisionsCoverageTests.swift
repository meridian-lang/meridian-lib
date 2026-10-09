import Foundation
import Testing
@testable import MeridianCore

/// Coverage for `StatementParser+Decisions` — judgment body collection paths,
/// autonomy non-block form, choice-gate nil guards, and choice-branch skips
/// that end-to-end fixtures rarely hit in isolation.
@Suite("StatementParser+Decisions coverage")
struct StatementParserDecisionsCoverageTests {

    private let parser = StatementParser(symbols: SymbolTable())

    private func parse(_ source: String) throws -> ASTBlock {
        try parser.parseBlock(IndentTokenizer().tokenize(source))
    }

    // MARK: - Judgment marker

    @Test("judgment follow-collect skips blanks/comments until a heading")
    func judgmentFollowCollectSkips() throws {
        let block = try parse("""
        ## Decision

        use judgment to follow the Decision guidance:

        step one

        # comment

        step two
        ## Next heading
        """)
        // The follow-collect path runs under a `##` heading context; we just
        // assert the block parsed without error and produced a prose step.
        #expect(block.statements.count >= 1)
    }

    @Test("judgment effectful cue without producing raises judgmentWithoutProducedValue")
    func judgmentEffectfulWithoutProducing() throws {
        #expect(throws: CompilerError.self) {
            _ = try parse("use judgment to delete the record.")
        }
        do {
            _ = try parse("use judgment to delete the record.")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .judgmentWithoutProducedValue })
        }
    }

    @Test("autonomy non-block single-line form trims without colon")
    func autonomyNonBlockTrim() throws {
        // `with autonomy <opts>` (no trailing colon) — the ternary false-branch
        // trims without dropping `:`.
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "with autonomy until ready",
                       raw: "with autonomy until ready", number: 1),
            SourceLine(indent: 2, text: "let x be 1.", raw: "let x be 1.", number: 2),
        ]
        let result = try parser.parseJudgmentMarker(src, at: 0, sourceFile: "t.meridian")
        guard let (stmt, _) = result,
              case .proseStep(let step) = stmt,
              step.dispatch == .autonomy else {
            Issue.record("expected autonomy proseStep"); return
        }
        #expect(step.autonomy != nil)
    }

    @Test("discretion block skips blanks in body")
    func discretionBlockSkipsBlanks() throws {
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "with discretion:", raw: "with discretion:", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# think", raw: "# think", number: 3),
            SourceLine(indent: 2, text: "figure it out.", raw: "figure it out.", number: 4),
        ]
        let result = try parser.parseJudgmentMarker(src, at: 0, sourceFile: "t.meridian")
        guard let (stmt, _) = result, case .proseStep(let step) = stmt else {
            Issue.record("expected discretion proseStep"); return
        }
        #expect(step.text.contains("figure it out"))
    }

    // MARK: - Choice gate

    @Test("choice gate with no options returns nil")
    func choiceGateEmptyOptions() {
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "ask the user to choose between:",
                       raw: "ask the user to choose between:", number: 1),
            SourceLine(indent: 0, text: "let x be 1.", raw: "let x be 1.", number: 2),
        ]
        #expect(parser.parseChoiceGate(src, at: 0) == nil)
    }

    @Test("collectChoiceOptions skips blanks and stops at shallower indent")
    func collectChoiceOptionsSkipsAndStops() {
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "ask the user to choose between:",
                       raw: "ask the user to choose between:", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# opt", raw: "# opt", number: 3),
            SourceLine(indent: 2, text: "1. First", raw: "1. First", number: 4),
            SourceLine(indent: 2, text: "", raw: "", number: 5),
            SourceLine(indent: 2, text: "- Second", raw: "- Second", number: 6),
            SourceLine(indent: 0, text: "let x be 1.", raw: "let x be 1.", number: 7),
        ]
        let result = parser.parseChoiceGate(src, at: 0)
        #expect(result != nil)
        if case .choice(_, let opts) = result?.statement.condition {
            #expect(opts.count == 2)
        } else {
            Issue.record("expected choice condition with 2 options")
        }
    }

    @Test("choiceOptionValue returns nil for empty stripped text")
    func choiceOptionValueEmptyStripped() {
        // `stripMarkdownListMarker` returns empty → choiceOptionValue returns nil
        // when no quote or number matched. Feed a whitespace-only string.
        #expect(parser.choiceOptionValue("   ") == nil)
    }

    // MARK: - Choice branch

    @Test("parseChoiceBranch skips blanks in body")
    func parseChoiceBranchSkipsBlanks() throws {
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "if the user picks 1:", raw: "if the user picks 1:", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# do", raw: "# do", number: 3),
            SourceLine(indent: 2, text: "let x be 1.", raw: "let x be 1.", number: 4),
        ]
        let result = try parser.parseChoiceBranch(src, at: 0, sourceFile: "t.meridian")
        guard let (stmt, _) = (result.map { ($0.statement, $0.consumed) }) else {
            Issue.record("expected choice branch"); return
        }
        #expect(stmt.thenBlock.statements.count == 1)
    }

    @Test("choiceBranchSelection returns nil for empty pick value")
    func choiceBranchSelectionEmptyPick() {
        #expect(parser.choiceBranchSelection("the user picks ") == nil)
        #expect(parser.choiceBranchSelection("the user picks yes") == "yes")
        #expect(parser.choiceBranchSelection("yes") == "yes")
        #expect(parser.choiceBranchSelection("no") == "no")
        #expect(parser.choiceBranchSelection("unknown") == nil)
    }
}
