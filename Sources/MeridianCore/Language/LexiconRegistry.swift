import Foundation

// The single table behind `=== language ===`: one row per `LexiconCategory`
// carrying the header spellings that select the category, the shape of its
// lines, and the rule that merges its entries into `EnglishLexicon`.
//
// Adding an author-extensible category is a `LexiconCategory` case plus a row
// here — `MerConfigParser.parseLanguageSection`, `MerConfigFile.merging` and
// `EnglishLexicon.merging(from:)` all read this table and need no edit.

/// The value shape of a category's `=== language ===` lines.
enum ValueShape: Sendable {
    /// Bare phrases, lower-cased (`Assertion synonyms:` → `verify`).
    case phraseList
    /// Bare phrases captured verbatim — table wildcard tokens keep their case.
    case phraseListVerbatim
    /// `key = <comparison spelling>`, resolved through the lexicon.
    case comparison
    /// `key = <duration unit>`, resolved through `lexicon.durationUnits`.
    case duration
    /// `key = count` / `key = list`.
    case aggregate
    /// `key = <SuperlativeDirection raw value>`.
    case superlative
    /// `key = <property> <direction>`.
    case gradable
    /// `key = value`, both lower-cased.
    case mapping
    /// `key = value`, the value keeping its original case (a tool ID).
    case mappingPreservingCase

    /// `true` for keyed shapes that behave like a dictionary: a repeated key
    /// replaces the earlier entry instead of appending a second one, matching
    /// the `[String: …]` lexicon field they merge into.
    var replacesDuplicateKeys: Bool {
        switch self {
        case .duration, .superlative, .gradable, .mapping, .mappingPreservingCase: return true
        default: return false
        }
    }
}

/// One `LexiconCategory` row: how the parser recognizes it, how it reads its
/// lines, and how its entries land in the lexicon.
struct LexiconCategorySpec: Sendable {
    let category: LexiconCategory
    /// Every accepted header spelling, matched case-insensitively as a prefix.
    let headers: [String]
    let shape: ValueShape
    /// The category's merge rule, ported from the hand-written
    /// `EnglishLexicon.merging(…)` field assignment it replaces.
    let merge: @Sendable (inout EnglishLexicon, [LexiconEntry]) -> Void
}

enum LexiconRegistry {

