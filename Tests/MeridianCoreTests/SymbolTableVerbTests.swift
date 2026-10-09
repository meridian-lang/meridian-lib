import Testing
@testable import MeridianCore

@Suite("SymbolTable — verb form and tool resolution")
struct SymbolTableVerbTests {
    private func symbols() throws -> SymbolTable {
        let cfg = try MerConfigParser().parse("""
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.

        Ownership relates one user to various pages.
        Ownership is read from the page's owner.
        The verb to own (it owns, it is owned) means the ownership relation.

        === tools ===

        Archive Page
        ============
        ~ archivePage(id: String) : Page
        """, file: "t.merconfig")
        return SymbolTable.build(from: cfg, sourceFile: "t.merconfig")
    }

    @Test("isVerbForm recognizes base, third-person, and participle forms")
    func verbForms() throws {
        let s = try symbols()
        #expect(s.isVerbForm("own"))
        #expect(s.isVerbForm("owns"))
        #expect(s.isVerbForm("owned"))
        #expect(!s.isVerbForm("frobnicate"))
    }

    @Test("resolveVerbForm carries the role for each surface form")
    func verbRole() throws {
        let s = try symbols()
        #expect(s.resolveVerbForm("owned")?.role == .pastParticiple)
        #expect(s.resolveVerbForm("own")?.verb.base == "own")
    }

    @Test("a declared tool resolves by display name and methodName")
    func toolLookup() throws {
        let s = try symbols()
        #expect(s.tool(named: "archivePage") != nil)
    }

    @Test("matchPhrase on whitespace-only input returns nil")
    func emptyInvocationNoMatch() throws {
        let s = try symbols()
        #expect(s.matchPhrase("   ") == nil)
    }

    @Test("extractArgs strips trailing punctuation after the kind word")
    func extractArgsStripsTrailers() throws {
        let s = try symbols()
        let pattern = PhrasePattern(segments: [
            .literal("archive "),
            .parameter(PhraseParameterAST(name: "page", kind: "page")),
        ])
        s.registerWorkflowPhrase(pattern: pattern, structName: "ArchivePage", sourceLine: 1, sourceFile: "t.merconfig")
        let (_, args) = try #require(s.matchPhrase("archive the page,"))
        if case .identifierRef(let name) = args["page"] {
            #expect(name.lowercased().contains("page"))
        } else {
            Issue.record("expected identifierRef for page argument")
        }
    }

    @Test("propertyNames returns an empty set for a kind with no declared properties")
    func propertyNamesUnknownKindIsEmpty() throws {
        let s = try symbols()
        #expect(s.propertyNames(of: "no-such-kind").isEmpty)
    }

    @Test("build backfills an empty phrase sourceFile from the config's own sourceFile")
    func buildBackfillsPhraseSourceFile() {
        let pattern = PhrasePattern(segments: [.literal("greet")])
        let phrase = PhraseDefinition(pattern: pattern, body: ASTBlock(statements: [], sourceLine: 1))
        #expect(phrase.sourceFile.isEmpty)
        let cfg = MerConfigFile(vocabulary: [.phrase(phrase)])
        let table = SymbolTable.build(from: cfg, sourceFile: "backfilled.merconfig")
        #expect(table.phrases.first?.sourceFile == "backfilled.merconfig")
    }

    @Test("tool(fromWords:) rejects an all-stopword invocation before scoring any candidate")
    func toolFromWordsRejectsStopwordOnlyInput() throws {
        let s = try symbols()
        #expect(s.tool(fromWords: "") == nil)
        #expect(s.tool(fromWords: lexiconStopwordPhrase(s)) == nil)
    }

    private func lexiconStopwordPhrase(_ s: SymbolTable) -> String {
        s.lexicon.toolStopwords.sorted().prefix(3).joined(separator: " ")
    }

    @Test("matchPhraseDirect traces 'no significant words' for a stopword-only invocation")
    func matchPhraseTracesNoSignificantWords() throws {
        let s = try symbols()
        let cap = ParserTrace.capturing(categories: [.phraseMatch])
        #expect(cap.trace.run { s.matchPhrase("   ") } == nil)
        #expect(cap.lines().contains { $0.contains("no significant words") })
    }

    @Test("matchPhrase traces the implicit-fill retry when the direct match fails")
    func matchPhraseTracesImplicitFillRetry() throws {
        let s = try symbols()
        let cap = ParserTrace.capturing(categories: [.phraseMatch])
        let defaultParam = PhraseParameterAST(name: "page", kind: "page")
        _ = cap.trace.run { s.matchPhrase("totally unrelated gibberish", defaultParam: defaultParam) }
        #expect(cap.lines().contains { $0.contains("phrase.match.implicit-fill") })
    }

    @Test("matchPhraseDirect traces skipping a candidate excluded by structName during the implicit-fill retry")
    func matchPhraseDirectTracesExcludedCandidate() throws {
        let s = try symbols()
        let pattern = PhrasePattern(segments: [
            .literal("greet "),
            .parameter(PhraseParameterAST(name: "user", kind: "user")),
        ])
        s.registerWorkflowPhrase(pattern: pattern, structName: "GreetUser", sourceLine: 1, sourceFile: "t.merconfig")
        let cap = ParserTrace.capturing(categories: [.phraseMatch])
        // The direct match on the raw invocation misses (no shared literal
        // with "greet"), so `matchPhrase` falls through to the implicit-fill
        // retry, which is the only call that receives `excludingStructName`.
        let defaultParam = PhraseParameterAST(name: "user", kind: "user")
        let result = cap.trace.run {
            s.matchPhrase("totally unrelated gibberish", defaultParam: defaultParam, excludingStructName: "GreetUser")
        }
        #expect(result == nil)
        #expect(cap.lines().contains { $0.contains("excluded: self-referential implicit fill") })
    }

    @Test("matchPhraseDirect traces and rejects a candidate whose only extractable argument is malformed")
    func matchPhraseDirectRejectsMalformedArgument() throws {
        let s = try symbols()
        let pattern = PhrasePattern(segments: [
            .literal("archive "),
            .parameter(PhraseParameterAST(name: "page", kind: "page")),
        ])
        s.registerWorkflowPhrase(pattern: pattern, structName: "ArchivePage", sourceLine: 1, sourceFile: "t.merconfig")
        let cap = ParserTrace.capturing(categories: [.phraseMatch])
        // Nothing follows the literal, so the parameter's raw arg text is
        // empty and `ExpressionParser.parseAtom` yields `.malformed`.
        let result = cap.trace.run { s.matchPhrase("archive") }
        #expect(result == nil)
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("reject") && $0.contains("malformed argument") })
        #expect(lines.contains { $0.contains("no match (every candidate left a malformed argument)") })
    }

    @Test("extractArgs traces a literal word that is absent from the remaining invocation text")
    func extractArgsTracesMissingLiteralWord() throws {
        let s = try symbols()
        let pattern = PhrasePattern(segments: [
            .literal("archive the "),
            .parameter(PhraseParameterAST(name: "page", kind: "page")),
        ])
        s.registerWorkflowPhrase(pattern: pattern, structName: "ArchiveThePage", sourceLine: 1, sourceFile: "t.merconfig")
        let cap = ParserTrace.capturing(categories: [.phraseExtractArgs])
        // "the" is a pattern literal word but never appears in the invocation.
        _ = cap.trace.run { s.matchPhrase("archive page1") }
        #expect(cap.lines().contains { $0.contains("literal word \"the\" NOT FOUND") })
    }
}
