import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Coverage for the Inform-7-tier expressiveness program (Wave 1): command
// annotations (1A), typed command holes (1B), predicate/temporal/ordering
// iteration (1C), and metadata-shaped sections (1D).

// MARK: - 1A. Command annotations

@Suite("Wave 1A — command annotations")
struct CommandAnnotationTests {

    private func lower(_ source: String) throws -> [IRWorkflow] {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent())
            .parse(source, file: "test.meridian")
        return try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)
    }

    @Test("a backticked command with a -- note carries the note as InvokeIR.comment")
    func annotationCarried() throws {
        let workflows = try lower("""
        To demo:
          `gbrain publish "title"` -- announce the page.
        """)
        guard case .invoke(let invoke) = workflows[0].body.statements.first else {
            Issue.record("expected invoke"); return
        }
        #expect(invoke.toolID == "shell.run")
        #expect(invoke.comment == "announce the page")
        guard case .literal(.string(let cmd)) = invoke.arguments.first?.value else {
            Issue.record("expected command literal"); return
        }
        #expect(cmd == "gbrain publish \"title\"")
    }

    @Test("a --flag inside the command is not mistaken for an annotation")
    func noFalseSplitOnFlag() throws {
        let workflows = try lower("""
        To demo:
          `gbrain recall --since-last-run --json`.
        """)
        guard case .invoke(let invoke) = workflows[0].body.statements.first else {
            Issue.record("expected invoke"); return
        }
        #expect(invoke.comment == nil)
        guard case .literal(.string(let cmd)) = invoke.arguments.first?.value else {
            Issue.record("expected command literal"); return
        }
        #expect(cmd == "gbrain recall --since-last-run --json")
    }

    @Test("a -- inside the backticks is part of the command, not an annotation")
    func dashInsideBackticksKept() throws {
        let workflows = try lower("""
        To demo:
          `git checkout -- file.txt`.
        """)
        guard case .invoke(let invoke) = workflows[0].body.statements.first else {
            Issue.record("expected invoke"); return
        }
        #expect(invoke.comment == nil)
        guard case .literal(.string(let cmd)) = invoke.arguments.first?.value else {
            Issue.record("expected command literal"); return
        }
        #expect(cmd == "git checkout -- file.txt")
    }

    @Test("splitCommandAnnotation only splits the space-dash-dash-space separator")
    func splitHelper() {
        let a = StatementParser.splitCommandAnnotation("`cmd` -- note")
        #expect(a.command == "`cmd`")
        #expect(a.annotation == "note")
        let b = StatementParser.splitCommandAnnotation("`cmd --flag`")
        #expect(b.annotation == nil)
        let c = StatementParser.splitCommandAnnotation("`cmd`")
        #expect(c.annotation == nil)
    }

    @Test("a desugar rule's rewritten command re-enters the shell path via the parseBlock hoist")
    func desugarReentersShellPath() throws {
        // `Run `cmd` to <purpose>` → `` `cmd` -- <purpose> `` (canonical 1A form).
        let rulebook = Rulebook(desugars: [
            DesugarRule(
                name: "annotated-command",
                match: [.literal("Run `"), .hole("command"), .literal("` to "), .hole("purpose")],
                rewrite: "`{command}` -- {purpose}"
            )
        ])
        let engine = RewriteEngine(rulebook: rulebook, trace: .silent())
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent(), rewriteEngine: engine)
            .parse("""
            To demo:
              Run `gbrain doctor --json` to check index health.
            """, file: "test.meridian")
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)
        guard case .invoke(let invoke) = workflows[0].body.statements.first else {
            Issue.record("expected the rewritten command to lower to a shell.run invoke"); return
        }
        #expect(invoke.toolID == "shell.run")
        #expect(invoke.comment == "check index health")
        guard case .literal(.string(let cmd)) = invoke.arguments.first?.value else {
            Issue.record("expected command literal"); return
        }
        #expect(cmd == "gbrain doctor --json")
    }

    @Test("emitInvoke renders the annotation as a // comment above the call")
    func emittedComment() {
        let emitter = SwiftEmitter(options: .init(emitSourceLineComments: false))
        let ctx = Ctx(depth: 1, options: SwiftEmitter.Options(emitSourceLineComments: false))
        let ir = InvokeIR(
            toolID: "shell.run",
            arguments: [InvokeArg("command", .literal(.string("echo hi")))],
            comment: "say hello"
        )
        let out = emitter.emitInvoke(ir, ctx: ctx).toString()
        #expect(out.contains("// say hello"))
        #expect(out.contains("tool: \"shell.run\""))
    }
}

