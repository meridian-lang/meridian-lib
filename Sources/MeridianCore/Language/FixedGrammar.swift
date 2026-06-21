import Foundation

public struct FixedStatementKeywords: Sendable {
    public let forEachPrefix: String
    public let forEveryPrefix: String
    public let otherwisePrefix: String
    public let lenientMode: String
    public let strictMode: String
    public let complete: String
    public let completeWithReasonPrefix: String
    public let commit: String
    public let commitWithLabelPrefix: String
    public let waitPrefix: String
    public let emitPrefix: String
    public let ifPrefix: String
    public let letPrefix: String
    public let letBeMarker: String
    public let bindPrefix: String
    public let rebindPrefix: String
    public let whilePrefix: String
    public let untilPrefix: String
    public let simultaneouslyHeader: String
    public let recoverFromPrefix: String
    public let recoverWherePrefix: String
    public let recoverPrefix: String
    public let doPrefix: String
    public let invokePrefix: String

    public init(
        forEachPrefix: String = "for each ",
        forEveryPrefix: String = "for every ",
        otherwisePrefix: String = "otherwise ",
        lenientMode: String = "in lenient mode",
        strictMode: String = "in strict mode",
        complete: String = "complete",
        completeWithReasonPrefix: String = "complete with reason ",
        commit: String = "commit",
        commitWithLabelPrefix: String = "commit with label ",
        waitPrefix: String = "wait ",
        emitPrefix: String = "emit ",
        ifPrefix: String = "if ",
        letPrefix: String = "let ",
        letBeMarker: String = " be ",
        bindPrefix: String = "bind ",
        rebindPrefix: String = "rebind ",
        whilePrefix: String = "while ",
        untilPrefix: String = "until ",
        simultaneouslyHeader: String = "simultaneously:",
        recoverFromPrefix: String = "recover from ",
        recoverWherePrefix: String = "recover where ",
        recoverPrefix: String = "recover ",
        doPrefix: String = "do ",
        invokePrefix: String = "invoke "
    ) {
        self.forEachPrefix = forEachPrefix
        self.forEveryPrefix = forEveryPrefix
        self.otherwisePrefix = otherwisePrefix
        self.lenientMode = lenientMode
        self.strictMode = strictMode
        self.complete = complete
        self.completeWithReasonPrefix = completeWithReasonPrefix
        self.commit = commit
        self.commitWithLabelPrefix = commitWithLabelPrefix
        self.waitPrefix = waitPrefix
        self.emitPrefix = emitPrefix
        self.ifPrefix = ifPrefix
        self.letPrefix = letPrefix
        self.letBeMarker = letBeMarker
        self.bindPrefix = bindPrefix
        self.rebindPrefix = rebindPrefix
        self.whilePrefix = whilePrefix
        self.untilPrefix = untilPrefix
        self.simultaneouslyHeader = simultaneouslyHeader
        self.recoverFromPrefix = recoverFromPrefix
        self.recoverWherePrefix = recoverWherePrefix
        self.recoverPrefix = recoverPrefix
        self.doPrefix = doPrefix
        self.invokePrefix = invokePrefix
    }

    public var primitivePrefixes: [String] {
        [
            emitPrefix, bindPrefix, rebindPrefix, invokePrefix, ifPrefix,
            whilePrefix, untilPrefix, waitPrefix, recoverPrefix, complete,
            commit, letPrefix, forEachPrefix, forEveryPrefix, simultaneouslyHeader,
        ]
    }

    public var otherwiseKeyword: String {
        otherwisePrefix.trimmingCharacters(in: .whitespaces)
    }

    public var otherwiseCommaKeyword: String {
        otherwiseKeyword + ","
    }

    public var inlineOtherwiseMarker: String {
        ", " + otherwisePrefix
    }
}

public struct FixedQuantifierDeterminers: Sendable {
    public let all: [String]
    public let any: [String]
    public let none: [String]
    public let atLeastPrefix: String
    public let atMostPrefix: String
    public let exactlyPrefix: String

