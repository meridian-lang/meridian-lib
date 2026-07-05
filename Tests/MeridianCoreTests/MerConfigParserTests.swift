import Foundation
import Testing
@testable import MeridianCore

@Suite("MerConfigParser — language section")
struct MerConfigLanguageSectionTests {
    private func parse(_ src: String) throws -> MerConfigFile {
        try MerConfigParser(trace: ParserTrace.silent()).parse(src, file: "t.merconfig")
    }

    @Test("every === language === synonym sub-block is captured")
    func everySubBlock() throws {
        let src = """
        === language ===
        Comparison synonyms:
          exceeds = greater than
          below = less than
        Duration synonyms:
          mins = minute
        Aggregate synonyms:
          tally = count
          everything = list
        Superlative synonyms:
          freshest = newest
          eldest = oldest
        Assertion synonyms:
          verify
          guarantee
        Empty synonyms:
          is blank
        Filled synonyms:
          is present
        Past-window synonyms:
          recently
        Future-window synonyms:
          soon
        Timestamp aliases:
          modified
        Sort-by synonyms:
          ordered by
        Ascending synonyms:
          rising
        Descending synonyms:
          falling
        Possessive synonyms:
          belonging to
        Anaphora synonyms:
          the same
        Condition-header synonyms:
          provided that
        Action-header synonyms:
          then do
        Wildcard synonyms:
          ANY
        Shell-fence synonyms:
          fish
        Fence tool mapping:
          python = interpreter.run
        timestamp = lastTouchedAt
        """
        let cfg = try parse(src)
        let syn = cfg.languageSynonyms

        #expect(syn.comparisonSynonyms.contains { $0.0 == "exceeds" })
        #expect(syn.comparisonSynonyms.contains { $0.0 == "below" })
        #expect(syn.aggregateSynonyms.contains { $0.0 == "tally" })
        #expect(syn.aggregateSynonyms.contains { $0.0 == "everything" })
        #expect(syn.superlativeSynonyms["freshest"] == .newest)
        #expect(syn.superlativeSynonyms["eldest"] == .oldest)
        #expect(syn.assertionSynonyms.contains("verify"))
        #expect(syn.assertionSynonyms.contains("guarantee"))
        #expect(syn.emptySynonyms.contains("is blank"))
        #expect(syn.filledSynonyms.contains("is present"))
        #expect(syn.pastWindowSynonyms.contains("recently"))
        #expect(syn.futureWindowSynonyms.contains("soon"))
        #expect(syn.timestampAliasSynonyms.contains("modified"))
        #expect(syn.sortBySynonyms.contains("ordered by"))
        #expect(syn.ascendingSynonyms.contains("rising"))
        #expect(syn.descendingSynonyms.contains("falling"))
        #expect(syn.possessiveSynonyms.contains("belonging to"))
        #expect(syn.anaphoraSynonyms.contains("the same"))
        #expect(syn.conditionHeaderSynonyms.contains("provided that"))
        #expect(syn.actionHeaderSynonyms.contains("then do"))
        // Wildcard captures the original (non-lowercased) token.
        #expect(syn.wildcardSynonyms.contains("ANY"))
        #expect(syn.shellFenceSynonyms.contains("fish"))
        #expect(syn.fenceToolMapping["python"] == "interpreter.run")
        #expect(syn.timestampProperty == "lastTouchedAt")
    }

    @Test("space-spelled headers (no hyphen) also switch mode")
    func spaceSpelledHeaders() throws {
        let src = """
        === language ===
        Past window synonyms:
          lately
        Future window synonyms:
          shortly
        Sort by synonyms:
          sorted on
        """
        let syn = try parse(src).languageSynonyms
        #expect(syn.pastWindowSynonyms.contains("lately"))
        #expect(syn.futureWindowSynonyms.contains("shortly"))
        #expect(syn.sortBySynonyms.contains("sorted on"))
    }

    @Test("comparison value resolves via the spelling table and via copula-stripping")
    func comparisonResolution() throws {
        let src = """
        === language ===
        Comparison synonyms:
          gt = greater than
          eq = equals
        """
        let syn = try parse(src).languageSynonyms
        #expect(syn.comparisonSynonyms.contains { $0.0 == "gt" && $0.1 == .greaterThan })
        #expect(syn.comparisonSynonyms.contains { $0.0 == "eq" && $0.1 == .equal })
    }
}

@Suite("MerConfigParser — sections + instances")
struct MerConfigSectionsTests {
    private func parse(_ src: String) throws -> MerConfigFile {
        try MerConfigParser(trace: ParserTrace.silent()).parse(src, file: "t.merconfig")
    }

