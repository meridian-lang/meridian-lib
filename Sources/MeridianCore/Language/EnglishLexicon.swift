import Foundation

/// The four sort-direction buckets a superlative gradable maps to. Encodes the
/// `(ascending, needsBy)` pair so authors extending `Superlative synonyms:`
/// never touch the booleans directly.
public enum SuperlativeDirection: String, Sendable {
    case oldest, newest, smallest, largest

    /// `oldest`/`smallest` sort ascending; `newest`/`largest` descending.
    public var ascending: Bool { self == .oldest || self == .smallest }

    /// Magnitude gradables (`smallest`/`largest`) require an explicit
    /// `by <property>`; timestamp gradables default to `timestampProperty`.
    public var needsBy: Bool { self == .smallest || self == .largest }
}

/// Declared measurable backing for a checkable adjective (`=== language ===`
/// `Gradable adjectives:`). Enables `the most <adj> <kind>` without an explicit
/// `by <property>` when the adjective is listed here.
public struct GradableAdjectiveMetadata: Sendable, Equatable {
    public let property: String
    /// Sort direction for `the most <adj> …`; `the least <adj> …` inverts this.
    public let ascending: Bool

    public init(property: String, ascending: Bool) {
        self.property = property
        self.ascending = ascending
    }
}

/// Centralises every English-specific table the compiler uses.
/// Pass a customised instance through `Compiler.Options.lexicon` to change
/// comparison vocabulary, duration units, or stop-word sets without
/// recompiling Meridian.
public struct EnglishLexicon: Sendable {

    /// Articles stripped from argument slot text and possessive chains.
    public let articles: Set<String>

    /// Indefinite articles that introduce phrase-pattern parameter slots.
    /// Kept separate from `articles` so a definite article (`the`) can still be
    /// stripped from expressions without accidentally creating new parameters.
    public let parameterArticles: Set<String>

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

    /// Whole-word cue vocabulary marking a sentence as an operational/
    /// normative contract (must/never/always, refusal/requirement language)
    /// rather than plain documentation or AI-inference prose. Used by
    /// `TrialLowering`'s per-line classifier (`SkillMigrator`'s marking pass)
    /// to decide whether an unlowerable line states a requirement that must
    /// be reworded into something checkable — a hard "reword or clarify"
    /// error (P1 category 4) — as opposed to genuinely-inert documentation
    /// or an AI-inference cue (see `inferenceCueWords`). Extend via
    /// `=== language ===` `Normative-cue synonyms:`.
    public let normativeCueWords: Set<String>

    /// Whole-word cue vocabulary marking a sentence as needing genuine AI
    /// inference/judgment — cognitive verbs (analyse, decide, assess, …)
    /// signalling the agent must *think*, not mechanically act. This is the
    /// ONLY signal that permits the migrator to emit any AI marker
    /// (`use judgment to …:`, `with autonomy`, `!!! table (( ai-discretion
    /// ))`, `!!! checklist (( ai-autonomy ))`) for content that failed to
    /// lower deterministically. A line is tested for lowerability first, so
    /// a lowerable phrase that happens to contain a cue word (e.g. "analyze
    /// the report") still lowers — the cue only classifies content that
    /// already failed to lower. Extend via `=== language ===`
    /// `Inference-cue synonyms:`.
    public let inferenceCueWords: Set<String>

    /// Heading/body substrings that mark a non-lowerable, cue-less section as
    /// genuinely documentary (rationale, examples, changelog, background,
    /// reference material) rather than an operational reword error. Used by
    /// `SkillMetrics.classifyInert`'s `looksReferenceLike` and by the
    /// migrator's whole-section decision. Extend via `=== language ===`
    /// `Reference-heading synonyms:`.
    public let referenceHeadingWords: Set<String>

    /// Body substrings marking a documentary contract note that the executable
    /// workflow already enforces the referenced guard (`already enforced`, …).
    /// Used by `SkillMetrics.inertContractDocumentsExistingGuard`. Extend via
    /// `=== language ===` `Contract-reference synonyms:`.
    public let contractReferencePhrases: Set<String>

    /// Vague hedges quarantined from kernel conditions (`looks`, `roughly`, …).
    /// A `whose`/comparison clause containing one of these triggers MER-CND-001.
    public let conditionVagueHedges: Set<String>

    /// Phrase cues marking effectful judgment goals that require a `producing`
    /// binding (MER-JDG-001 when absent).
    public let effectfulJudgmentCuePhrases: [String]

    /// Trailing markers that turn an `if <cond>` header into a **guarded
    /// fence**: `if <cond>, run:` immediately followed by a fenced shell
    /// code-block wraps that block's `shell.run` invokes in a `branch` — no
    /// new IR, just a structural production over two adjacent lines (SKILL.md
    /// bodies are flat, so the fence is never indented under the header).
    /// Ordered longest-first. Extend via `=== language ===`
    /// `Guarded-fence synonyms:`.
    public let guardedFenceIntroducers: [String]

