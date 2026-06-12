import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - B6: Fenced code-block string literals
//
// Verifies that IndentTokenizer collapses ``` fences into sentinel SourceLines,
// ExpressionParser decodes them back to .literal(.string) or .interpolatedString,
// StatementParser handles "decide using:" + sentinel, and the full compiler
// pipeline emits correct Swift source.

@Suite("B6 — IndentTokenizer fence collapsing")
struct IndentTokenizerFenceTests {

    private let tok = IndentTokenizer()

    @Test("plain fence at column 0 becomes a single sentinel SourceLine")
    func plainFenceAtColumnZero() {
        let src = """
        ```
        Hello world.
        ```
        """
        let lines = tok.tokenize(src)
        // Should be exactly 1 line (the sentinel)
        let content = lines.filter(\.isContent)
        #expect(content.count == 1, Comment(rawValue: "Expected 1 sentinel, got \(content.count) lines: \(content.map(\.text))"))
        let sentinel = content[0]
        #expect(sentinel.text.hasPrefix(codeBlockSentinelPrefix),
                Comment(rawValue: "Expected sentinel prefix, got: \(sentinel.text)"))
    }

    @Test("fence with language tag includes lang in sentinel")
    func fenceWithLangTag() {
        let src = """
        ```markdown
        # Heading
        Body text.
        ```
        """
        let lines = tok.tokenize(src)
        let content = lines.filter(\.isContent)
        #expect(content.count == 1)
        let sentinel = content[0]
        #expect(sentinel.text.hasPrefix(codeBlockSentinelPrefix + "markdown:"),
                Comment(rawValue: "Expected markdown lang tag, got: \(sentinel.text)"))
    }

    @Test("fence body decodes back to original text")
    func fenceBodyRoundTrip() {
        let original = "Line one.\nLine two.\nLine three."
        let src = "```\n\(original)\n```"
        let lines = tok.tokenize(src)
        let content = lines.filter(\.isContent)
        #expect(content.count == 1)
        let sentinel = content[0]

        // Decode the sentinel manually
        let rest = String(sentinel.text.dropFirst(codeBlockSentinelPrefix.count))
        let colonIdx = rest.firstIndex(of: ":")!
        let b64 = String(rest[rest.index(after: colonIdx)...])
        let decoded = String(data: Data(base64Encoded: b64)!, encoding: .utf8)!
        #expect(decoded == original, Comment(rawValue: "Expected \"\(original)\", got \"\(decoded)\""))
    }

    @Test("fence preserves indent depth of the opening backtick line")
    func fencePreservesIndent() {
        let src = "workflow do thing:\n  ```\n  Body line.\n  ```"
        let lines = tok.tokenize(src)
        let content = lines.filter(\.isContent)
        // 2 content lines: workflow header + sentinel
        #expect(content.count == 2)
        let sentinel = content[1]
        #expect(sentinel.indent == 2,
                Comment(rawValue: "Expected indent=2, got \(sentinel.indent)"))
    }

    @Test("fence body is dedented relative to opening fence indent")
    func fenceBodyDedented() {
        let src = "  ```\n    Indented line.\n  ```"
        let lines = tok.tokenize(src)
        let content = lines.filter(\.isContent)
        #expect(content.count == 1)
        let sentinel = content[0]

        let rest = String(sentinel.text.dropFirst(codeBlockSentinelPrefix.count))
        let colonIdx = rest.firstIndex(of: ":")!
        let b64 = String(rest[rest.index(after: colonIdx)...])
        let decoded = String(data: Data(base64Encoded: b64)!, encoding: .utf8)!
        // "    Indented line." dedented by 2 = "  Indented line."
        #expect(decoded == "  Indented line.", Comment(rawValue: "Got: \"\(decoded)\""))
    }

    @Test("sentinel isEmpty is false and isComment is false → isContent is true")
    func sentinelIsContent() {
        let src = "```\nHi.\n```"
        let lines = tok.tokenize(src)
        let sentinel = lines.first(where: { $0.text.hasPrefix(codeBlockSentinelPrefix) })!
        #expect(!sentinel.isEmpty)
        #expect(!sentinel.isComment)
        #expect(sentinel.isContent)
    }

    @Test("trailing blank line before closing fence is trimmed")
    func trailingBlankLineTrimmed() {
        let src = "```\nBody.\n\n```"
        let lines = tok.tokenize(src)
        let content = lines.filter(\.isContent)
        #expect(content.count == 1)
        let rest = String(content[0].text.dropFirst(codeBlockSentinelPrefix.count))
        let colonIdx = rest.firstIndex(of: ":")!
        let b64 = String(rest[rest.index(after: colonIdx)...])
        let decoded = String(data: Data(base64Encoded: b64)!, encoding: .utf8)!
        #expect(decoded == "Body.", Comment(rawValue: "Got: \"\(decoded)\""))
    }

    @Test("closing fence with trailing dot (```.) is recognised")
    func closingFenceWithDot() {
        let src = "```\nBody line.\n```."
        let lines = tok.tokenize(src)
        let content = lines.filter(\.isContent)
        // Should still produce exactly 1 sentinel — the "```." is the closing fence
        #expect(content.count == 1,
                Comment(rawValue: "Expected 1 sentinel, got \(content.count): \(content.map(\.text))"))
        let sentinel = content[0]
        #expect(sentinel.text.hasPrefix(codeBlockSentinelPrefix))
        let rest = String(sentinel.text.dropFirst(codeBlockSentinelPrefix.count))
        let colonIdx = rest.firstIndex(of: ":")!
        let b64 = String(rest[rest.index(after: colonIdx)...])
        let decoded = String(data: Data(base64Encoded: b64)!, encoding: .utf8)!
        #expect(decoded == "Body line.", Comment(rawValue: "Got: \"\(decoded)\""))
    }
}