// MARK: - 1B. Typed command holes

@Suite("Wave 1B — typed command holes")
struct CommandHoleTests {

    private func lower(_ source: String) throws -> [IRWorkflow] {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent())
            .parse(source, file: "test.meridian")
        return try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)
    }

    private func commandValue(_ workflows: [IRWorkflow]) -> IRExpression? {
        guard case .invoke(let invoke) = workflows[0].body.statements.first,
              let arg = invoke.arguments.first(where: { $0.key == "command" }) else { return nil }
        return arg.value
    }

    @Test("a hole referencing an in-scope param interpolates verbatim outside quotes")
    func holeResolvesToParam() throws {
        let workflows = try lower("""
        To notify a person:
          `echo {the person's name}`.
        """)
        guard case .interpolatedString(let segs) = commandValue(workflows) else {
            Issue.record("expected interpolated command"); return
        }
        // literal "echo " + verbatim expression segment for person.name.
        #expect(segs.contains { if case .expression = $0 { return true } else { return false } })
        #expect(!segs.contains { if case .shellEscapedExpression = $0 { return true } else { return false } })
    }

    @Test("a hole inside double quotes is shell-escaped")
    func holeInsideQuotesIsEscaped() throws {
        let workflows = try lower("""
        To notify a person:
          `gbrain search "{the person's name}"`.
        """)
        guard case .interpolatedString(let segs) = commandValue(workflows) else {
            Issue.record("expected interpolated command"); return
        }
        #expect(segs.contains { if case .shellEscapedExpression = $0 { return true } else { return false } })
    }

    @Test("an unresolved word-shaped hole is a hard sourced error")
    func unresolvedHoleErrors() {
        #expect(throws: CompilerError.self) {
            _ = try lower("""
            To demo:
              `echo {the widget count}`.
            """)
        }
    }

    @Test("code-shaped braces (XML namespace) stay literal — not a hole")
    func codeShapedBracesLiteral() throws {
        let workflows = try lower("""
        To demo:
          `python -c "print('{http://example.com/ns}tag')"`.
        """)
        // No identifier resolution attempted; the whole command is one literal.
        guard case .literal(.string(let cmd)) = commandValue(workflows) else {
            Issue.record("expected a plain literal command"); return
        }
        #expect(cmd.contains("{http://example.com/ns}tag"))
    }

    @Test("{{ }} escapes to literal braces and does not collide with a real hole")
    func doubleBraceEscape() throws {
        let workflows = try lower("""
        To notify a person:
          `echo {{not a hole}} {the person's name}`.
        """)
        guard case .interpolatedString(let segs) = commandValue(workflows) else {
            Issue.record("expected interpolated command"); return
        }
        // The {{…}} region is literal text containing single braces.
        let literalText = segs.compactMap { seg -> String? in
            if case .literal(let s) = seg { return s } else { return nil }
        }.joined()
        #expect(literalText.contains("{not a hole}"))
        #expect(segs.contains { if case .expression = $0 { return true } else { return false } })
    }

    @Test("${VAR} shell parameter expansion is never treated as a hole")
    func dollarBraceLiteral() throws {
        let workflows = try lower("""
        To demo:
          `echo ${HOME}`.
        """)
        guard case .literal(.string(let cmd)) = commandValue(workflows) else {
            Issue.record("expected a plain literal command"); return
        }
        #expect(cmd == "echo ${HOME}")
    }

    @Test("multiple holes in one command each become their own segment")
    func multipleHoles() throws {
        let workflows = try lower("""
        To notify a person:
          `gbrain link {the person's id} {the person's name}`.
        """)
        guard case .interpolatedString(let segs) = commandValue(workflows) else {
            Issue.record("expected interpolated command"); return
        }
        let exprCount = segs.filter { if case .expression = $0 { return true } else { return false } }.count
        #expect(exprCount == 2)
    }

    @Test("a hole resolves against an earlier bind in the same workflow")
    func holeResolvesToBind() throws {
        let workflows = try lower("""
        To demo:
          bind slug = invoke gbrain.search with query = "acme".
          `gbrain open {slug}`.
        """)
        // The second statement is the command; it must lower (no scope error)
        // because `slug` is bound by the preceding statement.
        let cmd = workflows[0].body.statements.compactMap { stmt -> IRExpression? in
            if case .invoke(let inv) = stmt, inv.toolID == "shell.run" {
                return inv.arguments.first(where: { $0.key == "command" })?.value
            }
            return nil
        }.first
        guard case .interpolatedString = cmd else {
            Issue.record("expected the command to interpolate the bound slug"); return
        }
    }

    @Test("a hole resolves against the enclosing loop variable")
    func holeResolvesToLoopVar() throws {
        let workflows = try lower("""
        To demo:
          for each order:
            `gbrain get {the order's id}`.
        """)
        guard case .iterate(let it) = workflows[0].body.statements.first else {
            Issue.record("expected a loop"); return
        }
        guard case .invoke(let inv) = it.body.statements.first,
              case .interpolatedString = inv.arguments.first(where: { $0.key == "command" })?.value else {
            Issue.record("expected the loop body command to interpolate the loop var"); return
        }
    }

    @Test("the unresolved-hole error names the bad reference and lists in-scope names")
    func unresolvedHoleErrorMessage() {
        do {
            _ = try lower("""
            To process an order:
              `echo {the widget count}`.
            """)
            Issue.record("expected a semantic error")
        } catch let error as CompilerError {
            let message = "\(error)"
            #expect(message.contains("widget"))
            #expect(message.contains("in scope") || message.contains("In-scope"))
            // `order` is the workflow parameter and must be listed as in-scope.
            #expect(message.contains("order"))
        } catch {
            Issue.record("expected CompilerError, got \(error)")
        }
    }
}