    /// Lead-in lines that introduce a **fallback chain**: an ordered list of
    /// steps where each step recovers into the next on failure, lowering to a
    /// nested `recover` chain (no new IR — the existing `attached`/`handler`
    /// shape, just built N-deep instead of 1-deep). Extend via
    /// `=== language ===` `Fallback-chain synonyms:`.
    public let fallbackChainIntroducers: [String]

    /// Substrings matched against tool/workflow IDs when detecting an existing
    /// approval step (so precondition injection does not double-wait). Extend
    /// via `=== language ===` `Approval-tool synonyms:`.
    public let approvalToolIDSubstrings: Set<String>

    /// The element property a temporal iteration clause (`within the last`/`in
    /// the next`) resolves `updated`/`created`-style references to. Default
    /// `updatedAt`; override via a `=== language ===` `timestamp:` entry.
    public let timestampProperty: String

    /// The closed grammar-skeleton vocabulary (relativizers, negation,
    /// quantifier body verbs, determiners, …). NOT author-extensible — see
    /// `FixedGrammar`. Threaded through `merging(...)` unchanged.
    public let grammar: FixedGrammar

    // MARK: - 3B author-extensible categories

    /// Property-emptiness markers (`<subj> has no <prop>` → `.isEmpty`).
    /// Extend via `=== language ===` `Empty synonyms:`.
    public let emptyMarkers: [String]

    /// Property-filled markers (`<subj> has a <prop>` → `.isNotEmpty`).
    /// Extend via `=== language ===` `Filled synonyms:`.
    public let filledMarkers: [String]

    /// One-sided temporal-window markers (`within the last`/`in the next`) and
    /// the comparison op each introduces. Extend via `Past-window synonyms:` /
    /// `Future-window synonyms:`.
    public let temporalWindowMarkers: [(String, ComparisonOpAST)]

    /// Bare participle subjects a temporal window resolves to `timestampProperty`
    /// (`updated`/`modified`/`changed`). Extend via `Timestamp aliases:`.
    public let timestampAliases: Set<String>

    /// Aggregate introducers (`number of`/`count of` → `.count`, `list of` →
    /// `.list`). Extend via `Aggregate synonyms:`.
    public let aggregateIntroducers: [(String, AggregateKindAST)]

    /// Superlative gradables (`oldest`/`largest`/…) → a sort direction bucket.
    /// Extend via `Superlative synonyms:`.
    public let superlativeGradables: [String: SuperlativeDirection]

    /// Checkable adjectives with a declared measurable backing property.
    /// Extend via `Gradable adjectives:` in `=== language ===`.
    public let gradableAdjectives: [String: GradableAdjectiveMetadata]

    /// Sort-clause introducer markers (`sorted by`). Extend via `Sort-by synonyms:`.
    public let sortByMarkers: [String]

    /// Ascending sort-direction tokens (`ascending`, `oldest`, `ascend`).
    /// Extend via `Ascending synonyms:`.
    public let ascendingMarkers: [String]

    /// Descending sort-direction tokens (`descending`, `newest`, `descend`).
    /// Extend via `Descending synonyms:`.
    public let descendingMarkers: [String]

    /// Possessive pronouns that refer back to a rule subject (`their`/`his`/…).
    /// Extend via `Possessive synonyms:`.
    public let possessivePronouns: [String]

    /// Anaphora markers a discretion/autonomy resolver treats as references to a
    /// prior result (`that result`/`the same`/`it`/`them`). Extend via
    /// `Anaphora synonyms:`.
    public let anaphoraMarkers: [String]

    /// Trace event outcome verbs and their canonical meanings.
    public let traceOutcomeVerbs: [String: EventPatternAST.OutcomeVerb]

    /// Perfect/passive auxiliary tokens (`has`/`have`/`had`/`was`/`were`/`been`)
    /// that a trace event-pattern subject may carry ahead of its outcome verb
    /// (`the deploy step has failed`, `slack.send was invoked`). Every operator
    /// except `has ever` (which splits on the ` has ever ` marker before the
    /// event pattern is ever parsed) hands the subject text — auxiliary still
    /// attached — straight to `TraceEventPatternGrammar`, so the auxiliary must
    /// be stripped there too, or it gets glued onto the subject (`.named("deploy
    /// step has")` instead of `.step("deploy")`), which silently never matches a
    /// real trace record. Extend via `=== language ===` `Trace-auxiliary synonyms:`.
    public let tracePerfectAuxiliaries: Set<String>

    // MARK: - 3D table/checklist surface vocabulary

    /// Decision-table condition-column headers that carry no information of
    /// their own (the cell is the whole condition). Extend via
    /// `Condition-header synonyms:`.
    public let tableConditionHeaders: Set<String>

    /// Decision-table action-column headers (the remaining columns are
    /// conditions). Extend via `Action-header synonyms:`.
    public let tableActionHeaders: Set<String>

    /// Decision-table wildcard cell tokens (a cell that does not constrain its
    /// row). Extend via `Wildcard synonyms:`.
    public let tableWildcardTokens: Set<String>

