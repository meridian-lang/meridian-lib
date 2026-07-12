import ArgumentParser
import Foundation
import MeridianCore
import MeridianRuntime

public struct TraceEvalCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "trace-eval",
        abstract: "Replay-evaluate a trace-temporal or trace-statistical expression."
    )

    @Argument(help: "Path to a semantic trace-store .jsonl file.")
    var input: String

    @Argument(help: "Expression to evaluate against the stored trace.")
    var expression: String

    @Option(name: .customLong("at"), help: "Replay instant as an ISO8601 timestamp.")
    var instant: String

    @Option(name: [.customLong("merconfig"), .customLong("vocab")], help: "Optional merconfig file(s) used when parsing the expression.")
    var merconfig: [String] = []

    @Option(name: .customLong("format"), help: "Output format: json or text.")
    var format: TraceEvalOutputFormat = .text

    @OptionGroup var cliTrace: CLITraceOptions

    public func run() async throws {
        try await TraceEvalRunner.run(
            input: input,
            expression: expression,
            instant: instant,
            merconfig: merconfig,
            format: format,
            trace: try cliTrace.makeTrace()
        )
    }
}

enum TraceEvalOutputFormat: String, ExpressibleByArgument {
    case json
    case text
}

enum TraceEvalRunner {
    struct JSONReport: Encodable, Equatable {
        let expression: String
        let instant: String
        let queryType: String
        let scope: String
        let truthValue: String
        let witnessEventIDs: [String]

        enum CodingKeys: String, CodingKey {
            case expression
            case instant
            case queryType = "query_type"
            case scope
            case truthValue = "truth_value"
            case witnessEventIDs = "witness_event_ids"
        }
    }

    struct ReplayPlan {
        enum QueryKind {
            case temporal(TraceTemporalQuery)
            case statistical(TraceStatisticalQuery)

            var typeLabel: String {
                switch self {
                case .temporal:
                    return "temporal"
                case .statistical:
                    return "statistical"
                }
            }

            var scope: MeridianRuntime.TraceScope {
                switch self {
                case .temporal(let query):
                    return query.scope
                case .statistical(let query):
                    return query.scope
                }
            }
        }

        let canonicalExpression: String
        let query: QueryKind
        let sampleFloor: Int
    }

    struct ReplayContext {
        let runID: String?
        let skillName: String
    }

    static func run(
        input: String,
        expression: String,
        instant: String,
        merconfig: [String],
        format: TraceEvalOutputFormat,
        trace: ParserTrace
    ) async throws {
        let fileURL = URL(fileURLWithPath: input).standardizedFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ValidationError("File not found: \(input)")
        }

        let evaluationInstant = try parseInstant(instant)
        let vocabularies = try DependencyDiscovery.loadVocabularies(try merconfig.map(existingURL(path:)))
        let plan = try makeReplayPlan(expression: expression, vocabularies: vocabularies, trace: trace)
        let store = try JSONLTraceStore(fileURL: fileURL)
        let context = try await inferReplayContext(store: store, scope: plan.query.scope)
        let replayContext = TraceEvaluationContext(
            runID: context.runID,
            skillName: context.skillName,
            evaluationInstant: evaluationInstant,
            sampleFloor: plan.sampleFloor
        )

        let replayResult: TraceReplayResult
        switch plan.query {
        case .temporal(let query):
            replayResult = try await TraceEvaluator.replay(temporal: query, store: store, context: replayContext)
        case .statistical(let query):
            replayResult = try await TraceEvaluator.replay(statistical: query, store: store, context: replayContext)
        }

        let report = JSONReport(
            expression: plan.canonicalExpression,
            instant: ISO8601DateFormatter.meridianFormatter.string(from: evaluationInstant),
            queryType: plan.query.typeLabel,
            scope: traceScopeLabel(plan.query.scope),
            truthValue: replayResult.truthValue.rawValue,
            witnessEventIDs: replayResult.witnessEventIDs
        )

