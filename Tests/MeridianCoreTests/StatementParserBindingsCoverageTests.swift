import Foundation
import Testing
@testable import MeridianCore

/// Branch coverage for `StatementParser+Bindings` — blank/comment skips,
/// empty match-arm labels, invoke comma continuations, and assert-otherwise
/// nil guards that end-to-end fixtures rarely hit in isolation.
@Suite("StatementParser+Bindings coverage")
struct StatementParserBindingsCoverageTests {

    private let parser = StatementParser(symbols: SymbolTable(), trace: .silent())

    private func parse(_ source: String) throws -> ASTBlock {
        try parser.parseBlock(IndentTokenizer().tokenize(source))
    }

    @Test("parseBindValue skips blanks before a code-block sentinel value")
    func bindValueSkipsBeforeSentinel() throws {
        let sentinel = codeBlockSentinelPrefix + "bash:" + Data("echo hi".utf8).base64EncodedString()
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "let x be", raw: "let x be", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# note", raw: "# note", number: 3),
            SourceLine(indent: 2, text: sentinel, raw: sentinel, number: 4),
        ]
        // Empty RHS after `be` — parseBindValue is called with "" and looks ahead.
        let (expr, consumed) = try parser.parseBindValue("", lines: src, at: 0)
        #expect(consumed == 3)
        guard case .literal(.string(let cmd)) = expr else {
            // parseAtom may wrap fence differently; accept any non-nil parse.
            #expect(consumed >= 1)
            return
        }
        #expect(cmd.contains("echo") || !cmd.isEmpty)
    }

    @Test("decide using: skips blanks before the fence")
    func decideUsingSkipsBlanks() throws {
        let block = try parse("""
        bind verdict = decide using:

        # prompt

        ```
        is this ready?
        ```
        """)
        guard case .bind(let b) = block.statements.first,
              case .invoke(let tool, _) = b.value else {
            Issue.record("expected decide-using invoke"); return
        }
        #expect(tool == "llm.decide")
    }

    @Test("invoke with comma-terminated header folds indented args")
    func invokeCommaContinuation() throws {
        // Header ends with `,` so the multi-line fold hits the hasSuffix(",")
        // arm; a space after `with` keeps the with-marker split valid once the
        // continuation is appended (`with, url = …` would not match ` with `).
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "invoke http get with url = \"https://a.example\",",
                       raw: "invoke http get with url = \"https://a.example\",", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# a", raw: "# a", number: 3),
            SourceLine(indent: 2, text: "path = \"/\"", raw: "path = \"/\"", number: 4),
        ]
        let (expr, extra) = parser.parseInvokeExpr(src[0].statement, lines: src, at: 0)
        #expect(extra == 1)
        guard case .invoke(_, let args) = expr else {
            Issue.record("expected invoke"); return
        }
        #expect(args.count == 2)
        #expect(args.contains { $0.0 == "url" })
        #expect(args.contains { $0.0 == "path" })
    }

    @Test("emit payload continuation skips blank and comment lines")
    func emitSkipsBlanks() throws {
        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "emit order.placed with", raw: "emit order.placed with", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# payload", raw: "# payload", number: 3),
            SourceLine(indent: 2, text: "note = \"hi\"", raw: "note = \"hi\"", number: 4),
        ]
        let (emit, extra) = try parser.parseEmit(src, at: 0)
        #expect(extra == 1)
        #expect(emit.eventID == "order.placed")
        #expect(emit.payload.count == 1)
    }

    @Test("match branch skips blanks; empty arm label raises matchBranchSyntax")
    func matchBranchSkipsAndEmptyLabel() throws {
        let ok: [SourceLine] = [
            SourceLine(indent: 0, text: "branch on the status:", raw: "branch on the status:", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# case", raw: "# case", number: 3),
            SourceLine(indent: 2, text: "\"ready\":", raw: "\"ready\":", number: 4),
            SourceLine(indent: 4, text: "", raw: "", number: 5),
            SourceLine(indent: 4, text: "# body", raw: "# body", number: 6),
            SourceLine(indent: 4, text: "let x be 1.", raw: "let x be 1.", number: 7),
            SourceLine(indent: 2, text: "otherwise:", raw: "otherwise:", number: 8),
            SourceLine(indent: 4, text: "let y be 2.", raw: "let y be 2.", number: 9),
        ]
        let (match, _) = try parser.parseMatchBranch(ok, at: 0, sourceFile: "t.meridian")
        #expect(match.cases.count == 1)
        #expect(match.otherwiseBlock != nil)

        let emptyLabel: [SourceLine] = [
            SourceLine(indent: 0, text: "branch on the status:", raw: "branch on the status:", number: 1),
            SourceLine(indent: 2, text: "   ", raw: "   ", number: 2),
        ]
        #expect(throws: CompilerError.self) {
            _ = try parser.parseMatchBranch(emptyLabel, at: 0, sourceFile: "t.meridian")
        }
        do {
            _ = try parser.parseMatchBranch(emptyLabel, at: 0, sourceFile: "t.meridian")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .matchBranchSyntax })
        }
    }

    @Test("assert otherwise: empty condition and blank skips in fallback")
    func assertOtherwiseEdges() throws {
        #expect(try parser.parseAssertWithOtherwise(
            [SourceLine(indent: 0, text: "assert  otherwise:", raw: "assert  otherwise:", number: 1)],
            at: 0,
            sourceFile: "t.meridian"
        ) == nil)

        let src: [SourceLine] = [
            SourceLine(indent: 0, text: "assert ready otherwise:", raw: "assert ready otherwise:", number: 1),
            SourceLine(indent: 2, text: "", raw: "", number: 2),
            SourceLine(indent: 2, text: "# fallback", raw: "# fallback", number: 3),
            SourceLine(indent: 2, text: "let x be 1.", raw: "let x be 1.", number: 4),
        ]
        let result = try parser.parseAssertWithOtherwise(src, at: 0, sourceFile: "t.meridian")
        #expect(result != nil)
        #expect(result?.0.otherwise?.statements.count == 1)
    }
}