    /// Fence info-string tags (lower-cased) treated as verbatim shell-command
    /// blocks — each command line lowers to a deterministic `shell.run` invoke.
    /// The default set is the module-level `shellFenceLanguages` constant (the
    /// single source of truth used by the lexicon-free authoring paths, e.g. the
    /// migrator marking pass). Extend via `=== language ===` `Shell fence
    /// synonyms:` so a domain can add dialects (`fish`, `pwsh`, `nu`, …).
    public let shellFenceLanguages: Set<String>

    /// True when a fence language tag denotes a shell-command block under this
    /// lexicon. Lower-cases the tag before lookup.
    public func isShellFence(_ lang: String) -> Bool {
        shellFenceLanguages.contains(lang.lowercased())
    }

    /// Fence info-string tag (lower-cased) → tool ID, for **non-shell**
    /// languages a domain wants lowered deterministically instead of falling
    /// to inert/AI dispatch — e.g. ```` ```python ```` → `interpreter.run`.
    /// Empty by default (opt-in only); populated via `=== language ===`
    /// `Fence tool mapping:` (`MerConfigParser.parseLanguageSection` →
    /// `LanguageSynonyms.fenceToolMapping`). Checked only when
    /// `isShellFence(_:)` is false — shell dialects keep their `shell.run` +
    /// command-hole-interpolation treatment regardless of any mapping entry.
    public let fenceToolMapping: [String: String]

    /// Explicit singular→plural overrides for irregular nouns (`person` →
    /// `people`). Multi-word heads consult both the full phrase and the final
    /// word. Regular morphology still covers `entry` → `entries`.
    public let irregularPlurals: [String: String]

    /// The configured tool ID for a fence language tag, or `nil` when no
    /// `Fence tool mapping:` entry matches. Lower-cases the tag before lookup.
    public func fenceTool(for lang: String) -> String? {
        fenceToolMapping[lang.lowercased()]
    }

