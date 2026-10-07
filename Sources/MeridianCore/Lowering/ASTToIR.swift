import Foundation
import MeridianRuntime

// MARK: - ASTToIR
//
// Lowers MeridianFile and MerConfigFile ASTs to IR (IRWorkflow, IRBlock, etc.).
// Phase 3: supports the 6 easy primitives + branch + wait + basic phrase inlining.
// Phrase inlining: patterns are matched and argument expressions substituted
// recursively, up to maxInlineDepth to prevent infinite loops.

public struct ASTToIR {

    public let symbols: SymbolTable
    public let sourceFile: String
    public let trace: ParserTrace
    public let lexicon: EnglishLexicon
    public let fallbackPolicy: FallbackPolicy
    /// Rulebook supplying section-role mappings and Inform-style conventions.
    /// Empty for plain `.meridian` files.
    public let rulebook: Rulebook
    /// Allow-list of tool method names available to prose/autonomy plan steps.
    /// `nil` means "every registered tool" (the historical default). When a
    /// skill declares frontmatter `tools:`, the Compiler resolves it to method
    /// names and passes the narrowed set here so the planner cannot reach
    /// outside the skill's declared capability surface.
    public let scopedTools: [String]?
    /// Raw tool tokens declared in frontmatter `tools:` and `## Tools Used`.
    /// Used (methodize-normalized) as an additional recognized tool source when
    /// validating `InvokeIR.toolID`, so a tool declared in frontmatter but not in
    /// `=== tools ===` (e.g. `get_health` → `getHealth`) still resolves.
    public let frontmatterTools: [String]
    /// Optional batch collector. When present, the per-workflow and per-rule
    /// loops in `lower` recover from a thrown `CompilerError` (collect + skip the
    /// construct) so one compile reports many errors. When `nil`, the historical
    /// first-error-throws behaviour is preserved.
    public let engine: DiagnosticEngine?
    let maxInlineDepth = 8

    /// Throw a lowering error for `DiagnosticEngine.recovering` to collect — do
    /// not pre-report: `recovering` calls `collect` on the thrown payload.
    func throwLoweringError(_ diagnostic: Diagnostic) throws -> Never {
        throw CompilerError.diagnostics([diagnostic])
    }

    public init(symbols: SymbolTable, sourceFile: String = "", trace: ParserTrace = .shared,
                lexicon: EnglishLexicon = .default,
                fallbackPolicy: FallbackPolicy = .strict,
                rulebook: Rulebook = .empty,
                scopedTools: [String]? = nil,
                frontmatterTools: [String] = [],
                engine: DiagnosticEngine? = nil) {
        self.symbols = symbols
        self.sourceFile = sourceFile
        self.trace = trace
        self.lexicon = lexicon
        self.fallbackPolicy = fallbackPolicy
        self.rulebook = rulebook
        self.scopedTools = scopedTools
        self.frontmatterTools = frontmatterTools
        self.engine = engine
    }

    /// Effective tool allow-list for a judgment/autonomy plan step.
    /// Build a single AI-routed statement. Both AI entry points (an explicit
    /// `proseStep` AST node and an unresolved phrase invocation inside a
    /// discretion/autonomy workflow) share the same scoped-tools and
    /// source-range plumbing; only `text`, `dispatchMode`, and `autonomy` vary
    /// — `dispatchMode` selects which of the two split IR primitives is built.
    func makeAIPrimitive(
        text: String,
        dispatchMode: ProseDispatchMode,
        autonomy: AutonomyConfigIR?,
        line: Int,
        guidance: String? = nil,
        outputBindings: [(kind: String, name: String)] = [],
        usingTools: [String] = []
    ) -> IRPrimitive {
        let scoped = resolveJudgmentTools(usingTools, line: line)
        let outputKind = outputBindings.first?.kind.lowercased() ?? "record"
        switch dispatchMode {
        case .planThenExecute:
            return .aiJudgment(AIJudgmentIR(
                text: text,
                scopedTools: scoped,
                sourceRange: sourceRange(line),
                guidance: guidance,
                outputKind: outputKind
            ))
        case .autonomousLoop:
            return .aiAutonomy(AIAutonomyIR(
                text: text,
                scopedTools: scoped,
                autonomy: autonomy ?? AutonomyConfigIR(),
                sourceRange: sourceRange(line),
                guidance: guidance,
                outputKind: outputKind
            ))
        }
    }