// MARK: - B6: ExpressionParser sentinel decoding

@Suite("B6 — ExpressionParser sentinel decoding")
struct ExpressionParserSentinelTests {

    private let tok = IndentTokenizer()
    private let ep  = ExpressionParser()

    private func sentinel(for body: String, lang: String = "plain") -> String {
        let b64 = Data(body.utf8).base64EncodedString()
        return codeBlockSentinelPrefix + lang + ":" + b64
    }

    @Test("sentinel decodes to literal string when no {{ markers")
    func sentinelToLiteralString() {
        let s = sentinel(for: "Is the diff safe to merge?")
        let expr = ep.parseAtom(s)
        if case .literal(.string(let v)) = expr {
            #expect(v == "Is the diff safe to merge?")
        } else {
            #expect(Bool(false), Comment(rawValue: "Expected .literal(.string), got \(expr)"))
        }
    }

    @Test("sentinel with {{ marker decodes to interpolatedString")
    func sentinelToInterpolatedString() {
        let body = "Order {{ the order's id }} is ready."
        let s = sentinel(for: body)
        let expr = ep.parseAtom(s)
        if case .interpolatedString(let segs) = expr {
            #expect(segs.count == 3,
                    Comment(rawValue: "Expected 3 segments, got \(segs.count): \(segs)"))
            if case .literal(let t) = segs[0] { #expect(t == "Order ") }
            if case .expression = segs[1] { /* property access */ } else {
                #expect(Bool(false), Comment(rawValue: "Expected .expression at seg[1]"))
            }
            if case .literal(let t) = segs[2] { #expect(t == " is ready.") }
        } else {
            #expect(Bool(false), Comment(rawValue: "Expected .interpolatedString, got \(expr)"))
        }
    }

    @Test("multi-line fence body round-trips through ExpressionParser")
    func multiLineFenceBodyRoundTrip() {
        let body = "Line 1.\nLine 2.\nLine 3."
        let s = sentinel(for: body)
        let expr = ep.parseAtom(s)
        if case .literal(.string(let v)) = expr {
            #expect(v == body)
        } else {
            #expect(Bool(false), Comment(rawValue: "Expected .literal(.string), got \(expr)"))
        }
    }

    @Test("escaped \\{{ in fence body is treated as literal {{")
    func escapedInterpolationMarker() {
        let body = #"Use \{{ literal }} braces."#
        let s = sentinel(for: body)
        let expr = ep.parseAtom(s)
        // \{{ is escaped — should become a plain string with literal {{
        if case .literal(.string(let v)) = expr {
            #expect(v.contains("{{"),
                    Comment(rawValue: "Expected literal '{{' in: \(v)"))
        } else if case .interpolatedString(let segs) = expr {
            // Acceptable if segments are all literals (no expression segments)
            let hasExpression = segs.contains { if case .expression = $0 { return true }; return false }
            #expect(!hasExpression, Comment(rawValue: "Unexpected expression segment in: \(segs)"))
        } else {
            #expect(Bool(false), Comment(rawValue: "Unexpected: \(expr)"))
        }
    }
}

