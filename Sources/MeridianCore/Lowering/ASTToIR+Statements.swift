import Foundation
import MeridianRuntime

// Statement / recover lowering — extracted from ASTToIR for Phase 3 readability.

extension ASTToIR {

    // MARK: - Statement lowering

    /// 2A/2B/2C carrier: surface a parse-time `.malformed` expression (mixed
    /// bare `and`/`or`, an invalid quantifier shape, an unidentifiable kind) as a
    /// sourced `semanticError` before lowering proceeds. `ExpressionParser.parse`
    /// stays non-throwing and records the diagnostic in the AST; this guard
    /// raises it with the owning statement's line. `lowerExpr` also throws on
    /// `.malformed` (defense in depth, covering non-statement positions such as
    /// definition bodies and quantifier sub-expressions).
    private func assertNoMalformed(_ stmt: StatementAST) throws {
        func check(_ e: ExpressionAST?) throws {
            guard let e, let found = firstMalformed(e) else { return }
            let diag = Diagnostic.structural(
                found.code,
                message: found.message,
                range: sourceRange(stmt.sourceLine),
                help: found.help ?? "Rewrite the condition using explicit grouping (`either … or …`, parentheses via sub-clauses) or fix the quantifier/description shape.",
                suggestions: found.suggestion.map { [$0] } ?? [])
            try throwLoweringError(diag)
        }
        switch stmt {
        case .bind(let s):        try check(s.value)
        case .rebind(let s):      try check(s.value)
        case .emit(let s):        for (_, v) in s.payload { try check(v) }
        case .assertStmt(let s):  try check(s.condition)
        case .conditional(let s):
            try check(s.condition)
        case .matchBranch(let s):
            try check(s.subject)
            for branchCase in s.cases {
                if case .literal(let expr) = branchCase.pattern { try check(expr) }
            }
        case .wait(let s):
            switch s.condition {
            case .approval(let subject, _): try check(subject)
            case .event(_, let matching):   try check(matching)
            default: break
            }
        case .iteration(let s):
            switch s.mode {
            case .whileCondition(let c): try check(c)
            case .untilCondition(let c): try check(c)
            case .forEach(_, let c):     try check(c)
            }
            try check(s.refinement?.predicate)
        case .recover(let s):
            if case .predicate(let p) = s.pattern { try check(p) }
            try assertNoMalformed(s.attached)
        case .labelled(let s):
            try assertNoMalformed(s.statement)
        default:
            break
        }
    }

