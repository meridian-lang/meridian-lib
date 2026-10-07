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
        Vague-hedge synonyms:
          kinda
        Effectful-judgment synonyms:
          scrub
        Article synonyms:
          da
        Parameter-article synonyms:
          ein
        Preposition synonyms:
          durch
        Copula synonyms:
          sein
        Participle synonyms:
          gekauft
        Tool-stopword synonyms:
          ausführen
        Irregular-plural mapping:
          maus = mäuse
        Contract-reference synonyms:
          bereits erzwungen
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
        #expect(syn.conditionVagueHedgeSynonyms.contains("kinda"))
        #expect(syn.effectfulJudgmentCueSynonyms.contains("scrub"))
        #expect(syn.articleSynonyms.contains("da"))
        #expect(syn.parameterArticleSynonyms.contains("ein"))
        #expect(syn.prepositionSynonyms.contains("durch"))
        #expect(syn.copulaSynonyms.contains("sein"))
        #expect(syn.participleSynonyms.contains("gekauft"))
        #expect(syn.toolStopwordSynonyms.contains("ausführen"))
        #expect(syn.irregularPluralSynonyms["maus"] == "mäuse")
        #expect(syn.contractReferenceSynonyms.contains("bereits erzwungen"))
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

    @Test("normative-cue, inference-cue, and reference-heading synonym headers are captured")
    func cueAndReferenceHeadingSynonyms() throws {
        let src = """
        === language ===
        Normative-cue synonyms:
          must always
        Inference-cue synonyms:
          exercise judgment
        Reference-heading synonyms:
          background
        """
        let syn = try parse(src).languageSynonyms
        #expect(syn.normativeCueSynonyms.contains("must always"))
        #expect(syn.inferenceCueSynonyms.contains("exercise judgment"))
        #expect(syn.referenceHeadingSynonyms.contains("background"))
    }

    @Test("a keyed-mode line without an ` = ` pair is ignored, not crashed on")
    func keyedModeLineWithoutEqualsIsIgnored() throws {
        let src = """
        === language ===
        Comparison synonyms:
          stray line without an equals sign
          gt = greater than
        """
        let syn = try parse(src).languageSynonyms
        #expect(syn.comparisonSynonyms.count == 1)
        #expect(syn.comparisonSynonyms.contains { $0.0 == "gt" })
    }

    @Test("an aggregate synonym with an unrecognized value is dropped")
    func aggregateSynonymUnrecognizedValueDropped() throws {
        let src = """
        === language ===
        Aggregate synonyms:
          tally = count
          bogus = whatever
        """
        let syn = try parse(src).languageSynonyms
        #expect(syn.aggregateSynonyms.contains { $0.0 == "tally" })
        #expect(!syn.aggregateSynonyms.contains { $0.0 == "bogus" })
    }

    @Test("guarded-fence, fallback-chain, and approval-tool synonym headers parse")
    func fenceChainApprovalSynonyms() throws {
        let syn = try parse("""
        === language ===
        Guarded-fence synonyms:
          , proceed:
        Fallback-chain synonyms:
          try these in order:
        Approval-tool synonyms:
          signoff
        """).languageSynonyms
        #expect(syn.guardedFenceIntroducerSynonyms == [", proceed:"])
        #expect(syn.fallbackChainIntroducerSynonyms == ["try these in order:"])
        #expect(syn.approvalToolSynonyms == ["signoff"])
    }

    @Test("gradable adjectives parse property + direction; invalid rows are dropped")
    func gradableAdjectives() throws {
        let syn = try parse("""
        === language ===
        Gradable adjectives:
          fresh = updatedAt ascending
          stale = updatedAt desc
          broken = sideways
          onetoken = descending
        """).languageSynonyms
        #expect(syn.gradableAdjectiveSynonyms["fresh"] ==
                GradableAdjectiveMetadata(property: "updatedat", ascending: true))
        #expect(syn.gradableAdjectiveSynonyms["stale"] ==
                GradableAdjectiveMetadata(property: "updatedat", ascending: false))
        #expect(syn.gradableAdjectiveSynonyms["broken"] == nil)
        #expect(syn.gradableAdjectiveSynonyms["onetoken"] == nil)
    }

    @Test("parseGradableDirection and resolveComparisonOp edge branches")
    func languageHelperBranches() throws {
        let parser = MerConfigParser(trace: .silent())
        #expect(parser.parseGradableDirection("ascending") == true)
        #expect(parser.parseGradableDirection("oldest") == true)
        #expect(parser.parseGradableDirection("most") == false)
        #expect(parser.parseGradableDirection("bogus") == nil)
        #expect(parser.resolveComparisonOp("equal") == .equal)
        #expect(parser.resolveComparisonOp("equals") == .equal)
        #expect(parser.stripLeadingCopula("is less than") == "less than")
        #expect(parser.stripLeadingCopula("less than") == "less than")
    }

    @Test("trace-auxiliary synonyms are captured as bare phrases, like assertion synonyms")
    func traceAuxiliarySynonymsCaptured() throws {
        let src = """
        === language ===
        Trace-auxiliary synonym:
          shall
        """
        let syn = try parse(src).languageSynonyms
        #expect(syn.traceAuxiliarySynonyms.contains("shall"))
    }

    @Test("trace outcome synonyms are captured keyed by their mapped value")
    func traceOutcomeSynonymsCaptured() throws {
        let src = """
        === language ===
        Trace outcome synonym:
          crashed = failed
          finished = succeeded
        """
        let syn = try parse(src).languageSynonyms
        #expect(syn.traceOutcomeSynonyms["crashed"] == "failed")
        #expect(syn.traceOutcomeSynonyms["finished"] == "succeeded")
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

    @Test("an unrecognized section with no body lines reports at line 1")
    func unrecognizedSectionWithEmptyBody() throws {
        let src = """
        === bogus ===
        === vocabulary ===
        An order is a kind of thing.
        """
        do {
            _ = try parse(src)
            Issue.record("expected unknownMerconfigSection for empty-bodied unknown section")
        } catch let e as CompilerError {
            let diag = e.diagnostics.first { $0.code == .unknownMerconfigSection }
            #expect(diag?.primaryRange.startLine == 1)
        }
    }

    @Test("a blank-named `===   ===` line does not open a new section")
    func blankNamedSectionHeaderIsIgnored() throws {
        let src = """
        ===   ===
        === vocabulary ===
        An order is a kind of thing.
        """
        let cfg = try parse(src)
        #expect(cfg.vocabulary.count == 1)
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

    @Test("a key declaration accepts the `an` article, not just `a`")
    func keyDeclarationAcceptsAnArticle() throws {
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        an order is keyed by id.
        """)
        let keys = cfg.vocabulary.compactMap { stmt -> KeyDeclaration? in
            if case .key(let k) = stmt { return k }
            return nil
        }
        guard let key = keys.first else {
            Issue.record("expected a key declaration"); return
        }
        #expect(key.kind == "order")
        #expect(key.property == "id")
    }

    @Test("a key declaration with a valid kind but an empty property (after trimming) is rejected")
    func keyDeclarationEmptyPropertyRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            widget is a kind of thing.
            a widget is keyed by .
            """)
        }
    }

    @Test("the alternate ` has:` block header suffix (without `properties`) is also recognized")
    func propertyBlockHeaderHasSuffixAlternate() throws {
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        order has:
          legacy_id.
        """)
        let props = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }
        #expect(props.first?.properties.map(\.name) == ["legacy_id"])
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

    @Test("unrecognized block property lines throw when no diagnostics engine is supplied")
    func unrecognizedBlockPropertyThrowsWithoutEngine() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            order is a kind of thing.
            order has properties:
              status which is one of ().
            """)
        }
    }

    @Test("malformed verb declarations throw when no diagnostics engine is supplied")
    func malformedVerbThrowsWithoutEngine() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            user is a kind of thing.
            page is a kind of thing.
            ownership relates one user to many pages.
            The verb to own says the ownership relation.
            """)
        }
    }

    @Test("a phrase header that never reaches a trailing colon falls through as unrecognized vocabulary")
    func phraseHeaderWithoutColonFallsThrough() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            To send an order without a terminator
            """)
        }
    }

    @Test("a has-properties block whose body is entirely blank falls through the block-header match")
    func blockPropertyAllBlankBodyFallsThrough() {
        // The block header itself is re-evaluated by later checks once no
        // entries were produced; it doesn't match anything else either, so
        // this still surfaces as an unrecognized vocabulary declaration.
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            order is a kind of thing.
            order has properties:
              .
            """)
        }
    }

    @Test("the alternate `kind {name} is {parent}.` syntax rejects an empty name")
    func kindPrefixSyntaxRejectsEmptyName() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            kind  is a widget.
            """)
        }
    }

    @Test("the alternate `kind {name} is {parent}.` syntax degrades gracefully (no crash) when the prefix and `is`-marker overlap")
    func kindPrefixSyntaxOverlapDoesNotCrash() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            kind is a widget.
            """)
        }
    }

    @Test("a single-letter-article kind name collides with the `kind of` marker's own leading space")
    func kindOfMarkerArticleOverlapRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            A is a kind of thing.
            """)
        }
    }

    @Test("`A has a name.` collides with the has-marker's own leading space after article-stripping")
    func hasMarkerArticleOverlapRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            order is a kind of thing.
            A has a name.
            """)
        }
    }

    @Test("a has-declaration whose property text is all commas produces zero properties")
    func hasDeclarationAllCommasProducesNoProperties() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            order is a kind of thing.
            order has ,,,.
            """)
        }
    }

    @Test("a which-is-one-of clause with no parentheses defaults to an empty case list")
    func whichIsOneOfWithoutParensDefaultsEmptyCases() throws {
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        order has a status which is one of active, suspended.
        """)
        let props = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }
        guard case .enumeration(let cases, _)? = props.first?.properties.first?.type else {
            Issue.record("expected enumeration property type"); return
        }
        #expect(cases.isEmpty)
    }

    @Test("a called-property fragment whose type text is only punctuation is rejected")
    func calledPropertyPunctuationOnlyTypeRejected() throws {
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        order has , called foo.
        """)
        // Falls back to the comma/and-split path instead of the called-property
        // shape, since the type text (just a comma) strips to empty.
        let props = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }
        #expect(props.first?.properties.isEmpty == false)
    }

    @Test("`A can be Foo or Bar.` collides with the can-be marker's own leading space")
    func canBeMarkerArticleOverlapRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            widget is a kind of thing.
            A can be active or inactive.
            """)
        }
    }

    @Test("a can-be declaration with fewer than two cases is rejected")
    func canBeDeclarationSingleCaseRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            widget is a kind of thing.
            A widget can be active.
            """)
        }
    }

    @Test("`A is usually Foo.` collides with the usually-marker's own leading space")
    func usuallyMarkerArticleOverlapRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            widget is a kind of thing.
            A is usually active.
            """)
        }
    }

    @Test("a usually-declaration with an empty default case is rejected")
    func usuallyDeclarationEmptyDefaultRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            widget is a kind of thing.
            A widget is usually ,.
            """)
        }
    }

    @Test("a relates-declaration with no ` to ` cardinality tail is rejected")
    func relatesDeclarationWithoutToTailRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            user is a kind of thing.
            ownership relates one user.
            """)
        }
    }

    @Test("relation backing `from` clause without a possessive apostrophe is rejected")
    func relationBackingFromWithoutPossessiveRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            page is a kind of thing.
            entity is a kind of thing.
            mentioning relates one page to many entities.
            Mentioning is read from the page.
            """)
        }
    }

    @Test("relation backing `from` clause with an empty possessive kind is rejected")
    func relationBackingFromEmptyKindRejected() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            page is a kind of thing.
            entity is a kind of thing.
            mentioning relates one page to many entities.
            Mentioning is read from 's id.
            """)
        }
    }

    @Test("a verb declaration without a ` means ` marker is malformed")
    func verbDeclarationWithoutMeansMarkerMalformed() throws {
        let engine = DiagnosticEngine(trace: .silent())
        _ = try parse("""
        === vocabulary ===
        user is a kind of thing.
        page is a kind of thing.
        ownership relates one user to many pages.
        The verb to own says the ownership relation.
        """, diagnostics: engine)
        #expect(engine.errors.contains { $0.message.contains("malformed verb declaration") })
    }

    @Test("a verb declaration whose meaning strips down to an empty relation is malformed")
    func verbDeclarationEmptyRelationMalformed() throws {
        let engine = DiagnosticEngine(trace: .silent())
        _ = try parse("""
        === vocabulary ===
        user is a kind of thing.
        The verb to own means .
        """, diagnostics: engine)
        #expect(engine.errors.contains { $0.message.contains("malformed verb declaration") })
    }

    @Test("a verb declaration without a conjugation table falls back to regular past-participle morphology")
    func verbDeclarationWithoutConjugationTableFallsBack() throws {
        let cfg = try parse("""
        === vocabulary ===
        user is a kind of thing.
        page is a kind of thing.
        ownership relates one user to many pages.
        The verb to own means the ownership relation.
        """)
        let verbs = cfg.vocabulary.compactMap { stmt -> VerbDeclaration? in
            if case .verb(let v) = stmt { return v }
            return nil
        }
        #expect(verbs.first?.pastParticiple == "owned")
    }

    @Test("a constant line with a leading article but no ` is ` marker is skipped")
    func constantWithoutIsMarkerSkipped() throws {
        let cfg = try parse("""
        === constants ===
        The tax rate equals 5.
        """)
        #expect(cfg.constants.isEmpty)
    }

    @Test("a constant whose value is not a recognized literal is skipped")
    func constantUnrecognizedLiteralSkipped() throws {
        let cfg = try parse("""
        === constants ===
        The tax rate is unspecified.
        """)
        #expect(cfg.constants.isEmpty)
    }

    @Test("single-quoted string literals are recognized alongside double-quoted ones")
    func singleQuotedStringLiteral() throws {
        let cfg = try parse("""
        === constants ===
        The greeting is 'hello'.
        """)
        guard case .string(let s)? = cfg.constants.first?.value else {
            Issue.record("expected a string literal constant"); return
        }
        #expect(s == "hello")
    }

    @Test("an instance line with `there is` but no `called` marker is skipped")
    func instanceWithoutCalledMarkerSkipped() throws {
        let cfg = try parse("""
        === vocabulary ===
        widget is a kind of thing.
        === instances ===
        There is a widget.
        """)
        #expect(cfg.instances.isEmpty)
    }

    @Test("inline instance properties with no `=` of any form are dropped, not crashed on")
    func inlineInstancePropertyWithoutEqualsDropped() throws {
        let cfg = try parse("""
        === vocabulary ===
        widget is a kind of thing.
        === instances ===
        There is a widget called foo with justsometext
        """)
        let inst = try #require(cfg.instances.first)
        #expect(inst.properties.isEmpty)
    }

    @Test("block-form instance properties tolerate a bare `key=value` with no surrounding spaces")
    func blockInstancePropertyBareEquals() throws {
        let cfg = try parse("""
        === vocabulary ===
        widget is a kind of thing.
        === instances ===
        There is a widget called foo:
          port=587
        """)
        let inst = try #require(cfg.instances.first)
        #expect(inst.properties.contains { $0.0 == "port" })
    }

    @Test("a bare `has properties:` line with no kind name is not a block header")
    func blockHeaderWithoutKindNameIsNotAHeader() {
        #expect(throws: (any Error).self) {
            try parse("""
            === vocabulary ===
            has properties:
              legacy_id.
            """)
        }
    }

    @Test("a block property line that strips down to an empty name is dropped, not appended")
    func blockPropertyEntryEmptyNameDropped() throws {
        let engine = DiagnosticEngine(trace: .silent())
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        order has properties:
          ,
          legacy_id.
        """, diagnostics: engine)
        let props = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }
        #expect(props.first?.properties.map(\.name) == ["legacy_id"])
        #expect(engine.errors.contains { $0.message.contains("unrecognized property line") })
    }

    @Test("a block property which-is-one-of clause with no parentheses is dropped, sibling entries still parse")
    func blockPropertyWhichIsOneOfWithoutParensDropped() throws {
        let engine = DiagnosticEngine(trace: .silent())
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        order has properties:
          legacy_id.
          status which is one of active, closed
        """, diagnostics: engine)
        let props = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }
        #expect(props.first?.properties.map(\.name) == ["legacy_id"])
        #expect(engine.errors.contains { $0.message.contains("unrecognized property line") })
    }

    @Test("a which-is-one-of clause's name prefix that itself contains a comma-which-is fragment is trimmed at the first")
    func blockPropertyWhichIsOneOfNameContainsCommaWhichIs() throws {
        let cfg = try parse("""
        === vocabulary ===
        order is a kind of thing.
        order has properties:
          status, which is critical, which is one of (open, closed).
        """)
        let props = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }
        #expect(props.first?.properties.map(\.name) == ["status"])
    }

    @Test("phrase pattern rejection logs its 'no kind words' trace message")
    func phrasePatternRejectionTraceMessage() {
        let cap = ParserTrace.capturing(categories: [.phraseParse])
        _ = PhrasePatternParser(trace: cap.trace).parse("validate a called reference")
        #expect(cap.lines().contains { $0.contains("no kind words") })
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
    private func parse(_ src: String, file: String = "trace.merconfig") throws -> MerConfigFile {
        try MerConfigParser(trace: ParserTrace.silent()).parse(src, file: file)
    }

    private func bootstrap(
        _ vocabularies: [Compiler.VocabularyInput]
    ) throws -> Compiler.KnowledgeContext {
        try Compiler(options: .init(trace: .silent())).knowledge(
            forSource: "",
            sourceFile: "empty.meri",
            vocabularies: vocabularies
        )
    }

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

    @Test("trace section and tool capture policies parse")
    func traceSectionParses() throws {
        let cfg = try parse("""
        === trace ===
        store: file
        retention: 30 days
        payload limit: 8192
        usually at least: 90%
        rarely at most: 10%
        sample floor: 20
        default monitor cadence: 1 days
        profile: production
        store failure policy: auto
        deployment zone: UTC

        === tools ===
        Validate Order
        ==============
        ~ validateOrder(order: Order) : Order
          capture: redacted (token, secret)
        """)
        #expect(cfg.traceConfiguration.store?.value == .file)
        #expect(cfg.traceConfiguration.payloadLimit?.value == 8192)
        #expect(cfg.traceConfiguration.profile?.value == .production)
        #expect(cfg.tools.first?.capturePolicy == .redacted(["token", "secret"]))
    }

    @Test("RISK-W8-07 production trace capture requires every tool to declare capture")
    func productionProfileMissingCaptureFails() {
        let config = Compiler.VocabularyInput(
            name: "trace",
            file: "trace.merconfig",
            source: """
            === trace ===
            profile: production

            === tools ===
            Validate Order
            ==============
            ~ validateOrder(order: Order) : Order

            Audit Order
            ===========
            ~ auditOrder(order: Order) : Order
              capture: hash-only
            """
        )

        do {
            _ = try bootstrap([config])
            Issue.record("expected MER-TMP-020 for the uncaptured production tool")
        } catch let error as CompilerError {
            let diagnostic = error.diagnostics.first { $0.code == .traceMissingProductionCapturePolicy }
            #expect(diagnostic?.message.contains("Validate Order") == true)
            #expect(diagnostic?.help?.contains("capture: full") == true)
            #expect(diagnostic?.notes.contains { $0.message.contains("trace profile `production` declared here") } == true)
        } catch {
            Issue.record("expected CompilerError, got \(error)")
        }
    }

    @Test("production trace capture succeeds when every tool is explicit")
    func productionProfileAllToolsCapturedSucceeds() throws {
        let config = Compiler.VocabularyInput(
            name: "trace",
            file: "trace.merconfig",
            source: """
            === trace ===
            profile: production

            === tools ===
            Validate Order
            ==============
            ~ validateOrder(order: Order) : Order
              capture: full

            Audit Order
            ===========
            ~ auditOrder(order: Order) : Order
              capture: redacted (token, secret)
            """
        )

        let knowledge = try bootstrap([config])
        #expect(knowledge.symbols.traceConfiguration.profile?.value == .production)
        #expect(knowledge.symbols.tools["validateOrder"]?.capturePolicy == .full)
        #expect(knowledge.symbols.tools["auditOrder"]?.capturePolicy == .redacted(["token", "secret"]))
    }

    @Test("development trace capture still allows omitted tool capture")
    func developmentProfileWithoutCaptureSucceeds() throws {
        let config = Compiler.VocabularyInput(
            name: "trace",
            file: "trace.merconfig",
            source: """
            === trace ===
            profile: development

            === tools ===
            Validate Order
            ==============
            ~ validateOrder(order: Order) : Order
            """
        )

        let knowledge = try bootstrap([config])
        #expect(knowledge.symbols.traceConfiguration.profile?.value == .development)
        #expect(knowledge.symbols.tools["validateOrder"]?.capturePolicy == nil)
    }

    @Test("merged production trace capture checks tools declared in another merconfig")
    func productionProfileMergedAcrossConfigsFailsWithoutCapture() {
        let tools = Compiler.VocabularyInput(
            name: "tools",
            file: "tools.merconfig",
            source: """
            === tools ===
            Validate Order
            ==============
            ~ validateOrder(order: Order) : Order
            """
        )
        let trace = Compiler.VocabularyInput(
            name: "trace",
            file: "trace.merconfig",
            source: """
            === trace ===
            profile: production
            """
        )

        do {
            _ = try bootstrap([tools, trace])
            Issue.record("expected merged production profile to reject missing tool capture")
        } catch let error as CompilerError {
            let diagnostic = error.diagnostics.first { $0.code == .traceMissingProductionCapturePolicy }
            #expect(diagnostic?.primaryRange.file == "tools.merconfig")
            #expect(diagnostic?.message.contains("Validate Order") == true)
            #expect(diagnostic?.notes.contains { $0.range?.file == "trace.merconfig" } == true)
        } catch {
            Issue.record("expected CompilerError, got \(error)")
        }
    }

    @Test("SEM_2_12 trace durations stay physical and deployment zones stay explicit")
    func sem212PhysicalDurationsAndZone() throws {
        let cfg = try parse("""
        === trace ===
        retention: 7 days
        deployment zone: Asia/Kolkata
        """)
        #expect(cfg.traceConfiguration.retention?.value == .seconds(604_800))
        #expect(cfg.traceConfiguration.deploymentZone?.value == "Asia/Kolkata")
    }

    @Test("conflicting trace settings across merconfigs throw a sourced merge error")
    func traceSectionMergeConflict() throws {
        let lhs = try parse("=== trace ===\nstore: memory\n", file: "a.merconfig")
        let rhs = try parse("=== trace ===\nstore: file\n", file: "b.merconfig")
        #expect(throws: MerConfigMergeError.self) {
            _ = try lhs.merging(rhs)
        }
    }

    @Test("equivalent tools merge capture policy from overlay")
    func toolCapturePolicyMerges() throws {
        let base = MerConfigFile(tools: [
            ToolDeclaration(displayName: "T", methodName: "t", parameters: [],
                            returnType: "Void", sourceFile: "a.merconfig")
        ])
        let overlay = MerConfigFile(tools: [
            ToolDeclaration(displayName: "T", methodName: "t", parameters: [],
                            returnType: "Void", sourceFile: "b.merconfig",
                            capturePolicy: .hashOnly)
        ])
        let merged = try base.merging(overlay)
        #expect(merged.tools.first?.capturePolicy == .hashOnly)
        #expect(merged.tools.count == 1)

        let appended = try base.merging(MerConfigFile(tools: [
            ToolDeclaration(displayName: "U", methodName: "u", parameters: [],
                            returnType: "Void", sourceFile: "c.merconfig")
        ]))
        #expect(appended.tools.map(\.methodName).sorted() == ["t", "u"])
    }

    @Test("conflicting tool declaration surfaces MerConfigMergeError description")
    func conflictingToolDeclaration() throws {
        let lhs = MerConfigFile(tools: [
            ToolDeclaration(displayName: "T", methodName: "t", parameters: [],
                            returnType: "Void", sourceFile: "a.merconfig")
        ])
        let rhs = MerConfigFile(tools: [
            ToolDeclaration(displayName: "T", methodName: "t", parameters: [],
                            returnType: "String", sourceFile: "b.merconfig")
        ])
        do {
            _ = try lhs.merging(rhs)
            Issue.record("expected MerConfigMergeError")
        } catch let error as MerConfigMergeError {
            #expect(error.description.contains("conflicting tool declaration"))
            #expect(error.description.contains("a.merconfig"))
            #expect(error.description.contains("b.merconfig"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("every malformed trace setting value reports its own diagnostic and is skipped, not crashed on")
    func everyMalformedTraceSettingValueIsReportedAndSkipped() throws {
        let engine = DiagnosticEngine(trace: .silent())
        let cfg = try MerConfigParser(trace: .silent(), diagnostics: engine).parse("""
        === trace ===
        this line has no colon
        store: carrier-pigeon
        store path:
        retention: banana days
        payload limit: not-a-number
        sample floor: not-a-number
        default monitor cadence: banana days
        profile: staging
        store failure policy: shrug
        state history: maybe
        some unknown key: whatever
        """, file: "trace.merconfig")

        // Every malformed setting is skipped (left nil), not defaulted or crashed on.
        #expect(cfg.traceConfiguration.store == nil)
        #expect(cfg.traceConfiguration.storePath == nil)
        #expect(cfg.traceConfiguration.retention == nil)
        #expect(cfg.traceConfiguration.payloadLimit == nil)
        #expect(cfg.traceConfiguration.sampleFloor == nil)
        #expect(cfg.traceConfiguration.defaultMonitorCadence == nil)
        #expect(cfg.traceConfiguration.profile == nil)
        #expect(cfg.traceConfiguration.storeFailurePolicy == nil)
        #expect(cfg.traceConfiguration.stateHistoryRetention == nil)

        #expect(engine.errors.contains { $0.message.contains("malformed trace setting") })
        #expect(engine.errors.contains { $0.message.contains("unknown trace store") })
        #expect(engine.errors.contains { $0.message.contains("store path cannot be empty") })
        #expect(engine.errors.contains { $0.message.contains("invalid trace retention") })
        #expect(engine.errors.contains { $0.message.contains("invalid payload limit") })
        #expect(engine.errors.contains { $0.message.contains("invalid sample floor") })
        #expect(engine.errors.contains { $0.message.contains("invalid monitor cadence") })
        #expect(engine.errors.contains { $0.message.contains("unknown trace profile") })
        #expect(engine.errors.contains { $0.message.contains("unknown trace store failure policy") })
        #expect(engine.errors.contains { $0.message.contains("invalid state history setting") })
        #expect(engine.errors.contains { $0.message.contains("unknown trace setting") })
    }

    @Test("store path and state history parse when well-formed")
    func storePathAndStateHistory() throws {
        let cfg = try MerConfigParser(trace: .silent()).parse("""
        === trace ===
        store: file
        store path: /tmp/traces.jsonl
        state history: enabled
        """, file: "trace.merconfig")
        #expect(cfg.traceConfiguration.store?.value == .file)
        #expect(cfg.traceConfiguration.storePath?.value == "/tmp/traces.jsonl")
        #expect(cfg.traceConfiguration.stateHistoryRetention?.value == true)
    }

    @Test("a malformed trace setting throws when no batch diagnostics engine is supplied")
    func malformedTraceSettingThrowsWithoutEngine() {
        #expect(throws: (any Error).self) {
            try MerConfigParser(trace: .silent()).parse("""
            === trace ===
            store: carrier-pigeon
            """, file: "trace.merconfig")
        }
    }

    @Test("an invalid usually/rarely percentage reports through the batch engine and defaults to zero")
    func invalidTracePercentageDefaultsToZero() throws {
        let engine = DiagnosticEngine(trace: .silent())
        let cfg = try MerConfigParser(trace: .silent(), diagnostics: engine).parse("""
        === trace ===
        usually at least: not-a-percent
        """, file: "trace.merconfig")
        #expect(cfg.traceConfiguration.usuallyThreshold?.value == 0)
        #expect(engine.errors.contains { $0.message.contains("invalid percentage") })
    }

    @Test("a fractional percentage without a % sign is used as-is, not divided by 100")
    func fractionalPercentageWithoutSignUsedAsIs() throws {
        let cfg = try parse("""
        === trace ===
        rarely at most: 0.1
        """)
        #expect(cfg.traceConfiguration.rarelyThreshold?.value == 0.1)
    }

    @Test("an unknown tool capture policy reports through the batch engine and defaults to full")
    func unknownToolCapturePolicyDefaultsToFull() throws {
        let engine = DiagnosticEngine(trace: .silent())
        let cfg = try MerConfigParser(trace: .silent(), diagnostics: engine).parse("""
        === tools ===
        Validate Order
        ==============
        ~ validateOrder(order: Order) : Order
          capture: sideways
        """, file: "trace.merconfig")
        #expect(cfg.tools.first?.capturePolicy == .full)
        #expect(engine.errors.contains { $0.message.contains("unknown capture policy") })
    }

    @Test("store failure policy accepts fail-open and fail-closed, not just auto")
    func storeFailurePolicyAcceptsFailOpenAndFailClosed() throws {
        let failOpen = try parse("""
        === trace ===
        store failure policy: fail-open
        """)
        #expect(failOpen.traceConfiguration.storeFailurePolicy?.value == .failOpen)

        let failClosed = try parse("""
        === trace ===
        store failure policy: fail-closed
        """)
        #expect(failClosed.traceConfiguration.storeFailurePolicy?.value == .failClosed)
    }

    @Test("a redacted capture policy without a parenthesized field list reports through the batch engine")
    func redactedCapturePolicyWithoutFieldsReported() throws {
        let engine = DiagnosticEngine(trace: .silent())
        let cfg = try MerConfigParser(trace: .silent(), diagnostics: engine).parse("""
        === tools ===
        Validate Order
        ==============
        ~ validateOrder(order: Order) : Order
          capture: redacted
        """, file: "trace.merconfig")
        #expect(cfg.tools.first?.capturePolicy == .redacted([]))
        #expect(engine.errors.contains { $0.message.contains("must list fields") })
    }
}

@Suite("MerConfigParser — tools section")
struct MerConfigToolsSectionTests {
    private func parse(_ src: String, diagnostics: DiagnosticEngine? = nil) throws -> MerConfigFile {
        try MerConfigParser(trace: .silent(), diagnostics: diagnostics).parse(src, file: "t.merconfig")
    }

    @Test("tool with description lines and omitted capture parses")
    func descriptionAndOmittedCapture() throws {
        let cfg = try parse("""
        === tools ===
        Charge Payment
        ==============
        -- Charges the customer via the processor.
        -- Returns a payment result.
        ~ chargePayment(order: Order, amount: Money) : PaymentResult
          capture: omitted
        """)
        #expect(cfg.tools.count == 1)
        #expect(cfg.tools[0].methodName == "chargePayment")
        #expect(cfg.tools[0].parameters.count == 2)
        #expect(cfg.tools[0].returnType == "PaymentResult")
        #expect(cfg.tools[0].capturePolicy == .omitted)
    }

    @Test("missing signature line reports a diagnostic")
    func missingSignatureReports() throws {
        let engine = DiagnosticEngine(trace: .silent())
        _ = try parse("""
        === tools ===
        Orphan Tool
        ===========
        -- description only, no tilde signature
        """, diagnostics: engine)
        #expect(engine.errors.contains { $0.message.contains("missing a `~ methodName") })
    }

    @Test("signature without return-type colon defaults to Any")
    func signatureDefaultsReturnTypeToAny() throws {
        let cfg = try parse("""
        === tools ===
        Ping
        ====
        ~ ping()
        """)
        #expect(cfg.tools.first?.returnType == "Any")
        #expect(cfg.tools.first?.methodName == "ping")
        #expect(cfg.tools.first?.parameters.isEmpty == true)
    }

    @Test("signature without parentheses is malformed")
    func signatureWithoutParensMalformed() throws {
        let engine = DiagnosticEngine(trace: .silent())
        _ = try parse("""
        === tools ===
        Broken
        ======
        ~ noParensHere : String
        """, diagnostics: engine)
        #expect(engine.errors.contains { $0.message.contains("malformed tool signature") })
    }
}

@Suite("MerConfigParser — vocabulary helper early exits")
struct MerConfigVocabularyHelperCoverageTests {
    @Test("property-block / relation-backing / verb / inverse guards return nil")
    func helperEarlyExits() {
        let p = MerConfigParser(trace: .silent())
        #expect(p.parsePropertyBlockHeader(" has:", line: 1) == nil)
        #expect(p.parsePropertyBlockHeader(" has properties:", line: 1) == nil)

        #expect(p.parseRelationBacking("Mentions something unrelated.", line: 1) == nil)
        #expect(p.parseRelationBacking(" is read from the page's title.", line: 1) == nil)

        #expect(p.parseVerb("A page is a kind of thing.", line: 1) == nil)
        #expect(p.parseInverse("A page is a kind of thing.", line: 1) == nil)
    }
}
