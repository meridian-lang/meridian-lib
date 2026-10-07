import Foundation
import MeridianRuntime

// MARK: - MerConfig AST

/// Language-surface synonyms loaded from a `=== language ===` section in a
/// .merconfig file. Merged into the effective `EnglishLexicon` at compile time.
public struct LanguageSynonyms: Sendable {
    public let comparisonSynonyms: [(String, ComparisonOpAST)]
    public let durationSynonyms: [String: TimeUnitAST]
    /// Extra leading keywords that introduce an invariant/assertion statement
    /// (`=== language ===` `Assertion synonyms:` block). Merged ahead of the
    /// lexicon defaults (`make sure` / `ensure` / `assert`).
    public let assertionSynonyms: [String]
    /// Extra operational/normative cue words (`=== language ===`
    /// `Normative-cue synonyms:` block) — see `EnglishLexicon.normativeCueWords`.
    public let normativeCueSynonyms: [String]
    /// Extra AI-inference cue words (`=== language ===` `Inference-cue
    /// synonyms:` block) — see `EnglishLexicon.inferenceCueWords`.
    public let inferenceCueSynonyms: [String]
    /// Extra documentary heading/body words (`=== language ===`
    /// `Reference-heading synonyms:` block) — see
    /// `EnglishLexicon.referenceHeadingWords`.
    public let referenceHeadingSynonyms: [String]
    /// Extra vague condition hedges (`=== language ===` `Vague-hedge synonyms:`).
    public let conditionVagueHedgeSynonyms: [String]
    /// Extra effectful-judgment goal cues (`=== language ===`
    /// `Effectful-judgment synonyms:`).
    public let effectfulJudgmentCueSynonyms: [String]
    /// Extra definite/indefinite articles (`=== language ===` `Article synonyms:`).
    public let articleSynonyms: [String]
    /// Extra parameter-slot articles (`=== language ===`
    /// `Parameter-article synonyms:`).
    public let parameterArticleSynonyms: [String]
    /// Extra preposition stop-words (`=== language ===` `Preposition synonyms:`).
    public let prepositionSynonyms: [String]
    /// Extra copula connectors (`=== language ===` `Copula synonyms:`).
    public let copulaSynonyms: [String]
    /// Extra past-participle stop signals (`=== language ===` `Participle synonyms:`).
    public let participleSynonyms: [String]
    /// Extra tool-resolution stop-words (`=== language ===`
    /// `Tool-stopword synonyms:`).
    public let toolStopwordSynonyms: [String]
    /// Irregular plural overrides (`=== language ===` `Irregular-plural mapping:`).
    public let irregularPluralSynonyms: [String: String]
    /// Documentary contract-guard body phrases (`=== language ===`
    /// `Contract-reference synonyms:`) — see `EnglishLexicon.contractReferencePhrases`.
    public let contractReferenceSynonyms: [String]
    /// Optional override for the temporal-iteration timestamp property
    /// (`=== language ===` `timestamp:` entry). `nil` keeps the lexicon default.
    public let timestampProperty: String?
    // 3B author-extensible category synonyms (each a `=== language ===` block).
    public let emptySynonyms: [String]
    public let filledSynonyms: [String]
    public let pastWindowSynonyms: [String]
    public let futureWindowSynonyms: [String]
    public let timestampAliasSynonyms: [String]
    public let aggregateSynonyms: [(String, AggregateKindAST)]
    public let superlativeSynonyms: [String: SuperlativeDirection]
    /// Measurable backing for checkable adjectives (`Gradable adjectives:` block).
    public let gradableAdjectiveSynonyms: [String: GradableAdjectiveMetadata]
    public let sortBySynonyms: [String]
    public let ascendingSynonyms: [String]
    public let descendingSynonyms: [String]
    public let possessiveSynonyms: [String]
    public let anaphoraSynonyms: [String]
    public let conditionHeaderSynonyms: [String]
    public let actionHeaderSynonyms: [String]
    public let wildcardSynonyms: [String]
    /// Outcome verb synonyms for trace event patterns (`foo = failed`).
    public let traceOutcomeSynonyms: [String: String]
    /// Extra perfect/passive auxiliary tokens a trace event-pattern subject may
    /// carry ahead of its outcome verb (`=== language ===` `Trace-auxiliary
    /// synonyms:`) — see `EnglishLexicon.tracePerfectAuxiliaries`.
    public let traceAuxiliarySynonyms: [String]
    /// Extra fence info-string tags treated as shell-command blocks
    /// (`=== language ===` `Shell fence synonyms:` — e.g. `fish`, `pwsh`, `nu`).
    public let shellFenceSynonyms: [String]
    /// Non-shell fence info-string tag → tool ID (`=== language ===` `Fence
    /// tool mapping:` — e.g. `python = interpreter.run`). Lets a non-shell
    /// skill repo lower a fenced code block deterministically to a configured
    /// tool instead of falling to inert or AI dispatch. See
    /// `EnglishLexicon.fenceToolMapping`.
    public let fenceToolMapping: [String: String]
    /// Extra guarded-fence trailing markers (`=== language ===`
    /// `Guarded-fence synonyms:`).
    public let guardedFenceIntroducerSynonyms: [String]
    /// Extra fallback-chain lead-ins (`=== language ===`
    /// `Fallback-chain synonyms:`).
    public let fallbackChainIntroducerSynonyms: [String]
    /// Extra approval-tool ID substrings (`=== language ===`
    /// `Approval-tool synonyms:`).
    public let approvalToolSynonyms: [String]
    public init(comparisonSynonyms: [(String, ComparisonOpAST)] = [],
                durationSynonyms: [String: TimeUnitAST] = [:],
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
                fenceToolMapping: [String: String] = [:],
                guardedFenceIntroducerSynonyms: [String] = [],
                fallbackChainIntroducerSynonyms: [String] = [],
                approvalToolSynonyms: [String] = []) {
        self.comparisonSynonyms = comparisonSynonyms
        self.durationSynonyms = durationSynonyms
        self.assertionSynonyms = assertionSynonyms
        self.normativeCueSynonyms = normativeCueSynonyms
        self.inferenceCueSynonyms = inferenceCueSynonyms
        self.referenceHeadingSynonyms = referenceHeadingSynonyms
        self.conditionVagueHedgeSynonyms = conditionVagueHedgeSynonyms
        self.effectfulJudgmentCueSynonyms = effectfulJudgmentCueSynonyms
        self.articleSynonyms = articleSynonyms
        self.parameterArticleSynonyms = parameterArticleSynonyms
        self.prepositionSynonyms = prepositionSynonyms
        self.copulaSynonyms = copulaSynonyms
        self.participleSynonyms = participleSynonyms
        self.toolStopwordSynonyms = toolStopwordSynonyms
        self.irregularPluralSynonyms = irregularPluralSynonyms
        self.contractReferenceSynonyms = contractReferenceSynonyms
        self.timestampProperty = timestampProperty
        self.emptySynonyms = emptySynonyms
        self.filledSynonyms = filledSynonyms
        self.pastWindowSynonyms = pastWindowSynonyms
        self.futureWindowSynonyms = futureWindowSynonyms
        self.timestampAliasSynonyms = timestampAliasSynonyms
        self.aggregateSynonyms = aggregateSynonyms
        self.superlativeSynonyms = superlativeSynonyms
        self.gradableAdjectiveSynonyms = gradableAdjectiveSynonyms
        self.sortBySynonyms = sortBySynonyms
        self.ascendingSynonyms = ascendingSynonyms
        self.descendingSynonyms = descendingSynonyms
        self.possessiveSynonyms = possessiveSynonyms
        self.anaphoraSynonyms = anaphoraSynonyms
        self.conditionHeaderSynonyms = conditionHeaderSynonyms
        self.actionHeaderSynonyms = actionHeaderSynonyms
        self.wildcardSynonyms = wildcardSynonyms
        self.traceOutcomeSynonyms = traceOutcomeSynonyms
        self.traceAuxiliarySynonyms = traceAuxiliarySynonyms
        self.shellFenceSynonyms = shellFenceSynonyms
        self.fenceToolMapping = fenceToolMapping
        self.guardedFenceIntroducerSynonyms = guardedFenceIntroducerSynonyms
        self.fallbackChainIntroducerSynonyms = fallbackChainIntroducerSynonyms
        self.approvalToolSynonyms = approvalToolSynonyms
    }
}

public struct TraceConfigValue<T: Sendable & Equatable>: Sendable, Equatable {
    public let value: T
    public let file: String
    public let line: Int

