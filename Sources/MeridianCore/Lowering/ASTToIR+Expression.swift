import Foundation
import MeridianRuntime

// MARK: - Expression lowering

extension ASTToIR {
    /// Lower an expression. `scope`, when non-nil, is the set of in-scope names
    /// (workflow params + earlier binds + loop vars, normalized via `scopeKey`)
    /// used to validate Wave 3 relation operands; `nil` means "scope unknown here,
    /// skip operand validation" (the safe default for positions that don't thread
    /// it). `line` carries the enclosing statement's source line so Wave 3 errors
    /// point at the right place.
    func lowerExpr(
        _ expr: ExpressionAST,
        scope: Set<String>? = nil,
        line: Int = 0,
        allowsBoundedFutureMonitors: Bool = false
    ) throws -> IRExpression {
        switch expr {
        case .malformed(let message, let code, let help, let suggestion):
            let diag = Diagnostic.structural(
                code,
                message: message,
                range: sourceRange(line),
                help: help ?? "Rewrite the condition using explicit grouping or fix the quantifier/description shape.",
                suggestions: suggestion.map { [$0] } ?? [])
            try throwLoweringError(diag)
        case .quantified(let q):
            return try lowerQuantifier(q, line: line)
        case .literal(let lit):
            return .literal(lowerLiteral(lit))
        case .identifierRef(let name):
            let lower = name.lowercased()
            if symbols.constants[lower] != nil { return .constantRef(name: lower) }
            if symbols.instances[lower] != nil { return .instanceRef(name: lower) }
            // A bare identifier matching a vocabulary enum case (e.g. `invalid`,
            // `denied`, `succeeded`) lowers to a string literal so comparisons
            // against `state.get("result.verdict")` (which holds an enum
            // raw-value string) actually match. Without this rule, the lowerer
            // would emit `state.get("invalid")`, which always resolves to nil
            // and silently makes branches dead.
            if symbols.enumCases.contains(lower) {
                return .literal(.string(lower))
            }
            // Multi-word bind variables become camelCase so they match how
            // `bind retry count = …` is emitted (`let retryCount = …`).
            return .identifierRef(name: camelCase(lower))
        case .constantRef(let name):
            return .constantRef(name: name.lowercased())
        case .instanceRef(let name):
            return .instanceRef(name: name.lowercased())
        case .propertyAccess(let base, let prop):
            return .propertyAccess(try lowerExpr(base, scope: scope, line: line), propertyName: prop)
        case .comparison(let lhs, let op, let rhs):
            return try lowerComparison(lhs, op, rhs, scope: scope, line: line)
        case .logical(let op, let exprs):
            return .logical(lowerLogicalOp(op), try exprs.map { try lowerExpr($0, scope: scope, line: line) })
        case .envVar(let name):
            return .envVar(name: name)
        case .now:
            return .nowExpression
        case .invoke(let toolID, let args):
            return .invocation(InvokeIR(
                toolID: toolID,
                arguments: try args.map { InvokeArg($0.0, try lowerExpr($0.1, scope: scope, line: line)) }
            ))
        case .decideWhether(let question):
            // SkillMD-D11a: Delegate to the runtime's Discretion protocol, not
            // the normal tool registry. The LLM can decide, but it cannot
            // execute. (See `.ai/brainstorm-done/skill_md_expressiveness_d1_d28.md`.)
            return .invocation(InvokeIR(
                toolID: "runtime.discretion.decide",
                arguments: [InvokeArg("question", .literal(.string(question)))]
            ))
        case .interpolatedString(let segs):
            // B7: Lower each segment; expressions are recursively lowered.
            let irSegs = try segs.map { seg -> IRInterpolationSegment in
                switch seg {
                case .literal(let s):    return .literal(s)
                case .expression(let e): return .expression(try lowerExpr(e, scope: scope, line: line))
                case .conditional(let c, let t, let o):
                    return .conditional(
                        condition: try lowerExpr(c, scope: scope, line: line),
                        then: try lowerInterpolationSegments(t, scope: scope, line: line),
                        otherwise: try lowerInterpolationSegments(o, scope: scope, line: line)
                    )
                case .forEach(let v, let c, let b):
                    return .forEach(
                        variable: v,
                        collection: try lowerExpr(c, scope: scope, line: line),
                        body: try lowerInterpolationSegments(b, scope: scope.map { $0.union([v]) }, line: line)
                    )
                case .formatted(let e, let f):
                    try validateFormatter(f, line: line)
                    return .formatted(try lowerExpr(e, scope: scope, line: line), formatter: f)
                }
            }
            return .interpolatedString(irSegs)
        case .recordList(let fields, let rows):
            let irRows = try rows.map { row in try row.map { try lowerExpr($0, scope: scope, line: line) } }
            return .recordList(fields: fields, rows: irRows)
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return .tableLookup(
                table: table,
                keyColumn: keyColumn,
                key: try lowerExpr(key, scope: scope, line: line),
                valueColumn: valueColumn
            )
        case .verbPredicate(let subject, let verb, let object):
            return try lowerVerbPredicate(subject: subject, verbForm: verb, object: object, scope: scope, line: line)
        case .eventPattern(let pattern):
            return .eventPattern(try lowerEventPattern(pattern, scope: scope, line: line))
        case .traceTemporal(let temporal):
            return .traceTemporal(try lowerTraceTemporal(
                temporal,
                scope: scope,
                line: line,
                allowsBoundedFutureMonitors: allowsBoundedFutureMonitors
            ))
        case .traceStatistical(let statistical):
            return .traceStatistical(try lowerTraceStatistical(statistical, scope: scope, line: line))
        case .relationTraversal, .description, .aggregate, .superlative:
            // Value position cannot host an `await` fetch, so a tool-backed
            // source is rejected inside the plan builders (bind it first);
            // property-backed sources produce an empty prelude, which is dropped.
            guard let rel = try lowerRelationalExpr(expr, allowToolFetch: false, scope: scope, line: line) else {
                throw CompilerError.diagnostics([
                    Diagnostic.error(.internalError,
                                     message: "internal: unhandled relational expression",
                                     range: sourceRange(line),
                                     help: "This is a compiler bug; please report it with the source file and line number.")
                ])
            }
            return rel.expr
        }
    }