    /// Depth-first search for the first `.malformed` carrier anywhere inside an
    /// expression tree. Returns its diagnostic message plus any structured
    /// "did you mean" suggestion it carries, or `nil` when clean.
    private func firstMalformed(_ e: ExpressionAST) -> (message: String, code: DiagnosticCode, help: String?, suggestion: Suggestion?)? {
        switch e {
        case .malformed(let m, let code, let help, let suggestion):
            return (m, code, help, suggestion)
        case .propertyAccess(let base, _):
            return firstMalformed(base)
        case .comparison(let l, _, let r):
            return firstMalformed(l) ?? firstMalformed(r)
        case .logical(_, let xs):
            for x in xs { if let m = firstMalformed(x) { return m } }
            return nil
        case .invoke(_, let args):
            for (_, v) in args { if let m = firstMalformed(v) { return m } }
            return nil
        case .interpolatedString(let segs):
            for s in segs {
                switch s {
                case .expression(let x), .formatted(let x, _):
                    if let m = firstMalformed(x) { return m }
                case .conditional(let c, let t, let o):
                    if let m = firstMalformed(c) { return m }
                    if let m = firstMalformed(.interpolatedString(t)) { return m }
                    if let m = firstMalformed(.interpolatedString(o)) { return m }
                case .forEach(_, let c, let b):
                    if let m = firstMalformed(c) { return m }
                    if let m = firstMalformed(.interpolatedString(b)) { return m }
                case .literal:
                    break
                }
            }
            return nil
        case .recordList(_, let rows):
            for row in rows { for cell in row { if let m = firstMalformed(cell) { return m } } }
            return nil
        case .tableLookup(_, _, let key, _):
            return firstMalformed(key)
        case .quantified(let q):
            return firstMalformedInDescription(q.description) ?? q.body.flatMap(firstMalformed)
        case .verbPredicate(let s, _, let o):
            return firstMalformed(s) ?? firstMalformed(o)
        case .relationTraversal(let b, _, _):
            return firstMalformed(b)
        case .description(let d):
            return firstMalformedInDescription(d)
        case .aggregate(_, let d):
            return firstMalformedInDescription(d)
        case .superlative(let s):
            return firstMalformedInDescription(s.description)
        case .eventPattern(let pattern):
            return pattern.payloadPredicate.flatMap(firstMalformed)
        case .traceTemporal(let temporal):
            switch temporal.kind {
            case .ever(let pattern),
                 .withinWindow(let pattern, _),
                 .countInWindow(let pattern, _, _),
                 .inARow(let pattern, _):
                return pattern.payloadPredicate.flatMap(firstMalformed)
            case .sinceLast(let anchor, let holds):
                return anchor.payloadPredicate.flatMap(firstMalformed) ?? firstMalformed(holds)
            case .boundedFutureMonitor(let condition, _, _):
                return firstMalformed(condition)
            }
        case .traceStatistical(let statistical):
            return statistical.pattern.payloadPredicate.flatMap(firstMalformed)
        default:
            return nil
        }
    }

    private func firstMalformedInDescription(_ d: DescriptionAST) -> (message: String, code: DiagnosticCode, help: String?, suggestion: Suggestion?)? {
        if let wp = d.wherePredicate, let m = firstMalformed(wp) { return m }
        for c in d.verbClauses { if let m = firstMalformed(c.operand) { return m } }
        return nil
    }

