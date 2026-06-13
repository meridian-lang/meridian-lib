import Foundation

/// A reference to a design decision in the `DecisionCatalog` (Pillar 11).
/// Kept as a thin id wrapper so `DiagnosticCode` (this file) does not depend on
/// the catalog's data; `meridian explain` / `meridian decisions` resolve it.
public struct DecisionRef: Sendable, Hashable {
    public let id: String
    public init(_ id: String) { self.id = id }
}

/// A stable, documented diagnostic code. Codes never change once shipped — they
/// are the durable contract that `meridian explain <code>`, editor integrations,
/// CI matchers, and tests rely on (messages may evolve, codes may not).
///
/// Ranges:
///   - `MER0xxx` — legacy/generic (migration shims)
///   - `MER1xxx` — lexing / parsing (structural)
///   - `MER2xxx` — name resolution
///   - `MER3xxx` — semantics
///   - `MER4xxx` — codegen
///   - `MER5xxx` — configuration / vocabulary
public struct DiagnosticCode: Sendable, Hashable {

    /// How a code is fixed — drives the always-on remediation guarantee
    /// (Pillar 3). `nameResolution` codes MUST be produced through
    /// `Diagnostic.unresolved(...)` so they always carry a suggestion or a
    /// candidate-list note. `structural` codes MUST carry a non-empty `help`.
    public enum Kind: String, Sendable, Hashable {
        case nameResolution
        case structural
        case other
    }

    public let id: String
    public let title: String
    public let explanation: String
    public let kind: Kind
    public let decision: DecisionRef?

    public init(id: String, title: String, explanation: String,
                kind: Kind, decision: DecisionRef? = nil) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.kind = kind
        self.decision = decision
    }
}

extension DiagnosticCode: CustomStringConvertible {
    public var description: String { id }
}

// MARK: - Catalog

extension DiagnosticCode {

    // MARK: MER0xxx — legacy / generic

    public static let legacySemantic = DiagnosticCode(
        id: "MER0001", title: "semantic error",
        explanation: "A semantic error not yet migrated to a specific code. See the message for details.",
        kind: .other)

    public static let legacySyntax = DiagnosticCode(
        id: "MER0002", title: "syntax error",
        explanation: "A syntax error not yet migrated to a specific code. See the message for details.",
        kind: .other)

    public static let notImplemented = DiagnosticCode(
        id: "MER0003", title: "not implemented",
        explanation: "A language or compiler feature referenced here is not implemented yet.",
        kind: .other)

    public static let internalError = DiagnosticCode(
        id: "MER0004", title: "internal compiler error",
        explanation: "An invariant the compiler relies on was violated. This is a compiler bug; please report it.",
        kind: .other)

    // MARK: MER1xxx — lex / parse (structural)

    public static let malformedWorkflowHeader = DiagnosticCode(
        id: "MER1001", title: "malformed workflow header",
        explanation: "A workflow header must end with a colon (':'). The line started a 'to …' workflow declaration but no ':' was found, so its body could not be attached.",
        kind: .structural, decision: DecisionRef("D-DX-2"))

    public static let orphanedCodeBlock = DiagnosticCode(
        id: "MER1002", title: "orphaned code block",
        explanation: "A fenced code block appeared where no statement could consume it (for example outside any workflow body or step). Move it under a statement that uses it, or remove it.",
        kind: .structural, decision: DecisionRef("D-DX-2"))

    public static let unparseableStatement = DiagnosticCode(
        id: "MER1003", title: "unrecognized statement",
        explanation: "A non-empty line inside a workflow body did not match any known statement form and was not a recognized phrase invocation.",
        kind: .structural, decision: DecisionRef("D-DX-2"))

    public static let unparseableRule = DiagnosticCode(
        id: "MER1004", title: "unparseable rule",
        explanation: "A top-level rule could not be classified into one of the supported shapes (must / must not / must be … by … before / when / may).",
        kind: .structural, decision: DecisionRef("D-DX-2"))

    public static let malformedCondition = DiagnosticCode(
        id: "MER1005", title: "malformed condition",
        explanation: "A boolean condition or expression was malformed (for example mixing bare 'and'/'or' at one level). Rewrite it using explicit grouping.",
        kind: .structural)

