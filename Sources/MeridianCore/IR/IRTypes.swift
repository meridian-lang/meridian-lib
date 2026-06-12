import Foundation
import MeridianRuntime

// MARK: - IR version

public let MERIDIAN_IR_VERSION = "1.0"

// MARK: - Execution mode

public enum ExecutionMode: Sendable, Hashable {
    case strict
    case lenient
}

// MARK: - Symbol references

public struct KindRef: Sendable, Hashable {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public struct ToolRef: Sendable, Hashable {
    public let id: String
    public init(_ id: String) { self.id = id }
}

// MARK: - Core IR block and workflow

public struct IRBlock: Sendable {
    public let statements: [IRPrimitive]
    public let sourceRange: SourceRange

    public init(statements: [IRPrimitive], sourceRange: SourceRange = .unknown) {
        self.statements = statements
        self.sourceRange = sourceRange
    }
}

public struct IRWorkflow: Sendable {
    public let name: String
    public let structName: String
    public let explicitStructName: String?
    public let parameters: [IRParameter]
    public let body: IRBlock
    public let mode: ExecutionMode
    public let sourceFile: String
    public let sourceRange: SourceRange
    /// Reserved for Phase B3 — workflows that allow agent discretion.
    public let allowsDiscretion: Bool

    public init(
        name: String,
        parameters: [IRParameter],
        body: IRBlock,
        mode: ExecutionMode = .strict,
        sourceFile: String = "",
        sourceRange: SourceRange = .unknown,
        explicitStructName: String? = nil,
        allowsDiscretion: Bool = false
    ) {
        self.name = name
        self.explicitStructName = explicitStructName
        self.structName = explicitStructName ?? IRWorkflow.structName(from: name)
        self.parameters = parameters
        self.body = body
        self.mode = mode
        self.sourceFile = sourceFile
        self.sourceRange = sourceRange
        self.allowsDiscretion = allowsDiscretion
    }

    /// Derive UpperCamelCase struct name from natural-language workflow name.
    /// Delegates to the supplied lexicon; falls back to the default lexicon.
    public static func structName(from name: String, lexicon: EnglishLexicon = .default) -> String {
        lexicon.structName(from: name)
    }
}

public struct IRParameter: Sendable, Hashable {
    public let name: String
    public let kind: KindRef

    public init(name: String, kind: KindRef) {
        self.name = name
        self.kind = kind
    }
}

// MARK: - The 10 IR primitives

public indirect enum IRPrimitive: Sendable {
    case invoke(InvokeIR)
    case bind(BindIR)
    case branch(BranchIR)
    case iterate(IterateIR)
    case assert(AssertIR)
    case emit(EmitIR)
    case wait(WaitIR)
    case commit(CommitIR)
    case recover(RecoverIR)
    case simultaneously(SimultaneouslyIR)
    case proseStep(ProseStepIR)
    case complete(CompleteIR)
}

// MARK: - 1. invoke

public struct InvokeIR: Sendable {
    public let toolID: String
    public let arguments: [InvokeArg]
    public let resultBinding: String?
    public let sourceRange: SourceRange

    public init(
        toolID: String,
        arguments: [InvokeArg] = [],
        resultBinding: String? = nil,
        sourceRange: SourceRange = .unknown
    ) {
        self.toolID = toolID
        self.arguments = arguments
        self.resultBinding = resultBinding
        self.sourceRange = sourceRange
    }
}

public struct InvokeArg: Sendable {
    public let key: String
    public let value: IRExpression

    public init(_ key: String, _ value: IRExpression) {
        self.key = key
        self.value = value
    }
}

// MARK: - 2. bind

public struct BindIR: Sendable {
    public let name: String
    public let expression: IRExpression
    public let isRebind: Bool
    public let sourceRange: SourceRange

    public init(name: String, expression: IRExpression, isRebind: Bool = false, sourceRange: SourceRange = .unknown) {
        self.name = name
        self.expression = expression
        self.isRebind = isRebind
        self.sourceRange = sourceRange
    }
}

// MARK: - 3. branch

public struct BranchIR: Sendable {
    public let condition: BranchCondition
    public let thenBlock: IRBlock
    public let elseBlock: IRBlock?
    public let sourceRange: SourceRange

