import Foundation
import MeridianRuntime
import ModelHike

// MARK: - SwiftEmitter
//
// Lowers an IRWorkflow to Swift source using StringTemplate from ModelHike.
// Each emit* function returns a StringTemplate whose builder body mirrors
// the structure of the Swift code it produces — easy to read and diff.
//
// Calling .toString(separator: "\n") on the top-level template (done in
// emitFile) flattens all nested StringTemplates recursively and joins every
// leaf string with a newline, producing properly formatted Swift source.
// Empty strings "" inside any template act as blank-line sentinels.

public struct SwiftEmitter {

    public struct Options {
        public var includeTimestamp: Bool
        public var sourceFileName: String
        public var indentUnit: String
        public var emitSourceLineComments: Bool
        /// When non-nil, every generated declaration (domain types, Constants,
        /// Instances, workflow & trigger structs) is wrapped in
        /// `public enum <namespaceEnum> { … }`. This lets many independently
        /// generated skill files coexist in a single Swift module without the
        /// per-file domain types (`Job`, `Brain`, `Constants`, …) colliding.
        /// The file header (imports + the private `meridianStringify` helper)
        /// stays at file scope. Default `nil` preserves top-level emission.
        public var namespaceEnum: String?

        public init(
            includeTimestamp: Bool = false,
            sourceFileName: String = "workflow.meridian",
            indentUnit: String = "    ",
            emitSourceLineComments: Bool = true,
            namespaceEnum: String? = nil
        ) {
            self.includeTimestamp = includeTimestamp
            self.sourceFileName = sourceFileName
            self.indentUnit = indentUnit
            self.emitSourceLineComments = emitSourceLineComments
            self.namespaceEnum = namespaceEnum
        }
    }

    public let options: Options
    public let trace: ParserTrace

    public init(options: Options = Options(), trace: ParserTrace = .shared) {
        self.options = options
        self.trace = trace
    }

    // MARK: - Public entry point

    /// Emit a complete Swift source file for the given workflows.
    /// Uses `toString(separator: "\n")` so nested StringTemplates are
    /// flattened and every leaf string becomes its own line.
    public func emitFile(
        workflows: [IRWorkflow],
        constantsDecl: ConstantsDecl? = nil,
        instancesDecl: InstancesDecl? = nil,
        domainDecl: DomainDecl? = nil,
        fileMetadata: FileMetadataAST? = nil,
        definitions: [LoweredDefinition] = []
    ) -> String {
        let hasConstants = constantsDecl != nil
        let hasInstances = instancesDecl != nil
        // Set of Swift type names produced by the Domain section. The grammar
        // permits workflow headers like `to plan a ci repair for a pull request`
        // where `ci repair` is parsed as a parameter kind even though the
        // vocabulary doesn't declare it as a kind. Without a generated struct
        // the call site `cirepair: CiRepair` references a missing type, so we
        // fall back to `Value` for any param kind that isn't in this set.
        let declaredKinds: Set<String> = Set(
            (domainDecl?.kinds ?? []).map { naturalToPascal($0.name) }
        )

        // Build a lookup of struct-name → typed parameter kinds so any nested
        // emit can coerce a call-site arg to the receiving workflow's typed
        // init param. Unknown kinds are normalised to `Value` here too so the
        // call-site coercion mirrors the param decl exactly.
        var paramTypes: [String: [(name: String, kind: String)]] = [:]
        for wf in workflows {
            paramTypes[wf.structName] = wf.parameters.map { p in
                let resolved = declaredKinds.contains(p.kind.name) ? p.kind.name : "Value"
                return (p.name, resolved)
            }
        }
        let namespace = options.namespaceEnum
        trace.log(.codegen, "emit file: \(workflows.count) workflow(s), \(definitions.count) definition(s)\(namespace.map { ", namespace \($0)" } ?? "")")
        return StringTemplate {
            fileHeader()
            ""
            // 2B: checkable-adjective helpers live at file scope (private), so
            // they resolve from every workflow `run()` regardless of namespacing.
            for def in definitions {
                emitDefinitionFunction(def)
                ""
            }
            if let namespace {
                "public enum \(namespace) {"
                ""
            }
            if let d = domainDecl {
                emitDomain(d)
                ""
            }
            if let c = constantsDecl {
                emitConstants(c)
                ""
            }
            if let i = instancesDecl {
                emitInstances(i)
                ""
            }
            for (idx, workflow) in workflows.enumerated() {
                // B1: Emit skillMetadata on the first workflow struct only.
                let skillEntries: [(String, String)]? = (idx == 0 ? fileMetadata?.entries : nil)
                let _ = trace.log(.codegen, "emit workflow \(workflow.structName) (\(workflow.body.statements.count) top-level primitives, mode \(workflow.mode))")
                emitWorkflow(workflow,
                             hasConstants: hasConstants,
                             hasInstances: hasInstances,
                             skillMetadata: skillEntries,
                             workflowParamTypes: paramTypes,
                             declaredKinds: declaredKinds)
                ""
            }
            if namespace != nil {
                "}"
            }
        }.toString(separator: "\n")
    }

    // MARK: - Workflow struct

    /// `hasConstants` controls whether `let constants = Constants()` is
    /// emitted inside `run()`. Only set when a `ConstantsDecl` was provided
    /// to `emitFile`, otherwise the reference would be unresolved.
    /// `skillMetadata` — when non-nil, emits a `skillMetadata: [String: String]`
    /// static property on this struct (B1, first workflow only).
    public func emitWorkflow(_ workflow: IRWorkflow,
                              hasConstants: Bool = false,
                              hasInstances: Bool = false,
                              skillMetadata: [(String, String)]? = nil,
                              workflowParamTypes: [String: [(name: String, kind: String)]] = [:],
                              declaredKinds: Set<String> = []) -> StringTemplate {
        // Seed the typed-identifier scope with this workflow's parameters —
        // params backed by a real domain kind are typed Swift values, so
        // identifier references to them don't need coercion at workflow-call
        // sites. Params whose kind wasn't declared in the vocabulary fall
        // back to `Value` and aren't considered typed.
        let typedParams = Set(
            workflow.parameters
                .filter { declaredKinds.isEmpty || declaredKinds.contains($0.kind.name) }
                .map { $0.name }
        )
        let ctx = Ctx(
            depth: 0,
            options: options,
            workflowParamTypes: workflowParamTypes,
            typedIdentifiers: typedParams
        )
        func resolveKind(_ k: String) -> String {
            declaredKinds.isEmpty || declaredKinds.contains(k) ? k : "Value"
        }
        let paramDecls  = workflow.parameters.map { "    public let \($0.name): \(resolveKind($0.kind.name))" }
        let initParams  = (["runtime: Runtime"] + workflow.parameters.map { "\($0.name): \(resolveKind($0.kind.name))" }).joined(separator: ", ")
        let initAssigns = workflow.parameters.map { "        self.\($0.name) = \($0.name)" }
        let stateBinds  = workflow.parameters.map { "        state.bind(\"\($0.name)\", \($0.name))" }

        return StringTemplate {
            "public struct \(workflow.structName): MeridianWorkflow {"
            "    public let runtime: Runtime"
            for decl in paramDecls { decl }
            // B1: Skill-discovery metadata as a static dictionary.
            if let entries = skillMetadata, !entries.isEmpty {
                ""
                "    public static let skillMetadata: [String: String] = ["
                for (k, v) in entries {
                    "        \"\(escapeSwiftString(k))\": \"\(escapeSwiftString(v))\","
                }
                "    ]"
            }
            ""
            "    public init(\(initParams)) {"
            "        self.runtime = runtime"
            for assign in initAssigns { assign }
            "    }"
            ""
            "    public func run() async throws -> WorkflowResult {"
            "        var state = State()"
            for bind in stateBinds { bind }
            "        let __meridianResumeContext = await runtime.consumeResumeContext()"
            "        if let __meridianResumeContext {"
            "            state.restore(from: __meridianResumeContext.restoredState)"
            "        }"
            "        var __meridianResumeTarget = __meridianResumeContext?.lastCheckpointLabel"
            "        func __meridianShouldRun(_ label: String) -> Bool {"
            "            guard let target = __meridianResumeTarget else { return true }"
            "            if target == label { __meridianResumeTarget = nil }"
            "            return false"
            "        }"
            if hasConstants {
                "        let constants = Constants()"
            }
            if hasInstances {
                "        let instances = Instances()"
            }
            "        await runtime.workflowStarted(workflowName: \"\(workflow.structName)\", parameters: [:])"
            ""
            emitBlock(workflow.body, ctx: ctx.in(2), workflow: workflow, path: "0")
            if !blockEndsWithComplete(workflow.body) {
                ""
                "        await runtime.complete(reason: nil)"
                "        return WorkflowResult(reason: nil, durationMS: await runtime.elapsedMS(), eventCount: await runtime.eventCount(), bindings: state.snapshot().asValues)"
            }
            "    }"
            "}"
        }
    }