    public init(
        all: [String] = ["all ", "every "],
        any: [String] = ["any ", "some "],
        none: [String] = ["none of ", "none ", "no "],
        atLeastPrefix: String = "at least ",
        atMostPrefix: String = "at most ",
        exactlyPrefix: String = "exactly "
    ) {
        self.all = all
        self.any = any
        self.none = none
        self.atLeastPrefix = atLeastPrefix
        self.atMostPrefix = atMostPrefix
        self.exactlyPrefix = exactlyPrefix
    }
}

public struct FixedBooleanConnectors: Sendable {
    public let orMarker: String
    public let andMarker: String
    public let notPrefix: String
    public let eitherPrefix: String
    public let oxfordAndMarker: String
    public let oxfordOrMarker: String

    public init(
        orMarker: String = " or ",
        andMarker: String = " and ",
        notPrefix: String = "not ",
        eitherPrefix: String = "either ",
        oxfordAndMarker: String = ", and ",
        oxfordOrMarker: String = ", or "
    ) {
        self.orMarker = orMarker
        self.andMarker = andMarker
        self.notPrefix = notPrefix
        self.eitherPrefix = eitherPrefix
        self.oxfordAndMarker = oxfordAndMarker
        self.oxfordOrMarker = oxfordOrMarker
    }
}

public struct FixedRuleMarkers: Sendable {
    public let whenPrefix: String
    public let mustBeMarker: String
    public let mustNotMarker: String
    public let mayMarker: String
    public let byMarker: String
    public let beforeMarker: String
    public let whoseMarker: String
    public let commaSeparator: String
    public let possessiveOfMarker: String

    public init(
        whenPrefix: String = "when ",
        mustBeMarker: String = " must be ",
        mustNotMarker: String = " must not ",
        mayMarker: String = " may ",
        byMarker: String = " by ",
        beforeMarker: String = " before ",
        whoseMarker: String = " whose ",
        commaSeparator: String = ", ",
        possessiveOfMarker: String = " of "
    ) {
        self.whenPrefix = whenPrefix
        self.mustBeMarker = mustBeMarker
        self.mustNotMarker = mustNotMarker
        self.mayMarker = mayMarker
        self.byMarker = byMarker
        self.beforeMarker = beforeMarker
        self.whoseMarker = whoseMarker
        self.commaSeparator = commaSeparator
        self.possessiveOfMarker = possessiveOfMarker
    }
}

public struct FixedMerConfigSkeleton: Sendable {
    public let workflowHeaderPrefix: String
    public let verbDeclPrefix: String
    public let inversePrefix: String
    public let propertiesBlockSuffix: String
    public let hasBlockSuffix: String
    public let whichIsOneOfMarker: String
    public let whichIsMarker: String
    public let commaWhichIsMarker: String
    public let kindPrefix: String
    public let isMarker: String
    public let kindOfMarker: String
    public let hasMarker: String
    public let andMarker: String
    public let relationContinuationPrefixes: [String]
    public let relatesMarker: String
    public let toMarker: String
    public let onePrefix: String
    public let manyPrefix: String
    public let variousPrefix: String
    public let isReadMarker: String
    public let fromPrefix: String
    public let viaPrefix: String
    public let toolSuffix: String
    public let meansMarker: String
    public let relationSuffix: String
    public let thereIsPrefix: String
    public let calledMarker: String
    public let withMarker: String

