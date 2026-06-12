import Foundation
import Testing
@testable import MeridianCore

@Suite("SKILL-style surface — markdown lists and headings")
struct SkillSurfaceMarkdownTests {

    @Test("tokenizer strips markdown list markers")
    func tokenizerStripsListMarkers() {
        let lines = IndentTokenizer().tokenize("""
        - complete.
        * commit.
        1. wait 5 seconds.
        """)

        #expect(lines[0].listMarker == "-")
        #expect(lines[0].statement == "complete")
        #expect(lines[1].listMarker == "*")
        #expect(lines[1].statement == "commit")
        #expect(lines[2].listMarker == "1.")
        #expect(lines[2].statement == "wait 5 seconds")
    }

    @Test("tokenizer records markdown headings without treating h1 comments as headings")
    func tokenizerRecordsHeadings() {
        let lines = IndentTokenizer().tokenize("""
        # Existing comment semantics
        ## Comments
        ### CI
        """)

        #expect(lines[0].isComment)
        #expect(lines[0].headingLevel == nil)
        #expect(lines[1].headingLevel == 2)
        #expect(lines[1].text == "Comments")
        #expect(lines[2].headingLevel == 3)
        #expect(lines[2].text == "CI")
    }

    @Test("parser skips headings and parses list items as normal statements")
    func parserSkipsHeadings() throws {
        let ast = try MeridianParser(symbols: SymbolTable()).parse("""
        ---
        name: markdown-demo
        ---

        ## Overview

        To demo markdown:
          ## Steps
          - complete.
        """)

        #expect(ast.outline.count == 2)
        #expect(ast.outline.map(\.text) == ["Overview", "Steps"])
        #expect(ast.outline.map(\.level) == [2, 2])
        #expect(ast.workflows.count == 1)
        #expect(ast.workflows[0].body.statements.count == 1)
        if case .complete = ast.workflows[0].body.statements[0] {
            // expected
        } else {
            Issue.record("Expected markdown list item to parse as complete statement")
        }
    }

    @Test("manifest emits markdown outline under meridian_skill")
    func manifestEmitsOutline() throws {
        let manifest = try ManifestEmitter().emit(.init(
            workflows: [],
            metadata: FileMetadataAST(entries: [("name", "markdown-demo")]),
            outline: [
                HeadingEntry(level: 2, text: "Comments", line: 7),
                HeadingEntry(level: 3, text: "CI", line: 12)
            ]
        ))
        let data = try #require(manifest.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let skill = try #require(json["meridian_skill"] as? [String: Any])
        let outline = try #require(skill["outline"] as? [[String: Any]])

        #expect(outline.count == 2)
        #expect(outline[0]["level"] as? Int == 2)
        #expect(outline[0]["text"] as? String == "Comments")
        #expect(outline[0]["line"] as? Int == 7)
        #expect(outline[1]["level"] as? Int == 3)
    }
}

@Suite("SKILL-style surface — implicit entry workflows")
struct SkillSurfaceImplicitEntryTests {

    private func symbols(_ source: String) throws -> SymbolTable {
        let cfg = try MerConfigParser(trace: .silent()).parse(source, file: "test.merconfig")
        return SymbolTable.build(from: cfg, sourceFile: "test.merconfig", trace: .silent())
    }