    // MARK: - Block

    func emitBlock(_ block: IRBlock, ctx: Ctx, workflow: IRWorkflow, path: String) -> StringTemplate {
        StringTemplate {
            for (idx, stmt) in block.statements.enumerated() {
                let childPath = "\(path).\(idx)"
                if shouldCheckpointAfter(stmt) {
                    emitReplayGuardedPrimitive(stmt, ctx: ctx, workflow: workflow, path: childPath)
                } else {
                    emitPrimitive(stmt, ctx: ctx, workflow: workflow, path: childPath)
                }
            }
        }
    }

    // MARK: - Primitive dispatch

    func emitPrimitive(_ p: IRPrimitive, ctx: Ctx, workflow: IRWorkflow, path: String = "0") -> StringTemplate {
        let range = sourceRange(of: p)
        trace.log(.codegen, "emit \(primitiveTraceName(p)) L\(range.startLine)")
        switch p {
        case .invoke(let ir):   return emitInvoke(ir, ctx: ctx)
        case .bind(let ir):     return emitBind(ir, ctx: ctx)
        case .emit(let ir):     return emitEmit(ir, ctx: ctx, mode: workflow.mode)
        case .branch(let ir):   return emitBranch(ir, ctx: ctx, workflow: workflow, path: path)
        case .complete(let ir): return emitComplete(ir, ctx: ctx)
        case .commit(let ir):   return emitCommit(ir, ctx: ctx)
        case .iterate(let ir):  return emitIterate(ir, ctx: ctx, workflow: workflow, path: path)
        case .assert(let ir):   return emitAssert(ir, ctx: ctx, workflow: workflow, path: path)
        case .recover(let ir):  return emitRecover(ir, ctx: ctx, workflow: workflow, path: path)
        case .wait(let ir):     return emitWait(ir, ctx: ctx)
        case .simultaneously(let ir):
            return emitSimultaneously(ir, ctx: ctx, workflow: workflow, path: path)
        case .proseStep(let ir):
            return emitProseStep(ir, ctx: ctx)
        }
    }

    func emitReplayGuardedPrimitive(_ p: IRPrimitive, ctx: Ctx, workflow: IRWorkflow, path: String) -> StringTemplate {
        let label = checkpointLabel(for: p, path: path)
        return StringTemplate {
            "\(ctx.s)if __meridianShouldRun(\"\(label)\") {"
            emitPrimitive(p, ctx: ctx.in(1), workflow: workflow, path: path)
            if !isCommit(p) {
                "\(ctx.in(1).s)try await runtime.checkpoint(label: \"\(label)\", state: state.snapshot())"
            }
            "\(ctx.s)}"
        }
    }

    func shouldCheckpointAfter(_ p: IRPrimitive) -> Bool {
        switch p {
        case .invoke, .emit, .wait, .assert:
            return true
        case .commit:
            return true
        default:
            return false
        }
    }

    func checkpointLabel(for p: IRPrimitive, path: String) -> String {
        if case .commit(let ir) = p, let label = ir.label {
            return label
        }
        return progressLabel(for: p, path: path)
    }

    func isCommit(_ p: IRPrimitive) -> Bool {
        if case .commit = p { return true }
        return false
    }

    func progressLabel(for p: IRPrimitive, path: String) -> String {
        let range = sourceRange(of: p)
        return "progress:\(path):L\(range.startLine):C\(range.startColumn)"
    }

    func sourceRange(of p: IRPrimitive) -> SourceRange {
        switch p {
        case .invoke(let ir): return ir.sourceRange
        case .bind(let ir): return ir.sourceRange
        case .branch(let ir): return ir.sourceRange
        case .iterate(let ir): return ir.sourceRange
        case .assert(let ir): return ir.sourceRange
        case .emit(let ir): return ir.sourceRange
        case .wait(let ir): return ir.sourceRange
        case .commit(let ir): return ir.sourceRange
        case .recover(let ir): return ir.sourceRange
        case .simultaneously(let ir): return ir.sourceRange
        case .proseStep(let ir): return ir.sourceRange
        case .complete(let ir): return ir.sourceRange
        }
    }

    private func primitiveTraceName(_ p: IRPrimitive) -> String {
        switch p {
        case .invoke: return "invoke"
        case .bind(let ir): return ir.isRebind ? "rebind" : "bind"
        case .branch: return "branch"
        case .emit: return "emit"
        case .complete: return "complete"
        case .commit: return "commit"
        case .iterate: return "iterate"
        case .assert: return "assert"
        case .recover: return "recover"
        case .wait: return "wait"
        case .simultaneously: return "simultaneously"
        case .proseStep: return "proseStep"
        }
    }

    func swiftIdentifierSuffix(_ raw: String) -> String {
        raw.map { ch in
            ch.isLetter || ch.isNumber ? String(ch) : "_"
        }.joined()
    }

    // MARK: - 1. invoke

    func emitInvoke(_ ir: InvokeIR, ctx: Ctx) -> StringTemplate {
        // Workflow recursion / cross-workflow calls land here with toolID
        // `workflow:StructName` (set by ASTToIR.lowerPhraseInvocation).
        if ir.toolID.hasPrefix("workflow:") {
            return emitWorkflowCall(ir, ctx: ctx)
        }
        let binding = ir.resultBinding.map { "let \($0) = " } ?? "_ = "
        let argLines = ir.arguments.map { a in
            "\(ctx.in(1).s)    \"\(a.key)\": \(emitValueExpr(a.value)),"
        }
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            if let note = ir.comment, !note.isEmpty {
                "\(ctx.s)// \(note.replacingOccurrences(of: "\n", with: " "))"
            }
            if ir.arguments.isEmpty {
                "\(ctx.s)\(binding)try await runtime.invoke(tool: \"\(ir.toolID)\", args: [:])"
            } else {
                "\(ctx.s)\(binding)try await runtime.invoke("
                "\(ctx.s)    tool: \"\(ir.toolID)\","
                "\(ctx.s)    args: ["
                for line in argLines { line }
                "\(ctx.s)    ]"
                "\(ctx.s))"
            }
            if let b = ir.resultBinding {
                "\(ctx.s)state.bind(\"\(b)\", \(b))"
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
        let binding = ir.resultBinding.map { "let \($0) = " } ?? "_ = "
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
    private func emitWorkflowCallArg(
        _ expr: IRExpression,
        targetKind: String?,
        ctx: Ctx
    ) -> String {
        switch expr {
        case .identifierRef(let name):
            if ctx.typedIdentifiers.contains(name) || targetKind == nil {
                return name
            }
            return "(try Value.from(\(name)).coerce(to: \(targetKind!).self))"
        case .propertyAccess:
            let inner = emitExpr(expr) + " ?? .null"
            guard let kind = targetKind else { return inner }
            return "(try (\(inner)).coerce(to: \(kind).self))"
        default:
            return emitExpr(expr)
        }
    }

    // MARK: - 2. bind

    func emitBind(_ ir: BindIR, ctx: Ctx) -> StringTemplate {
        let method = ir.isRebind ? "rebind" : "bind"
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)state.\(method)(\"\(ir.name)\", \(emitExpr(ir.expression)))"
        }
    }

    func emitProseStep(_ ir: ProseStepIR, ctx: Ctx) -> StringTemplate {
        let resultName = "__meridianProseResults_L\(max(ir.sourceRange.startLine, 0))"
        let tools = ir.scopedTools.map { "\"\(escapeSwiftString($0))\"" }.joined(separator: ", ")
        let call = ir.dispatchMode == .autonomousLoop ? "executeAutonomousLoop" : "executeProsePlan"
        let config = ir.autonomy ?? AutonomyConfigIR()
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)let \(resultName) = try await runtime.\(call)("
            "\(ctx.s)    prose: \"\(escapeSwiftString(ir.text))\","
            "\(ctx.s)    snapshot: state.snapshot(),"
            if ir.dispatchMode == .planThenExecute {
                "\(ctx.s)    scopedTools: [\(tools)]"
            } else {
                "\(ctx.s)    scopedTools: [\(tools)],"
                "\(ctx.s)    maxSteps: \(config.maxSteps),"
                if config.until == nil && config.unless == nil {
                    "\(ctx.s)    replanAfterFailures: \(config.replanAfterFailures)"
                } else {
                    "\(ctx.s)    replanAfterFailures: \(config.replanAfterFailures),"
                }
                if let until = config.until {
                    for line in emitAutonomyPredicate(name: "until", expr: until, ctx: ctx, includeComma: config.unless != nil) {
                        line
                    }
                }
                if let unless = config.unless {
                    for line in emitAutonomyPredicate(name: "unless", expr: unless, ctx: ctx, includeComma: false) {
                        line
                    }
                }
            }
            "\(ctx.s))"
            "\(ctx.s)for (__key, __value) in \(resultName) {"
            "\(ctx.in(1).s)state.bind(__key, __value)"
            "\(ctx.s)}"
        }
    }