    public init(
        articles: Set<String>,
        parameterArticles: Set<String> = ["a", "an"],
        prepositions: Set<String>,
        copulas: Set<String>,
        participles: Set<String>,
        participleSuffixes: [String],
        comparisonMarkers: [(String, ComparisonOpAST)],
        durationUnits: [String: TimeUnitAST],
        toolStopwords: Set<String>,
        assertionMarkers: [String] = ["make sure", "ensure", "assert"],
        normativeCueWords: Set<String> = [
            "must", "never", "always",
            "refuse", "refuses", "refused", "refusing",
            "require", "requires", "required", "requiring",
            "forbidden", "mandatory",
        ],
        inferenceCueWords: Set<String> = [
            "analyse", "analyze", "analyzes", "analyses", "analyzing", "analysing",
            "assess", "assesses", "assessing",
            "evaluate", "evaluates", "evaluating",
            "judge", "judges", "judging",
            "decide", "decides", "deciding",
            "determine", "determines", "determining",
            "interpret", "interprets", "interpreting",
            "consider", "considers", "considering",
            "reason", "reasons", "reasoning",
            "infer", "infers", "inferring",
            "diagnose", "diagnoses", "diagnosing",
            "critique", "critiques", "critiquing",
            "synthesize", "synthesizes", "synthesizing", "synthesise", "synthesising",
            "understand", "understands", "understanding",
        ],
        referenceHeadingWords: Set<String> = [
            "what", "why", "philosophy", "example", "examples", "example:", "for reference",
            "format", "changelog", "related", "reference", "background", "overview",
            "notes", "caveats", "prior work", "methodology", "template",
            "guide", "guidance", "tutorial", "vision", "options", "available",
            "semantics", "invocation patterns", "tracking", "state", "vs",
            "cycle", "patterns", "quality bar", "trust boundary", "idempotency",
            "privacy", "cooldown",
        ],
        contractReferencePhrases: Set<String> = [
            "already enforced", "enforced above",
            "workflow's own", "workflow’s own",
        ],
        conditionVagueHedges: Set<String> = [
            "looks", "roughly", "about", "maybe", "probably", "seems", "appears",
        ],
        effectfulJudgmentCuePhrases: [String] = [
            "clean up", "cleanup", "update the", "delete", "invoke", "send",
            "modify", "remove", "create", "insert into", "write to",
        ],
        guardedFenceIntroducers: [String] = [", run:", ", execute:"],
        fallbackChainIntroducers: [String] = [
            "try the following in order until one succeeds:",
            "try each of the following until one works:",
        ],
        approvalToolIDSubstrings: Set<String> = ["approval", "approve"],
        timestampProperty: String = "updatedAt",
        grammar: FixedGrammar = .default,
        emptyMarkers: [String] = [" has no ", " have no "],
        filledMarkers: [String] = [" has a ", " has an ", " has some ", " have a ", " have an ", " have some "],
        temporalWindowMarkers: [(String, ComparisonOpAST)] = [
            (" within the last ", .withinPast),
            (" in the next ", .withinFuture),
        ],
        timestampAliases: Set<String> = ["updated", "modified", "changed"],
        aggregateIntroducers: [(String, AggregateKindAST)] = [
            ("number of ", .count), ("count of ", .count), ("list of ", .list),
        ],
        superlativeGradables: [String: SuperlativeDirection] = [
            "oldest": .oldest, "earliest": .oldest,
            "newest": .newest, "latest": .newest, "most recent": .newest,
            "smallest": .smallest, "lowest": .smallest, "least": .smallest, "fewest": .smallest,
            "largest": .largest, "highest": .largest, "most": .largest, "greatest": .largest, "biggest": .largest,
            "best": .largest, "worst": .smallest,
        ],
        gradableAdjectives: [String: GradableAdjectiveMetadata] = [:],
        sortByMarkers: [String] = [" sorted by "],
        ascendingMarkers: [String] = ["ascending", "oldest", "ascend"],
        descendingMarkers: [String] = ["descending", "newest", "descend"],
        possessivePronouns: [String] = ["their ", "his ", "her ", "its "],
        anaphoraMarkers: [String] = ["that result", "the same", "it", "them"],
        traceOutcomeVerbs: [String: EventPatternAST.OutcomeVerb] = [
            "failed": .failed,
            "succeeded": .succeeded,
            "invoked": .invoked,
            "emitted": .emitted,
            "prevented": .prevented,
            "violated": .violated,
            "occurred": .occurred,
        ],
        tracePerfectAuxiliaries: Set<String> = ["has", "have", "had", "was", "were", "been"],
        tableConditionHeaders: Set<String> = [
            "condition", "situation", "case", "scenario", "when", "if", "trigger", "context", "state",
        ],
        tableActionHeaders: Set<String> = ["action", "then", "do", "result"],
        tableWildcardTokens: Set<String> = ["*", "-", "\u{2014}", "\u{2013}", "any"],
        shellFenceLanguages: Set<String> = MeridianCore.shellFenceLanguages,
        fenceToolMapping: [String: String] = [:],
        irregularPlurals: [String: String] = [
            "person": "people", "child": "children", "man": "men", "woman": "women",
            "mouse": "mice", "goose": "geese", "tooth": "teeth", "foot": "feet",
            "ox": "oxen", "index": "indices", "matrix": "matrices",
        ]
    ) {
        self.articles = articles
        self.parameterArticles = parameterArticles
        self.prepositions = prepositions
        self.copulas = copulas
        self.participles = participles
        self.participleSuffixes = participleSuffixes
        self.comparisonMarkers = comparisonMarkers
        self.durationUnits = durationUnits
        self.toolStopwords = toolStopwords
        self.assertionMarkers = assertionMarkers
        self.normativeCueWords = normativeCueWords
        self.inferenceCueWords = inferenceCueWords
        self.referenceHeadingWords = referenceHeadingWords
        self.contractReferencePhrases = contractReferencePhrases
        self.conditionVagueHedges = conditionVagueHedges
        self.effectfulJudgmentCuePhrases = effectfulJudgmentCuePhrases
        self.guardedFenceIntroducers = guardedFenceIntroducers
        self.fallbackChainIntroducers = fallbackChainIntroducers
        self.approvalToolIDSubstrings = approvalToolIDSubstrings
        self.timestampProperty = timestampProperty
        self.grammar = grammar
        self.emptyMarkers = emptyMarkers
        self.filledMarkers = filledMarkers
        self.temporalWindowMarkers = temporalWindowMarkers
        self.timestampAliases = timestampAliases
        self.aggregateIntroducers = aggregateIntroducers
        self.superlativeGradables = superlativeGradables
        self.gradableAdjectives = gradableAdjectives
        self.sortByMarkers = sortByMarkers
        self.ascendingMarkers = ascendingMarkers
        self.descendingMarkers = descendingMarkers
        self.possessivePronouns = possessivePronouns
        self.anaphoraMarkers = anaphoraMarkers
        self.traceOutcomeVerbs = traceOutcomeVerbs
        self.tracePerfectAuxiliaries = tracePerfectAuxiliaries
        self.tableConditionHeaders = tableConditionHeaders
        self.tableActionHeaders = tableActionHeaders
        self.tableWildcardTokens = tableWildcardTokens
        self.shellFenceLanguages = shellFenceLanguages
        self.fenceToolMapping = fenceToolMapping
        self.irregularPlurals = irregularPlurals
    }

