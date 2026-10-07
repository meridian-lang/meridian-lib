import Foundation

/// Accountability metadata for every `DiagnosticCode` in the catalog.
/// The inventory test asserts each non-reserved code has at least one emitter
/// listed here so docs/code cannot drift (e.g. MER1002 defined but never wired).
public enum DiagnosticCodeStatus: String, Sendable {
    case active
    case reserved
    case deprecated
}

public struct DiagnosticCodeEntry: Sendable {
    public let code: DiagnosticCode
    public let status: DiagnosticCodeStatus
    /// Production emit sites (module-relative paths). Empty for reserved/deprecated.
    public let emitters: [String]

    public init(_ code: DiagnosticCode, status: DiagnosticCodeStatus, emitters: [String] = []) {
        self.code = code
        self.status = status
        self.emitters = emitters
    }
}

extension DiagnosticCode {

    /// Single source of truth for catalog accountability tests and `meridian explain-diag`.
    public static let catalog: [DiagnosticCodeEntry] = [
        // MER0xxx — legacy shims (still emitted via CompilerError projection)
        .init(.legacySemantic, status: .deprecated),
        .init(.legacySyntax, status: .deprecated),
        .init(.notImplemented, status: .deprecated),
        .init(.internalError, status: .active, emitters: ["ASTToIR+Expression.swift"]),

        // MER1xxx — parse / structural
        .init(.malformedWorkflowHeader, status: .active, emitters: ["MeridianParser.swift"]),
        .init(.orphanedCodeBlock, status: .active, emitters: ["StatementParser.swift", "StatementParser+Blocks.swift"]),
        .init(.unparseableStatement, status: .active, emitters: ["StatementParser.swift", "StatementParser+Blocks.swift"]),
        .init(.unparseableRule, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.malformedCondition, status: .active,
              emitters: ["ASTToIR.swift", "ASTToIR+Expression.swift"]),
        .init(.frontmatterPlacement, status: .active, emitters: ["MeridianParser.swift"]),
        .init(.invalidTestSpecKey, status: .active, emitters: ["SpecParser.swift"]),
        .init(.removedImportForm, status: .active, emitters: ["MeridianParser.swift"]),
        .init(.sectionStructuralError, status: .active, emitters: ["SkillSectionBuilder.swift"]),
        .init(.uncheckablePredicate, status: .active,
              emitters: ["SkillSectionBuilder.swift", "StatementParser+Checklists.swift"]),
        .init(.invalidTableCell, status: .active, emitters: ["StatementParser+Blocks.swift"]),
        .init(.matchBranchSyntax, status: .active, emitters: ["StatementParser+Bindings.swift:parseMatchBranch"]),

        // MER2xxx — name resolution
        .init(.unresolvedPhrase, status: .active, emitters: ["ASTToIR+PhraseInvocation.swift"]),
        .init(.unknownTool, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.unknownKind, status: .active, emitters: ["MeridianParser.swift"]),
        .init(.unknownProperty, status: .active,
              emitters: ["ASTToIR+Definitions.swift", "ASTToIR+Relations.swift"]),
        .init(.unknownVocabulary, status: .active, emitters: ["Compiler.swift"]),
        .init(.unknownRulebook, status: .active, emitters: ["Compiler.swift"]),
        .init(.unknownAdjective, status: .active, emitters: ["ASTToIR+Definitions.swift"]),
        .init(.unknownVerb, status: .active, emitters: ["ASTToIR+Relations.swift"]),
        .init(.unknownFallbackKind, status: .active, emitters: ["Compiler.swift"]),
        .init(.unknownTraceCategory, status: .active, emitters: ["ParserTrace.swift", "CLISupport.swift"]),
        .init(.missingPhraseArgument, status: .active, emitters: ["ASTToIR+PhraseInvocation.swift:lowerPhraseInvocation"]),
        .init(.unknownTemplateFormatter, status: .active,
              emitters: ["ASTToIR+Expression.swift:validateFormatter", "RuleInjector.swift:lowerInterpolationSegmentSimple"]),

        // MER3xxx — semantics
        .init(.phraseInlineDepthExceeded, status: .active, emitters: ["ASTToIR+PhraseInvocation.swift"]),
        .init(.definitionRecursion, status: .active, emitters: ["ASTToIR+Definitions.swift"]),
        .init(.duplicateDeclaration, status: .active, emitters: ["Compiler.swift", "ASTToIR+Definitions.swift"]),
        .init(.duplicateName, status: .active, emitters: ["Compiler.swift"]),
        .init(.relationBackingInvalid, status: .active, emitters: ["ASTToIR+Relations.swift"]),
        .init(.unattachedRule, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.unresolvedTriggerAction, status: .active, emitters: ["RuleInjector.swift"]),
        .init(.toolBackedInlineDisallowed, status: .active, emitters: ["ASTToIR+Relations.swift"]),
        .init(.ambiguousEntryWorkflow, status: .active, emitters: ["MeridianParser.swift"]),
        .init(.proseDisallowed, status: .active, emitters: ["ASTToIR+Statements.swift"]),
        .init(.commandHoleOutOfScope, status: .active, emitters: ["ASTToIR+Commands.swift", "ASTToIR+Relations.swift"]),
        .init(.quantifierSemantic, status: .active, emitters: ["ASTToIR+Quantifier.swift"]),
        .init(.ambiguousAnaphora, status: .active, emitters: ["AnaphoraResolver.swift"]),
        .init(.invalidEnumDefault, status: .active, emitters: ["Compiler.swift:mergeEnumDefaults"]),
        .init(.unlowerableRulePredicate, status: .active, emitters: ["RuleInjector.swift:lowerExprSimple"]),
        .init(.unsupportedTriggerCondition, status: .active, emitters: ["RuleInjector.swift:synthesizeTriggers"]),
        .init(.matchBranchSemantic, status: .active, emitters: ["ASTToIR+Statements.swift", "IRValidator.swift"]),
        .init(.traceBarePerfect, status: .active, emitters: ["TraceTemporalGrammar.swift"]),
        .init(.traceWindowExceedsRetention, status: .active, emitters: ["ASTToIR+Expression.swift"]),
        .init(.traceCausalSince, status: .active, emitters: ["TraceTemporalGrammar.swift"]),
        .init(.traceFuture, status: .active,
              emitters: ["TraceTemporalGrammar.swift", "ASTToIR+Expression.swift"]),
        .init(.traceUnknownStep, status: .active, emitters: ["ASTToIR+Expression.swift"]),
        .init(.traceUnknownPayloadField, status: .active, emitters: ["ASTToIR+Expression.swift"]),
        .init(.traceUnkeyedDefinition, status: .active, emitters: ["ASTToIR+Definitions.swift"]),
        .init(.traceRecently, status: .active, emitters: ["TraceTemporalGrammar.swift"]),
        .init(.traceProgressive, status: .active, emitters: ["TraceTemporalGrammar.swift"]),
        .init(.traceStateHistorySince, status: .active, emitters: ["ASTToIR+Expression.swift"]),
        .init(.traceMissingProductionCapturePolicy, status: .active, emitters: ["Compiler.swift:validateProductionTraceCapturePolicies"]),
        .init(.traceCrossSkillScope, status: .active, emitters: ["ASTToIR+Expression.swift:lowerEventSubject"]),
        .init(.traceMissingUnknownArm, status: .active, emitters: ["ASTToIR+Statements.swift"]),
        .init(.statisticalConfidenceReserved, status: .deprecated, emitters: []),
        .init(.statisticalVagueFrequency, status: .active, emitters: ["TraceStatisticalGrammar.swift"]),

        // MER-REF / MER-TYP — binding reference & type (compound note form)
        .init(.noteBindingUndeclared, status: .active, emitters: ["ASTToIR+Bind.swift"]),
        .init(.noteBindingNonText, status: .active, emitters: ["ASTToIR+Bind.swift"]),

        // MER4xxx — codegen
        .init(.codegenError, status: .active, emitters: ["Compiler.swift:codegenError projection"]),
        .init(.invalidIR, status: .active, emitters: ["IRValidator.swift"]),

        // MER5xxx — configuration
        .init(.swiftFormatFailed, status: .active, emitters: ["CompileCommand.swift"]),
        .init(.vocabularyDeclarationUnrecognized, status: .active,
              emitters: ["MerConfigParser+Vocabulary.swift", "MerConfigParser+Trace.swift"]),
        .init(.rulebookSectionUnknown, status: .active, emitters: ["RulebookParser.swift"]),
        .init(.unknownMerconfigSection, status: .active, emitters: ["MerConfigParser.swift"]),
        .init(.malformedRulebookEntry, status: .active, emitters: ["RulebookParser.swift"]),
        .init(.unrecognizedBlockProperty, status: .active,
              emitters: ["MerConfigParser+Vocabulary.swift"]),
        .init(.unwritableTraceFile, status: .active, emitters: ["CLISupport.swift:makeCLITrace"]),
        .init(.emptyLexiconMarkers, status: .active, emitters: ["Verbalizer.swift"]),
        .init(.inputFileNotFound, status: .active, emitters: ["CLISupport.swift"]),
        .init(.directoryReadFailed, status: .active, emitters: ["CLISupport.swift"]),

        // MER6xxx — lint / authoring warnings
        .init(.lintPoliteCommand, status: .active, emitters: ["MeridianLinter.swift:paraphraseHint"]),
        .init(.lintUncertainty, status: .active, emitters: ["MeridianLinter.swift:paraphraseHint"]),
        .init(.migrationRouteFuzzyDowngrade, status: .active,
              emitters: ["SkillMigrator+CommandRewrite.swift"]),
        .init(.diagnosticRecoverySummary, status: .active,
              emitters: ["DiagnosticEngine.swift:throwIfErrors"]),
        .init(.lintCrossRunInARow, status: .active,
              emitters: ["MeridianLinter.swift:crossRunInARowHint"]),
        .init(.lintSuperlativeEventAnchor, status: .active,
              emitters: ["MeridianLinter.swift:superlativeEventAnchorHint"]),

        // MER-DEO — deontic (Final Wave)
        .init(.deonticSameScopeConflict, status: .active, emitters: ["DeonticLowering.swift"]),
        .init(.deonticStickyDeny, status: .active, emitters: ["DeonticLowering.swift"]),
        .init(.deonticNonNormModal, status: .active, emitters: ["DeonticLowering.swift"]),
        .init(.deonticToolOutsidePermissions, status: .active,
              emitters: ["DeonticLowering.swift:wrapInvokeIfNeeded"]),
        .init(.deonticOutcomeAsAction, status: .active, emitters: ["DeonticLowering.swift"]),
        .init(.normIdCollision, status: .active, emitters: ["NormIdentity.swift"]),
        .init(.deonticUnlowerableCondition, status: .active,
              emitters: ["RuleLowering.swift:lowerExprForDeontic", "DeonticLowering.swift:lowerCheckableDeonticExpr"]),

        // MER-MOD — shared modules (Final Wave)
        .init(.moduleNotFound, status: .active, emitters: ["ModuleResolver.swift:locatePackage"]),
        .init(.moduleImportCycle, status: .active, emitters: ["ModuleResolver.swift:resolveOne"]),
        .init(.moduleExportCollision, status: .active, emitters: ["ModuleResolver.swift:resolveOne"]),
        .init(.moduleSealedCollision, status: .active, emitters: ["ModuleResolver.swift:resolveOne"]),
        .init(.duplicateModuleImport, status: .active, emitters: ["ModuleResolver.swift:resolve"]),

        // MER-JDG / MER-CND / MER-DSC / MER-DOM — cookbook north-star diagnostics
        .init(.judgmentWithoutProducedValue, status: .active,
              emitters: ["StatementParser+Decisions.swift:parseJudgmentMarker"]),
        .init(.judgmentToolOutsidePermissions, status: .active,
              emitters: ["ASTToIR.swift:resolveJudgmentTools"]),
        .init(.conditionUnknownComparator, status: .active,
              emitters: ["StatementParser+Idioms.swift:extractIterationRefinement"]),
        .init(.domainContradictoryDefault, status: .active,
              emitters: ["Compiler.swift:mergeEnumDefaults"]),
        .init(.descriptionSuperlativeNeedsProperty, status: .active,
              emitters: ["SuperlativeGrammar.swift"]),
    ]

    public static var catalogByID: [String: DiagnosticCodeEntry] {
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.code.id, $0) })
    }
}