// MARK: - 1B. migrate-skill placeholder rewrite

@Suite("Wave 1B — migrate-skill placeholder rewrite")
struct CommandPlaceholderMigrationTests {

    private func migrator() -> SkillMigrator {
        SkillMigrator(compiler: Compiler(options: .init(fallbackPolicy: .lenient)), vocabularies: [])
    }

    @Test("an in-scope placeholder inside a command span is rewritten to a hole")
    func inScopePlaceholderRewritten() {
        let src = """
        ---
        parameters: slug
        ---
        ## Procedure
        - `gbrain open <slug>`.
        """
        let out = migrator().rewriteCommandPlaceholders(src)
        #expect(out.contains("`gbrain open {slug}`"))
        #expect(!out.contains("<slug>"))
    }

    @Test("an out-of-scope placeholder is left untouched")
    func outOfScopeUntouched() {
        let src = """
        ---
        parameters: slug
        ---
        ## Procedure
        - `gbrain open <attendee name>`.
        """
        let out = migrator().rewriteCommandPlaceholders(src)
        #expect(out.contains("<attendee name>"))
    }

    @Test("placeholders outside command spans are not rewritten")
    func prosePlaceholderUntouched() {
        let src = """
        ---
        parameters: slug
        ---
        ## Notes
        Use the <slug> carefully.
        """
        let out = migrator().rewriteCommandPlaceholders(src)
        #expect(out.contains("<slug>"))
    }

    @Test("detectCategories flags command-hole-rewritten")
    func categoryDetected() {
        let original = """
        ## Procedure
        - `gbrain open <slug>`.
        """
        let ported = """
        ## Procedure
        - `gbrain open {slug}`.
        """
        let cats = SkillDeviation.detectCategories(
            originalMarkdown: original, portedMeri: ported, frontmatterAdded: [])
        #expect(cats.contains("command-hole-rewritten"))
    }
}

// MARK: - 1D. Tools Used + output invariants

@Suite("Wave 1D — metadata sections + output invariants")
struct MetadataSectionTests {

    private func compile(_ src: String) throws -> String {
        try Compiler(options: .init(fallbackPolicy: .lenient)).compile(
            meridianSource: src, meridianFile: "test.meridian",
            merconfigSource: "", merconfigFile: "test.merconfig")
    }