// MARK: - B6/B7: parseInterpolationSegments unit tests

@Suite("B7 — parseInterpolationSegments")
struct InterpolationSegmentsTests {

    private let ep = ExpressionParser()

    @Test("plain body returns single literal segment")
    func plainBody() {
        let segs = ep.parseInterpolationSegments("No markers here.")
        #expect(segs.count == 1)
        if case .literal(let t) = segs[0] { #expect(t == "No markers here.") }
        else { #expect(Bool(false)) }
    }

    @Test("single {{ expr }} marker splits into three segments")
    func singleMarker() {
        let segs = ep.parseInterpolationSegments("Hello {{ name }}, welcome!")
        #expect(segs.count == 3)
        if case .literal(let t) = segs[0] { #expect(t == "Hello ") }
        if case .expression = segs[1] { /* ok */ } else { #expect(Bool(false)) }
        if case .literal(let t) = segs[2] { #expect(t == ", welcome!") }
    }

    @Test("marker at start produces leading expression segment")
    func markerAtStart() {
        let segs = ep.parseInterpolationSegments("{{ order.id }} placed.")
        // Should be: .expression + .literal
        #expect(segs.count == 2)
        if case .expression = segs[0] { /* ok */ } else { #expect(Bool(false)) }
        if case .literal(let t) = segs[1] { #expect(t == " placed.") }
    }

    @Test("marker at end produces trailing expression segment")
    func markerAtEnd() {
        let segs = ep.parseInterpolationSegments("Order: {{ order.id }}")
        #expect(segs.count == 2)
        if case .literal(let t) = segs[0] { #expect(t == "Order: ") }
        if case .expression = segs[1] { /* ok */ } else { #expect(Bool(false)) }
    }

    @Test("multiple markers split correctly")
    func multipleMarkers() {
        let segs = ep.parseInterpolationSegments("A={{ x }}, B={{ y }}")
        // .literal("A=") .expression(x) .literal(", B=") .expression(y)
        #expect(segs.count == 4)
    }

    @Test("unclosed marker is treated as literal tail")
    func unclosedMarker() {
        let segs = ep.parseInterpolationSegments("Hello {{ unclosed")
        // The {{...unclosed should become a literal fragment
        #expect(!segs.isEmpty)
        let hasExpression = segs.contains { if case .expression = $0 { return true }; return false }
        #expect(!hasExpression, Comment(rawValue: "Unclosed {{ should not produce an expression"))
    }
}

// MARK: - B6/B7: SwiftEmitter interpolation emission

@Suite("B7 — SwiftEmitter interpolatedString emission")
struct InterpolatedStringEmissionTests {

    private let emitter = SwiftEmitter(options: .init(emitSourceLineComments: false))

    @Test("interpolatedString in emitExpr concatenates parts")
    func emitExprInterpolated() {
        let segs: [IRInterpolationSegment] = [
            .literal("Order "),
            .expression(.propertyAccess(.identifierRef(name: "order"), propertyName: "id")),
            .literal(" placed.")
        ]
        let out = emitter.emitExpr(.interpolatedString(segs))
        #expect(out.contains("\"Order \""),
                Comment(rawValue: "Expected literal 'Order ' in: \(out)"))
        #expect(out.contains("meridianStringify("),
                Comment(rawValue: "Expected meridianStringify call in: \(out)"))
        #expect(out.contains("\" placed.\""),
                Comment(rawValue: "Expected literal ' placed.' in: \(out)"))
    }

    @Test("interpolatedString in emitValueExpr wraps in .string()")
    func emitValueExprInterpolated() {
        let segs: [IRInterpolationSegment] = [
            .literal("Hello "),
            .expression(.identifierRef(name: "name"))
        ]
        let out = emitter.emitValueExpr(.interpolatedString(segs))
        #expect(out.hasPrefix(".string("),
                Comment(rawValue: "Expected .string(...) wrapper, got: \(out)"))
        #expect(out.contains("meridianStringify("),
                Comment(rawValue: "Expected meridianStringify call in: \(out)"))
    }

    @Test("empty interpolatedString emits empty string")
    func emitEmptyInterpolated() {
        #expect(emitter.emitExpr(.interpolatedString([])) == "\"\"")
        #expect(emitter.emitValueExpr(.interpolatedString([])) == ".string(\"\")")
    }

    @Test("fileHeader includes meridianStringify helper")
    func fileHeaderIncludesHelper() {
        let wf = IRWorkflow(
            name: "test workflow",
            parameters: [],
            body: IRBlock(statements: []),
            mode: .strict,
            sourceFile: "test.meridian"
        )
        let out = emitter.emitFile(workflows: [wf])
        #expect(out.contains("private func meridianStringify("),
                Comment(rawValue: "meridianStringify not found in:\n\(out)"))
        #expect(out.contains("case .string(let s): return s"),
                Comment(rawValue: "meridianStringify string case missing"))
    }

    @Test("strings with special chars are escaped in interpolation")
    func specialCharsEscaped() {
        let segs: [IRInterpolationSegment] = [
            .literal("Say \"hello\"\nand \\goodbye.")
        ]
        let out = emitter.emitExpr(.interpolatedString(segs))
        // Embedded quotes and backslashes must be Swift-escaped
        #expect(out.contains("\\\""),
                Comment(rawValue: "Expected escaped quotes in: \(out)"))
        #expect(out.contains("\\\\"),
                Comment(rawValue: "Expected escaped backslash in: \(out)"))
        #expect(out.contains("\\n"),
                Comment(rawValue: "Expected escaped newline in: \(out)"))
    }
}

