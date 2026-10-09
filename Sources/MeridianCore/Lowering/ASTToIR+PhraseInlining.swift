import Foundation
import MeridianRuntime

// Phrase inlining / argument substitution — extracted from ASTToIR for Phase 3 readability.

extension ASTToIR {

    // MARK: - Phrase inlining

    func inlinePhrase(
        _ phrase: PhraseDefinition,
        args: [String: ExpressionAST],
        invocationLine: Int,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: (parameter: PhraseParameterAST, owningStructName: String)? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil
    ) throws -> [IRPrimitive] {
        let trace = ParserTrace.current
        let token = trace.push(.phraseInline, "inline phrase @L\(phrase.sourceLine)")
        defer { trace.pop(token) }
        // Expanded primitives belong to the invocation site. Retaining the
        // merconfig phrase-definition lines here makes source maps point at a
        // different file and can assign stable step paths to an unrelated
        // markdown section that happens to share the same line number.
        let inlinedBlock = retargetSourceLines(
            in: substituteArgs(phrase.body, args: args),
            to: invocationLine
        )
        return try lowerBlock(inlinedBlock, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig).statements
    }

    private func retargetSourceLines(in block: ASTBlock, to line: Int) -> ASTBlock {
        ASTBlock(
            statements: block.statements.map { retargetSourceLines(in: $0, to: line) },
            sourceLine: line
        )
    }

    private func retargetSourceLines(in statement: StatementAST, to line: Int) -> StatementAST {
        switch statement {
        case .bind(let ast):
            return .bind(BindStatementAST(name: ast.name, value: ast.value, sourceLine: line))
        case .rebind(let ast):
            return .rebind(RebindStatementAST(name: ast.name, value: ast.value, sourceLine: line))
        case .note(let ast):
            return .note(NoteStatementAST(binding: ast.binding, text: ast.text, sourceLine: line))
        case .emit(let ast):
            return .emit(EmitStatementAST(eventID: ast.eventID, payload: ast.payload, sourceLine: line))
        case .assertStmt(let ast):
            return .assertStmt(AssertStatementAST(
                condition: ast.condition,
                message: ast.message,
                otherwise: ast.otherwise.map { retargetSourceLines(in: $0, to: line) },
                sourceLine: line
            ))
        case .wait(let ast):
            return .wait(WaitStatementAST(condition: ast.condition, sourceLine: line))
        case .commit(let ast):
            return .commit(CommitStatementAST(label: ast.label, sourceLine: line))
        case .complete(let ast):
            return .complete(CompleteStatementAST(reason: ast.reason, sourceLine: line))
        case .conditional(let ast):
            return .conditional(ConditionalStatementAST(
                condition: ast.condition,
                thenBlock: retargetSourceLines(in: ast.thenBlock, to: line),
                unknownBlock: ast.unknownBlock.map { retargetSourceLines(in: $0, to: line) },
                elseBlock: ast.elseBlock.map { retargetSourceLines(in: $0, to: line) },
                sourceLine: line
            ))
        case .matchBranch(let ast):
            return .matchBranch(MatchBranchStatementAST(
                subject: ast.subject,
                cases: ast.cases.map {
                    MatchBranchCaseAST(
                        pattern: $0.pattern,
                        block: retargetSourceLines(in: $0.block, to: line)
                    )
                },
                otherwiseBlock: ast.otherwiseBlock.map { retargetSourceLines(in: $0, to: line) },
                sourceLine: line
            ))
        case .iteration(let ast):
            return .iteration(IterationStatementAST(
                mode: ast.mode,
                body: retargetSourceLines(in: ast.body, to: line),
                sourceLine: line,
                refinement: ast.refinement
            ))
        case .simultaneously(let ast):
            return .simultaneously(SimultaneouslyStatementAST(
                branches: ast.branches.map { retargetSourceLines(in: $0, to: line) },
                detached: ast.detached,
                sourceLine: line
            ))
        case .recover(let ast):
            return .recover(RecoverStatementAST(
                pattern: ast.pattern,
                handler: retargetSourceLines(in: ast.handler, to: line),
                attached: retargetSourceLines(in: ast.attached, to: line),
                sourceLine: line
            ))
        case .labelled(let ast):
            return .labelled(LabelledStatementAST(
                label: ast.label,
                statement: retargetSourceLines(in: ast.statement, to: line),
                sourceLine: line
            ))
        case .proseStep(let ast):
            return .proseStep(ProseStepAST(
                text: ast.text,
                sourceLine: line,
                dispatch: ast.dispatch,
                autonomy: ast.autonomy,
                guidance: ast.guidance,
                outputBindings: ast.outputBindings,
                usingTools: ast.usingTools
            ))
        case .modal:
            return statement
        case .phraseInvocation(let ast):
            return .phraseInvocation(PhraseInvocationAST(
                words: ast.words,
                annotation: ast.annotation,
                sourceLine: line
            ))
        }
    }