    func lowerEventPattern(_ pattern: EventPatternAST, scope: Set<String>?, line: Int) throws -> EventPatternIR {
        let subject = try lowerEventSubject(pattern.subject, line: line)
        let payloadPredicate = try pattern.payloadPredicate.map { try lowerExpr($0, scope: scope, line: line) }
        if let payloadPredicate, let fieldName = payloadFieldName(payloadPredicate) {
            try validatePayloadField(fieldName, subjectName: eventSubjectRawName(pattern.subject), line: line)
        }
        return EventPatternIR(
            subject: subject,
            outcome: EventPatternIR.OutcomeVerb(rawValue: pattern.outcome.rawValue) ?? .failed,
            payloadPredicate: payloadPredicate,
            negated: pattern.negated
        )
    }

    /// resolve an event-pattern subject, rejecting a
    /// cross-skill-scoped step ([DECISION D4], SEM-4-03 — not yet supported)
    /// and a step name that closely misspells a declared kind/tool name.
    /// `.step`/`.named` names have no formal declaration surface today (a
    /// step is free-form English, e.g. `the deploy step` with no `Step:
    /// deploy` declaration anywhere) — this deliberately only rejects a
    /// near-miss of something that IS declared (a real typo), never a
    /// wholly novel, self-consistent step vocabulary, so existing skills that
    /// never declare their step nouns as kinds/tools keep compiling.
    func lowerEventSubject(_ subject: EventPatternAST.Subject, line: Int) throws -> EventPatternIR.Subject {
        switch subject {
        case .step(let name):
            let known = knownStepNames()
            // A tight, fixed budget (not `Suggester.defaultBudget`'s
            // length-scaled one): a real typo is usually a 1-2 character slip
            // (`deply` -> `deploy`), while two *legitimately distinct* domain
            // nouns sharing a stem (`access review` vs. the declared `access
            // request`) can still land within the scaled default budget for
            // longer strings. This check exists to catch typos of declared
            // vocabulary, not to force every step noun to resemble one.
            if !known.contains(name.lowercased()), let closest = Suggester().closest(name, among: known, budget: 2) {
                let diag = Diagnostic.unresolved(
                    .traceUnknownStep,
                    target: name,
                    among: known,
                    range: sourceRange(line),
                    noun: "trace step",
                    help: "Declared step names in scope: \(known.sorted().joined(separator: ", ")). Did you mean `\(closest)`?"
                )
                try throwLoweringError(diag)
            }
            return .step(name)
        case .named(let name):
            return .named(name)
        case .stepOfSkill(let step, let skill):
            try validateCrossSkillAllowList([skill], line: line)
            return .step(step)
        }
    }