    /// Every category, in apply order. Rows are applied left-to-right by
    /// `EnglishLexicon.merging(from:)`; the only pair whose order is
    /// observable is the temporal-window pair — `futureWindow` is applied
    /// before `pastWindow` so the two prepends compose to
    /// `past + future + defaults`, exactly as the hand-written merge did.
    static let allSpecs: [LexiconCategorySpec] = [
        .init(category: .comparison, headers: ["comparison synonym"], shape: .comparison) { lexicon, entries in
            lexicon.comparisonMarkers = comparisonPairs(entries) + lexicon.comparisonMarkers
        },
        .init(category: .duration, headers: ["duration synonym"], shape: .duration) { lexicon, entries in
            for case .duration(let key, let unit) in entries { lexicon.durationUnits[key] = unit }
        },
        .init(category: .assertion, headers: ["assertion synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.assertionMarkers = deduplicated(lowercasedPhrases(entries) + lexicon.assertionMarkers)
                .sorted { $0.count > $1.count }
        },
        .init(category: .normativeCue, headers: ["normative-cue synonym", "normative cue synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.normativeCueWords.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .inferenceCue, headers: ["inference-cue synonym", "inference cue synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.inferenceCueWords.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .referenceHeading, headers: ["reference-heading synonym", "reference heading synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.referenceHeadingWords.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .conditionVagueHedge, headers: ["vague-hedge synonym", "vague hedge synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.conditionVagueHedges.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .effectfulJudgment, headers: ["effectful-judgment synonym", "effectful judgment synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.effectfulJudgmentCuePhrases = deduplicated(
                lowercasedPhrases(entries).sorted { $0.count > $1.count }
                + lexicon.effectfulJudgmentCuePhrases.sorted { $0.count > $1.count }
            )
        },
        .init(category: .article, headers: ["article synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.articles.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .parameterArticle, headers: ["parameter-article synonym", "parameter article synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.parameterArticles.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .preposition, headers: ["preposition synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.prepositions.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .copula, headers: ["copula synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.copulas.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .participle, headers: ["participle synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.participles.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .toolStopword, headers: ["tool-stopword synonym", "tool stopword synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.toolStopwords.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .irregularPlural, headers: ["irregular-plural mapping", "irregular plural mapping"],
              shape: .mapping) { lexicon, entries in
            for case .mapping(let singular, let plural) in entries {
                lexicon.irregularPlurals[singular.lowercased()] = plural.lowercased()
            }
        },
        .init(category: .contractReference, headers: ["contract-reference synonym", "contract reference synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.contractReferencePhrases.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .empty, headers: ["empty synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.emptyMarkers = spacedPhrases(entries) + lexicon.emptyMarkers
        },
        .init(category: .filled, headers: ["filled synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.filledMarkers = spacedPhrases(entries) + lexicon.filledMarkers
        },
        // `futureWindow` before `pastWindow` — see `allSpecs` doc comment.
        .init(category: .futureWindow, headers: ["future-window synonym", "future window synonym"],
              shape: .phraseList) { lexicon, entries in
            let markers: [(String, ComparisonOpAST)] = spacedPhrases(entries).map { ($0, .withinFuture) }
            lexicon.temporalWindowMarkers = markers + lexicon.temporalWindowMarkers
        },
        .init(category: .pastWindow, headers: ["past-window synonym", "past window synonym"],
              shape: .phraseList) { lexicon, entries in
            let markers: [(String, ComparisonOpAST)] = spacedPhrases(entries).map { ($0, .withinPast) }
            lexicon.temporalWindowMarkers = markers + lexicon.temporalWindowMarkers
        },
        .init(category: .timestampAlias, headers: ["timestamp alias"], shape: .phraseList) { lexicon, entries in
            lexicon.timestampAliases.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .aggregate, headers: ["aggregate synonym"], shape: .aggregate) { lexicon, entries in
            lexicon.aggregateIntroducers = aggregatePairs(entries) + lexicon.aggregateIntroducers
        },
        .init(category: .superlative, headers: ["superlative synonym"], shape: .superlative) { lexicon, entries in
            for case .superlative(let key, let direction) in entries {
                lexicon.superlativeGradables[key.lowercased()] = direction
            }
        },
        .init(category: .gradableAdjective, headers: ["gradable adjective", "gradable adjectives"],
              shape: .gradable) { lexicon, entries in
            for case .gradable(let key, let metadata) in entries {
                lexicon.gradableAdjectives[key.lowercased()] = metadata
            }
        },
        .init(category: .sortBy, headers: ["sort-by synonym", "sort by synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.sortByMarkers = spacedPhrases(entries) + lexicon.sortByMarkers
        },
        .init(category: .ascending, headers: ["ascending synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.ascendingMarkers = lowercasedPhrases(entries) + lexicon.ascendingMarkers
        },
        .init(category: .descending, headers: ["descending synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.descendingMarkers = lowercasedPhrases(entries) + lexicon.descendingMarkers
        },
        .init(category: .possessive, headers: ["possessive synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.possessivePronouns = entries.map { "\($0.phrase.lowercased()) " } + lexicon.possessivePronouns
        },
        .init(category: .anaphora, headers: ["anaphora synonym"], shape: .phraseList) { lexicon, entries in
            lexicon.anaphoraMarkers = lowercasedPhrases(entries) + lexicon.anaphoraMarkers
        },
        .init(category: .conditionHeader, headers: ["condition-header synonym", "condition header synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.tableConditionHeaders.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .actionHeader, headers: ["action-header synonym", "action header synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.tableActionHeaders.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .wildcard, headers: ["wildcard synonym"], shape: .phraseListVerbatim) { lexicon, entries in
            lexicon.tableWildcardTokens.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .traceOutcome, headers: ["trace outcome synonym"], shape: .mapping) { lexicon, entries in
            for case .mapping(let key, let value) in entries {
                guard let outcome = EventPatternAST.OutcomeVerb(rawValue: value.lowercased()) else { continue }
                lexicon.traceOutcomeVerbs[key.lowercased()] = outcome
            }
        },
        .init(category: .traceAuxiliary, headers: ["trace-auxiliary synonym", "trace auxiliary synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.tracePerfectAuxiliaries.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .shellFence, headers: ["shell-fence synonym", "shell fence synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.shellFenceLanguages.formUnion(lowercasedPhrases(entries))
        },
        .init(category: .fenceTool, headers: ["fence tool mapping"], shape: .mappingPreservingCase) { lexicon, entries in
            for case .mapping(let key, let toolID) in entries {
                lexicon.fenceToolMapping[key.lowercased()] = toolID
            }
        },
        .init(category: .guardedFenceIntroducer, headers: ["guarded-fence synonym", "guarded fence synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.guardedFenceIntroducers = deduplicated(
                lowercasedPhrases(entries).sorted { $0.count > $1.count }
                + lexicon.guardedFenceIntroducers.sorted { $0.count > $1.count }
            )
        },
        .init(category: .fallbackChainIntroducer, headers: ["fallback-chain synonym", "fallback chain synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.fallbackChainIntroducers = deduplicated(
                lowercasedPhrases(entries).sorted { $0.count > $1.count }
                + lexicon.fallbackChainIntroducers.sorted { $0.count > $1.count }
            )
        },
        .init(category: .approvalTool, headers: ["approval-tool synonym", "approval tool synonym"],
              shape: .phraseList) { lexicon, entries in
            lexicon.approvalToolIDSubstrings.formUnion(lowercasedPhrases(entries))
        },
    ]

    /// Flat header → spec index in table order. The parser matches headers as
    /// case-insensitive prefixes and the first hit wins; no spelling is a prefix
    /// of another *category's* spelling (pinned by `LexiconRegistryParityTests`),
    /// so this order cannot change which block a line opens.
    private static let headerIndex: [(header: String, spec: LexiconCategorySpec)] =
        allSpecs.flatMap { spec in spec.headers.map { (header: $0, spec: spec) } }

    /// The category whose header block `lowercased` opens, if any.
    static func spec(matchingHeader lowercased: String) -> LexiconCategorySpec? {
        headerIndex.first { lowercased.hasPrefix($0.header) }?.spec
    }
}

// MARK: - Merge-rule helpers

private func lowercasedPhrases(_ entries: [LexiconEntry]) -> [String] {
    entries.map { $0.phrase.lowercased() }
}

private func spacedPhrases(_ entries: [LexiconEntry]) -> [String] {
    entries.map { " \($0.phrase.lowercased()) " }
}

private func deduplicated(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
}

private func comparisonPairs(_ entries: [LexiconEntry]) -> [(String, ComparisonOpAST)] {
    entries.compactMap { entry in
        guard case .comparison(let marker, let op) = entry else { return nil }
        return (marker, op)
    }
}

private func aggregatePairs(_ entries: [LexiconEntry]) -> [(String, AggregateKindAST)] {
    entries.compactMap { entry in
        guard case .aggregate(let marker, let kind) = entry else { return nil }
        return (marker, kind)
    }
}