    private func resolveJudgmentTools(_ usingTools: [String], line: Int) -> [String] {
        guard !usingTools.isEmpty else { return effectiveScopedTools }
        let allowed = Set((frontmatterTools + (scopedTools ?? [])).map { $0.lowercased() })
        for tool in usingTools {
            let key = tool.lowercased()
            let declared = symbols.tools.keys.contains { $0.lowercased() == key || symbols.tools[$0]?.displayName.lowercased() == key }
            let permitted = allowed.contains(key) || allowed.contains(where: { key.hasSuffix($0) })
            if !declared || !permitted {
                let diag = Diagnostic.error(
                    .judgmentToolOutsidePermissions,
                    message: "judgment step names tool `\(tool)` outside the skill's permission scope",
                    range: sourceRange(line),
                    notes: [DiagnosticNote("same condition as MER-DEO-004 (deontic tool outside permissions)")],
                    help: "Add `\(tool)` to frontmatter `tools:` / permissions, or remove it from the `using` clause.")
                if let engine {
                    engine.report(diag)
                }
            }
        }
        return usingTools
    }

    private var effectiveScopedTools: [String] {
        scopedTools ?? Array(symbols.tools.keys).sorted()
    }

    // MARK: - Entry points

    public func lower(_ file: MeridianFile, preRegistered: Bool = false) throws -> [IRWorkflow] {
        // Register every workflow as a phrase stub before lowering, so that
        // mid-body recursive calls like "process the order placed by the
        // customer" resolve and lower to a workflow invocation instead of
        // emitting an `_unresolved` placeholder. In a skillpack compile the
        // caller pre-registers every file's workflows into the shared symbol
        // table first (for cross-file resolution), so this self-registration is
        // skipped to avoid duplicate stubs.
        if !preRegistered {
            for wf in file.workflows {
                let structName = IRWorkflow.structName(from: wf.pattern.displayText, lexicon: lexicon)
                symbols.registerWorkflowPhrase(
                    pattern: wf.pattern,
                    structName: structName,
                    sourceLine: wf.sourceLine,
                    sourceFile: wf.sourceFile.isEmpty ? sourceFile : wf.sourceFile
                )
            }
        }
        // 2B: Register checkable adjectives (merconfig + file-level) before any
        // workflow lowers, so `X is <adj>` and `for each <adj> <kind>` resolve
        // regardless of source order. Idempotent across repeated `lower` calls.
        try registerDefinitions(file.definitions)

        // 3A/3B: validate the relational layer (backings, verb→relation, form
        // collisions) before any workflow body lowers.
        try validateRelationsAndVerbs()

        // Per-workflow recovery boundary: with a batch engine, a workflow whose
        // body fails to lower is collected and skipped so the rest of the file
        // still reports. Cascade-safe because every workflow was registered as a
        // phrase stub above, so dependent invocations still resolve.
        var workflows: [IRWorkflow]
        if let engine {
            workflows = []
            for wf in file.workflows {
                let context = "workflow \(wf.pattern.displayText)"
                if let lowered = try engine.recovering(context: context, { try lowerWorkflow(wf) }) {
                    workflows.append(lowered)
                }
            }
        } else {
            workflows = try file.workflows.map { try lowerWorkflow($0) }
        }

        // C1-C4: Classify and inject rules into lowered workflows.
        if !file.rules.isEmpty {
            let analyzer = RuleAnalyzer(lexicon: lexicon, trace: trace, symbols: symbols)
            let lowerActionClosure: (String, SourceRange) throws -> [IRPrimitive] = { text, range in
                let invocation = PhraseInvocationAST(words: text, sourceLine: range.startLine)
                return try self.lowerPhraseInvocation(invocation, mode: .strict, depth: 0)
            }
            var injector = RuleInjector(
                symbols: symbols, lexicon: lexicon, trace: trace,
                lowerAction: lowerActionClosure,
                fallbackPolicy: fallbackPolicy, sourceFile: sourceFile,
                reportFallback: { [self] diagnostic in reportFallbackWarning(diagnostic) }
            )

            // Classify every rule. Each Nil result is either a hard error
            // or (when the policy allows) a logged drop.
            var parsedRules: [ParsedRule] = []
            for raw in file.rules {
                if let rejection = analyzer.deonticRejection(for: raw, sourceFile: sourceFile) {
                    if let engine { engine.report(rejection) } else { throw CompilerError.diagnostics([rejection]) }
                    continue
                }
                if let parsed = try analyzer.classify(raw) {
                    parsedRules.append(parsed)
                } else {
                    if fallbackPolicy.allows(.unparseableRules) {
                        reportFallbackWarning(
                            .unparseableRule,
                            message: "unparseable rule dropped by allow-fallbacks: \"\(raw.text)\"",
                            range: sourceRange(raw.sourceLine),
                            help: "Remove `allow-fallbacks: unparseable-rules` to make this a hard error, or rewrite the rule into a supported rule shape.")
                    } else {
                        let diag = Diagnostic.structural(
                            .unparseableRule,
                            message: "unparseable rule: \"\(raw.text)\"",
                            range: sourceRange(raw.sourceLine),
                            help: "Use one of the supported rule shapes (must / must not / must be … by … before / when / may), or set frontmatter `allow-fallbacks: unparseable-rules` to drop it.")
                        if let engine { engine.report(diag) } else { throw CompilerError.diagnostics([diag]) }
                    }
                }
            }

            if let engine {
                workflows = (try engine.recovering(context: "rule injection", { try injector.inject(rules: parsedRules, into: workflows, sourceFile: sourceFile) })) ?? workflows
            } else {
                workflows = try injector.inject(rules: parsedRules, into: workflows, sourceFile: sourceFile)
            }

            let norms = DeonticLowering.norms(from: parsedRules).map { norm in
                NormIR(
                    id: norm.id,
                    kind: norm.kind,
                    scope: norm.scope,
                    actionPattern: norm.actionPattern,
                    condition: norm.condition,
                    blocking: norm.blocking,
                    sourceRange: SourceRange(file: sourceFile, line: norm.sourceRange.startLine, column: 0),
                    originalText: norm.originalText
                )
            }
            let finalizedNorms = try NormId.finalize(norms)
            let conflictDiagnostics = DeonticLowering.detectConflicts(finalizedNorms)
            if !conflictDiagnostics.isEmpty {
                if let engine {
                    for diag in conflictDiagnostics { engine.report(diag) }
                }
                throw CompilerError.diagnostics(conflictDiagnostics)
            }
            workflows = try DeonticLowering.apply(norms: finalizedNorms, to: workflows, engine: engine)

            // Surface unattached rules. Strict mode treats this as an error
            // because a rule that matches no workflow is almost always a bug
            // (typo in the action verb, missing target workflow, etc.).
            for u in injector.unattachedRules {
                if fallbackPolicy.allows(.unattachedRules) {
                    reportFallbackWarning(
                        .unattachedRule,
                        message: "unattached rule dropped by allow-fallbacks: \(describeRule(u.rule))",
                        range: sourceRange(ruleLine(u.rule)),
                        help: "Remove `allow-fallbacks: unattached-rules` to make this a hard error, or align the rule's action with a workflow.")
                } else {
                    let diag = Diagnostic.error(
                        .unattachedRule,
                        message: "rule did not attach to any workflow: \(describeRule(u.rule))",
                        range: sourceRange(ruleLine(u.rule)),
                        help: "Make sure the rule's action verb matches a workflow's name or parameter, or set frontmatter `allow-fallbacks: unattached-rules` to drop the rule.")
                    if let engine { engine.report(diag) } else { throw CompilerError.diagnostics([diag]) }
                }
            }

            // synthesizeTriggers may throw if a trigger's action doesn't lower
            // and the policy doesn't allow `unresolved-trigger-actions`.
            if let engine {
                if let triggers = try engine.recovering(context: "triggers", { try injector.synthesizeTriggers(parsedRules, sourceFile: sourceFile) }) {
                    workflows += triggers
                }
            } else {
                workflows += try injector.synthesizeTriggers(parsedRules, sourceFile: sourceFile)
            }
        }

        // J: Inject the rulebook's Inform-style conventions (before/check →
        // prepend guard, after/report/carry-out → append step, instead-of →
        // replace) into every matching workflow. The body is parsed + lowered
        // through the same strict pipeline, so an unresolved convention body is
        // a hard error just like inline source.
        if !rulebook.conventions.isEmpty {
            let conventionInjector = ConventionInjector(
                lexicon: lexicon, trace: trace,
                lowerBody: { [self] text, line in try lowerConventionBody(text, sourceLine: line) }
            )
            workflows = try conventionInjector.inject(
                conventions: rulebook.conventions, into: workflows
            )
        }

        // Pillar 6: every emitted tool ID must resolve to a recognized source
        // (built-in catalog, vocabulary `=== tools ===`, frontmatter `tools:`,
        // or a `workflow:` reference). A miss is almost always a typo or a
        // forgotten declaration — surface it with did-you-mean.
        validateToolIDs(in: workflows)

        return workflows
    }

