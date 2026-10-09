import Foundation

public enum DriftCategory: String, Sendable {
    case synonymCanonicalized
    case structureNormalized
    case desugarExpanded
    case meaningBearing
}

public struct DriftHunk: Sendable {
    public let category: DriftCategory
    public let authored: String
    public let canonical: String

    public init(category: DriftCategory, authored: String, canonical: String) {
        self.category = category
        self.authored = authored
        self.canonical = canonical
    }
}

public struct DriftReport: Sendable {
    public let hunks: [DriftHunk]

    public init(hunks: [DriftHunk]) {
        self.hunks = hunks
    }

    public var counts: [DriftCategory: Int] {
        var result: [DriftCategory: Int] = [:]
        for hunk in hunks {
            result[hunk.category, default: 0] += 1
        }
        return result
    }
}

public struct DriftEngine: Sendable {
    public static func diff(
        authored: String,
        canonical: String,
        lexicon: EnglishLexicon = .default
    ) -> DriftReport {
        let trace = ParserTrace.current
        let authoredLines = authored.components(separatedBy: .newlines)
        let canonicalLines = canonical.components(separatedBy: .newlines)
        let maxCount = max(authoredLines.count, canonicalLines.count)
        var hunks: [DriftHunk] = []
        for index in 0..<maxCount {
            let left = index < authoredLines.count ? authoredLines[index] : ""
            let right = index < canonicalLines.count ? canonicalLines[index] : ""
            guard left != right else { continue }
            hunks.append(DriftHunk(
                category: classify(authored: left, canonical: right, lexicon: lexicon),
                authored: left,
                canonical: right
            ))
        }
        trace.log(.drift, "classified \(hunks.count) drift hunk(s)")
        return DriftReport(hunks: hunks)
    }

    private static func classify(authored: String, canonical: String, lexicon: EnglishLexicon) -> DriftCategory {
        if authored.trimmingCharacters(in: .whitespacesAndNewlines) ==
            canonical.trimmingCharacters(in: .whitespacesAndNewlines) {
            return .structureNormalized
        }
        if normalizedSpacing(authored) == normalizedSpacing(canonical) {
            return .structureNormalized
        }
        if looksDesugared(authored: authored, canonical: canonical, lexicon: lexicon) {
            return .desugarExpanded
        }
        if looksSynonymCanonicalized(authored: authored, canonical: canonical, lexicon: lexicon) {
            return .synonymCanonicalized
        }
        return .meaningBearing
    }

    private static func normalizedSpacing(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func looksDesugared(authored: String, canonical: String, lexicon: EnglishLexicon) -> Bool {
        // `diff` classifies one line at a time, so the canonical side never
        // contains a newline here. Treat a `do … and …` authored line whose
        // counterpart no longer carries the `do` sugar as desugar-expanded.
        let doPrefix = lexicon.grammar.statement.doPrefix
        let andMarker = lexicon.grammar.merconfig.andMarker
        let left = authored.lowercased()
        let right = canonical.lowercased()
        return left.contains(doPrefix) && left.contains(andMarker) && !right.contains(doPrefix)
    }

    private static func looksSynonymCanonicalized(authored: String, canonical: String, lexicon: EnglishLexicon) -> Bool {
        // `classify` already returned `.structureNormalized` when spacing-
        // normalized forms match, so left and right differ here.
        let right = normalizedSpacing(canonical.lowercased())
        let comparisonMarkers = lexicon.comparisonMarkers.map { $0.0.trimmingCharacters(in: .whitespaces) }
        let grammar = lexicon.grammar
        let canonicalMarkers = comparisonMarkers + [
            grammar.verbalizer.assertPrefix.trimmingCharacters(in: .whitespaces),
            grammar.statement.completeWithReasonPrefix.trimmingCharacters(in: .whitespaces),
        ]
        return canonicalMarkers.contains { !$0.isEmpty && right.contains($0) }
    }
}