    @Test("top-level statements become an implicit entry workflow")
    func implicitEntryWorkflow() throws {
        let symbols = try symbols("""
        === vocabulary ===
        A pull request is a kind of thing.
        """)

        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
        ---
        name: babysit
        parameters: pull request
        ---

        ## Comments (( role: procedure ))
        - complete.
        """, file: "babysit.meridian")

        #expect(ast.workflows.count == 1)
        #expect(ast.workflows[0].pattern.displayText == "babysit a pull request")
        #expect(ast.workflows[0].pattern.parameters.first?.kind == "pull request")
        #expect(ast.workflows[0].body.statements.count == 1)
        #expect(ast.outline.map(\.text) == ["Comments"])
        // The forced role surfaces in the recorded section table.
        #expect(ast.skillSections.contains { $0.heading == "Comments" && $0.role == "procedure" && $0.executes })
    }

    @Test("frontmatter parameters must resolve to vocabulary kinds")
    func unknownFrontmatterParameterThrows() throws {
        let symbols = try symbols("""
        === vocabulary ===
        A pull request is a kind of thing.
        """)

        #expect(throws: CompilerError.self) {
            _ = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
            ---
            name: babysit
            parameters: ticket
            ---

            complete.
            """, file: "bad.meridian")
        }
    }

    @Test("implicit body cannot shadow an explicit entry workflow")
    func implicitEntryCannotShadowExplicitWorkflow() throws {
        let symbols = try symbols("""
        === vocabulary ===
        A pull request is a kind of thing.
        """)

        #expect(throws: CompilerError.self) {
            _ = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
            ---
            name: babysit
            parameters: pull request
            ---

            complete.

            To babysit a pull request:
              complete.
            """, file: "ambiguous.meridian")
        }
    }
}

@Suite("SKILL-style surface — natural connectives")
struct SkillSurfaceConnectiveTests {

    private func parse(_ source: String) throws -> ASTBlock {
        let lines = IndentTokenizer().tokenize(source)
        return try StatementParser(symbols: SymbolTable(), trace: .silent()).parseBlock(lines)
    }

    @Test("only when suffix becomes a single-statement conditional")
    func onlyWhenSuffix() throws {
        let block = try parse("complete only when ready.")

        #expect(block.statements.count == 1)
        guard case .conditional(let cond) = block.statements[0] else {
            Issue.record("Expected conditional")
            return
        }
        #expect(cond.thenBlock.statements.count == 1)
        if case .complete = cond.thenBlock.statements[0] {
            // expected
        } else {
            Issue.record("Expected complete in then block")
        }
        if case .identifierRef(let name) = cond.condition {
            #expect(name == "ready")
        } else {
            Issue.record("Expected identifier condition")
        }
    }

    @Test("unless suffix negates the predicate")
    func unlessSuffix() throws {
        let block = try parse("complete unless blocked.")

        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("Expected conditional")
            return
        }
        if case .logical(.not, let operands) = cond.condition {
            #expect(operands.count == 1)
            if case .identifierRef(let name) = operands[0] {
                #expect(name == "blocked")
            } else {
                Issue.record("Expected blocked identifier")
            }
        } else {
            Issue.record("Expected negated condition")
        }
    }

    @Test("leading otherwise attaches a recover handler to the previous statement")
    func leadingOtherwiseRecover() throws {
        let block = try parse("""
        complete.
        otherwise complete with reason "failed".
        """)

        #expect(block.statements.count == 1)
        guard case .recover(let rec) = block.statements[0] else {
            Issue.record("Expected recover")
            return
        }
        if case .complete = rec.attached {
            // expected
        } else {
            Issue.record("Expected recover to attach to previous complete")
        }
        #expect(rec.handler.statements.count == 1)
        if case .complete(let complete) = rec.handler.statements[0] {
            #expect(complete.reason == "failed")
        } else {
            Issue.record("Expected complete handler")
        }
    }

    @Test("if you decide that becomes decideWhether")
    func ifYouDecideThat() throws {
        let block = try parse("""
        if you decide that the comment is correct,
          complete.
        """)

        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("Expected conditional")
            return
        }
        if case .decideWhether(let question) = cond.condition {
            #expect(question == "the comment is correct")
        } else {
            Issue.record("Expected decideWhether condition")
        }
    }

    @Test("unless you decide that negates decideWhether")
    func unlessYouDecideThat() throws {
        let block = try parse("""
        unless you decide that the ci is healthy,
          complete.
        """)

        guard case .conditional(let cond) = block.statements.first else {
            Issue.record("Expected conditional")
            return
        }
        if case .logical(.not, let operands) = cond.condition,
           case .decideWhether(let question) = operands.first {
            #expect(question == "the ci is healthy")
        } else {
            Issue.record("Expected negated decideWhether")
        }
    }
}

@Suite("SKILL-style surface — every/each iteration")
struct SkillSurfaceEveryEachTests {

    private func parse(_ source: String) throws -> ASTBlock {
        try StatementParser(symbols: SymbolTable(), trace: .silent())
            .parseBlock(IndentTokenizer().tokenize(source))
    }

    @Test("every noun lowers to an iteration over the plural collection")
    func everyIteration() throws {
        let block = try parse("review every comment.")

        guard case .iteration(let iter) = block.statements.first else {
            Issue.record("Expected iteration")
            return
        }
        if case .forEach(let variable, let collection) = iter.mode {
            #expect(variable == "comment")
            if case .identifierRef(let name) = collection {
                #expect(name == "comments")
            } else {
                Issue.record("Expected comments collection")
            }
        } else {
            Issue.record("Expected forEach mode")
        }
        guard case .phraseInvocation(let phrase) = iter.body.statements.first else {
            Issue.record("Expected phrase body")
            return
        }
        #expect(phrase.words == "review the comment")
    }

    @Test("each multi-word noun uses camelCase collection names")
    func eachMultiWordIteration() throws {
        let block = try parse("inspect each pull request.")

        guard case .iteration(let iter) = block.statements.first,
              case .forEach(let variable, let collection) = iter.mode else {
            Issue.record("Expected forEach iteration")
            return
        }
        #expect(variable == "pullRequest")
        if case .identifierRef(let name) = collection {
            #expect(name == "pullRequests")
        } else {
            Issue.record("Expected pullRequests collection")
        }
    }
}

@Suite("SKILL-style surface — implicit result binding")
struct SkillSurfaceImplicitBindTests {

    @Test("bare return-valued invoke receives a derived result binding")
    func bareInvokeImplicitBinding() throws {
        let cfg = MerConfigFile(tools: [
            ToolDeclaration(
                displayName: "Get Customer",
                methodName: "getCustomer",
                parameters: [ToolParameterAST(name: "id", type: "String")],
                returnType: "Customer"
            )
        ])
        let symbols = SymbolTable.build(from: cfg, sourceFile: "test.merconfig", trace: .silent())
        #expect(symbols.tools["getCustomer"]?.returnType == "Customer")
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
        To demo:
          invoke get customer with id = "c-1".
        """, file: "test.meridian")
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)

        guard case .invoke(let invoke) = workflows[0].body.statements.first else {
            Issue.record("Expected invoke")
            return
        }
        #expect(invoke.toolID == "getCustomer")
        #expect(invoke.resultBinding == "customer")
    }

    @Test("explicit bind keeps its chosen binding")
    func explicitBindWins() throws {
        let cfg = MerConfigFile(tools: [
            ToolDeclaration(
                displayName: "Get Customer",
                methodName: "getCustomer",
                parameters: [ToolParameterAST(name: "id", type: "String")],
                returnType: "Customer"
            )
        ])
        let symbols = SymbolTable.build(from: cfg, sourceFile: "test.merconfig", trace: .silent())
        #expect(symbols.tools["getCustomer"]?.returnType == "Customer")
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
        To demo:
          bind fetched customer = invoke get customer with id = "c-1".
        """, file: "test.meridian")
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)

        guard case .invoke(let invoke) = workflows[0].body.statements.first else {
            Issue.record("Expected invoke")
            return
        }
        #expect(invoke.resultBinding == "fetchedCustomer")
    }
}

@Suite("SKILL-style surface — topic labels, chains, and goals")
struct SkillSurfaceLateTier1Tests {

    @Test("topic label wraps a parsed statement and appears in outline")
    func topicLabel() throws {
        let ast = try MeridianParser(symbols: SymbolTable(), trace: .silent()).parse("""
        To demo:
          Comments: complete.
        """)

        #expect(ast.outline.first?.text == "Comments")
        #expect(ast.outline.first?.kind == "topic")
        guard case .labelled(let labelled) = ast.workflows[0].body.statements.first else {
            Issue.record("Expected labelled statement")
            return
        }
        #expect(labelled.label == "Comments")
        if case .complete = labelled.statement {
            // expected
        } else {
            Issue.record("Expected labelled complete statement")
        }
    }

    @Test("do chains parse as sequential statements")
    func inlineStatementChain() throws {
        let block = try StatementParser(symbols: SymbolTable(), trace: .silent())
            .parseBlock(IndentTokenizer().tokenize("do complete, commit, and wait 5 seconds."))

        #expect(block.statements.count == 3)
        if case .complete = block.statements[0] {} else { Issue.record("Expected complete") }
        if case .commit = block.statements[1] {} else { Issue.record("Expected commit") }
        if case .wait = block.statements[2] {} else { Issue.record("Expected wait") }
    }

    @Test("single workflow parameter is filled when phrase needs it")
    func implicitSingleParameterFill() throws {
        let cfg = try MerConfigParser(trace: .silent()).parse("""
        === vocabulary ===
        A pull request is a kind of thing.
        A comment is a kind of thing.

        To review a comment for a pull request:
          complete.
        """, file: "test.merconfig")
        let symbols = SymbolTable.build(from: cfg, sourceFile: "test.merconfig", trace: .silent())
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse("""
        To babysit a pull request:
          review the comment.
        """, file: "test.meridian")
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)

        guard case .complete = workflows[0].body.statements.first else {
            Issue.record("Expected phrase to resolve via implicit parameter fill")
            return
        }
    }

    @Test("frontmatter goal is emitted as meridian_skill.goal")
    func goalManifest() throws {
        let manifest = try ManifestEmitter().emit(.init(
            workflows: [],
            metadata: FileMetadataAST(entries: [
                ("name", "babysit"),
                ("goal", "Keep the PR merge-ready")
            ])
        ))
        let data = try #require(manifest.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let skill = try #require(json["meridian_skill"] as? [String: Any])
        #expect(skill["goal"] as? String == "Keep the PR merge-ready")
    }
}
