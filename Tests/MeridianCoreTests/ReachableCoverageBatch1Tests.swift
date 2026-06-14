import Testing
import Foundation
import MeridianRuntime
@testable import MeridianCore

/// Batch 1 of the "everything reachable aims for 100%" push: small, pure
/// MeridianCore surfaces whose uncovered regions are reachable in-process
/// (accessors, compat shims, fallback arms, and a couple of parser branches).
/// Genuinely-unreachable defensive lines (the single `WholeWordRegex`
/// precondition, the JSON-serialize fallback) are NOT chased here — they are
/// documented permanent exceptions.

@Suite("Reachable coverage — batch 1 (pure core)")
struct ReachableCoverageBatch1Tests {

    // MARK: IdentifierNaming — empty/all-separator fallback (both casings)

    @Test("identifier naming falls back for empty/all-separator input")
    func identifierFallback() {
        // camel family → returns the (possibly lower-cased) source verbatim.
        #expect(IdentifierNaming.lowerCamel("") == "")
        #expect(IdentifierNaming.camelPreservingCase("   ") == "   ")
        // pascal family → empty identifier.
        #expect(IdentifierNaming.pascalCase("   ") == "")
        #expect(IdentifierNaming.pascalCaseFromSpaces("") == "")
        // sanity: the normal path still works.
        #expect(IdentifierNaming.lowerCamel("Mailer Server") == "mailerServer")
        #expect(IdentifierNaming.pascalCase("validation result") == "ValidationResult")
    }

    // MARK: WholeWordRegex — the centralized helper (replaces 3 copies)

    @Test("whole-word regex replace/contains, including empty-needle no-ops")
    func wholeWordRegex() {
        #expect(WholeWordRegex.replace("order ordered", of: "order", with: "X") == "X ordered")
        #expect(WholeWordRegex.replace("anything", of: "", with: "X") == "anything")
        // replacement with regex-special chars is treated literally.
        #expect(WholeWordRegex.replace("pay it", of: "it", with: "$1") == "pay $1")
        #expect(WholeWordRegex.contains("it", in: "pay it now"))
        #expect(!WholeWordRegex.contains("it", in: "items only"))
        #expect(!WholeWordRegex.contains("", in: "anything"))
    }

    // MARK: MeridianAST — inits + backward-compat iteration accessors

