import Testing
@testable import MeridianCore
@testable import MeridianRuntime

@Suite("Phase F language surfaces")
struct PhaseFLanguageTests {
    private let cfg = """
    === vocabulary ===
    A page is a kind of thing.
    A page has a text called the title.
    === tools ===
    Gbrain Search
    ================
    ~ gbrain.search(query: String) : Boolean
    Slack Read
    ================
    ~ slack.read(channel: String) : Boolean
  """

    private func compile(_ mer: String, file: String = "test.meridian") throws -> String {
        try Compiler(options: .init(trace: .silent())).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: file)], vocabularies: [.init(name: "t", file: "t.merconfig", source: cfg)]))[file]!.swift
    }

    @Test("wait with timeout and recover lowers recover from wait.timeout")
    func waitTimeoutRecover() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To wait for ack:
          wait for signal "ready" with timeout 5 minutes recovering on timeout:
            emit ack.timed_out.
          complete.
        """
        let out = try compile(mer)
        #expect(out.contains("wait.timeout"))
        #expect(out.contains("timeout: .seconds("))
    }

    @Test("judgment producing and using scopes tools")
    func judgmentProducingUsing() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        tools: gbrain.search, slack.read
        ---
        To draft a summary:
          use judgment to compose the narrative, producing a text called the narrative, using gbrain.search:
            Keep it short.
          complete.
        """
        let out = try compile(mer)
        #expect(out.contains("gbrain.search"))
        #expect(out.contains("outputKind: \"text\""))
    }

    @Test("judgment tool outside permissions is MER-JDG-002")
    func judgmentToolOutsidePermissions() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        tools: gbrain.search
        ---
        To draft a summary:
          use judgment to compose the narrative, using slack.read:
            Keep it short.
          complete.
        """
        do {
            _ = try compile(mer)
            Issue.record("Expected permission error")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .judgmentToolOutsidePermissions })
        }
    }

    @Test("the last N take suffix parses on descriptions")
    func lastNTakeSuffix() throws {
        let symbols = SymbolTable.build(
            from: try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig"),
            trace: .silent()
        )
        let parsed = DescriptionGrammar(
            lexicon: .default,
            symbols: symbols,
            atom: { .malformed($0) },
            recurse: { _ in .malformed("") }
        ).parse("the last 3 pages whose status is \"open\"")
        let desc = try #require(parsed)
        #expect(desc.takeFromEnd == 3)
        #expect(desc.noun.lowercased().contains("page"))
    }

    @Test("obligation assert emits recordViolation observed")
    func assertObligationViolationWitness() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        A page is healthy must hold.

        To inspect pages:
          assert every page is healthy.
          complete.
        """
        let out = try compile(mer)
        #expect(out.contains("recordViolation"))
        #expect(out.contains("observed"))
    }

    @Test("commit emits checkpoint call")
    func commitCheckpoint() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To save:
          commit.
          complete.
        """
        let out = try compile(mer)
        #expect(out.contains("runtime.checkpoint"))
    }

    private let gradableCfg = """
    === vocabulary ===
    A deal is a kind of thing.
    A deal has an amount, which is Money.
    Definition: a deal is urgent if its amount is more than 1000.
    === language ===
    Gradable adjectives:
      urgent = amount descending
    """

    @Test("gradable adjective metadata enables most-adjective superlative")
    func gradableAdjectiveSuperlative() throws {
        let config = try MerConfigParser(trace: .silent()).parse(gradableCfg, file: "g.merconfig")
        let lexicon = EnglishLexicon.default.merging(
            comparisonSynonyms: config.languageSynonyms.comparisonSynonyms,
            durationSynonyms: config.languageSynonyms.durationSynonyms,
            gradableAdjectiveSynonyms: config.languageSynonyms.gradableAdjectiveSynonyms
        )
        let symbols = SymbolTable.build(from: config, trace: .silent(), lexicon: lexicon)
        let parser = ExpressionParser(symbols: symbols, trace: .silent(), lexicon: lexicon)
        let expr = parser.parse("the most urgent deal")
        guard case .superlative(let sup) = expr else {
            Issue.record("expected superlative from gradable adjective metadata")
            return
        }
        #expect(sup.property == "amount")
        #expect(sup.ascending == false)
        #expect(sup.description.adjectives.contains { $0.lowercased() == "urgent" })
    }

    @Test("MER-DSC-001 when magnitude superlative lacks by and gradable metadata")
    func merDsc001WithoutGradableBacking() throws {
        let symbols = SymbolTable.build(
            from: try MerConfigParser(trace: .silent()).parse("""
            === vocabulary ===
            A deal is a kind of thing.
            A deal has an amount, which is Money.
            """, file: "g.merconfig"),
            trace: .silent()
        )
        let parser = ExpressionParser(symbols: symbols, trace: .silent())
        let expr: ExpressionAST = parser.parse("the largest deal")
        guard case .malformed(_, code: let code, _, _) = expr else {
            Issue.record("expected malformed superlative without by")
            return
        }
        #expect(code == .descriptionSuperlativeNeedsProperty)
    }

    @Test("SEM-3-01 compensation is author-owned steps inside recover handler")
    func sem301CompensationBoundary() throws {
        let revokeCfg = """
        \(cfg)
        Revoke Access
        =============
        ~ access.revoke(user: String, resource: String) : Boolean
        Grant Access
        ============
        ~ access.grant(user: String, resource: String) : Boolean
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        tools: access.grant, access.revoke
        ---
        To grant with manual compensation:
          commit.
          invoke access.grant with user = "u1", resource = "r1".
          recover from any:
            invoke access.revoke with user = "u1", resource = "r1".
          complete.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "grant.meridian")], vocabularies: [.init(name: "t", file: "t.merconfig", source: revokeCfg)]))["grant.meridian"]!.swift
        #expect(out.contains("runtime.checkpoint"))
        #expect(out.contains("recordRecoverEngaged"))
        #expect(out.contains("access.revoke"))
        #expect(!out.contains("compensate("))
    }
}