    func eventSubjectRawName(_ subject: EventPatternAST.Subject) -> String {
        switch subject {
        case .step(let name): return name
        case .named(let name): return name
        case .stepOfSkill(let step, _): return step
        }
    }

    /// The declared vocabulary a `.step` subject may name: every declared
    /// kind, every declared tool ID, and every declared tool's dotted prefix
    /// (`deploy.rollback` -> `deploy`).
    func knownStepNames() -> [String] {
        var names = Set(symbols.kinds.keys.map { $0.lowercased() })
        for toolID in symbols.tools.keys {
            names.insert(toolID.lowercased())
            if let dot = toolID.firstIndex(of: ".") {
                names.insert(String(toolID[toolID.startIndex..<dot]).lowercased())
            }
        }
        return names.sorted()
    }

    /// The declared payload schema for an event-pattern subject: a tool's
    /// declared parameters (matched by full tool ID or dotted prefix) unioned
    /// with a matching kind's declared properties. `nil` when the subject
    /// resolves to neither (an undeclared step/named subject) — payload
    /// fields on those are never checked, matching the leniency
    /// `lowerEventSubject` already extends to the subject name itself.
    func knownPayloadFields(forSubjectNamed name: String) -> Set<String>? {
        let lower = name.lowercased()
        var fields: Set<String> = []
        var matched = false
        for (toolID, decl) in symbols.tools {
            let prefix = toolID.firstIndex(of: ".").map { String(toolID[toolID.startIndex..<$0]) } ?? toolID
            guard toolID.lowercased() == lower || prefix.lowercased() == lower else { continue }
            fields.formUnion(decl.parameters.map { $0.name.lowercased() })
            matched = true
        }
        if symbols.kinds[lower] != nil, let props = symbols.properties[lower] {
            fields.formUnion(props.map { $0.name.lowercased() })
            matched = true
        }
        return matched ? fields : nil
    }

    func payloadFieldName(_ expr: IRExpression) -> String? {
        switch expr {
        case .comparison(let lhs, _, _):
            return payloadFieldName(lhs)
        case .identifierRef(let name):
            return name
        default:
            return nil
        }
    }

    func validatePayloadField(_ field: String, subjectName: String, line: Int) throws {
        guard let known = knownPayloadFields(forSubjectNamed: subjectName), !known.contains(field.lowercased()) else { return }
        let diag = Diagnostic.unresolved(
            .traceUnknownPayloadField,
            target: field,
            among: Array(known),
            range: sourceRange(line),
            noun: "trace payload field"
        )
        try throwLoweringError(diag)
    }

    func validateCrossSkillAllowList(_ skills: [String], line: Int) throws {
        let allowList = symbols.traceConfiguration.crossSkillAllowList?.value ?? []
        let normalizedAllow = Set(allowList.map { $0.lowercased() })
        let undeclared = skills.filter { !normalizedAllow.contains($0.lowercased()) }
        guard undeclared.isEmpty else {
            let diag = Diagnostic.structural(
                .traceCrossSkillScope,
                message: "cross-skill trace scope references undeclared skill(s): \(undeclared.joined(separator: ", "))",
                range: sourceRange(line),
                help: "Declare allowed skills in `=== trace ===` with `cross-skill allow-list: \(undeclared.joined(separator: ", "))`."
            )
            try throwLoweringError(diag)
        }
    }

    func crossSkillNames(in subject: EventPatternAST.Subject) -> [String] {
        if case .stepOfSkill(_, let skill) = subject { return [skill] }
        return []
    }

    func resolveTraceScope(
        declared: TraceScopeAST,
        subjects: [EventPatternAST.Subject],
        line: Int
    ) throws -> TraceScope {
        let implicit = subjects.flatMap(crossSkillNames(in:))
        switch declared {
        case .currentRun:
            if !implicit.isEmpty {
                try validateCrossSkillAllowList(implicit, line: line)
                return .acrossSkills(implicit)
            }
            return .currentRun
        case .acrossAllRuns:
            return .acrossAllRuns
        case .acrossSkills(let skills):
            try validateCrossSkillAllowList(skills, line: line)
            return .acrossSkills(skills)
        }
    }