    public init(_ value: T, file: String, line: Int) {
        self.value = value
        self.file = file
        self.line = line
    }
}

public struct TraceConfigurationAST: Sendable, Equatable {
    public let store: TraceConfigValue<TraceStoreKind>?
    public let retention: TraceConfigValue<Duration>?
    public let payloadLimit: TraceConfigValue<Int>?
    public let usuallyThreshold: TraceConfigValue<Double>?
    public let rarelyThreshold: TraceConfigValue<Double>?
    public let sampleFloor: TraceConfigValue<Int>?
    public let defaultMonitorCadence: TraceConfigValue<Duration>?
    public let profile: TraceConfigValue<TraceProfile>?
    public let storeFailurePolicy: TraceConfigValue<TraceStoreFailurePolicy>?
    public let deploymentZone: TraceConfigValue<String>?
    public let crossSkillAllowList: TraceConfigValue<[String]>?
    public let stateHistoryRetention: TraceConfigValue<Bool>?
    public let storePath: TraceConfigValue<String>?
    public let toolCapturePolicies: [String: TraceConfigValue<TraceCapturePolicy>]

    public init(
        store: TraceConfigValue<TraceStoreKind>? = nil,
        retention: TraceConfigValue<Duration>? = nil,
        payloadLimit: TraceConfigValue<Int>? = nil,
        usuallyThreshold: TraceConfigValue<Double>? = nil,
        rarelyThreshold: TraceConfigValue<Double>? = nil,
        sampleFloor: TraceConfigValue<Int>? = nil,
        defaultMonitorCadence: TraceConfigValue<Duration>? = nil,
        profile: TraceConfigValue<TraceProfile>? = nil,
        storeFailurePolicy: TraceConfigValue<TraceStoreFailurePolicy>? = nil,
        deploymentZone: TraceConfigValue<String>? = nil,
        crossSkillAllowList: TraceConfigValue<[String]>? = nil,
        stateHistoryRetention: TraceConfigValue<Bool>? = nil,
        storePath: TraceConfigValue<String>? = nil,
        toolCapturePolicies: [String: TraceConfigValue<TraceCapturePolicy>] = [:]
    ) {
        self.store = store
        self.retention = retention
        self.payloadLimit = payloadLimit
        self.usuallyThreshold = usuallyThreshold
        self.rarelyThreshold = rarelyThreshold
        self.sampleFloor = sampleFloor
        self.defaultMonitorCadence = defaultMonitorCadence
        self.profile = profile
        self.storeFailurePolicy = storeFailurePolicy
        self.deploymentZone = deploymentZone
        self.crossSkillAllowList = crossSkillAllowList
        self.stateHistoryRetention = stateHistoryRetention
        self.storePath = storePath
        self.toolCapturePolicies = toolCapturePolicies
    }
}

public struct MerConfigFile: Sendable {
    public let vocabulary: [VocabularyStatement]
    public let constants: [ConstantDeclaration]
    public let instances: [InstanceDeclaration]
    public let tools: [ToolDeclaration]
    public let languageSynonyms: LanguageSynonyms
    public let traceConfiguration: TraceConfigurationAST
    /// `=== imports ===` lines (`import <module> [as <alias>]`).
    public let imports: [ModuleImportLine]

    public init(
        vocabulary: [VocabularyStatement] = [],
        constants: [ConstantDeclaration] = [],
        instances: [InstanceDeclaration] = [],
        tools: [ToolDeclaration] = [],
        languageSynonyms: LanguageSynonyms = LanguageSynonyms(),
        traceConfiguration: TraceConfigurationAST = TraceConfigurationAST(),
        imports: [ModuleImportLine] = []
    ) {
        self.vocabulary = vocabulary
        self.constants = constants
        self.instances = instances
        self.tools = tools
        self.languageSynonyms = languageSynonyms
        self.traceConfiguration = traceConfiguration
        self.imports = imports
    }

    /// Concatenate two parsed merconfig files, preserving declaration order
    /// (left-hand sections first). Duplicate-name detection is the caller's
    /// job — `Compiler.merge` walks the merged symbol table and rejects
    /// colliding kind / phrase / tool names with a sourced error.
    public func merging(_ other: MerConfigFile) throws -> MerConfigFile {
        let mergedSynonyms = LanguageSynonyms(
            comparisonSynonyms: languageSynonyms.comparisonSynonyms + other.languageSynonyms.comparisonSynonyms,
            durationSynonyms: languageSynonyms.durationSynonyms.merging(other.languageSynonyms.durationSynonyms) { _, new in new },
            assertionSynonyms: languageSynonyms.assertionSynonyms + other.languageSynonyms.assertionSynonyms,
            normativeCueSynonyms: languageSynonyms.normativeCueSynonyms + other.languageSynonyms.normativeCueSynonyms,
            inferenceCueSynonyms: languageSynonyms.inferenceCueSynonyms + other.languageSynonyms.inferenceCueSynonyms,
            referenceHeadingSynonyms: languageSynonyms.referenceHeadingSynonyms + other.languageSynonyms.referenceHeadingSynonyms,
            conditionVagueHedgeSynonyms: languageSynonyms.conditionVagueHedgeSynonyms + other.languageSynonyms.conditionVagueHedgeSynonyms,
            effectfulJudgmentCueSynonyms: languageSynonyms.effectfulJudgmentCueSynonyms + other.languageSynonyms.effectfulJudgmentCueSynonyms,
            articleSynonyms: languageSynonyms.articleSynonyms + other.languageSynonyms.articleSynonyms,
            parameterArticleSynonyms: languageSynonyms.parameterArticleSynonyms + other.languageSynonyms.parameterArticleSynonyms,
            prepositionSynonyms: languageSynonyms.prepositionSynonyms + other.languageSynonyms.prepositionSynonyms,
            copulaSynonyms: languageSynonyms.copulaSynonyms + other.languageSynonyms.copulaSynonyms,
            participleSynonyms: languageSynonyms.participleSynonyms + other.languageSynonyms.participleSynonyms,
            toolStopwordSynonyms: languageSynonyms.toolStopwordSynonyms + other.languageSynonyms.toolStopwordSynonyms,
            irregularPluralSynonyms: languageSynonyms.irregularPluralSynonyms.merging(other.languageSynonyms.irregularPluralSynonyms) { _, new in new },
            contractReferenceSynonyms: languageSynonyms.contractReferenceSynonyms + other.languageSynonyms.contractReferenceSynonyms,
            timestampProperty: other.languageSynonyms.timestampProperty ?? languageSynonyms.timestampProperty,
            emptySynonyms: languageSynonyms.emptySynonyms + other.languageSynonyms.emptySynonyms,
            filledSynonyms: languageSynonyms.filledSynonyms + other.languageSynonyms.filledSynonyms,
            pastWindowSynonyms: languageSynonyms.pastWindowSynonyms + other.languageSynonyms.pastWindowSynonyms,
            futureWindowSynonyms: languageSynonyms.futureWindowSynonyms + other.languageSynonyms.futureWindowSynonyms,
            timestampAliasSynonyms: languageSynonyms.timestampAliasSynonyms + other.languageSynonyms.timestampAliasSynonyms,
            aggregateSynonyms: languageSynonyms.aggregateSynonyms + other.languageSynonyms.aggregateSynonyms,
            superlativeSynonyms: languageSynonyms.superlativeSynonyms.merging(other.languageSynonyms.superlativeSynonyms) { _, new in new },
            gradableAdjectiveSynonyms: languageSynonyms.gradableAdjectiveSynonyms.merging(other.languageSynonyms.gradableAdjectiveSynonyms) { _, new in new },
            sortBySynonyms: languageSynonyms.sortBySynonyms + other.languageSynonyms.sortBySynonyms,
            ascendingSynonyms: languageSynonyms.ascendingSynonyms + other.languageSynonyms.ascendingSynonyms,
            descendingSynonyms: languageSynonyms.descendingSynonyms + other.languageSynonyms.descendingSynonyms,
            possessiveSynonyms: languageSynonyms.possessiveSynonyms + other.languageSynonyms.possessiveSynonyms,
            anaphoraSynonyms: languageSynonyms.anaphoraSynonyms + other.languageSynonyms.anaphoraSynonyms,
            conditionHeaderSynonyms: languageSynonyms.conditionHeaderSynonyms + other.languageSynonyms.conditionHeaderSynonyms,
            actionHeaderSynonyms: languageSynonyms.actionHeaderSynonyms + other.languageSynonyms.actionHeaderSynonyms,
            wildcardSynonyms: languageSynonyms.wildcardSynonyms + other.languageSynonyms.wildcardSynonyms,
            traceOutcomeSynonyms: languageSynonyms.traceOutcomeSynonyms.merging(other.languageSynonyms.traceOutcomeSynonyms) { _, new in new },
            traceAuxiliarySynonyms: languageSynonyms.traceAuxiliarySynonyms + other.languageSynonyms.traceAuxiliarySynonyms,
            shellFenceSynonyms: languageSynonyms.shellFenceSynonyms + other.languageSynonyms.shellFenceSynonyms,
            fenceToolMapping: languageSynonyms.fenceToolMapping.merging(other.languageSynonyms.fenceToolMapping) { _, new in new },
            guardedFenceIntroducerSynonyms: languageSynonyms.guardedFenceIntroducerSynonyms + other.languageSynonyms.guardedFenceIntroducerSynonyms,
            fallbackChainIntroducerSynonyms: languageSynonyms.fallbackChainIntroducerSynonyms + other.languageSynonyms.fallbackChainIntroducerSynonyms,
            approvalToolSynonyms: languageSynonyms.approvalToolSynonyms + other.languageSynonyms.approvalToolSynonyms
        )
        return MerConfigFile(
            vocabulary: vocabulary + other.vocabulary,
            constants:  constants  + other.constants,
            instances:  instances  + other.instances,
            tools: try mergeTools(with: other.tools),
            languageSynonyms: mergedSynonyms,
            traceConfiguration: try traceConfiguration.merging(other.traceConfiguration),
            imports: imports + other.imports
        )
    }

