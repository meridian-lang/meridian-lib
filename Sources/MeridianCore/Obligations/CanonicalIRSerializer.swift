import Foundation
import MeridianRuntime

/// Deterministic JSON for obligation identity hashing and proof-IR export.
/// Excludes source line/wording/status/build hash — semantic scope, kind,
/// condition, and action pattern only.
public enum CanonicalIRSerializer {

    public static func normSemanticJSON(_ norm: NormIR) throws -> Data {
        try CanonicalJSON.data(for: normSemanticPayload(norm))
    }

    public static func normSemanticPayload(_ norm: NormIR) -> [String: Value] {
        var payload: [String: Value] = [
            "kind": .string(norm.kind.rawValue),
            "scope": scopeValue(norm.scope),
        ]
        if let pattern = norm.actionPattern {
            payload["action_pattern"] = actionPatternValue(pattern)
        }
        if let condition = norm.condition {
            payload["condition"] = expressionValue(condition)
        }
        return payload
    }

    public static func contractAssertSemanticPayload(
        condition: IRExpression,
        scope: NormScope,
        monitored: Bool
    ) -> [String: Value] {
        var payload: [String: Value] = [
            "kind": .string(monitored ? "contract_monitor" : "contract_invariant"),
            "scope": scopeValue(scope),
            "condition": expressionValue(condition),
        ]
        if monitored {
            payload["monitored"] = .boolean(true)
        }
        return payload
    }

    public static func defaultDenySemanticPayload(
        toolID: String,
        scope: NormScope
    ) -> [String: Value] {
        [
            "kind": .string("default_deny"),
            "scope": scopeValue(scope),
            "action_pattern": actionPatternValue(ActionPatternIR(toolID: toolID)),
        ]
    }

    public static func proofIRJSONString(_ value: Value) throws -> String {
        String(data: try valueProofJSONData(value), encoding: .utf8) ?? "{}"
    }

    private static func valueProofJSONData(_ value: Value) throws -> Data {
        switch value {
        case .record(let record):
            return try CanonicalJSON.data(for: record)
        default:
            return try CanonicalJSON.data(for: ["value": value])
        }
    }

    // MARK: - Scope

    private static func scopeValue(_ scope: NormScope) -> Value {
        switch scope {
        case .skill:
            return .record(["kind": .string("skill")])
        case .workflow(let name):
            return .record(["kind": .string("workflow"), "name": .string(name)])
        case .section(let stablePath):
            return .record(["kind": .string("section"), "stable_path": .string(stablePath)])
        case .kind(let name):
            return .record(["kind": .string("kind"), "name": .string(name)])
        }
    }

    // MARK: - Action pattern

    private static func actionPatternValue(_ pattern: ActionPatternIR) -> Value {
        let constraints = pattern.argumentConstraints
            .sorted { $0.path < $1.path }
            .map { constraint in
                Value.record([
                    "path": .string(constraint.path),
                    "op": .string(comparisonOpName(constraint.op)),
                    "value": expressionValue(constraint.value),
                ])
            }
        return .record([
            "tool_id": .string(IdentifierNaming.methodize(pattern.toolID)),
            "argument_constraints": .list(constraints),
        ])
    }

    // MARK: - Expressions (proof IR)