    private func manifest(_ src: String) throws -> ManifestEmitter.Input {
        try Compiler(options: .init(fallbackPolicy: .lenient)).compileWithManifest(
            meridianSource: src, meridianFile: "test.meridian",
            vocabularies: []).manifest
    }

    @Test("Tools Used bullets are mined into the manifest tools_used")
    func toolsUsedScoped() throws {
        let m = try manifest("""
        ## Protocol
        `echo hi`

        ## Tools Used
        - Search the brain (gbrain_search)
        - Open a page (gbrain_open)
        """)
        #expect(m.toolsUsed.contains("gbrain_search"))
        #expect(m.toolsUsed.contains("gbrain_open"))
    }

    @Test("a malformed Tools Used bullet is a hard error")
    func malformedToolBullet() {
        #expect(throws: CompilerError.self) {
            _ = try compile("""
            ## Protocol
            `echo hi`

            ## Tools Used
            - Search the brain with no id
            """)
        }
    }

    @Test("output invariant `every emitted X matches pattern` lowers to a regex assert")
    func outputInvariant() throws {
        let out = try compile("""
        ## Contract
        - every emitted brain page matches pattern "^# ".

        ## Protocol
        `echo hi`
        """)
        #expect(out.contains("meridianRegexMatches"))
        #expect(out.contains("private func meridianRegexMatches"))
    }

    @Test("output invariant generalizes beyond regex to any checkable predicate")
    func outputInvariantGeneralized() throws {
        let out = try compile("""
        ## Contract
        - every emitted report contains "Sources".
        - each emitted summary is not empty.

        ## Protocol
        `echo hi`
        """)
        // `every emitted X contains "Y"` → assert on bound result `report`.
        #expect(out.contains(".contains("))
        // `each emitted X is not empty` → emptiness assert on `summary`.
        #expect(out.contains("MeridianComparison.isNotEmpty"))
    }

    @Test("a Tools Used heading resolves to the tools role")
    func toolsRole() {
        #expect(SkillSectionRole.builtinRole(forHeading: "Tools Used") == .tools)
        #expect(SkillSectionRole.tools.isExecutable == false)
    }

    @Test("multiple Tools Used bullets across the section all merge into the manifest")
    func multipleToolsMerge() throws {
        let m = try manifest("""
        ## Protocol
        `echo hi`

        ## Tools Used
        - Search the brain (gbrain_search)
        - Open a page (gbrain_open)
        - Publish a page (gbrain_publish)
        """)
        #expect(Set(["gbrain_search", "gbrain_open", "gbrain_publish"]).isSubset(of: Set(m.toolsUsed)))
    }

    @Test("a tool id with dots and dashes is accepted")
    func dottedToolId() throws {
        let m = try manifest("""
        ## Protocol
        `echo hi`

        ## Tools Used
        - Fetch a URL (http.get)
        - Run a check (ci-runner)
        """)
        #expect(m.toolsUsed.contains("http.get"))
        #expect(m.toolsUsed.contains("ci-runner"))
    }

    @Test("conventionRef is a non-executable role")
    func conventionRefNonExecutable() {
        #expect(SkillSectionRole.conventionRef.rawValue == "convention-ref")
        #expect(SkillSectionRole.conventionRef.isExecutable == false)
    }
}

// MARK: - 1D. Convention restatement (migrator marking)

@Suite("Wave 1D — convention restatement")
struct ConventionRestatementTests {

    private func migrator(_ rulebook: String) -> SkillMigrator {
        SkillMigrator(
            compiler: Compiler(options: .init(fallbackPolicy: .lenient)),
            vocabularies: [],
            rulebooks: [RulebookInput(name: "t", file: "t.merrules", source: rulebook)])
    }

    private let rulebook = """
    === conventions ===
    after filing a page:
      always include a citation.
    """

    @Test("a section body that verbatim restates a convention is marked convention-ref")
    func restatementMarked() {
        let out = migrator(rulebook).markSections("""
        ## Citation Policy
        Always include a citation.
        """).markdown
        #expect(out.contains("(( inert, role: convention-ref ))"))
    }

    @Test("a section that does not restate a convention is plain inert")
    func nonRestatementInert() {
        let out = migrator(rulebook).markSections("""
        ## Random Notes
        This text matches no convention at all.
        """).markdown
        #expect(out.contains("(( inert ))"))
        #expect(!out.contains("convention-ref"))
    }

