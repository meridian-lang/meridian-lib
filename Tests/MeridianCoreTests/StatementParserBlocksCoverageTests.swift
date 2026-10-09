import Foundation
import Testing
@testable import MeridianCore

/// Coverage for `StatementParser+Blocks` — iteration tables, typed data-cell
/// validation, backtick command embedding, shell splitting, and Markdown list
/// marker stripping that end-to-end fixtures rarely hit in isolation.
@Suite("StatementParser+Blocks coverage")
struct StatementParserBlocksCoverageTests {

    private let parser = StatementParser(symbols: SymbolTable())

    private func parse(_ source: String) throws -> ASTBlock {
        try parser.parseBlock(IndentTokenizer().tokenize(source))
    }

    // MARK: - Iteration table

    @Test("iteration table expands for-each rows into iteration statements")
    func iterationTableExpansion() throws {
        let block = try parse("""
        !!! table (( iteration table ))
        | action |
        | --- |
        | for each item in the items |
        | for each page in the pages |
        """)
        let iterations = block.statements.filter { if case .iteration = $0 { return true } else { return false } }
        #expect(iterations.count == 2)
    }

    @Test("iteration table without an action column returns empty")
    func iterationTableNoActionColumn() throws {
        let block = try parse("""
        !!! table (( iteration table ))
        | header |
        | --- |
        | for each item in the items |
        """)
        #expect(block.statements.isEmpty)
    }

    @Test("iteration table skips non-iteration rows")
    func iterationTableSkipsNonIteration() throws {
        let block = try parse("""
        !!! table (( iteration table ))
        | action |
        | --- |
        | for each item in the items |
        | let x be 1 |
        """)
        let iterations = block.statements.filter { if case .iteration = $0 { return true } else { return false } }
        #expect(iterations.count == 1)
    }

    // MARK: - Typed data table cells

    @Test("data table validates typed columns: number, boolean, duration")
    func typedDataTableCells() throws {
        let block = try parse("""
        !!! table (( data table: typed ))
        | amount (number) | active (boolean) | ttl (duration) |
        | --- | --- | --- |
        | 42 | true | 2 hours |
        """)
        #expect(block.statements.count == 1)
    }

    @Test("data table accepts a double in a number column")
    func typedDataTableAcceptsDouble() throws {
        let block = try parse("""
        !!! table (( data table: typed ))
        | amount (number) |
        | --- |
        | 3.14 |
        """)
        #expect(block.statements.count == 1)
    }

    @Test("validateDataCell accepts a synthetic money literal")
    func validateDataCellMoneyLiteral() throws {
        let line = SourceLine(indent: 0, text: "| x |", raw: "| x |", number: 1)
        try parser.validateDataCell(.literal(.money(10, currency: "USD")), raw: "10", type: "money", row: 1, column: "price", line: line, sourceFile: "t")
    }

    @Test("data table rejects a non-money in a money column")
    func typedDataTableRejectsMoneyMismatch() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            !!! table (( data table: bad ))
            | price (money) |
            | --- |
            | 10 |
            """)
        }
    }

    @Test("data table rejects a non-duration in a duration column")
    func typedDataTableRejectsDurationMismatch() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            !!! table (( data table: bad ))
            | ttl (duration) |
            | --- |
            | soon |
            """)
        }
    }

    @Test("parseDataColumnHeader handles empty type annotation")
    func dataColumnHeaderEmptyType() {
        let result = parser.parseDataColumnHeader("name ()")
        #expect(result.name == "name")
        #expect(result.type == nil)
    }

    @Test("parseDataColumnHeader keeps trimmed raw when name before paren is empty")
    func dataColumnHeaderEmptyName() {
        let result = parser.parseDataColumnHeader("(number)")
        #expect(result.name == "(number)")
        #expect(result.type == "number")
    }

    // MARK: - Backtick commands

    @Test("embeddedBacktickedCommand keeps annotation from surrounding prose")
    func embeddedBacktickWithAnnotation() throws {
        let block = try parse("Verify: `gbrain doctor --json`.")
        guard case .phraseInvocation(let phrase) = block.statements.first else {
            Issue.record("expected phrase invocation"); return
        }
        #expect(phrase.annotation == "Verify")
    }

    @Test("embeddedBacktickedCommand with only punctuation yields nil annotation")
    func embeddedBacktickEmptyAnnotation() {
        let line = SourceLine(indent: 0, text: ": `gbrain doctor --json`", raw: ": `gbrain doctor --json`", number: 1)
        guard case .phraseInvocation(let phrase) = parser.embeddedBacktickedCommand(line) else {
            Issue.record("expected phrase invocation"); return
        }
        #expect(phrase.annotation == nil)
    }

    @Test("embeddedBacktickedCommand returns nil for primitive statements")
    func embeddedBacktickRejectsPrimitives() {
        let line = SourceLine(indent: 0, text: "let x be `echo hi`", raw: "let x be `echo hi`", number: 1)
        #expect(parser.embeddedBacktickedCommand(line) == nil)
    }

    @Test("inlineBacktickedCommand parses a bare backtick span")
    func inlineBacktickParses() {
        let line = SourceLine(indent: 0, text: "`gbrain doctor`", raw: "`gbrain doctor`", number: 1)
        let result = parser.inlineBacktickedCommand(line)
        guard case .phraseInvocation(let phrase) = result else {
            Issue.record("expected phrase invocation"); return
        }
        #expect(phrase.annotation == nil)
    }

    // MARK: - Shell splitting

    @Test("splitShellCommands joins backslash continuations and drops comments")
    func splitShellCommandsContinuations() {
        let cmds = parser.splitShellCommands("echo hello \\\nworld\n# comment\necho done")
        #expect(cmds == ["echo hello world", "echo done"])
    }

    @Test("splitShellCommands keeps a dangling backslash continuation as a command")
    func splitShellCommandsDanglingContinuation() {
        let cmds = parser.splitShellCommands("echo hello \\")
        #expect(cmds == ["echo hello"])
    }

    // MARK: - Markdown list marker stripping

    @Test("stripMarkdownListMarker handles numbered and bullet markers")
    func stripMarkdownListMarkerVariants() {
        #expect(parser.stripMarkdownListMarker("- item") == "item")
        #expect(parser.stripMarkdownListMarker("* item") == "item")
        #expect(parser.stripMarkdownListMarker("1. item") == "item")
        #expect(parser.stripMarkdownListMarker("1) item") == "item")
        #expect(parser.stripMarkdownListMarker("1.") == "")
        #expect(parser.stripMarkdownListMarker("plain text") == "plain text")
    }

    // MARK: - parseInlineChain / tables

    @Test("parseInlineChain returns nil for a plain non-chain statement")
    func parseInlineChainPlainStatement() throws {
        let line = SourceLine(indent: 0, text: "let x be 1.", raw: "let x be 1.", number: 1)
        let result = try parser.parseInlineChain(line, sourceFile: "t")
        #expect(result == nil)
    }

    @Test("do-and chain with an unparseable chunk raises unparseableStatement")
    func doAndChainUnparseableChunk() {
        #expect(throws: CompilerError.self) {
            _ = try parse("do complete and bind total.")
        }
    }

    @Test("decision-table unparseable action raises unparseableStatement")
    func decisionTableUnparseableRow() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            | status | action |
            | --- | --- |
            | open | bind total. |
            """)
        }
    }

    @Test("inert table expands to no statements")
    func inertTableEmpty() throws {
        let block = try parse("""
        !!! table (( inert ))
        | a | b |
        | --- | --- |
        | 1 | 2 |
        """)
        #expect(block.statements.isEmpty)
    }
}