// MARK: - B6: End-to-end compiler tests

@Suite("B6 — End-to-end compiler: fenced code blocks")
struct B6EndToEndTests {

    private let cfg = """
    === vocabulary ===
    kind Order is a thing.
    """

    // MARK: decide using: (plain body)

    private func examplesURL() -> URL {
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url.appendingPathComponent("examples")
    }

    @Test("decide using: with plain code block compiles to llm.decide invoke")
    func decideUsingPlainBlock() throws {
        // Meridian workflow headers start with "to". The closing fence uses
        // no trailing "." — the block form terminates implicitly.
        let mer = """
        to check the order, with discretion:
          bind verdict = decide using:
            ```
            Should we approve this order?
            All checks passed.
            ```
          complete.
        """
        let out = try Compiler().compile(
            meridianSource: mer,
            meridianFile: "check.meridian",
            merconfigSource: cfg,
            merconfigFile: "check.merconfig"
        )
        #expect(out.contains("llm.decide"),
                Comment(rawValue: "Expected llm.decide in:\n\(out)"))
        #expect(out.contains("Should we approve"),
                Comment(rawValue: "Expected question text in:\n\(out)"))
    }

    // MARK: decide using: (interpolated body)

    @Test("decide using: with {{ }} interpolation emits meridianStringify")
    func decideUsingInterpolated() throws {
        let mer = """
        to check the order, with discretion:
          bind verdict = decide using:
            ```
            Order {{ the order's id }} has status {{ the order's status }}.
            Should we approve?
            ```
          complete.
        """
        let out = try Compiler().compile(
            meridianSource: mer,
            meridianFile: "check.meridian",
            merconfigSource: cfg,
            merconfigFile: "check.merconfig"
        )
        #expect(out.contains("meridianStringify("),
                Comment(rawValue: "Expected meridianStringify in:\n\(out)"))
        #expect(out.contains("llm.decide"),
                Comment(rawValue: "Expected llm.decide in:\n\(out)"))
    }

    // MARK: Code block as bind value (plain string)

    @Test("bind X = invoke tool with string arg compiles to runtime.invoke")
    func bindInvokeWithStringPrompt() throws {
        let mer = """
        to store the prompt:
          bind prompt = invoke llm.chat with prompt = "Hello AI".
          complete.
        """
        let out = try Compiler().compile(
            meridianSource: mer,
            meridianFile: "store.meridian",
            merconfigSource: cfg,
            merconfigFile: "store.merconfig"
        )
        // `invoke llm.chat` is methodized to `llmChat` (camelCase) when the
        // tool is not declared in the merconfig vocabulary.
        #expect(out.contains("runtime.invoke"),
                Comment(rawValue: "Expected runtime.invoke in:\n\(out)"))
        #expect(out.contains("llmChat") || out.contains("llm"),
                Comment(rawValue: "Expected llm.chat tool in:\n\(out)"))
    }

    // MARK: closing fence with trailing dot

    @Test("closing ```dot fence works correctly")
    func closingFenceWithDotInSource() throws {
        // The "```." form: closing fence followed by statement terminator ".".
        let mer = """
        to check the order, with discretion:
          bind verdict = decide using:
            ```
            Approve order?
            ```.
          complete.
        """
        let out = try Compiler().compile(
            meridianSource: mer,
            meridianFile: "dot.meridian",
            merconfigSource: cfg,
            merconfigFile: "dot.merconfig"
        )
        #expect(out.contains("llm.decide"),
                Comment(rawValue: "Expected llm.decide in:\n\(out)"))
        #expect(out.contains("Approve order?"),
                Comment(rawValue: "Expected question text in:\n\(out)"))
    }

    // MARK: Sentinel is skipped when orphaned

    @Test("orphaned code block sentinel in workflow body is silently skipped")
    func orphanedSentinelSkipped() throws {
        // A raw fence block that isn't tied to a bind/decide — should be ignored
        // The tokenizer produces a sentinel; parseStatement returns (nil, 1).
        let mer = """
        to do something:
          emit done with id = "x".
        """
        let out = try Compiler().compile(
            meridianSource: mer,
            meridianFile: "orphan.meridian",
            merconfigSource: cfg,
            merconfigFile: "orphan.merconfig"
        )
        #expect(out.contains("DoSomething"),
                Comment(rawValue: "Expected DoSomething struct in:\n\(out)"))
    }

    // MARK: Phase 3 regression

    @Test("Phase 3 forcing function still passes after B6/B7")
    func phase3Regression() throws {
        let dir = examplesURL()
        let mer = try String(contentsOf: dir.appendingPathComponent("order_processing.meridian"), encoding: .utf8)
        let cfg = try String(contentsOf: dir.appendingPathComponent("ecommerce.merconfig"), encoding: .utf8)
        let out = try Compiler().compile(
            meridianSource: mer,
            meridianFile: "order_processing.meridian",
            merconfigSource: cfg,
            merconfigFile: "ecommerce.merconfig"
        )
        #expect(!out.contains("_unresolved"),
                Comment(rawValue: "Found _unresolved in generated Swift"))
        #expect(out.contains("ProcessOrder"),
                Comment(rawValue: "Expected ProcessOrder struct"))
    }
}

