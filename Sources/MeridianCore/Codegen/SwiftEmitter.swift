import Foundation
import MeridianRuntime

// MARK: - SwiftEmitter
//
// Lowers an IRWorkflow to Swift source using vendored StringTemplate.
// Each emit* function returns a StringTemplate whose builder body mirrors
// the structure of the Swift code it produces — easy to read and diff.
//
// Calling .toString(separator: "\n") on the top-level template (done in
// `render`) flattens all nested StringTemplates recursively and joins every
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

    /// Populated at the top of `emit` so `.definitionPredicate` call sites
    /// throughout emission can look up a referenced definition's body/subject
    /// without threading it through every `emit*` signature — see
    /// `definitionRequiresState`.
    var definitionsByName: [String: LoweredDefinition] = [:]

    public init(options: Options = Options()) {
        self.options = options
    }

    // MARK: - Public entry point

    /// Every Swift string one compile can produce: the combined single-file
    /// output plus the two parts of the multi-file split. All three come from
    /// the same traversal of the workflow/domain IR.
    public struct Output: Sendable {
        /// Domain types, constants, instances and definition helpers only.
        public let domain: String
        /// Workflow structs (and optional skill metadata) only.
        public let workflows: String
        /// The complete single-file output (header + domain + workflows).
        public let combined: String

        public init(domain: String, workflows: String, combined: String) {
            self.domain = domain
            self.workflows = workflows
            self.combined = combined
        }
    }

    /// Emit the combined file and both multi-file parts for the given
    /// workflows. Uses `toString(separator: "\n")` so nested StringTemplates
    /// are flattened and every leaf string becomes its own line. Non-mutating
    /// on the caller's value (many call sites hold a `let SwiftEmitter`):
    /// builds a local mutable copy with `definitionsByName` populated.
    public func emit(
        workflows: [IRWorkflow],
        constantsDecl: ConstantsDecl? = nil,
        instancesDecl: InstancesDecl? = nil,
        domainDecl: DomainDecl? = nil,
        fileMetadata: FileMetadataAST? = nil,
        definitions: [LoweredDefinition] = []
    ) throws -> Output {
        var copy = self
        copy.definitionsByName = Dictionary(uniqueKeysWithValues: definitions.map { ($0.functionName, $0) })
        return try copy.emitAll(
            workflows: workflows,
            constantsDecl: constantsDecl,
            instancesDecl: instancesDecl,
            domainDecl: domainDecl,
            fileMetadata: fileMetadata,
            definitions: definitions
        )
    }

    private func emitAll(
        workflows: [IRWorkflow],
        constantsDecl: ConstantsDecl?,
        instancesDecl: InstancesDecl?,
        domainDecl: DomainDecl?,
        fileMetadata: FileMetadataAST?,
        definitions: [LoweredDefinition]
    ) throws -> Output {
        let trace = ParserTrace.current
        try IRValidator.validate(workflows, sourceFile: options.sourceFileName)
        trace.log(.codegen, "emit file: \(workflows.count) workflow(s), \(definitions.count) definition(s)\(options.namespaceEnum.map { ", namespace \($0)" } ?? "")")
        if let namespace = options.namespaceEnum {
            trace.log(.codegen, "emit namespace wrapper: public enum \(namespace)")
        }
        if let d = domainDecl {
            trace.log(.codegen, "emit domain: \(d.kinds.count) kind(s), \(d.enumerations.count) enumeration(s)")
        }
        if let c = constantsDecl {
            trace.log(.codegen, "emit constants: \(c.entries.count) entrie(s)")
        }
        if let i = instancesDecl {
            trace.log(.codegen, "emit instances: \(i.entries.count) entrie(s)")
        }
        trace.log(.codegen, "multi-file emit: domain + workflows split")

        let combined = try render(
            workflows: workflows,
            constantsDecl: constantsDecl,
            instancesDecl: instancesDecl,
            domainDecl: domainDecl,
            fileMetadata: fileMetadata,
            definitions: definitions
        )
        let domain = try render(
            workflows: [],
            constantsDecl: constantsDecl,
            instancesDecl: instancesDecl,
            domainDecl: domainDecl,
            fileMetadata: nil,
            definitions: definitions
        )
        // The workflows part of the split has never resolved definition
        // helpers (the historical `emitMultiFile` passed `definitions: []`),
        // so render it from a copy with an empty `definitionsByName` to keep
        // the emitted predicate calls byte-identical.
        var workflowsOnly = self
        workflowsOnly.definitionsByName = [:]
        let workflowsPart = try workflowsOnly.render(
            workflows: workflows,
            constantsDecl: nil,
            instancesDecl: nil,
            domainDecl: nil,
            fileMetadata: fileMetadata,
            definitions: []
        )
        return Output(domain: domain, workflows: workflowsPart, combined: combined)
    }

    private func render(
        workflows: [IRWorkflow],
        constantsDecl: ConstantsDecl?,
        instancesDecl: InstancesDecl?,
        domainDecl: DomainDecl?,
        fileMetadata: FileMetadataAST?,
        definitions: [LoweredDefinition]
    ) throws -> String {
        let trace = ParserTrace.current
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
                let resolved = resolveParameterKind(p.kind.name, declaredKinds: declaredKinds)
                return (IdentifierNaming.camelPreservingCase(p.name), resolved)
            }
        }
        let namespace = options.namespaceEnum
        return StringTemplate {
            fileHeader()
            ""
            if namespace == nil {
                // 2B: checkable-adjective helpers live at file scope (private),
                // so they resolve from every workflow `run()`. A `Definition:`
                // body can reference a declared constant/instance
                // (`constants.highValueThreshold`) — when namespaced, those
                // live inside the `public enum` wrapper below, so the helper
                // functions must move inside it too (see the `namespace`
                // branch) or the reference would be out of scope.
                for def in definitions {
                    if !definitionRequiresAsyncTrace(def.body) && !definitionRequiresState(def.body, bound: [def.subjectVar]) {
                        emitDefinitionFunction(def)
                        ""
                    }
                }
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
            if namespace != nil {
                for def in definitions {
                    if !definitionRequiresAsyncTrace(def.body) && !definitionRequiresState(def.body, bound: [def.subjectVar]) {
                        emitDefinitionFunction(def)
                        ""
                    }
                }
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
    /// to `emit`, otherwise the reference would be unresolved.
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
                .filter { resolveParameterKind($0.kind.name, declaredKinds: declaredKinds) != "Value" }
                .map { IdentifierNaming.camelPreservingCase($0.name) }
        )
        let stateHistoryEnabled = workflow.runtimeTraceConfiguration?.trace.stateHistoryRetention ?? false
        let ctx = Ctx(
            depth: 0,
            options: options,
            workflowParamTypes: workflowParamTypes,
            typedIdentifiers: typedParams,
            stateHistoryEnabled: stateHistoryEnabled
        )
        func resolveKind(_ k: String) -> String {
            resolveParameterKind(k, declaredKinds: declaredKinds)
        }
        let paramDecls = workflow.parameters.map {
            "    public let \(IdentifierNaming.camelPreservingCase($0.name)): \(resolveKind($0.kind.name))"
        }
        let initParams = (["runtime: Runtime"] + workflow.parameters.map {
            "\(IdentifierNaming.camelPreservingCase($0.name)): \(resolveKind($0.kind.name))"
        }).joined(separator: ", ")
        let initAssigns = workflow.parameters.map {
            let name = IdentifierNaming.camelPreservingCase($0.name)
            return "        self.\(name) = \(name)"
        }
        let stateBinds = workflow.parameters.map {
            let name = IdentifierNaming.camelPreservingCase($0.name)
            return "        state.bind(\"\($0.name)\", \(name))"
        }

        return StringTemplate {
            "public struct \(workflow.structName): MeridianWorkflow {"
            "    public let runtime: Runtime"
            for decl in paramDecls { decl }
            // B1: Skill-discovery metadata as a static dictionary.
            if let entries = skillMetadata, !entries.isEmpty {
                ""
                "    public static let skillMetadata: [String: String] = ["
                for (k, v) in entries {
                    "        \"\(escapeSwiftStringLiteral(k))\": \"\(escapeSwiftStringLiteral(v))\","
                }
                "    ]"
            }
            if let traceConfig = workflow.runtimeTraceConfiguration {
                ""
                "    public static let skillVersionHash = \"\(escapeSwiftStringLiteral(workflow.skillVersionHash))\""
                // Must be typed as Optional to witness `MeridianWorkflow.runtimeTraceConfiguration`
                // (a non-optional `let` does not replace the protocol-extension default of `nil`).
                "    public static let runtimeTraceConfiguration: RuntimeTraceConfiguration? = \(emitRuntimeTraceConfiguration(traceConfig))"
            }
            ""
            "    public init(\(initParams)) {"
            "        self.runtime = runtime"
            for assign in initAssigns { assign }
            "    }"
            ""
            "    public func run() async throws -> WorkflowResult {"
            "        do {"
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
                "        await runtime.complete(reason: nil, step: \"\(workflow.structName).complete\")"
                "        return WorkflowResult(reason: nil, durationMS: await runtime.elapsedMS(), eventCount: await runtime.eventCount(), bindings: state.snapshot().asValues)"
            }
            "        } catch {"
            "            if error is CancellationError { throw error }"
            "            try await runtime.workflowFailed(workflowName: \"\(workflow.structName)\", error: error)"
            "            throw error"
            "        }"
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
        let range = p.sourceRange
        ParserTrace.current.log(.codegen, "emit \(primitiveTraceName(p)) L\(range.startLine)")
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
        case .aiJudgment(let ir):
            return emitAIJudgment(ir, ctx: ctx)
        case .aiAutonomy(let ir):
            return emitAIAutonomy(ir, ctx: ctx)
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
        return stableStepPath(for: p, fallbackPath: path)
    }

    func isCommit(_ p: IRPrimitive) -> Bool {
        if case .commit = p { return true }
        return false
    }

    func progressLabel(for p: IRPrimitive, path: String) -> String {
        let range = p.sourceRange
        return "progress:\(path):L\(range.startLine):C\(range.startColumn)"
    }

    func stableStepPath(for p: IRPrimitive, fallbackPath: String) -> String {
        p.stableStepPath ?? progressLabel(for: p, path: fallbackPath)
    }

    func emitRuntimeTraceConfiguration(_ config: RuntimeTraceConfiguration) -> String {
        let toolPolicies = config.toolCapturePolicies.sorted { $0.key < $1.key }.map { key, value in
            let rendered: String
            switch value {
            case .full:
                rendered = ".full"
            case .hashOnly:
                rendered = ".hashOnly"
            case .omitted:
                rendered = ".omitted"
            case .redacted(let fields):
                let joined = fields.map { "\"\(escapeSwiftStringLiteral($0))\"" }.joined(separator: ", ")
                rendered = ".redacted([\(joined)])"
            }
            return "\"\(escapeSwiftStringLiteral(key))\": \(rendered)"
        }.joined(separator: ", ")
        let toolPoliciesLiteral = toolPolicies.isEmpty ? "[:]" : "[\(toolPolicies)]"
        var optionalStoreFields = ""
        if let storePath = config.storePath {
            optionalStoreFields += ",\n        storePath: \"\(escapeSwiftStringLiteral(storePath))\""
        }
        return """
RuntimeTraceConfiguration(
        store: .\(config.store.rawValue),
        trace: TraceConfiguration(
            retention: .seconds(\(config.trace.retention.components.seconds)),
            payloadLimit: \(config.trace.payloadLimit.map(String.init) ?? "nil"),
            usuallyThreshold: \(config.trace.usuallyThreshold),
            rarelyThreshold: \(config.trace.rarelyThreshold),
            sampleFloor: \(config.trace.sampleFloor),
            defaultMonitorCadence: .seconds(\(config.trace.defaultMonitorCadence.components.seconds)),
            profile: .\(config.trace.profile.rawValue),
            storeFailurePolicy: .\(config.trace.storeFailurePolicy.rawValue),
            deploymentZone: "\(escapeSwiftStringLiteral(config.trace.deploymentZone))",
            crossSkillAllowList: [\(config.trace.crossSkillAllowList.map { "\"\(escapeSwiftStringLiteral($0))\"" }.joined(separator: ", "))],
            stateHistoryRetention: \(config.trace.stateHistoryRetention)
        ),
        skillIdentity: TraceSkillIdentity(
            name: "\(escapeSwiftStringLiteral(config.skillIdentity.name))",
            versionHash: "\(escapeSwiftStringLiteral(config.skillIdentity.versionHash))"
        ),
        toolCapturePolicies: \(toolPoliciesLiteral)\(optionalStoreFields)
    )
"""
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
        case .aiJudgment: return "aiJudgment"
        case .aiAutonomy: return "aiAutonomy"
        }
    }

    func swiftIdentifierSuffix(_ raw: String) -> String {
        raw.map { ch in
            ch.isLetter || ch.isNumber ? String(ch) : "_"
        }.joined()
    }
}

