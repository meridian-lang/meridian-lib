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

    @Test("an unrecognized section is MER5010")
    func unrecognizedSection() throws {
        let src = """
        === bogus ===
        random content that means nothing here
        === vocabulary ===
        An order is a kind of thing.
        """
        do {
            _ = try parse(src)
            Issue.record("expected MER5010 for unknown section")
        } catch let e as CompilerError {
            #expect(e.diagnostics.contains { $0.code.id == "MER5010" })
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
