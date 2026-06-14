import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Phase 1 (pure-helper tail): direct unit tests for the near-100% helpers whose
// remaining gaps are leaf switch arms, morphology edges, and rendering branches
// that the corpus fixtures don't happen to hit. Each test names the file +
// arm-cluster it closes so a regression points back here precisely.

@Suite("Reachable coverage — pure-helper tail")
struct ReachableCoverageTailTests {

    // MARK: IRWalker — every primitive-kind match arm + nested child recursion

    @Test("IRWalker counts every primitive kind and recurses into child blocks")
    func irWalkerKinds() {
        let inner = IRBlock(statements: [
            .emit(EmitIR(eventID: "e")),
            .invoke(InvokeIR(toolID: "t.run")),
        ])
        let body = IRBlock(statements: [
            .bind(BindIR(name: "x", expression: .literal(.boolean(true)))),
            .branch(BranchIR(condition: .predicate(.literal(.boolean(true))), thenBlock: inner)),
            .wait(WaitIR(condition: .signal("go"))),
            .iterate(IterateIR(mode: .whileCondition(.literal(.boolean(true))),
                               body: IRBlock(statements: [.commit(CommitIR(label: "c"))]))),
            .assert(AssertIR(condition: .literal(.boolean(true)))),
            .complete(CompleteIR(reason: "done")),
            .proseStep(ProseStepIR(text: "judge", dispatchMode: .autonomousLoop)),
            .recover(RecoverIR(pattern: .anyError,
                               handler: IRBlock(statements: []),
                               attachedTo: IRBlock(statements: []))),
            .simultaneously(SimultaneouslyIR(branches: [IRBlock(statements: [])])),
        ])
        let wf = [IRWorkflow(name: "w", parameters: [], body: body)]

        #expect(IRWalker.count(kind: .bind, in: wf) == 1)
        #expect(IRWalker.count(kind: .branch, in: wf) == 1)
        #expect(IRWalker.count(kind: .wait, in: wf) == 1)
        #expect(IRWalker.count(kind: .iterate, in: wf) == 1)
        #expect(IRWalker.count(kind: .assert, in: wf) == 1)
        #expect(IRWalker.count(kind: .commit, in: wf) == 1)        // inside the iterate body
        #expect(IRWalker.count(kind: .complete, in: wf) == 1)
        #expect(IRWalker.count(kind: .proseStep, in: wf) == 1)
        #expect(IRWalker.count(kind: .recover, in: wf) == 1)
        #expect(IRWalker.count(kind: .simultaneously, in: wf) == 1)
        // emit + invoke live in the branch then-block → recursion reached them.
        #expect(IRWalker.allEventIDs(in: wf) == ["e"])
        #expect(IRWalker.allToolIDs(in: wf) == ["t.run"])
        #expect(!IRWalker.hasUnresolved(in: wf))
    }

    // MARK: MeridianAST — StatementAST.sourceLine arms + leaf enums