    /// Lower a standalone expression through the compiler's normal AST -> IR
    /// path. This is for authoring/debugging tools that need the real lowered
    /// semantics for one condition without inventing a second lowering path.
    public func lowerExpression(_ expression: ExpressionAST, scope: Set<String>? = nil, line: Int = 1) throws -> IRExpression {
        try lowerExpr(expression, scope: scope, line: line)
    }

    // MARK: - Tool-ID validation (Pillar 6)

    func reportFallbackWarning(
        _ code: DiagnosticCode,
        message: String,
        range: SourceRange,
        help: String? = nil
    ) {
        reportFallbackWarning(Diagnostic.warning(code, message: message, range: range, help: help))
    }

    func reportFallbackWarning(_ diagnostic: Diagnostic) {
        trace.log(.lowering, "fallback warning \(diagnostic.code.id): \(diagnostic.message)")
        engine?.report(diagnostic)
    }

    /// Methodize a raw tool token the same way the invoke path does
    /// (`get_health` → `getHealth`), so frontmatter `tools:` tokens line up
    /// with the emitted `InvokeIR.toolID`.
    private func methodizeToolToken(_ name: String) -> String {
        IdentifierNaming.methodize(name, stopwords: lexicon.articles)
    }

    /// The union of every recognized tool ID for this compile, in the same
    /// surface forms the invoke path can resolve. Because a declared tool is
    /// matched case-insensitively against its `methodName` and an *undeclared*
    /// tool is `methodize`-d (so the built-in `llm.chat` is invoked as
    /// `llmChat`), every source contributes both its raw and methodized form,
    /// and recognition is done on lowercased keys (see `validateToolIDs`).
    private func recognizedToolForms() -> Set<String> {
        var forms: Set<String> = []
        func add(_ s: String) {
            forms.insert(s.lowercased())
            forms.insert(methodizeToolToken(s).lowercased())
        }
        for id in BuiltinToolCatalog.ids { add(id) }
        for (key, decl) in symbols.tools {
            add(key)
            add(decl.methodName)
        }
        if let scopedTools { for s in scopedTools { add(s) } }
        for token in frontmatterTools { add(token) }
        return forms
    }

