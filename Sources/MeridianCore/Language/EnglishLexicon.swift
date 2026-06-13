import Foundation

/// Centralises every English-specific table the compiler uses.
/// Pass a customised instance through `Compiler.Options.lexicon` to change
/// comparison vocabulary, duration units, or stop-word sets without
/// recompiling Meridian.
public struct EnglishLexicon: Sendable {

    /// Articles stripped from argument slot text and possessive chains.
    public let articles: Set<String>

    /// Prepositions used as stop-words when deriving struct names and
    /// tokenising phrase invocations.
    public let prepositions: Set<String>

    /// Copula verb forms treated as connectors in phrase-pattern parsing.
    public let copulas: Set<String>

    /// Well-known past participles used as verb stop signals in phrase-pattern
    /// parsing. Heuristic suffix matching (`hasSuffix("ed")`) covers most
    /// regular forms; add irregular ones here.
    public let participles: Set<String>

    /// Suffix heuristics for detecting verb-like words in phrase patterns.
    /// Default: `["ed", "ing"]`.
    public let participleSuffixes: [String]

    /// Ordered list of (marker, ComparisonOpAST) pairs for `parseComparison`.
    /// Longest markers first so e.g. "is more than" matches before "is".
    public let comparisonMarkers: [(String, ComparisonOpAST)]

    /// Map from canonical duration-unit spellings (and their plural/abbrev
    /// variants) to TimeUnitAST.  Key is lower-cased.
    public let durationUnits: [String: TimeUnitAST]

    /// Stop-words stripped before token-overlap tool-resolution scoring.
    public let toolStopwords: Set<String>

    /// Leading keywords that introduce an invariant/assertion statement
    /// (`make sure X.`, `ensure X.`, `assert X.`). Ordered longest-first so a
    /// multi-word marker matches before a single-word prefix of it. Extend via
    /// a `=== language ===` `Assertion synonyms:` block.
    public let assertionMarkers: [String]

    /// The element property a temporal iteration clause (`within the last`/`in
    /// the next`) resolves `updated`/`created`-style references to. Default
    /// `updatedAt`; override via a `=== language ===` `timestamp:` entry.
    public let timestampProperty: String

    public init(
        articles: Set<String>,
        prepositions: Set<String>,
        copulas: Set<String>,
        participles: Set<String>,
        participleSuffixes: [String],
        comparisonMarkers: [(String, ComparisonOpAST)],
        durationUnits: [String: TimeUnitAST],
        toolStopwords: Set<String>,
        assertionMarkers: [String] = ["make sure", "ensure", "assert"],
        timestampProperty: String = "updatedAt"
    ) {
        self.articles = articles
        self.prepositions = prepositions
        self.copulas = copulas
        self.participles = participles
        self.participleSuffixes = participleSuffixes
        self.comparisonMarkers = comparisonMarkers
        self.durationUnits = durationUnits
        self.toolStopwords = toolStopwords
        self.assertionMarkers = assertionMarkers
        self.timestampProperty = timestampProperty
    }

    /// Default English surface used when no custom lexicon is supplied.
    public static let `default` = EnglishLexicon(
        articles: ["a", "an", "the"],
        prepositions: ["of", "for", "with", "by", "from", "to", "on", "at", "via",
                       "about", "into", "through", "during", "before", "after",
                       "because", "between", "since", "until", "upon"],
        copulas: ["is", "are", "was", "were", "has", "have", "had"],
        participles: [
            "placed", "sent", "given", "taken", "made", "approved", "rejected",
            "submitted", "received", "created", "updated", "deleted", "found",
            "named", "called", "labelled", "tagged", "owned", "managed",
            "performed", "executed", "triggered", "raised", "emitted",
            "processed", "completed", "cancelled", "failed", "succeeded",
            "flagged", "assigned", "allocated", "delivered", "returned"
        ],
        participleSuffixes: ["ed", "ing"],
        comparisonMarkers: [
            // longest matches first — order matters
            ("is more than or equal to", .greaterOrEqual),
            ("is less than or equal to", .lessOrEqual),
            ("is no less than",          .greaterOrEqual),
            ("is no more than",          .lessOrEqual),
            ("is at least",              .greaterOrEqual),
            ("is at most",               .lessOrEqual),
            ("up to",                    .lessOrEqual),
            ("is greater than",          .greaterThan),
            ("is more than",             .greaterThan),
            ("is fewer than",            .lessThan),
            ("is less than",             .lessThan),
            ("is within",                .within),
            ("matches pattern",          .matchesPattern),
            ("is one of",                .oneOf),
            ("contains",                 .contains),
            ("exceeds",                  .greaterThan),
            ("is not",                   .notEqual),
            ("is",                       .equal),
        ],
        durationUnits: [
            "ms": .millisecond, "millisecond": .millisecond, "milliseconds": .millisecond,
            "second": .second, "seconds": .second, "sec": .second, "secs": .second,
            "minute": .minute, "minutes": .minute, "min": .minute, "mins": .minute,
            "hour": .hour, "hours": .hour, "hr": .hour, "hrs": .hour,
            "day": .day, "days": .day,
            "week": .week, "weeks": .week,
        ],
        toolStopwords: ["a", "an", "the", "of", "for", "with", "from", "by", "to", "that",
                        "and", "or", "invoke", "call", "run"]
    )