    public static func expressionValue(_ expression: IRExpression) -> Value {
        switch expression {
        case .literal(let literal):
            return .record(["kind": .string("literal"), "value": literalValue(literal)])
        case .constantRef(let name):
            return .record(["kind": .string("constantRef"), "name": .string(name)])
        case .identifierRef(let name):
            return .record(["kind": .string("identifierRef"), "name": .string(name)])
        case .instanceRef(let name):
            return .record(["kind": .string("instanceRef"), "name": .string(name)])
        case .propertyAccess(let base, let propertyName):
            return .record([
                "kind": .string("propertyAccess"),
                "base": expressionValue(base),
                "property": .string(propertyName),
            ])
        case .relationTraversal(let base, let relationName, let target):
            return .record([
                "kind": .string("relationTraversal"),
                "base": expressionValue(base),
                "relation": .string(relationName),
                "target": target.map(expressionValue) ?? .null,
            ])
        case .comparison(let lhs, let op, let rhs):
            return .record([
                "kind": .string("comparison"),
                "op": .string(comparisonOpName(op)),
                "lhs": expressionValue(lhs),
                "rhs": expressionValue(rhs),
            ])
        case .logical(let op, let expressions):
            let sorted = expressions.enumerated()
                .sorted { lhs, rhs in
                    let l = canonicalSortKey(expressionValue(lhs.element))
                    let r = canonicalSortKey(expressionValue(rhs.element))
                    if l != r { return l < r }
                    return lhs.offset < rhs.offset
                }
                .map(\.element)
            return .record([
                "kind": .string("logical"),
                "op": .string(logicalOpName(op)),
                "items": .list(sorted.map(expressionValue)),
            ])
        case .envVar(let name):
            return .record(["kind": .string("envVar"), "name": .string(name)])
        case .nowExpression:
            return .record(["kind": .string("nowExpression")])
        case .invocation(let invoke):
            return .record([
                "kind": .string("invocation"),
                "tool_id": .string(invoke.toolID),
                "arguments": .list(invoke.arguments.sorted { $0.key < $1.key }.map {
                    .record(["key": .string($0.key), "value": expressionValue($0.value)])
                }),
            ])
        case .interpolatedString(let segments):
            return .record([
                "kind": .string("interpolatedString"),
                "segments": .list(segments.map(interpolationValue)),
            ])
        case .recordList(let fields, let rows):
            return .record([
                "kind": .string("recordList"),
                "fields": .list(fields.sorted().map(Value.string)),
                "rows": .list(rows.map { .list($0.map(expressionValue)) }),
            ])
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return .record([
                "kind": .string("tableLookup"),
                "table": .string(table),
                "key_column": .string(keyColumn),
                "key": expressionValue(key),
                "value_column": .string(valueColumn),
            ])
        case .definitionPredicate(let functionName, let subject):
            return .record([
                "kind": .string("definitionPredicate"),
                "function": .string(functionName),
                "subject": expressionValue(subject),
            ])
        case .quantified(let quantifier):
            return .record(["kind": .string("quantified"), "value": quantifierValue(quantifier)])
        case .description(let description):
            return .record(["kind": .string("description"), "value": descriptionValue(description)])
        case .aggregate(let aggregate, let description):
            return .record([
                "kind": .string("aggregate"),
                "aggregate": .string(String(describing: aggregate)),
                "description": descriptionValue(description),
            ])
        case .superlative(let superlative):
            return .record([
                "kind": .string("superlative"),
                "description": descriptionValue(superlative.description),
                "sort_path": .string(superlative.sortPath),
                "ascending": .boolean(superlative.ascending),
            ])
        case .eventPattern(let pattern):
            let subject: Value
            switch pattern.subject {
            case .step(let name):
                subject = .record(["kind": .string("step"), "name": .string(name)])
            case .named(let name):
                subject = .record(["kind": .string("named"), "name": .string(name)])
            }
            return .record([
                "kind": .string("eventPattern"),
                "subject": subject,
                "outcome": .string(pattern.outcome.rawValue),
                "payload": pattern.payloadPredicate.map(expressionValue) ?? .null,
            ])
        case .traceTemporal(let temporal):
            return .record([
                "kind": .string("traceTemporal"),
                "scope": .string(String(describing: temporal.scope)),
                "value": traceTemporalValue(temporal),
            ])
        case .traceStatistical(let statistical):
            return .record([
                "kind": .string("traceStatistical"),
                "scope": .string(String(describing: statistical.scope)),
                "value": traceStatisticalValue(statistical),
            ])
        }
    }

