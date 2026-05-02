import Foundation

// MARK: - MerConfig AST

/// Language-surface synonyms loaded from a `=== language ===` section in a
/// .merconfig file. Merged into the effective `EnglishLexicon` at compile time.
public struct LanguageSynonyms: Sendable {
    public let comparisonSynonyms: [(String, ComparisonOpAST)]
    public let durationSynonyms: [String: TimeUnitAST]
    public init(comparisonSynonyms: [(String, ComparisonOpAST)] = [],
                durationSynonyms: [String: TimeUnitAST] = [:]) {
        self.comparisonSynonyms = comparisonSynonyms
        self.durationSynonyms = durationSynonyms
    }
}

public struct MerConfigFile: Sendable {
    public let vocabulary: [VocabularyStatement]
    public let constants: [ConstantDeclaration]
    public let instances: [InstanceDeclaration]
    public let tools: [ToolDeclaration]
    public let languageSynonyms: LanguageSynonyms

    public init(
        vocabulary: [VocabularyStatement] = [],
        constants: [ConstantDeclaration] = [],
        instances: [InstanceDeclaration] = [],
        tools: [ToolDeclaration] = [],
        languageSynonyms: LanguageSynonyms = LanguageSynonyms()
    ) {
        self.vocabulary = vocabulary
        self.constants = constants
        self.instances = instances
        self.tools = tools
        self.languageSynonyms = languageSynonyms
    }

    /// Concatenate two parsed merconfig files, preserving declaration order
    /// (left-hand sections first). Duplicate-name detection is the caller's
    /// job — `Compiler.merge` walks the merged symbol table and rejects
    /// colliding kind / phrase / tool names with a sourced error.
    public func merging(_ other: MerConfigFile) -> MerConfigFile {
        let mergedSynonyms = LanguageSynonyms(
            comparisonSynonyms: languageSynonyms.comparisonSynonyms + other.languageSynonyms.comparisonSynonyms,
            durationSynonyms: languageSynonyms.durationSynonyms.merging(other.languageSynonyms.durationSynonyms) { _, new in new }
        )
        return MerConfigFile(
            vocabulary: vocabulary + other.vocabulary,
            constants:  constants  + other.constants,
            instances:  instances  + other.instances,
            tools:      tools      + other.tools,
            languageSynonyms: mergedSynonyms
        )
    }
}

public enum VocabularyStatement: Sendable {
    case kind(KindDeclaration)
    case property(PropertyDeclaration)
    case relation(RelationDeclaration)
    case inverse(InverseDeclaration)
    case phrase(PhraseDefinition)
}