    // MARK: - Articles

    /// Strip a single leading article (`a`/`an`/`the`, plus any domain-added
    /// `articles` entries) from `s`, if present. Case-insensitive; the returned
    /// string preserves the original casing of the remainder. Longest article
    /// first, so a multi-word article cannot be shadowed by a shorter prefix.
    /// Use this instead of re-listing `["the ", "a ", "an "]` inline — articles
    /// are lexicon-owned surface vocabulary (see AGENTS.md §3).
    public func stripLeadingArticle(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        for article in articles.sorted(by: { $0.count > $1.count }) {
            let prefix = article + " "
            if lower.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return trimmed
    }

    // MARK: - Duration parsing

    /// Try to parse "N unit" text into a (Double, TimeUnitAST) pair using this
    /// lexicon's `durationUnits` table. Returns nil if the text doesn't match.
    ///
    /// The unit lookup is plural-tolerant: if the spelled unit isn't directly
    /// in `durationUnits`, we strip a trailing `s` (or `es` for words like
    /// `fortnights → fortnight`) and try again. Lexicon authors only need to
    /// list the singular form; common pluralised forms still resolve.
    public func parseDuration(_ s: String) -> (Double, TimeUnitAST)? {
        let parts = s.components(separatedBy: " ").filter { !$0.isEmpty }
        guard parts.count >= 2, let amount = Double(parts[0]) else { return nil }
        let unit = parts[1].lowercased()
        if let unitAST = durationUnits[unit] { return (amount, unitAST) }
        let singular = singularize(unit)
        if singular != unit,
           let unitAST = durationUnits[singular] {
            return (amount, unitAST)
        }
        return nil
    }

    public func singularize(_ raw: String) -> String {
        let s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        // `ies` → `y` (after a consonant): `categories` → `category`.
        if s.hasSuffix("ies"), s.count > 3 {
            let stem = s.dropLast(3)
            if let prev = stem.last, !"aeiou".contains(prev) { return String(stem) + "y" }
        }
        // `es` only strips two when the stem ends in a sibilant (`statuses` →
        // `status`, `boxes` → `box`). Plain `pages` must NOT become `pag`.
        if s.hasSuffix("es"), s.count > 2 {
            let stem = s.dropLast(2)
            if stem.hasSuffix("s") || stem.hasSuffix("x") || stem.hasSuffix("z")
                || stem.hasSuffix("ch") || stem.hasSuffix("sh") {
                return String(stem)
            }
        }
        if s.hasSuffix("s"), s.count > 1 {
            return String(s.dropLast())
        }
        return s
    }

    /// Regular pluralization, the inverse of `singularize`: `y→ies` after a
    /// consonant, `+es` after a sibilant, else `+s`. Already-plural inputs are
    /// returned unchanged.
    public func pluralize(_ raw: String) -> String {
        let s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return s }
        if s.hasSuffix("s") || s.hasSuffix("x") || s.hasSuffix("z")
            || s.hasSuffix("ch") || s.hasSuffix("sh") { return s.hasSuffix("s") ? s : s + "es" }
        if s.hasSuffix("y"), let prev = s.dropLast().last, !"aeiou".contains(prev) {
            return String(s.dropLast()) + "ies"
        }
        return s + "s"
    }