    private func mergeTools(with otherTools: [ToolDeclaration]) throws -> [ToolDeclaration] {
        var merged = tools
        var indexByID = Dictionary(uniqueKeysWithValues: merged.enumerated().map { ($0.element.methodName, $0.offset) })
        for tool in otherTools {
            guard let existingIndex = indexByID[tool.methodName] else {
                indexByID[tool.methodName] = merged.count
                merged.append(tool)
                continue
            }
            let existing = merged[existingIndex]
            guard existing.isEquivalent(to: tool) else {
                throw MerConfigMergeError.conflictingToolDeclaration(
                    toolID: tool.methodName,
                    leftFile: existing.sourceFile,
                    rightFile: tool.sourceFile
                )
            }
            merged[existingIndex] = existing.mergingCapture(from: tool)
        }
        return merged
    }
}

public enum MerConfigMergeError: Error, Sendable, Equatable, CustomStringConvertible {
    case conflictingTraceSetting(key: String, leftFile: String, rightFile: String)
    case conflictingToolCapture(toolID: String, leftFile: String, rightFile: String)
    case conflictingToolDeclaration(toolID: String, leftFile: String, rightFile: String)

    public var description: String {
        switch self {
        case .conflictingTraceSetting(let key, let leftFile, let rightFile):
            return "conflicting trace setting `\(key)` in \(leftFile) and \(rightFile)"
        case .conflictingToolCapture(let toolID, let leftFile, let rightFile):
            return "conflicting trace capture policy for tool `\(toolID)` in \(leftFile) and \(rightFile)"
        case .conflictingToolDeclaration(let toolID, let leftFile, let rightFile):
            return "conflicting tool declaration `\(toolID)` in \(leftFile) and \(rightFile)"
        }
    }
}

public extension TraceConfigurationAST {
    func merging(_ other: TraceConfigurationAST) throws -> TraceConfigurationAST {
        try TraceConfigurationAST(
            store: mergeValue(store, other.store, key: "store"),
            retention: mergeValue(retention, other.retention, key: "retention"),
            payloadLimit: mergeValue(payloadLimit, other.payloadLimit, key: "payload limit"),
            usuallyThreshold: mergeValue(usuallyThreshold, other.usuallyThreshold, key: "usually at least"),
            rarelyThreshold: mergeValue(rarelyThreshold, other.rarelyThreshold, key: "rarely at most"),
            sampleFloor: mergeValue(sampleFloor, other.sampleFloor, key: "sample floor"),
            defaultMonitorCadence: mergeValue(defaultMonitorCadence, other.defaultMonitorCadence, key: "default monitor cadence"),
            profile: mergeValue(profile, other.profile, key: "profile"),
            storeFailurePolicy: mergeValue(storeFailurePolicy, other.storeFailurePolicy, key: "store failure policy"),
            deploymentZone: mergeValue(deploymentZone, other.deploymentZone, key: "deployment zone"),
            crossSkillAllowList: mergeValue(crossSkillAllowList, other.crossSkillAllowList, key: "cross-skill allow-list"),
            stateHistoryRetention: mergeValue(stateHistoryRetention, other.stateHistoryRetention, key: "state history"),
            storePath: mergeValue(storePath, other.storePath, key: "store path"),
            toolCapturePolicies: try mergeToolCapturePolicies(other.toolCapturePolicies)
        )
    }

    private func mergeToolCapturePolicies(
        _ other: [String: TraceConfigValue<TraceCapturePolicy>]
    ) throws -> [String: TraceConfigValue<TraceCapturePolicy>] {
        var merged = toolCapturePolicies
        for (toolID, rhs) in other {
            guard let lhs = merged[toolID] else {
                merged[toolID] = rhs
                continue
            }
            if lhs.value != rhs.value {
                throw MerConfigMergeError.conflictingToolCapture(
                    toolID: toolID,
                    leftFile: lhs.file,
                    rightFile: rhs.file
                )
            }
        }
        return merged
    }

    private func mergeValue<T: Sendable & Equatable>(
        _ lhs: TraceConfigValue<T>?,
        _ rhs: TraceConfigValue<T>?,
        key: String
    ) throws -> TraceConfigValue<T>? {
        switch (lhs, rhs) {
        case (.none, .none): return nil
        case (.some(let value), .none), (.none, .some(let value)): return value
        case (.some(let left), .some(let right)):
            guard left.value == right.value else {
                throw MerConfigMergeError.conflictingTraceSetting(
                    key: key,
                    leftFile: left.file,
                    rightFile: right.file
                )
            }
            return left
        }
    }
}

public enum VocabularyStatement: Sendable {
    case kind(KindDeclaration)
    case property(PropertyDeclaration)
    case key(KeyDeclaration)
    case relation(RelationDeclaration)
    case inverse(InverseDeclaration)
    case phrase(PhraseDefinition)
    /// 2B: `Definition: a page is stale if <condition>.` — a checkable
    /// adjective declared in the merconfig vocabulary.
    case definition(DefinitionDeclaration)
    /// 3A: `<Relation> is read from the <kind>'s <prop>.` / `… is read via the
    /// <tool>.` — the evaluation backing of a previously-declared relation.
    case relationBacking(RelationBackingDeclaration)
    /// 3B: `The verb to own (he owns, it is owned) means the ownership relation.`
    case verb(VerbDeclaration)
}

/// 2B: A checkable adjective definition (`Definition: a <kind> is <adjective>
/// if <condition>.`). The `body` condition is parsed with `it`/`its`
/// preprocessed to the subject, so it reads as a predicate over `subjectVar`
/// (the singular kind name). Lowered to a file-scope `private func
/// meridianDef_<Kind>_<adjCamel>(_ subject: Value?) -> Bool` helper.
public struct DefinitionDeclaration: Sendable {
    /// Normalised surface adjective (lowercased, hyphens→spaces). Globally
    /// unique across all definitions — a collision is a hard error.
    public let adjective: String
    /// The kind this adjective applies to (singular, e.g. "page").
    public let kind: String
    /// The subject variable the body is expressed over (the singular kind name).
    public let subjectVar: String
    public let body: ExpressionAST
    public let sourceLine: Int
    public init(adjective: String, kind: String, subjectVar: String,
                body: ExpressionAST, sourceLine: Int = 0) {
        self.adjective = adjective; self.kind = kind
        self.subjectVar = subjectVar; self.body = body
        self.sourceLine = sourceLine
    }
}

public struct KindDeclaration: Sendable {
    public let name: String
    public let parent: String
    public let sourceLine: Int
    public init(name: String, parent: String, sourceLine: Int = 0) {
        self.name = name; self.parent = parent; self.sourceLine = sourceLine
    }
}

public struct KeyDeclaration: Sendable {
    public let kind: String
    public let property: String
    public let sourceLine: Int
    public init(kind: String, property: String, sourceLine: Int = 0) {
        self.kind = kind
        self.property = property
        self.sourceLine = sourceLine
    }
}