    private static func canonicalSortKey(_ value: Value) -> String {
        (try? valueProofJSONData(value)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private static func literalValue(_ literal: IRLiteral) -> Value {
        switch literal {
        case .string(let value):
            return .record(["kind": .string("string"), "value": .string(value)])
        case .number(let value):
            return .record(["kind": .string("number"), "value": .number(value)])
        case .boolean(let value):
            return .record(["kind": .string("boolean"), "value": .boolean(value)])
        case .money(let amount, let currency):
            return .record(["kind": .string("money"), "amount": .number(amount), "currency": .string(currency)])
        case .duration(let duration):
            return .record(["kind": .string("duration"), "value": durationValue(duration)])
        case .date(let date):
            return .record(["kind": .string("date"), "value": .string(ISO8601DateFormatter.meridianFormatter.string(from: date))])
        case .dateTime(let dateTime):
            return .record(["kind": .string("dateTime"), "value": .string(ISO8601DateFormatter.meridianFormatter.string(from: dateTime))])
        case .enumValue(let value, let kind):
            return .record(["kind": .string("enumValue"), "value": .string(value), "enum_kind": .string(kind)])
        case .calendarAmount(let amount):
            return .record([
                "kind": .string("calendarAmount"),
                "magnitude": .number(Decimal(amount.magnitude)),
                "unit": .string(amount.unit.rawValue),
            ])
        }
    }

    private static func durationValue(_ duration: Duration) -> Value {
        .record([
            "seconds": .number(Decimal(duration.components.seconds)),
            "attoseconds": .number(Decimal(string: String(duration.components.attoseconds)) ?? 0),
        ])
    }

    private static func quantifierValue(_ quantifier: QuantifierIR) -> Value {
        .record([
            "kind": quantifierKindValue(quantifier.kind),
            "description": descriptionValue(quantifier.description),
            "body": quantifier.body.map(expressionValue) ?? .null,
        ])
    }

    private static func quantifierKindValue(_ kind: QuantifierKind) -> Value {
        switch kind {
        case .all: return .record(["kind": .string("all")])
        case .any: return .record(["kind": .string("any")])
        case .none: return .record(["kind": .string("none")])
        case .atLeast(let value): return .record(["kind": .string("atLeast"), "value": .number(Decimal(value))])
        case .atMost(let value): return .record(["kind": .string("atMost"), "value": .number(Decimal(value))])
        case .exactly(let value): return .record(["kind": .string("exactly"), "value": .number(Decimal(value))])
        }
    }

    private static func descriptionValue(_ description: DescriptionIR) -> Value {
        .record([
            "collection": expressionValue(description.collection),
            "elementVar": .string(description.elementVar),
            "filters": .list(description.filters.map(expressionValue)),
            "sort": description.sort.map { .record(["path": .string($0.path), "ascending": .boolean($0.ascending)]) } ?? .null,
            "take": description.take.map { .number(Decimal($0)) } ?? .null,
        ])
    }

    private static func interpolationValue(_ segment: IRInterpolationSegment) -> Value {
        switch segment {
        case .literal(let text):
            return .record(["kind": .string("literal"), "text": .string(text)])
        case .expression(let expression):
            return .record(["kind": .string("expression"), "value": expressionValue(expression)])
        case .conditional(let condition, let then, let otherwise):
            return .record([
                "kind": .string("conditional"),
                "condition": expressionValue(condition),
                "then": .list(then.map(interpolationValue)),
                "otherwise": .list(otherwise.map(interpolationValue)),
            ])
        case .forEach(let variable, let collection, let body):
            return .record([
                "kind": .string("forEach"),
                "variable": .string(variable),
                "collection": expressionValue(collection),
                "body": .list(body.map(interpolationValue)),
            ])
        case .formatted(let expression, let formatter):
            return .record([
                "kind": .string("formatted"),
                "expression": expressionValue(expression),
                "formatter": .string(formatter),
            ])
        case .shellEscapedExpression(let expression):
            return .record(["kind": .string("shellEscapedExpression"), "expression": expressionValue(expression)])
        }
    }

    private static func traceTemporalValue(_ temporal: TraceTemporalIR) -> Value {
        switch temporal.kind {
        case .ever(let pattern):
            return .record(["kind": .string("ever"), "pattern": expressionValue(.eventPattern(pattern))])
        case .withinWindow(let pattern, let duration):
            return .record([
                "kind": .string("withinWindow"),
                "pattern": expressionValue(.eventPattern(pattern)),
                "duration": durationValue(duration),
            ])
        case .countInWindow(let pattern, let comparator, let duration):
            return .record([
                "kind": .string("countInWindow"),
                "pattern": expressionValue(.eventPattern(pattern)),
                "comparator": countComparatorValue(comparator),
                "duration": durationValue(duration),
            ])
        case .inARow(let pattern, let count):
            return .record([
                "kind": .string("inARow"),
                "pattern": expressionValue(.eventPattern(pattern)),
                "count": .number(Decimal(count)),
            ])
        case .sinceLast(let anchor, let holds, let holdsPattern, let usesStateHistory):
            var record: [String: Value] = [
                "kind": .string("sinceLast"),
                "anchor": expressionValue(.eventPattern(anchor)),
                "holds": expressionValue(holds),
                "holdsUsesStateHistory": .boolean(usesStateHistory),
            ]
            if let holdsPattern {
                record["holdsPattern"] = expressionValue(.eventPattern(holdsPattern))
            }
            return .record(record)
        case .boundedFutureMonitor(let condition, let horizon, let mode):
            return .record([
                "kind": .string("boundedFutureMonitor"),
                "condition": expressionValue(condition),
                "horizon": durationValue(horizon),
                "mode": .string(mode == .eventuallyWithin ? "eventuallyWithin" : "alwaysFor"),
            ])
        }
    }

    private static func countComparatorValue(_ comparator: TraceCountComparatorIR) -> Value {
        switch comparator {
        case .atLeast(let value):
            return .record(["kind": .string("atLeast"), "value": .number(Decimal(value))])
        case .atMost(let value):
            return .record(["kind": .string("atMost"), "value": .number(Decimal(value))])
        case .exactly(let value):
            return .record(["kind": .string("exactly"), "value": .number(Decimal(value))])
        }
    }

    private static func traceStatisticalValue(_ statistical: TraceStatisticalIR) -> Value {
        let subject: Value
        switch statistical.pattern.subject {
        case .step(let name):
            subject = .record(["kind": .string("step"), "name": .string(name)])
        case .named(let name):
            subject = .record(["kind": .string("named"), "name": .string(name)])
        }
        let outcome: Value = .string({
            switch statistical.outcome {
            case .succeeds: return "succeeds"
            case .fails: return "fails"
            }
        }())
        let bound: Value = {
            switch statistical.bound {
            case .atLeast(let ratio):
                return .record(["kind": .string("atLeast"), "ratio": .number(Decimal(ratio))])
            case .atMost(let ratio):
                return .record(["kind": .string("atMost"), "ratio": .number(Decimal(ratio))])
            }
        }()
        let denominator: Value = .string(statistical.denominator == .runs ? "runs" : "occurrences")
        return .record([
            "pattern": .record([
                "subject": subject,
                "payload": statistical.pattern.payloadPredicate.map(expressionValue) ?? .null,
            ]),
            "outcome": outcome,
            "bound": bound,
            "denominator": denominator,
            "window": statistical.window.map(durationValue) ?? .null,
            "monitor_cadence": statistical.monitorCadence.map(durationValue) ?? .null,
            "blocking": .boolean(statistical.blocking),
            "subject_key": statistical.subjectKeyExpr.map(expressionValue) ?? .null,
        ])
    }

    private static func comparisonOpName(_ op: ComparisonOp) -> String {
        switch op {
        case .equal: return "equal"
        case .notEqual: return "notEqual"
        case .lessThan: return "lessThan"
        case .lessOrEqual: return "lessOrEqual"
        case .greaterThan: return "greaterThan"
        case .greaterOrEqual: return "greaterOrEqual"
        case .oneOf: return "oneOf"
        case .contains: return "contains"
        case .startsWith: return "startsWith"
        case .endsWith: return "endsWith"
        case .withinDuration: return "withinDuration"
        case .withinPast: return "withinPast"
        case .withinFuture: return "withinFuture"
        case .matchesPattern: return "matchesPattern"
        case .isEmpty: return "isEmpty"
        case .isNotEmpty: return "isNotEmpty"
        case .identifies: return "identifies"
        }
    }

    private static func logicalOpName(_ op: LogicalOp) -> String {
        switch op {
        case .and: return "and"
        case .or: return "or"
        case .not: return "not"
        }
    }
}