    private func validateToolIDs(in workflows: [IRWorkflow]) {
        guard engine != nil else {
            // Without a batch engine (the test-runner re-lower / RunCommand
            // re-lower paths) the primary compile already validated tool IDs, so
            // skip to avoid a redundant first-error throw on a non-canonical path.
            return
        }
        let recognized = recognizedToolForms()
        let candidates = Array(Set(BuiltinToolCatalog.ids + symbols.tools.values.map { $0.methodName })).sorted()
        var seen: Set<String> = []
        for prim in IRWalker.flatPrimitives(workflows: workflows) {
            guard case .invoke(let inv) = prim else { continue }
            let id = inv.toolID
            // `workflow:<Struct>` references and already-recognized tools pass.
            if id.hasPrefix("workflow:") || recognized.contains(id.lowercased()) { continue }
            // The `_unresolved` placeholder (allow-fallbacks: unresolved-phrases)
            // is reported elsewhere; don't double-flag its synthetic invoke.
            if id.isEmpty || id == "_unresolved" { continue }
            guard seen.insert(id).inserted else { continue }
            if fallbackPolicy.allows(.unknownTools) {
                reportFallbackWarning(
                    .unknownTool,
                    message: "unknown tool allowed by fallback: \(id)",
                    range: inv.sourceRange,
                    help: "Declare the tool when possible; keep `allow-fallbacks: unknown-tools` only for host-provided runtime tools.")
                continue
            }
            engine?.report(Diagnostic.unresolved(
                .unknownTool,
                target: id,
                among: candidates,
                range: inv.sourceRange,
                noun: "tool",
                help: "Declare it in a `=== tools ===` block or frontmatter `tools:`, or set frontmatter `allow-fallbacks: unknown-tools` if it is a host-provided tool registered at runtime."))
        }
    }