public struct PropertyDeclaration: Sendable {
    public let kind: String
    public let properties: [PropertyEntry]
    public let sourceLine: Int
    public init(kind: String, properties: [PropertyEntry], sourceLine: Int = 0) {
        self.kind = kind; self.properties = properties; self.sourceLine = sourceLine
    }
}

public struct PropertyEntry: Sendable {
    public let name: String
    public let type: PropertyTypeAST
    public init(name: String, type: PropertyTypeAST) { self.name = name; self.type = type }
}

public indirect enum PropertyTypeAST: Sendable {
    case defaulted
    case explicit(String)
    case listOf(PropertyTypeAST)
    case optional(PropertyTypeAST)
    case enumeration(cases: [String], defaultCase: String?)
}

public struct RelationDeclaration: Sendable {
    /// The relation name as written (`Ownership`, `Mentioning`), lowercased.
    public let verb: String
    public let leftCardinality: CardinalityAST
    public let leftKind: String
    public let rightCardinality: CardinalityAST
    public let rightKind: String
    public let sourceLine: Int
    public init(verb: String, leftCardinality: CardinalityAST, leftKind: String,
                rightCardinality: CardinalityAST, rightKind: String, sourceLine: Int = 0) {
        self.verb = verb; self.leftCardinality = leftCardinality; self.leftKind = leftKind
        self.rightCardinality = rightCardinality; self.rightKind = rightKind
        self.sourceLine = sourceLine
    }
}

/// 3A: how a relation is evaluated. Backing is mandatory — an unbacked relation
/// is a compile error (relations must be witnessable, not a hidden datastore).
public enum RelationBackingAST: Sendable, Equatable {
    /// `Ownership is read from the page's owner.` — the link lives at
    /// `<kind>.<path>` (the `kind` is one side of the relation; `path` holds the
    /// related entity / its id).
    case property(kind: String, path: String)
    /// `Mentioning is read via the link tool.` — the related collection is
    /// produced by invoking `toolID` once with the fixed operand.
    case tool(toolID: String)
}

/// 3A: `<Relation> is read from the <kind>'s <prop>.` / `… is read via the
/// <tool>.`. Pairs a relation name with its evaluation backing.
public struct RelationBackingDeclaration: Sendable {
    public let relation: String
    public let backing: RelationBackingAST
    public let sourceLine: Int
    public init(relation: String, backing: RelationBackingAST, sourceLine: Int = 0) {
        self.relation = relation; self.backing = backing; self.sourceLine = sourceLine
    }
}

/// 3B: a verb bound to a relation, with its conjugation table.
/// `The verb to own (he owns, it is owned) means the ownership relation.`
public struct VerbDeclaration: Sendable {
    public let base: String            // "own"
    public let thirdPerson: String     // "owns"
    public let pastParticiple: String  // "owned"
    public let relation: String        // "ownership" (lowercased relation name)
    public let sourceLine: Int
    public init(base: String, thirdPerson: String, pastParticiple: String,
                relation: String, sourceLine: Int = 0) {
        self.base = base; self.thirdPerson = thirdPerson
        self.pastParticiple = pastParticiple; self.relation = relation
        self.sourceLine = sourceLine
    }
}

public enum CardinalityAST: Sendable { case one, many }

public struct InverseDeclaration: Sendable {
    public let forwardGerund: String
    public let inverseGerund: String
    public let sourceLine: Int
    public init(forwardGerund: String, inverseGerund: String, sourceLine: Int = 0) {
        self.forwardGerund = forwardGerund; self.inverseGerund = inverseGerund
        self.sourceLine = sourceLine
    }
}

// MARK: - Phrase patterns

public struct PhraseDefinition: Sendable {
    public let pattern: PhrasePattern
    public let body: ASTBlock
    public let sourceLine: Int
    public let sourceFile: String
    /// When non-nil, this phrase is a *workflow stub* registered for recursive
    /// invocation. The body is empty; lowering emits a workflow call instead
    /// of inlining. Value is the Swift struct name (e.g. "ProcessOrder").
    public let workflowStructName: String?
    public init(pattern: PhrasePattern,
                body: ASTBlock,
                sourceLine: Int = 0,
                sourceFile: String = "",
                workflowStructName: String? = nil) {
        self.pattern = pattern; self.body = body
        self.sourceLine = sourceLine; self.sourceFile = sourceFile
        self.workflowStructName = workflowStructName
    }
}

public struct PhrasePattern: Sendable {
    public let segments: [PatternSegment]
    public init(segments: [PatternSegment]) { self.segments = segments }

    public var parameters: [PhraseParameterAST] {
        segments.compactMap { if case .parameter(let p) = $0 { return p } else { return nil } }
    }

    public var displayText: String {
        segments.map {
            switch $0 {
            case .literal(let s): return s
            case .parameter(let p): return "a \(p.kind)"
            }
        }.joined(separator: " ")
    }
}

public enum PatternSegment: Sendable {
    case literal(String)
    case parameter(PhraseParameterAST)
}

public struct PhraseParameterAST: Sendable {
    public let name: String
    public let kind: String
    public init(name: String, kind: String) { self.name = name; self.kind = kind }
}

// MARK: - Constants, instances, tools

public struct ConstantDeclaration: Sendable {
    public let name: String
    public let value: LiteralAST
    public let sourceLine: Int
    public init(name: String, value: LiteralAST, sourceLine: Int = 0) {
        self.name = name; self.value = value; self.sourceLine = sourceLine
    }
}

public struct InstanceDeclaration: Sendable {
    public let kind: String
    public let name: String
    public let properties: [(String, PropertyValueAST)]
    public let sourceLine: Int
    public init(kind: String, name: String, properties: [(String, PropertyValueAST)] = [], sourceLine: Int = 0) {
        self.kind = kind; self.name = name
        self.properties = properties; self.sourceLine = sourceLine
    }
}

public enum PropertyValueAST: Sendable {
    case literal(LiteralAST)
    case envVar(String)
}

public struct ToolDeclaration: Sendable, Equatable {
    public let displayName: String
    public let methodName: String
    public let parameters: [ToolParameterAST]
    public let returnType: String
    public let sourceLine: Int
    public let sourceFile: String
    public let capturePolicy: TraceCapturePolicy?
    public init(displayName: String, methodName: String,
                parameters: [ToolParameterAST], returnType: String, sourceLine: Int = 0,
                sourceFile: String = "", capturePolicy: TraceCapturePolicy? = nil) {
        self.displayName = displayName; self.methodName = methodName
        self.parameters = parameters; self.returnType = returnType
        self.sourceLine = sourceLine
        self.sourceFile = sourceFile
        self.capturePolicy = capturePolicy
    }

    func isEquivalent(to other: ToolDeclaration) -> Bool {
        displayName == other.displayName &&
        methodName == other.methodName &&
        parameters == other.parameters &&
        returnType == other.returnType
    }

    func mergingCapture(from other: ToolDeclaration) -> ToolDeclaration {
        ToolDeclaration(
            displayName: displayName,
            methodName: methodName,
            parameters: parameters,
            returnType: returnType,
            sourceLine: sourceLine,
            sourceFile: sourceFile,
            capturePolicy: capturePolicy ?? other.capturePolicy
        )
    }
}

public struct ToolParameterAST: Sendable, Equatable {
    public let name: String
    public let type: String
    public init(name: String, type: String) { self.name = name; self.type = type }
}

// MARK: - Meridian file AST

/// Key-value metadata from the optional `---`-delimited frontmatter block
/// at the top of a `.meridian` file (B1 / skill-discovery metadata).
public struct FileMetadataAST: Sendable {
    public let entries: [(key: String, value: String)]
    public let sourceLine: Int
    public init(entries: [(key: String, value: String)], sourceLine: Int = 0) {
        self.entries = entries
        self.sourceLine = sourceLine
    }
    public subscript(_ key: String) -> String? {
        entries.first(where: { $0.key.lowercased() == key.lowercased() })?.value
    }
}

public struct HeadingEntry: Sendable {
    public let level: Int
    public let text: String
    public let line: Int
    public let kind: String

    public init(level: Int, text: String, line: Int, kind: String = "heading") {
        self.level = level
        self.text = text
        self.line = line
        self.kind = kind
    }
}