    /// Substitute phrase parameter names in an AST block with caller arguments.
    /// This is a simple syntactic substitution on identifierRef nodes.
    func substituteArgs(_ block: ASTBlock, args: [String: ExpressionAST]) -> ASTBlock {
        guard !args.isEmpty else { return block }
        let stmts = block.statements.map { substituteStmt($0, args: args) }
        return ASTBlock(statements: stmts, sourceLine: block.sourceLine)
    }

    private func substituteStmt(_ stmt: StatementAST, args: [String: ExpressionAST]) -> StatementAST {
        switch stmt {
        case .bind(let s):
            return .bind(BindStatementAST(name: s.name, value: subExpr(s.value, args: args), sourceLine: s.sourceLine))
        case .rebind(let s):
            return .rebind(RebindStatementAST(name: s.name, value: subExpr(s.value, args: args), sourceLine: s.sourceLine))
        case .emit(let s):
            let payload = s.payload.map { ($0.0, subExpr($0.1, args: args)) }
            return .emit(EmitStatementAST(eventID: s.eventID, payload: payload, sourceLine: s.sourceLine))
        case .conditional(let s):
            let thenBlock = substituteArgs(s.thenBlock, args: args)
            let elseBlock = s.elseBlock.map { substituteArgs($0, args: args) }
            return .conditional(ConditionalStatementAST(
                condition: subExpr(s.condition, args: args),
                thenBlock: thenBlock, elseBlock: elseBlock, sourceLine: s.sourceLine))
        case .matchBranch(let s):
            let cases = s.cases.map { branchCase in
                let pattern: MatchPatternAST
                switch branchCase.pattern {
                case .literal(let expr):
                    pattern = .literal(subExpr(expr, args: args))
                case .enumValue(let value):
                    pattern = .enumValue(value)
                case .wildcard:
                    pattern = .wildcard
                }
                return MatchBranchCaseAST(
                    pattern: pattern,
                    block: substituteArgs(branchCase.block, args: args)
                )
            }
            return .matchBranch(MatchBranchStatementAST(
                subject: subExpr(s.subject, args: args),
                cases: cases,
                otherwiseBlock: s.otherwiseBlock.map { substituteArgs($0, args: args) },
                sourceLine: s.sourceLine
            ))
        case .simultaneously(let s):
            return .simultaneously(SimultaneouslyStatementAST(
                branches: s.branches.map { substituteArgs($0, args: args) },
                sourceLine: s.sourceLine
            ))
        case .phraseInvocation(let s):
            // Substitute named references in the invocation text. Two correctness
            // requirements:
            //   1. Iterate longest param first ("emailAddress" before "email"),
            //      otherwise replacing "the email" inside "the email address"
            //      damages the longer slot.
            //   2. Use whole-word matching for both "the X" and bare X forms.
            //      Param names are camelCase ("mailerServer"); body text usually
            //      writes the spaced form ("mailer server") — we try both, plus
            //      the legacy snake form, so source written in any convention
            //      still resolves.
            var words = s.words
            let ordered = args.sorted { $0.key.count > $1.key.count }
            for (param, argExpr) in ordered {
                let argText = exprToText(argExpr)
                let spaced = decamel(param).replacingOccurrences(of: "_", with: " ")
                let snake  = param.replacingOccurrences(of: " ", with: "_")
                let variants = Array(Set([spaced, snake, param]))
                if let definiteArticle = lexicon.definiteArticle {
                    for v in variants {
                        words = WholeWordRegex.replace(words, of: "\(definiteArticle) \(v)", with: argText)
                    }
                }
                for v in variants {
                    words = WholeWordRegex.replace(words, of: v, with: argText)
                }
            }
            return .phraseInvocation(PhraseInvocationAST(words: words, sourceLine: s.sourceLine))
        case .labelled(let s):
            return .labelled(LabelledStatementAST(
                label: s.label,
                statement: substituteStmt(s.statement, args: args),
                sourceLine: s.sourceLine
            ))
        case .proseStep:
            return stmt
        case .complete(let s):
            return .complete(CompleteStatementAST(reason: s.reason, sourceLine: s.sourceLine))
        default:
            return stmt
        }
    }