    /// Default English surface used when no custom lexicon is supplied.
    public static let `default` = EnglishLexicon(
        articles: ["a", "an", "the"],
        parameterArticles: ["a", "an"],
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
            // Ordered by match priority (first split wins in `parseComparison`).
            // Each copula-prefixed marker (`is X`) is listed before its bare,
            // copula-less sibling (`X`) so `a is greater than b` binds to the
            // `is` form and `a greater than b` falls through to the bare form.
            // The bare forms make the canonical English comparison spellings
            // first-class surface — a condition needn't include the copula.
            //
            // The `… than or equal to` (≥/≤) entries embed the word `or`. The
            // boolean layer would otherwise split on that `or`; `ExpressionParser`
            // shields it (see `maskComparisonOr`). Any or-bearing marker added
            // here — or via a `=== language ===` synonym — is shielded
            // automatically because the shield is derived from this list.
            ("is more than or equal to", .greaterOrEqual),
            ("is less than or equal to", .lessOrEqual),
            ("greater than or equal to", .greaterOrEqual),
            ("more than or equal to",    .greaterOrEqual),
            ("less than or equal to",    .lessOrEqual),
            ("is no less than",          .greaterOrEqual),
            ("is no more than",          .lessOrEqual),
            ("is at least",              .greaterOrEqual),
            ("at least",                 .greaterOrEqual),
            ("is at most",               .lessOrEqual),
            ("at most",                  .lessOrEqual),
            ("up to",                    .lessOrEqual),
            ("is greater than",          .greaterThan),
            ("greater than",             .greaterThan),
            ("is more than",             .greaterThan),
            ("more than",                .greaterThan),
            ("is fewer than",            .lessThan),
            ("fewer than",               .lessThan),
            ("is less than",             .lessThan),
            ("less than",                .lessThan),
            ("is within",                .within),
            ("matches pattern",          .matchesPattern),
            ("is one of",                .oneOf),
            ("contains",                 .contains),
            ("exceeds",                  .greaterThan),
            ("is not",                   .notEqual),
            ("equals",                   .equal),
            ("equal to",                 .equal),
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

    public func hasLeadingArticle(_ s: String) -> Bool {
        let lower = s.trimmingCharacters(in: .whitespaces).lowercased()
        return articles.contains { lower.hasPrefix($0 + " ") }
    }

    public var definiteArticle: String? {
        if articles.contains("the") { return "the" }
        return articles.sorted().first
    }

    /// Indefinite article for a kind-scoped deontic norm subject (`A customer …`).
    /// Vowel-initial phrases use `an` when present in `parameterArticles`.
    public func indefiniteArticlePrefix(for phrase: String) -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.lowercased().first else {
            return parameterArticles.contains("a") ? "a " : "an "
        }
        if "aeiou".contains(first), parameterArticles.contains("an") {
            return "an "
        }
        return parameterArticles.contains("a") ? "a " : "an "
    }