    @Test("an unrecognized section is unknownMerconfigSection")
    func unrecognizedSection() throws {
        let src = """
        === bogus ===
        random content that means nothing here
        === vocabulary ===
        An order is a kind of thing.
        """
        do {
            _ = try parse(src)
            Issue.record("expected unknownMerconfigSection for unknown section")
        } catch let e as CompilerError {
            #expect(e.diagnostics.contains { $0.code == .unknownMerconfigSection })
        }
    }

    @Test("inline instance properties parse via ' with '")
    func inlineInstanceProperties() throws {
        let src = """
        === vocabulary ===
        A mailer server is a kind of thing.
        === instances ===
        There is a mailer server called primary with host = "smtp.example.com", port = 587
        """
        let cfg = try parse(src)
        let inst = try #require(cfg.instances.first)
        #expect(inst.name == "primary")
        #expect(inst.properties.contains { $0.0 == "host" })
        #expect(inst.properties.contains { $0.0 == "port" })
    }

    @Test("env-var instance property is recognized")
    func envVarProperty() throws {
        let src = """
        === vocabulary ===
        A processor is a kind of thing.
        === instances ===
        There is a processor called stripe with api key = $STRIPE_KEY
        """
        let cfg = try parse(src)
        let inst = try #require(cfg.instances.first)
        if case .envVar(let name)? = inst.properties.first(where: { $0.0 == "api key" })?.1 {
            #expect(name == "STRIPE_KEY")
        } else {
            Issue.record("expected an envVar property value")
        }
    }
}

@Suite("MerConfigParser — declaration edge cases")
struct MerConfigParserDeclarationCoverageTests {
    private func parse(_ src: String, diagnostics: DiagnosticEngine? = nil) throws -> MerConfigFile {
        try MerConfigParser(trace: .silent(), diagnostics: diagnostics).parse(src, file: "t.merconfig")
    }