    private func subExpr(_ expr: ExpressionAST, args: [String: ExpressionAST]) -> ExpressionAST {
        switch expr {
        case .identifierRef(let name):
            // Phrase-arg substitution tries three forms in order so the
            // lookup tolerates whichever convention the surrounding source
            // uses: original spaced ("payment processor"), snake_case
            // ("payment_processor", legacy), and camelCase ("paymentProcessor").
            let lower = name.lowercased().trimmingCharacters(in: .whitespaces)
            let snake = lower.replacingOccurrences(of: " ", with: "_")
            let camel = IdentifierNaming.lowerCamel(lower)
            return args[lower] ?? args[snake] ?? args[camel] ?? expr
        case .propertyAccess(let base, let prop):
            let subBase = subExpr(base, args: args)
            return .propertyAccess(subBase, prop)
        case .invoke(let toolID, let callArgs):
            return .invoke(toolID, callArgs.map { ($0.0, subExpr($0.1, args: args)) })
        case .comparison(let lhs, let op, let rhs):
            return .comparison(subExpr(lhs, args: args), op, subExpr(rhs, args: args))
        case .logical(let op, let exprs):
            return .logical(op, exprs.map { subExpr($0, args: args) })
        case .instanceRef, .constantRef, .literal, .envVar, .now, .decideWhether, .malformed:
            return expr
        case .quantified(let q):
            return .quantified(QuantifierAST(
                kind: q.kind,
                description: subDescription(q.description, args: args),
                body: q.body.map { subExpr($0, args: args) }
            ))
        case .verbPredicate(let s, let v, let o):
            return .verbPredicate(subject: subExpr(s, args: args), verb: v, object: subExpr(o, args: args))
        case .relationTraversal(let b, let r, let nk):
            return .relationTraversal(subExpr(b, args: args), relation: r, navKind: nk)
        case .description(let d):
            return .description(subDescription(d, args: args))
        case .aggregate(let k, let d):
            return .aggregate(k, subDescription(d, args: args))
        case .superlative(let s):
            return .superlative(SuperlativeAST(description: subDescription(s.description, args: args),
                                               property: s.property, ascending: s.ascending))
        case .interpolatedString(let segs):
            return .interpolatedString(segs.map { seg in
                switch seg {
                case .literal:           return seg
                case .expression(let e): return .expression(subExpr(e, args: args))
                case .conditional(let c, let t, let o):
                    return .conditional(
                        condition: subExpr(c, args: args),
                        then: t.map { subInterpolationSegment($0, args: args) },
                        otherwise: o.map { subInterpolationSegment($0, args: args) }
                    )
                case .forEach(let v, let c, let b):
                    return .forEach(variable: v, collection: subExpr(c, args: args), body: b.map { subInterpolationSegment($0, args: args) })
                case .formatted(let e, let f):
                    return .formatted(subExpr(e, args: args), formatter: f)
                }
            })
        case .recordList(let fields, let rows):
            return .recordList(fields: fields, rows: rows.map { $0.map { subExpr($0, args: args) } })
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return .tableLookup(table: table, keyColumn: keyColumn, key: subExpr(key, args: args), valueColumn: valueColumn)
        case .eventPattern(let pattern):
            return .eventPattern(subEventPattern(pattern, args: args))
        case .traceTemporal(let temporal):
            let kind: TraceTemporalKindAST
            switch temporal.kind {
            case .ever(let pattern):
                kind = .ever(subEventPattern(pattern, args: args))
            case .withinWindow(let pattern, let duration):
                kind = .withinWindow(subEventPattern(pattern, args: args), duration: duration)
            case .countInWindow(let pattern, let comparator, let duration):
                kind = .countInWindow(subEventPattern(pattern, args: args), comparator: comparator, duration: duration)
            case .inARow(let pattern, let count):
                kind = .inARow(subEventPattern(pattern, args: args), count: count)
            case .sinceLast(let anchor, let holds):
                kind = .sinceLast(anchor: subEventPattern(anchor, args: args), holds: subExpr(holds, args: args))
            case .boundedFutureMonitor(let condition, let horizon, let mode):
                kind = .boundedFutureMonitor(condition: subExpr(condition, args: args), horizon: horizon, mode: mode)
            }
            return .traceTemporal(TraceTemporalAST(scope: temporal.scope, kind: kind))
        case .traceStatistical(let statistical):
            return .traceStatistical(TraceStatisticalAST(
                scope: statistical.scope,
                pattern: TraceStatisticalPatternAST(
                    subject: statistical.pattern.subject,
                    payloadPredicate: statistical.pattern.payloadPredicate.map { subExpr($0, args: args) }
                ),
                outcome: statistical.outcome,
                bound: statistical.bound,
                denominator: statistical.denominator,
                window: statistical.window,
                monitorCadence: statistical.monitorCadence,
                blocking: statistical.blocking,
                confidencePercent: statistical.confidencePercent
            ))
        }
    }

