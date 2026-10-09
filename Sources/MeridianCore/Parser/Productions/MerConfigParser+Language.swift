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
    ///
    /// Every header block, the shape of its lines and the way its entries reach
    /// the lexicon come from `LexiconRegistry`, so a new category needs no edit
    /// here. A line that opens no known block is ignored, exactly as before.
    func parseLanguageSection(_ lines: [SourceLine]) -> LanguageSynonyms {
        let content = lines.filter(\.isContent)
        var entries: [LexiconCategory: [LexiconEntry]] = [:]
        var timestampProperty: String? = nil
        var spec: LexiconCategorySpec? = nil

        for line in content {
            let t = line.statement.trimmingCharacters(in: .whitespaces)
            let lower = t.lowercased()

            // Header → mode. The registry table is checked in order, so the
            // most specific spelling wins where two prefixes overlap (e.g.
            // `timestamp alias` ahead of the standalone `timestamp =` entry).
            if let header = LexiconRegistry.spec(matchingHeader: lower) {
                spec = header
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
            guard let spec else { continue }

            // A bare-phrase block appends the line itself — lower-cased, or
            // verbatim for the table-wildcard list. A keyed block parses a
            // `key = value` pair in the shape its category declares.
            switch spec.shape {
            case .phraseList:
                guard !lower.isEmpty else { continue }
                record(.phrase(lower), in: spec, into: &entries)
            case .phraseListVerbatim:
                guard !t.isEmpty else { continue }
                record(.phrase(t), in: spec, into: &entries)
            case .comparison, .duration, .aggregate, .superlative, .gradable, .mapping, .mappingPreservingCase:
                guard let entry = parseKeyedEntry(t, shape: spec.shape) else { continue }
                record(entry, in: spec, into: &entries)
            }
        }

        return LanguageSynonyms(entries: entries, timestampProperty: timestampProperty)
    }

    /// Parse one `key = value` line in the shape its category declares. Only
    /// keyed shapes reach here — a bare-phrase block handles its own lines.
    func parseKeyedEntry(_ statement: String, shape: ValueShape) -> LexiconEntry? {
        guard let eqRange = statement.range(of: " = ") else { return nil }
        let key = String(statement[statement.startIndex ..< eqRange.lowerBound])
            .trimmingCharacters(in: .whitespaces).lowercased()
        let rawValue = String(statement[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let value = rawValue.lowercased()

        switch shape {
        case .comparison:
            guard let op = resolveComparisonOp(value) else { return nil }
            return .comparison(key, op)
        case .duration:
            guard let unit = lexicon.durationUnits[value] else { return nil }
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
                  let ascending = parseGradableDirection(tokens[tokens.count - 1]) else { return nil }
            // `split` omits empty subsequences, so dropLast() is non-empty when count >= 2.
            let property = tokens.dropLast().joined(separator: " ")
            return .gradable(key, GradableAdjectiveMetadata(property: property, ascending: ascending))
        case .mapping:
            return .mapping(key, value)
        case .mappingPreservingCase:
            // "python = interpreter.run" — the value keeps its original case
            // (a tool ID), unlike the lower-cased keyed values above. It is
            // never empty: `t` is whitespace-trimmed, so a matched " = " cannot
            // end the line.
            return .mapping(key, rawValue)
        case .phraseList, .phraseListVerbatim:
            return nil
        }
    }

    /// Append `entry` to its category, replacing an earlier same-key entry for
    /// dictionary-shaped categories (the `[String: …]` field's last-write-wins).
    private func record(
        _ entry: LexiconEntry,
        in spec: LexiconCategorySpec,
        into entries: inout [LexiconCategory: [LexiconEntry]]
    ) {
        var list = entries[spec.category] ?? []
        if spec.shape.replacesDuplicateKeys,
           let index = list.firstIndex(where: { $0.phrase == entry.phrase }) {
            list[index] = entry
        } else {
            list.append(entry)
        }
        entries[spec.category] = list
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