/// A single markdown section from a sectioned (heading-bearing) document,
/// recorded for the manifest. Every section — executable and non-executable —
/// is captured, so nothing in the source is silently dropped.
public struct SkillSectionRecord: Sendable {
    public let heading: String
    /// Resolved/forced role string (`invariants`, `procedure`, `template`, …)
    /// or `"inert"` for an `(( inert ))` heading with no role. Never derived
    /// from the heading text for non-executable sections.
    public let role: String
    public let executes: Bool
    /// Verbatim statement text of the section's content lines.
    public let lines: [String]
    public let line: Int
    public init(heading: String, role: String, executes: Bool, lines: [String], line: Int) {
        self.heading = heading
        self.role = role
        self.executes = executes
        self.lines = lines
        self.line = line
    }
}

public struct MeridianFile: Sendable {
    public let imports: [ImportStatementAST]
    public let rules: [RuleAST]
    public let workflows: [WorkflowAST]
    /// Optional frontmatter parsed from a `---`-delimited block at the top
    /// of the file. Nil when no frontmatter is present.
    public let metadata: FileMetadataAST?
    public let outline: [HeadingEntry]
    /// Every markdown section recorded by `SkillSectionBuilder` (empty for
    /// non-sectioned files). Mandatory carrier for the manifest — never `nil`.
    public let skillSections: [SkillSectionRecord]
    /// Literal applicability dispatch phrases mined from `When To Use`
    /// sections (for the resolver). Empty for non-sectioned files.
    public let dispatchPhrases: [String]
    public let negativeDispatchPhrases: [String]
    /// Tool IDs mined from a `## Tools Used` section (1D). Merged into the
    /// workflow's `scopedTools` and the manifest `tools_used`. Empty otherwise.
    public let toolsUsed: [String]
    /// 2B: Top-level `Definition:` lines pulled out of the implicit body. These
    /// are registered into the symbol table before workflow lowering so an
    /// adjective resolves regardless of source order.
    public let definitions: [DefinitionDeclaration]
    public init(imports: [ImportStatementAST] = [],
                rules: [RuleAST] = [],
                workflows: [WorkflowAST] = [],
                metadata: FileMetadataAST? = nil,
                outline: [HeadingEntry] = [],
                skillSections: [SkillSectionRecord] = [],
                dispatchPhrases: [String] = [],
                negativeDispatchPhrases: [String] = [],
                toolsUsed: [String] = [],
                definitions: [DefinitionDeclaration] = []) {
        self.imports = imports; self.rules = rules; self.workflows = workflows
        self.metadata = metadata
        self.outline = outline
        self.skillSections = skillSections
        self.dispatchPhrases = dispatchPhrases
        self.negativeDispatchPhrases = negativeDispatchPhrases
        self.toolsUsed = toolsUsed
        self.definitions = definitions
    }
}

public enum ImportKind: Sendable, Equatable {
    /// Legacy frontmatter `vocabulary:` merconfig reference.
    case vocabulary
    /// Shared module package (`import <module> [as <alias>]`).
    case module
}

public struct ImportStatementAST: Sendable {
    public let path: String
    public let alias: String?
    public let kind: ImportKind
    public let sourceLine: Int
    public init(path: String, alias: String? = nil, kind: ImportKind = .vocabulary, sourceLine: Int = 0) {
        self.path = path
        self.alias = alias
        self.kind = kind
        self.sourceLine = sourceLine
    }
}

public struct RuleAST: Sendable {
    public let text: String
    public let sourceLine: Int
    public init(text: String, sourceLine: Int = 0) { self.text = text; self.sourceLine = sourceLine }
}

public struct WorkflowAST: Sendable {
    public let pattern: PhrasePattern
    public let body: ASTBlock
    public let sourceLine: Int
    public let sourceFile: String
    /// When true, the workflow header contained `, with discretion` — enables
    /// `decide whether …` expressions inside the body (B3).
    public let allowsDiscretion: Bool
    public let autonomy: AutonomyConfigAST?
    public init(pattern: PhrasePattern, body: ASTBlock, sourceLine: Int = 0, sourceFile: String = "",
                allowsDiscretion: Bool = false, autonomy: AutonomyConfigAST? = nil) {
        self.pattern = pattern; self.body = body
        self.sourceLine = sourceLine; self.sourceFile = sourceFile
        self.allowsDiscretion = allowsDiscretion
        self.autonomy = autonomy
    }
}

public struct AutonomyConfigAST: Sendable {
    public let until: ExpressionAST?
    public let unless: ExpressionAST?
    public let replanAfterFailures: Int
    public let maxSteps: Int

    public init(
        until: ExpressionAST? = nil,
        unless: ExpressionAST? = nil,
        replanAfterFailures: Int = 3,
        maxSteps: Int = 32
    ) {
        self.until = until
        self.unless = unless
        self.replanAfterFailures = replanAfterFailures
        self.maxSteps = maxSteps
    }