    /// Find the earliest article-delimited parameter slot in a phrase pattern.
    /// Returns the text before the article (`intro`) and the text after it
    /// (`rest`), preserving source casing. Prefix matches are preferred over
    /// infix matches; infix matches choose the earliest position.
    public func findEarliestArticle(_ source: String) -> (intro: String, rest: String)? {
        let sortedArticles = parameterArticles.sorted(by: { $0.count > $1.count })
        let lower = source.lowercased()
        for article in sortedArticles {
            let prefix = article + " "
            if lower.hasPrefix(prefix) {
                return ("", String(source.dropFirst(prefix.count)))
            }
        }

        var best: (range: Range<String.Index>, length: Int)?
        for article in sortedArticles {
            let marker = " \(article) "
            if let range = source.range(of: marker, options: [.caseInsensitive]) {
                if best == nil
                    || range.lowerBound < best!.range.lowerBound
                    || (range.lowerBound == best!.range.lowerBound && marker.count > best!.length) {
                    best = (range, marker.count)
                }
            }
        }

        guard let pick = best else { return nil }
        let intro = String(source[source.startIndex ..< pick.range.lowerBound])
        let rest = String(source[pick.range.upperBound...])
        return (intro, rest)
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

    // MARK: - Calendar amount parsing

    /// Parse `N calendar day` / `N business days` / `N months` using grammar-owned
    /// unit strings. Distinct from physical `parseDuration` (`day` ≠ `calendar day`).
    public func parseCalendarAmount(_ s: String) -> (Double, CalendarAmountUnitAST)? {
        let parts = s.components(separatedBy: " ").filter { !$0.isEmpty }
        guard parts.count >= 2, let amount = Double(parts[0]) else { return nil }
        let unitPhrase = parts.dropFirst().joined(separator: " ").lowercased()
        let table = Self.calendarAmountUnitTable(grammar: grammar)
        if let unit = table[unitPhrase] { return (amount, unit) }
        let singular = singularize(unitPhrase)
        if singular != unitPhrase, let unit = table[singular] { return (amount, unit) }
        return nil
    }

    private static func calendarAmountUnitTable(grammar: FixedGrammar) -> [String: CalendarAmountUnitAST] {
        [
            grammar.calendarBusinessDayUnit.lowercased(): .businessDays,
            grammar.calendarBusinessDaysUnit.lowercased(): .businessDays,
            grammar.calendarDayUnit.lowercased(): .calendarDays,
            grammar.calendarDaysUnit.lowercased(): .calendarDays,
            grammar.calendarMonthUnit.lowercased(): .months,
            grammar.calendarMonthsUnit.lowercased(): .months,
        ]
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
    /// returned unchanged. Multi-word heads pluralize the final word only
    /// (`journal entry` → `journal entries`). Explicit irregular overrides in
    /// `irregularPlurals` win when present.
    public func pluralize(_ raw: String) -> String {
        let s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return s }
        if let override = irregularPlurals[s] { return override }
        let parts = s.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let last = parts.last else { return s }
        if let override = irregularPlurals[last] {
            return (parts.dropLast() + [override]).joined(separator: " ")
        }
        let pluralLast = pluralizeWord(last)
        if parts.count == 1 { return pluralLast }
        return (parts.dropLast() + [pluralLast]).joined(separator: " ")
    }

    private func pluralizeWord(_ s: String) -> String {
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

    /// Merge every `=== language ===` synonym category from `synonyms` into this
    /// lexicon. Preferred call site for compile-time and metrics bootstrap.
    public func merging(from synonyms: LanguageSynonyms) -> EnglishLexicon {
        merging(
            comparisonSynonyms: synonyms.comparisonSynonyms,
            durationSynonyms: synonyms.durationSynonyms,
            assertionSynonyms: synonyms.assertionSynonyms,
            normativeCueSynonyms: synonyms.normativeCueSynonyms,
            inferenceCueSynonyms: synonyms.inferenceCueSynonyms,
            referenceHeadingSynonyms: synonyms.referenceHeadingSynonyms,
            conditionVagueHedgeSynonyms: synonyms.conditionVagueHedgeSynonyms,
            effectfulJudgmentCueSynonyms: synonyms.effectfulJudgmentCueSynonyms,
            articleSynonyms: synonyms.articleSynonyms,
            parameterArticleSynonyms: synonyms.parameterArticleSynonyms,
            prepositionSynonyms: synonyms.prepositionSynonyms,
            copulaSynonyms: synonyms.copulaSynonyms,
            participleSynonyms: synonyms.participleSynonyms,
            toolStopwordSynonyms: synonyms.toolStopwordSynonyms,
            irregularPluralSynonyms: synonyms.irregularPluralSynonyms,
            contractReferenceSynonyms: synonyms.contractReferenceSynonyms,
            timestampProperty: synonyms.timestampProperty,
            emptySynonyms: synonyms.emptySynonyms,
            filledSynonyms: synonyms.filledSynonyms,
            pastWindowSynonyms: synonyms.pastWindowSynonyms,
            futureWindowSynonyms: synonyms.futureWindowSynonyms,
            timestampAliasSynonyms: synonyms.timestampAliasSynonyms,
            aggregateSynonyms: synonyms.aggregateSynonyms,
            superlativeSynonyms: synonyms.superlativeSynonyms,
            gradableAdjectiveSynonyms: synonyms.gradableAdjectiveSynonyms,
            sortBySynonyms: synonyms.sortBySynonyms,
            ascendingSynonyms: synonyms.ascendingSynonyms,
            descendingSynonyms: synonyms.descendingSynonyms,
            possessiveSynonyms: synonyms.possessiveSynonyms,
            anaphoraSynonyms: synonyms.anaphoraSynonyms,
            conditionHeaderSynonyms: synonyms.conditionHeaderSynonyms,
            actionHeaderSynonyms: synonyms.actionHeaderSynonyms,
            wildcardSynonyms: synonyms.wildcardSynonyms,
            traceOutcomeSynonyms: synonyms.traceOutcomeSynonyms,
            traceAuxiliarySynonyms: synonyms.traceAuxiliarySynonyms,
            shellFenceSynonyms: synonyms.shellFenceSynonyms,
            fenceToolSynonyms: synonyms.fenceToolMapping,
            guardedFenceIntroducerSynonyms: synonyms.guardedFenceIntroducerSynonyms,
            fallbackChainIntroducerSynonyms: synonyms.fallbackChainIntroducerSynonyms,
            approvalToolSynonyms: synonyms.approvalToolSynonyms
        )
    }

    /// Return a new lexicon with additional comparison markers prepended
    /// (so vocabulary synonyms take priority over defaults) and additional
    /// duration unit aliases merged in.
    public func merging(
        comparisonSynonyms: [(String, ComparisonOpAST)],
        durationSynonyms: [String: TimeUnitAST],
        assertionSynonyms: [String] = [],
        normativeCueSynonyms: [String] = [],
        inferenceCueSynonyms: [String] = [],
        referenceHeadingSynonyms: [String] = [],
        conditionVagueHedgeSynonyms: [String] = [],
        effectfulJudgmentCueSynonyms: [String] = [],
        articleSynonyms: [String] = [],
        parameterArticleSynonyms: [String] = [],
        prepositionSynonyms: [String] = [],
        copulaSynonyms: [String] = [],
        participleSynonyms: [String] = [],
        toolStopwordSynonyms: [String] = [],
        irregularPluralSynonyms: [String: String] = [:],
        contractReferenceSynonyms: [String] = [],
        timestampProperty: String? = nil,
        emptySynonyms: [String] = [],
        filledSynonyms: [String] = [],
        pastWindowSynonyms: [String] = [],
        futureWindowSynonyms: [String] = [],
        timestampAliasSynonyms: [String] = [],
        aggregateSynonyms: [(String, AggregateKindAST)] = [],
        superlativeSynonyms: [String: SuperlativeDirection] = [:],
        gradableAdjectiveSynonyms: [String: GradableAdjectiveMetadata] = [:],
        sortBySynonyms: [String] = [],
        ascendingSynonyms: [String] = [],
        descendingSynonyms: [String] = [],
        possessiveSynonyms: [String] = [],
        anaphoraSynonyms: [String] = [],
        conditionHeaderSynonyms: [String] = [],
        actionHeaderSynonyms: [String] = [],
        wildcardSynonyms: [String] = [],
        traceOutcomeSynonyms: [String: String] = [:],
        traceAuxiliarySynonyms: [String] = [],
        shellFenceSynonyms: [String] = [],
        fenceToolSynonyms: [String: String] = [:],
        guardedFenceIntroducerSynonyms: [String] = [],
        fallbackChainIntroducerSynonyms: [String] = [],
        approvalToolSynonyms: [String] = []
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

        seen = Set<String>()
        let mergedGuardedFence = (
            guardedFenceIntroducerSynonyms.map { $0.lowercased() }.sorted { $0.count > $1.count }
            + guardedFenceIntroducers.sorted { $0.count > $1.count }
        )
            .filter { seen.insert($0).inserted }

        seen = Set<String>()
        let mergedFallbackChain = (
            fallbackChainIntroducerSynonyms.map { $0.lowercased() }.sorted { $0.count > $1.count }
            + fallbackChainIntroducers.sorted { $0.count > $1.count }
        )
            .filter { seen.insert($0).inserted }

        // Temporal-window synonyms become spaced markers (` <phrase> `) so they
        // match mid-string exactly like the defaults.
        let pastWindow = pastWindowSynonyms.map { (" \($0.lowercased()) ", ComparisonOpAST.withinPast) }
        let futureWindow = futureWindowSynonyms.map { (" \($0.lowercased()) ", ComparisonOpAST.withinFuture) }

        var mergedSuperlatives = superlativeGradables
        for (k, v) in superlativeSynonyms { mergedSuperlatives[k.lowercased()] = v }

        var mergedGradableAdjectives = gradableAdjectives
        for (k, v) in gradableAdjectiveSynonyms { mergedGradableAdjectives[k.lowercased()] = v }

        var mergedFenceTools = fenceToolMapping
        for (k, v) in fenceToolSynonyms { mergedFenceTools[k.lowercased()] = v }

        var mergedTraceOutcomes = traceOutcomeVerbs
        for (key, value) in traceOutcomeSynonyms {
            guard let outcome = EventPatternAST.OutcomeVerb(rawValue: value.lowercased()) else { continue }
            mergedTraceOutcomes[key.lowercased()] = outcome
        }

        var seenEffectful = Set<String>()
        let mergedEffectfulJudgment = (
            effectfulJudgmentCueSynonyms.map { $0.lowercased() }.sorted { $0.count > $1.count }
            + effectfulJudgmentCuePhrases.sorted { $0.count > $1.count }
        )
            .filter { seenEffectful.insert($0).inserted }

        var mergedIrregularPlurals = irregularPlurals
        for (singular, plural) in irregularPluralSynonyms {
            mergedIrregularPlurals[singular.lowercased()] = plural.lowercased()
        }

        return EnglishLexicon(
            articles: articles.union(articleSynonyms.map { $0.lowercased() }),
            parameterArticles: parameterArticles.union(parameterArticleSynonyms.map { $0.lowercased() }),
            prepositions: prepositions.union(prepositionSynonyms.map { $0.lowercased() }),
            copulas: copulas.union(copulaSynonyms.map { $0.lowercased() }),
            participles: participles.union(participleSynonyms.map { $0.lowercased() }),
            participleSuffixes: participleSuffixes,
            comparisonMarkers: mergedComparisons,
            durationUnits: mergedDuration,
            toolStopwords: toolStopwords.union(toolStopwordSynonyms.map { $0.lowercased() }),
            assertionMarkers: mergedAssertions,
            normativeCueWords: normativeCueWords.union(normativeCueSynonyms.map { $0.lowercased() }),
            inferenceCueWords: inferenceCueWords.union(inferenceCueSynonyms.map { $0.lowercased() }),
            referenceHeadingWords: referenceHeadingWords.union(referenceHeadingSynonyms.map { $0.lowercased() }),
            contractReferencePhrases: contractReferencePhrases.union(contractReferenceSynonyms.map { $0.lowercased() }),
            conditionVagueHedges: conditionVagueHedges.union(conditionVagueHedgeSynonyms.map { $0.lowercased() }),
            effectfulJudgmentCuePhrases: mergedEffectfulJudgment,
            guardedFenceIntroducers: mergedGuardedFence,
            fallbackChainIntroducers: mergedFallbackChain,
            approvalToolIDSubstrings: approvalToolIDSubstrings.union(approvalToolSynonyms.map { $0.lowercased() }),
            timestampProperty: timestampProperty ?? self.timestampProperty,
            grammar: grammar,
            emptyMarkers: emptySynonyms.map { " \($0.lowercased()) " } + emptyMarkers,
            filledMarkers: filledSynonyms.map { " \($0.lowercased()) " } + filledMarkers,
            temporalWindowMarkers: pastWindow + futureWindow + temporalWindowMarkers,
            timestampAliases: timestampAliases.union(timestampAliasSynonyms.map { $0.lowercased() }),
            aggregateIntroducers: aggregateSynonyms + aggregateIntroducers,
            superlativeGradables: mergedSuperlatives,
            gradableAdjectives: mergedGradableAdjectives,
            sortByMarkers: sortBySynonyms.map { " \($0.lowercased()) " } + sortByMarkers,
            ascendingMarkers: ascendingSynonyms.map { $0.lowercased() } + ascendingMarkers,
            descendingMarkers: descendingSynonyms.map { $0.lowercased() } + descendingMarkers,
            possessivePronouns: possessiveSynonyms.map { "\($0.lowercased()) " } + possessivePronouns,
            anaphoraMarkers: anaphoraSynonyms.map { $0.lowercased() } + anaphoraMarkers,
            traceOutcomeVerbs: mergedTraceOutcomes,
            tracePerfectAuxiliaries: tracePerfectAuxiliaries.union(traceAuxiliarySynonyms.map { $0.lowercased() }),
            tableConditionHeaders: tableConditionHeaders.union(conditionHeaderSynonyms.map { $0.lowercased() }),
            tableActionHeaders: tableActionHeaders.union(actionHeaderSynonyms.map { $0.lowercased() }),
            tableWildcardTokens: tableWildcardTokens.union(wildcardSynonyms.map { $0.lowercased() }),
            shellFenceLanguages: shellFenceLanguages.union(shellFenceSynonyms.map { $0.lowercased() }),
            fenceToolMapping: mergedFenceTools,
            irregularPlurals: mergedIrregularPlurals
        )
    }

    /// Canonical English comparison surface for verbalization. Author-supplied
    /// comparison markers take priority; otherwise falls back to the grammar
    /// spelling table and the built-in verbalizer defaults.
    public func canonicalComparisonSurface(_ op: ComparisonOp) -> String {
        let trimmedMarkers = comparisonMarkers
            .filter { Self.comparisonOp(from: $0.1) == op }
            .map { $0.0.trimmingCharacters(in: .whitespaces) }
        if let preferred = Self.verbalizerComparisonDefaults[op],
           let marker = trimmedMarkers.first(where: { $0 == preferred }) {
            return marker
        }
        if let marker = trimmedMarkers.first, !marker.isEmpty {
            return marker
        }
        // Dictionary order is not stable across runs; tests accept any spelling
        // for the same op when markers are empty.
        if let spelling = grammar.comparisonOpSpellings.first(where: { Self.comparisonOp(from: $0.value) == op })?.key {
            switch op {
            case .lessThan, .greaterThan, .lessOrEqual, .greaterOrEqual, .notEqual:
                if spelling.hasPrefix("is ") || spelling.contains(" or ") { return spelling }
                return "is \(spelling)"
            default:
                return spelling
            }
        }
        return Self.verbalizerComparisonDefaults[op] ?? "equals"
    }

    private static let verbalizerComparisonDefaults: [ComparisonOp: String] = [
        .equal: "equals",
        .notEqual: "is not",
        .lessThan: "is less than",
        .lessOrEqual: "is at most",
        .greaterThan: "is more than",
        .greaterOrEqual: "is at least",
        .oneOf: "is one of",
        .contains: "contains",
        .startsWith: "starts with",
        .endsWith: "ends with",
        .withinDuration: "is within",
        .withinPast: "is within the last",
        .withinFuture: "is in the next",
        .matchesPattern: "matches pattern",
        .isEmpty: "is empty",
        .isNotEmpty: "is not empty",
        .identifies: "identifies",
    ]

    private static func comparisonOp(from ast: ComparisonOpAST) -> ComparisonOp? {
        switch ast {
        case .equal: return .equal
        case .notEqual: return .notEqual
        case .lessThan: return .lessThan
        case .lessOrEqual: return .lessOrEqual
        case .greaterThan: return .greaterThan
        case .greaterOrEqual: return .greaterOrEqual
        case .oneOf: return .oneOf
        case .contains: return .contains
        case .within: return .withinDuration
        case .withinPast: return .withinPast
        case .withinFuture: return .withinFuture
        case .matchesPattern: return .matchesPattern
        case .isEmpty: return .isEmpty
        case .isNotEmpty: return .isNotEmpty
        }
    }
}