    /// Parse a convention body statement and lower it to IR through the strict
    /// pipeline. Used by `ConventionInjector` to turn `before/after/…` rule
    /// bodies into prepended/appended primitives.
    private func lowerConventionBody(_ text: String, sourceLine: Int) throws -> [IRPrimitive] {
        let sp = StatementParser(symbols: symbols, trace: trace, lexicon: lexicon)
        let bodyText = text.hasSuffix(".") ? text : text + "."
        let line = SourceLine(indent: 0, text: bodyText, raw: text, number: sourceLine)
        let block = try sp.parseBlock([line], sourceFile: sourceFile)
        return try block.statements.flatMap {
            try lowerStatement($0, mode: .strict, depth: 0)
        }
    }

    private func describeRule(_ r: ParsedRule) -> String {
        switch r {
        case .invariant(_, _, _, let line, let txt):       return "L\(line) [invariant] \(txt)"
        case .parameterGuard(_, _, _, let line, let txt):  return "L\(line) [parameterGuard] \(txt)"
        case .precondition(_, _, _, _, let line, let txt): return "L\(line) [precondition] \(txt)"
        case .trigger(_, _, let line, let txt):            return "L\(line) [trigger] \(txt)"
        case .unsupportedTriggerCondition(_, _, let line, let txt): return "L\(line) [unsupportedTriggerCondition] \(txt)"
        case .permission(_, _, _, _, _, let line, let txt):return "L\(line) [permission] \(txt)"
        case .deonticProhibition(let norm): return "L\(norm.sourceRange.startLine) [deonticProhibition] \(norm.originalText)"
        case .deonticObligation(let norm): return "L\(norm.sourceRange.startLine) [deonticObligation] \(norm.originalText)"
        case .deonticPermission(let norm): return "L\(norm.sourceRange.startLine) [deonticPermission] \(norm.originalText)"
        }
    }

    private func ruleLine(_ r: ParsedRule) -> Int {
        switch r {
        case .invariant(_, _, _, let line, _),
             .parameterGuard(_, _, _, let line, _),
             .precondition(_, _, _, _, let line, _),
             .trigger(_, _, let line, _),
             .unsupportedTriggerCondition(_, _, let line, _),
             .permission(_, _, _, _, _, let line, _):
            return line
        case .deonticProhibition(let norm), .deonticObligation(let norm), .deonticPermission(let norm):
            return norm.sourceRange.startLine
        }
    }

    public func lowerWorkflow(_ ast: WorkflowAST) throws -> IRWorkflow {
        let token = trace.push(.lowering, "lowerWorkflow: \(ast.pattern.displayText)")
        defer { trace.pop(token) }
        let parameters = phraseParameters(ast.pattern)
        let mode: ExecutionMode = modeFromBlock(ast.body)
        let owningStructName = IRWorkflow.structName(from: ast.pattern.displayText, lexicon: lexicon)
        // Pairing the single default parameter with its OWNING workflow's
        // struct name lets `matchPhrase`'s low-confidence implicit-fill retry
        // (below) refuse to resolve back to the workflow currently being
        // lowered — see `SymbolTable.matchPhrase`'s `excludingStructName`.
        // Without this, a leftover unmined narrative line anywhere in a
        // single-parameter workflow's own body can spuriously self-match via
        // the implicit fill (any shared word with the workflow's own trigger
        // text is enough), producing a nonsense recursive self-invocation
        // instead of the intended `unresolvedPhrase` diagnostic.
        let defaultParam: (parameter: PhraseParameterAST, owningStructName: String)? =
            ast.pattern.parameters.count == 1 ? (ast.pattern.parameters[0], owningStructName) : nil
        let autonomyConfig = try ast.autonomy.map(lowerAutonomyConfig)
        let proseDispatchMode: ProseDispatchMode? = ast.autonomy != nil
            ? .autonomousLoop
            : (ast.allowsDiscretion ? .planThenExecute : nil)
        // Seed the scope tracker (1B) with the workflow's parameter names. It
        // grows as binds / invoke result-bindings / loop variables are lowered,
        // and is consulted to validate command holes ({…}) against in-scope
        // names. Names are normalized via `scopeKey` so camelCase / spacing
        // differences between params, binds, and lowered hole identifiers match.
        let initialScope = Set(parameters.map { scopeKey($0.name) })
        // Enforce the compound note form's declared/text contract before lowering
        // (INFORM7 §2.9): undeclared → MER-REF-004, non-text → MER-TYP-001.
        try validateNoteTargets(in: ast.body, declared: initialScope, textDeclared: [])
        let body = try lowerBlock(
            ast.body,
            mode: mode,
            depth: 0,
            defaultParam: defaultParam,
            proseDispatchMode: proseDispatchMode,
            autonomyConfig: autonomyConfig,
            scope: initialScope
        )
        return IRWorkflow(
            name: ast.pattern.displayText,
            parameters: parameters,
            body: body,
            mode: mode,
            sourceFile: ast.sourceFile.isEmpty ? sourceFile : ast.sourceFile,
            sourceRange: sourceRange(ast.sourceLine),
            explicitStructName: owningStructName
        )
    }