        switch format {
        case .json:
            try emitJSON(report)
        case .text:
            emitText(report)
        }
    }

    static func makeReplayPlan(
        expression: String,
        vocabularies: [Compiler.VocabularyInput],
        trace: ParserTrace
    ) throws -> ReplayPlan {
        let compiler = Compiler(options: .init(trace: trace))
        let knowledge = try compiler.knowledge(
            forSource: "",
            sourceFile: "<trace-eval>",
            vocabularies: vocabularies
        )
        let parsed = ExpressionParser(
            symbols: knowledge.symbols,
            trace: trace,
            lexicon: knowledge.lexicon
        ).parse(expression)
        let lowered = try ASTToIR(
            symbols: knowledge.symbols,
            sourceFile: "<trace-eval>",
            trace: trace,
            lexicon: knowledge.lexicon,
            rulebook: knowledge.rulebook
        ).lowerExpression(parsed, line: 1)
        let canonical = Verbalizer(model: VerbalizerModel(
            workflows: [],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: knowledge.symbols,
            lexicon: knowledge.lexicon,
            sourceFileName: "<trace-eval>",
            authoredSource: expression
        ), trace: trace).verbalize(lowered)

        switch lowered {
        case .traceTemporal(let temporal):
            return ReplayPlan(
                canonicalExpression: canonical,
                query: .temporal(try runtimeTemporalQuery(from: temporal)),
                sampleFloor: knowledge.symbols.traceConfiguration.sampleFloor?.value ?? TraceConfiguration.default.sampleFloor
            )
        case .traceStatistical(let statistical):
            return ReplayPlan(
                canonicalExpression: canonical,
                query: .statistical(try runtimeStatisticalQuery(from: statistical)),
                sampleFloor: knowledge.symbols.traceConfiguration.sampleFloor?.value ?? TraceConfiguration.default.sampleFloor
            )
        default:
            throw ValidationError("Expression must lower to a trace-temporal or trace-statistical query.")
        }
    }

    static func runtimeTemporalQuery(from temporal: TraceTemporalIR) throws -> TraceTemporalQuery {
        let kind: TraceTemporalQuery.Kind
        switch temporal.kind {
        case .ever(let pattern):
            kind = .ever(try runtimePattern(from: pattern))
        case .withinWindow(let pattern, let duration):
            kind = .withinWindow(try runtimePattern(from: pattern), duration: duration)
        case .countInWindow(let pattern, let comparator, let duration):
            kind = .countInWindow(
                try runtimePattern(from: pattern),
                comparator: runtimeComparator(from: comparator),
                duration: duration
            )
        case .inARow(let pattern, let count):
            kind = .inARow(try runtimePattern(from: pattern), count: count)
        case .sinceLast(let anchor, _, let holdsPattern):
            kind = .sinceLast(
                anchor: try runtimePattern(from: anchor),
                holds: try runtimePattern(from: holdsPattern)
            )
        }
        return TraceTemporalQuery(scope: runtimeScope(from: temporal.scope), kind: kind)
    }

    static func runtimeStatisticalQuery(from statistical: TraceStatisticalIR) throws -> TraceStatisticalQuery {
        return TraceStatisticalQuery(
            scope: runtimeScope(from: statistical.scope),
            pattern: TraceEventPatternQuery(
                subject: runtimeSubject(from: statistical.pattern.subject),
                outcome: statistical.outcome == .succeeds ? .succeeded : .failed,
                subjectKey: nil,
                payloadContains: try runtimePayloadContains(from: statistical.pattern.payloadPredicate)
            ),
            bound: runtimeBound(from: statistical.bound),
            denominator: statistical.denominator == .runs ? .runs : .occurrences,
            window: statistical.window
        )
    }

    static func runtimePattern(from pattern: EventPatternIR) throws -> TraceEventPatternQuery {
        TraceEventPatternQuery(
            subject: runtimeSubject(from: pattern.subject),
            outcome: runtimeOutcome(from: pattern.outcome),
            subjectKey: nil,
            payloadContains: try runtimePayloadContains(from: pattern.payloadPredicate),
            negated: pattern.negated
        )
    }

    /// Interpret a lowered `whose <field> is <value>` payload predicate
    /// directly into the runtime store's `payloadContains` shape (no codegen
    /// involved on this path — `trace-eval` replays against a stored JSONL
    /// trace, not a compiled workflow).
    static func runtimePayloadContains(from predicate: IRExpression?) throws -> [String: Value]? {
        guard let predicate else { return nil }
        guard case .comparison(let lhs, .equal, let rhs) = predicate,
              case .identifierRef(let field) = lhs,
              case .literal(let literal) = rhs,
              let value = runtimeLiteralValue(literal) else {
            throw ValidationError("`trace-eval` only supports simple `whose <field> is <value>` payload predicates.")
        }
        return [field: value]
    }

    static func runtimeLiteralValue(_ literal: IRLiteral) -> Value? {
        switch literal {
        case .string(let value): return .string(value)
        case .number(let value): return .number(value)
        case .boolean(let value): return .boolean(value)
        case .money(let amount, let currency): return .money(Money(amount: amount, currency: currency))
        case .duration(let duration): return .duration(duration)
        case .date(let date): return .date(date)
        case .dateTime(let date): return .dateTime(date)
        case .enumValue(let value, let kind): return .enumValue(value, kind: kind)
        }
    }

    static func runtimeSubject(from subject: EventPatternIR.Subject) -> TraceEventPatternQuery.Subject {
        switch subject {
        case .step(let name):
            return .step(name)
        case .named(let name):
            return .named(name)
        }
    }

    static func runtimeOutcome(from outcome: EventPatternIR.OutcomeVerb) -> TraceEventPatternQuery.Outcome {
        switch outcome {
        case .failed:
            return .failed
        case .succeeded:
            return .succeeded
        case .invoked:
            return .invoked
        case .emitted:
            return .emitted
        case .prevented:
            return .prevented
        case .violated:
            return .violated
        case .occurred:
            return .occurred
        }
    }

    static func runtimeComparator(from comparator: TraceCountComparatorIR) -> TraceCountComparator {
        switch comparator {
        case .atLeast(let count):
            return .atLeast(count)
        case .atMost(let count):
            return .atMost(count)
        case .exactly(let count):
            return .exactly(count)
        }
    }

    static func runtimeBound(from bound: TraceStatisticalBoundIR) -> TraceStatisticalBound {
        switch bound {
        case .atLeast(let value):
            return .atLeast(value)
        case .atMost(let value):
            return .atMost(value)
        }
    }

    static func inferReplayContext(
        store: any TraceStore,
        scope: MeridianRuntime.TraceScope
    ) async throws -> ReplayContext {
        let records = try await store.query(
            scope: .acrossAllRuns,
            runID: nil,
            skillName: nil,
            window: nil,
            pattern: nil
        )
        guard !records.isEmpty else {
            throw ValidationError("Trace store is empty.")
        }
        let skillNames = Array(Set(records.map(\.skillName))).sorted()
        guard skillNames.count == 1, let skillName = skillNames.first else {
            throw ValidationError("Trace store must contain exactly one skill name for replay evaluation.")
        }
        switch scope {
        case .acrossAllRuns:
            return ReplayContext(runID: nil, skillName: skillName)
        case .currentRun:
            let runIDs = Array(Set(records.map(\.run))).sorted()
            guard runIDs.count == 1, let runID = runIDs.first else {
                throw ValidationError("Current-run replay requires a trace store containing exactly one run.")
            }
            return ReplayContext(runID: runID, skillName: skillName)
        }
    }

    static func parseInstant(_ text: String) throws -> Date {
        if let parsed = ISO8601DateFormatter.meridianFormatter.date(from: text) {
            return parsed
        }
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        if let parsed = fallback.date(from: text) {
            return parsed
        }
        throw ValidationError("Invalid ISO8601 instant for --at: \(text)")
    }

    static func emitJSON(_ report: JSONReport) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    static func emitText(_ report: JSONReport) {
        var lines: [String] = []
        lines.append("Trace evaluation")
        lines.append("Expression: \(report.expression)")
        lines.append("Instant: \(report.instant)")
        lines.append("Type: \(report.queryType)")
        lines.append("Scope: \(report.scope)")
        lines.append("Truth value: \(report.truthValue)")
        if report.witnessEventIDs.isEmpty {
            lines.append("Witness event IDs: none")
        } else {
            lines.append("Witness event IDs: \(report.witnessEventIDs.joined(separator: ", "))")
        }
        FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    static func traceScopeLabel(_ scope: MeridianRuntime.TraceScope) -> String {
        switch scope {
        case .currentRun:
            return "currentRun"
        case .acrossAllRuns:
            return "acrossAllRuns"
        }
    }

    static func existingURL(path: String) throws -> URL {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("merconfig not found: \(path)")
        }
        return url
    }

    static func runtimeScope(from scope: MeridianCore.TraceScope) -> MeridianRuntime.TraceScope {
        switch scope {
        case .currentRun:
            return .currentRun
        case .acrossAllRuns:
            return .acrossAllRuns
        }
    }
}