    public init(condition: BranchCondition, thenBlock: IRBlock, elseBlock: IRBlock? = nil, sourceRange: SourceRange = .unknown) {
        self.condition = condition
        self.thenBlock = thenBlock
        self.elseBlock = elseBlock
        self.sourceRange = sourceRange
    }
}

public indirect enum BranchCondition: Sendable {
    case predicate(IRExpression)
    case match(IRExpression, [BranchCase])
}

public struct BranchCase: Sendable {
    public let pattern: IRPattern
    public let block: IRBlock

    public init(pattern: IRPattern, block: IRBlock) {
        self.pattern = pattern
        self.block = block
    }
}

public enum IRPattern: Sendable {
    case literal(IRLiteral)
    case enumValue(String, kind: String)
    case wildcard
}

// MARK: - 4. iterate

public struct IterateIR: Sendable {
    public let mode: IterateMode
    public let body: IRBlock
    public let sourceRange: SourceRange

    public init(mode: IterateMode, body: IRBlock, sourceRange: SourceRange = .unknown) {
        self.mode = mode
        self.body = body
        self.sourceRange = sourceRange
    }
}

// MARK: - 4b. simultaneously

public struct SimultaneouslyIR: Sendable {
    public let branches: [IRBlock]
    /// When true, the branches are spawned fire-and-forget (a detached `Task`)
    /// and the workflow does NOT wait for them (no `group.waitForAll()`). Set by
    /// the `in the background, <stmt>.` surface. Defaults to false (join semantics).
    public let detached: Bool
    public let sourceRange: SourceRange

    public init(branches: [IRBlock], detached: Bool = false, sourceRange: SourceRange = .unknown) {
        self.branches = branches
        self.detached = detached
        self.sourceRange = sourceRange
    }
}

public indirect enum IterateMode: Sendable {
    case overCollection(parameter: String, kind: KindRef, collection: IRExpression)
    case whileCondition(IRExpression)
    case untilCondition(IRExpression)
}

// MARK: - 5. assert

public struct AssertIR: Sendable {
    public let condition: IRExpression
    public let message: String?
    public let otherwiseAction: IRBlock?
    public let sourceRange: SourceRange

    public init(condition: IRExpression, message: String? = nil, otherwiseAction: IRBlock? = nil, sourceRange: SourceRange = .unknown) {
        self.condition = condition
        self.message = message
        self.otherwiseAction = otherwiseAction
        self.sourceRange = sourceRange
    }
}

// MARK: - 6. emit

public struct EmitIR: Sendable {
    public let eventID: String
    public let payload: [EmitField]
    public let strict: Bool
    public let sourceRange: SourceRange

    public init(eventID: String, payload: [EmitField] = [], strict: Bool = true, sourceRange: SourceRange = .unknown) {
        self.eventID = eventID
        self.payload = payload
        self.strict = strict
        self.sourceRange = sourceRange
    }
}

public struct EmitField: Sendable {
    public let key: String
    public let value: IRExpression

    public init(_ key: String, _ value: IRExpression) {
        self.key = key
        self.value = value
    }
}

// MARK: - 7. wait

public struct WaitIR: Sendable {
    public let condition: WaitConditionIR
    public let timeout: Duration?
    public let sourceRange: SourceRange

    public init(condition: WaitConditionIR, timeout: Duration? = nil, sourceRange: SourceRange = .unknown) {
        self.condition = condition
        self.timeout = timeout
        self.sourceRange = sourceRange
    }
}

public enum WaitConditionIR: Sendable {
    case duration(Duration)
    case signal(String)
    case approval(of: IRExpression, by: String)
    case event(String, matching: IRExpression?)
    /// Choice-gate: present `options` to the user and block until the host
    /// delivers a selection (reuses the signal continuation plumbing). The
    /// chosen option is bound to `choice` in state by codegen.
    case choice(prompt: String, options: [String])
}

// MARK: - 8. commit

public struct CommitIR: Sendable {
    public let label: String?
    public let sourceRange: SourceRange