    public static let frontmatterPlacement = DiagnosticCode(
        id: "MER1006", title: "misplaced frontmatter",
        explanation: "A '---' frontmatter block may only appear at the very head of a file (optionally preceded by blank lines).",
        kind: .structural)

    public static let invalidTestSpecKey = DiagnosticCode(
        id: "MER1007", title: "unknown test-spec key",
        explanation: "A `.meridian.test` spec used a key the runner does not recognize.",
        kind: .nameResolution)

    public static let removedImportForm = DiagnosticCode(
        id: "MER1008", title: "removed import form",
        explanation: "Body-level `import` is removed. Declare vocabulary/rulebook dependencies in frontmatter (`vocabulary:` / `rulebook:`).",
        kind: .structural)

    // MARK: MER2xxx — name resolution

    public static let unresolvedPhrase = DiagnosticCode(
        id: "MER2001", title: "unresolved phrase",
        explanation: "A phrase invocation did not match any declared phrase or workflow. Add a matching phrase/workflow, fix the wording, or set frontmatter `allow-fallbacks: unresolved-phrases` to emit a placeholder.",
        kind: .nameResolution, decision: DecisionRef("D-DX-1"))

    public static let unknownTool = DiagnosticCode(
        id: "MER2002", title: "unknown tool",
        explanation: "An invoked tool id is not a built-in, a vocabulary-declared tool, a frontmatter `tools:` entry, or a workflow reference. Declare it in `=== tools ===`, list it in frontmatter `tools:`, or set `allow-fallbacks: unknown-tools` for host-provided tools.",
        kind: .nameResolution, decision: DecisionRef("D-DX-5"))

    public static let unknownKind = DiagnosticCode(
        id: "MER2003", title: "unknown kind",
        explanation: "A kind (type) name does not resolve to any declared vocabulary kind.",
        kind: .nameResolution, decision: DecisionRef("D-DX-4"))

    public static let unknownProperty = DiagnosticCode(
        id: "MER2004", title: "unknown property",
        explanation: "A property name is not declared on the referenced kind.",
        kind: .nameResolution, decision: DecisionRef("D-DX-4"))

    public static let unknownVocabulary = DiagnosticCode(
        id: "MER2005", title: "unknown vocabulary",
        explanation: "A `vocabulary:` reference did not match any supplied `.merconfig`.",
        kind: .nameResolution)

    public static let unknownRulebook = DiagnosticCode(
        id: "MER2006", title: "unknown rulebook",
        explanation: "A `rulebook:` reference did not match any supplied `.merrules`.",
        kind: .nameResolution)

    public static let unknownAdjective = DiagnosticCode(
        id: "MER2007", title: "unknown adjective",
        explanation: "A checkable adjective used in a condition was never defined (`Definition: a <kind> is <adj> if …`).",
        kind: .nameResolution, decision: DecisionRef("D-DX-4"))

    public static let unknownVerb = DiagnosticCode(
        id: "MER2008", title: "unknown verb",
        explanation: "A verb form does not resolve to any declared verb (`The verb to <base> … means the <relation> relation.`).",
        kind: .nameResolution, decision: DecisionRef("D-DX-4"))

    public static let unknownFallbackKind = DiagnosticCode(
        id: "MER2009", title: "unknown allow-fallbacks kind",
        explanation: "A frontmatter `allow-fallbacks:` token is not a recognized fallback kind.",
        kind: .nameResolution)

    public static let unknownTraceCategory = DiagnosticCode(
        id: "MER2010", title: "unknown trace category",
        explanation: "A `--trace` token is not a recognized tracing category. Run `meridian trace categories` to list them.",
        kind: .nameResolution)

    // MARK: MER3xxx — semantics

    public static let phraseInlineDepthExceeded = DiagnosticCode(
        id: "MER3001", title: "phrase inlining too deep",
        explanation: "A phrase inlined other phrases beyond the recursion limit. This usually indicates a cyclic phrase definition.",
        kind: .other, decision: DecisionRef("D-DX-2"))

    public static let definitionRecursion = DiagnosticCode(
        id: "MER3002", title: "recursive definition",
        explanation: "A checkable adjective definition refers back to itself (directly or transitively). Definitions must be acyclic.",
        kind: .other)

