import Foundation
import MeridianRuntime

// Branch / simultaneously / assert / recover / wait / complete / commit —
// extracted from SwiftEmitter for Phase 3 readability.

extension SwiftEmitter {

    // MARK: - 3. branch

    func emitBranch(_ ir: BranchIR, ctx: Ctx, workflow: IRWorkflow, path: String = "0") -> StringTemplate {
        let trace = ParserTrace.current
        let inner = ctx.in(1)
        switch ir.condition {
        case .predicate:
            trace.log(.codegen, "emit branch \(path): predicate arm")
        case .match(_, let cases):
            trace.log(.codegen, "emit branch \(path): match with \(cases.count) case arm(s), default \(ir.thenBlock.statements.isEmpty ? "absent" : "present")")
            for (idx, c) in cases.enumerated() {
                trace.log(.codegen, "emit branch \(path).case\(idx): match \(patternTraceName(c.pattern))")
            }
            if !ir.thenBlock.statements.isEmpty {
                trace.log(.codegen, "emit branch \(path).default: match otherwise")
            }
        }
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            switch ir.condition {
            case .predicate(let expr):
                let conditionText = emitExprUnchecked(expr)
                if expressionMayBeIndeterminate(expr) {
                    let truthVar = "__meridianTruth_\(swiftIdentifierSuffix(path))"
                    let thenCondition = indeterminateThenCondition(truthVar: truthVar, policy: ir.unknownPolicy)
                    "\(ctx.s)let \(truthVar) = \(emitTruthValueExpr(expr))"
                    "\(ctx.s)if \(thenCondition) {"
                    emitBranchTakenCall(ctx: inner, condition: conditionText, into: "then", stableStepPath: ir.stableStepPath)
                    emitBlock(ir.thenBlock, ctx: inner, workflow: workflow, path: "\(path).then")
                    emitBranchEndedCall(ctx: inner, into: "then", stableStepPath: ir.stableStepPath)
                    if let unknownBlock = ir.unknownBlock, ir.unknownPolicy == .explicit {
                        "\(ctx.s)} else if \(truthVar) == .indeterminate {"
                        emitBranchTakenCall(ctx: inner, condition: conditionText, into: "unknown", stableStepPath: ir.stableStepPath)
                        emitBlock(unknownBlock, ctx: inner, workflow: workflow, path: "\(path).unknown")
                        emitBranchEndedCall(ctx: inner, into: "unknown", stableStepPath: ir.stableStepPath)
                        if let elseBlock = ir.elseBlock {
                            "\(ctx.s)} else {"
                            emitBranchTakenCall(ctx: inner, condition: conditionText, into: "otherwise", stableStepPath: ir.stableStepPath)
                            emitBlock(elseBlock, ctx: inner, workflow: workflow, path: "\(path).else")
                            emitBranchEndedCall(ctx: inner, into: "otherwise", stableStepPath: ir.stableStepPath)
                        }
                    } else                     if let elseBlock = ir.elseBlock {
                        "\(ctx.s)} else {"
                        emitBranchTakenCall(ctx: inner, condition: conditionText, into: "otherwise", stableStepPath: ir.stableStepPath)
                        emitDeonticDenyIfNeeded(ir.deonticGuard, ctx: inner, stableStepPath: ir.stableStepPath)
                        emitBlock(elseBlock, ctx: inner, workflow: workflow, path: "\(path).else")
                        emitBranchEndedCall(ctx: inner, into: "otherwise", stableStepPath: ir.stableStepPath)
                    } else if let guardIR = ir.deonticGuard {
                        "\(ctx.s)} else {"
                        emitBranchTakenCall(ctx: inner, condition: conditionText, into: "otherwise", stableStepPath: ir.stableStepPath)
                        emitDeonticDeny(guardIR, ctx: inner, stableStepPath: ir.stableStepPath)
                        emitBranchEndedCall(ctx: inner, into: "otherwise", stableStepPath: ir.stableStepPath)
                    }
                } else {
                    "\(ctx.s)if \(conditionText) {"
                    emitBranchTakenCall(ctx: inner, condition: conditionText, into: "then", stableStepPath: ir.stableStepPath)
                    emitBlock(ir.thenBlock, ctx: inner, workflow: workflow, path: "\(path).then")
                    emitBranchEndedCall(ctx: inner, into: "then", stableStepPath: ir.stableStepPath)
                    if let elseBlock = ir.elseBlock {
                        "\(ctx.s)} else {"
                        emitBranchTakenCall(ctx: inner, condition: conditionText, into: "otherwise", stableStepPath: ir.stableStepPath)
                        emitDeonticDenyIfNeeded(ir.deonticGuard, ctx: inner, stableStepPath: ir.stableStepPath)
                        emitBlock(elseBlock, ctx: inner, workflow: workflow, path: "\(path).else")
                        emitBranchEndedCall(ctx: inner, into: "otherwise", stableStepPath: ir.stableStepPath)
                    } else if let guardIR = ir.deonticGuard {
                        "\(ctx.s)} else {"
                        emitBranchTakenCall(ctx: inner, condition: conditionText, into: "otherwise", stableStepPath: ir.stableStepPath)
                        emitDeonticDeny(guardIR, ctx: inner, stableStepPath: ir.stableStepPath)
                        emitBranchEndedCall(ctx: inner, into: "otherwise", stableStepPath: ir.stableStepPath)
                    }
                }
                "\(ctx.s)}"
            case .match(let expr, let cases):
                // Verbalizer `otherwise:` ↔ IR `thenBlock` ↔ codegen `default:`.
                let discriminant = emitExprUnchecked(expr)
                "\(ctx.s)switch \(discriminant) {"
                for (idx, c) in cases.enumerated() {
                    "\(ctx.s)case \(emitPattern(c.pattern)):"
                    emitBranchTakenCall(ctx: inner, condition: discriminant, into: patternTraceName(c.pattern), stableStepPath: ir.stableStepPath)
                    emitBlock(c.block, ctx: inner, workflow: workflow, path: "\(path).case\(idx)")
                    emitBranchEndedCall(ctx: inner, into: patternTraceName(c.pattern), stableStepPath: ir.stableStepPath)
                }
                if !ir.thenBlock.statements.isEmpty {
                    "\(ctx.s)default:"
                    emitBranchTakenCall(ctx: inner, condition: discriminant, into: "otherwise", stableStepPath: ir.stableStepPath)
                    emitBlock(ir.thenBlock, ctx: inner, workflow: workflow, path: "\(path).default")
                    emitBranchEndedCall(ctx: inner, into: "otherwise", stableStepPath: ir.stableStepPath)
                }
                "\(ctx.s)}"
            }
            ""
        }
    }

    /// `branch.taken` / `branch.end` instrumentation (8B/E): taken is the first
    /// statement of whichever arm is entered; end closes the arm so
    /// `TraceTreeRenderer` can nest the body under the decision.
    func indeterminateThenCondition(truthVar: String, policy: UnknownHandlingPolicyIR) -> String {
        switch policy {
        case .asTrue:
            return "\(truthVar) == .true || \(truthVar) == .indeterminate"
        case .asFalse, .explicit:
            return "\(truthVar) == .true"
        }
    }

    func emitBranchTakenCall(ctx: Ctx, condition: String, into: String, stableStepPath: String?) -> String {
        let step = "\"\(escapeSwiftStringLiteral(stableStepPath ?? "branch"))\""
        return "\(ctx.s)try await runtime.recordBranchTaken(condition: \"\(escapeSwiftStringLiteral(condition))\", into: \"\(escapeSwiftStringLiteral(into))\", step: \(step))"
    }

    func emitBranchEndedCall(ctx: Ctx, into: String, stableStepPath: String?) -> String {
        let step = "\"\(escapeSwiftStringLiteral(stableStepPath ?? "branch"))\""
        return "\(ctx.s)try await runtime.recordBranchEnded(into: \"\(escapeSwiftStringLiteral(into))\", step: \(step))"
    }

    func emitDeonticDenyIfNeeded(_ guardIR: DeonticGuardIR?, ctx: Ctx, stableStepPath: String?) -> StringTemplate {
        guard let guardIR else { return StringTemplate { "" } }
        return emitDeonticDeny(guardIR, ctx: ctx, stableStepPath: stableStepPath)
    }

    func emitDeonticDeny(_ guardIR: DeonticGuardIR, ctx: Ctx, stableStepPath: String?) -> StringTemplate {
        let step = "\"\(escapeSwiftStringLiteral(stableStepPath ?? guardIR.actionPattern.toolID))\""
        let tool = escapeSwiftStringLiteral(guardIR.actionPattern.toolID)
        let disposition = escapeSwiftStringLiteral(guardIR.disposition.rawValue)
        let normID = escapeSwiftStringLiteral(guardIR.normID)
        return StringTemplate {
            "\(ctx.s)try await runtime.recordViolation(normID: \"\(normID)\", disposition: \"\(disposition)\", blocking: \(guardIR.blocking), toolID: \"\(tool)\", step: \(step))"
            if guardIR.blocking {
                "\(ctx.s)throw MeridianRuntimeError.violation(message: \"deontic prohibition blocked invoke of \(tool)\")"
            }
        }
    }

    // MARK: - 10. complete

    func emitComplete(_ ir: CompleteIR, ctx: Ctx) -> StringTemplate {
        let reasonStr = ir.reason.map { "\"\(escapeSwiftStringLiteral($0))\"" } ?? "nil"
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)await runtime.complete(reason: \(reasonStr), step: \"\(escapeSwiftStringLiteral(ir.stableStepPath ?? "complete"))\")"
            "\(ctx.s)return WorkflowResult(reason: \(reasonStr), durationMS: await runtime.elapsedMS(), eventCount: await runtime.eventCount(), bindings: state.snapshot().asValues)"
        }
    }

    // MARK: - 8. commit

    func emitCommit(_ ir: CommitIR, ctx: Ctx) -> StringTemplate {
        let labelStr = "\"\(escapeSwiftStringLiteral(ir.label ?? ir.stableStepPath ?? "commit"))\""
        let step = escapeSwiftStringLiteral(ir.stableStepPath ?? ir.label ?? "commit")
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)try await runtime.checkpoint(label: \(labelStr), state: state.snapshot(), step: \"\(step)\")"
        }
    }

    // MARK: - 4b. simultaneously

    func emitSimultaneously(_ ir: SimultaneouslyIR, ctx: Ctx, workflow: IRWorkflow, path: String = "0") -> StringTemplate {
        // Detached / background spawn (`in the background, <stmt>.`): each branch
        // runs in a fire-and-forget `Task`; the workflow does NOT join. State is
        // captured by value so the detached work sees a snapshot.
        if ir.detached {
            let taskCtx = ctx.in(1)
            return StringTemplate {
                sourceLineComment(ir.sourceRange, ctx: ctx)
                for (idx, branch) in ir.branches.enumerated() {
                    "\(ctx.s)Task {"
                    "\(taskCtx.s)var state = state"
                    emitBlock(branch, ctx: taskCtx, workflow: workflow, path: "\(path).detached\(idx)")
                    "\(ctx.s)}"
                }
                ""
            }
        }
        let groupCtx = ctx.in(1)
        let branchCtx = ctx.in(3)
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)try await withThrowingTaskGroup(of: Void.self) { group in"
            for (idx, branch) in ir.branches.enumerated() {
                "\(groupCtx.s)group.addTask {"
                "\(groupCtx.in(1).s)var state = state"
                emitBlock(branch, ctx: branchCtx, workflow: workflow, path: "\(path).branch\(idx)")
                "\(groupCtx.s)}"
            }
            "\(groupCtx.s)try await group.waitForAll()"
            "\(ctx.s)}"
            ""
        }
    }

    // MARK: - 5. assert

    func emitAssert(_ ir: AssertIR, ctx: Ctx, workflow: IRWorkflow, path: String = "0") -> StringTemplate {
        let msg = escapeSwiftStringLiteral(ir.message ?? "assertion failed")
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            if ir.monitored, case .traceStatistical(let statistical) = ir.condition, let cadence = ir.cadence {
                "\(ctx.s)await runtime.registerMonitor("
                "\(ctx.s)    query: \(emitTraceStatisticalQuery(statistical)),"
                "\(ctx.s)    cadence: .seconds(\(cadence.components.seconds)),"
                "\(ctx.s)    message: \"\(msg)\","
                "\(ctx.s)    blocking: \(ir.blocking),"
                "\(ctx.s)    step: \"\(escapeSwiftStringLiteral(ir.stableStepPath ?? "assert.monitor"))\","
                "\(ctx.s)    sourceRange: nil"
                "\(ctx.s))"
            } else if let action = ir.otherwiseAction {
                // `assert X otherwise: …` form — run the otherwise block but
                // still surface the failure as an `assert.failed` event so
                // observers see it. The block decides whether to throw.
                if expressionMayBeIndeterminate(ir.condition) {
                    let truthVar = "__meridianAssertTruth_\(swiftIdentifierSuffix(path))"
                    "\(ctx.s)let \(truthVar) = \(emitTruthValueExpr(ir.condition))"
                    "\(ctx.s)if \(truthVar) != .true {"
                    "\(ctx.in(1).s)try await runtime.assert(\(truthVar), message: \"\(msg)\")"
                } else {
                    "\(ctx.s)if !(\(emitExprUnchecked(ir.condition))) {"
                    "\(ctx.in(1).s)try await runtime.assert(false, message: \"\(msg)\")"
                }
                emitBlock(action, ctx: ctx.in(1), workflow: workflow, path: "\(path).otherwise")
                "\(ctx.s)} else {"
                if expressionMayBeIndeterminate(ir.condition) {
                    "\(ctx.in(1).s)try await runtime.assert(TruthValue.true, message: \"\(msg)\")"
                } else {
                    "\(ctx.in(1).s)try await runtime.assert(true, message: \"\(msg)\")"
                }
                "\(ctx.s)}"
            } else {
                let step = "\"\(escapeSwiftStringLiteral(ir.stableStepPath ?? "assert"))\""
                if let normID = ir.normID {
                    if expressionMayBeIndeterminate(ir.condition) {
                        let truthVar = "__meridianAssertTruth_\(swiftIdentifierSuffix(path))"
                        "\(ctx.s)let \(truthVar) = \(emitTruthValueExpr(ir.condition))"
                        "\(ctx.s)if \(truthVar) != .true {"
                        "\(ctx.in(1).s)try await runtime.recordViolation(normID: \"\(escapeSwiftStringLiteral(normID))\", disposition: \"observed\", blocking: \(ir.blocking), toolID: nil, step: \(step))"
                        "\(ctx.in(1).s)try await runtime.assert(\(truthVar), message: \"\(msg)\", step: \(step))"
                        "\(ctx.s)} else {"
                        "\(ctx.in(1).s)try await runtime.assert(TruthValue.true, message: \"\(msg)\", step: \(step))"
                        "\(ctx.s)}"
                    } else {
                        "\(ctx.s)if !(\(emitExprUnchecked(ir.condition))) {"
                        "\(ctx.in(1).s)try await runtime.recordViolation(normID: \"\(escapeSwiftStringLiteral(normID))\", disposition: \"observed\", blocking: \(ir.blocking), toolID: nil, step: \(step))"
                        "\(ctx.in(1).s)try await runtime.assert(false, message: \"\(msg)\", step: \(step))"
                        "\(ctx.s)} else {"
                        "\(ctx.in(1).s)try await runtime.assert(true, message: \"\(msg)\", step: \(step))"
                        "\(ctx.s)}"
                    }
                } else if expressionMayBeIndeterminate(ir.condition) {
                    "\(ctx.s)try await runtime.assert(\(emitTruthValueExpr(ir.condition)), message: \"\(msg)\")"
                } else {
                    "\(ctx.s)try await runtime.assert(\(emitExprUnchecked(ir.condition)), message: \"\(msg)\")"
                }
            }
        }
    }

    // MARK: - 9. recover

    func emitRecover(_ ir: RecoverIR, ctx: Ctx, workflow: IRWorkflow, path: String = "0") -> StringTemplate {
        let (catchClause, _) = errorPatternClause(ir.pattern)
        let step = "\"\(escapeSwiftStringLiteral(ir.stableStepPath ?? "recover"))\""
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)do {"
            emitBlock(ir.attachedTo, ctx: ctx.in(1), workflow: workflow, path: "\(path).do")
            "\(ctx.s)} catch \(catchClause){"
            // `recover.engaged` instrumentation (8B/E) — `TraceTreeRenderer`
            // already renders this kind (semantic tag `recovered`); this call
            // site was the only missing link.
            "\(ctx.in(1).s)try await runtime.recordRecoverEngaged(pattern: \"\(escapeSwiftStringLiteral(errorPatternTraceName(ir.pattern)))\", step: \(step))"
            emitBlock(ir.handler, ctx: ctx.in(1), workflow: workflow, path: "\(path).catch")
            "\(ctx.s)}"
        }
    }

    /// Human-readable description of an `ErrorPattern` for `recover.engaged`'s
    /// `pattern` payload field. Mirrors `patternTraceName`'s style for `IRPattern`.
    func errorPatternTraceName(_ p: ErrorPattern) -> String {
        switch p {
        case .anyError: return "any"
        case .named(let n): return n
        case .typed(let k): return k.name
        case .predicate(let expr): return emitExprUnchecked(expr)
        }
    }

    /// Returns the catch clause string and whether a trailing space is already included.
    ///
    /// For `.named`, the generated clause uses `meridianMatches(_:named:)` from
    /// `MeridianRuntimeError.swift` so no non-existent `.isNamed` member is called.
    /// For `.predicate`, a synthetic `_recoveredError` binding is always produced;
    /// the predicate expression is emitted as a `where` guard.
    func errorPatternClause(_ p: ErrorPattern) -> (clause: String, hasSpace: Bool) {
        switch p {
        case .anyError:
            return ("let _recoveredError ", true)
        case .named(let n):
            return ("let _recoveredError where meridianMatches(_recoveredError, named: \"\(n)\") ", true)
        case .typed(let k):
            return ("let _recoveredError as \(k.name) ", true)
        case .predicate(let expr):
            return ("let _recoveredError where \(emitExprUnchecked(expr)) ", true)
        }
    }

    // MARK: - 7. wait

    func emitWait(_ ir: WaitIR, ctx: Ctx) -> StringTemplate {
        let timeoutExpr = ir.timeout.map { "timeout: .seconds(\($0.components.seconds)), " } ?? ""
        let rangeExpr = "sourceRange: nil"
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            switch ir.condition {
            case .duration(let d):
                "\(ctx.s)try await runtime.wait(.duration(.seconds(\(d.components.seconds))), \(timeoutExpr)\(rangeExpr))"
            case .signal(let id):
                "\(ctx.s)try await runtime.wait(.signal(\"\(escapeSwiftStringLiteral(id))\"), \(timeoutExpr)\(rangeExpr))"
            case .approval(let subj, let role):
                let subjExpr = emitValueExprUnchecked(subj)
                "\(ctx.s)try await runtime.wait(.approval(of: \(subjExpr), by: RoleRef(identifier: \"\(role)\")), \(timeoutExpr)\(rangeExpr))"
            case .event(let id, let matching):
                if let m = matching {
                    "\(ctx.s)try await runtime.wait(.event(\"\(id)\", matching: { _event in \(emitExprUnchecked(m)) }), \(timeoutExpr)\(rangeExpr))"
                } else {
                    "\(ctx.s)try await runtime.wait(.event(\"\(id)\", matching: nil), \(timeoutExpr)\(rangeExpr))"
                }
            case .choice(let prompt, let options):
                let optsList = options.map { "\"\(escapeSwiftStringLiteral($0))\"" }.joined(separator: ", ")
                "\(ctx.s)try await runtime.wait(.choice(prompt: \"\(escapeSwiftStringLiteral(prompt))\", options: [\(optsList)]), \(timeoutExpr)\(rangeExpr))"
                "\(ctx.s)state.bind(\"choice\", .string(await runtime.consumeChoiceSelection()))"
            }
        }
    }

}