    func lowerTraceTemporal(
        _ temporal: TraceTemporalAST,
        scope: Set<String>?,
        line: Int,
        allowsBoundedFutureMonitors: Bool = false
    ) throws -> TraceTemporalIR {
        var subjectASTs: [EventPatternAST.Subject] = []
        let kind: TraceTemporalKind
        switch temporal.kind {
        case .ever(let pattern):
            subjectASTs = [pattern.subject]
            kind = .ever(try lowerEventPattern(pattern, scope: scope, line: line))
        case .withinWindow(let pattern, let duration):
            subjectASTs = [pattern.subject]
            try checkWindowAgainstRetention(duration, line: line)
            kind = .withinWindow(try lowerEventPattern(pattern, scope: scope, line: line), duration: durationSeconds(duration))
        case .countInWindow(let pattern, let comparator, let duration):
            subjectASTs = [pattern.subject]
            try checkWindowAgainstRetention(duration, line: line)
            let loweredComparator: TraceCountComparatorIR
            switch comparator {
            case .atLeast(let value): loweredComparator = .atLeast(value)
            case .atMost(let value): loweredComparator = .atMost(value)
            case .exactly(let value): loweredComparator = .exactly(value)
            }
            kind = .countInWindow(
                try lowerEventPattern(pattern, scope: scope, line: line),
                comparator: loweredComparator,
                duration: durationSeconds(duration)
            )
        case .inARow(let pattern, let count):
            subjectASTs = [pattern.subject]
            kind = .inARow(try lowerEventPattern(pattern, scope: scope, line: line), count: count)
        case .sinceLast(let anchor, let holds):
            subjectASTs = [anchor.subject]
            let loweredHolds = try lowerExpr(holds, scope: scope, line: line)
            let resolved = try resolveSinceHolds(loweredHolds, line: line)
            kind = .sinceLast(
                anchor: try lowerEventPattern(anchor, scope: scope, line: line),
                holds: loweredHolds,
                holdsPattern: resolved.holdsPattern,
                holdsUsesStateHistory: resolved.usesStateHistory
            )
        case .boundedFutureMonitor(let condition, let horizon, let mode):
            guard allowsBoundedFutureMonitors else {
                let diag = Diagnostic.structural(
                    .traceFuture,
                    message: "bounded future monitors are only allowed in Contract or obligation monitor contexts",
                    range: sourceRange(line),
                    help: "Move this form into a Contract section or an obligation monitor body, or rewrite it as a pure-past trace predicate."
                )
                try throwLoweringError(diag)
            }
            let monitorMode: FutureMonitorModeIR
            switch mode {
            case .eventuallyWithin: monitorMode = .eventuallyWithin
            case .alwaysFor: monitorMode = .alwaysFor
            }
            kind = .boundedFutureMonitor(
                condition: try lowerExpr(condition, scope: scope, line: line),
                horizon: durationSeconds(horizon),
                mode: monitorMode
            )
        }
        let scopeIR = try resolveTraceScope(declared: temporal.scope, subjects: subjectASTs, line: line)
        return TraceTemporalIR(scope: scopeIR, kind: kind)
    }

    func durationSeconds(_ duration: (Double, TimeUnitAST)) -> Duration {
        Duration.seconds(Int64(duration.0 * Double(duration.1.inSeconds)))
    }

    /// MER-TMP-011: a trace-temporal trailing window that exceeds
    /// configured retention `ρ` is a compile error, never a silently narrower
    /// query. Both durations are named. Retention defaults to 30 days when the
    /// merconfig declares no `=== trace ===` retention (matching
    /// `TraceIdentityPlanner`).
    func checkWindowAgainstRetention(_ window: (Double, TimeUnitAST), line: Int) throws {
        let windowSeconds = window.0 * Double(window.1.inSeconds)
        let retention = symbols.traceConfiguration.retention?.value ?? Duration.seconds(60 * 60 * 24 * 30)
        let retentionSeconds = Double(retention.components.seconds)
        guard windowSeconds > retentionSeconds else { return }
        let diag = Diagnostic.error(
            .traceWindowExceedsRetention,
            message: "trace window `\(TraceDurationText.window(window))` exceeds configured trace retention `\(TraceDurationText.seconds(retentionSeconds))`",
            range: sourceRange(line),
            help: "Raise the `=== trace ===` retention to at least `\(TraceDurationText.window(window))`, or narrow the window to `\(TraceDurationText.seconds(retentionSeconds))` or less."
        )
        try throwLoweringError(diag)
    }