    public init(
        workflowHeaderPrefix: String = "to ",
        verbDeclPrefix: String = "the verb to ",
        inversePrefix: String = "the inverse of ",
        propertiesBlockSuffix: String = " has properties:",
        hasBlockSuffix: String = " has:",
        whichIsOneOfMarker: String = "which is one of",
        whichIsMarker: String = " which is ",
        commaWhichIsMarker: String = ", which is ",
        kindPrefix: String = "kind ",
        isMarker: String = " is ",
        kindOfMarker: String = " is a kind of ",
        hasMarker: String = " has ",
        andMarker: String = " and ",
        relationContinuationPrefixes: [String] = ["and a ", "and an "],
        relatesMarker: String = " relates ",
        toMarker: String = " to ",
        onePrefix: String = "one ",
        manyPrefix: String = "many ",
        variousPrefix: String = "various ",
        isReadMarker: String = " is read ",
        fromPrefix: String = "from ",
        viaPrefix: String = "via ",
        toolSuffix: String = " tool",
        meansMarker: String = " means ",
        relationSuffix: String = " relation",
        thereIsPrefix: String = "there is ",
        calledMarker: String = " called ",
        withMarker: String = " with "
    ) {
        self.workflowHeaderPrefix = workflowHeaderPrefix
        self.verbDeclPrefix = verbDeclPrefix
        self.inversePrefix = inversePrefix
        self.propertiesBlockSuffix = propertiesBlockSuffix
        self.hasBlockSuffix = hasBlockSuffix
        self.whichIsOneOfMarker = whichIsOneOfMarker
        self.whichIsMarker = whichIsMarker
        self.commaWhichIsMarker = commaWhichIsMarker
        self.kindPrefix = kindPrefix
        self.isMarker = isMarker
        self.kindOfMarker = kindOfMarker
        self.hasMarker = hasMarker
        self.andMarker = andMarker
        self.relationContinuationPrefixes = relationContinuationPrefixes
        self.relatesMarker = relatesMarker
        self.toMarker = toMarker
        self.onePrefix = onePrefix
        self.manyPrefix = manyPrefix
        self.variousPrefix = variousPrefix
        self.isReadMarker = isReadMarker
        self.fromPrefix = fromPrefix
        self.viaPrefix = viaPrefix
        self.toolSuffix = toolSuffix
        self.meansMarker = meansMarker
        self.relationSuffix = relationSuffix
        self.thereIsPrefix = thereIsPrefix
        self.calledMarker = calledMarker
        self.withMarker = withMarker
    }

    public var cardinalityPrefixes: [String] { [onePrefix, manyPrefix, variousPrefix] }
}

public struct FixedTableLookupMarkers: Sendable {
    public let correspondingToMarker: String
    public let inTableMarker: String

    public init(
        correspondingToMarker: String = " corresponding to the ",
        inTableMarker: String = " in the "
    ) {
        self.correspondingToMarker = correspondingToMarker
        self.inTableMarker = inTableMarker
    }
}

public struct FixedTemplateDirectives: Sendable {
    public let ifPrefix: String
    public let otherwiseTerminator: String
    public let endIfTerminator: String
    public let forEachPrefix: String
    public let endForTerminator: String
    public let formatAsMarker: String
    public let loopInMarker: String

    public init(
        ifPrefix: String = "[if ",
        otherwiseTerminator: String = "[otherwise]",
        endIfTerminator: String = "[end if]",
        forEachPrefix: String = "[for each ",
        endForTerminator: String = "[end for]",
        formatAsMarker: String = " as a ",
        loopInMarker: String = " in "
    ) {
        self.ifPrefix = ifPrefix
        self.otherwiseTerminator = otherwiseTerminator
        self.endIfTerminator = endIfTerminator
        self.forEachPrefix = forEachPrefix
        self.endForTerminator = endForTerminator
        self.formatAsMarker = formatAsMarker
        self.loopInMarker = loopInMarker
    }
}

public struct FixedChoiceBranchLabels: Sendable {
    public let yesLabels: Set<String>
    public let noLabels: Set<String>
    public let pickPrefixes: [String]
    public let choiceConditionPrefix: String