    private func emitAutonomyPredicate(name: String, expr: IRExpression, ctx: Ctx, includeComma: Bool) -> [String] {
        let close = includeComma ? "    }," : "    }"
        return [
            "\(ctx.s)    \(name): { __meridianAutonomySnapshot in",
            "\(ctx.s)        var state = State()",
            "\(ctx.s)        state.restore(from: __meridianAutonomySnapshot)",
            "\(ctx.s)        return \(emitExpr(expr))",
            "\(ctx.s)\(close)"
        ]
    }

    // MARK: - 6. emit

    func emitEmit(_ ir: EmitIR, ctx: Ctx, mode: ExecutionMode) -> StringTemplate {
        let isStrict = ir.strict && mode == .strict
        let call = isStrict ? "try await runtime.emit" : "await runtime.emitLenient"
        let payloadLines = ir.payload.map { f in
            "\(ctx.in(1).s)    \"\(f.key)\": \(emitValueExpr(f.value)),"
        }
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            if ir.payload.isEmpty {
                "\(ctx.s)\(call)(event: \"\(escapeSwiftString(ir.eventID))\", payload: [:])"
            } else {
                "\(ctx.s)\(call)("
                "\(ctx.s)    event: \"\(escapeSwiftString(ir.eventID))\","
                "\(ctx.s)    payload: ["
                for line in payloadLines { line }
                "\(ctx.s)    ]"
                "\(ctx.s))"
            }
        }
    }

    // MARK: - 3. branch

    func emitBranch(_ ir: BranchIR, ctx: Ctx, workflow: IRWorkflow, path: String = "0") -> StringTemplate {
        let inner = ctx.in(1)
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            switch ir.condition {
            case .predicate(let expr):
                "\(ctx.s)if \(emitExpr(expr)) {"
                emitBlock(ir.thenBlock, ctx: inner, workflow: workflow, path: "\(path).then")
                if let elseBlock = ir.elseBlock {
                    "\(ctx.s)} else {"
                    emitBlock(elseBlock, ctx: inner, workflow: workflow, path: "\(path).else")
                }
                "\(ctx.s)}"
            case .match(let expr, let cases):
                "\(ctx.s)switch \(emitExpr(expr)) {"
                for (idx, c) in cases.enumerated() {
                    "\(ctx.s)case \(emitPattern(c.pattern)):"
                    emitBlock(c.block, ctx: inner, workflow: workflow, path: "\(path).case\(idx)")
                }
                "\(ctx.s)}"
            }
            ""
        }
    }

    // MARK: - 10. complete

    func emitComplete(_ ir: CompleteIR, ctx: Ctx) -> StringTemplate {
        let reasonStr = ir.reason.map { "\"\(escapeSwiftString($0))\"" } ?? "nil"
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)await runtime.complete(reason: \(reasonStr))"
            "\(ctx.s)return WorkflowResult(reason: \(reasonStr), durationMS: await runtime.elapsedMS(), eventCount: await runtime.eventCount(), bindings: state.snapshot().asValues)"
        }
    }

    // MARK: - 8. commit

    func emitCommit(_ ir: CommitIR, ctx: Ctx) -> StringTemplate {
        let labelStr = ir.label.map { "label: \"\($0)\"" } ?? "label: nil"
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)try await runtime.checkpoint(\(labelStr), state: state.snapshot())"
        }
    }

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
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            switch ir.mode {
            case .overCollection(let param, _, let collection):
                // Iterate over a `Value.list` binding. `MeridianRuntime` ships
                // a `Value.asList` accessor that returns `[Value]?` so the
                // generated code stays free of force-casts.
                let var_ = IdentifierNaming.camelPreservingCase(param)
                "\(ctx.s)for (\(loopIndex), \(var_)) in (\(emitExpr(collection))?.asList ?? []).enumerated() {"
                "\(inner.s)let \(loopLabel) = \"progress:\(path):iteration:\\(\(loopIndex))\""
                "\(inner.s)if __meridianShouldRun(\(loopLabel)) {"
                "\(inner.s)state.bind(\"\(var_)\", \(var_))"
                emitBlock(ir.body, ctx: inner.in(1), workflow: workflow, path: "\(path).body")
                "\(inner.in(1).s)try await runtime.checkpoint(label: \(loopLabel), state: state.snapshot())"
                "\(inner.s)}"
                "\(ctx.s)}"
            case .whileCondition(let cond):
                "\(ctx.s)var \(loopIndex) = 0"
                "\(ctx.s)while \(emitExpr(cond)) {"
                "\(inner.s)let \(loopLabel) = \"progress:\(path):iteration:\\(\(loopIndex))\""
                "\(inner.s)\(loopIndex) += 1"
                "\(inner.s)if __meridianShouldRun(\(loopLabel)) {"
                emitBlock(ir.body, ctx: inner.in(1), workflow: workflow, path: "\(path).body")
                "\(inner.in(1).s)try await runtime.checkpoint(label: \(loopLabel), state: state.snapshot())"
                "\(inner.s)}"
                "\(ctx.s)}"
            case .untilCondition(let cond):
                "\(ctx.s)var \(loopIndex) = 0"
                "\(ctx.s)while !(\(emitExpr(cond))) {"
                "\(inner.s)let \(loopLabel) = \"progress:\(path):iteration:\\(\(loopIndex))\""
                "\(inner.s)\(loopIndex) += 1"
                "\(inner.s)if __meridianShouldRun(\(loopLabel)) {"
                emitBlock(ir.body, ctx: inner.in(1), workflow: workflow, path: "\(path).body")
                "\(inner.in(1).s)try await runtime.checkpoint(label: \(loopLabel), state: state.snapshot())"
                "\(inner.s)}"
                "\(ctx.s)}"
            }
            ""
        }
    }

    /// Emit a refined `for each … whose/within/sorted by/first N` loop. The
    /// source list is filtered, sorted, then prefixed *before* iterating, so the
    /// `first N` prefix counts post-filter. Filter/sort closures read element
    /// properties via `Value.member(...)` (no surrounding `State`).
    private func emitRefinedIterate(_ ir: IterateIR, refinement: IRIterationRefinement,
                                    param: String, collection: IRExpression,
                                    ctx: Ctx, workflow: IRWorkflow, path: String,
                                    loopIndex: String, loopLabel: String) -> StringTemplate {
        let inner = ctx.in(1)
        let var_ = IdentifierNaming.camelPreservingCase(param)
        let suffix = swiftIdentifierSuffix(path)
        let srcVar = "__meridianSrc_\(suffix)"

        var pipeline = "(\(emitExpr(collection))?.asList ?? [])"
        if !refinement.filters.isEmpty {
            let cond = refinement.filters
                .map { "(\(emitElementExpr($0, loopVar: param, closureParam: "__e")))" }
                .joined(separator: " && ")
            pipeline += ".filter { __e in \(cond) }"
        }
        if let sort = refinement.sort {
            let key = escapeSwiftString(sort.path)
            pipeline += ".sorted { __a, __b in MeridianComparison.orderedBefore(__a.member(\"\(key)\"), __b.member(\"\(key)\"), ascending: \(sort.ascending)) }"
        }

        let iterSource: String = refinement.take != nil ? "\(srcVar)Refined" : srcVar
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)let \(srcVar) = \(pipeline)"
            if let take = refinement.take {
                "\(ctx.s)let \(srcVar)Refined = Array(\(srcVar).prefix(\(take)))"
            }
            "\(ctx.s)for (\(loopIndex), \(var_)) in \(iterSource).enumerated() {"
            "\(inner.s)let \(loopLabel) = \"progress:\(path):iteration:\\(\(loopIndex))\""
            "\(inner.s)if __meridianShouldRun(\(loopLabel)) {"
            "\(inner.s)state.bind(\"\(var_)\", \(var_))"
            emitBlock(ir.body, ctx: inner.in(1), workflow: workflow, path: "\(path).body")
            "\(inner.in(1).s)try await runtime.checkpoint(label: \(loopLabel), state: state.snapshot())"
            "\(inner.s)}"
            "\(ctx.s)}"
            ""
        }
    }

    /// Emit a filter/sort predicate in *element context*: references to the loop
    /// variable resolve to the closure parameter (`__e`), property accesses to
    /// `__e.member("prop")`. Used only inside `emitRefinedIterate` closures.
    private func emitElementExpr(_ e: IRExpression, loopVar: String, closureParam: String) -> String {
        switch e {
        case .comparison(let lhs, let op, let rhs):
            let l = emitElementOperand(lhs, loopVar: loopVar, closureParam: closureParam)
            switch op {
            case .withinPast:     return "MeridianComparison.isWithinPast(\(l), \(emitExpr(rhs)))"
            case .withinFuture:   return "MeridianComparison.isWithinFuture(\(l), \(emitExpr(rhs)))"
            case .withinDuration: return "MeridianComparison.isWithin(\(l), \(emitExpr(rhs)))"
            case .matchesPattern: return "meridianRegexMatches(\(l), \(emitExpr(rhs)))"
            case .isEmpty:        return "MeridianComparison.isEmpty(\(l))"
            case .isNotEmpty:     return "MeridianComparison.isNotEmpty(\(l))"
            case .identifies:     return "MeridianComparison.identifies(\(l), \(emitValueExpr(rhs)))"
            case .equal:          return "MeridianComparison.eq(\(l), \(emitValueExpr(rhs)))"
            case .notEqual:       return "MeridianComparison.neq(\(l), \(emitValueExpr(rhs)))"
            case .lessThan:       return "MeridianComparison.lt(\(l), \(emitValueExpr(rhs)))"
            case .lessOrEqual:    return "MeridianComparison.le(\(l), \(emitValueExpr(rhs)))"
            case .greaterThan:    return "MeridianComparison.gt(\(l), \(emitValueExpr(rhs)))"
            case .greaterOrEqual: return "MeridianComparison.ge(\(l), \(emitValueExpr(rhs)))"
            case .contains:       return "((\(l))?.description ?? \"\").contains(\(emitExpr(rhs)))"
            case .startsWith:     return "((\(l))?.description ?? \"\").hasPrefix(\(emitExpr(rhs)))"
            case .endsWith:       return "((\(l))?.description ?? \"\").hasSuffix(\(emitExpr(rhs)))"
            case .oneOf:          return "(\(emitExpr(rhs))).contains(\(l) ?? .null)"
            }
        case .logical(let op, let parts):
            let ps = parts.map { "(\(emitElementExpr($0, loopVar: loopVar, closureParam: closureParam)))" }
            switch op {
            case .and: return ps.isEmpty ? "true" : ps.joined(separator: " && ")
            case .or:  return ps.isEmpty ? "false" : ps.joined(separator: " || ")
            case .not: return "!(\(ps.first ?? "true"))"
            }
        case .definitionPredicate(let fn, let subject):
            return "\(fn)(\(emitElementOperand(subject, loopVar: loopVar, closureParam: closureParam)))"
        case .quantified(let q):
            // A nested quantifier evaluates against its own source; references to
            // the enclosing element are resolved through the element operand.
            return emitQuantifier(q,
                operand: { self.emitElementOperand($0, loopVar: loopVar, closureParam: closureParam) },
                element: { ee, ev in self.emitElementExpr(ee, loopVar: ev, closureParam: "__e") })
        default:
            return "(\(emitElementOperand(e, loopVar: loopVar, closureParam: closureParam)) != nil)"
        }
    }

    /// Emit an operand in element context, producing a `Value?` expression.
    private func emitElementOperand(_ e: IRExpression, loopVar: String, closureParam: String) -> String {
        switch e {
        case .identifierRef(let name) where name == loopVar:
            return closureParam
        case .propertyAccess(let base, let prop):
            let key = escapeSwiftString(IdentifierNaming.camelPreservingCase(prop))
            if case .identifierRef(let n) = base, n == loopVar {
                return "\(closureParam).member(\"\(key)\")"
            }
            return "\(emitElementOperand(base, loopVar: loopVar, closureParam: closureParam))?.member(\"\(key)\")"
        default:
            return emitExpr(e)
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
        let msg = escapeSwiftString(ir.message ?? "assertion failed")
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            if let action = ir.otherwiseAction {
                // `assert X otherwise: …` form — run the otherwise block but
                // still surface the failure as an `assert.failed` event so
                // observers see it. The block decides whether to throw.
                "\(ctx.s)if !(\(emitExpr(ir.condition))) {"
                "\(ctx.in(1).s)try await runtime.assert(false, message: \"\(msg)\")"
                emitBlock(action, ctx: ctx.in(1), workflow: workflow, path: "\(path).otherwise")
                "\(ctx.s)} else {"
                "\(ctx.in(1).s)try await runtime.assert(true, message: \"\(msg)\")"
                "\(ctx.s)}"
            } else {
                // Bare `assert X.` — let the runtime emit the event and
                // throw `MeridianRuntimeError.assertion` on failure.
                "\(ctx.s)try await runtime.assert(\(emitExpr(ir.condition)), message: \"\(msg)\")"
            }
        }
    }

    // MARK: - 9. recover

    func emitRecover(_ ir: RecoverIR, ctx: Ctx, workflow: IRWorkflow, path: String = "0") -> StringTemplate {
        let (catchClause, _) = errorPatternClause(ir.pattern)
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            "\(ctx.s)do {"
            emitBlock(ir.attachedTo, ctx: ctx.in(1), workflow: workflow, path: "\(path).do")
            "\(ctx.s)} catch \(catchClause){"
            emitBlock(ir.handler, ctx: ctx.in(1), workflow: workflow, path: "\(path).catch")
            "\(ctx.s)}"
        }
    }

    /// Returns the catch clause string and whether a trailing space is already included.
    ///
    /// For `.named`, the generated clause uses `meridianMatches(_:named:)` from
    /// `MeridianRuntimeError.swift` so no non-existent `.isNamed` member is called.
    /// For `.predicate`, a synthetic `_recoveredError` binding is always produced;
    /// the predicate expression is emitted as a `where` guard.
    private func errorPatternClause(_ p: ErrorPattern) -> (clause: String, hasSpace: Bool) {
        switch p {
        case .anyError:
            return ("let _recoveredError ", true)
        case .named(let n):
            return ("let _recoveredError where meridianMatches(_recoveredError, named: \"\(n)\") ", true)
        case .typed(let k):
            return ("let _recoveredError as \(k.name) ", true)
        case .predicate(let expr):
            return ("let _recoveredError where \(emitExpr(expr)) ", true)
        }
    }

    // MARK: - 7. wait

    func emitWait(_ ir: WaitIR, ctx: Ctx) -> StringTemplate {
        return StringTemplate {
            sourceLineComment(ir.sourceRange, ctx: ctx)
            switch ir.condition {
            case .duration(let d):
                "\(ctx.s)try await runtime.wait(.duration(.seconds(\(d.components.seconds))))"
            case .signal(let id):
                "\(ctx.s)try await runtime.wait(.signal(\"\(id)\"))"
            case .approval(let subj, let role):
                // `by:` takes `RoleRef` — convert the role string to a RoleRef initialiser.
                // `of:` is the subject (Value); empty-string literal signals implicit subject.
                let subjExpr = emitValueExpr(subj)
                "\(ctx.s)try await runtime.wait(.approval(of: \(subjExpr), by: RoleRef(identifier: \"\(role)\")))"
            case .event(let id, let matching):
                if let m = matching {
                    // Emit a closure `{ event in … }` so the predicate gets access to the event.
                    "\(ctx.s)try await runtime.wait(.event(\"\(id)\", matching: { _event in \(emitExpr(m)) }))"
                } else {
                    "\(ctx.s)try await runtime.wait(.event(\"\(id)\", matching: nil))"
                }
            case .choice(let prompt, let options):
                // Choice-gate: block on the selection, then bind it to `choice`
                // in state so a following `branch`/`if the choice is "…"` routes.
                let optsList = options.map { "\"\(escapeSwiftString($0))\"" }.joined(separator: ", ")
                "\(ctx.s)try await runtime.wait(.choice(prompt: \"\(escapeSwiftString(prompt))\", options: [\(optsList)]))"
                "\(ctx.s)state.bind(\"choice\", .string(await runtime.consumeChoiceSelection()))"
            }
        }
    }

    // MARK: - Expression emission

    func emitExpr(_ expr: IRExpression) -> String {
        switch expr {
        case .literal(let lit):
            return emitLiteral(lit)
        case .constantRef(let name):
            return "constants.\(IdentifierNaming.camelPreservingCase(name))"
        case .instanceRef(let name):
            return "instances.\(IdentifierNaming.camelPreservingCase(name))"
        case .identifierRef(let name):
            return "state.get(\"\(escapeSwiftString(name))\")"
        case .propertyAccess(let base, let prop):
            // Property paths use camelCase end-to-end so they line up with
            // generated Swift property names *and* with the keys produced by
            // Codable's default encoding when an opaque domain value is
            // traversed by `State.get`.
            let path = propertyPath(base) + "." + IdentifierNaming.camelPreservingCase(prop)
            return "state.get(\"\(escapeSwiftString(path))\")"
        case .comparison(let lhs, let op, let rhs):
            switch op {
            case .withinDuration:
                return "MeridianComparison.isWithin(\(emitExpr(lhs)), \(emitExpr(rhs)))"
            case .withinPast:
                return "MeridianComparison.isWithinPast(\(emitExpr(lhs)), \(emitExpr(rhs)))"
            case .withinFuture:
                return "MeridianComparison.isWithinFuture(\(emitExpr(lhs)), \(emitExpr(rhs)))"
            case .matchesPattern:
                return "meridianRegexMatches(\(emitExpr(lhs)), \(emitExpr(rhs)))"
            case .isEmpty:
                return "MeridianComparison.isEmpty(\(emitComparisonOperand(lhs)))"
            case .isNotEmpty:
                return "MeridianComparison.isNotEmpty(\(emitComparisonOperand(lhs)))"
            case .contains:
                return "(\(emitExpr(lhs))).contains(\(emitExpr(rhs)))"
            case .startsWith:
                return "(\(emitExpr(lhs))).hasPrefix(\(emitExpr(rhs)))"
            case .endsWith:
                return "(\(emitExpr(lhs))).hasSuffix(\(emitExpr(rhs)))"
            case .oneOf:
                return "(\(emitExpr(rhs))).contains(\(emitExpr(lhs)))"
            case .identifies:
                return "MeridianComparison.identifies(\(emitComparisonOperand(lhs)), \(emitComparisonOperand(rhs)))"
            case .equal, .notEqual, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual:
                // Use Value-aware helpers when either side reads from state
                // (returns Value?) — Swift can't compare Optional<Value> with `<`.
                if needsValueComparison(lhs) || needsValueComparison(rhs) {
                    let helper = compHelper(op)
                    return "MeridianComparison.\(helper)(\(emitComparisonOperand(lhs)), \(emitComparisonOperand(rhs)))"
                }
                return "(\(emitExpr(lhs))) \(compOp(op)) (\(emitExpr(rhs)))"
            }
        case .logical(let op, let operands):
            switch op {
            case .and: return operands.map { "(\(emitExpr($0)))" }.joined(separator: " && ")
            case .or:  return operands.map { "(\(emitExpr($0)))" }.joined(separator: " || ")
            case .not: return "!(\(operands.first.map { emitExpr($0) } ?? "true"))"
            }
        case .envVar(let name):
            return "ProcessInfo.processInfo.environment[\"\(name)\"] ?? \"\""
        case .nowExpression:
            return "Date()"
        case .invocation(let ir):
            if ir.toolID == "runtime.discretion.decide" {
                return "try await runtime.discretion.decide(DiscretionContext(question: \(discretionQuestionExpr(ir)), snapshot: state.snapshot()))"
            }
            return "/* inline invoke: \(ir.toolID) */"
        case .relationTraversal(let base, let rel, _):
            return "\(emitExpr(base)).\(IdentifierNaming.camelPreservingCase(rel))"
        case .interpolatedString(let segs):
            // B7: Build a Swift string by concatenating literal parts and
            // stringified expression parts via `meridianStringify`.
            if segs.isEmpty { return "\"\"" }
            return "(\(interpolationParts(segs)))"
        case .definitionPredicate(let fn, let subject):
            return "\(fn)(\(emitComparisonOperand(subject)))"
        case .quantified(let q):
            return emitQuantifier(q, operand: { self.emitComparisonOperand($0) },
                                  element: { e, ev in self.emitElementExpr(e, loopVar: ev, closureParam: "__e") })
        case .description(let d):
            return "Value.list(\(emitDescriptionList(d)))"
        case .aggregate(let kind, let d):
            switch kind {
            // Wrap the element count in `Decimal` so it compares against the
            // `Decimal` numeric literals produced elsewhere (`> 5`).
            case .count: return "Decimal(\(emitDescriptionList(d)).count)"
            case .list:  return "Value.list(\(emitDescriptionList(d)))"
            }
        case .superlative(let s):
            return "(\(emitSuperlativeList(s)).first)"
        case .recordList(let fields, let rows):
            return emitRecordList(fields: fields, rows: rows)
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return emitTableLookup(table: table, keyColumn: keyColumn, key: key, valueColumn: valueColumn)
        }
    }

    /// Data table → `Value.list([.record([...]), ...])`. Field names are
    /// camelCased so `for each row in <name>` property access (`row.fieldName`)
    /// resolves against the record keys.
    private func emitRecordList(fields: [String], rows: [[IRExpression]]) -> String {
        let records = rows.map { row -> String in
            let pairs = zip(fields, row).map { field, cell in
                "\"\(escapeSwiftString(IdentifierNaming.camelPreservingCase(field)))\": \(emitValueExpr(cell))"
            }.joined(separator: ", ")
            return ".record([\(pairs)])"
        }.joined(separator: ", ")
        return "Value.list([\(records)])"
    }

    private func emitTableLookup(table: String, keyColumn: String, key: IRExpression, valueColumn: String) -> String {
        let tableKey = escapeSwiftString(IdentifierNaming.camelPreservingCase(table))
        let keyField = escapeSwiftString(IdentifierNaming.camelPreservingCase(keyColumn))
        let valueField = escapeSwiftString(IdentifierNaming.camelPreservingCase(valueColumn))
        let keyExpr = emitComparisonOperand(key)
        return "try ({ () throws -> Value? in guard let __rows = state.get(\"\(tableKey)\")?.asList else { throw ToolError.implementation(code: \"table.lookup_miss\", message: \"table \(tableKey) is not bound\", cause: nil) }; for __row in __rows { if MeridianComparison.eq(__row.member(\"\(keyField)\"), \(keyExpr)) { return __row.member(\"\(valueField)\") } }; throw ToolError.implementation(code: \"table.lookup_miss\", message: \"no row in \(tableKey) where \(keyField) matches\", cause: nil) })()"
    }

    /// 3C: render a description as a `[Value]` pipeline — `(coll.asList ?? [])`
    /// filtered (element context), sorted, then `prefix`-taken. Shared by the
    /// description / aggregate / superlative emitters.
    func emitDescriptionList(_ d: DescriptionIR) -> String {
        let ev = d.elementVar
        let coll = emitComparisonOperand(d.collection)
        var pipeline = "((\(coll))?.asList ?? [])"
        if !d.filters.isEmpty {
            let parts = d.filters
                .map { "(\(emitElementExpr($0, loopVar: ev, closureParam: "__e")))" }
                .joined(separator: " && ")
            pipeline += ".filter { __e in \(parts) }"
        }
        if let sort = d.sort {
            let key = escapeSwiftString(sort.path)
            pipeline += ".sorted { __a, __b in MeridianComparison.orderedBefore(__a.member(\"\(key)\"), __b.member(\"\(key)\"), ascending: \(sort.ascending)) }"
        }
        if let take = d.take {
            pipeline = "Array(\(pipeline).prefix(\(take)))"
        }
        return pipeline
    }

    /// 3C: a superlative reuses the description pipeline but forces its own sort
    /// key/direction so `.first` is the min (ascending) or max element.
    private func emitSuperlativeList(_ s: SuperlativeIR) -> String {
        let forced = DescriptionIR(collection: s.description.collection,
                                   elementVar: s.description.elementVar,
                                   filters: s.description.filters,
                                   sort: (path: s.sortPath, ascending: s.ascending),
                                   take: nil)
        return emitDescriptionList(forced)
    }

    /// Emit a checkable-adjective helper. The body is rendered in element
    /// context with the subject variable bound to the `__subject` parameter, so
    /// `it`/`its <prop>` (preprocessed to `<subject>.<prop>`) becomes
    /// `__subject.member("prop")` and bare emptiness/comparisons resolve too.
    func emitDefinitionFunction(_ def: LoweredDefinition) -> StringTemplate {
        let cond = emitElementExpr(def.body, loopVar: def.subjectVar, closureParam: "__subject")
        return StringTemplate {
            "private func \(def.functionName)(_ __subjectValue: Value?) -> Bool {"
            "    let __subject = __subjectValue ?? .null"
            "    return \(cond)"
            "}"
        }
    }

    /// Emit a quantified description as a self-contained `Bool` IIFE.
    /// `operand` renders the source collection expression in the current
    /// context (plain → `state.get`, element → closure member access).
    func emitQuantifier(_ q: QuantifierIR,
                        operand: (IRExpression) -> String,
                        element: (IRExpression, String) -> String) -> String {
        let ev = q.description.elementVar
        let coll = operand(q.description.collection)
        let filterParts = q.description.filters.map { "(\(element($0, ev)))" }
        let filterClause = filterParts.isEmpty ? "" : ".filter { __e in \(filterParts.joined(separator: " && ")) }"
        let bodyClause = q.body.map { ".filter { __e in \(element($0, ev)) }" } ?? ""
        let base = "((\(coll))?.asList ?? [])\(filterClause)"
        switch q.kind {
        case .all:
            if let body = q.body {
                return "(\(base).allSatisfy { __e in \(element(body, ev)) })"
            }
            return "(!\(base).isEmpty)"
        case .any:
            return "(!(\(base)\(bodyClause)).isEmpty)"
        case .none:
            return "((\(base)\(bodyClause)).isEmpty)"
        case .atLeast(let n):
            return "((\(base)\(bodyClause)).count >= \(n))"
        case .atMost(let n):
            return "((\(base)\(bodyClause)).count <= \(n))"
        case .exactly(let n):
            return "((\(base)\(bodyClause)).count == \(n))"
        }
    }

    /// Render a comparison operand for `MeridianComparison.{eq,neq,lt,le,gt,ge}`,
    /// which all take `Value?`. State reads (`identifierRef` / `propertyAccess`)
    /// already return `Value?` and are passed through unchanged. Literals and
    /// constants/instances are wrapped via the same `Value`-bridging helpers
    /// used for invoke args and emit payloads, so the surrounding helper call
    /// type-checks regardless of which side the literal sits on.
    func emitComparisonOperand(_ expr: IRExpression) -> String {
        switch expr {
        case .identifierRef, .propertyAccess:
            return emitExpr(expr)
        default:
            return emitValueExpr(expr)
        }
    }

    /// Like `emitExpr` but wraps the result so it satisfies `Value` in places
    /// the runtime expects a `[String: Value]` dictionary (invoke args, emit
    /// payloads). Strings, numbers, etc. become `.string(...)`/`.number(...)`;
    /// `state.get(...)` (which returns `Value?`) becomes `... ?? .null`.
    func emitValueExpr(_ expr: IRExpression) -> String {
        switch expr {
        case .literal(let lit):
            return emitValueLiteral(lit)
        case .nowExpression:
            return ".date(Date())"
        case .identifierRef, .propertyAccess:
            return "\(emitExpr(expr)) ?? .null"
        case .constantRef, .instanceRef:
            // Typed constants & instances bridge into Value via Value.from(_:).
            return "Value.from(\(emitExpr(expr)))"
        case .envVar(let name):
            return ".string(ProcessInfo.processInfo.environment[\"\(escapeSwiftString(name))\"] ?? \"\")"
        case .interpolatedString(let segs):
            // B7: Produce a Value.string(...) built from concatenated segments.
            if segs.isEmpty { return ".string(\"\")" }
            return ".string(\(interpolationParts(segs)))"
        case .description(let d):
            return "Value.list(\(emitDescriptionList(d)))"
        case .aggregate(let kind, let d):
            switch kind {
            case .count: return ".number(Decimal(\(emitDescriptionList(d)).count))"
            case .list:  return "Value.list(\(emitDescriptionList(d)))"
            }
        case .superlative(let s):
            return "(\(emitExpr(.superlative(s))) ?? .null)"
        case .recordList(let fields, let rows):
            return emitRecordList(fields: fields, rows: rows)
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return "(\(emitTableLookup(table: table, keyColumn: keyColumn, key: key, valueColumn: valueColumn)) ?? .null)"
        default:
            // For derived expressions we rely on the runtime `Value(...)` init,
            // wrapping the bare emission so it survives Swift type-checking.
            return ".init(\(emitExpr(expr)))"
        }
    }

    /// The ` + `-joined Swift fragments of an interpolated string's segments.
    /// Shared by the plain (`emitExpr`) and Value-wrapped (`emitValueExpr`)
    /// interpolation emitters, which differ only in the empty-case literal and
    /// the wrapper they place around this body.
    private func interpolationParts(_ segs: [IRInterpolationSegment]) -> String {
        segs.map { seg -> String in
            switch seg {
            case .literal(let s):
                return "\"\(escapeSwiftString(s))\""
            case .expression(let e):
                return "meridianStringify(\(emitValueExpr(e)))"
            case .formatted(let e, let f):
                return "meridianFormat(\(emitValueExpr(e)), as: \"\(escapeSwiftString(f))\")"
            case .conditional(let condition, let thenSegs, let elseSegs):
                return "({ () -> String in if \(emitExpr(condition)) { return \(interpolationParts(thenSegs)) } else { return \(interpolationParts(elseSegs)) } })()"
            case .forEach(let variable, let collection, let body):
                let coll = emitComparisonOperand(collection)
                return "({ () -> String in var __out = \"\"; for __item in ((\(coll))?.asList ?? []) { __out += \(interpolationParts(body, loopVariable: variable, elementName: "__item")) }; return __out })()"
            case .shellEscapedExpression(let e):
                return "meridianShellQuote(\(emitValueExpr(e)))"
            }
        }.joined(separator: " + ")
    }

    private func interpolationParts(_ segs: [IRInterpolationSegment], loopVariable: String, elementName: String) -> String {
        segs.map { seg -> String in
            switch seg {
            case .literal(let s):
                return "\"\(escapeSwiftString(s))\""
            case .expression(let e):
                return "meridianStringify(\(emitLoopValueExpr(e, loopVariable: loopVariable, elementName: elementName)))"
            case .formatted(let e, let f):
                return "meridianFormat(\(emitLoopValueExpr(e, loopVariable: loopVariable, elementName: elementName)), as: \"\(escapeSwiftString(f))\")"
            case .conditional(let condition, let thenSegs, let elseSegs):
                return "({ () -> String in if \(emitLoopBoolExpr(condition, loopVariable: loopVariable, elementName: elementName)) { return \(interpolationParts(thenSegs, loopVariable: loopVariable, elementName: elementName)) } else { return \(interpolationParts(elseSegs, loopVariable: loopVariable, elementName: elementName)) } })()"
            case .forEach:
                return "\"\""
            case .shellEscapedExpression(let e):
                return "meridianShellQuote(\(emitLoopValueExpr(e, loopVariable: loopVariable, elementName: elementName)))"
            }
        }.joined(separator: " + ")
    }

    private func emitLoopValueExpr(_ e: IRExpression, loopVariable: String, elementName: String) -> String {
        switch e {
        case .identifierRef(let name) where name == loopVariable:
            return elementName
        case .identifierRef(let name) where name.hasPrefix(loopVariable + "."):
            let path = String(name.dropFirst(loopVariable.count + 1))
            return "\(elementName).member(\"\(escapeSwiftString(IdentifierNaming.camelPreservingCase(path)))\") ?? .null"
        case .propertyAccess(.identifierRef(let name), let prop) where name == loopVariable:
            return "\(elementName).member(\"\(escapeSwiftString(IdentifierNaming.camelPreservingCase(prop)))\") ?? .null"
        default:
            return emitValueExpr(e)
        }
    }

    private func emitLoopBoolExpr(_ e: IRExpression, loopVariable: String, elementName: String) -> String {
        switch e {
        case .comparison(let l, let op, let r):
            let lhs = emitLoopValueExpr(l, loopVariable: loopVariable, elementName: elementName)
            let rhs = emitLoopValueExpr(r, loopVariable: loopVariable, elementName: elementName)
            return "MeridianComparison.\(compHelper(op))(\(lhs), \(rhs))"
        default:
            return emitExpr(e)
        }
    }

    /// Wrap an IRLiteral for use in `[String: Value]`.
    func emitValueLiteral(_ lit: IRLiteral) -> String {
        switch lit {
        case .string(let s):              return ".string(\"\(escapeSwiftString(s))\")"
        case .number(let n):              return ".number(Decimal(\(n)))"
        case .boolean(let b):             return ".boolean(\(b))"
        case .money(let a, let c):        return ".money(Money(amount: Decimal(\(a)), currency: \"\(c)\"))"
        case .duration(let d):            return ".duration(Duration.seconds(\(d.components.seconds)))"
        case .date(let d):                return ".date(Date(timeIntervalSince1970: \(d.timeIntervalSince1970)))"
        case .dateTime(let d):            return ".date(Date(timeIntervalSince1970: \(d.timeIntervalSince1970)))"
        case .enumValue(let v, _):        return ".string(\"\(v)\")"
        }
    }

    private func discretionQuestionExpr(_ ir: InvokeIR) -> String {
        guard let question = ir.arguments.first(where: { $0.key == "question" })?.value else {
            return "\"\""
        }
        switch question {
        case .literal(.string(let s)):
            return "\"\(escapeSwiftString(s))\""
        case .interpolatedString:
            return emitExpr(question)
        default:
            return "meridianStringify(\(emitValueExpr(question)))"
        }
    }

    func emitLiteral(_ lit: IRLiteral) -> String {
        switch lit {
        case .string(let s):              return "\"\(escapeSwiftString(s))\""
        case .number(let n):              return "Decimal(\(n))"
        case .boolean(let b):             return b ? "true" : "false"
        case .money(let a, let c):        return "Money(amount: Decimal(\(a)), currency: \"\(c)\")"
        case .duration(let d):            return "Duration.seconds(\(d.components.seconds))"
        case .date(let d):                return "Date(timeIntervalSince1970: \(d.timeIntervalSince1970))"
        case .dateTime(let d):            return "Date(timeIntervalSince1970: \(d.timeIntervalSince1970))"
        case .enumValue(let v, let kind): return "\(kind).\(v)"
        }
    }

    /// Escape a String for use inside a Swift double-quoted string literal.
    private func escapeSwiftString(_ s: String) -> String {
        escapeSwiftStringLiteral(s)
    }

    private func propertyPath(_ expr: IRExpression) -> String {
        switch expr {
        case .identifierRef(let name):      return name
        case .propertyAccess(let b, let p): return propertyPath(b) + "." + IdentifierNaming.camelPreservingCase(p)
        default:                            return emitExpr(expr)
        }
    }

    private func compOp(_ op: ComparisonOp) -> String {
        switch op {
        case .equal:          return "=="
        case .notEqual:       return "!="
        case .lessThan:       return "<"
        case .lessOrEqual:    return "<="
        case .greaterThan:    return ">"
        case .greaterOrEqual: return ">="
        default:              return "/* \(op) */"
        }
    }

    /// Map a comparison op to the corresponding `MeridianComparison.X` helper name.
    private func compHelper(_ op: ComparisonOp) -> String {
        switch op {
        case .equal:          return "eq"
        case .notEqual:       return "neq"
        case .lessThan:       return "lt"
        case .lessOrEqual:    return "le"
        case .greaterThan:    return "gt"
        case .greaterOrEqual: return "ge"
        default:              return "eq"
        }
    }

    /// True when an expression resolves to `state.get(...)` (Value?), which
    /// Swift can't compare with `<` / `>` / `==` directly.
    private func needsValueComparison(_ expr: IRExpression) -> Bool {
        switch expr {
        case .identifierRef, .propertyAccess: return true
        // 3C: a superlative is a `Value?`; a `.list` aggregate / description is a
        // `Value`. A `.count` aggregate is a bare `Int` and compares directly.
        case .superlative, .description:      return true
        case .aggregate(let kind, _):         return kind == .list
        default:                              return false
        }
    }

    private func emitPattern(_ p: IRPattern) -> String {
        switch p {
        case .literal(let lit):         return emitLiteral(lit)
        case .enumValue(let v, _):      return ".\(v)"
        case .wildcard:                 return "default"
        }
    }

    // MARK: - Constants struct

    public struct ConstantsDecl {
        public struct Entry {
            public let name: String
            public let value: IRLiteral
            public init(_ name: String, _ value: IRLiteral) { self.name = name; self.value = value }
        }
        public let entries: [Entry]
        public init(entries: [Entry]) { self.entries = entries }
    }

    func emitConstants(_ decl: ConstantsDecl) -> StringTemplate {
        StringTemplate {
            "public struct Constants: Sendable {"
            for e in decl.entries {
                "    public let \(IdentifierNaming.camelPreservingCase(e.name)): \(typeOfLiteral(e.value)) = \(emitLiteral(e.value))"
            }
            "}"
            ""
            // Inside a namespace enum a module-level binding must be `static`
            // (enums cannot hold stored instance properties). Each `run()` also
            // emits its own local `let constants`, so bare references resolve
            // there regardless; this binding is for parity/top-level use.
            options.namespaceEnum == nil
                ? "private let constants = Constants()"
                : "private static let constants = Constants()"
        }
    }

    // MARK: - Instances struct

    public struct InstancesDecl {
        public struct Field {
            public let key: String
            public let value: PropertyValue
            public init(_ key: String, _ value: PropertyValue) { self.key = key; self.value = value }
        }
        public enum PropertyValue {
            case literal(IRLiteral)
            case envVar(String)
        }
        public struct Entry {
            public let name: String          // "primary mailer"
            public let kind: String          // "mailer server"
            public let fields: [Field]
            public init(_ name: String, _ kind: String, _ fields: [Field]) {
                self.name = name; self.kind = kind; self.fields = fields
            }
        }
        public let entries: [Entry]
        public init(entries: [Entry]) { self.entries = entries }
    }

    /// Emit a generated Instances struct that bundles each declared instance
    /// as a `Value` (`.record(...)`). Codegen lowers `instanceRef("primary mailer")`
    /// to `instances.primaryMailer`, so this struct is the resolution target.
    func emitInstances(_ decl: InstancesDecl) -> StringTemplate {
        StringTemplate {
            "public struct Instances: Sendable {"
            for e in decl.entries {
                let recordLines = e.fields.map { f in
                    // Record keys use the same camelCase convention as
                    // generated property paths so `state.get("foo.authType")`
                    // resolves through any matching `.record(["authType": …])`.
                    "        \"\(IdentifierNaming.camelPreservingCase(f.key))\": \(emitInstanceValue(f.value)),"
                }
                "    public let \(IdentifierNaming.camelPreservingCase(e.name)): Value = .record(["
                for line in recordLines { line }
                "    ])"
            }
            "}"
            ""
            options.namespaceEnum == nil
                ? "private let instances = Instances()"
                : "private static let instances = Instances()"
        }
    }

    private func emitInstanceValue(_ v: InstancesDecl.PropertyValue) -> String {
        switch v {
        case .literal(let lit):
            return emitValueLiteral(lit)
        case .envVar(let name):
            return ".string(ProcessInfo.processInfo.environment[\"\(escapeSwiftString(name))\"] ?? \"\")"
        }
    }

    private func typeOfLiteral(_ lit: IRLiteral) -> String {
        switch lit {
        case .string:                   return "String"
        case .number:                   return "Decimal"
        case .boolean:                  return "Bool"
        case .money:                    return "Money"
        case .duration:                 return "Duration"
        case .date, .dateTime:          return "Date"
        case .enumValue(_, let kind):   return kind
        }
    }

    // MARK: - File header

    func fileHeader() -> StringTemplate {
        StringTemplate {
            "// THIS FILE IS GENERATED BY MERIDIAN. DO NOT EDIT."
            "// Source: \(options.sourceFileName)"
            if options.includeTimestamp {
                "// Generated at: \(ISO8601DateFormatter().string(from: Date()))"
            }
            "// Meridian IR version: \(MERIDIAN_IR_VERSION)"
            ""
            "import Foundation"
            "import MeridianRuntime"
            ""
            "// B7: Runtime helper for {{ expr }} interpolation in fenced code blocks."
            "private func meridianStringify(_ v: Value) -> String { v.scalarDescription }"
            "private func meridianFormat(_ v: Value, as formatter: String) -> String {"
            "    switch formatter.lowercased() {"
            "    case \"integer\":"
            "        if case .number(let n) = v { return NSDecimalNumber(decimal: n).intValue.description }"
            "    case let f where f.hasPrefix(\"decimal(\") && f.hasSuffix(\")\"):"
            "        if case .number(let n) = v, let places = Int(f.dropFirst(\"decimal(\".count).dropLast()) {"
            "            let nf = NumberFormatter(); nf.minimumFractionDigits = places; nf.maximumFractionDigits = places"
            "            return nf.string(from: NSDecimalNumber(decimal: n)) ?? n.description"
            "        }"
            "    case \"short date\", \"long date\":"
            "        if case .date(let d) = v {"
            "            let df = DateFormatter(); df.dateStyle = formatter.lowercased() == \"short date\" ? .short : .long; df.timeStyle = .none"
            "            return df.string(from: d)"
            "        }"
            "    default: break"
            "    }"
            "    return meridianStringify(v)"
            "}"
            ""
            "// 1B: Shell-escape a value for safe interpolation inside a double-"
            "// quoted span of a shell command (escapes \\\\, \", $, and backtick)."
            "private func meridianShellQuote(_ v: Value) -> String {"
            "    var out = \"\""
            "    for ch in meridianStringify(v) {"
            "        if ch == \"\\\\\" || ch == \"\\\"\" || ch == \"$\" || ch == \"`\" { out.append(\"\\\\\") }"
            "        out.append(ch)"
            "    }"
            "    return out"
            "}"
            ""
            "// 1D: Output invariant — true iff the value's string form matches the"
            "// regex pattern (anchored anywhere). An invalid pattern fails closed."
            "private func meridianRegexMatches(_ v: Value?, _ pattern: String) -> Bool {"
            "    let s = v.map(meridianStringify) ?? \"\""
            "    guard let re = try? NSRegularExpression(pattern: pattern) else { return false }"
            "    return re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil"
            "}"
        }
    }

    // MARK: - Helpers

    /// Returns a source-line comment template for the given range.
    /// Contributes nothing to the flattened output when comments are disabled
    /// or the range has no valid line number, avoiding spurious blank lines.
    private func sourceLineComment(_ range: SourceRange, ctx: Ctx) -> StringTemplate {
        StringTemplate {
            if options.emitSourceLineComments && range.startLine > 0 {
                "\(ctx.s)// L\(range.startLine)"
            }
        }
    }

    private func blockEndsWithComplete(_ block: IRBlock) -> Bool {
        guard let last = block.statements.last else { return false }
        if case .complete = last { return true }
        if case .branch(let b) = last {
            return blockEndsWithComplete(b.thenBlock) &&
                   (b.elseBlock.map(blockEndsWithComplete) ?? false)
        }
        return false
    }

    /// PascalCase a natural-language phrase the same way `ASTToIR.kindName`
    /// does (`"pull request"` → `"PullRequest"`). Used to compare param kinds
    /// against the declared domain kinds when deciding whether to emit a typed
    /// init param or fall back to `Value`.
    func naturalToPascal(_ s: String) -> String { IdentifierNaming.pascalCaseFromSpaces(s) }

}