    struct ResolvedSinceHolds {
        let holdsPattern: EventPatternIR?
        let usesStateHistory: Bool
    }

    func resolveSinceHolds(_ holds: IRExpression, line: Int) throws -> ResolvedSinceHolds {
        if case .eventPattern(let pattern) = holds {
            return ResolvedSinceHolds(holdsPattern: pattern, usesStateHistory: false)
        }
        if case .definitionPredicate(let functionName, _) = holds,
           let record = symbols.definitions.values.first(where: { $0.functionName == functionName }) {
            let body = try lowerExpr(record.body)
            if case .eventPattern(let pattern) = body {
                return ResolvedSinceHolds(holdsPattern: pattern, usesStateHistory: false)
            }
            if case .traceTemporal(let temporal) = body, case .ever(let pattern) = temporal.kind {
                return ResolvedSinceHolds(holdsPattern: pattern, usesStateHistory: false)
            }
        }
        if symbols.traceConfiguration.stateHistoryRetention?.value == true {
            return ResolvedSinceHolds(holdsPattern: nil, usesStateHistory: true)
        }
        let diag = Diagnostic.structural(
            .traceStateHistorySince,
            message: "the predicate held after a `since the last` anchor is not an event pattern, so it cannot be checked over the trace",
            range: sourceRange(line),
            help: "Enable `state history: enabled` in `=== trace ===` for keyed state predicates, back the holds with an adjective whose body is a `has ever` event query, or drop the `since` form."
        )
        try throwLoweringError(diag)
    }

    func lowerTraceStatistical(_ statistical: TraceStatisticalAST, scope: Set<String>?, line: Int) throws -> TraceStatisticalIR {
        let scopeIR = try resolveTraceScope(
            declared: statistical.scope,
            subjects: [statistical.pattern.subject],
            line: line
        )

        let outcome: TraceStatisticalOutcomeIR
        switch statistical.outcome {
        case .succeeds:
            outcome = .succeeds
        case .fails:
            outcome = .fails
        }

        let bound: TraceStatisticalBoundIR
        switch statistical.bound {
        case .atLeast(let ratio):
            bound = .atLeast(ratio)
        case .atMost(let ratio):
            bound = .atMost(ratio)
        case .usually:
            bound = .atLeast(symbols.traceConfiguration.usuallyThreshold?.value ?? 0.9)
        case .rarely:
            bound = .atMost(symbols.traceConfiguration.rarelyThreshold?.value ?? 0.1)
        }

        let denominator: TraceStatisticalDenominatorIR
        switch statistical.denominator {
        case .runs:
            denominator = .runs
        case .occurrences:
            denominator = .occurrences
        }

        let statisticalSubject = try lowerEventSubject(statistical.pattern.subject, line: line)
        let statisticalPayloadPredicate = try statistical.pattern.payloadPredicate.map { try lowerExpr($0, scope: scope, line: line) }
        if let statisticalPayloadPredicate, let fieldName = payloadFieldName(statisticalPayloadPredicate) {
            try validatePayloadField(fieldName, subjectName: eventSubjectRawName(statistical.pattern.subject), line: line)
        }
        let pattern = TraceStatisticalPatternIR(
            subject: statisticalSubject,
            payloadPredicate: statisticalPayloadPredicate
        )

        let window = statistical.window.map {
            Duration.seconds(Int64($0.0 * Double($0.1.inSeconds)))
        }
        let monitorCadence = statistical.monitorCadence.map {
            Duration.seconds(Int64($0.0 * Double($0.1.inSeconds)))
        }

        return TraceStatisticalIR(
            scope: scopeIR,
            pattern: pattern,
            outcome: outcome,
            bound: bound,
            denominator: denominator,
            window: window,
            monitorCadence: monitorCadence,
            blocking: statistical.blocking,
            confidencePercent: statistical.confidencePercent
        )
    }