    @Test("with no rulebook conventions, nothing is marked convention-ref")
    func noConventionsNoMark() {
        let mig = SkillMigrator(
            compiler: Compiler(options: .init(fallbackPolicy: .lenient)), vocabularies: [])
        let out = mig.markSections("""
        ## Citation Policy
        Always include a citation.
        """).markdown
        #expect(!out.contains("convention-ref"))
    }
}

// MARK: - 1C. Predicate / temporal / ordering iteration refinements

@Suite("Wave 1C — iteration refinements")
struct IterationRefinementTests {

    private func iterate(_ source: String) throws -> IterateIR? {
        let symbols = SymbolTable()
        let ast = try MeridianParser(symbols: symbols, trace: .silent())
            .parse(source, file: "test.meridian")
        let workflows = try ASTToIR(symbols: symbols, sourceFile: "test.meridian", trace: .silent()).lower(ast)
        for stmt in workflows[0].body.statements {
            if case .iterate(let ir) = stmt { return ir }
        }
        return nil
    }

    @Test("whose + sorted by + first N populate the refinement")
    func fullRefinement() throws {
        let ir = try iterate("""
        To process:
          for each the first 3 orders whose total is at least 100 sorted by created at, newest first:
            `echo hi`.
        """)
        guard let source = ir?.source else { Issue.record("expected refinement"); return }
        #expect(source.take == 3)
        #expect(source.sort?.path == "createdAt")
        #expect(source.sort?.ascending == false)
        #expect(source.filters.count == 1)
        guard case .comparison(let lhs, .greaterOrEqual, _) = source.filters[0] else {
            Issue.record("expected >= comparison"); return
        }
        // LHS is qualified to the loop variable `order`.
        guard case .propertyAccess(.identifierRef("order"), "total") = lhs else {
            Issue.record("expected order.total property access, got \(lhs)"); return
        }
    }

    @Test("temporal `within the last` lowers to a one-sided past window")
    func temporalPast() throws {
        let ir = try iterate("""
        To process:
          for each order within the last 7 days:
            `echo hi`.
        """)
        guard let source = ir?.source, source.filters.count == 1 else {
            Issue.record("expected one temporal filter"); return
        }
        guard case .comparison(.propertyAccess(.identifierRef("order"), "updatedAt"), .withinPast, _) = source.filters[0] else {
            Issue.record("expected updatedAt withinPast comparison, got \(source.filters[0])"); return
        }
    }

    @Test("a plain `for each` has no refinement")
    func plainNoRefinement() throws {
        let ir = try iterate("""
        To process:
          for each order:
            `echo hi`.
        """)
        #expect(ir?.source == nil)
    }

    @Test("refined iterate emits a pre-loop filter/sort/prefix pipeline")
    func codegenPipeline() throws {
        let cfg = ""
        let out = try Compiler(options: .init(fallbackPolicy: .lenient)).compile(
            meridianSource: """
            To process:
              for each the first 2 orders whose total is at least 100 sorted by created at, newest first:
                `echo hi`.
            """,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains(".filter { __e in"))
        #expect(out.contains(".sorted { __a, __b in MeridianComparison.orderedBefore"))
        #expect(out.contains(".prefix(2)"))
        #expect(out.contains("__e.member(\"total\")"))
    }

    @Test("temporal `in the next` lowers to a one-sided future window")
    func temporalFuture() throws {
        let ir = try iterate("""
        To process:
          for each order in the next 3 days:
            `echo hi`.
        """)
        guard let source = ir?.source, source.filters.count == 1 else {
            Issue.record("expected one temporal filter"); return
        }
        guard case .comparison(.propertyAccess(.identifierRef("order"), "updatedAt"), .withinFuture, _) = source.filters[0] else {
            Issue.record("expected updatedAt withinFuture comparison, got \(source.filters[0])"); return
        }
    }

    @Test("`sorted by` without a direction defaults to ascending")
    func sortDefaultAscending() throws {
        let ir = try iterate("""
        To process:
          for each order sorted by created at:
            `echo hi`.
        """)
        #expect(ir?.source?.sort?.path == "createdAt")
        #expect(ir?.source?.sort?.ascending == true)
    }