// MARK: - Ctx (emit context / indentation)

struct Ctx {
    let depth: Int
    let options: SwiftEmitter.Options

    /// `structName → [(paramName, kindTypeName)]` lookup populated at the top
    /// of `emitFile`. Empty when an emitter call doesn't have access to the
    /// full workflow set (e.g. tests that call `emitWorkflow` directly). Used
    /// by `emitWorkflowCall` to wrap `Value`-typed call-site arguments (loop
    /// vars, state-bound bindings) so they coerce into the typed kind structs
    /// the receiving workflow init expects.
    let workflowParamTypes: [String: [(name: String, kind: String)]]

    /// Identifier names that resolve to a typed kind struct in the current
    /// emit scope (workflow parameters, `bind X = invoke …` results when the
    /// tool returns a known kind). Anything not in this set is treated as a
    /// `Value` for the purpose of workflow call-site coercion.
    let typedIdentifiers: Set<String>

    var s: String { String(repeating: options.indentUnit, count: depth) }

    init(
        depth: Int,
        options: SwiftEmitter.Options,
        workflowParamTypes: [String: [(name: String, kind: String)]] = [:],
        typedIdentifiers: Set<String> = []
    ) {
        self.depth = depth
        self.options = options
        self.workflowParamTypes = workflowParamTypes
        self.typedIdentifiers = typedIdentifiers
    }

    func `in`(_ levels: Int) -> Ctx {
        Ctx(
            depth: depth + levels,
            options: options,
            workflowParamTypes: workflowParamTypes,
            typedIdentifiers: typedIdentifiers
        )
    }

    func withTyped(_ extra: [String]) -> Ctx {
        Ctx(
            depth: depth,
            options: options,
            workflowParamTypes: workflowParamTypes,
            typedIdentifiers: typedIdentifiers.union(extra)
        )
    }
}