    func monitoredAssertConfig(
        for condition: IRExpression,
        line: Int
    ) throws -> (monitored: Bool, cadence: Duration?, blocking: Bool) {
        guard case .traceStatistical(let statistical) = condition else {
            return (false, nil, false)
        }
        if let cadence = statistical.monitorCadence {
            return (true, cadence, statistical.blocking)
        }
        if let defaultCadence = symbols.traceConfiguration.defaultMonitorCadence?.value {
            return (true, defaultCadence, statistical.blocking)
        }
        let diag = Diagnostic.error(
            .malformedCondition,
            message: "statistical assertions need `checked every <duration>` or a `default monitor cadence` trace setting",
            range: sourceRange(line),
            help: "Add `, checked every 1 days` to the assertion or configure `default monitor cadence:` inside `=== trace ===`."
        )
        try throwLoweringError(diag)
    }

    func lowerInterpolationSegments(_ segments: [InterpolationSegment], scope: Set<String>?, line: Int) throws -> [IRInterpolationSegment] {
        try segments.map { seg in
            switch seg {
            case .literal(let s):
                return .literal(s)
            case .expression(let e):
                return .expression(try lowerExpr(e, scope: scope, line: line))
            case .conditional(let c, let t, let o):
                return .conditional(
                    condition: try lowerExpr(c, scope: scope, line: line),
                    then: try lowerInterpolationSegments(t, scope: scope, line: line),
                    otherwise: try lowerInterpolationSegments(o, scope: scope, line: line)
                )
            case .forEach(let v, let c, let b):
                return .forEach(
                    variable: v,
                    collection: try lowerExpr(c, scope: scope, line: line),
                    body: try lowerInterpolationSegments(b, scope: scope.map { $0.union([v]) }, line: line)
                )
            case .formatted(let e, let f):
                try validateFormatter(f, line: line)
                return .formatted(try lowerExpr(e, scope: scope, line: line), formatter: f)
            }
        }
    }

    /// B7: `{{ expr as a <formatter> }}` names one formatter from the closed
    /// `FormatterRegistry`. Validated once, here, at lowering time — the only
    /// place a `.formatted` interpolation segment is turned into IR — so
    /// codegen (`SwiftEmitter.meridianFormat`) never has to silently no-op on
    /// an unrecognized formatter string.
    func validateFormatter(_ formatter: String, line: Int) throws {
        guard !FormatterRegistry.isValid(formatter) else { return }
        throw CompilerError.diagnostics([
            Diagnostic.unresolved(
                .unknownTemplateFormatter,
                target: formatter,
                among: FormatterRegistry.available,
                range: sourceRange(line),
                noun: "template formatter",
                help: "Available formatters: \(FormatterRegistry.available.joined(separator: ", ")).")
        ])
    }

    /// Lower a comparison. Handles three special shapes before the generic
    /// path: checkable-adjective predicates (`X is/is not <adj>`), the emptiness
    /// operators (RHS is an ignored placeholder), and ordinary comparisons.
    func lowerComparison(_ lhs: ExpressionAST, _ op: ComparisonOpAST, _ rhs: ExpressionAST,
                                 scope: Set<String>? = nil, line: Int = 0) throws -> IRExpression {
        // `X is <adj>` / `X is not <adj>` — a checkable-adjective predicate,
        // recognised ONLY when the LHS is in subject position (lowers to a bare
        // identifier reference) and the RHS names a registered adjective.
        if op == .equal || op == .notEqual,
           case .identifierRef(let adjName) = rhs,
           let record = symbols.definition(forAdjective: adjName) {
            let loweredLhs = try lowerExpr(lhs, scope: scope, line: line)
            if case .identifierRef = loweredLhs {
                let pred = IRExpression.definitionPredicate(functionName: record.functionName, subject: loweredLhs)
                return op == .equal ? pred : .logical(.not, [pred])
            }
            // Not subject position — fall through to a normal comparison.
        }
        switch op {
        case .isEmpty, .isNotEmpty:
            return .comparison(try lowerExpr(lhs, scope: scope, line: line), lowerCompOp(op), .literal(.boolean(true)))
        default:
            return .comparison(try lowerExpr(lhs, scope: scope, line: line), lowerCompOp(op),
                               try lowerExpr(rhs, scope: scope, line: line))
        }
    }

}
