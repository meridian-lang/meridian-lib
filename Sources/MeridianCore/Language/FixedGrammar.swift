import Foundation

/// The closed grammar skeleton of Meridian's controlled English: the surface
/// tokens that define *what the language is*, as opposed to *what a domain
/// calls things*. Unlike `EnglishLexicon`'s domain-synonymisable tables, these
/// are **NOT author-extensible** — they are centralized here (literal, in one
/// trackable place) purely so a maintainer can find and reason about them
/// together instead of hunting hand-listed copies across parse sites.
///
/// Exposed as `EnglishLexicon.grammar`, a defaulted stored field that
/// `merging(...)` passes through unchanged, so there is still a single lexicon
/// thread parameter and no extra plumbing at call sites.
///
/// Promotion rule: move an entry into an author-extensible `=== language ===`
/// `EnglishLexicon` field only when a real domain needs to rename it. Until
/// then it stays here, fixed.
public struct FixedGrammar: Sendable {

    /// Relative-clause introducers that gate a verb from being read as a
    /// top-level active predicate (`pages that mention …` is a description, not
    /// a `verbPredicate`).
    public let relativizers: Set<String>

    /// Do-support auxiliaries carrying negation before a base verb
    /// (`the entity does not link …`).
    public let negationAuxiliaries: Set<String>

    /// Negated do-support contractions that fuse the negator (`doesn't`).
    public let negationContractions: Set<String>

    /// Clause-level negation introducer (`it is not the case that X` → ¬X).
    /// Stored with its trailing space for direct prefix matching.
    public let clauseNegationIntroducer: String

    /// Quantifier per-element body verbs (spaced for in-string matching), e.g.
    /// `every page has …`. Splits the description from the body clause.
    public let quantifierBodyVerbs: [String]

    /// Plural→singular normalization of a quantifier body verb so the
    /// synthesised `<element> <body>` re-parses (`have`→`has`, `are`→`is`).
    public let quantifierBodyNormalization: [String: String]

    /// Partitive markers introducing a quantifier collection (`some of the …`).
    /// Distinct from the aggregate `number of`/`list of` forms.
    public let quantifierPartitiveMarkers: [String]

    /// Rule-subject filter-clause introducers (`a customer with status …`).
    public let subjectFilterIntroducers: Set<String>

    /// Markers bounding a permission's action clause (`approve any order whose
    /// total is up to …`).
    public let permissionBoundMarkers: [String]

    /// Determiners stripped when extracting an object kind from action text
    /// (`approve all orders` → `orders`). Shared by the rule object-kind and
    /// permission object-kind extractors.
    public let nounPhraseDeterminers: Set<String>

    /// Phrase-pattern parameter boundary connectors (in addition to
    /// prepositions/copulas) in `.merconfig` phrase declarations.
    public let phraseParamConnectors: Set<String>

    /// The `called` introducer naming a phrase-pattern parameter explicitly.
    public let calledIntroducer: String

    /// Output-format-invariant quantifier prefixes (`every emitted <noun> …`)
    /// rewritten to `the <noun> …`. A structural rewrite (not domain vocab).
    public let emittedInvariantPrefixes: [String]

    // MARK: - 3E prose / control-flow introducer families
    //
    // These define the language's prose-mode and modality surface. Centralized
    // here (one source) so the same trigger isn't hand-listed across parse
    // sites — notably the discretion/autonomy markers, which gate BOTH the
    // workflow header (`MeridianParser`) and body blocks (`StatementParser`).

    /// `use judgment to <goal>` discretion-block introducers (spelling variants).
    public let judgmentIntroducers: [String]

    /// The discretion block/header marker (`with discretion`). The workflow
    /// header form is `", " + discretionMarker`; the body form is the bare
    /// marker (optionally `:`-terminated).
    public let discretionMarker: String

    /// The autonomy block/header marker (`with autonomy`).
    public let autonomyMarker: String

    /// `decide whether <question>` boolean-discretion introducer.
    public let decideWhetherIntroducer: String

    /// `decide using:` code-block discretion introducer (exact match).
    public let decideUsingMarker: String

    /// `you decide that <question>` discretion-predicate introducer.
    public let youDecideIntroducer: String

    /// `unless you decide that <question>` negated discretion-predicate introducer.
    public let unlessYouDecideIntroducer: String

    /// Choice-gate introducers (`ask the user to choose between …`, variants).
    public let choiceGateIntroducers: [String]

    /// Background-spawn introducers (`in the background, <stmt>`, variants).
    public let backgroundSpawnIntroducers: [String]

    /// Passive-modality markers rewritten to active voice (` should be `,
    /// ` must be `, ` needs to be `).
    public let passiveModalityMarkers: [String]

    /// `wait for signal "<name>"` introducer.
    public let waitSignalIntroducer: String