public struct KindDeclaration: Sendable {
    public let name: String
    public let parent: String
    public let sourceLine: Int
    public init(name: String, parent: String, sourceLine: Int = 0) {
        self.name = name; self.parent = parent; self.sourceLine = sourceLine
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

public enum PropertyTypeAST: Sendable {
    case defaulted
    case explicit(String)
    case enumeration([String])
}

public struct RelationDeclaration: Sendable {
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

public struct ToolDeclaration: Sendable {
    public let displayName: String
    public let methodName: String
    public let parameters: [ToolParameterAST]
    public let returnType: String
    public let sourceLine: Int
    public init(displayName: String, methodName: String,
                parameters: [ToolParameterAST], returnType: String, sourceLine: Int = 0) {
        self.displayName = displayName; self.methodName = methodName
        self.parameters = parameters; self.returnType = returnType
        self.sourceLine = sourceLine
    }
}

public struct ToolParameterAST: Sendable {
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

public struct MeridianFile: Sendable {
    public let imports: [ImportStatementAST]
    public let rules: [RuleAST]
    public let workflows: [WorkflowAST]
    /// Optional frontmatter parsed from a `---`-delimited block at the top
    /// of the file. Nil when no frontmatter is present.
    public let metadata: FileMetadataAST?
    public let outline: [HeadingEntry]
    public init(imports: [ImportStatementAST] = [],
                rules: [RuleAST] = [],
                workflows: [WorkflowAST] = [],
                metadata: FileMetadataAST? = nil,
                outline: [HeadingEntry] = []) {
        self.imports = imports; self.rules = rules; self.workflows = workflows
        self.metadata = metadata
        self.outline = outline
    }
}

public struct ImportStatementAST: Sendable {
    public let path: String
    public let sourceLine: Int
    public init(path: String, sourceLine: Int = 0) { self.path = path; self.sourceLine = sourceLine }
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
    case emit(EmitStatementAST)
    case assertStmt(AssertStatementAST)
    case wait(WaitStatementAST)
    case commit(CommitStatementAST)
    case complete(CompleteStatementAST)
    case conditional(ConditionalStatementAST)
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
        case .emit(let s):              return s.sourceLine
        case .assertStmt(let s):        return s.sourceLine
        case .wait(let s):              return s.sourceLine
        case .commit(let s):            return s.sourceLine
        case .complete(let s):          return s.sourceLine
        case .conditional(let s):       return s.sourceLine
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
    public let sourceLine: Int
    public init(condition: WaitConditionAST, sourceLine: Int = 0) {
        self.condition = condition; self.sourceLine = sourceLine
    }
}

public enum WaitConditionAST: Sendable {
    case duration(Double, TimeUnitAST)
    case signal(String)
    case approval(subject: ExpressionAST, byRole: String)
    /// `wait for event {eventID} matching {predicate}.`
    /// `predicate` is nil when no `matching` clause is present.
    case event(String, matching: ExpressionAST?)
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

public struct ConditionalStatementAST: Sendable {
    public let condition: ExpressionAST
    public let thenBlock: ASTBlock
    public let elseBlock: ASTBlock?
    public let sourceLine: Int
    public init(condition: ExpressionAST, thenBlock: ASTBlock,
                elseBlock: ASTBlock? = nil, sourceLine: Int = 0) {
        self.condition = condition; self.thenBlock = thenBlock
        self.elseBlock = elseBlock; self.sourceLine = sourceLine
    }
}

/// Discriminates the three loop forms supported by the Meridian language.
public enum IterationModeAST: Sendable {
    case forEach(variable: String, collection: ExpressionAST)
    case whileCondition(ExpressionAST)
    case untilCondition(ExpressionAST)
}

public struct IterationStatementAST: Sendable {
    public let mode: IterationModeAST
    public let body: ASTBlock
    public let sourceLine: Int
    public init(mode: IterationModeAST, body: ASTBlock, sourceLine: Int = 0) {
        self.mode = mode; self.body = body; self.sourceLine = sourceLine
    }
    /// Backward-compatible accessor — non-nil only for `.forEach` loops.
    public var variable: String? {
        if case .forEach(let v, _) = mode { return v }
        return nil
    }
    /// Backward-compatible accessor — non-nil only for `.forEach` loops.
    public var collection: ExpressionAST? {
        if case .forEach(_, let c) = mode { return c }
        return nil
    }
}

public struct SimultaneouslyStatementAST: Sendable {
    public let branches: [ASTBlock]
    public let sourceLine: Int
    public init(branches: [ASTBlock], sourceLine: Int = 0) {
        self.branches = branches
        self.sourceLine = sourceLine
    }
}

public struct PhraseInvocationAST: Sendable {
    public let words: String
    public let sourceLine: Int
    public init(words: String, sourceLine: Int = 0) {
        self.words = words; self.sourceLine = sourceLine
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

public struct ProseStepAST: Sendable {
    public let text: String
    public let sourceLine: Int

    public init(text: String, sourceLine: Int = 0) {
        self.text = text
        self.sourceLine = sourceLine
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
}

public enum LiteralAST: Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case money(Double, currency: String)
    case duration(Double, TimeUnitAST)
}

public enum ComparisonOpAST: Sendable {
    case equal, notEqual
    case lessThan, lessOrEqual
    case greaterThan, greaterOrEqual
    case within
}

public enum LogicalOpAST: Sendable { case and, or, not }