    // MARK: - 3B. Regular verb morphology

    /// Third-person singular of a regular verb base: `+es` after a sibilant/
    /// `o`/`x`/`z`, `y→ies` after a consonant, else `+s`. No consonant doubling.
    /// Authors override irregulars inline in the verb declaration.
    public func thirdPersonSingular(_ base: String) -> String {
        let b = base.lowercased()
        guard let last = b.last else { return b }
        if b.hasSuffix("s") || b.hasSuffix("sh") || b.hasSuffix("ch") || b.hasSuffix("x") || b.hasSuffix("z") || b.hasSuffix("o") {
            return b + "es"
        }
        if last == "y", let prev = b.dropLast().last, !"aeiou".contains(prev) {
            return String(b.dropLast()) + "ies"
        }
        return b + "s"
    }

    /// Regular past participle: `+d` after `e`, `y→ied` after a consonant, else
    /// `+ed`. No consonant doubling; irregulars are declared inline.
    public func regularPastParticiple(_ base: String) -> String {
        let b = base.lowercased()
        guard let last = b.last else { return b }
        if last == "e" { return b + "d" }
        if last == "y", let prev = b.dropLast().last, !"aeiou".contains(prev) {
            return String(b.dropLast()) + "ied"
        }
        return b + "ed"
    }

    // MARK: - Struct-name derivation

    /// Derive an UpperCamelCase struct name from a natural-language workflow name.
    /// Takes significant words (strips articles + prepositions) until the first
    /// preposition that follows at least one significant word.
    /// e.g. "process an order placed by a customer" → "ProcessOrder"
    /// e.g. "sync analytics for an order placed by a customer" → "SyncAnalytics"
    public func structName(from name: String) -> String {
        // Split on whitespace AND any non-identifier character (hyphens,
        // underscores, dots, slashes, apostrophes, …). A hyphenated skill name
        // like "webhook-transforms" must yield valid CamelCase
        // ("WebhookTransforms"), never an identifier containing '-' which is a
        // hard Swift syntax error (`struct Webhook-transforms { … }`).
        let words = name
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
        var result: [String] = []
        for word in words {
            let lower = word.lowercased()
            // Stop at any preposition once we have at least one significant word
            if !result.isEmpty && (prepositions.contains(lower) || participles.contains(lower)) {
                break
            }
            // Skip articles
            if articles.contains(lower) { continue }
            result.append(word.prefix(1).uppercased() + word.dropFirst().lowercased())
        }
        let joined = result.joined()
        guard let first = joined.first else { return "Workflow" }
        // Swift identifiers may not begin with a digit.
        return first.isNumber ? "_" + joined : joined
    }

    // MARK: - Lexicon merging (for synonym support)

    /// Return a new lexicon with additional comparison markers prepended
    /// (so vocabulary synonyms take priority over defaults) and additional
    /// duration unit aliases merged in.
    public func merging(
        comparisonSynonyms: [(String, ComparisonOpAST)],
        durationSynonyms: [String: TimeUnitAST],
        assertionSynonyms: [String] = [],
        timestampProperty: String? = nil
    ) -> EnglishLexicon {
        let mergedComparisons = comparisonSynonyms + comparisonMarkers
        var mergedDuration = durationUnits
        for (k, v) in durationSynonyms { mergedDuration[k] = v }
        // Author-supplied markers take priority; de-duplicate, then sort
        // longest-first so a multi-word marker wins over a single-word prefix.
        var seen = Set<String>()
        let mergedAssertions = (assertionSynonyms.map { $0.lowercased() } + assertionMarkers)
            .filter { seen.insert($0).inserted }
            .sorted { $0.count > $1.count }
        return EnglishLexicon(
            articles: articles,
            prepositions: prepositions,
            copulas: copulas,
            participles: participles,
            participleSuffixes: participleSuffixes,
            comparisonMarkers: mergedComparisons,
            durationUnits: mergedDuration,
            toolStopwords: toolStopwords,
            assertionMarkers: mergedAssertions,
            timestampProperty: timestampProperty ?? self.timestampProperty
        )
    }
}