    public init(
        yesLabels: Set<String> = ["yes", "the user agrees", "the user says yes"],
        noLabels: Set<String> = ["no", "the user declines", "the user says no"],
        pickPrefixes: [String] = [
            "the user picks ", "the user selects ", "the user chooses ",
            "user picks ", "user selects ", "user chooses ",
        ],
        choiceConditionPrefix: String = "choice is "
    ) {
        self.yesLabels = yesLabels
        self.noLabels = noLabels
        self.pickPrefixes = pickPrefixes
        self.choiceConditionPrefix = choiceConditionPrefix
    }
}

public struct FixedIterationMarkers: Sendable {
    public let whoseMarker: String
    public let firstPrefix: String
    public let collectionInMarker: String
    public let chainCommaAndMarker: String
    public let chainAndMarker: String
    public let chainThenMarker: String
    public let cleanupAndPrefix: String
    public let cleanupThenPrefix: String
    public let embeddedEachMarkers: [String]

    public init(
        whoseMarker: String = " whose ",
        firstPrefix: String = "first ",
        collectionInMarker: String = " in ",
        chainCommaAndMarker: String = ", and ",
        chainAndMarker: String = " and ",
        chainThenMarker: String = " then ",
        cleanupAndPrefix: String = "and ",
        cleanupThenPrefix: String = "then ",
        embeddedEachMarkers: [String] = [" every ", " each "]
    ) {
        self.whoseMarker = whoseMarker
        self.firstPrefix = firstPrefix
        self.collectionInMarker = collectionInMarker
        self.chainCommaAndMarker = chainCommaAndMarker
        self.chainAndMarker = chainAndMarker
        self.chainThenMarker = chainThenMarker
        self.cleanupAndPrefix = cleanupAndPrefix
        self.cleanupThenPrefix = cleanupThenPrefix
        self.embeddedEachMarkers = embeddedEachMarkers
    }
}

public struct FixedAutonomyMarkers: Sendable {
    public let until: String
    public let unless: String
    public let replanAfter: [String]
    public let maxSteps: [String]

    public init(
        until: String = "until",
        unless: String = "unless",
        replanAfter: [String] = ["re-plan after", "replan after"],
        maxSteps: [String] = ["max", "up to"]
    ) {
        self.until = until
        self.unless = unless
        self.replanAfter = replanAfter
        self.maxSteps = maxSteps
    }

    public var boundaryMarkers: [String] {
        ([until, unless] + replanAfter + maxSteps).map { " \($0) " }
    }
}

public struct FixedLintMarkers: Sendable {
    public let politenessPrefixes: [String]
    public let uncertaintyMarkers: [String]

    public init(
        politenessPrefixes: [String] = ["please "],
        uncertaintyMarkers: [String] = [" maybe ", "maybe "]
    ) {
        self.politenessPrefixes = politenessPrefixes
        self.uncertaintyMarkers = uncertaintyMarkers
    }
}

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
public final class FixedGrammar: Sendable {

    public let statement: FixedStatementKeywords
    public let quantifierDeterminers: FixedQuantifierDeterminers
    public let booleanConnectors: FixedBooleanConnectors
    public let ruleMarkers: FixedRuleMarkers
    public let merconfig: FixedMerConfigSkeleton
    public let tableLookup: FixedTableLookupMarkers
    public let templateDirectives: FixedTemplateDirectives
    public let choiceBranchLabels: FixedChoiceBranchLabels
    public let iterationMarkers: FixedIterationMarkers
    public let autonomyMarkers: FixedAutonomyMarkers
    public let lintMarkers: FixedLintMarkers
    public let implicitParamFillConnector: String
    public let negationWrapperPrefix: String
    public let negationWrapperSuffix: String
    public let definitionPrefix: String
    public let definitionIfMarker: String
    public let definitionPossessivePronoun: String
    public let definitionSubjectPronoun: String
    public let legacyImportVocabularyPrefix: String
    public let legacyImportPrefix: String
    public let topLevelRulePrefix: String
    public let informRulePhasePrefixes: [String]
    public let informStopOutcome: String
    public let informSuccessOutcome: String
    public let informFailureOutcome: String

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

