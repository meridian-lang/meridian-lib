import Foundation
import MeridianRuntime

// Invoke / bind / emit / AI-judgment primitives — extracted from
// SwiftEmitter for Phase 3 readability.

extension SwiftEmitter {

    // MARK: - 1. invoke

    func emitInvoke(_ ir: InvokeIR, ctx: Ctx) -> StringTemplate {
        // Workflow recursion / cross-workflow calls land here with toolID
        // `workflow:StructName` (set by ASTToIR.lowerPhraseInvocation).
        if ir.toolID.hasPrefix("workflow:") {
            return emitWorkflowCall(ir, ctx: ctx)
        }
        let binding = ir.resultBinding.map { "let \(IdentifierNaming.escapeIfReservedIdentifier($0)) = " } ?? "_ = "
        let argLines = ir.arguments.map { a in
            "\(ctx.in(1).s)    \"\(a.key)\": \(emitValueExprUnchecked(a.value)),"
        }
        let capture = "Self.runtimeTraceConfiguration!.capturePolicy(for: \"\(escapeSwiftStringLiteral(ir.toolID))\")"
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            if let note = ir.comment, !note.isEmpty {
                "\(ctx.s)// \(note.replacingOccurrences(of: "\n", with: " "))"
            }
            if ir.arguments.isEmpty {
                "\(ctx.s)\(binding)try await runtime.invoke(tool: \"\(ir.toolID)\", args: [:], step: \"\(escapeSwiftStringLiteral(ir.stableStepPath ?? ir.toolID))\", capturePolicy: \(capture))"
            } else {
                "\(ctx.s)\(binding)try await runtime.invoke("
                "\(ctx.s)    tool: \"\(ir.toolID)\","
                "\(ctx.s)    args: ["
                for line in argLines { line }
                "\(ctx.s)    ],"
                "\(ctx.s)    step: \"\(escapeSwiftStringLiteral(ir.stableStepPath ?? ir.toolID))\","
                "\(ctx.s)    capturePolicy: \(capture)"
                "\(ctx.s))"
            }
            if let b = ir.resultBinding {
                "\(ctx.s)state.bind(\"\(b)\", \(IdentifierNaming.escapeIfReservedIdentifier(b)))"
            }
            ""
        }
    }

    /// Emit `_ = try await StructName(runtime: runtime, arg1: …, arg2: …).run()`
    /// for a workflow-call invoke (toolID "workflow:StructName"). Argument keys
    /// are camelCase'd so they line up with the generated init signature.
    /// When `ir.arguments` is empty we drop the trailing comma so the call site
    /// is `StructName(runtime: runtime).run()` — Swift rejects the half-formed
    /// `runtime, ` form even when the init has no other parameters.
    func emitWorkflowCall(_ ir: InvokeIR, ctx: Ctx) -> StringTemplate {
        let structName = String(ir.toolID.dropFirst("workflow:".count))
        let binding = ir.resultBinding.map { "let \(IdentifierNaming.escapeIfReservedIdentifier($0)) = " } ?? "_ = "
        let targetParams = ctx.workflowParamTypes[structName] ?? []
        let argParts = ir.arguments.map { a in
            let key = IdentifierNaming.camelPreservingCase(a.key)
            // Find the receiving init's typed kind name (if known) so we can
            // wrap a Value-typed call site in `Value.from(arg).coerce(to: …)`.
            let targetKind = targetParams.first { $0.name == key || $0.name == a.key }?.kind
            return "\(key): \(emitWorkflowCallArg(a.value, targetKind: targetKind, ctx: ctx))"
        }
        let argList = argParts.isEmpty ? "" : ", " + argParts.joined(separator: ", ")
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)\(binding)try await \(structName)(runtime: runtime\(argList)).run()"
        }
    }

    /// Workflow inits expect typed kind structs (Order, Customer, …), not Value.
    /// We have to bridge two cases at call sites:
    ///
    ///   1. The argument is already a typed Swift value in scope — most
    ///      commonly the current workflow's own parameter (`pullrequest`,
    ///      tracked via `ctx.typedIdentifiers`). Pass it through as-is.
    ///
    ///   2. The argument is a `Value` (loop variable from `iterate`, or a
    ///      `state.get(...)` lookup). Wrap in
    ///      `try Value.from(arg).coerce(to: KindName.self)`. `Value.from(Value)`
    ///      is the identity overload, so this also works when the arg is
    ///      already `Value`-typed; the typed-arg path stays direct because we
    ///      bail out before constructing the coerce call.
    func emitWorkflowCallArg(
        _ expr: IRExpression,
        targetKind: String?,
        ctx: Ctx
    ) -> String {
        switch expr {
        case .identifierRef(let name):
            if ctx.typedIdentifiers.contains(name) {
                return name
            }
            guard let kind = targetKind else { return name }
            return "(try Value.from(\(name)).coerce(to: \(kind).self))"
        case .propertyAccess:
            let inner = emitExprUnchecked(expr) + " ?? .null"
            guard let kind = targetKind else { return inner }
            return "(try (\(inner)).coerce(to: \(kind).self))"
        default:
            return emitExprUnchecked(expr)
        }
    }

    // MARK: - 2. bind

    func emitBind(_ ir: BindIR, ctx: Ctx) -> StringTemplate {
        let method = ir.isRebind ? "rebind" : "bind"
        let step = escapeSwiftStringLiteral(ir.stableStepPath ?? method)
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)state.\(method)(\"\(ir.name)\", \(emitBindValue(ir.expression)))"
            if ctx.stateHistoryEnabled {
                "\(ctx.s)try await runtime.recordStateSnapshotIfEnabled(state: state.snapshot(), operation: \"\(method)\", key: \"\(escapeSwiftStringLiteral(ir.name))\", step: \"\(step)\")"
            }
        }
    }

    /// Emit the value operand of a `state.bind`/`state.rebind` call.
    ///
    /// Text-producing expressions (`.string` literals and interpolated template
    /// bodies — including the compound-note `proceed, and note … in …` rebind,
    /// INFORM7 §2.9) otherwise emit a bare Swift `String` from
    /// `emitExprUnchecked`, which is wrong twice over: it only type-checks
    /// against `bind`'s generic `T` overload (so `rebind`, which has none, fails
    /// to compile), and it stores the text as `.opaque`, so `meridianStringify`
    /// renders it as a `<opaque …>` debug string instead of the clean receipt
    /// text. Emit those as a first-class `Value.string(...)` instead. All other
    /// expression kinds keep their established emission (they already yield a
    /// `Value`, or bridge through `bind`'s generic overload unchanged).
    func emitBindValue(_ expr: IRExpression) -> String {
        switch expr {
        case .literal(.string), .interpolatedString:
            return emitValueExprUnchecked(expr)
        default:
            return emitExprUnchecked(expr)
        }
    }

    func emitAIJudgment(_ ir: AIJudgmentIR, ctx: Ctx) -> StringTemplate {
        let resultName = "__meridianProseResults_L\(max(ir.sourceRange.startLine, 0))"
        let tools = ir.scopedTools.map { "\"\(escapeSwiftStringLiteral($0))\"" }.joined(separator: ", ")
        let hasGuidance = ir.guidance != nil
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)let \(resultName) = try await runtime.executeProsePlan("
            "\(ctx.s)    prose: \"\(escapeSwiftStringLiteral(ir.text))\","
            "\(ctx.s)    snapshot: state.snapshot(),"
            "\(ctx.s)    scopedTools: [\(tools)],"
            "\(ctx.s)    outputKind: \"\(escapeSwiftStringLiteral(ir.outputKind))\","
            "\(ctx.s)    step: \"\(escapeSwiftStringLiteral(ir.stableStepPath ?? "aiJudgment"))\"\(hasGuidance ? "," : "")"
            if let guidance = ir.guidance {
                "\(ctx.s)    guidance: \"\(escapeSwiftStringLiteral(guidance))\""
            }
            "\(ctx.s))"
            "\(ctx.s)for (__key, __value) in \(resultName) {"
            "\(ctx.in(1).s)state.bind(__key, __value)"
            "\(ctx.s)}"
        }
    }

    func emitAIAutonomy(_ ir: AIAutonomyIR, ctx: Ctx) -> StringTemplate {
        let resultName = "__meridianProseResults_L\(max(ir.sourceRange.startLine, 0))"
        let tools = ir.scopedTools.map { "\"\(escapeSwiftStringLiteral($0))\"" }.joined(separator: ", ")
        let config = ir.autonomy
        let hasGuidance = ir.guidance != nil
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)let \(resultName) = try await runtime.executeAutonomousLoop("
            "\(ctx.s)    prose: \"\(escapeSwiftStringLiteral(ir.text))\","
            "\(ctx.s)    snapshot: state.snapshot(),"
            "\(ctx.s)    scopedTools: [\(tools)],"
            "\(ctx.s)    maxSteps: \(config.maxSteps),"
            let noUntilUnless = config.until == nil && config.unless == nil
            "\(ctx.s)    replanAfterFailures: \(config.replanAfterFailures),"
            "\(ctx.s)    outputKind: \"\(escapeSwiftStringLiteral(ir.outputKind))\","
            "\(ctx.s)    step: \"\(escapeSwiftStringLiteral(ir.stableStepPath ?? "aiAutonomy"))\"\((!noUntilUnless || hasGuidance) ? "," : "")"
            if let until = config.until {
                for line in emitAutonomyPredicate(name: "until", expr: until, ctx: ctx, includeComma: config.unless != nil || hasGuidance) {
                    line
                }
            }
            if let unless = config.unless {
                for line in emitAutonomyPredicate(name: "unless", expr: unless, ctx: ctx, includeComma: hasGuidance) {
                    line
                }
            }
            if let guidance = ir.guidance {
                "\(ctx.s)    guidance: \"\(escapeSwiftStringLiteral(guidance))\""
            }
            "\(ctx.s))"
            "\(ctx.s)for (__key, __value) in \(resultName) {"
            "\(ctx.in(1).s)state.bind(__key, __value)"
            "\(ctx.s)}"
        }
    }

    func emitAutonomyPredicate(name: String, expr: IRExpression, ctx: Ctx, includeComma: Bool) -> [String] {
        let close = includeComma ? "    }," : "    }"
        return [
            "\(ctx.s)    \(name): { __meridianAutonomySnapshot in",
            "\(ctx.s)        var state = State()",
            "\(ctx.s)        state.restore(from: __meridianAutonomySnapshot)",
            "\(ctx.s)        return \(emitExprUnchecked(expr))",
            "\(ctx.s)\(close)"
        ]
    }

    // MARK: - 6. emit

    func emitEmit(_ ir: EmitIR, ctx: Ctx, mode: ExecutionMode) -> StringTemplate {
        let isStrict = ir.strict && mode == .strict
        let call = isStrict ? "try await runtime.emit" : "await runtime.emitLenient"
        let payloadLines = ir.payload.map { f in
            "\(ctx.in(1).s)    \"\(f.key)\": \(emitValueExprUnchecked(f.value)),"
        }
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            if ir.payload.isEmpty {
                "\(ctx.s)\(call)(event: \"\(escapeSwiftStringLiteral(ir.eventID))\", payload: [:], step: \"\(escapeSwiftStringLiteral(ir.stableStepPath ?? ir.eventID))\")"
            } else {
                "\(ctx.s)\(call)("
                "\(ctx.s)    event: \"\(escapeSwiftStringLiteral(ir.eventID))\","
                "\(ctx.s)    payload: ["
                for line in payloadLines { line }
                "\(ctx.s)    ],"
                "\(ctx.s)    step: \"\(escapeSwiftStringLiteral(ir.stableStepPath ?? ir.eventID))\""
                "\(ctx.s))"
            }
        }
    }

}