    func lowerStatement(
        _ stmt: StatementAST,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: (parameter: PhraseParameterAST, owningStructName: String)? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil,
        scope: Set<String> = []
    ) throws -> [IRPrimitive] {
        let trace = ParserTrace.current
        try assertNoMalformed(stmt)
        trace.log(.lowering, "L\(stmt.sourceLine) lowerStatement \(Self.statementKind(stmt))")
        switch stmt {

        case .bind(let s):
            return try lowerBind(s, mode: mode, depth: depth, scope: scope)

        case .rebind(let s):
            return try lowerRebind(s, mode: mode, depth: depth, scope: scope)

        case .note(let s):
            return try lowerNote(s, scope: scope)

        case .emit(let s):
            let ir = EmitIR(
                eventID: s.eventID,
                payload: try s.payload.map { EmitField($0.0, try lowerExpr($0.1, scope: scope, line: s.sourceLine)) },
                strict: mode == .strict,
                sourceRange: sourceRange(s.sourceLine)
            )
            return [.emit(ir)]

        case .complete(let s):
            return [.complete(CompleteIR(reason: s.reason, sourceRange: sourceRange(s.sourceLine)))]

        case .commit(let s):
            return [.commit(CommitIR(label: s.label, sourceRange: sourceRange(s.sourceLine)))]

        case .wait(let s):
            let cond = try lowerWaitCondition(s.condition)
            let timeout = s.timeout.map { LiteralLowering.durationSeconds($0.value, unit: $0.unit) }
            let sr = sourceRange(s.sourceLine)
            var primitives: [IRPrimitive] = []
            if case .choice(let prompt, let options) = cond {
                let emit = EmitIR(
                    eventID: "ask.choice",
                    payload: [
                        EmitField("prompt", .literal(.string(prompt))),
                        EmitField("options", .literal(.string(options.joined(separator: ", "))))
                    ],
                    strict: true,
                    sourceRange: sr
                )
                primitives.append(.emit(emit))
            }
            let waitIR = WaitIR(condition: cond, timeout: timeout, sourceRange: sr)
            if let recover = s.timeoutRecover {
                let handler = try lowerBlock(recover, mode: mode, depth: depth, defaultParam: defaultParam,
                                             proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope)
                primitives.append(.recover(RecoverIR(
                    pattern: .named("wait.timeout"),
                    handler: handler,
                    attachedTo: IRBlock(statements: [.wait(waitIR)], sourceRange: sr),
                    sourceRange: sr
                )))
            } else {
                primitives.append(.wait(waitIR))
            }
            return primitives

        case .assertStmt(let s):
            let otherwise = try s.otherwise.map { try lowerBlock($0, mode: mode, depth: depth, scope: scope) }
            let condition = try lowerExpr(
                s.condition,
                scope: scope,
                line: s.sourceLine,
                allowsBoundedFutureMonitors: true
            )
            if case .traceStatistical = condition, otherwise != nil {
                let diag = Diagnostic.error(
                    .malformedCondition,
                    message: "statistical assertions cannot use an `otherwise` block",
                    range: sourceRange(s.sourceLine),
                    help: "Use a non-monitored statistical branch for point-in-time fallback logic, or remove the `otherwise` block from the monitored assertion."
                )
                try throwLoweringError(diag)
            }
            let monitor = try monitoredAssertConfig(for: condition, line: s.sourceLine)
            if assertNeedsExplicitDefaultPolicy(
                condition: condition,
                otherwise: otherwise,
                monitored: monitor.monitored,
                blocking: monitor.blocking
            ) {
                let diag = Diagnostic.error(
                    .traceMissingUnknownArm,
                    message: "blocking assert over a possibly-indeterminate `since the last` condition needs an explicit unknown/default policy",
                    range: sourceRange(s.sourceLine),
                    help: "Add an `otherwise:` block at this assert site so the missing-anchor / indeterminate case has an explicit default policy."
                )
                try throwLoweringError(diag)
            }
            return [.assert(AssertIR(
                condition: condition,
                message: s.message,
                otherwiseAction: otherwise,
                monitored: monitor.monitored,
                cadence: monitor.cadence,
                blocking: monitor.blocking,
                sourceRange: sourceRange(s.sourceLine)
            ))]

        case .conditional(let s):
            let thenBlock = try lowerBlock(s.thenBlock, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope)
            let unknownBlock = try s.unknownBlock.map { try lowerBlock($0, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope) }
            let elseBlock = try s.elseBlock.map { try lowerBlock($0, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope) }
            let condExpr  = try lowerExpr(s.condition, scope: scope, line: s.sourceLine)
            let unknownPolicy: UnknownHandlingPolicyIR
            switch s.unknownPolicy {
            case .explicit: unknownPolicy = .explicit
            case .asTrue: unknownPolicy = .asTrue
            case .asFalse: unknownPolicy = .asFalse
            }
            if unknownPolicy == .explicit,
               unknownBlock == nil,
               elseBlock == nil,
               IndeterminateAnalysis(symbols: symbols).possiblyIndeterminate(condExpr) {
                let diag = Diagnostic.error(
                    .traceMissingUnknownArm,
                    message: "possibly-indeterminate decision needs an `if it is unknown whether` or `otherwise` arm",
                    range: sourceRange(s.sourceLine),
                    help: "Add an explicit unknown arm for indeterminate results, add `treating unknown as true` or `treating unknown as false`, or add an `otherwise` arm that should handle both false and indeterminate."
                )
                try throwLoweringError(diag)
            }
            return [.branch(BranchIR(
                condition: .predicate(condExpr),
                thenBlock: thenBlock,
                unknownBlock: unknownBlock,
                elseBlock: elseBlock,
                unknownPolicy: unknownPolicy,
                authoredForm: s.authoredForm,
                sourceRange: sourceRange(s.sourceLine)
            ))]

        case .matchBranch(let s):
            let subject = try lowerExpr(s.subject, scope: scope, line: s.sourceLine)
            let cases = try s.cases.map { branchCase -> BranchCase in
                let pattern = try lowerMatchPattern(branchCase.pattern, scope: scope, line: s.sourceLine)
                let block = try lowerBlock(
                    branchCase.block, mode: mode, depth: depth,
                    defaultParam: defaultParam, proseDispatchMode: proseDispatchMode,
                    autonomyConfig: autonomyConfig, scope: scope
                )
                return BranchCase(pattern: pattern, block: block)
            }
            ParserTrace.current.log(.lowering, "match branch L\(s.sourceLine): \(cases.count) case(s) \(cases.map { matchPatternTraceName($0.pattern) }.joined(separator: ", ")), otherwise \(s.otherwiseBlock == nil ? "absent" : "present")")
            let otherwise = try s.otherwiseBlock.map {
                try lowerBlock(
                    $0, mode: mode, depth: depth,
                    defaultParam: defaultParam, proseDispatchMode: proseDispatchMode,
                    autonomyConfig: autonomyConfig, scope: scope
                )
            } ?? IRBlock(statements: [])
            return [.branch(BranchIR(
                condition: .match(subject, cases),
                thenBlock: otherwise,
                elseBlock: nil,
                sourceRange: sourceRange(s.sourceLine)
            ))]

        case .iteration(let s):
            // A for-each loop variable is in scope inside the body (so a command
            // hole like `{the attendee's name}` resolves under `for every
            // attendee`).
            var bodyScope = scope
            if case .forEach(let variable, _) = s.mode {
                bodyScope.insert(scopeKey(variable.trimmingCharacters(in: .whitespaces)))
            }
            let body = try lowerBlock(s.body, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: bodyScope)
            let range = sourceRange(s.sourceLine)
            switch s.mode {
            case .forEach(let variable, let collection):
                let param = variable.trimmingCharacters(in: .whitespaces)
                let coll  = try lowerExpr(collection, scope: scope, line: s.sourceLine)
                let refinement = try s.refinement.map { try lowerIterationRefinement($0, loopVar: param) }
                return [.iterate(IterateIR(
                    mode: .overCollection(parameter: param, kind: KindRef("Any"), collection: coll),
                    body: body, source: refinement, sourceRange: range
                ))]
            case .whileCondition(let cond):
                return [.iterate(IterateIR(
                    mode: .whileCondition(try lowerExpr(cond, scope: scope, line: s.sourceLine)),
                    body: body, sourceRange: range
                ))]
            case .untilCondition(let cond):
                return [.iterate(IterateIR(
                    mode: .untilCondition(try lowerExpr(cond, scope: scope, line: s.sourceLine)),
                    body: body, sourceRange: range
                ))]
            }

        case .simultaneously(let s):
            let branches = try s.branches.map { try lowerBlock($0, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope) }
            return [.simultaneously(SimultaneouslyIR(
                branches: branches,
                detached: s.detached,
                sourceRange: sourceRange(s.sourceLine)
            ))]

        case .phraseInvocation(let s):
            return try lowerPhraseInvocation(s, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope)

        case .recover(let s):
            return try lowerRecover(s, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope)

        case .labelled(let s):
            return try lowerStatement(s.statement, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope)

        case .proseStep(let s):
            // An explicit local marker (`use judgment to …:` / `with discretion:`
            // / `with autonomy …:`) sets the dispatch mode directly and is valid
            // in any workflow. Without an explicit marker, the prose step inherits
            // the enclosing workflow's mode — and is a hard error if the workflow
            // is not itself discretion/autonomy (no unmarked prose ever promotes).
            let effectiveMode: ProseDispatchMode?
            let effectiveAutonomy: AutonomyConfigIR?
            switch s.dispatch {
            case .discretion:
                effectiveMode = .planThenExecute
                effectiveAutonomy = autonomyConfig
            case .autonomy:
                effectiveMode = .autonomousLoop
                effectiveAutonomy = try s.autonomy.map(lowerAutonomyConfig)
                    ?? autonomyConfig ?? AutonomyConfigIR()
            case .none:
                effectiveMode = proseDispatchMode
                effectiveAutonomy = autonomyConfig
            }
            guard let mode = effectiveMode else {
                throw semanticError(
                    "free-form prose is only allowed in workflows marked `with discretion` or `with autonomy`, or inside an explicit `use judgment to …:` marker",
                    s.sourceLine, code: .proseDisallowed,
                    help: "Mark the workflow `with discretion`/`with autonomy` or wrap the step in `use judgment to …:`.")
            }
            return [makeAIPrimitive(
                text: s.text, dispatchMode: mode, autonomy: effectiveAutonomy, line: s.sourceLine,
                guidance: s.guidance, outputBindings: s.outputBindings, usingTools: s.usingTools)]

        case .modal:
            return []  // handled at block level
        }
    }