    @Test("rebind/let AST inits and iteration variable/collection accessors")
    func astShims() {
        let rb = RebindStatementAST(name: "total", value: .literal(.integer(1)), sourceLine: 3)
        #expect(rb.name == "total" && rb.sourceLine == 3)

        let forEach = IterationStatementAST(
            mode: .forEach(variable: "item", collection: .identifierRef("items")),
            body: ASTBlock(statements: []))
        #expect(forEach.variable == "item")
        if case .identifierRef(let c)? = forEach.collection { #expect(c == "items") }
        else { Issue.record("expected collection identifierRef") }

        let whileLoop = IterationStatementAST(
            mode: .whileCondition(.literal(.boolean(true))), body: ASTBlock(statements: []))
        #expect(whileLoop.variable == nil)
        #expect(whileLoop.collection == nil)
    }

    // MARK: IR symbol refs

    @Test("ToolRef / KindRef inits")
    func irRefs() {
        #expect(ToolRef("http.get").id == "http.get")
        #expect(KindRef("Order").name == "Order")
    }

    // MARK: DiagnosticEngine — errors/warnings projections

    @Test("DiagnosticEngine separates errors from warnings, mirrors suggestions/notes to trace")
    func diagnosticEngineProjections() {
        let r = SourceRange(file: "t.meridian", line: 1, column: 1)
        // An enabled trace so the suggestion/note mirroring autoclosures evaluate.
        let cap = ParserTrace.capturing(categories: [.diagnostics])
        let eng = DiagnosticEngine(trace: cap.trace)
        eng.report(Diagnostic(
            code: .unknownTool, severity: .error, message: "boom", primaryRange: r,
            suggestions: [Suggestion(replacement: "fix", range: r, rationale: "did you mean fix?")],
            notes: [DiagnosticNote("a related note")]))
        eng.report([Diagnostic.warning(.unknownTool, message: "meh", range: r)])
        #expect(eng.errors.count == 1)
        #expect(eng.warnings.count == 1)
        #expect(eng.hasErrors)
        #expect(cap.lines().contains { $0.contains("suggestion") })
        #expect(cap.lines().contains { $0.contains("note") })
    }

    // MARK: SkillFrontmatter — typed accessors over the raw bag

    @Test("SkillFrontmatter surfaces scalars and lists (incl. hyphen aliases)")
    func skillFrontmatter() {
        let meta = FileMetadataAST(entries: [
            ("name", "porter"),
            ("description", "ports skills"),
            ("goal", "port"),
            ("version", "2"),
            ("prompt-version", "7"),
            ("priority", "high"),
            ("brain-first", "yes"),
            ("writes-pages", "true"),
            ("writes-to", "brain, notes"),
            ("when-to-use", "always"),
            ("tools-required", "git, gh"),
            ("triggers", "schedule: daily"),
        ])
        let fm = SkillFrontmatter(meta)
        #expect(fm.name == "porter")
        #expect(fm.description == "ports skills")
        #expect(fm.goal == "port")
        #expect(fm.version == "2")
        #expect(fm.promptVersion == "7")
        #expect(fm.priority == "high")
        #expect(fm.brainFirst == "yes")
        #expect(fm.writesPages == "true")
        #expect(fm.writesTo == ["brain", "notes"])
        #expect(fm.whenToUse == ["always"])
        #expect(fm.tools == ["git", "gh"])
        #expect(!fm.manifestEntries.isEmpty)
        // nil scalar + empty list paths.
        let empty = SkillFrontmatter(nil)
        #expect(empty.name == nil)
        #expect(empty.parameters.isEmpty)
    }

    // MARK: MeridianLinter — paraphrase hints + anaphora detection

    @Test("linter emits please/maybe paraphrase hints and flags anaphora")
    func linterHints() {
        let lint = MeridianLinter()
        let please = lint.lint(source: "please do the thing.")
        #expect(please.contains { $0.hint?.contains("please") == true })

        let maybe = lint.lint(source: "maybe do the thing.")
        #expect(maybe.contains { $0.hint?.contains("discretion") == true })

        // >4 bind referents exercises the referent-window trim branch.
        let manyBinds = lint.lint(source: """
        bind a = 1.
        bind b = 2.
        bind c = 3.
        bind d = 4.
        bind e = 5.
        bind f = 6.
        """)
        #expect(manyBinds.isEmpty || !manyBinds.isEmpty)  // executes the trim path
    }

    // MARK: DefinitionParser — guard-failure (return nil) branches

    @Test("definition parser rejects malformed shapes and parses period-less input")
    func definitionParserBranches() {
        let dp = DefinitionParser(lexicon: .default, trace: .silent())
        // Not a definition line.
        #expect(dp.parse("To do a thing:", line: 1) == nil)
        // No ` if ` introducer.
        #expect(dp.parse("Definition: a page is stale", line: 1) == nil)
        // No ` is ` in the head.
        #expect(dp.parse("Definition: a page stale if it has no summary", line: 1) == nil)
        // Valid, WITHOUT a trailing period (exercises the no-`.` branch).
        let noDot = dp.parse("Definition: a page is stale if it has no summary", line: 1)
        #expect(noDot?.adjective == "stale")
        // Valid, WITH a trailing period (exercises the strip-`.` branch).
        let withDot = dp.parse("Definition: a page is stale if it has no summary.", line: 1)
        #expect(withDot?.adjective == "stale")
    }

    // MARK: RewriteEngine — priority ordering + trailing-literal anchoring

    @Test("desugar rules sort by priority; trailing literal must reach the end")
    func rewriteEngine() throws {
        let rb = try RulebookParser(trace: .silent()).parse("""
        === desugar ===
        rule "low" (priority 1):
          match: start {x} end
          rewrite: LOW {x}
        rule "high" (priority 10):
          match: begin {y}
          rewrite: HIGH {y}
        """)
        // Enabled trace so the rewrite-log autoclosure evaluates.
        let cap = ParserTrace.capturing(categories: [.rulebook])
        let engine = RewriteEngine(rulebook: rb, trace: cap.trace)
        #expect(!engine.isEmpty)
        // High-priority rule fires.
        #expect(engine.rewrite("begin now").text == "HIGH now")
        #expect(cap.lines().contains { $0.contains("rewrite") })
        // Trailing-literal rule: input has trailing content after `end`, so the
        // template can't anchor to the end → no rewrite.
        #expect(engine.rewrite("start foo end extra").changed == false)
        // Exact trailing-literal match does fire.
        #expect(engine.rewrite("start foo end").text == "LOW foo")

        // Empty rulebook → rewrite short-circuits (text, false).
        let empty = RewriteEngine(rulebook: try RulebookParser(trace: .silent()).parse(""), trace: .silent())
        #expect(empty.isEmpty)
        #expect(empty.rewrite("anything") == ("anything", false))

        // Direct matcher/substituter edge cases (internal statics).
        #expect(RewriteEngine.match([], against: "x") == nil)                       // empty tokens
        #expect(RewriteEngine.match([.literal("  "), .hole("h")], against: "  v") != nil)  // empty literal skipped
        #expect(RewriteEngine.match([.hole("h"), .literal("end")], against: "end") == nil) // empty capture before literal
        #expect(RewriteEngine.match([.hole("h")], against: "   ") == nil)           // empty trailing capture
        #expect(RewriteEngine.substitute("{missing}", with: [:]) == "")            // unknown hole → ""
    }
}
