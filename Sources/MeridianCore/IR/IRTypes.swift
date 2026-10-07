import Foundation
import MeridianRuntime

// MARK: - IR version

public let MERIDIAN_IR_VERSION = "1.1"

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
    public let skillName: String
    public let skillVersionHash: String
    public let runtimeTraceConfiguration: RuntimeTraceConfiguration?
    public let norms: [NormIR]

    public init(
        name: String,
        parameters: [IRParameter],
        body: IRBlock,
        mode: ExecutionMode = .strict,
        sourceFile: String = "",
        sourceRange: SourceRange = .unknown,
        explicitStructName: String? = nil,
        allowsDiscretion: Bool = false,
        skillName: String? = nil,
        skillVersionHash: String = "unknown",
        runtimeTraceConfiguration: RuntimeTraceConfiguration? = nil,
        norms: [NormIR] = []
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
        self.skillName = skillName ?? name
        self.skillVersionHash = skillVersionHash
        self.runtimeTraceConfiguration = runtimeTraceConfiguration
        self.norms = norms
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

// MARK: - The 12 IR primitives

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
    case aiJudgment(AIJudgmentIR)
    case aiAutonomy(AIAutonomyIR)
    case complete(CompleteIR)
}

// MARK: - 1. invoke

public struct InvokeIR: Sendable {
    public let toolID: String
    public let arguments: [InvokeArg]
    public let resultBinding: String?
    /// A human-readable note (1A command annotation) emitted as a `//` comment
    /// above the call. Payload extension only — does not affect execution.
    public let comment: String?
    public let sourceRange: SourceRange
    public let stableStepPath: String?

    public init(
        toolID: String,
        arguments: [InvokeArg] = [],
        resultBinding: String? = nil,
        comment: String? = nil,
        sourceRange: SourceRange = .unknown,
        stableStepPath: String? = nil
    ) {
        self.toolID = toolID
        self.arguments = arguments
        self.resultBinding = resultBinding
        self.comment = comment
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
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
    public let stableStepPath: String?

    public init(name: String, expression: IRExpression, isRebind: Bool = false, sourceRange: SourceRange = .unknown, stableStepPath: String? = nil) {
        self.name = name
        self.expression = expression
        self.isRebind = isRebind
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
    }
}

public enum UnknownHandlingPolicyIR: Sendable, Equatable {
  case explicit
  case asTrue
  case asFalse
}

// MARK: - 3. branch

/// D11 authored-form metadata: `unless` and `if not` lower to the same
/// negated predicate but verbalize with the keyword the author used.
public enum BranchAuthoredForm: String, Sendable, Equatable, Codable {
    case ifPositive
    case ifNot
    case unlessHeader
    case unlessSuffix
}

public struct BranchIR: Sendable {
    public let condition: BranchCondition
    public let thenBlock: IRBlock
    public let unknownBlock: IRBlock?
    public let elseBlock: IRBlock?
    public let unknownPolicy: UnknownHandlingPolicyIR
    public let authoredForm: BranchAuthoredForm
    public let deonticGuard: DeonticGuardIR?
    public let sourceRange: SourceRange
    public let stableStepPath: String?

    public init(
        condition: BranchCondition,
        thenBlock: IRBlock,
        unknownBlock: IRBlock? = nil,
        elseBlock: IRBlock? = nil,
        unknownPolicy: UnknownHandlingPolicyIR = .explicit,
        authoredForm: BranchAuthoredForm = .ifPositive,
        deonticGuard: DeonticGuardIR? = nil,
        sourceRange: SourceRange = .unknown,
        stableStepPath: String? = nil
    ) {
        self.condition = condition
        self.thenBlock = thenBlock
        self.unknownBlock = unknownBlock
        self.elseBlock = elseBlock
        self.unknownPolicy = unknownPolicy
        self.authoredForm = authoredForm
        self.deonticGuard = deonticGuard
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
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
    /// Optional single-clause refinement applied to an `overCollection` source
    /// before iterating: `whose`/temporal filters, a `sorted by` order, and a
    /// `first N` prefix. `nil` preserves today's plain-iteration behavior.
    public let source: IRIterationRefinement?
    public let sourceRange: SourceRange
    public let stableStepPath: String?

    public init(mode: IterateMode, body: IRBlock,
                source: IRIterationRefinement? = nil,
                sourceRange: SourceRange = .unknown,
                stableStepPath: String? = nil) {
        self.mode = mode
        self.body = body
        self.source = source
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
    }
}

/// A refinement over an `overCollection` iteration source. Filters are applied
/// (conjunctively) first, then sorting, then the `take` prefix — so `first N`
/// counts post-filter. All fields are expressed relative to the loop variable.
public struct IRIterationRefinement: Sendable {
    public let filters: [IRExpression]
    public let sort: (path: String, ascending: Bool)?
    public let take: Int?
    public let takeFromEnd: Int?