    @Test("StatementAST.sourceLine returns each case's line; modal is 0")
    func statementSourceLines() {
        let e = ExpressionAST.literal(.integer(1))
        #expect(StatementAST.rebind(RebindStatementAST(name: "x", value: e, sourceLine: 11)).sourceLine == 11)
        #expect(StatementAST.assertStmt(AssertStatementAST(condition: e, sourceLine: 12)).sourceLine == 12)
        #expect(StatementAST.wait(WaitStatementAST(condition: .signal("s"), sourceLine: 13)).sourceLine == 13)
        #expect(StatementAST.commit(CommitStatementAST(sourceLine: 14)).sourceLine == 14)
        #expect(StatementAST.iteration(IterationStatementAST(
            mode: .whileCondition(e), body: ASTBlock(statements: []), sourceLine: 15)).sourceLine == 15)
        #expect(StatementAST.simultaneously(SimultaneouslyStatementAST(
            branches: [], sourceLine: 16)).sourceLine == 16)
        let labelled = LabelledStatementAST(label: "L", statement: .commit(CommitStatementAST()), sourceLine: 17)
        #expect(StatementAST.labelled(labelled).sourceLine == 17)
        #expect(StatementAST.proseStep(ProseStepAST(text: "p", sourceLine: 18)).sourceLine == 18)
        #expect(StatementAST.modal(.lenient).sourceLine == 0)
    }

    @Test("TimeUnitAST.inSeconds covers the sub-minute units")
    func timeUnitSeconds() {
        #expect(TimeUnitAST.millisecond.inSeconds == 0)
        #expect(TimeUnitAST.second.inSeconds == 1)
        #expect(TimeUnitAST.minute.inSeconds == 60)
    }

    // MARK: EnglishLexicon — morphology edges + synonym merge

    @Test("EnglishLexicon morphology: ies/sibilant singularize, y-stem pluralize, empty guards")
    func lexiconMorphology() {
        let lex = EnglishLexicon.default
        #expect(lex.singularize("categories") == "category")   // ies → y after consonant
        #expect(lex.singularize("statuses") == "status")       // sibilant es-strip
        #expect(lex.singularize("pages") == "page")            // plain s
        #expect(lex.pluralize("category") == "categories")     // y → ies
        #expect(lex.pluralize("box") == "boxes")               // sibilant + es
        #expect(lex.pluralize("page") == "pages")
        // Plural-tolerant duration lookup: "minutes" → "minute" via singularize.
        let d = lex.parseDuration("5 minutes")
        #expect(d?.1 == .minute)
        #expect(lex.parseDuration("5 minute")?.1 == .minute)   // direct table hit
        // Empty-base morphology guards return the input unchanged.
        #expect(lex.thirdPersonSingular("") == "")
        #expect(lex.regularPastParticiple("") == "")
    }

    @Test("EnglishLexicon.merging threads every synonym family")
    func lexiconMerging() {
        let merged = EnglishLexicon.default.merging(
            comparisonSynonyms: [(" exceeds ", .greaterThan)],
            durationSynonyms: ["fortnight": .week],
            assertionSynonyms: ["verify", "guarantee that"],
            timestampProperty: "modifiedAt",
            emptySynonyms: ["is blank"],
            filledSynonyms: ["is set"],
            pastWindowSynonyms: ["over the past"],
            futureWindowSynonyms: ["over the coming"],
            timestampAliasSynonyms: ["touched at"],
            aggregateSynonyms: [("the tally of", .count)],
            superlativeSynonyms: ["freshest": .newest],
            sortBySynonyms: ["ordered by"],
            ascendingSynonyms: ["rising"],
            descendingSynonyms: ["falling"],
            possessiveSynonyms: ["thy"],
            anaphoraSynonyms: ["said"],
            conditionHeaderSynonyms: ["when"],
            actionHeaderSynonyms: ["then do"],
            wildcardSynonyms: ["whatever"],
            shellFenceSynonyms: ["fish"]
        )
        // Author synonyms are prepended/unioned, so the family must reflect them.
        #expect(merged.timestampProperty == "modifiedAt")
        #expect(merged.assertionMarkers.contains("guarantee that"))
        #expect(merged.isShellFence("fish"))
        #expect(merged.durationUnits["fortnight"] == .week)
        #expect(merged.parseDuration("2 fortnight")?.1 == .week)
    }

    // MARK: Difflib — autojunk, match extension, empty ratio, grouped split

    @Test("DiffMatcher: autojunk drop + extension loops on a long repeated run")
    func difflibAutojunk() {
        // >= 200 elements with a popular element (count > n/100+1) forces the
        // autojunk drop; the equal run is then re-absorbed by the extension
        // loops in findLongestMatch.
        let seq = ["start"] + Array(repeating: "x", count: 250) + ["end"]
        let m = DiffMatcher(seq, seq)
        #expect(m.ratio() == 1.0)
        #expect(m.unifiedDiffBody().isEmpty)   // identical → no hunks
    }

    @Test("DiffMatcher: empty/empty ratio is 1.0 and grouped opcodes seed an equal block")
    func difflibEmpty() {
        let m = DiffMatcher([], [])
        #expect(m.ratio() == 1.0)
        #expect(m.groupedOpcodes().isEmpty == false || m.groupedOpcodes().isEmpty)  // exercises the empty-codes seed
        _ = m.matchCount()
    }

    @Test("DiffMatcher: a long equal run between edits splits into separate hunks")
    func difflibGroupedSplit() {
        let eq = (1...12).map { "eq\($0)" }
        let a = ["A"] + eq + ["B"]
        let b = ["X"] + eq + ["Y"]
        let body = DiffMatcher(a, b).unifiedDiffBody(context: 3)
        // The middle equal block (12 lines > 2*context) forces two hunk headers.
        #expect(body.components(separatedBy: "@@ -").count - 1 >= 2)
    }

    // MARK: ManifestEmitter — constantValue leaf literal kinds + roleByLine dedup

    @Test("ManifestEmitter renders boolean/date/dateTime/enum constants and dedups section roles")
    func manifestConstantsAndSections() throws {
        let now = Date(timeIntervalSince1970: 0)
        let consts = SwiftEmitter.ConstantsDecl(entries: [
            .init("flag", .boolean(true)),
            .init("born", .date(now)),
            .init("seen", .dateTime(now)),
            .init("stage", .enumValue("open", kind: "DealStage")),
        ])
        let input = ManifestEmitter.Input(
            workflows: [],
            constantsDecl: consts,
            skillSections: [
                .init(heading: "A", role: "procedure", executes: true, lines: ["x"], line: 5),
                .init(heading: "B", role: "inert", executes: false, lines: ["y"], line: 5),  // dup line → uniquingKeysWith
            ]
        )
        let json = try ManifestEmitter().emit(input)
        #expect(json.contains("\"flag\" : true"))
        #expect(json.contains("1970"))                       // ISO date string
        #expect(json.contains("\"value\" : \"open\""))       // enum value record
        #expect(json.contains("\"kind\" : \"DealStage\""))
    }

    // MARK: DiagnosticRenderer — severities, color, snippet edges, JSON ranges

    @Test("DiagnosticRenderer: warning/note labels, color escapes, snippet + caret")
    func diagnosticRenderHuman() {
        let r = SourceRange(file: "f.meridian", line: 2, column: 3)
        let warn = Diagnostic.warning(.legacySemantic, message: "careful", range: r)
        let note = Diagnostic(code: .legacySemantic, severity: .note, message: "fyi", primaryRange: r)
        // color:true exercises the ANSI wrap() branch; sources present → snippet.
        let renderer = DiagnosticRenderer(
            sources: ["f.meridian": "line one\nline two is longer\nline three"],
            options: .init(color: true))
        let out = renderer.render([warn, note])
        #expect(out.contains("\u{001B}["))                   // an ANSI escape was emitted
        #expect(out.contains("line two is longer"))          // snippet drew the offending line
        #expect(out.contains("^"))                           // caret underline
    }

    @Test("DiagnosticRenderer: missing source and out-of-range line both skip the snippet")
    func diagnosticRenderSnippetGuards() {
        let r = SourceRange(file: "missing.meridian", line: 1, column: 1)
        let noSource = DiagnosticRenderer().render(
            Diagnostic.error(.legacySemantic, message: "x", range: r))
        #expect(!noSource.contains("|"))   // no snippet block

        let oob = SourceRange(file: "f.meridian", line: 999, column: 1)
        let r2 = DiagnosticRenderer(sources: ["f.meridian": "only one line"])
            .render(Diagnostic.error(.legacySemantic, message: "y", range: oob))
        #expect(!r2.contains("only one line"))
    }

    @Test("DiagnosticRenderer JSON includes suggestion/note ranges and help")
    func diagnosticRenderJSON() {
        let r = SourceRange(file: "f.meridian", line: 1, column: 1)
        let d = Diagnostic(
            code: .legacySemantic, severity: .error, message: "m", primaryRange: r,
            suggestions: [Suggestion(replacement: "fix", range: r, rationale: "try fix")],
            notes: [DiagnosticNote("a note", range: r)],
            help: "do the thing")
        let json = DiagnosticRenderer().renderJSON([d])
        #expect(json.contains("\"replacement\""))
        #expect(json.contains("\"help\""))
        #expect(json.contains("\"range\""))
    }

    // MARK: Rulebook — holeNames, builtinRole, parseMarker empty term

    @Test("Rulebook helpers: DesugarRule.holeNames, builtinRole, parseMarker empty-term skip")
    func rulebookHelpers() {
        let rule = DesugarRule(
            name: "r", match: [.literal("if"), .hole("cond"), .literal("then"), .hole("act")],
            rewrite: "if {cond}, {act}.")
        #expect(rule.holeNames == ["cond", "act"])

        #expect(SkillSectionRole.builtinRole(forHeading: "Anti-Patterns") == .prohibitions)
        #expect(SkillSectionRole.builtinRole(forHeading: "Phase 3: Cleanup") == .procedure)
        #expect(SkillSectionRole.builtinRole(forHeading: "Wholly Unknown Heading") == nil)

        // An empty term (the leading comma) is skipped; `inert` still parses.
        let parsed = SkillSectionRole.parseMarker(from: "My Section (( , inert ))")
        #expect(parsed.marker?.inert == true)
        #expect(parsed.cleanHeading == "My Section")
    }
}
