import Foundation
import MeridianRuntime

/// Decodes proof-IR JSON embedded in obligation artifacts into runtime query shapes.
/// Independent of generated guards — artifacts + trace only (SEM-7-01 / SEM-8-01).
enum ProofIRReader {

    static func actionPattern(
        from json: String?,
        trace: ParserTrace = .shared
    ) -> ActionPatternIR? {
        guard let json else { return nil }
        guard let data = json.data(using: .utf8) else {
            logReadLoss("action pattern JSON is not UTF-8", trace: trace)
            return nil
        }
        let root: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logReadLoss("action pattern root is not a JSON object", trace: trace)
                return nil
            }
            root = parsed
        } catch {
            logReadLoss("action pattern JSON decode failed: \(error.localizedDescription)", trace: trace)
            return nil
        }
        guard let toolID = root["tool_id"] as? String else {
            logReadLoss("action pattern missing tool_id", trace: trace)
            return nil
        }
        let constraints = (root["argument_constraints"] as? [[String: Any]] ?? [])
            .compactMap { actionArgumentConstraint($0, trace: trace) }
        return ActionPatternIR(toolID: toolID, argumentConstraints: constraints)
    }

    static func traceStatisticalQuery(
        from json: String?,
        trace: ParserTrace = .shared
    ) -> TraceStatisticalQuery? {
        guard let json else { return nil }
        guard let data = json.data(using: .utf8) else {
            logReadLoss("trace statistical query JSON is not UTF-8", trace: trace)
            return nil
        }
        let root: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logReadLoss("trace statistical query root is not a JSON object", trace: trace)
                return nil
            }
            root = parsed
        } catch {
            logReadLoss("trace statistical query JSON decode failed: \(error.localizedDescription)", trace: trace)
            return nil
        }
        guard root["kind"] as? String == "traceStatistical",
              let value = root["value"] as? [String: Any] else {
            logReadLoss("trace statistical query missing kind/value", trace: trace)
            return nil
        }
        let scope = traceScope(root["scope"] as? String)
        guard let pattern = statisticalPattern(value["pattern"] as? [String: Any]),
              let outcome = value["outcome"] as? String,
              let boundNode = value["bound"] as? [String: Any],
              let denominator = value["denominator"] as? String else {
            logReadLoss("trace statistical query missing required fields", trace: trace)
            return nil
        }
        let eventPattern = TraceEventPatternQuery(
            subject: pattern.subject,
            outcome: outcome == "fails" ? .failed : .succeeded,
            subjectKey: pattern.subjectKey,
            payloadContains: pattern.payloadContains
        )
        guard let bound = statisticalBound(boundNode) else {
            logReadLoss("trace statistical query has invalid bound", trace: trace)
            return nil
        }
        let denom: TraceStatisticalDenominator = denominator == "runs" ? .runs : .occurrences
        return TraceStatisticalQuery(
            scope: scope,
            pattern: eventPattern,
            bound: bound,
            denominator: denom,
            window: durationValue(value["window"] as? [String: Any])
        )
    }

    static func traceTemporalQuery(
        from json: String?,
        trace: ParserTrace = .shared
    ) -> TraceTemporalQuery? {
        guard let json else { return nil }
        guard let data = json.data(using: .utf8) else {
            logReadLoss("trace temporal query JSON is not UTF-8", trace: trace)
            return nil
        }
        let root: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logReadLoss("trace temporal query root is not a JSON object", trace: trace)
                return nil
            }
            root = parsed
        } catch {
            logReadLoss("trace temporal query JSON decode failed: \(error.localizedDescription)", trace: trace)
            return nil
        }
        guard root["kind"] as? String == "traceTemporal",
              let value = root["value"] as? [String: Any] else {
            logReadLoss("trace temporal query missing kind/value", trace: trace)
            return nil
        }
        let scope = traceScope(root["scope"] as? String)
        guard let kindName = value["kind"] as? String else {
            logReadLoss("trace temporal query missing temporal kind", trace: trace)
            return nil
        }
        switch kindName {
        case "ever":
            guard let pattern = eventPattern(value["pattern"] as? [String: Any]) else {
                logReadLoss("trace temporal ever query missing event pattern", trace: trace)
                return nil
            }
            return TraceTemporalQuery(scope: scope, kind: .ever(pattern))
        case "withinWindow":
            guard let pattern = eventPattern(value["pattern"] as? [String: Any]),
                  let duration = durationValue(value["duration"] as? [String: Any]) else {
                logReadLoss("trace temporal withinWindow query missing pattern or duration", trace: trace)
                return nil
            }
            return TraceTemporalQuery(scope: scope, kind: .withinWindow(pattern, duration: duration))
        case "countInWindow":
            guard let pattern = eventPattern(value["pattern"] as? [String: Any]),
                  let duration = durationValue(value["duration"] as? [String: Any]),
                  let comparator = countComparator(value["comparator"] as? [String: Any]) else {
                logReadLoss("trace temporal countInWindow query missing pattern, duration, or comparator", trace: trace)
                return nil
            }
            return TraceTemporalQuery(scope: scope, kind: .countInWindow(pattern, comparator: comparator, duration: duration))
        case "inARow":
            guard let pattern = eventPattern(value["pattern"] as? [String: Any]),
                  let count = intValue(value["count"]) else {
                logReadLoss("trace temporal inARow query missing pattern or count", trace: trace)
                return nil
            }
            return TraceTemporalQuery(scope: scope, kind: .inARow(pattern, count: count))
        case "sinceLast":
            guard let anchor = eventPattern(value["anchor"] as? [String: Any]) else {
                logReadLoss("trace temporal sinceLast query missing anchor pattern", trace: trace)
                return nil
            }
            let usesStateHistory = (value["holdsUsesStateHistory"] as? Bool) ?? false
            if usesStateHistory {
                return TraceTemporalQuery(
                    scope: scope,
                    kind: .sinceLast(anchor: anchor, holds: nil, holdsStatePredicateJSON: nil, holdsUsesStateHistory: true)
                )
            }
            guard let holds = eventPattern(value["holds"] as? [String: Any]) else {
                logReadLoss("trace temporal sinceLast query missing holds event pattern", trace: trace)
                return nil
            }
            return TraceTemporalQuery(
                scope: scope,
                kind: .sinceLast(anchor: anchor, holds: holds, holdsStatePredicateJSON: nil, holdsUsesStateHistory: false)
            )
        default:
            logReadLoss("trace temporal query has unknown kind `\(kindName)`", trace: trace)
            return nil
        }
    }

    // MARK: - Private

    private static func logReadLoss(_ message: String, trace: ParserTrace) {
        trace.log(.validation, "proof-ir read warning: \(message)")
    }

    private struct ParsedEventPattern {
        let subject: TraceEventPatternQuery.Subject
        let outcome: TraceEventPatternQuery.Outcome
        let subjectKey: String?
        let payloadContains: [String: Value]?
    }

    private struct ParsedStatisticalPattern {
        let subject: TraceEventPatternQuery.Subject
        let subjectKey: String?
        let payloadContains: [String: Value]?
    }

    private static func actionArgumentConstraint(
        _ node: [String: Any],
        trace: ParserTrace
    ) -> ActionArgumentConstraint? {
        guard let path = node["path"] as? String,
              let opName = node["op"] as? String,
              let valueNode = node["value"] as? [String: Any],
              let op = comparisonOp(opName),
              let expr = expressionValue(valueNode) else {
            logReadLoss("action argument constraint missing path/op/value", trace: trace)
            return nil
        }
        return ActionArgumentConstraint(path: path, op: op, value: expr)
    }

    private static func comparisonOp(_ name: String) -> ComparisonOp? {
        switch name {
        case "equal": return .equal
        case "notEqual": return .notEqual
        case "lessThan": return .lessThan
        case "lessOrEqual": return .lessOrEqual
        case "greaterThan": return .greaterThan
        case "greaterOrEqual": return .greaterOrEqual
        case "oneOf": return .oneOf
        case "contains": return .contains
        case "startsWith": return .startsWith
        case "endsWith": return .endsWith
        case "withinDuration": return .withinDuration
        case "withinPast": return .withinPast
        case "withinFuture": return .withinFuture
        case "matchesPattern": return .matchesPattern
        case "isEmpty": return .isEmpty
        case "isNotEmpty": return .isNotEmpty
        case "identifies": return .identifies
        default: return nil
        }
    }

    private static func expressionValue(_ node: [String: Any]) -> IRExpression? {
        guard let kind = node["kind"] as? String else { return nil }
        switch kind {
        case "literal":
            guard let value = node["value"] as? [String: Any],
                  let litKind = value["kind"] as? String else { return nil }
            switch litKind {
            case "string":
                guard let v = value["value"] as? String else { return nil }
                return .literal(.string(v))
            case "number":
                if let n = value["value"] as? NSNumber { return .literal(.number(Decimal(string: n.stringValue) ?? 0)) }
                return nil
            case "boolean":
                guard let v = value["value"] as? Bool else { return nil }
                return .literal(.boolean(v))
            default:
                return nil
            }
        case "identifierRef":
            guard let name = node["name"] as? String else { return nil }
            return .identifierRef(name: name)
        default:
            return nil
        }
    }

    private static func traceScope(_ raw: String?) -> MeridianRuntime.TraceScope {
        raw == "acrossAllRuns" ? .acrossAllRuns : .currentRun
    }

    private static func statisticalPattern(_ node: [String: Any]?) -> ParsedStatisticalPattern? {
        guard let node,
              let subjectNode = node["subject"] as? [String: Any],
              let subject = eventSubject(subjectNode) else {
            return nil
        }
        return ParsedStatisticalPattern(
            subject: subject,
            subjectKey: nil,
            payloadContains: payloadContains(node["payload"] as? [String: Any])
        )
    }

    private static func eventPattern(_ node: [String: Any]?) -> TraceEventPatternQuery? {
        guard let node,
              node["kind"] as? String == "eventPattern",
              let value = node["value"] as? [String: Any],
              let subjectNode = value["subject"] as? [String: Any],
              let subject = eventSubject(subjectNode),
              let outcomeRaw = value["outcome"] as? String,
              let outcome = eventOutcome(outcomeRaw) else {
            return nil
        }
        return TraceEventPatternQuery(
            subject: subject,
            outcome: outcome,
            subjectKey: nil,
            payloadContains: payloadContains(value["payload"] as? [String: Any])
        )
    }

    private static func eventSubject(_ node: [String: Any]) -> TraceEventPatternQuery.Subject? {
        guard let kind = node["kind"] as? String, let name = node["name"] as? String else { return nil }
        switch kind {
        case "step": return .step(name)
        case "named": return .named(name)
        default: return nil
        }
    }

    private static func eventOutcome(_ raw: String) -> TraceEventPatternQuery.Outcome? {
        switch raw {
        case "failed": return .failed
        case "succeeded": return .succeeded
        case "invoked": return .invoked
        case "emitted": return .emitted
        case "prevented": return .prevented
        case "violated": return .violated
        case "occurred": return .occurred
        default: return nil
        }
    }

    private static func payloadContains(_ node: [String: Any]?) -> [String: Value]? {
        guard let node, node["kind"] as? String == "literal",
              let value = node["value"] as? [String: Any],
              value["kind"] as? String == "string",
              let text = value["value"] as? String else {
            return nil
        }
        return ["value": .string(text)]
    }

    private static func statisticalBound(_ node: [String: Any]) -> TraceStatisticalBound? {
        guard let kind = node["kind"] as? String else { return nil }
        let ratio: Double
        if let n = node["ratio"] as? NSNumber {
            ratio = n.doubleValue
        } else {
            return nil
        }
        switch kind {
        case "atLeast": return .atLeast(ratio)
        case "atMost": return .atMost(ratio)
        default: return nil
        }
    }

    private static func countComparator(_ node: [String: Any]?) -> TraceCountComparator? {
        guard let node, let kind = node["kind"] as? String, let value = intValue(node["value"]) else { return nil }
        switch kind {
        case "atLeast": return .atLeast(value)
        case "atMost": return .atMost(value)
        case "exactly": return .exactly(value)
        default: return nil
        }
    }

    private static func durationValue(_ node: [String: Any]?) -> Duration? {
        guard let node,
              let seconds = node["seconds"] as? NSNumber else { return nil }
        let atto = (node["attoseconds"] as? NSNumber).map(\.int64Value) ?? 0
        return Duration(secondsComponent: seconds.int64Value, attosecondsComponent: atto)
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let n = value as? NSNumber { return n.intValue }
        return nil
    }
}
