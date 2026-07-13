import Foundation
import MeridianRuntime

// Iterate / element-context emission — extracted from SwiftEmitter for
// Phase 3 readability. Shared element helpers are also used by
// SwiftEmitter+Expressions.

extension SwiftEmitter {

    // MARK: - 4. iterate

    func emitIterate(_ ir: IterateIR, ctx: Ctx, workflow: IRWorkflow, path: String = "0") -> StringTemplate {
        let inner = ctx.in(1)
        let loopIndex = "__meridianLoopIndex_\(swiftIdentifierSuffix(path))"
        let loopLabel = "__meridianLoopLabel_\(swiftIdentifierSuffix(path))"
        // 1C: a refined `overCollection` builds the iteration source pre-loop so
        // `first N` counts post-filter.
        if case .overCollection(let param, _, let collection) = ir.mode, let refinement = ir.source {
            return emitRefinedIterate(ir, refinement: refinement, param: param,
                                      collection: collection, ctx: ctx,
                                      workflow: workflow, path: path,
                                      loopIndex: loopIndex, loopLabel: loopLabel)
        }
        let collVar = "__meridianColl_\(swiftIdentifierSuffix(path))"
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            switch ir.mode {
            case .overCollection(let param, _, let collection):
                // Iterate over a `Value.list` binding. `MeridianRuntime` ships
                // a `Value.asList` accessor that returns `[Value]?` so the
                // generated code stays free of force-casts.
                let var_ = IdentifierNaming.camelPreservingCase(param)
                let over = emitExprUnchecked(collection)
                "\(ctx.s)let \(collVar) = (\(over)?.asList ?? [])"
                emitIterateStartCall(ctx: ctx, over: over, stableStepPath: ir.stableStepPath)
                "\(ctx.s)for (\(loopIndex), \(var_)) in \(collVar).enumerated() {"
                "\(inner.s)let \(loopLabel) = \"progress:\(path):iteration:\\(\(loopIndex))\""
                "\(inner.s)if __meridianShouldRun(\(loopLabel)) {"
                emitIterateIterationCall(ctx: inner.in(1), index: loopIndex, stableStepPath: ir.stableStepPath)
                "\(inner.s)state.bind(\"\(var_)\", \(var_))"
                emitBlock(ir.body, ctx: inner.in(1), workflow: workflow, path: "\(path).body")
                "\(inner.in(1).s)try await runtime.checkpoint(label: \(loopLabel), state: state.snapshot())"
                "\(inner.s)}"
                "\(ctx.s)}"
                emitIterateEndCall(ctx: ctx, over: over, count: "\(collVar).count", stableStepPath: ir.stableStepPath)
            case .whileCondition(let cond):
                let over = "while " + emitExprUnchecked(cond)
                "\(ctx.s)var \(loopIndex) = 0"
                emitIterateStartCall(ctx: ctx, over: over, stableStepPath: ir.stableStepPath)
                "\(ctx.s)while \(emitExprUnchecked(cond)) {"
                "\(inner.s)let \(loopLabel) = \"progress:\(path):iteration:\\(\(loopIndex))\""
                "\(inner.s)\(loopIndex) += 1"
                "\(inner.s)if __meridianShouldRun(\(loopLabel)) {"
                emitIterateIterationCall(ctx: inner.in(1), index: "\(loopIndex) - 1", stableStepPath: ir.stableStepPath)
                emitBlock(ir.body, ctx: inner.in(1), workflow: workflow, path: "\(path).body")
                "\(inner.in(1).s)try await runtime.checkpoint(label: \(loopLabel), state: state.snapshot())"
                "\(inner.s)}"
                "\(ctx.s)}"
                emitIterateEndCall(ctx: ctx, over: over, count: loopIndex, stableStepPath: ir.stableStepPath)
            case .untilCondition(let cond):
                let over = "until " + emitExprUnchecked(cond)
                "\(ctx.s)var \(loopIndex) = 0"
                emitIterateStartCall(ctx: ctx, over: over, stableStepPath: ir.stableStepPath)
                "\(ctx.s)while !(\(emitExprUnchecked(cond))) {"
                "\(inner.s)let \(loopLabel) = \"progress:\(path):iteration:\\(\(loopIndex))\""
                "\(inner.s)\(loopIndex) += 1"
                "\(inner.s)if __meridianShouldRun(\(loopLabel)) {"
                emitIterateIterationCall(ctx: inner.in(1), index: "\(loopIndex) - 1", stableStepPath: ir.stableStepPath)
                emitBlock(ir.body, ctx: inner.in(1), workflow: workflow, path: "\(path).body")
                "\(inner.in(1).s)try await runtime.checkpoint(label: \(loopLabel), state: state.snapshot())"
                "\(inner.s)}"
                "\(ctx.s)}"
                emitIterateEndCall(ctx: ctx, over: over, count: loopIndex, stableStepPath: ir.stableStepPath)
            }
            ""
        }
    }

    /// `iterate.start`/`iterate.iteration`/`iterate.end` instrumentation (8B/E).
    /// `TraceTreeRenderer` already paired-nests on these kinds (semantic tag
    /// `iterated`) — these call sites were the only missing link.
    func emitIterateStartCall(ctx: Ctx, over: String, stableStepPath: String?) -> String {
        let step = "\"\(escapeSwiftStringLiteral(stableStepPath ?? "iterate"))\""
        return "\(ctx.s)try await runtime.recordIterateStart(over: \"\(escapeSwiftStringLiteral(over))\", step: \(step))"
    }

    func emitIterateIterationCall(ctx: Ctx, index: String, stableStepPath: String?) -> String {
        let step = "\"\(escapeSwiftStringLiteral(stableStepPath ?? "iterate"))\""
        return "\(ctx.s)try await runtime.recordIterateIteration(index: \(index), step: \(step))"
    }

    func emitIterateEndCall(ctx: Ctx, over: String, count: String, stableStepPath: String?) -> String {
        let step = "\"\(escapeSwiftStringLiteral(stableStepPath ?? "iterate"))\""
        return "\(ctx.s)try await runtime.recordIterateEnd(over: \"\(escapeSwiftStringLiteral(over))\", count: \(count), step: \(step))"
    }

    /// Emit a refined `for each … whose/within/sorted by/first N` loop. The
    /// source list is filtered, sorted, then prefixed *before* iterating, so the
    /// `first N` prefix counts post-filter. Filter/sort closures read element
    /// properties via `Value.member(...)` (no surrounding `State`).
    func emitRefinedIterate(_ ir: IterateIR, refinement: IRIterationRefinement,
                                    param: String, collection: IRExpression,
                                    ctx: Ctx, workflow: IRWorkflow, path: String,
                                    loopIndex: String, loopLabel: String) -> StringTemplate {
        let inner = ctx.in(1)
        let var_ = IdentifierNaming.camelPreservingCase(param)
        let suffix = swiftIdentifierSuffix(path)
        let srcVar = "__meridianSrc_\(suffix)"

        var pipeline = emitCollectionArray(collection)
        if !refinement.filters.isEmpty {
            let elementParam = freshElementParam([:])
            let cond = refinement.filters
                .map { "(\(emitElementExpr($0, env: [param: elementParam])))" }
                .joined(separator: " && ")
            pipeline += ".filter { \(elementParam) in \(cond) }"
        }
        if let sort = refinement.sort {
            let key = escapeSwiftStringLiteral(sort.path)
            pipeline += ".sorted { __a, __b in MeridianComparison.orderedBefore(__a.member(\"\(key)\"), __b.member(\"\(key)\"), ascending: \(sort.ascending)) }"
        }

        let iterSource: String = (refinement.take != nil || refinement.takeFromEnd != nil) ? "\(srcVar)Refined" : srcVar
        let over = emitExprUnchecked(collection)
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)let \(srcVar) = \(pipeline)"
            if let take = refinement.take {
                "\(ctx.s)let \(srcVar)Refined = Array(\(srcVar).prefix(\(take)))"
            } else if let takeEnd = refinement.takeFromEnd {
                "\(ctx.s)let \(srcVar)Refined = Array(\(srcVar).suffix(\(takeEnd)))"
            }
            emitIterateStartCall(ctx: ctx, over: over, stableStepPath: ir.stableStepPath)
            "\(ctx.s)for (\(loopIndex), \(var_)) in \(iterSource).enumerated() {"
            "\(inner.s)let \(loopLabel) = \"progress:\(path):iteration:\\(\(loopIndex))\""
            "\(inner.s)if __meridianShouldRun(\(loopLabel)) {"
            emitIterateIterationCall(ctx: inner.in(1), index: loopIndex, stableStepPath: ir.stableStepPath)
            "\(inner.s)state.bind(\"\(var_)\", \(var_))"
            emitBlock(ir.body, ctx: inner.in(1), workflow: workflow, path: "\(path).body")
            "\(inner.in(1).s)try await runtime.checkpoint(label: \(loopLabel), state: state.snapshot())"
            "\(inner.s)}"
            "\(ctx.s)}"
            emitIterateEndCall(ctx: ctx, over: over, count: "\(iterSource).count", stableStepPath: ir.stableStepPath)
            ""
        }
    }

    /// A fresh, nesting-depth-unique closure-parameter name for the next
    /// `.filter { … }` / `.allSatisfy { … }` element scope introduced below
    /// `env`. Reusing the same literal parameter name (`__e`) at two nesting
    /// depths is a real bug, not just a style issue: Swift's *own* (correct)
    /// lexical shadowing means an inner closure's `__e` always wins over an
    /// outer one once both closures share that literal name — so an `env`
    /// entry recorded as `"__e"` at the outer level (e.g. a `Definition:`
    /// subject var keyed by `its`) silently starts referring to the *inner*
    /// element instead once that text is spliced into a nested quantifier's
    /// filter closure. `env.count` grows by exactly one new entry per nesting
    /// level (each level's `element` closure merges exactly one new key), so
    /// it doubles as a collision-free depth counter.
    func freshElementParam(_ env: [String: String]) -> String {
        // The overwhelmingly common case is a single, non-nested filter/sort
        // closure with no outer element variable in scope: keep emitting the
        // plain `__e` golden-stable spelling there. Only fall back to the
        // nesting-depth-numbered `__e<n>` form once an outer scope is
        // actually present, so a nested filter/quantifier or an inlined
        // stateful definition body can never shadow its enclosing element
        // parameter (see the Gallery-8 shadowing bug this exists to fix).
        env.isEmpty ? "__e" : "__e\(env.count)"
    }

    /// Emit a filter/sort predicate in *element context*: references to a
    /// bound loop/subject variable resolve to its closure-parameter text
    /// (`__e0`, `__subject`, …), property accesses to `<param>.member("prop")`.
    /// `env` maps every identifier resolvable without `state` at this point in
    /// the tree to the Swift expression text that stands in for it — a single
    /// entry for `emitRefinedIterate`'s element closures, but multiple entries
    /// once nested inside a `Definition:` body (the subject var) that itself
    /// quantifies over a nested collection (the quantifier's own elementVar):
    /// both must stay resolvable, so a nested scope *adds* to `env` rather
    /// than replacing it (see `definitionRequiresState`'s doc comment).
    func emitElementExpr(_ e: IRExpression, env: [String: String]) -> String {
        switch e {
        case .comparison(let lhs, let op, let rhs):
            let l = emitElementOperand(lhs, env: env)
            let r = emitElementValueExpr(rhs, env: env)
            switch op {
            case .withinPast:     return "MeridianComparison.isWithinPast(\(l), \(emitExprUnchecked(rhs)))"
            case .withinFuture:   return "MeridianComparison.isWithinFuture(\(l), \(emitExprUnchecked(rhs)))"
            case .withinDuration: return "MeridianComparison.isWithin(\(l), \(emitExprUnchecked(rhs)))"
            case .matchesPattern: return "meridianRegexMatches(\(l), \(emitExprUnchecked(rhs)))"
            case .isEmpty:        return "MeridianComparison.isEmpty(\(l))"
            case .isNotEmpty:     return "MeridianComparison.isNotEmpty(\(l))"
            case .identifies:     return "MeridianComparison.identifies(\(l), \(r))"
            case .equal:          return "MeridianComparison.eq(\(l), \(r))"
            case .notEqual:       return "MeridianComparison.neq(\(l), \(r))"
            case .lessThan:       return "MeridianComparison.lt(\(l), \(r))"
            case .lessOrEqual:    return "MeridianComparison.le(\(l), \(r))"
            case .greaterThan:    return "MeridianComparison.gt(\(l), \(r))"
            case .greaterOrEqual: return "MeridianComparison.ge(\(l), \(r))"
            case .contains:       return "((\(l))?.description ?? \"\").contains(\(emitExprUnchecked(rhs)))"
            case .startsWith:     return "((\(l))?.description ?? \"\").hasPrefix(\(emitExprUnchecked(rhs)))"
            case .endsWith:       return "((\(l))?.description ?? \"\").hasSuffix(\(emitExprUnchecked(rhs)))"
            case .oneOf:          return "(\(emitExprUnchecked(rhs))).contains(\(l) ?? .null)"
            }
        case .logical(let op, let parts):
            let ps = parts.map { "(\(emitElementExpr($0, env: env)))" }
            switch op {
            case .and: return ps.isEmpty ? "true" : ps.joined(separator: " && ")
            case .or:  return ps.isEmpty ? "false" : ps.joined(separator: " || ")
            case .not: return "!(\(ps.first ?? "true"))"
            }
        case .definitionPredicate(let fn, let subject):
            return emitDefinitionPredicate(fn, subject: subject,
                subjectText: emitElementOperand(subject, env: env),
                nonOptionalSubjectText: emitNonOptionalElementOperand(subject, env: env))
        case .quantified(let q):
            // A nested quantifier evaluates against its own source; references to
            // any enclosing element/subject remain resolvable via `env`, merged
            // with the quantifier's own freshly-introduced elementVar. The
            // closure parameter itself must be depth-unique (see
            // `freshElementParam`) — reusing the enclosing scope's literal
            // name here is what let a `Definition:` subject var's `its`
            // keying silently rebind to *this* quantifier's own element once
            // nested two (or more) levels deep.
            let param = freshElementParam(env)
            return emitQuantifier(q, elementParam: param,
                operand: { self.emitElementOperand($0, env: env) },
                element: { ee, ev in self.emitElementExpr(ee, env: env.merging([ev: param]) { _, new in new }) })
        default:
            return "(\(emitElementOperand(e, env: env)) != nil)"
        }
    }

    /// Emit an operand in element context, producing a `Value?` expression.
    func emitElementOperand(_ e: IRExpression, env: [String: String]) -> String {
        switch e {
        case .identifierRef(let name) where env[name] != nil:
            return env[name]!
        case .propertyAccess(let base, let prop):
            let key = escapeSwiftStringLiteral(IdentifierNaming.camelPreservingCase(prop))
            if case .identifierRef(let n) = base, let param = env[n] {
                return "\(param).member(\"\(key)\")"
            }
            return "\(emitElementOperand(base, env: env))?.member(\"\(key)\")"
        default:
            return emitExprUnchecked(e)
        }
    }

    /// Like `emitElementOperand`, but guarantees the result is a non-optional
    /// `Value` (never `Value?`) — needed when the result becomes an `env`
    /// entry for an *inlined* definition body (`emitDefinitionPredicate`),
    /// since `env` entries are always dereferenced with `.member(...)`
    /// (never `?.member(...)`).
    func emitNonOptionalElementOperand(_ e: IRExpression, env: [String: String]) -> String {
        switch e {
        case .identifierRef(let name) where env[name] != nil:
            return env[name]!
        case .identifierRef, .propertyAccess:
            // Not bound in `env`: falls through to `emitExprUnchecked`
            // (`state.get(...)`) inside `emitElementOperand`, which is
            // `Value?`. Every other case there already yields a bare `Value`.
            return "(\(emitElementOperand(e, env: env)) ?? .null)"
        default:
            return emitElementOperand(e, env: env)
        }
    }

    /// Element-context value operand for comparison helpers. A same-subject
    /// property on either side of a definition/filter comparison must read from
    /// the closure/subject value, not from workflow `state` (which is absent in
    /// generated definition helpers).
    func emitElementValueExpr(_ e: IRExpression, env: [String: String]) -> String {
        switch e {
        case .identifierRef(let name) where env[name] != nil:
            return env[name]!
        case .identifierRef, .propertyAccess:
            return "\(emitElementOperand(e, env: env)) ?? .null"
        case .description(let d):
            return "Value.list(\(emitDescriptionList(d, env: env)))"
        case .aggregate(let kind, let d):
            switch kind {
            case .count: return ".number(Decimal(\(emitDescriptionList(d, env: env)).count))"
            case .list:  return "Value.list(\(emitDescriptionList(d, env: env)))"
            }
        case .comparison, .logical, .definitionPredicate, .quantified:
            return "Value.from(\(emitElementExpr(e, env: env)))"
        default:
            return emitValueExprUnchecked(e)
        }
    }

    /// Shared `.definitionPredicate` rendering for both the plain/state
    /// (`emitExprUnchecked`) and element (`emitElementExpr`) contexts: calls
    /// the standalone helper when one was emitted, or inlines the referenced
    /// definition's body (rebased onto `nonOptionalSubjectText`) when it
    /// required `state` and so has no standalone helper to call — see
    /// `definitionRequiresState`. `subjectText` (used for the ordinary
    /// function-call form) may be `Value?`; `nonOptionalSubjectText` never is,
    /// since it becomes an `env` entry dereferenced with `.member(...)`.
    func emitDefinitionPredicate(
        _ fn: String, subject: IRExpression, subjectText: String, nonOptionalSubjectText: String
    ) -> String {
        if let def = definitionsByName[fn], definitionRequiresState(def.body, bound: [def.subjectVar]) {
            return emitElementExpr(def.body, env: [def.subjectVar: nonOptionalSubjectText])
        }
        return "\(fn)(\(subjectText))"
    }

}