    public static let duplicateDeclaration = DiagnosticCode(
        id: "MER3003", title: "duplicate declaration",
        explanation: "A kind / phrase / tool / constant / instance name was declared more than once in the merged vocabulary.",
        kind: .other)

    public static let duplicateName = DiagnosticCode(
        id: "MER3004", title: "duplicate name",
        explanation: "A vocabulary or rulebook name was supplied more than once.",
        kind: .other)

    public static let relationBackingInvalid = DiagnosticCode(
        id: "MER3005", title: "invalid relation backing",
        explanation: "A relation's evaluation backing referenced a kind, property, or tool that does not exist, or a verb-named relation has no backing.",
        kind: .other)

    public static let unattachedRule = DiagnosticCode(
        id: "MER3006", title: "unattached rule",
        explanation: "A rule parsed cleanly but matched no workflow's action surface. Align the rule's verb with a workflow name/parameter, or set `allow-fallbacks: unattached-rules`.",
        kind: .other, decision: DecisionRef("D-DX-2"))

    public static let unresolvedTriggerAction = DiagnosticCode(
        id: "MER3007", title: "unresolved trigger action",
        explanation: "A `when … , do X` trigger's action text did not lower to a real phrase invocation. Fix the action, or set `allow-fallbacks: unresolved-trigger-actions`.",
        kind: .other, decision: DecisionRef("D-DX-2"))

    public static let toolBackedInlineDisallowed = DiagnosticCode(
        id: "MER3008", title: "tool-backed expression must be a statement",
        explanation: "A tool-backed relation traversal or description requires an `await` fetch and cannot be used in an inline expression position. Bind it with `let`/`bind` first.",
        kind: .other)

    // MARK: MER4xxx — codegen

    public static let codegenError = DiagnosticCode(
        id: "MER4001", title: "codegen error",
        explanation: "Code generation failed to produce valid Swift for a construct.",
        kind: .other)

    // MARK: MER5xxx — configuration / vocabulary

    public static let swiftFormatFailed = DiagnosticCode(
        id: "MER5001", title: "swift-format failed",
        explanation: "swift-format could not format the generated Swift. The unformatted output was kept; the program is still valid.",
        kind: .other, decision: DecisionRef("D-DX-3"))

    public static let vocabularyDeclarationUnrecognized = DiagnosticCode(
        id: "MER5002", title: "unrecognized vocabulary declaration",
        explanation: "A line in a `.merconfig` looked like a declaration but matched no known vocabulary form.",
        kind: .structural)

    public static let rulebookSectionUnknown = DiagnosticCode(
        id: "MER5003", title: "unknown rulebook section",
        explanation: "A `=== section ===` header in a `.merrules` is not one of the recognized rulebook sections (desugar / sections / conventions / language).",
        kind: .nameResolution)

    /// Every catalog code, for `meridian explain`, the staleness/guard tests,
    /// and uniqueness checks. Keep this list complete — a guard test asserts
    /// there are no duplicate ids and every code has a non-empty explanation.
    public static let all: [DiagnosticCode] = [
        .legacySemantic, .legacySyntax, .notImplemented, .internalError,
        .malformedWorkflowHeader, .orphanedCodeBlock, .unparseableStatement,
        .unparseableRule, .malformedCondition, .frontmatterPlacement,
        .invalidTestSpecKey, .removedImportForm,
        .unresolvedPhrase, .unknownTool, .unknownKind, .unknownProperty,
        .unknownVocabulary, .unknownRulebook, .unknownAdjective, .unknownVerb,
        .unknownFallbackKind, .unknownTraceCategory,
        .phraseInlineDepthExceeded, .definitionRecursion, .duplicateDeclaration,
        .duplicateName, .relationBackingInvalid, .unattachedRule,
        .unresolvedTriggerAction, .toolBackedInlineDisallowed,
        .codegenError,
        .swiftFormatFailed, .vocabularyDeclarationUnrecognized, .rulebookSectionUnknown,
    ]

    /// Look up a code by its stable id (`"MER2001"`), case-insensitively.
    public static func lookup(_ id: String) -> DiagnosticCode? {
        let needle = id.uppercased()
        return all.first { $0.id == needle }
    }
}