    /// `wait for approval from <role>` introducer.
    public let waitApprovalIntroducer: String

    /// `wait for event <id>` introducer.
    public let waitEventIntroducer: String

    /// The `matching` clause marker inside a `for event … matching …` wait.
    public let waitMatchingMarker: String

    // MARK: - 3E statement idiom rewrites
    //
    // Surface idioms that desugar to a core control-flow shape. The trigger
    // word is fixed grammar; the rewritten form re-parses through the normal
    // path. Centralized so the trigger and its rewrite target stay paired.

    /// `after <cond>, <action>` temporal-precondition idiom → guarded action.
    public let afterIdiomIntroducer: String

    /// `<action> except when <pred>` idiom, rewritten to `<action> unless <pred>`.
    public let exceptWhenMarker: String

    /// `try <action>; if it fails <handler>` recover idiom: the `try ` prefix
    /// and the `; if it fails ` separator.
    public let tryIdiomIntroducer: String
    public let tryIdiomFailureSeparator: String

    /// Suffix-conditional applicability markers (`<action> only when <pred>` /
    /// `<action> unless <pred>`). The ` unless ` form negates the predicate;
    /// it is also the rewrite target of `except when`.
    public let suffixConditionalMarkers: [String]
    public let suffixConditionalNegated: String

    // MARK: - Relational / condition-layer markers (Wave 3)
    //
    // Closed structural markers of the relational query surface. Each maps 1:1
    // to a fixed parse shape (not a domain-renamable term), centralized here so
    // the relational layer's surface tokens live in one place.

    /// Property-emptiness predicate suffixes (`<subj> is empty` / `is not
    /// empty`) mapping to `.isEmpty` / `.isNotEmpty`. Distinct from the
    /// author-extensible `has no`/`has a` forms in `EnglishLexicon`.
    public let emptyPredicateSuffix: String
    public let notEmptyPredicateSuffix: String

    /// Ordered relative-clause split markers for a description's verb clause
    /// (`pages that mention …`, `pages which …`). `whose` is handled by a
    /// separate predicate branch and is intentionally NOT in this list.
    public let relativeClauseMarkers: [String]

    /// The passive-voice / superlative agent marker (`pages written by X`,
    /// `the largest order by total`). A fixed structural ` by `, NOT a general
    /// preposition substitution.
    public let passiveByMarker: String

    /// Scalar relation-navigation connectors (`the task assigned to/by the
    /// user`). The closed set of prepositions that introduce the nav operand.
    public let scalarNavConnectors: Set<String>

    /// Past-participle suffix heuristic for the "did you mean a relation verb?"
    /// error (`owned`, `written`). Distinct from `EnglishLexicon`'s
    /// `participleSuffixes` (`ed`/`ing`, a verb-stop signal in phrase patterns).
    public let pastParticipleSuffixes: [String]

    /// Standalone cue words (beyond copulas + comparison markers) that make a
    /// fragment read as a *condition* rather than a descriptive dispatch phrase
    /// (`X equals Y`, `not ready`). Used by `ConditionClassifier.readsAsCondition`.
    public let conditionCueWords: Set<String>

    /// Plain-English comparison-operator spellings accepted as the *target* of a
    /// `=== language ===` `Comparison synonyms:` entry, beyond what
    /// `EnglishLexicon.comparisonMarkers` already lists (which is tried first).
    /// Centralized so the synonym-target vocabulary lives in one place.
    public let comparisonOpSpellings: [String: ComparisonOpAST]

