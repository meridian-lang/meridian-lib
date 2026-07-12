import Testing
@testable import MeridianCore

@Suite("Wave 5 grammar table")
struct GrammarTableTests {

    @Test("surface grammar lists productions in review order")
    func productionOrder() {
        let names = PegexSurfaceGrammar().table.productions.map(\.name)

        #expect(names == [
            "literal-atom",
            "possessive-chain",
            "comparison",
            "boolean",
            "trace-event-pattern",
            "trace-statistical-frequency",
            "trace-temporal-ever",
            "trace-temporal-window",
            "trace-temporal-count",
            "trace-temporal-in-a-row",
            "trace-temporal-since",
            "trace-scope-marker",
            "temporal-window",
            "emptiness",
            "quantifier",
            "aggregate",
            "superlative",
            "description",
            "active-verb",
            "scalar-navigation",
            "table-lookup",
            "template-conditional",
            "template-loop",
            "template-formatter",
            "after-idiom",
            "except-when-idiom",
            "try-recover-idiom",
            "suffix-conditional",
            "compound-note",
        ])
    }

    @Test("production names are unique and each production has review metadata")
    func productionMetadata() {
        let productions = PegexSurfaceGrammar().table.productions
        let names = productions.map(\.name)

        #expect(Set(names).count == names.count)
        #expect(productions.allSatisfy { !$0.canonicalExample.isEmpty })
        #expect(productions.allSatisfy { !$0.summary.isEmpty })
    }

    @Test("anchors are threaded from custom lexicon data")
    func customLexiconAnchors() {
        let lexicon = EnglishLexicon.default.merging(
            comparisonSynonyms: [("dominates", .greaterThan)],
            durationSynonyms: [:],
            aggregateSynonyms: [("bundle of ", .list)],
            superlativeSynonyms: ["freshest": .newest],
            sortBySynonyms: ["ranked by"]
        )
        let table = PegexSurfaceGrammar(lexicon: lexicon).table

        #expect(table.production(named: "comparison")?.anchors.contains("dominates") == true)
        #expect(table.production(named: "aggregate")?.anchors.contains("bundle of") == true)
        #expect(table.production(named: "description")?.anchors.contains("ranked by") == true)
        #expect(table.production(named: "superlative")?.anchors.contains("freshest") == true)
    }

    @Test("markdown reference is generated from the registry")
    func markdownReference() {
        let markdown = PegexSurfaceGrammar().table.markdownReference()

        #expect(markdown.contains("| `comparison` | pegex | `total amount is more than 500` |"))
        #expect(markdown.contains("| `template-formatter` | hand-written | `{{ deadline as a short date }}` |"))
        #expect(markdown.contains("`is more than`"))
    }

    @Test("markdown reference handles no-anchor productions")
    func markdownNoAnchors() {
        let table = GrammarTable(productions: [
            GrammarProduction(
                name: "empty-anchor",
                category: .expression,
                implementation: .pegex,
                canonicalExample: "`x`",
                summary: "No anchor production.",
                anchors: []
            )
        ])

        #expect(table.markdownReference().contains("(none)"))
        #expect(stableUnique(["a", "a", "b"]) == ["a", "b"])
    }

    @Test("each production's implementation choice matches the per-pattern design decision")
    func implementationChoices() {
        let table = PegexSurfaceGrammar().table
        let pegex: Set<String> = [
            "literal-atom", "comparison", "boolean", "temporal-window", "emptiness",
            "quantifier", "aggregate", "superlative", "description", "table-lookup",
        ]
        let handWritten: Set<String> = [
            "possessive-chain", "trace-event-pattern", "trace-temporal-ever",
            "trace-statistical-frequency", "trace-temporal-window", "trace-temporal-count", "trace-temporal-in-a-row",
            "trace-temporal-since", "trace-scope-marker", "active-verb", "scalar-navigation",
            "template-conditional", "template-loop", "template-formatter",
            "compound-note",
        ]
        for name in pegex {
            #expect(table.production(named: name)?.implementation == .pegex, "\(name) should be pegex")
        }
        for name in handWritten {
            #expect(table.production(named: name)?.implementation == .handWritten, "\(name) should be hand-written")
        }
        // The four statement idioms are metadata-only (no backing implementation
        // yet); `implementation` records their planned form.
        for name in ["after-idiom", "except-when-idiom", "try-recover-idiom", "suffix-conditional"] {
            #expect(table.production(named: name)?.implementation == .pegex)
        }
    }
}