    @Test("`oldest first` sorts ascending; `newest first` sorts descending")
    func sortDirections() throws {
        let oldest = try iterate("""
        To process:
          for each order sorted by created at, oldest first:
            `echo hi`.
        """)
        #expect(oldest?.source?.sort?.ascending == true)
        let newest = try iterate("""
        To process:
          for each order sorted by created at, newest first:
            `echo hi`.
        """)
        #expect(newest?.source?.sort?.ascending == false)
    }

    @Test("`the first N` alone sets take with no filter or sort")
    func takeOnly() throws {
        let ir = try iterate("""
        To process:
          for each the first 5 orders:
            `echo hi`.
        """)
        #expect(ir?.source?.take == 5)
        #expect(ir?.source?.filters.isEmpty == true)
        #expect(ir?.source?.sort == nil)
    }

    @Test("a refinement on an explicit `for each X in Y` collection still parses")
    func explicitCollectionWithRefinement() throws {
        let ir = try iterate("""
        To process:
          for each the first 2 orders in the queue sorted by total, newest first:
            `echo hi`.
        """)
        // `the queue` is the collection; refinement (take + sort) is still parsed.
        #expect(ir?.source?.take == 2)
        #expect(ir?.source?.sort?.path == "total")
        #expect(ir?.source?.sort?.ascending == false)
    }

    @Test("the refined codegen omits the prefix line when there is no take")
    func codegenNoPrefixWithoutTake() throws {
        let out = try Compiler(options: .init(fallbackPolicy: .lenient)).compile(
            meridianSource: """
            To process:
              for each order whose total is at least 100:
                `echo hi`.
            """,
            meridianFile: "test.meridian", merconfigSource: "", merconfigFile: "test.merconfig")
        #expect(out.contains(".filter { __e in"))
        #expect(!out.contains(".prefix("))
    }

    @Test("`whose … contains …` lowers to a .contains filter and emits a string contains")
    func containsComparator() throws {
        let ir = try iterate("""
        To process:
          for each order whose tags contains "urgent":
            `echo hi`.
        """)
        guard let source = ir?.source, source.filters.count == 1 else {
            Issue.record("expected one filter"); return
        }
        guard case .comparison(.propertyAccess(.identifierRef("order"), "tags"), .contains, _) = source.filters[0] else {
            Issue.record("expected order.tags contains comparison, got \(source.filters[0])"); return
        }
        let out = try Compiler(options: .init(fallbackPolicy: .lenient)).compile(
            meridianSource: """
            To process:
              for each order whose tags contains "urgent":
                `echo hi`.
            """,
            meridianFile: "test.meridian",
            merconfigSource: "",
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains(".filter { __e in"))
        #expect(out.contains("__e.member(\"tags\")"))
        #expect(out.contains(".contains("))
    }

    @Test("`whose … is one of …` lowers to a .oneOf filter")
    func oneOfComparator() throws {
        let ir = try iterate("""
        To process:
          for each order whose status is one of "open", "pending":
            `echo hi`.
        """)
        guard let source = ir?.source, source.filters.count == 1 else {
            Issue.record("expected one filter"); return
        }
        guard case .comparison(.propertyAccess(.identifierRef("order"), "status"), .oneOf, _) = source.filters[0] else {
            Issue.record("expected order.status oneOf comparison, got \(source.filters[0])"); return
        }
    }

    @Test("a capitalized `For every X:` block header is a loop, not a topic label")
    func capitalizedBlockHeaderIsLoop() throws {
        // A capitalized header ending in `:` (`For every attendee:`) used to
        // match the topic-label rule (uppercase, ≤40 chars, letters/spaces) with
        // an empty body and was dropped, orphaning the loop-body bullets at the
        // top level so a `{loop var}` hole could not resolve. The iteration check
        // now precedes the topic-label rule.
        let ir = try iterate("""
        To process:
          For every attendee:
            `gbrain get {the attendee's slug}`.
        """)
        guard let ir else { Issue.record("expected an iteration, header was dropped"); return }
        guard case .overCollection(let parameter, _, _) = ir.mode else {
            Issue.record("expected overCollection mode"); return
        }
        #expect(parameter == "attendee")
        // The body bullet is inside the loop (so the hole resolves against the
        // loop variable) rather than orphaned at the top level.
        #expect(ir.body.statements.count == 1)
    }
}