    private func subEventPattern(_ pattern: EventPatternAST, args: [String: ExpressionAST]) -> EventPatternAST {
        EventPatternAST(
            subject: pattern.subject,
            outcome: pattern.outcome,
            payloadPredicate: pattern.payloadPredicate.map { subExpr($0, args: args) },
            negated: pattern.negated
        )
    }

    private func subInterpolationSegment(_ seg: InterpolationSegment, args: [String: ExpressionAST]) -> InterpolationSegment {
        switch seg {
        case .literal, .expression:
            if case .expression(let e) = seg { return .expression(subExpr(e, args: args)) }
            return seg
        case .conditional(let c, let t, let o):
            return .conditional(condition: subExpr(c, args: args),
                                then: t.map { subInterpolationSegment($0, args: args) },
                                otherwise: o.map { subInterpolationSegment($0, args: args) })
        case .forEach(let v, let c, let b):
            return .forEach(variable: v, collection: subExpr(c, args: args), body: b.map { subInterpolationSegment($0, args: args) })
        case .formatted(let e, let f):
            return .formatted(subExpr(e, args: args), formatter: f)
        }
    }

    /// Phrase-arg substitution inside a description (where-predicate + verb-clause
    /// operands recurse; adjectives/noun/sort/take are surface text untouched).
    private func subDescription(_ d: DescriptionAST, args: [String: ExpressionAST]) -> DescriptionAST {
        DescriptionAST(
            noun: d.noun,
            adjectives: d.adjectives,
            wherePredicate: d.wherePredicate.map { subExpr($0, args: args) },
            verbClauses: d.verbClauses.map {
                VerbClauseAST(verbForm: $0.verbForm,
                              operand: subExpr($0.operand, args: args),
                              elementIsSubject: $0.elementIsSubject)
            },
            sort: d.sort, take: d.take, takeFromEnd: d.takeFromEnd
        )
    }

    /// Render an ExpressionAST back to a text fragment for phrase text substitution.
    /// Identifiers render bare (without "the ") so substitution into a body that
    /// already has "the {param}" produces clean possessive forms like "order's id".
    /// `ExpressionParser` handles bare possessives in `parseAtom`.
    func exprToText(_ expr: ExpressionAST) -> String {
        switch expr {
        case .identifierRef(let n):             return n
        case .instanceRef(let n):               return [lexicon.definiteArticle, n].compactMap { $0 }.joined(separator: " ")
        case .constantRef(let n):               return [lexicon.definiteArticle, n].compactMap { $0 }.joined(separator: " ")
        case .propertyAccess(let base, let p):  return "\(exprToText(base))'s \(p)"
        case .literal(.string(let s)):          return "\"\(s)\""
        case .literal(.integer(let n)):         return "\(n)"
        case .literal(.double(let d)):          return "\(d)"
        case .literal(.money(let a, _)):        return "$\(a)"
        case .now:                              return "now"
        case .interpolatedString:              return ""
        default:                               return ""
        }
    }


}