    private func lowerMatchPattern(
        _ pattern: MatchPatternAST,
        scope: Set<String>,
        line: Int
    ) throws -> IRPattern {
        switch pattern {
        case .literal(let expr):
            let lowered = try lowerExpr(expr, scope: scope, line: line)
            guard case .literal(let literal) = lowered else {
                let wildcard = lexicon.grammar.statement.matchBranchCanonicalWildcard
                throw semanticError(
                    "match-branch case pattern must be a literal, enum value, or \(wildcard)",
                    line, code: .matchBranchSemantic,
                    help: "Use a quoted literal (for example `\"ready\":`), an enum case, or the canonical wildcard `\(wildcard):`."
                )
            }
            return .literal(literal)
        case .enumValue(let value):
            return .enumValue(value, kind: "")
        case .wildcard:
            return .wildcard
        }
    }

    private func matchPatternTraceName(_ pattern: IRPattern) -> String {
        switch pattern {
        case .literal(let literal): return "literal(\(literal))"
        case .enumValue(let value, let kind): return kind.isEmpty ? "enum(\(value))" : "enum(\(kind).\(value))"
        case .wildcard: return "wildcard"
        }
    }

    // MARK: - Recover lowering

    private func lowerRecover(
        _ s: RecoverStatementAST,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: (parameter: PhraseParameterAST, owningStructName: String)? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil,
        scope: Set<String> = []
    ) throws -> [IRPrimitive] {
        let pattern = try lowerRecoverPattern(s.pattern)
        let handlerBlock = try lowerBlock(s.handler, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope)
        // Lower the attached statement into an IRBlock so the recover wraps
        // the full set of IR primitives, even when a phrase inlines to several.
        let attachedPrimitives = try lowerStatement(s.attached, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope)
        let attachedBlock = IRBlock(statements: attachedPrimitives, sourceRange: sourceRange(s.attached.sourceLine))
        return [.recover(RecoverIR(
            pattern: pattern,
            handler: handlerBlock,
            attachedTo: attachedBlock,
            sourceRange: sourceRange(s.sourceLine)
        ))]
    }

    private func lowerRecoverPattern(_ p: RecoverPatternAST) throws -> ErrorPattern {
        switch p {
        case .any:              return .anyError
        case .named(let n):     return .named(n)
        case .typed(let t):     return .typed(KindRef(t))
        case .predicate(let e): return .predicate(try lowerExpr(e))
        }
    }


    private static func statementKind(_ stmt: StatementAST) -> String {
        switch stmt {
        case .bind: return "bind"
        case .rebind: return "rebind"
        case .note: return "note"
        case .emit: return "emit"
        case .complete: return "complete"
        case .commit: return "commit"
        case .wait: return "wait"
        case .assertStmt: return "assert"
        case .conditional: return "branch"
        case .matchBranch: return "matchBranch"
        case .iteration: return "iterate"
        case .recover: return "recover"
        case .simultaneously: return "simultaneously"
        case .phraseInvocation: return "phrase"
        case .proseStep: return "prose"
        case .modal: return "modal"
        case .labelled: return "labelled"
        }
    }
}