    /// Parse autonomy-loop options from a `with autonomy …` clause:
    /// `until <expr>`, `unless <expr>`, `re-plan after N`, `up to N steps`.
    /// `parseExpression` turns a captured clause into an `ExpressionAST` (the
    /// caller supplies its own `ExpressionParser` so this stays parser-agnostic).
    public static func parse(
        _ raw: String,
        parseExpression: (String) -> ExpressionAST
    ) -> AutonomyConfigAST {
        let lower = raw.lowercased()
        let markers = EnglishLexicon.default.grammar.autonomyMarkers
        let boundaries = markers.boundaryMarkers
        func clause(_ marker: String) -> String? {
            guard let range = raw.range(of: "\(marker) ", options: [.caseInsensitive]) else { return nil }
            let start = range.upperBound
            var end = raw.endIndex
            for next in boundaries {
                if let r = raw[start...].range(of: next, options: [.caseInsensitive]), r.lowerBound < end { end = r.lowerBound }
            }
            let text = String(raw[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        func intAfter(_ marker: String) -> Int? {
            guard let range = lower.range(of: marker) else { return nil }
            let digits = lower[range.upperBound...].drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
            return Int(String(digits))
        }
        return AutonomyConfigAST(
            until: clause(markers.until).map(parseExpression),
            unless: clause(markers.unless).map(parseExpression),
            replanAfterFailures: markers.replanAfter.compactMap(intAfter).first ?? 3,
            maxSteps: markers.maxSteps.compactMap(intAfter).first ?? 32
        )
    }
}

// MARK: - Block / Statements

public struct ASTBlock: Sendable {
    public let statements: [StatementAST]
    public let sourceLine: Int
    public init(statements: [StatementAST], sourceLine: Int = 0) {
        self.statements = statements; self.sourceLine = sourceLine
    }
}

public indirect enum StatementAST: Sendable {
    case bind(BindStatementAST)
    case rebind(RebindStatementAST)
    /// `proceed, and note "<text>" in the <binding>` (INFORM7 §2.9). Lowers to a
    /// `rebind` that appends `text` to an already-declared `text` binding; it is
    /// carried as its own AST node so lowering can enforce the "declared + text"
    /// contract and reject undeclared/non-text targets before desugaring.
    case note(NoteStatementAST)
    case emit(EmitStatementAST)
    case assertStmt(AssertStatementAST)
    case wait(WaitStatementAST)
    case commit(CommitStatementAST)
    case complete(CompleteStatementAST)
    case conditional(ConditionalStatementAST)
    /// `branch on <expr>:` match form (Wave 7 verbalizer surface / IR round-trip).
    /// Ordinary authored skills still lower only `.conditional` → `.predicate`;
    /// this AST exists so verbalized `.match` IR can reparse.
    case matchBranch(MatchBranchStatementAST)
    case iteration(IterationStatementAST)
    case simultaneously(SimultaneouslyStatementAST)
    case recover(RecoverStatementAST)
    case labelled(LabelledStatementAST)
    case proseStep(ProseStepAST)
    case modal(ExecutionModeAST)
    case phraseInvocation(PhraseInvocationAST)

    public var sourceLine: Int {
        switch self {
        case .bind(let s):              return s.sourceLine
        case .rebind(let s):            return s.sourceLine
        case .note(let s):              return s.sourceLine
        case .emit(let s):              return s.sourceLine
        case .assertStmt(let s):        return s.sourceLine
        case .wait(let s):              return s.sourceLine
        case .commit(let s):            return s.sourceLine
        case .complete(let s):          return s.sourceLine
        case .conditional(let s):       return s.sourceLine
        case .matchBranch(let s):       return s.sourceLine
        case .iteration(let s):         return s.sourceLine
        case .simultaneously(let s):    return s.sourceLine
        case .recover(let s):           return s.sourceLine
        case .labelled(let s):          return s.sourceLine
        case .proseStep(let s):         return s.sourceLine
        case .modal:                    return 0
        case .phraseInvocation(let s):  return s.sourceLine
        }
    }
}

public enum ExecutionModeAST: Sendable { case strict, lenient }

public struct BindStatementAST: Sendable {
    public let name: String
    public let value: ExpressionAST
    public let sourceLine: Int
    public init(name: String, value: ExpressionAST, sourceLine: Int = 0) {
        self.name = name; self.value = value; self.sourceLine = sourceLine
    }
}

public struct NoteStatementAST: Sendable {
    public let binding: String
    public let text: String
    public let sourceLine: Int
    public init(binding: String, text: String, sourceLine: Int = 0) {
        self.binding = binding; self.text = text; self.sourceLine = sourceLine
    }
}

public struct RebindStatementAST: Sendable {
    public let name: String
    public let value: ExpressionAST
    public let sourceLine: Int
    public init(name: String, value: ExpressionAST, sourceLine: Int = 0) {
        self.name = name; self.value = value; self.sourceLine = sourceLine
    }
}

public struct EmitStatementAST: Sendable {
    public let eventID: String
    public let payload: [(String, ExpressionAST)]
    public let sourceLine: Int
    public init(eventID: String, payload: [(String, ExpressionAST)], sourceLine: Int = 0) {
        self.eventID = eventID; self.payload = payload; self.sourceLine = sourceLine
    }
}

public struct AssertStatementAST: Sendable {
    public let condition: ExpressionAST
    public let message: String?
    public let otherwise: ASTBlock?
    public let sourceLine: Int
    public init(condition: ExpressionAST, message: String? = nil,
                otherwise: ASTBlock? = nil, sourceLine: Int = 0) {
        self.condition = condition; self.message = message
        self.otherwise = otherwise; self.sourceLine = sourceLine
    }
}

public struct WaitStatementAST: Sendable {
    public let condition: WaitConditionAST
    public let timeout: (value: Double, unit: TimeUnitAST)?
    public let timeoutRecover: ASTBlock?
    public let sourceLine: Int
    public init(
        condition: WaitConditionAST,
        timeout: (value: Double, unit: TimeUnitAST)? = nil,
        timeoutRecover: ASTBlock? = nil,
        sourceLine: Int = 0
    ) {
        self.condition = condition
        self.timeout = timeout
        self.timeoutRecover = timeoutRecover
        self.sourceLine = sourceLine
    }
}

public enum WaitConditionAST: Sendable {
    case duration(Double, TimeUnitAST)
    case signal(String)
    case approval(subject: ExpressionAST, byRole: String)
    /// `wait for event {eventID} matching {predicate}.`
    /// `predicate` is nil when no `matching` clause is present.
    case event(String, matching: ExpressionAST?)
    /// `ask the user to choose between "A", "B", or "C":` — emits `ask.choice`,
    /// waits for the host to deliver a selection, and binds it to `choice` so a
    /// following `branch` can route on it. Deterministic: no LLM involved.
    case choice(prompt: String, options: [String])
}

public enum TimeUnitAST: Sendable, Equatable {
    case millisecond, second, minute, hour, day, week

    public var inSeconds: Int {
        switch self {
        case .millisecond: return 0
        case .second:      return 1
        case .minute:      return 60
        case .hour:        return 3600
        case .day:         return 86400
        case .week:        return 604800
        }
    }
}

public enum CalendarAmountUnitAST: Sendable, Equatable {
    case businessDays
    case calendarDays
    case months
}

public struct CommitStatementAST: Sendable {
    public let label: String?
    public let sourceLine: Int
    public init(label: String? = nil, sourceLine: Int = 0) {
        self.label = label; self.sourceLine = sourceLine
    }
}

public struct CompleteStatementAST: Sendable {
    public let reason: String?
    public let sourceLine: Int
    public init(reason: String? = nil, sourceLine: Int = 0) {
        self.reason = reason; self.sourceLine = sourceLine
    }
}

public enum UnknownHandlingPolicyAST: Sendable, Equatable {
    case explicit
    case asTrue
    case asFalse
}

public struct ConditionalStatementAST: Sendable {
    public let condition: ExpressionAST
    public let thenBlock: ASTBlock
    public let unknownBlock: ASTBlock?
    public let elseBlock: ASTBlock?
    public let unknownPolicy: UnknownHandlingPolicyAST
    public let authoredForm: BranchAuthoredForm
    public let sourceLine: Int
    public init(condition: ExpressionAST, thenBlock: ASTBlock,
                unknownBlock: ASTBlock? = nil,
                elseBlock: ASTBlock? = nil,
                unknownPolicy: UnknownHandlingPolicyAST = .explicit,
                authoredForm: BranchAuthoredForm = .ifPositive,
                sourceLine: Int = 0) {
        self.condition = condition; self.thenBlock = thenBlock
        self.unknownBlock = unknownBlock
        self.elseBlock = elseBlock
        self.unknownPolicy = unknownPolicy
        self.authoredForm = authoredForm
        self.sourceLine = sourceLine
    }
}

/// One arm of a `branch on …:` match statement.
public struct MatchBranchCaseAST: Sendable {
    public let pattern: MatchPatternAST
    public let block: ASTBlock
    public init(pattern: MatchPatternAST, block: ASTBlock) {
        self.pattern = pattern
        self.block = block
    }
}

/// Pattern surface for `branch on` cases (`"yes":` / `approved:` / `anything:`).
public enum MatchPatternAST: Sendable {
    case literal(ExpressionAST)
    case enumValue(String)
    case wildcard
}

/// `branch on <subject>:` with indented `pattern:` cases and optional `otherwise:`.
public struct MatchBranchStatementAST: Sendable {
    public let subject: ExpressionAST
    public let cases: [MatchBranchCaseAST]
    public let otherwiseBlock: ASTBlock?
    public let sourceLine: Int
    public init(subject: ExpressionAST, cases: [MatchBranchCaseAST],
                otherwiseBlock: ASTBlock? = nil, sourceLine: Int = 0) {
        self.subject = subject
        self.cases = cases
        self.otherwiseBlock = otherwiseBlock
        self.sourceLine = sourceLine
    }
}

/// Discriminates the three loop forms supported by the Meridian language.
public enum IterationModeAST: Sendable {
    case forEach(variable: String, collection: ExpressionAST)
    case whileCondition(ExpressionAST)
    case untilCondition(ExpressionAST)
}

/// A single-clause refinement on a `for each` loop source (1C): `whose`/temporal
/// filters, a `sorted by` order, and a `the first N` prefix. Expressed relative
/// to the loop variable; `nil` everywhere = plain iteration.
public struct IterationRefinementAST: Sendable {
    public enum TemporalWindow: Sendable { case past, future }
    /// A `whose <prop> <comp> <value>` predicate, parsed as a comparison whose
    /// LHS is a bare property identifier (qualified to the loop var at lowering).
    public var predicate: ExpressionAST?
    /// A temporal window: `(property, .past|.future, duration-in-seconds)`.
    public var temporal: (property: String, window: TemporalWindow, seconds: Double)?
    public var sort: (property: String, ascending: Bool)?
    public var take: Int?
    /// `the last N` take-suffix (distinct from temporal windows).
    public var takeFromEnd: Int?
    /// 2B: Leading adjective modifiers (`for each stale page`) split off the
    /// kind noun. Resolved to `.definitionPredicate` filters at lowering.
    public var adjectives: [String]

    public init(predicate: ExpressionAST? = nil,
                temporal: (property: String, window: TemporalWindow, seconds: Double)? = nil,
                sort: (property: String, ascending: Bool)? = nil,
                take: Int? = nil,
                takeFromEnd: Int? = nil,
                adjectives: [String] = []) {
        self.predicate = predicate
        self.temporal = temporal
        self.sort = sort
        self.take = take
        self.takeFromEnd = takeFromEnd
        self.adjectives = adjectives
    }

    public var isEmpty: Bool {
        predicate == nil && temporal == nil && sort == nil && take == nil
            && takeFromEnd == nil && adjectives.isEmpty
    }
}

public struct IterationStatementAST: Sendable {
    public let mode: IterationModeAST
    public let body: ASTBlock
    public let sourceLine: Int
    public let refinement: IterationRefinementAST?
    public init(mode: IterationModeAST, body: ASTBlock, sourceLine: Int = 0,
                refinement: IterationRefinementAST? = nil) {
        self.mode = mode; self.body = body; self.sourceLine = sourceLine
        self.refinement = refinement
    }
}

public struct SimultaneouslyStatementAST: Sendable {
    public let branches: [ASTBlock]
    /// Fire-and-forget spawn (`in the background, <stmt>.`) — no join.
    public let detached: Bool
    public let sourceLine: Int
    public init(branches: [ASTBlock], detached: Bool = false, sourceLine: Int = 0) {
        self.branches = branches
        self.detached = detached
        self.sourceLine = sourceLine
    }
}

public struct PhraseInvocationAST: Sendable {
    public let words: String
    /// A trailing ` -- <note>` explanation on a command bullet (1A). Carried
    /// through lowering onto `InvokeIR.comment` and emitted as a source comment.
    public let annotation: String?
    public let sourceLine: Int
    public init(words: String, annotation: String? = nil, sourceLine: Int = 0) {
        self.words = words; self.annotation = annotation; self.sourceLine = sourceLine
    }
}

public struct LabelledStatementAST: Sendable {
    public let label: String
    public let statement: StatementAST
    public let sourceLine: Int

    public init(label: String, statement: StatementAST, sourceLine: Int = 0) {
        self.label = label
        self.statement = statement
        self.sourceLine = sourceLine
    }
}

/// An explicit, author-written prose-dispatch marker on a single statement.
/// This is the ONLY way prose reaches the planner inside an otherwise
/// deterministic workflow: `use judgment to …:` / `with discretion:` →
/// `.discretion`; `with autonomy …:` → `.autonomy`. When `dispatch` is `nil`
/// the prose step inherits the enclosing workflow's mode (legacy behavior:
/// only valid inside a `with discretion`/`with autonomy` workflow).
public enum ProseDispatchAST: Sendable {
    case discretion
    case autonomy
}

public struct ProseStepAST: Sendable {
    public let text: String
    public let sourceLine: Int
    /// Explicit local dispatch marker (nil = inherit the workflow's mode).
    public let dispatch: ProseDispatchAST?
    /// Autonomy configuration when `dispatch == .autonomy`.
    public let autonomy: AutonomyConfigAST?
    /// Section narrative carried alongside `text` as extra planner context —
    /// distinct from the dispatch goal itself. Populated by the
    /// `use judgment to follow the <heading> guidance:` migrator idiom, which
    /// collects a whole leftover inert-narrative body verbatim; `nil` for
    /// ordinary judgment/discretion/autonomy steps. Carried on both split IR
    /// primitives (`AIJudgmentIR`/`AIAutonomyIR`) — no new IR shape needed.
    public let guidance: String?
    /// `producing a <kind> called <name>` bindings from the judgment header.
    public let outputBindings: [(kind: String, name: String)]
    /// Explicit `using <tool>` scope from the judgment header.
    public let usingTools: [String]

    public init(text: String, sourceLine: Int = 0,
                dispatch: ProseDispatchAST? = nil,
                autonomy: AutonomyConfigAST? = nil,
                guidance: String? = nil,
                outputBindings: [(kind: String, name: String)] = [],
                usingTools: [String] = []) {
        self.text = text
        self.sourceLine = sourceLine
        self.dispatch = dispatch
        self.autonomy = autonomy
        self.guidance = guidance
        self.outputBindings = outputBindings
        self.usingTools = usingTools
    }
}

// MARK: - Recover

/// The error-pattern part of a `recover from {pattern}:` block.
public enum RecoverPatternAST: Sendable {
    /// `recover from any:` — catches all errors
    case any
    /// `recover from payment.declined:` — matches by error code / name
    case named(String)
    /// `recover from TimeoutError:` — matches by Swift type name
    case typed(String)
    /// `recover where {predicate}:` — matches by predicate expression
    case predicate(ExpressionAST)
}

/// AST node for a `recover from …:` block.
///
/// Attaches to the immediately preceding `StatementAST` in the enclosing block
/// (see `StatementParser.parseBlock`). The `attached` statement is stored here
/// so lowering can produce a single `RecoverIR` wrapping the correct `attachedTo`
/// block, even when the preceding statement lowered to multiple IR primitives.
public struct RecoverStatementAST: Sendable {
    public let pattern: RecoverPatternAST
    public let handler: ASTBlock
    /// The single statement this recover block is attached to.
    public let attached: StatementAST
    public let sourceLine: Int
    public init(pattern: RecoverPatternAST, handler: ASTBlock,
                attached: StatementAST, sourceLine: Int = 0) {
        self.pattern = pattern; self.handler = handler
        self.attached = attached; self.sourceLine = sourceLine
    }
}

// MARK: - Expressions (AST level)

/// B6/B7: One segment of a fenced-code-block string that contains `{{ expr }}`
/// interpolation markers.  A plain (non-interpolated) code block is lowered
/// directly to `.literal(.string(body))` and never produces segments.
public enum InterpolationSegment: Sendable {
    case literal(String)
    case expression(ExpressionAST)
    case conditional(condition: ExpressionAST, then: [InterpolationSegment], otherwise: [InterpolationSegment])
    case forEach(variable: String, collection: ExpressionAST, body: [InterpolationSegment])
    case formatted(ExpressionAST, formatter: String)
}

public indirect enum ExpressionAST: Sendable {
    case literal(LiteralAST)
    case identifierRef(String)
    case propertyAccess(ExpressionAST, String)
    case comparison(ExpressionAST, ComparisonOpAST, ExpressionAST)
    case logical(LogicalOpAST, [ExpressionAST])
    case envVar(String)
    case now
    case invoke(String, [(String, ExpressionAST)])
    case instanceRef(String)
    case constantRef(String)
    /// B3: `decide whether <question>` — delegates to `llm.decide` at runtime.
    case decideWhether(question: String)
    /// B6/B7: Fenced code block that contains `{{ expr }}` interpolation markers.
    case interpolatedString([InterpolationSegment])
    /// Data table: a list of records sharing `fields`, one record per row.
    /// Lowers to `.list([.record([...])])`.
    case recordList(fields: [String], rows: [[ExpressionAST]])
    /// Wave 4B: deterministic lookup in a named data table.
    case tableLookup(table: String, keyColumn: String, key: ExpressionAST, valueColumn: String)
    /// 2C: A quantified description (`all/any/no/at least N … <description>`).
    case quantified(QuantifierAST)
    /// 3B: An active verb condition (`the user owns the page`). Resolved to a
    /// relation predicate at lowering via the verb table.
    case verbPredicate(subject: ExpressionAST, verb: String, object: ExpressionAST)
    /// 3C: Scalar relation navigation (`the task assigned to the user`). `relation`
    /// is the surface verb/relation form; resolved + directed at lowering.
    case relationTraversal(ExpressionAST, relation: String, navKind: String)
    /// 3C: A description used as a value (`the stale pages that mention the entity`).
    case description(DescriptionAST)
    /// 3C: An aggregate over a description (`the number of …`, `the list of …`).
    case aggregate(AggregateKindAST, DescriptionAST)
    /// 3C: A superlative over a description (`the oldest stale page`,
    /// `the largest deal by amount`).
    case superlative(SuperlativeAST)
    case eventPattern(EventPatternAST)
    case traceTemporal(TraceTemporalAST)
    case traceStatistical(TraceStatisticalAST)
    /// 2A/2B/2C carrier: a surface-level violation (mixed bare and/or, an
    /// invalid quantifier/description shape, an unidentifiable kind) recorded
    /// at parse time with a fully-formed diagnostic. `ExpressionParser.parse`
    /// stays non-throwing; `ASTToIR.assertNoMalformed` raises the sourced error.
    /// The optional `suggestion` carries a structured "did you mean" (e.g. the
    /// closest declared verb form) so it survives as a real `Suggestion` on
    /// the emitted `Diagnostic`, not just text baked into the message.
    case malformed(String, code: DiagnosticCode = .malformedCondition,
                   help: String? = nil, suggestion: Suggestion? = nil)
}

public struct EventPatternAST: Sendable {
    public enum Subject: Sendable {
        case step(String)
        case named(String)
        /// `the fetch step of the briefing skill` (cookbook 17). Parsed so the
        /// compiler can raise a precise, named diagnostic — cross-skill trace
        /// scope is out of v1 by [DECISION D4] — rather than silently falling
        /// through to `.named("fetch step of the briefing skill")`.
        case stepOfSkill(step: String, skill: String)
    }

    public enum OutcomeVerb: String, Sendable {
        case failed
        case succeeded
        case invoked
        case emitted
        case prevented
        case violated
        /// Generic completion of the subject, regardless of success/failure —
        /// the reading `E has ever occurred` (SEM-5-1) and outcome-less
        /// kind-flavored anchors (`since the last production deploy`) need.
        case occurred
    }

    public let subject: Subject
    public let outcome: OutcomeVerb
    public let payloadPredicate: ExpressionAST?
    /// True for the event-negation reading `no <event pattern>`
    /// (`since the last production deploy, no critical alert has occurred`,
    /// cookbook 17/18.5, north-star flagship). Distinct from the `no`
    /// quantifier and the `has no <noun>` emptiness marker (cookbook 2.7 "no
    /// is triple-booked") — this flag only ever appears on the pattern that
    /// lives in `since`-holds / condition position.
    public let negated: Bool

    public init(subject: Subject, outcome: OutcomeVerb, payloadPredicate: ExpressionAST? = nil, negated: Bool = false) {
        self.subject = subject
        self.outcome = outcome
        self.payloadPredicate = payloadPredicate
        self.negated = negated
    }
}

public struct TraceStatisticalPatternAST: Sendable {
    public let subject: EventPatternAST.Subject
    public let payloadPredicate: ExpressionAST?

    public init(subject: EventPatternAST.Subject, payloadPredicate: ExpressionAST? = nil) {
        self.subject = subject
        self.payloadPredicate = payloadPredicate
    }
}

public enum TraceScopeAST: Sendable, Equatable {
    case currentRun
    case acrossAllRuns
    case acrossSkills([String])
}

public enum TraceCountComparatorAST: Sendable {
    case atLeast(Int)
    case atMost(Int)
    case exactly(Int)
}

public indirect enum TraceTemporalKindAST: Sendable {
    case ever(EventPatternAST)
    case withinWindow(EventPatternAST, duration: (Double, TimeUnitAST))
    case countInWindow(EventPatternAST, comparator: TraceCountComparatorAST, duration: (Double, TimeUnitAST))
    case inARow(EventPatternAST, count: Int)
    case sinceLast(anchor: EventPatternAST, holds: ExpressionAST)
    case boundedFutureMonitor(condition: ExpressionAST, horizon: (Double, TimeUnitAST), mode: FutureMonitorModeAST)
}

public enum FutureMonitorModeAST: Sendable, Equatable {
    case eventuallyWithin
    case alwaysFor
}

public struct TraceTemporalAST: Sendable {
    public let scope: TraceScopeAST
    public let kind: TraceTemporalKindAST

    public init(scope: TraceScopeAST = .currentRun, kind: TraceTemporalKindAST) {
        self.scope = scope
        self.kind = kind
    }
}

public enum TraceStatisticalOutcomeAST: Sendable {
    case succeeds
    case fails
}

public enum TraceStatisticalBoundAST: Sendable {
    case atLeast(Double)
    case atMost(Double)
    case usually
    case rarely
}

public enum TraceStatisticalDenominatorAST: Sendable {
    case runs
    case occurrences
}

public struct TraceStatisticalAST: Sendable {
    public let scope: TraceScopeAST
    public let pattern: TraceStatisticalPatternAST
    public let outcome: TraceStatisticalOutcomeAST
    public let bound: TraceStatisticalBoundAST
    public let denominator: TraceStatisticalDenominatorAST
    public let window: (Double, TimeUnitAST)?
    public let monitorCadence: (Double, TimeUnitAST)?
    public let blocking: Bool
    public let confidencePercent: Double?

    public init(
        scope: TraceScopeAST = .currentRun,
        pattern: TraceStatisticalPatternAST,
        outcome: TraceStatisticalOutcomeAST,
        bound: TraceStatisticalBoundAST,
        denominator: TraceStatisticalDenominatorAST,
        window: (Double, TimeUnitAST)? = nil,
        monitorCadence: (Double, TimeUnitAST)? = nil,
        blocking: Bool = false,
        confidencePercent: Double? = nil
    ) {
        self.scope = scope
        self.pattern = pattern
        self.outcome = outcome
        self.bound = bound
        self.denominator = denominator
        self.window = window
        self.monitorCadence = monitorCadence
        self.blocking = blocking
        self.confidencePercent = confidencePercent
    }
}

// MARK: - 2C. Quantifiers over descriptions

/// The quantifier determiner of a quantified description.
public enum QuantifierKindAST: Sendable, Equatable {
    case all          // all / every — requires a body
    case any          // any / some / at least one
    case none         // no / none of
    case atLeast(Int)
    case atMost(Int)
    case exactly(Int)
}

/// A description = `[adjectives] <kind plural> ( whose <predicate> | <verb
/// clause> )* [sorted by …] [first N]`. The adjectives are kept as raw surface
/// strings and resolved to definition predicates at lowering. `wherePredicate`,
/// when present, terminates the where-restriction; `verbClauses` carry relation
/// relative/passive restrictions (3B).
public struct DescriptionAST: Sendable {
    /// The collection noun as written (typically plural, e.g. "pages").
    public let noun: String
    public let adjectives: [String]
    public let wherePredicate: ExpressionAST?
    /// 3B: relation relative/passive clauses restricting the element set.
    public let verbClauses: [VerbClauseAST]
    /// 3C: a `sorted by <property>[, dir]` order.
    public let sort: (property: String, ascending: Bool)?
    /// 3C: a `the first N` take-prefix (post-filter, post-sort).
    public let take: Int?
    /// 3C: a `the last N` take-suffix (post-filter, post-sort) — disambiguated
    /// from temporal `within the last N <unit>` by requiring a kind noun, not a
    /// duration unit, immediately after the count.
    public let takeFromEnd: Int?
    public init(noun: String, adjectives: [String] = [], wherePredicate: ExpressionAST? = nil,
                verbClauses: [VerbClauseAST] = [],
                sort: (property: String, ascending: Bool)? = nil, take: Int? = nil,
                takeFromEnd: Int? = nil) {
        self.noun = noun; self.adjectives = adjectives; self.wherePredicate = wherePredicate
        self.verbClauses = verbClauses; self.sort = sort; self.take = take
        self.takeFromEnd = takeFromEnd
    }
}

/// 3B: a relation clause restricting a description's element set. The element
/// (the iterated kind) plays either the subject or object role of `verbForm`'s
/// relation; `operand` is the fixed other side.
///   `pages that mention the entity`  → elementIsSubject = true,  operand = entity
///   `pages owned by the user`        → elementIsSubject = false, operand = user
///   `pages that the user owns`       → elementIsSubject = false, operand = user
public struct VerbClauseAST: Sendable {
    public let verbForm: String
    public let operand: ExpressionAST
    public let elementIsSubject: Bool
    public init(verbForm: String, operand: ExpressionAST, elementIsSubject: Bool) {
        self.verbForm = verbForm; self.operand = operand; self.elementIsSubject = elementIsSubject
    }
}

public enum AggregateKindAST: Sendable, Equatable { case count, list }

/// 3C: a superlative — a description reduced to a single element by a sort key.
/// `ascending == true` takes the minimum (oldest/smallest); `false` the maximum.
public struct SuperlativeAST: Sendable {
    public let description: DescriptionAST
    public let property: String
    public let ascending: Bool
    public init(description: DescriptionAST, property: String, ascending: Bool) {
        self.description = description; self.property = property; self.ascending = ascending
    }
}

/// A quantified description. `body` (`have <noun>` / `are <adjective>`) is a
/// per-element predicate; `all`/`every` require it, and it is only recognised
/// when the description has no `whose` clause.
public struct QuantifierAST: Sendable {
    public let kind: QuantifierKindAST
    public let description: DescriptionAST
    public let body: ExpressionAST?
    public init(kind: QuantifierKindAST, description: DescriptionAST, body: ExpressionAST? = nil) {
        self.kind = kind; self.description = description; self.body = body
    }
}

public enum LiteralAST: Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case money(Double, currency: String)
    case duration(Double, TimeUnitAST)
    case calendarAmount(Double, CalendarAmountUnitAST)
}
public enum ComparisonOpAST: Sendable {
    case equal, notEqual
    case lessThan, lessOrEqual
    case greaterThan, greaterOrEqual
    case within
    case contains, oneOf
    case matchesPattern
    /// Shared condition grammar: one-sided temporal windows (`within the last`
    /// / `in the next`) and property-backed emptiness (`has no` / `has a` /
    /// `is empty` / `is not empty`).
    case withinPast, withinFuture
    case isEmpty, isNotEmpty
}

public enum LogicalOpAST: Sendable { case and, or, not }
