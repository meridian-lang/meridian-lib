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

    /// Single source of truth for catalog accountability tests and `meridian explain`.
    public static let catalog: [DiagnosticCodeEntry] = [
        // MER0xxx — legacy shims (still emitted via CompilerError projection)
        .init(.legacySemantic, status: .active, emitters: ["Compiler.swift:semanticError projection"]),
        .init(.legacySyntax, status: .active, emitters: ["Compiler.swift:syntaxError projection"]),
        .init(.notImplemented, status: .active, emitters: ["Compiler.swift:notImplemented projection"]),
        .init(.internalError, status: .active, emitters: ["ASTToIR.swift"]),

        // MER1xxx — parse / structural
        .init(.malformedWorkflowHeader, status: .active, emitters: ["MeridianParser.swift"]),
        .init(.orphanedCodeBlock, status: .active, emitters: ["StatementParser.swift"]),
        .init(.unparseableStatement, status: .active, emitters: ["StatementParser.swift"]),
        .init(.unparseableRule, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.malformedCondition, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.frontmatterPlacement, status: .active, emitters: ["MeridianParser.swift"]),
        .init(.invalidTestSpecKey, status: .active, emitters: ["SpecParser.swift"]),
        .init(.removedImportForm, status: .active, emitters: ["MeridianParser.swift"]),
        .init(.sectionStructuralError, status: .active, emitters: ["SkillSectionBuilder.swift"]),
        .init(.uncheckablePredicate, status: .active,
              emitters: ["SkillSectionBuilder.swift", "StatementParser.swift"]),
        .init(.invalidTableCell, status: .active, emitters: ["StatementParser.swift"]),

        // MER2xxx — name resolution
        .init(.unresolvedPhrase, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.unknownTool, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.unknownKind, status: .active, emitters: ["MeridianParser.swift", "ASTToIR.swift"]),
        .init(.unknownProperty, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.unknownVocabulary, status: .active, emitters: ["Compiler.swift"]),
        .init(.unknownRulebook, status: .active, emitters: ["Compiler.swift"]),
        .init(.unknownAdjective, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.unknownVerb, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.unknownFallbackKind, status: .active, emitters: ["Compiler.swift"]),
        .init(.unknownTraceCategory, status: .active, emitters: ["ParserTrace.swift", "CLISupport.swift"]),

        // MER3xxx — semantics
        .init(.phraseInlineDepthExceeded, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.definitionRecursion, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.duplicateDeclaration, status: .active, emitters: ["Compiler.swift", "ASTToIR.swift"]),
        .init(.duplicateName, status: .active, emitters: ["Compiler.swift"]),
        .init(.relationBackingInvalid, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.unattachedRule, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.unresolvedTriggerAction, status: .active, emitters: ["RuleInjector.swift"]),
        .init(.toolBackedInlineDisallowed, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.ambiguousEntryWorkflow, status: .active, emitters: ["MeridianParser.swift"]),
        .init(.proseDisallowed, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.commandHoleOutOfScope, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.quantifierSemantic, status: .active, emitters: ["ASTToIR.swift"]),
        .init(.ambiguousAnaphora, status: .active, emitters: ["AnaphoraResolver.swift"]),
        .init(.invalidEnumDefault, status: .active, emitters: ["Compiler.swift:mergeEnumDefaults"]),

        // MER4xxx — codegen
        .init(.codegenError, status: .active, emitters: ["Compiler.swift:codegenError projection"]),

        // MER5xxx — configuration
        .init(.swiftFormatFailed, status: .active, emitters: ["CompileCommand.swift"]),
        .init(.vocabularyDeclarationUnrecognized, status: .active,
              emitters: ["MerConfigParser.swift", "MerConfigParser.swift:tools"]),
        .init(.rulebookSectionUnknown, status: .active, emitters: ["RulebookParser.swift"]),
        .init(.unknownMerconfigSection, status: .active, emitters: ["MerConfigParser.swift"]),
        .init(.malformedRulebookEntry, status: .active, emitters: ["RulebookParser.swift"]),
        .init(.unrecognizedBlockProperty, status: .active, emitters: ["MerConfigParser.swift:parseBlockProperty"]),
    ]

    public static var catalogByID: [String: DiagnosticCodeEntry] {
        Dictionary(uniqueKeysWithValues: catalog.map { ($0.code.id, $0) })
    }
}