    public init(label: String? = nil, sourceRange: SourceRange = .unknown) {
        self.label = label
        self.sourceRange = sourceRange
    }
}

// MARK: - 9. recover

public struct RecoverIR: Sendable {
    public let pattern: ErrorPattern
    public let handler: IRBlock
    public let attachedTo: IRBlock
    public let sourceRange: SourceRange

    public init(pattern: ErrorPattern, handler: IRBlock, attachedTo: IRBlock, sourceRange: SourceRange = .unknown) {
        self.pattern = pattern
        self.handler = handler
        self.attachedTo = attachedTo
        self.sourceRange = sourceRange
    }
}

public enum ErrorPattern: Sendable {
    case anyError
    case named(String)
    case typed(KindRef)
    case predicate(IRExpression)
}

// MARK: - 10. complete

public struct CompleteIR: Sendable {
    public let reason: String?
    public let sourceRange: SourceRange

    public init(reason: String? = nil, sourceRange: SourceRange = .unknown) {
        self.reason = reason
        self.sourceRange = sourceRange
    }
}

// MARK: - 11. prose step

public enum ProseDispatchMode: Sendable, Equatable {
    case planThenExecute
    case autonomousLoop
}

public struct ProseStepIR: Sendable {
    public let text: String
    public let scopedTools: [String]
    public let snapshotKeys: [String]
    public let dispatchMode: ProseDispatchMode
    public let autonomy: AutonomyConfigIR?
    public let sourceRange: SourceRange

    public init(
        text: String,
        scopedTools: [String] = [],
        snapshotKeys: [String] = [],
        dispatchMode: ProseDispatchMode,
        autonomy: AutonomyConfigIR? = nil,
        sourceRange: SourceRange = .unknown
    ) {
        self.text = text
        self.scopedTools = scopedTools
        self.snapshotKeys = snapshotKeys
        self.dispatchMode = dispatchMode
        self.autonomy = autonomy
        self.sourceRange = sourceRange
    }
}

public struct AutonomyConfigIR: Sendable {
    public let until: IRExpression?
    public let unless: IRExpression?
    public let replanAfterFailures: Int
    public let maxSteps: Int

    public init(
        until: IRExpression? = nil,
        unless: IRExpression? = nil,
        replanAfterFailures: Int = 3,
        maxSteps: Int = 32
    ) {
        self.until = until
        self.unless = unless
        self.replanAfterFailures = replanAfterFailures
        self.maxSteps = maxSteps
    }
}

// MARK: - Expressions

/// B6/B7: One segment of a lowered interpolated string.
public enum IRInterpolationSegment: Sendable {
    case literal(String)
    case expression(IRExpression)
}

public indirect enum IRExpression: Sendable {
    case literal(IRLiteral)
    case constantRef(name: String)
    case identifierRef(name: String)
    /// Reference to a named instance declared in the merconfig `=== instances ===`
    /// section (e.g. "primary mailer", "stripe"). Codegen emits as
    /// `instances.primaryMailer` against the generated `Instances` struct.
    case instanceRef(name: String)
    case propertyAccess(IRExpression, propertyName: String)
    case relationTraversal(IRExpression, relationName: String, target: IRExpression?)
    case comparison(IRExpression, ComparisonOp, IRExpression)
    case logical(LogicalOp, [IRExpression])
    case envVar(name: String)
    case nowExpression
    case invocation(InvokeIR)
    /// B6/B7: Fenced code-block body with `{{ expr }}` interpolation.
    case interpolatedString([IRInterpolationSegment])
}

public enum ComparisonOp: Sendable {
    case equal, notEqual
    case lessThan, lessOrEqual
    case greaterThan, greaterOrEqual
    case oneOf
    case contains, startsWith, endsWith
    case withinDuration
}

public enum LogicalOp: Sendable {
    case and, or, not
}

public enum IRLiteral: Sendable {
    case string(String)
    case number(Decimal)
    case boolean(Bool)
    case money(Decimal, currency: String)
    case duration(Duration)
    case date(Date)
    case dateTime(Date)
    case enumValue(String, kind: String)
}

// MARK: - SourceRange convenience

extension SourceRange {
    public static let unknown = SourceRange(file: "<unknown>", line: 0, column: 0)
}
