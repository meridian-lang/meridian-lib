import Foundation
import Testing
@testable import MeridianCore

// Category-complete parity between a `=== language ===` section and the merged
// `EnglishLexicon`, plus the registry invariants that make that parity hold for
// every category. The point is to catch a registry row wired to the wrong
// lexicon field (or a header block wired to the wrong category) — a spot check
// on one or two categories cannot.
//
// Three layers:
//   1. `registryIntegrity` — one row per category, one header owner each, and
//      every header's category re-derived from the header text itself.
//   2. `categoryIsolation` — for every category and every accepted header
//      spelling, a synthesized one-line fixture must land in that category's
//      field and leave every other category untouched.
//   3. `fixtureParity` — every real `=== language ===` fixture on disk and
//      inline in the test sources must land in exactly the categories it
//      declares, and nowhere else.

@Suite("Lexicon registry parity")
struct LexiconRegistryParityTests {

    // MARK: - 1. Registry integrity

    @Test("every category has exactly one spec row and its own header spellings")
    func registryIntegrity() {
        let specs = LexiconRegistry.allSpecs
        #expect(specs.count == LexiconCategory.allCases.count)
        #expect(Set(specs.map(\.category)) == Set(LexiconCategory.allCases))

        let headers = specs.flatMap(\.headers)
        #expect(Set(headers).count == headers.count, Comment(rawValue: "a header spelling is claimed twice"))
        #expect(headers.allSatisfy { $0 == $0.lowercased() && !$0.isEmpty },
                Comment(rawValue: "headers are matched against a lower-cased line"))