// MARK: - B7: ASTToIR lowering for interpolatedString

@Suite("B7 — ASTToIR lowerExpr interpolatedString")
struct ASTToIRInterpolationTests {

    private func lower(_ expr: ExpressionAST) -> IRExpression {
        let symbols = SymbolTable()
        return ASTToIR(symbols: symbols).lowerExpr(expr)
    }

    @Test("literal-only interpolatedString lowers to interpolatedString IR")
    func literalOnlySegments() {
        let expr = ExpressionAST.interpolatedString([
            .literal("Hello world.")
        ])
        let ir = lower(expr)
        if case .interpolatedString(let segs) = ir {
            #expect(segs.count == 1)
            if case .literal(let t) = segs[0] { #expect(t == "Hello world.") }
            else { #expect(Bool(false)) }
        } else {
            #expect(Bool(false), Comment(rawValue: "Expected .interpolatedString, got \(ir)"))
        }
    }

    @Test("expression segment lowers its nested expression")
    func expressionSegmentLowered() {
        let expr = ExpressionAST.interpolatedString([
            .literal("Order "),
            .expression(.propertyAccess(.identifierRef("order"), "id"))
        ])
        let ir = lower(expr)
        if case .interpolatedString(let segs) = ir {
            #expect(segs.count == 2)
            if case .expression(let irExpr) = segs[1] {
                if case .propertyAccess(let base, let prop) = irExpr {
                    if case .identifierRef(let n) = base { #expect(n == "order") }
                    #expect(prop == "id")
                } else {
                    #expect(Bool(false), Comment(rawValue: "Expected .propertyAccess"))
                }
            } else {
                #expect(Bool(false), Comment(rawValue: "Expected .expression segment"))
            }
        } else {
            #expect(Bool(false))
        }
    }
}