    // MARK: - Parameters from phrase pattern

    private func phraseParameters(_ pattern: PhrasePattern) -> [IRParameter] {
        // PhrasePattern parameters already store names in lower-camelCase
        // (`pull request` → `pullRequest`) via `tryParseParam.camelize`. Keep
        // the casing intact: identifier references lowered through
        // `lowerExpr.identifierRef` also use the same camelCase form, so the
        // emitted Swift init param and the call-site identifier line up
        // letter-for-letter. An earlier `.lowercased()` here drove `pullRequest`
        // to `pullrequest`, which then collided with `pullRequest` on the
        // value side and produced "cannot find pullRequest in scope" errors.
        pattern.parameters.map { p in
            IRParameter(name: p.name, kind: KindRef(kindName(p.kind)))
        }
    }

    /// Convert a natural-language kind name to UpperCamelCase Swift type name.
    private func kindName(_ s: String) -> String { IdentifierNaming.pascalCaseFromSpaces(s) }

    // MARK: - Block lowering

    func lowerBlock(
        _ block: ASTBlock,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: (parameter: PhraseParameterAST, owningStructName: String)? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil,
        scope: Set<String> = []
    ) throws -> IRBlock {
        var stmts: [IRPrimitive] = []
        var scope = scope
        for stmt in block.statements {
            if case .modal = stmt { continue }  // already consumed as mode
            let lowered = try lowerStatement(
                stmt,
                mode: mode,
                depth: depth,
                defaultParam: defaultParam,
                proseDispatchMode: proseDispatchMode,
                autonomyConfig: autonomyConfig,
                scope: scope
            )
            stmts += lowered
            // A bind / invoke result-binding is in scope for later statements.
            scope.formUnion(boundNames(in: lowered))
        }
        return IRBlock(statements: stmts, sourceRange: sourceRange(block.sourceLine))
    }

    /// Names introduced by a lowered statement's top-level primitives (binds and
    /// invoke result-bindings), normalized for scope membership.
    private func boundNames(in primitives: [IRPrimitive]) -> Set<String> {
        var names: Set<String> = []
        for p in primitives {
            switch p {
            case .bind(let b):           names.insert(scopeKey(b.name))
            case .invoke(let i):         if let r = i.resultBinding { names.insert(scopeKey(r)) }
            default:                     break
            }
        }
        return names
    }

    /// Canonical key for scope membership: lowercased, alphanumerics only. This
    /// folds camelCase parameter names (`pullRequest`), spaced bind names
    /// (`validation result` → `validationResult`), and lowered hole identifiers
    /// to a single comparable form.
    func scopeKey(_ s: String) -> String { ScopeNaming.key(s) }

    private func modeFromBlock(_ block: ASTBlock) -> ExecutionMode {
        for stmt in block.statements {
            if case .modal(let m) = stmt { return m == .lenient ? .lenient : .strict }
        }
        return .strict
    }

    func lowerAutonomyConfig(_ config: AutonomyConfigAST) throws -> AutonomyConfigIR {
        AutonomyConfigIR(
            until: try config.until.map { try lowerExpr($0) },
            unless: try config.unless.map { try lowerExpr($0) },
            replanAfterFailures: config.replanAfterFailures,
            maxSteps: config.maxSteps
        )
    }

    // MARK: - Source range helper

    func sourceRange(_ line: Int) -> SourceRange {
        // Column 0 = "whole line" (the renderer clamps to a line-accurate caret
        // at column 1). This value also feeds codegen progress labels
        // (`progress:…:C<col>`), so it must stay 0 to keep goldens stable; precise
        // carets come from the Tier-2 `SourceLine.range(file:of:)` helper.
        SourceRange(file: sourceFile, line: line, column: 0)
    }

}