// MARK: - Ctx (emit context / indentation)

struct Ctx {
    let depth: Int
    let options: SwiftEmitter.Options

    /// `structName → [(paramName, kindTypeName)]` lookup populated at the top
    /// of `emit`. Empty when an emitter call doesn't have access to the
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

    /// When true, generated bind/rebind/commit sites emit `.stateSnapshot` records.
    let stateHistoryEnabled: Bool

    var s: String { String(repeating: options.indentUnit, count: depth) }

    init(
        depth: Int,
        options: SwiftEmitter.Options,
        workflowParamTypes: [String: [(name: String, kind: String)]] = [:],
        typedIdentifiers: Set<String> = [],
        stateHistoryEnabled: Bool = false
    ) {
        self.depth = depth
        self.options = options
        self.workflowParamTypes = workflowParamTypes
        self.typedIdentifiers = typedIdentifiers
        self.stateHistoryEnabled = stateHistoryEnabled
    }

    func `in`(_ levels: Int) -> Ctx {
        Ctx(
            depth: depth + levels,
            options: options,
            workflowParamTypes: workflowParamTypes,
            typedIdentifiers: typedIdentifiers,
            stateHistoryEnabled: stateHistoryEnabled
        )
    }

    func withTyped(_ extra: [String]) -> Ctx {
        Ctx(
            depth: depth,
            options: options,
            workflowParamTypes: workflowParamTypes,
            typedIdentifiers: typedIdentifiers.union(extra),
            stateHistoryEnabled: stateHistoryEnabled
        )
    }
}