    @Test("block property entries without an explicit type clause default the type")
    func blockPropertyDefaultedType() throws {
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        order has properties:
          legacy_id.
        """)
        let props = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }
        guard let entry = props.first?.properties.first else {
            Issue.record("expected a block property entry"); return
        }
        #expect(entry.name == "legacy_id")
        guard case .defaulted = entry.type else {
            Issue.record("expected defaulted property type"); return
        }
    }

    @Test("comma-which-is stripping in block property names")
    func blockPropertyCommaWhichIsName() throws {
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        order has properties:
          external id, which is a String.
        """)
        let props = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }
        guard let entry = props.first?.properties.first else {
            Issue.record("expected property"); return
        }
        #expect(entry.name == "external id")
        guard case .explicit(let ty) = entry.type else {
            Issue.record("expected explicit type"); return
        }
        #expect(ty == "String")
    }

    @Test("malformed tool signatures report through a batch DiagnosticEngine")
    func malformedToolSignatureBatch() throws {
        let engine = DiagnosticEngine(trace: .silent())
        _ = try parse("""
        === tools ===

        Broken Tool
        ============
        ~ not(valid sig
        """, diagnostics: engine)
        #expect(engine.errors.contains { $0.message.contains("malformed tool signature") })
    }

    @Test("unrecognized block property lines report through a batch DiagnosticEngine")
    func unrecognizedBlockPropertyBatch() throws {
        let engine = DiagnosticEngine(trace: .silent())
        _ = try parse("""
        === vocabulary ===
        order is a kind of thing.
        order has properties:
          legacy_id.
          status which is one of ().
        """, diagnostics: engine)
        #expect(engine.errors.contains { $0.message.contains("unrecognized property line") })
    }

    @Test("relation backing via tool parses tool id")
    func relationBackingViaTool() throws {
        let cfg = try parse("""
        === vocabulary ===
        page is a kind of thing.
        entity is a kind of thing.
        mentioning relates one page to many entities.
        Mentioning is read via the link tool.
        """)
        let backings = cfg.vocabulary.compactMap { stmt -> RelationBackingDeclaration? in
            if case .relationBacking(let b) = stmt { return b }
            return nil
        }
        guard let via = backings.first(where: { $0.relation == "mentioning" }) else {
            Issue.record("expected mentioning backing"); return
        }
        guard case .tool(let toolID) = via.backing else {
            Issue.record("expected tool backing"); return
        }
        #expect(toolID == "link")
    }

    @Test("relation backing rejects is-read lines without from or via tails")
    func relationBackingUnrecognizedTail() throws {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            page is a kind of thing.
            entity is a kind of thing.
            mentioning relates one page to many entities.
            Mentioning is read under water.
            """)
        }
    }

    @Test("inline property Oxford lists strip which-is without a leading comma")
    func inlinePropertyWhichIsWithoutComma() throws {
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        An order has a name and a legacy id which is a String.
        """)
        let props = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }
        guard let entries = props.first?.properties, entries.count >= 2 else {
            Issue.record("expected two properties, got \(props.first?.properties.map(\.name) ?? [])"); return
        }
        #expect(entries.contains { $0.name == "name" })
        #expect(entries.contains { $0.name.contains("legacy") })
    }

    @Test("verb declarations parse optional conjugation tables")
    func verbDeclarationWithConjugations() throws {
        let cfg = try parse("""
        === vocabulary ===
        user is a kind of thing.
        page is a kind of thing.
        ownership relates one user to many pages.
        The verb to own (he owns, it is owned) means the ownership relation.
        """)
        let verbs = cfg.vocabulary.compactMap { stmt -> VerbDeclaration? in
            if case .verb(let v) = stmt { return v }
            return nil
        }
        guard let own = verbs.first else {
            Issue.record("expected verb declaration"); return
        }
        #expect(own.base == "own")
        #expect(own.relation == "ownership")
    }

    @Test("verb conjugations accept a bare is-prefixed participle table entry")
    func verbParticipleIsPrefixForm() throws {
        let cfg = try parse("""
        === vocabulary ===
        page is a kind of thing.
        entity is a kind of thing.
        mention relates one page to many entities.
        The verb to mention (is mentioned) means the mention relation.
        """)
        let verbs = cfg.vocabulary.compactMap { stmt -> VerbDeclaration? in
            if case .verb(let v) = stmt { return v }
            return nil
        }
        guard let mention = verbs.first(where: { $0.base == "mention" }) else {
            Issue.record("expected mention verb"); return
        }
        #expect(mention.pastParticiple == "mentioned")
    }

    @Test("instance inline properties coerce unquoted values to string literals")
    func instanceInlinePropertyStringCoercion() throws {
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        === instances ===
        There is an order called ORD1 with status = active.
        """)
        guard let inst = cfg.instances.first else {
            Issue.record("expected instance"); return
        }
        #expect(inst.name == "ord1")
        guard let (_, value) = inst.properties.first else {
            Issue.record("expected inline property"); return
        }
        guard case .literal(.string(let raw)) = value else {
            Issue.record("expected string literal property value"); return
        }
        #expect(raw == "active")
    }

    @Test("comparison synonyms resolve spellings-only operator names")
    func comparisonSynonymSpellingTable() throws {
        let cfg = try parse("""
        === language ===
        Comparison synonyms:
          sameas = equal
        """)
        guard let pair = cfg.languageSynonyms.comparisonSynonyms.first(where: { $0.0 == "sameas" }) else {
            Issue.record("expected comparison synonym"); return
        }
        #expect(pair.1 == .equal)
    }

    @Test("language keyed lines outside a synonym header are ignored")
    func languageKeyedLineWithoutHeaderIgnored() throws {
        let cfg = try parse("""
        === language ===
        orphan = greater than
        Assertion synonyms:
          verify
        """)
        #expect(cfg.languageSynonyms.assertionSynonyms.contains("verify"))
        #expect(cfg.languageSynonyms.comparisonSynonyms.isEmpty)
    }

    @Test("malformed tool signatures throw when no batch diagnostics engine is set")
    func malformedToolThrowsWithoutEngine() {
        #expect(throws: (any Error).self) {
            try MerConfigParser(trace: .silent()).parse("""
            === tools ===

            Broken Tool
            ============
            ~ not(valid sig
            """, file: "t.merconfig")
        }
    }
}

@Suite("MerConfigParser — phrase pattern coverage")
struct MerConfigPhrasePatternCoverageTests {
    @Test("phrase patterns honor called parameter introducers")
    func phrasePatternCalledIntroducer() {
        let pattern = PhrasePatternParser(trace: .silent()).parse("send an order called reference")
        let params = pattern.segments.compactMap { seg -> PhraseParameterAST? in
            if case .parameter(let p) = seg { return p }
            return nil
        }
        guard let param = params.first else {
            Issue.record("expected phrase parameter"); return
        }
        #expect(param.kind == "order")
        #expect(param.name == "reference")
    }

    @Test("phrase patterns reject slots with no kind words before called")
    func phrasePatternCalledWithoutKindRejects() {
        let pattern = PhrasePatternParser(trace: .silent()).parse("validate a called reference")
        let hasParam = pattern.segments.contains { seg in
            if case .parameter = seg { return true }
            return false
        }
        #expect(!hasParam)
    }
}

@Suite("MerConfigParser — trace")
struct MerConfigTraceTests {
    @Test("merconfig trace category emits section + summary lines")
    func traceEmitsSections() throws {
        let cap = ParserTrace.capturing(categories: [.merconfig])
        _ = try MerConfigParser(trace: cap.trace).parse("""
        === vocabulary ===
        An order is a kind of thing.
        === language ===
        Assertion synonyms:
         verify
        """, file: "trace.merconfig")
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("section === vocabulary ===") })
        #expect(lines.contains { $0.contains("parsed 1 vocab") })
    }
}