    /// Declarative domain sentence markers (`A page can be archived or live.`,
    /// `A page is usually live.`). These are fixed assembly-time grammar, not
    /// author-extensible vocabulary.
    public let domainCanBeMarker: String
    public let domainUsuallyMarker: String

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

    /// Judgment wrapper generated by the migrator; its body may intentionally
    /// collect until the next heading because wrapped guidance can contain
    /// Markdown-like indentation.
    public let judgmentFollowCollectPrefix: String

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
        statement: FixedStatementKeywords = .init(),
        quantifierDeterminers: FixedQuantifierDeterminers = .init(),
        booleanConnectors: FixedBooleanConnectors = .init(),
        ruleMarkers: FixedRuleMarkers = .init(),
        merconfig: FixedMerConfigSkeleton = .init(),
        tableLookup: FixedTableLookupMarkers = .init(),
        templateDirectives: FixedTemplateDirectives = .init(),
        choiceBranchLabels: FixedChoiceBranchLabels = .init(),
        iterationMarkers: FixedIterationMarkers = .init(),
        autonomyMarkers: FixedAutonomyMarkers = .init(),
        lintMarkers: FixedLintMarkers = .init(),
        implicitParamFillConnector: String = " for the ",
        negationWrapperPrefix: String = "not (",
        negationWrapperSuffix: String = ")",
        definitionPrefix: String = "definition:",
        definitionIfMarker: String = " if ",
        definitionPossessivePronoun: String = "its",
        definitionSubjectPronoun: String = "it",
        legacyImportVocabularyPrefix: String = "import vocabulary from ",
        legacyImportPrefix: String = "import ",
        topLevelRulePrefix: String = "when ",
        informRulePhasePrefixes: [String] = [
            "before ", "instead of ", "check ", "carry out ", "after ", "report ",
        ],
        informStopOutcome: String = "stop",
        informSuccessOutcome: String = "success",
        informFailureOutcome: String = "fail",
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
        domainCanBeMarker: String = " can be ",
        domainUsuallyMarker: String = " is usually ",
        emittedInvariantPrefixes: [String] = ["every emitted ", "each emitted "],
        judgmentIntroducers: [String] = ["use judgment to ", "use judgement to ", "use your judgment to "],
        judgmentFollowCollectPrefix: String = "use judgment to follow the ",
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
        self.statement = statement
        self.quantifierDeterminers = quantifierDeterminers
        self.booleanConnectors = booleanConnectors
        self.ruleMarkers = ruleMarkers
        self.merconfig = merconfig
        self.tableLookup = tableLookup
        self.templateDirectives = templateDirectives
        self.choiceBranchLabels = choiceBranchLabels
        self.iterationMarkers = iterationMarkers
        self.autonomyMarkers = autonomyMarkers
        self.lintMarkers = lintMarkers
        self.implicitParamFillConnector = implicitParamFillConnector
        self.negationWrapperPrefix = negationWrapperPrefix
        self.negationWrapperSuffix = negationWrapperSuffix
        self.definitionPrefix = definitionPrefix
        self.definitionIfMarker = definitionIfMarker
        self.definitionPossessivePronoun = definitionPossessivePronoun
        self.definitionSubjectPronoun = definitionSubjectPronoun
        self.legacyImportVocabularyPrefix = legacyImportVocabularyPrefix
        self.legacyImportPrefix = legacyImportPrefix
        self.topLevelRulePrefix = topLevelRulePrefix
        self.informRulePhasePrefixes = informRulePhasePrefixes
        self.informStopOutcome = informStopOutcome
        self.informSuccessOutcome = informSuccessOutcome
        self.informFailureOutcome = informFailureOutcome
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
        self.domainCanBeMarker = domainCanBeMarker
        self.domainUsuallyMarker = domainUsuallyMarker
        self.emittedInvariantPrefixes = emittedInvariantPrefixes
        self.judgmentIntroducers = judgmentIntroducers
        self.judgmentFollowCollectPrefix = judgmentFollowCollectPrefix
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