    public init(filters: [IRExpression] = [],
                sort: (path: String, ascending: Bool)? = nil,
                take: Int? = nil,
                takeFromEnd: Int? = nil) {
        self.filters = filters
        self.sort = sort
        self.take = take
        self.takeFromEnd = takeFromEnd
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
    public let stableStepPath: String?

    public init(branches: [IRBlock], detached: Bool = false, sourceRange: SourceRange = .unknown, stableStepPath: String? = nil) {
        self.branches = branches
        self.detached = detached
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
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
    public let monitored: Bool
    public let cadence: Duration?
    public let blocking: Bool
    public let normID: String?
    public let violationDisposition: ViolationDisposition?
    public let sourceRange: SourceRange
    public let stableStepPath: String?

    public init(
        condition: IRExpression,
        message: String? = nil,
        otherwiseAction: IRBlock? = nil,
        monitored: Bool = false,
        cadence: Duration? = nil,
        blocking: Bool = false,
        normID: String? = nil,
        violationDisposition: ViolationDisposition? = nil,
        sourceRange: SourceRange = .unknown,
        stableStepPath: String? = nil
    ) {
        self.condition = condition
        self.message = message
        self.otherwiseAction = otherwiseAction
        self.monitored = monitored
        self.cadence = cadence
        self.blocking = blocking
        self.normID = normID
        self.violationDisposition = violationDisposition
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
    }
}

// MARK: - 6. emit

public struct EmitIR: Sendable {
    public let eventID: String
    public let payload: [EmitField]
    public let strict: Bool
    public let sourceRange: SourceRange
    public let stableStepPath: String?

    public init(eventID: String, payload: [EmitField] = [], strict: Bool = true, sourceRange: SourceRange = .unknown, stableStepPath: String? = nil) {
        self.eventID = eventID
        self.payload = payload
        self.strict = strict
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
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
    public let stableStepPath: String?

    public init(condition: WaitConditionIR, timeout: Duration? = nil, sourceRange: SourceRange = .unknown, stableStepPath: String? = nil) {
        self.condition = condition
        self.timeout = timeout
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
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
    public let stableStepPath: String?

    public init(label: String? = nil, sourceRange: SourceRange = .unknown, stableStepPath: String? = nil) {
        self.label = label
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
    }
}

// MARK: - 9. recover

public struct RecoverIR: Sendable {
    public let pattern: ErrorPattern
    public let handler: IRBlock
    public let attachedTo: IRBlock
    public let sourceRange: SourceRange
    public let stableStepPath: String?

    public init(pattern: ErrorPattern, handler: IRBlock, attachedTo: IRBlock, sourceRange: SourceRange = .unknown, stableStepPath: String? = nil) {
        self.pattern = pattern
        self.handler = handler
        self.attachedTo = attachedTo
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
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
    public let stableStepPath: String?

    public init(reason: String? = nil, sourceRange: SourceRange = .unknown, stableStepPath: String? = nil) {
        self.reason = reason
        self.sourceRange = sourceRange
        self.stableStepPath = stableStepPath
    }
}

// MARK: - 11. AI-routed primitives (judgment / autonomy)

/// Distinguishes the two AI-routed dispatch shapes at the AST/lowering
/// boundary (a workflow inherits one of these from `with discretion` /
/// `with autonomy`, or a local marker sets it explicitly). Once lowered, the
/// distinction is structural — `IRPrimitive.aiJudgment` vs `.aiAutonomy` —
/// not carried as a field on a single generic primitive.
public enum ProseDispatchMode: Sendable, Equatable {
    case planThenExecute
    case autonomousLoop
}

/// AI-routed step under judgment/discretion (`use judgment to …:`, `with
/// discretion`, `ai-discretion` table/checklist routing). Codegen calls
/// `runtime.executeProsePlan(...)` — a single plan-then-execute pass with no
/// autonomous retry loop, so this primitive carries no `AutonomyConfigIR`.
public struct AIJudgmentIR: Sendable {
    public let text: String
    public let scopedTools: [String]
    public let snapshotKeys: [String]
    public let sourceRange: SourceRange
    /// Optional planner context distinct from `text`'s dispatch goal — e.g. a
    /// migrated section's inert narrative, carried verbatim so the planner
    /// sees the original documentation behind a judgment step.
    public let guidance: String?
    public let stableStepPath: String?
    /// SEM-4-04's "declared output kind" witness. The language has no surface
    /// syntax yet to declare a single-value judgment output kind (the
    /// northstar `producing a <kind> called <name>` clause is not implemented),
    /// so this is the true structural contract of every judgment primitive
    /// today: `executeProsePlan` always returns a `[String: Value]` of named
    /// action bindings, i.e. a record. Kept as a real (not `nil`/placeholder)
    /// field so a future single-value output syntax has somewhere to land.
    public let outputKind: String

    public init(
        text: String,
        scopedTools: [String] = [],
        snapshotKeys: [String] = [],
        sourceRange: SourceRange = .unknown,
        guidance: String? = nil,
        stableStepPath: String? = nil,
        outputKind: String = "record"
    ) {
        self.text = text
        self.scopedTools = scopedTools
        self.snapshotKeys = snapshotKeys
        self.sourceRange = sourceRange
        self.guidance = guidance
        self.stableStepPath = stableStepPath
        self.outputKind = outputKind
    }
}

/// AI-routed step under autonomy (`with autonomy …:`, inherited autonomy
/// prose, `ai-autonomy` table/checklist routing). Codegen calls
/// `runtime.executeAutonomousLoop(...)`, re-planning within
/// `AutonomyConfigIR`'s bounds until `until`/`unless` resolves.
public struct AIAutonomyIR: Sendable {
    public let text: String
    public let scopedTools: [String]
    public let snapshotKeys: [String]
    public let autonomy: AutonomyConfigIR
    public let sourceRange: SourceRange
    /// See `AIJudgmentIR.guidance` — same purpose, carried on the autonomy
    /// primitive too since a migrated section can lower to either mode.
    public let guidance: String?
    public let stableStepPath: String?
    /// See `AIJudgmentIR.outputKind` — same SEM-4-04 witness, same structural
    /// default (`executeAutonomousLoop` also returns a `[String: Value]`).
    public let outputKind: String

    public init(
        text: String,
        scopedTools: [String] = [],
        snapshotKeys: [String] = [],
        autonomy: AutonomyConfigIR = AutonomyConfigIR(),
        sourceRange: SourceRange = .unknown,
        guidance: String? = nil,
        stableStepPath: String? = nil,
        outputKind: String = "record"
    ) {
        self.text = text
        self.scopedTools = scopedTools
        self.snapshotKeys = snapshotKeys
        self.autonomy = autonomy
        self.sourceRange = sourceRange
        self.guidance = guidance
        self.stableStepPath = stableStepPath
        self.outputKind = outputKind
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
    case conditional(condition: IRExpression, then: [IRInterpolationSegment], otherwise: [IRInterpolationSegment])
    case forEach(variable: String, collection: IRExpression, body: [IRInterpolationSegment])
    case formatted(IRExpression, formatter: String)
    /// A command hole (1B) that sits inside a double-quoted span of a shell
    /// command: its value is shell-escaped (for use within `"…"`) by the
    /// emitted `meridianShellQuote` helper rather than interpolated verbatim.
    case shellEscapedExpression(IRExpression)
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
    /// Data table: a list of records sharing `fields`, one record per row.
    /// Emitted as `.list([.record([...]), ...])`.
    case recordList(fields: [String], rows: [[IRExpression]])
    /// Wave 4B: deterministic lookup in a named data table.
    case tableLookup(table: String, keyColumn: String, key: IRExpression, valueColumn: String)
    /// 2B: A checkable adjective predicate (`X is stale`). `functionName` is the
    /// precomputed `meridianDef_<Kind>_<adjCamel>` helper; `subject` is the
    /// value the predicate runs over. The emitter needs no definition registry.
    case definitionPredicate(functionName: String, subject: IRExpression)
    /// 2C: A quantified description, emitted as a single-expression IIFE so it
    /// slots into any condition position (`if`, `assert`, `whose`, …).
    case quantified(QuantifierIR)
    /// 3C: A description used as a value — emitted as a `Value.list(...)` of the
    /// fetched-once, filtered, sorted, taken element set.
    case description(DescriptionIR)
    /// 3C: An aggregate over a description. `.count` emits a bare `Int`
    /// expression (so it composes with numeric comparisons); `.list` emits a
    /// `Value.list(...)`.
    case aggregate(AggregateKind, DescriptionIR)
    /// 3C: A superlative — a description reduced to a single element by a sort
    /// key, emitted as `(…).sorted{…}.first` (a `Value?`).
    case superlative(SuperlativeIR)
    case eventPattern(EventPatternIR)
    case traceTemporal(TraceTemporalIR)
    case traceStatistical(TraceStatisticalIR)
}

public struct EventPatternIR: Sendable {
    public enum Subject: Sendable {
        case step(String)
        case named(String)
    }

    public enum OutcomeVerb: String, Sendable {
        case failed
        case succeeded
        case invoked
        case emitted
        case prevented
        case violated
        case occurred
    }

    public let subject: Subject
    public let outcome: OutcomeVerb
    public let payloadPredicate: IRExpression?
    /// `no <event pattern>` event-negation reading (see `EventPatternAST.negated`).
    public let negated: Bool

    public init(subject: Subject, outcome: OutcomeVerb, payloadPredicate: IRExpression? = nil, negated: Bool = false) {
        self.subject = subject
        self.outcome = outcome
        self.payloadPredicate = payloadPredicate
        self.negated = negated
    }
}

public enum TraceScope: Sendable, Equatable {
    case currentRun
    case acrossAllRuns
    case acrossSkills([String])
}

public enum TraceCountComparatorIR: Sendable {
    case atLeast(Int)
    case atMost(Int)
    case exactly(Int)
}

public indirect enum TraceTemporalKind: Sendable {
    case ever(EventPatternIR)
    case withinWindow(EventPatternIR, duration: Duration)
    case countInWindow(EventPatternIR, comparator: TraceCountComparatorIR, duration: Duration)
    case inARow(EventPatternIR, count: Int)
    /// `since the last <anchor>, <holds>`. `holds` keeps the authored predicate
    /// (an event pattern, or an adjective whose body is a `has ever` event
    /// query) so the verbalizer can round-trip the surface form; `holdsPattern`
    /// is the event pattern that predicate resolves to, which is what the
    /// runtime/emitter evaluate. Lowering guarantees the two agree and rejects a
    /// pure state predicate with MER-TMP-019 unless state-history retention is
    /// enabled for the keyed subject (SEM-4-12 / SEM-5-13).
    case sinceLast(anchor: EventPatternIR, holds: IRExpression, holdsPattern: EventPatternIR?, holdsUsesStateHistory: Bool)
    /// Bounded future monitor (SEM-5-12): Contract/obligation contexts only.
    case boundedFutureMonitor(condition: IRExpression, horizon: Duration, mode: FutureMonitorModeIR)
}

public enum FutureMonitorModeIR: Sendable, Equatable {
    case eventuallyWithin
    case alwaysFor
}

public struct TraceTemporalIR: Sendable {
    public let scope: TraceScope
    public let kind: TraceTemporalKind
    public let subjectKeyExpr: IRExpression?

    public init(scope: TraceScope = .currentRun, kind: TraceTemporalKind, subjectKeyExpr: IRExpression? = nil) {
        self.scope = scope
        self.kind = kind
        self.subjectKeyExpr = subjectKeyExpr
    }
}

public struct TraceStatisticalPatternIR: Sendable {
    public let subject: EventPatternIR.Subject
    public let payloadPredicate: IRExpression?

    public init(subject: EventPatternIR.Subject, payloadPredicate: IRExpression? = nil) {
        self.subject = subject
        self.payloadPredicate = payloadPredicate
    }
}

public enum TraceStatisticalOutcomeIR: Sendable, Equatable {
    case succeeds
    case fails
}

public enum TraceStatisticalBoundIR: Sendable, Equatable {
    case atLeast(Double)
    case atMost(Double)
}

public enum TraceStatisticalDenominatorIR: Sendable, Equatable {
    case runs
    case occurrences
}

public struct TraceStatisticalIR: Sendable {
    public let scope: TraceScope
    public let pattern: TraceStatisticalPatternIR
    public let outcome: TraceStatisticalOutcomeIR
    public let bound: TraceStatisticalBoundIR
    public let denominator: TraceStatisticalDenominatorIR
    public let window: Duration?
    public let monitorCadence: Duration?
    public let blocking: Bool
    public let confidencePercent: Double?
    public let subjectKeyExpr: IRExpression?

    public init(
        scope: TraceScope = .currentRun,
        pattern: TraceStatisticalPatternIR,
        outcome: TraceStatisticalOutcomeIR,
        bound: TraceStatisticalBoundIR,
        denominator: TraceStatisticalDenominatorIR,
        window: Duration? = nil,
        monitorCadence: Duration? = nil,
        blocking: Bool = false,
        confidencePercent: Double? = nil,
        subjectKeyExpr: IRExpression? = nil
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
        self.subjectKeyExpr = subjectKeyExpr
    }
}

public enum AggregateKind: Sendable, Equatable { case count, list }

/// 3C: a lowered superlative (description + sort key + direction → first).
public struct SuperlativeIR: Sendable {
    public let description: DescriptionIR
    public let sortPath: String
    public let ascending: Bool
    public init(description: DescriptionIR, sortPath: String, ascending: Bool) {
        self.description = description; self.sortPath = sortPath; self.ascending = ascending
    }
}

// MARK: - 2C. Quantifiers (IR)

public enum QuantifierKind: Sendable, Equatable {
    case all
    case any
    case none
    case atLeast(Int)
    case atMost(Int)
    case exactly(Int)
}

/// A lowered description: a fetched-once `collection` source, an `elementVar`
/// binding, and a conjunction of element-context `filters` (adjectives →
/// `.definitionPredicate`, `whose` → qualified comparison/logical).
public struct DescriptionIR: Sendable {
    public let collection: IRExpression
    public let elementVar: String
    public let filters: [IRExpression]
    /// 3C: a post-filter total order (`sorted by <path>`).
    public let sort: (path: String, ascending: Bool)?
    /// 3C: a post-sort `first N` take-prefix.
    public let take: Int?
    /// 3C: a post-sort `the last N` take-suffix.
    public let takeFromEnd: Int?
    public init(collection: IRExpression, elementVar: String, filters: [IRExpression] = [],
                sort: (path: String, ascending: Bool)? = nil, take: Int? = nil,
                takeFromEnd: Int? = nil) {
        self.collection = collection; self.elementVar = elementVar; self.filters = filters
        self.sort = sort; self.take = take; self.takeFromEnd = takeFromEnd
    }
}

public struct QuantifierIR: Sendable {
    public let kind: QuantifierKind
    public let description: DescriptionIR
    /// Per-element body predicate (element context). Optional for `any`/`none`.
    public let body: IRExpression?
    public init(kind: QuantifierKind, description: DescriptionIR, body: IRExpression? = nil) {
        self.kind = kind; self.description = description; self.body = body
    }
}

/// 2B: A lowered checkable-adjective definition, ready for codegen. The emitter
/// produces `private func <functionName>(_ __subject: Value?) -> Bool { return
/// <body in element context over subjectVar> }`.
public struct LoweredDefinition: Sendable {
    public let functionName: String
    public let subjectVar: String
    public let body: IRExpression
    public init(functionName: String, subjectVar: String, body: IRExpression) {
        self.functionName = functionName; self.subjectVar = subjectVar; self.body = body
    }
}

// MARK: - Deontic norms (Wave 9A)

public struct ActionArgumentConstraint: Sendable {
    public let path: String
    public let op: ComparisonOp
    public let value: IRExpression

    public init(path: String, op: ComparisonOp, value: IRExpression) {
        self.path = path
        self.op = op
        self.value = value
    }
}

public struct ActionPatternIR: Sendable {
    public let toolID: String
    public let argumentConstraints: [ActionArgumentConstraint]

    public init(toolID: String, argumentConstraints: [ActionArgumentConstraint] = []) {
        self.toolID = toolID
        self.argumentConstraints = argumentConstraints
    }
}

public enum NormKind: String, Sendable, Hashable {
    case prohibition
    case obligation
    case permission
}

public enum NormScope: Sendable, Hashable {
    case skill
    case workflow(String)
    case section(stablePath: String)
    case kind(String)
}

public struct NormIR: Sendable {
    public let id: String
    public let kind: NormKind
    public let scope: NormScope
    public let actionPattern: ActionPatternIR?
    public let condition: IRExpression?
    public let blocking: Bool
    public let sourceRange: SourceRange
    public let originalText: String

    public init(
        id: String = "",
        kind: NormKind,
        scope: NormScope,
        actionPattern: ActionPatternIR? = nil,
        condition: IRExpression? = nil,
        blocking: Bool = false,
        sourceRange: SourceRange,
        originalText: String
    ) {
        self.id = id
        self.kind = kind
        self.scope = scope
        self.actionPattern = actionPattern
        self.condition = condition
        self.blocking = blocking
        self.sourceRange = sourceRange
        self.originalText = originalText
    }
}

public enum ViolationDisposition: String, Sendable, Hashable {
    case prevented
    case observed
}

public struct DeonticGuardIR: Sendable {
    public let normID: String
    public let disposition: ViolationDisposition
    public let blocking: Bool
    public let actionPattern: ActionPatternIR

    public init(
        normID: String,
        disposition: ViolationDisposition,
        blocking: Bool,
        actionPattern: ActionPatternIR
    ) {
        self.normID = normID
        self.disposition = disposition
        self.blocking = blocking
        self.actionPattern = actionPattern
    }
}

public enum ComparisonOp: Sendable {
    case equal, notEqual
    case lessThan, lessOrEqual
    case greaterThan, greaterOrEqual
    case oneOf
    case contains, startsWith, endsWith
    case withinDuration
    /// One-sided temporal windows (1C `within the last` / `in the next`).
    case withinPast, withinFuture
    /// Regex match (1D output invariant `matches pattern "<regex>"`).
    case matchesPattern
    /// 2 (shared condition grammar): property-backed emptiness checks. The RHS
    /// operand is unused (a `.literal(.boolean(true))` placeholder).
    case isEmpty, isNotEmpty
    /// 3B: relation link identity (`page.owner identifies user`). LHS is the
    /// link property (scalar or list); RHS is the entity being matched. Lowered
    /// from active verb predicates and property-backed verb clauses.
    case identifies
}

public enum LogicalOp: Sendable {
    case and, or, not
}

public struct CalendarAmountIR: Sendable, Equatable {
    public enum Unit: String, Sendable, Equatable {
        case businessDays
        case calendarDays
        case months
    }

    public let magnitude: Double
    public let unit: Unit

    public init(magnitude: Double, unit: Unit) {
        self.magnitude = magnitude
        self.unit = unit
    }
}

public enum IRLiteral: Sendable {
    case string(String)
    case number(Decimal)
    case boolean(Bool)
    case money(Decimal, currency: String)
    case duration(Duration)
    case calendarAmount(CalendarAmountIR)
    case date(Date)
    case dateTime(Date)
    case enumValue(String, kind: String)
}

// MARK: - SourceRange convenience

extension SourceRange {
    public static let unknown = SourceRange(file: "<unknown>", line: 0, column: 0)
}