        for spec in specs {
            #expect(!spec.headers.isEmpty, Comment(rawValue: "\(spec.category) has no header spelling"))
            for header in spec.headers {
                // Re-derived from the header text, not read from the row: a row
                // whose header belongs to another category fails here.
                #expect(expectedCategory(forHeader: header) == spec.category, Comment(rawValue: header))
                // The parser resolves a header through the flat table.
                #expect(LexiconRegistry.spec(matchingHeader: header)?.category == spec.category,
                        Comment(rawValue: header))
                #expect(LexiconRegistry.spec(matchingHeader: header + ":")?.category == spec.category,
                        Comment(rawValue: header))
                // No spelling is a prefix of another *category's* spelling, so
                // the flat table's order cannot change which block a line opens
                // (the only overlap, `gradable adjective`/`adjectives`, is one
                // category's).
                for other in specs where other.category != spec.category {
                    for otherHeader in other.headers {
                        #expect(!otherHeader.hasPrefix(header),
                                Comment(rawValue: "\(header) shadows \(other.category)'s \(otherHeader)"))
                    }
                }
            }
        }
    }

    // MARK: - 2. Per-category isolation

    @Test("each category's header block lands in its own field and nowhere else")
    func categoryIsolation() throws {
        for spec in LexiconRegistry.allSpecs {
            for header in spec.headers {
                let sample = sample(for: spec)
                let source = "=== language ===\n\(header):\n\(sample.line)\n"
                let synonyms = try MerConfigParser(trace: .silent())
                    .parse(source, file: "parity.merconfig").languageSynonyms
                let context = Comment(rawValue: "\(spec.category) / \(header)")

                #expect(synonyms.entries[spec.category] == [sample.declared], context)
                #expect(synonyms.entries.count == 1, context)

                let merged = EnglishLexicon.default.merging(from: synonyms)
                #expect(fieldEntries(spec.category, in: merged).contains(sample.field), context)
                for other in LexiconCategory.allCases where other != spec.category {
                    #expect(fieldEntries(other, in: merged) == fieldEntries(other, in: .default),
                            Comment(rawValue: "\(context.rawValue) leaked into \(other)"))
                }
            }
        }
    }

    @Test("past-window markers stay ahead of future-window markers, defaults last")
    func temporalWindowMarkerOrder() {
        let merged = EnglishLexicon.default.merging(entries: [
            .pastWindow: [.phrase("over the past")],
            .futureWindow: [.phrase("over the coming")],
        ])
        #expect(merged.temporalWindowMarkers.map(\.0)
            == [" over the past ", " over the coming ", " within the last ", " in the next "])
    }

    @Test("author entries lead the defaults in every prepend-ordered category")
    func prependOrder() {
        let merged = EnglishLexicon.default.merging(entries: [
            .comparison: [.comparison("zqxcmp", .greaterThan)],
            .aggregate: [.aggregate("zqxagg", .count)],
            .ascending: [.phrase("zqxasc")],
            .descending: [.phrase("zqxdesc")],
            .anaphora: [.phrase("zqxana")],
            .empty: [.phrase("zqxempty")],
            .filled: [.phrase("zqxfilled")],
            .sortBy: [.phrase("zqxsorted by")],
            .possessive: [.phrase("zqxposs")],
            // Long enough to sort ahead of every default assertion marker.
            .assertion: [.phrase("zqxassertionmarker")],
        ])
        #expect(merged.comparisonMarkers.first?.0 == "zqxcmp")
        #expect(merged.comparisonMarkers.first?.1 == .greaterThan)
        #expect(merged.aggregateIntroducers.first?.0 == "zqxagg")
        #expect(merged.aggregateIntroducers.first?.1 == .count)
        #expect(merged.ascendingMarkers.first == "zqxasc")
        #expect(merged.descendingMarkers.first == "zqxdesc")
        #expect(merged.anaphoraMarkers.first == "zqxana")
        #expect(merged.emptyMarkers.first == " zqxempty ")
        #expect(merged.filledMarkers.first == " zqxfilled ")
        #expect(merged.sortByMarkers.first == " zqxsorted by ")
        #expect(merged.possessivePronouns.first == "zqxposs ")
        #expect(merged.assertionMarkers.first == "zqxassertionmarker")
        // Categories the entries table says nothing about keep the defaults.
        #expect(merged.temporalWindowMarkers.map(\.0) == [" within the last ", " in the next "])
        #expect(merged.superlativeGradables["oldest"] == .oldest)
    }

    @Test("multi-entry sorted categories de-duplicate and order longest-first")
    func sortedPrependRules() {
        let merged = EnglishLexicon.default.merging(entries: [
            .effectfulJudgment: [.phrase("scrub"), .phrase("scrub the")],
            .guardedFenceIntroducer: [.phrase(", go:"), .phrase(", go ahead:")],
            .fallbackChainIntroducer: [.phrase("try these:"), .phrase("try these in order:")],
        ])
        #expect(Array(merged.effectfulJudgmentCuePhrases.prefix(2)) == ["scrub the", "scrub"])
        #expect(Array(merged.guardedFenceIntroducers.prefix(2)) == [", go ahead:", ", go:"])
        #expect(Array(merged.fallbackChainIntroducers.prefix(2)) == ["try these in order:", "try these:"])
    }

    @Test("a merge rule ignores an entry whose case does not match its category")
    func mismatchedEntryIgnored() {
        // A hand-built entries table can pair any entry with any category; the
        // row's merge rule must skip what it cannot read instead of corrupting
        // the field (or trapping).
        let mismatched: [LexiconCategory: [LexiconEntry]] = [
            .comparison: [.phrase("not a comparison")],
            .duration: [.phrase("not a duration")],
            .aggregate: [.phrase("not an aggregate")],
            .superlative: [.phrase("not a superlative")],
            .gradableAdjective: [.phrase("not a gradable")],
            .irregularPlural: [.phrase("not a mapping")],
            .traceOutcome: [.phrase("not an outcome")],
            .fenceTool: [.phrase("not a tool")],
        ]
        let merged = EnglishLexicon.default.merging(entries: mismatched)
        for category in LexiconCategory.allCases {
            #expect(fieldEntries(category, in: merged) == fieldEntries(category, in: .default),
                    Comment(rawValue: "\(category) changed on a mismatched entry"))
        }
    }

    // MARK: - 3. Real fixtures

    @Test("every === language === fixture merges into exactly the categories it declares")
    func fixtureParity() throws {
        var fixtures = onDiskFixtures()
        fixtures += inlineFixtures()

        var parsed = 0
        for fixture in fixtures {
            let source = "=== language ===\n" + fixture.body.joined(separator: "\n") + "\n"
            guard let synonyms = try? MerConfigParser(trace: .silent())
                .parse(source, file: fixture.name).languageSynonyms else {
                continue  // a fixture the parser rejects is not a parity oracle
            }
            let expected = declaredEntries(inSection: fixture.body)
            parsed += 1

            let merged = EnglishLexicon.default.merging(from: synonyms)
            for category in LexiconCategory.allCases {
                let declared = expected.entries[category] ?? []
                let before = fieldEntries(category, in: .default)
                let after = fieldEntries(category, in: merged)
                let context = Comment(rawValue: "\(fixture.name) / \(category)")
                if declared.isEmpty {
                    // The fixture says nothing about this category, so its
                    // field must be byte-identical to the default.
                    #expect(after == before, context)
                    continue
                }
                // Count + membership, for exactly the declared surface forms.
                let phrases = Set(declared.map(\.phrase))
                #expect(after.filter { phrases.contains($0.phrase) } == Set(declared), context)
            }
            if let timestamp = expected.timestampProperty {
                #expect(merged.timestampProperty == timestamp, Comment(rawValue: fixture.name))
            }
        }
        #expect(parsed >= 20, Comment(rawValue: "only \(parsed) fixtures parsed — extractor regression?"))
    }

    // MARK: - Fixture discovery

    private struct Fixture {
        let name: String
        let body: [String]
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// A `=== <name> ===` header line, matching `MerConfigParser.sectionName`.
    private func isSectionHeader(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("==="), t.hasSuffix("==="), !t.allSatisfy({ $0 == "=" }) else { return false }
        return !t.dropFirst(3).dropLast(3).trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func isLanguageHeader(_ text: String) -> Bool {
        guard isSectionHeader(text) else { return false }
        let t = text.trimmingCharacters(in: .whitespaces)
        return t.dropFirst(3).dropLast(3).trimmingCharacters(in: .whitespaces).lowercased() == "language"
    }

    /// Section bodies of every `=== language ===` block in a file's lines.
    private func sections(in lines: [String]) -> [[String]] {
        var found: [[String]] = []
        var current: [String]? = nil
        for line in lines {
            if isSectionHeader(line) {
                if let body = current { found.append(body) }
                current = isLanguageHeader(line) ? [] : nil
                continue
            }
            current?.append(line)
        }
        if let body = current { found.append(body) }
        return found
    }

    private func onDiskFixtures() -> [Fixture] {
        let root = repositoryRoot()
        var fixtures: [Fixture] = []
        let scan = ["examples", "corpora", "sample-gbrain", "Tests/MeridianCoreTests/Fixtures"]
        for relative in scan {
            let directory = root.appendingPathComponent(relative)
            guard let enumerator = FileManager.default.enumerator(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]) else { continue }
            while let item = enumerator.nextObject() as? URL {
                guard let text = try? String(contentsOf: item, encoding: .utf8),
                      text.contains("=== language ===") else { continue }
                for (index, body) in sections(in: text.components(separatedBy: "\n")).enumerated() {
                    let name = relative + "/" + item.lastPathComponent + "#\(index + 1)"
                    fixtures.append(Fixture(name: name, body: body))
                }
            }
        }
        return fixtures
    }

    /// `=== language ===` blocks written inline in the test sources. A block
    /// ends at the closing quote of the string literal it lives in, which the
    /// source indentation delimits.
    private func inlineFixtures() -> [Fixture] {
        let root = repositoryRoot()
        let directory = root.appendingPathComponent("Tests/MeridianCoreTests")
        guard let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]) else { return [] }

        var fixtures: [Fixture] = []
        while let item = enumerator.nextObject() as? URL {
            guard item.pathExtension == "swift",
                  let text = try? String(contentsOf: item, encoding: .utf8),
                  text.contains("=== language ===") else { continue }
            let lines = text.components(separatedBy: "\n")
            for (offset, line) in lines.enumerated() where isLanguageHeader(line) {
                let indent = line.prefix(while: { $0 == " " }).count
                var body: [String] = []
                for next in lines[(offset + 1)...] {
                    if next.contains("\"\"\"") || isSectionHeader(next) { break }
                    let trimmed = next.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty, next.prefix(while: { $0 == " " }).count <= indent { break }
                    body.append(next)
                }
                let name = item.lastPathComponent + ":" + String(offset + 1)
                fixtures.append(Fixture(name: name, body: body))
            }
        }
        return fixtures
    }

    // MARK: - Independent expectations

    /// The category a header block must select, derived from the header text:
    /// strip the trailing kind word, camel-case the rest, and look it up.
    private func expectedCategory(forHeader header: String) -> LexiconCategory? {
        var words = header.split(separator: " ").map(String.init)
        guard let kind = words.last,
              ["synonym", "synonyms", "mapping", "alias", "aliases", "adjective", "adjectives"].contains(kind)
        else { return nil }
        words.removeLast()
        let parts = words.flatMap { $0.split(separator: "-").map(String.init) }
        let camel = parts.enumerated()
            .map { $0.offset == 0 ? $0.element : $0.element.capitalized }
            .joined()
        // Categories whose name is not the camel-cased header text.
        let aliases: [String: LexiconCategory] = [
            "vagueHedge": .conditionVagueHedge,
            "guardedFence": .guardedFenceIntroducer,
            "fallbackChain": .fallbackChainIntroducer,
            "timestamp": .timestampAlias,
            "gradable": .gradableAdjective,
        ]
        return LexiconCategory(rawValue: camel) ?? aliases[camel]
    }

    /// What a category's lexicon field holds, in the surface terms a
    /// `=== language ===` line declares (merge decorations trimmed).
    private func fieldEntries(_ category: LexiconCategory, in lexicon: EnglishLexicon) -> Set<LexiconEntry> {
        func phrase(_ raw: String) -> LexiconEntry {
            .phrase(raw.trimmingCharacters(in: .whitespaces))
        }
        switch category {
        case .comparison:           return Set(lexicon.comparisonMarkers.map { .comparison($0.0, $0.1) })
        case .duration:             return Set(lexicon.durationUnits.map { .duration($0.key, $0.value) })
        case .assertion:            return Set(lexicon.assertionMarkers.map { phrase($0) })
        case .normativeCue:         return Set(lexicon.normativeCueWords.map { phrase($0) })
        case .inferenceCue:         return Set(lexicon.inferenceCueWords.map { phrase($0) })
        case .referenceHeading:     return Set(lexicon.referenceHeadingWords.map { phrase($0) })
        case .conditionVagueHedge:  return Set(lexicon.conditionVagueHedges.map { phrase($0) })
        case .effectfulJudgment:    return Set(lexicon.effectfulJudgmentCuePhrases.map { phrase($0) })
        case .article:              return Set(lexicon.articles.map { phrase($0) })
        case .parameterArticle:     return Set(lexicon.parameterArticles.map { phrase($0) })
        case .preposition:          return Set(lexicon.prepositions.map { phrase($0) })
        case .copula:               return Set(lexicon.copulas.map { phrase($0) })
        case .participle:           return Set(lexicon.participles.map { phrase($0) })
        case .toolStopword:         return Set(lexicon.toolStopwords.map { phrase($0) })
        case .irregularPlural:      return Set(lexicon.irregularPlurals.map { .mapping($0.key, $0.value) })
        case .contractReference:    return Set(lexicon.contractReferencePhrases.map { phrase($0) })
        case .empty:                return Set(lexicon.emptyMarkers.map { phrase($0) })
        case .filled:               return Set(lexicon.filledMarkers.map { phrase($0) })
        case .pastWindow:           return Set(windowMarkers(.withinPast, lexicon).map { phrase($0) })
        case .futureWindow:         return Set(windowMarkers(.withinFuture, lexicon).map { phrase($0) })
        case .timestampAlias:       return Set(lexicon.timestampAliases.map { phrase($0) })
        case .aggregate:            return Set(lexicon.aggregateIntroducers.map { .aggregate($0.0, $0.1) })
        case .superlative:          return Set(lexicon.superlativeGradables.map { .superlative($0.key, $0.value) })
        case .gradableAdjective:    return Set(lexicon.gradableAdjectives.map { .gradable($0.key, $0.value) })
        case .sortBy:               return Set(lexicon.sortByMarkers.map { phrase($0) })
        case .ascending:            return Set(lexicon.ascendingMarkers.map { phrase($0) })
        case .descending:           return Set(lexicon.descendingMarkers.map { phrase($0) })
        case .possessive:           return Set(lexicon.possessivePronouns.map { phrase($0) })
        case .anaphora:             return Set(lexicon.anaphoraMarkers.map { phrase($0) })
        case .conditionHeader:      return Set(lexicon.tableConditionHeaders.map { phrase($0) })
        case .actionHeader:         return Set(lexicon.tableActionHeaders.map { phrase($0) })
        case .wildcard:             return Set(lexicon.tableWildcardTokens.map { phrase($0) })
        case .traceOutcome:         return Set(lexicon.traceOutcomeVerbs.map { .mapping($0.key, $0.value.rawValue) })
        case .traceAuxiliary:       return Set(lexicon.tracePerfectAuxiliaries.map { phrase($0) })
        case .shellFence:           return Set(lexicon.shellFenceLanguages.map { phrase($0) })
        case .fenceTool:            return Set(lexicon.fenceToolMapping.map { .mapping($0.key, $0.value) })
        case .guardedFenceIntroducer:  return Set(lexicon.guardedFenceIntroducers.map { phrase($0) })
        case .fallbackChainIntroducer: return Set(lexicon.fallbackChainIntroducers.map { phrase($0) })
        case .approvalTool:         return Set(lexicon.approvalToolIDSubstrings.map { phrase($0) })
        }
    }

    private func windowMarkers(_ op: ComparisonOpAST, _ lexicon: EnglishLexicon) -> [String] {
        lexicon.temporalWindowMarkers.filter { $0.1 == op }.map(\.0)
    }

    /// What a fixture declares, derived from its text with the same value
    /// resolvers the parser uses (comparison spellings, duration units, …) but
    /// without the registry's per-category wiring.
    private func declaredEntries(inSection body: [String]) -> (entries: [LexiconCategory: [LexiconEntry]], timestampProperty: String?) {
        let parser = MerConfigParser(trace: .silent())
        var spec: LexiconCategorySpec? = nil
        var entries: [LexiconCategory: [LexiconEntry]] = [:]
        var timestampProperty: String? = nil

        for raw in body {
            let text = raw.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, !text.hasPrefix("#"), !text.hasPrefix(">") else { continue }
            let statement = SentenceBreaker().statementText(from: text, trace: .silent())
                .trimmingCharacters(in: .whitespaces)
            let lower = statement.lowercased()

            if let header = LexiconRegistry.spec(matchingHeader: lower) {
                spec = header
                continue
            }
            if lower.hasPrefix("timestamp"), let eq = statement.range(of: " = ") {
                let value = String(statement[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { timestampProperty = value }
                continue
            }
            guard let spec else { continue }

            switch spec.shape {
            case .phraseList:
                guard !lower.isEmpty else { continue }
                entries[spec.category, default: []].append(.phrase(lower))
            case .phraseListVerbatim:
                guard !statement.isEmpty else { continue }
                entries[spec.category, default: []].append(.phrase(statement))
            case .comparison, .duration, .aggregate, .superlative, .gradable, .mapping, .mappingPreservingCase:
                guard let entry = declaredKeyedEntry(statement, spec: spec, parser: parser) else { continue }
                var list = entries[spec.category] ?? []
                if spec.shape.replacesDuplicateKeys,
                   let index = list.firstIndex(where: { $0.phrase == entry.phrase }) {
                    list[index] = entry
                } else {
                    list.append(entry)
                }
                entries[spec.category] = list
            }
        }
        return (entries, timestampProperty)
    }

    private func declaredKeyedEntry(
        _ statement: String,
        spec: LexiconCategorySpec,
        parser: MerConfigParser
    ) -> LexiconEntry? {
        guard let eqRange = statement.range(of: " = ") else { return nil }
        let key = String(statement[statement.startIndex ..< eqRange.lowerBound])
            .trimmingCharacters(in: .whitespaces).lowercased()
        let rawValue = String(statement[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let value = rawValue.lowercased()

        switch spec.shape {
        case .comparison:
            guard let op = parser.resolveComparisonOp(value) else { return nil }
            return .comparison(key, op)
        case .duration:
            guard let unit = EnglishLexicon.default.durationUnits[value] else { return nil }
            return .duration(key, unit)
        case .aggregate:
            switch value {
            case "count": return .aggregate(key, .count)
            case "list":  return .aggregate(key, .list)
            default:      return nil
            }
        case .superlative:
            guard let direction = SuperlativeDirection(rawValue: value) else { return nil }
            return .superlative(key, direction)
        case .gradable:
            let tokens = value.split(whereSeparator: \.isWhitespace).map(String.init)
            guard tokens.count >= 2,
                  let ascending = parser.parseGradableDirection(tokens[tokens.count - 1]) else { return nil }
            return .gradable(key, GradableAdjectiveMetadata(
                property: tokens.dropLast().joined(separator: " "), ascending: ascending))
        case .mapping:
            return .mapping(key, value)
        case .mappingPreservingCase:
            guard !rawValue.isEmpty else { return nil }
            return .mapping(key, rawValue)
        case .phraseList, .phraseListVerbatim:
            return nil
        }
    }

    /// One synthetic line per category, plus how it reads before and after the
    /// merge (only the verbatim wildcard list changes case).
    private struct CategorySample {
        let line: String
        let declared: LexiconEntry
        let field: LexiconEntry
    }

    private func sample(for spec: LexiconCategorySpec) -> CategorySample {
        let name = "zqx" + spec.category.rawValue.lowercased()
        switch spec.shape {
        case .phraseList:
            return CategorySample(line: "  \(name)", declared: .phrase(name), field: .phrase(name))
        case .phraseListVerbatim:
            let verbatim = "ZQX-\(spec.category.rawValue)"
            return CategorySample(line: "  \(verbatim)", declared: .phrase(verbatim),
                                  field: .phrase(verbatim.lowercased()))
        case .comparison:
            return CategorySample(line: "  \(name) = greater than",
                                  declared: .comparison(name, .greaterThan),
                                  field: .comparison(name, .greaterThan))
        case .duration:
            return CategorySample(line: "  \(name) = week",
                                  declared: .duration(name, .week), field: .duration(name, .week))
        case .aggregate:
            return CategorySample(line: "  \(name) = count",
                                  declared: .aggregate(name, .count), field: .aggregate(name, .count))
        case .superlative:
            return CategorySample(line: "  \(name) = newest",
                                  declared: .superlative(name, .newest), field: .superlative(name, .newest))
        case .gradable:
            let metadata = GradableAdjectiveMetadata(property: "zqxproperty", ascending: true)
            return CategorySample(line: "  \(name) = zqxproperty ascending",
                                  declared: .gradable(name, metadata), field: .gradable(name, metadata))
        case .mapping:
            // A trace-outcome synonym must name a real outcome verb; the merge
            // drops anything else, so the sample follows the same rule.
            let value = spec.category == .traceOutcome ? "failed" : "zqxvalue"
            return CategorySample(line: "  \(name) = \(value)",
                                  declared: .mapping(name, value), field: .mapping(name, value))
        case .mappingPreservingCase:
            return CategorySample(line: "  \(name) = Zqx.Tool.Run",
                                  declared: .mapping(name, "Zqx.Tool.Run"),
                                  field: .mapping(name, "Zqx.Tool.Run"))
        }
    }
}