    public init(
        relativizers: Set<String> = ["that", "which", "who", "whose", "whom"],
        negationAuxiliaries: Set<String> = ["does", "do", "did"],
        negationContractions: Set<String> = ["doesn't", "don't", "didn't"],
        clauseNegationIntroducer: String = "it is not the case that ",
        quantifierBodyVerbs: [String] = [
            " have ", " has ", " are ", " is ", " contain ", " contains ",
            " include ", " includes ", " do ", " does "
        ],
        quantifierBodyNormalization: [String: String] = [
            "have": "has", "are": "is", "do": "does",
            "contain": "contains", "include": "includes"
        ],
        quantifierPartitiveMarkers: [String] = ["of the ", "of "],
        subjectFilterIntroducers: Set<String> = ["with", "whose", "that", "which", "having"],
        permissionBoundMarkers: [String] = ["whose ", "up to ", "if "],
        nounPhraseDeterminers: Set<String> = ["a", "an", "the", "any", "some", "all"],
        phraseParamConnectors: Set<String> = ["and", "that", "whose", "which"],
        calledIntroducer: String = "called",
        emittedInvariantPrefixes: [String] = ["every emitted ", "each emitted "],
        judgmentIntroducers: [String] = ["use judgment to ", "use judgement to ", "use your judgment to "],
        discretionMarker: String = "with discretion",
        autonomyMarker: String = "with autonomy",
        decideWhetherIntroducer: String = "decide whether ",
        decideUsingMarker: String = "decide using:",
        youDecideIntroducer: String = "you decide that ",
        unlessYouDecideIntroducer: String = "unless you decide that ",
        choiceGateIntroducers: [String] = [
            "ask the user to choose between ", "ask the user to choose from ",
            "choose between ", "ask to choose between ",
        ],
        backgroundSpawnIntroducers: [String] = [
            "in the background, ", "in the background ", "spawn in the background, ",
        ],
        passiveModalityMarkers: [String] = [" should be ", " must be ", " needs to be "],
        waitSignalIntroducer: String = "for signal ",
        waitApprovalIntroducer: String = "for approval from ",
        waitEventIntroducer: String = "for event ",
        waitMatchingMarker: String = " matching ",
        afterIdiomIntroducer: String = "after ",
        exceptWhenMarker: String = " except when ",
        tryIdiomIntroducer: String = "try ",
        tryIdiomFailureSeparator: String = "; if it fails ",
        suffixConditionalMarkers: [String] = [" only when ", " unless "],
        suffixConditionalNegated: String = " unless ",
        emptyPredicateSuffix: String = " is empty",
        notEmptyPredicateSuffix: String = " is not empty",
        relativeClauseMarkers: [String] = [" that "],
        passiveByMarker: String = " by ",
        scalarNavConnectors: Set<String> = ["to", "by"],
        pastParticipleSuffixes: [String] = ["ed", "en"],
        conditionCueWords: Set<String> = ["equals", "not"],
        comparisonOpSpellings: [String: ComparisonOpAST] = [
            "greater than": .greaterThan, "greater": .greaterThan,
            "less than": .lessThan, "less": .lessThan,
            "greater or equal": .greaterOrEqual, "greater than or equal": .greaterOrEqual,
            "greater or equal to": .greaterOrEqual,
            "less or equal": .lessOrEqual, "less than or equal": .lessOrEqual,
            "less or equal to": .lessOrEqual,
            "equal": .equal, "equals": .equal,
            "not equal": .notEqual, "not equals": .notEqual,
            "within": .within,
        ]
    ) {
        self.relativizers = relativizers
        self.negationAuxiliaries = negationAuxiliaries
        self.negationContractions = negationContractions
        self.clauseNegationIntroducer = clauseNegationIntroducer
        self.quantifierBodyVerbs = quantifierBodyVerbs
        self.quantifierBodyNormalization = quantifierBodyNormalization
        self.quantifierPartitiveMarkers = quantifierPartitiveMarkers
        self.subjectFilterIntroducers = subjectFilterIntroducers
        self.permissionBoundMarkers = permissionBoundMarkers
        self.nounPhraseDeterminers = nounPhraseDeterminers
        self.phraseParamConnectors = phraseParamConnectors
        self.calledIntroducer = calledIntroducer
        self.emittedInvariantPrefixes = emittedInvariantPrefixes
        self.judgmentIntroducers = judgmentIntroducers
        self.discretionMarker = discretionMarker
        self.autonomyMarker = autonomyMarker
        self.decideWhetherIntroducer = decideWhetherIntroducer
        self.decideUsingMarker = decideUsingMarker
        self.youDecideIntroducer = youDecideIntroducer
        self.unlessYouDecideIntroducer = unlessYouDecideIntroducer
        self.choiceGateIntroducers = choiceGateIntroducers
        self.backgroundSpawnIntroducers = backgroundSpawnIntroducers
        self.passiveModalityMarkers = passiveModalityMarkers
        self.waitSignalIntroducer = waitSignalIntroducer
        self.waitApprovalIntroducer = waitApprovalIntroducer
        self.waitEventIntroducer = waitEventIntroducer
        self.waitMatchingMarker = waitMatchingMarker
        self.afterIdiomIntroducer = afterIdiomIntroducer
        self.exceptWhenMarker = exceptWhenMarker
        self.tryIdiomIntroducer = tryIdiomIntroducer
        self.tryIdiomFailureSeparator = tryIdiomFailureSeparator
        self.suffixConditionalMarkers = suffixConditionalMarkers
        self.suffixConditionalNegated = suffixConditionalNegated
        self.emptyPredicateSuffix = emptyPredicateSuffix
        self.notEmptyPredicateSuffix = notEmptyPredicateSuffix
        self.relativeClauseMarkers = relativeClauseMarkers
        self.passiveByMarker = passiveByMarker
        self.scalarNavConnectors = scalarNavConnectors
        self.pastParticipleSuffixes = pastParticipleSuffixes
        self.conditionCueWords = conditionCueWords
        self.comparisonOpSpellings = comparisonOpSpellings
    }

    public static let `default` = FixedGrammar()
}
