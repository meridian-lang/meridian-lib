import Foundation

// MARK: - Language section

extension MerConfigParser {

    /// Parse a `=== language ===` section body into `LanguageSynonyms`.
    ///
    /// Format:
    /// ```
    /// Comparison synonyms:
    ///   exceeds = greater than
    ///   below = less than
    /// Duration synonyms:
    ///   hr = hour
    ///   mins = minute
    /// Assertion synonyms:
    ///   verify
    ///   guarantee
    /// ```
    func parseLanguageSection(_ lines: [SourceLine]) -> LanguageSynonyms {
        let content = lines.filter(\.isContent)
        var comparisonSynonyms: [(String, ComparisonOpAST)] = []
        var durationSynonyms: [String: TimeUnitAST] = [:]
        var assertionSynonyms: [String] = []
        var normativeCueSynonyms: [String] = []
        var inferenceCueSynonyms: [String] = []
        var referenceHeadingSynonyms: [String] = []
        var conditionVagueHedgeSynonyms: [String] = []
        var effectfulJudgmentCueSynonyms: [String] = []
        var articleSynonyms: [String] = []
        var parameterArticleSynonyms: [String] = []
        var prepositionSynonyms: [String] = []
        var copulaSynonyms: [String] = []
        var participleSynonyms: [String] = []
        var toolStopwordSynonyms: [String] = []
        var irregularPluralSynonyms: [String: String] = [:]
        var contractReferenceSynonyms: [String] = []
        var timestampProperty: String? = nil
        var emptySynonyms: [String] = []
        var filledSynonyms: [String] = []
        var pastWindowSynonyms: [String] = []
        var futureWindowSynonyms: [String] = []
        var timestampAliasSynonyms: [String] = []
        var aggregateSynonyms: [(String, AggregateKindAST)] = []
        var superlativeSynonyms: [String: SuperlativeDirection] = [:]
        var gradableAdjectiveSynonyms: [String: GradableAdjectiveMetadata] = [:]
        var sortBySynonyms: [String] = []
        var ascendingSynonyms: [String] = []
        var descendingSynonyms: [String] = []
        var possessiveSynonyms: [String] = []
        var anaphoraSynonyms: [String] = []
        var conditionHeaderSynonyms: [String] = []
        var actionHeaderSynonyms: [String] = []
        var wildcardSynonyms: [String] = []
        var traceOutcomeSynonyms: [String: String] = [:]
        var traceAuxiliarySynonyms: [String] = []
        var shellFenceSynonyms: [String] = []
        var fenceToolMapping: [String: String] = [:]
        var guardedFenceIntroducerSynonyms: [String] = []
        var fallbackChainIntroducerSynonyms: [String] = []
        var approvalToolSynonyms: [String] = []

        enum Mode {
            case none, comparison, duration, assertion
            case normativeCue, inferenceCue, referenceHeading
            case vagueHedge, effectfulJudgment
            case article, parameterArticle, preposition, copula, participle, toolStopword
            case irregularPlural, contractReference
            case empty, filled, pastWindow, futureWindow, timestampAlias
            case aggregate, superlative, gradableAdjective, sortBy, ascending, descending
            case possessive, anaphora
            case conditionHeader, actionHeader, wildcard, traceOutcome, traceAuxiliary, shellFence, fenceTool
            case guardedFence, fallbackChain, approvalTool
        }
        var mode: Mode = .none

        // Header → mode. Checked longest/most-specific first where prefixes
        // overlap (e.g. `timestamp alias` before the `timestamp =` entry).
        let headers: [(String, Mode)] = [
            ("comparison synonym", .comparison),
            ("duration synonym", .duration),
            ("assertion synonym", .assertion),
            ("normative-cue synonym", .normativeCue),
            ("normative cue synonym", .normativeCue),
            ("inference-cue synonym", .inferenceCue),
            ("inference cue synonym", .inferenceCue),
            ("reference-heading synonym", .referenceHeading),
            ("reference heading synonym", .referenceHeading),
            ("vague-hedge synonym", .vagueHedge),
            ("vague hedge synonym", .vagueHedge),
            ("effectful-judgment synonym", .effectfulJudgment),
            ("effectful judgment synonym", .effectfulJudgment),
            ("article synonym", .article),
            ("parameter-article synonym", .parameterArticle),
            ("parameter article synonym", .parameterArticle),
            ("preposition synonym", .preposition),
            ("copula synonym", .copula),
            ("participle synonym", .participle),
            ("tool-stopword synonym", .toolStopword),
            ("tool stopword synonym", .toolStopword),
            ("irregular-plural mapping", .irregularPlural),
            ("irregular plural mapping", .irregularPlural),
            ("contract-reference synonym", .contractReference),
            ("contract reference synonym", .contractReference),
            ("empty synonym", .empty),
            ("filled synonym", .filled),
            ("past-window synonym", .pastWindow),
            ("past window synonym", .pastWindow),
            ("future-window synonym", .futureWindow),
            ("future window synonym", .futureWindow),
            ("timestamp alias", .timestampAlias),
            ("aggregate synonym", .aggregate),
            ("superlative synonym", .superlative),
            ("gradable adjective", .gradableAdjective),
            ("gradable adjectives", .gradableAdjective),
            ("sort-by synonym", .sortBy),
            ("sort by synonym", .sortBy),
            ("ascending synonym", .ascending),
            ("descending synonym", .descending),
            ("possessive synonym", .possessive),
            ("anaphora synonym", .anaphora),
            ("condition-header synonym", .conditionHeader),
            ("condition header synonym", .conditionHeader),
            ("action-header synonym", .actionHeader),
            ("action header synonym", .actionHeader),
            ("wildcard synonym", .wildcard),
            ("trace outcome synonym", .traceOutcome),
            ("trace-auxiliary synonym", .traceAuxiliary),
            ("trace auxiliary synonym", .traceAuxiliary),
            ("shell-fence synonym", .shellFence),
            ("shell fence synonym", .shellFence),
            ("fence tool mapping", .fenceTool),
            ("guarded-fence synonym", .guardedFence),
            ("guarded fence synonym", .guardedFence),
            ("fallback-chain synonym", .fallbackChain),
            ("fallback chain synonym", .fallbackChain),
            ("approval-tool synonym", .approvalTool),
            ("approval tool synonym", .approvalTool),
        ]

        for line in content {
            let t = line.statement.trimmingCharacters(in: .whitespaces)
            let lower = t.lowercased()

            if let header = headers.first(where: { lower.hasPrefix($0.0) }) {
                mode = header.1
                continue
            }
            // `timestamp = <propertyName>` — the property a temporal iteration
            // clause resolves against (default `updatedAt`). Standalone entry.
            // (Distinct from the `Timestamp aliases:` header above.)
            if lower.hasPrefix("timestamp"), let eq = t.range(of: " = ") {
                let value = String(t[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { timestampProperty = value }
                continue
            }

            // Bare-phrase blocks (no `key = value`); captured verbatim, lower-cased.
            let marker = lower
            switch mode {
            case .assertion:     if !marker.isEmpty { assertionSynonyms.append(marker) };     continue
            case .normativeCue:  if !marker.isEmpty { normativeCueSynonyms.append(marker) };  continue
            case .inferenceCue:  if !marker.isEmpty { inferenceCueSynonyms.append(marker) };  continue
            case .referenceHeading: if !marker.isEmpty { referenceHeadingSynonyms.append(marker) }; continue
            case .vagueHedge: if !marker.isEmpty { conditionVagueHedgeSynonyms.append(marker) }; continue
            case .effectfulJudgment: if !marker.isEmpty { effectfulJudgmentCueSynonyms.append(marker) }; continue
            case .article: if !marker.isEmpty { articleSynonyms.append(marker) }; continue
            case .parameterArticle: if !marker.isEmpty { parameterArticleSynonyms.append(marker) }; continue
            case .preposition: if !marker.isEmpty { prepositionSynonyms.append(marker) }; continue
            case .copula: if !marker.isEmpty { copulaSynonyms.append(marker) }; continue
            case .participle: if !marker.isEmpty { participleSynonyms.append(marker) }; continue
            case .toolStopword: if !marker.isEmpty { toolStopwordSynonyms.append(marker) }; continue
            case .contractReference: if !marker.isEmpty { contractReferenceSynonyms.append(marker) }; continue
            case .empty:         if !marker.isEmpty { emptySynonyms.append(marker) };         continue
            case .filled:        if !marker.isEmpty { filledSynonyms.append(marker) };        continue
            case .pastWindow:    if !marker.isEmpty { pastWindowSynonyms.append(marker) };    continue
            case .futureWindow:  if !marker.isEmpty { futureWindowSynonyms.append(marker) };  continue
            case .timestampAlias:if !marker.isEmpty { timestampAliasSynonyms.append(marker) };continue
            case .sortBy:        if !marker.isEmpty { sortBySynonyms.append(marker) };        continue
            case .ascending:     if !marker.isEmpty { ascendingSynonyms.append(marker) };     continue
            case .descending:    if !marker.isEmpty { descendingSynonyms.append(marker) };    continue
            case .possessive:    if !marker.isEmpty { possessiveSynonyms.append(marker) };    continue
            case .anaphora:      if !marker.isEmpty { anaphoraSynonyms.append(marker) };      continue
            case .conditionHeader: if !marker.isEmpty { conditionHeaderSynonyms.append(marker) }; continue
            case .actionHeader:  if !marker.isEmpty { actionHeaderSynonyms.append(marker) };   continue
            case .wildcard:      if !t.isEmpty { wildcardSynonyms.append(t) };                 continue
            case .shellFence:    if !marker.isEmpty { shellFenceSynonyms.append(marker) };     continue
            case .traceAuxiliary: if !marker.isEmpty { traceAuxiliarySynonyms.append(marker) }; continue
            case .guardedFence:  if !marker.isEmpty { guardedFenceIntroducerSynonyms.append(marker) }; continue
            case .fallbackChain: if !marker.isEmpty { fallbackChainIntroducerSynonyms.append(marker) }; continue
            case .approvalTool:  if !marker.isEmpty { approvalToolSynonyms.append(marker) }; continue
            case .comparison, .duration, .aggregate, .superlative, .gradableAdjective, .traceOutcome, .fenceTool, .irregularPlural, .none:
                break  // keyed `key = value` blocks handled below
            }

            // Parse "key = value" pair
            guard let eqRange = t.range(of: " = ") else { continue }
            let key   = String(t[t.startIndex ..< eqRange.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(t[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()

            switch mode {
            case .comparison:
                if let op = resolveComparisonOp(value) {
                    comparisonSynonyms.append((key, op))
                }
            case .duration:
                if let unit = lexicon.durationUnits[value] {
                    durationSynonyms[key] = unit
                }
            case .aggregate:
                switch value {
                case "count": aggregateSynonyms.append((key, .count))
                case "list":  aggregateSynonyms.append((key, .list))
                default:      break
                }
            case .superlative:
                if let dir = SuperlativeDirection(rawValue: value) {
                    superlativeSynonyms[key] = dir
                }
            case .gradableAdjective:
                let tokens = value.split(whereSeparator: \.isWhitespace).map(String.init)
                guard tokens.count >= 2,
                      let ascending = parseGradableDirection(tokens[tokens.count - 1]) else { break }
                // `split` omits empty subsequences, so dropLast() is non-empty when count >= 2.
                let property = tokens.dropLast().joined(separator: " ")
                gradableAdjectiveSynonyms[key] = GradableAdjectiveMetadata(
                    property: property, ascending: ascending)
            case .traceOutcome:
                traceOutcomeSynonyms[key] = value
            case .fenceTool:
                // "python = interpreter.run" — value keeps its original case
                // (a tool ID), unlike the lower-cased comparison/aggregate/
                // superlative values above.
                let toolID = String(t[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !toolID.isEmpty { fenceToolMapping[key] = toolID }
            case .irregularPlural:
                irregularPluralSynonyms[key] = value
            default:
                break
            }
        }

        return LanguageSynonyms(comparisonSynonyms: comparisonSynonyms,
                                durationSynonyms: durationSynonyms,
                                assertionSynonyms: assertionSynonyms,
                                normativeCueSynonyms: normativeCueSynonyms,
                                inferenceCueSynonyms: inferenceCueSynonyms,
                                referenceHeadingSynonyms: referenceHeadingSynonyms,
                                conditionVagueHedgeSynonyms: conditionVagueHedgeSynonyms,
                                effectfulJudgmentCueSynonyms: effectfulJudgmentCueSynonyms,
                                articleSynonyms: articleSynonyms,
                                parameterArticleSynonyms: parameterArticleSynonyms,
                                prepositionSynonyms: prepositionSynonyms,
                                copulaSynonyms: copulaSynonyms,
                                participleSynonyms: participleSynonyms,
                                toolStopwordSynonyms: toolStopwordSynonyms,
                                irregularPluralSynonyms: irregularPluralSynonyms,
                                contractReferenceSynonyms: contractReferenceSynonyms,
                                timestampProperty: timestampProperty,
                                emptySynonyms: emptySynonyms,
                                filledSynonyms: filledSynonyms,
                                pastWindowSynonyms: pastWindowSynonyms,
                                futureWindowSynonyms: futureWindowSynonyms,
                                timestampAliasSynonyms: timestampAliasSynonyms,
                                aggregateSynonyms: aggregateSynonyms,
                                superlativeSynonyms: superlativeSynonyms,
                                gradableAdjectiveSynonyms: gradableAdjectiveSynonyms,
                                sortBySynonyms: sortBySynonyms,
                                ascendingSynonyms: ascendingSynonyms,
                                descendingSynonyms: descendingSynonyms,
                                possessiveSynonyms: possessiveSynonyms,
                                anaphoraSynonyms: anaphoraSynonyms,
                                conditionHeaderSynonyms: conditionHeaderSynonyms,
                                actionHeaderSynonyms: actionHeaderSynonyms,
                                wildcardSynonyms: wildcardSynonyms,
                                traceOutcomeSynonyms: traceOutcomeSynonyms,
                                traceAuxiliarySynonyms: traceAuxiliarySynonyms,
                                shellFenceSynonyms: shellFenceSynonyms,
                                fenceToolMapping: fenceToolMapping,
                                guardedFenceIntroducerSynonyms: guardedFenceIntroducerSynonyms,
                                fallbackChainIntroducerSynonyms: fallbackChainIntroducerSynonyms,
                                approvalToolSynonyms: approvalToolSynonyms)
    }

    /// Resolve a human-readable operator description to a `ComparisonOpAST`.
    func parseGradableDirection(_ token: String) -> Bool? {
        switch token.lowercased() {
        case "ascending", "asc", "oldest", "smallest", "lowest", "least": return true
        case "descending", "desc", "newest", "largest", "highest", "most": return false
        default: return nil
        }
    }

    func resolveComparisonOp(_ value: String) -> ComparisonOpAST? {
        // Try matching the value against existing comparison markers
        for (marker, op) in lexicon.comparisonMarkers {
            let lowerMarker = marker.lowercased()
            if lowerMarker == value || stripLeadingCopula(lowerMarker) == value {
                return op
            }
        }
        // Also handle plain English names (centralized spelling table).
        return lexicon.grammar.comparisonOpSpellings[value]
    }

    func stripLeadingCopula(_ marker: String) -> String {
        let trimmed = marker.trimmingCharacters(in: .whitespaces)
        for copula in lexicon.copulas.sorted(by: { $0.count > $1.count }) {
            let prefix = copula + " "
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return trimmed
    }
}
