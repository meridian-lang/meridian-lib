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
    private let maxInlineDepth = 8

    public init(symbols: SymbolTable, sourceFile: String = "", trace: ParserTrace = .shared,
                lexicon: EnglishLexicon = .default,
                fallbackPolicy: FallbackPolicy = .strict,
                rulebook: Rulebook = .empty,
                scopedTools: [String]? = nil) {
        self.symbols = symbols
        self.sourceFile = sourceFile
        self.trace = trace
        self.lexicon = lexicon
        self.fallbackPolicy = fallbackPolicy
        self.rulebook = rulebook
        self.scopedTools = scopedTools
    }

    /// Effective tool allow-list for a prose/autonomy plan step.
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
        var workflows = try file.workflows.map { try lowerWorkflow($0) }

        // C1-C4: Classify and inject rules into lowered workflows.
        if !file.rules.isEmpty {
            let analyzer = RuleAnalyzer(lexicon: lexicon, trace: trace)
            let lowerActionClosure: (String, SourceRange) throws -> [IRPrimitive] = { text, range in
                let invocation = PhraseInvocationAST(words: text, sourceLine: range.startLine)
                return try self.lowerPhraseInvocation(invocation, mode: .strict, depth: 0)
            }
            var injector = RuleInjector(
                symbols: symbols, lexicon: lexicon, trace: trace,
                lowerAction: lowerActionClosure,
                fallbackPolicy: fallbackPolicy, sourceFile: sourceFile
            )

            // Classify every rule. Each Nil result is either a hard error
            // or (when the policy allows) a logged drop.
            var parsedRules: [ParsedRule] = []
            for raw in file.rules {
                if let parsed = analyzer.classify(raw) {
                    parsedRules.append(parsed)
                } else {
                    if fallbackPolicy.allows(.unparseableRules) {
                        trace.log(.lowering, "rule unparseable @L\(raw.sourceLine) (allow-fallbacks: unparseable-rules): \(raw.text)")
                    } else {
                        throw CompilerError.semanticError(
                            message: "unparseable rule: \"\(raw.text)\". Use one of the supported rule shapes (must / must not / must be … by … before / when / may), or set frontmatter `allow-fallbacks: unparseable-rules` to drop it.",
                            range: sourceRange(raw.sourceLine)
                        )
                    }
                }
            }

            workflows = try injector.inject(rules: parsedRules, into: workflows, sourceFile: sourceFile)

            // Surface unattached rules. Strict mode treats this as an error
            // because a rule that matches no workflow is almost always a bug
            // (typo in the action verb, missing target workflow, etc.).
            for u in injector.unattachedRules {
                if fallbackPolicy.allows(.unattachedRules) {
                    trace.log(.lowering, "rule did not attach (allow-fallbacks: unattached-rules): \(describeRule(u.rule)) — \(u.reason)")
                } else {
                    throw CompilerError.semanticError(
                        message: "rule did not attach to any workflow: \(describeRule(u.rule)). Make sure the rule's action verb matches a workflow's name or parameter, or set frontmatter `allow-fallbacks: unattached-rules` to drop the rule.",
                        range: sourceRange(ruleLine(u.rule))
                    )
                }
            }

            let triggers = try injector.synthesizeTriggers(parsedRules, sourceFile: sourceFile)
            // synthesizeTriggers may throw if a trigger's action doesn't lower
            // and the policy doesn't allow `unresolved-trigger-actions`.
            workflows += triggers
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

        return workflows
    }

    /// Parse a convention body statement and lower it to IR through the strict
    /// pipeline. Used by `ConventionInjector` to turn `before/after/…` rule
    /// bodies into prepended/appended primitives.
    private func lowerConventionBody(_ text: String, sourceLine: Int) throws -> [IRPrimitive] {
        let sp = StatementParser(symbols: symbols, trace: trace, lexicon: lexicon)
        let bodyText = text.hasSuffix(".") ? text : text + "."
        let line = SourceLine(indent: 0, text: bodyText, raw: text, number: sourceLine)
        let block = try sp.parseBlock([line], file: sourceFile)
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
        case .permission(_, _, _, _, _, let line, let txt):return "L\(line) [permission] \(txt)"
        }
    }

    private func ruleLine(_ r: ParsedRule) -> Int {
        switch r {
        case .invariant(_, _, _, let line, _),
             .parameterGuard(_, _, _, let line, _),
             .precondition(_, _, _, _, let line, _),
             .trigger(_, _, let line, _),
             .permission(_, _, _, _, _, let line, _):
            return line
        }
    }

    public func lowerWorkflow(_ ast: WorkflowAST) throws -> IRWorkflow {
        let token = trace.push(.lowering, "lowerWorkflow: \(ast.pattern.displayText)")
        defer { trace.pop(token) }
        let parameters = phraseParameters(ast.pattern)
        let mode: ExecutionMode = modeFromBlock(ast.body)
        let defaultParam = ast.pattern.parameters.count == 1 ? ast.pattern.parameters[0] : nil
        let autonomyConfig = ast.autonomy.map(lowerAutonomyConfig)
        let proseDispatchMode: ProseDispatchMode? = ast.autonomy != nil
            ? .autonomousLoop
            : (ast.allowsDiscretion ? .planThenExecute : nil)
        let body = try lowerBlock(
            ast.body,
            mode: mode,
            depth: 0,
            defaultParam: defaultParam,
            proseDispatchMode: proseDispatchMode,
            autonomyConfig: autonomyConfig
        )
        let derivedStructName = IRWorkflow.structName(from: ast.pattern.displayText, lexicon: lexicon)
        return IRWorkflow(
            name: ast.pattern.displayText,
            parameters: parameters,
            body: body,
            mode: mode,
            sourceFile: ast.sourceFile.isEmpty ? sourceFile : ast.sourceFile,
            sourceRange: sourceRange(ast.sourceLine),
            explicitStructName: derivedStructName
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
    private func kindName(_ s: String) -> String {
        s.split(separator: " ").map { word in
            word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined()
    }

    // MARK: - Block lowering

    func lowerBlock(
        _ block: ASTBlock,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: PhraseParameterAST? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil
    ) throws -> IRBlock {
        var stmts: [IRPrimitive] = []
        for stmt in block.statements {
            if case .modal = stmt { continue }  // already consumed as mode
            let lowered = try lowerStatement(
                stmt,
                mode: mode,
                depth: depth,
                defaultParam: defaultParam,
                proseDispatchMode: proseDispatchMode,
                autonomyConfig: autonomyConfig
            )
            stmts += lowered
        }
        return IRBlock(statements: stmts, sourceRange: sourceRange(block.sourceLine))
    }

    private func modeFromBlock(_ block: ASTBlock) -> ExecutionMode {
        for stmt in block.statements {
            if case .modal(let m) = stmt { return m == .lenient ? .lenient : .strict }
        }
        return .strict
    }

    private func lowerAutonomyConfig(_ config: AutonomyConfigAST) -> AutonomyConfigIR {
        AutonomyConfigIR(
            until: config.until.map(lowerExpr),
            unless: config.unless.map(lowerExpr),
            replanAfterFailures: config.replanAfterFailures,
            maxSteps: config.maxSteps
        )
    }

    // MARK: - Statement lowering

    func lowerStatement(
        _ stmt: StatementAST,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: PhraseParameterAST? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil
    ) throws -> [IRPrimitive] {
        switch stmt {

        case .bind(let s):
            return try lowerBind(s, mode: mode, depth: depth)

        case .rebind(let s):
            return try lowerRebind(s, mode: mode, depth: depth)

        case .emit(let s):
            let ir = EmitIR(
                eventID: s.eventID,
                payload: s.payload.map { EmitField($0.0, lowerExpr($0.1)) },
                strict: mode == .strict,
                sourceRange: sourceRange(s.sourceLine)
            )
            return [.emit(ir)]

        case .complete(let s):
            return [.complete(CompleteIR(reason: s.reason, sourceRange: sourceRange(s.sourceLine)))]

        case .commit(let s):
            return [.commit(CommitIR(label: s.label, sourceRange: sourceRange(s.sourceLine)))]

        case .wait(let s):
            let cond = lowerWaitCondition(s.condition)
            // Choice-gate lowers to a fan-out `ask.choice` emit (so the host
            // sees the prompt + options) followed by the blocking choice wait.
            if case .choice(let prompt, let options) = cond {
                let sr = sourceRange(s.sourceLine)
                let emit = EmitIR(
                    eventID: "ask.choice",
                    payload: [
                        EmitField("prompt", .literal(.string(prompt))),
                        EmitField("options", .literal(.string(options.joined(separator: ", "))))
                    ],
                    strict: true,
                    sourceRange: sr
                )
                return [.emit(emit), .wait(WaitIR(condition: cond, sourceRange: sr))]
            }
            return [.wait(WaitIR(condition: cond, sourceRange: sourceRange(s.sourceLine)))]

        case .assertStmt(let s):
            let otherwise = try s.otherwise.map { try lowerBlock($0, mode: mode, depth: depth) }
            return [.assert(AssertIR(
                condition: lowerExpr(s.condition),
                message: s.message,
                otherwiseAction: otherwise,
                sourceRange: sourceRange(s.sourceLine)
            ))]

        case .conditional(let s):
            let thenBlock = try lowerBlock(s.thenBlock, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig)
            let elseBlock = try s.elseBlock.map { try lowerBlock($0, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig) }
            let condExpr  = lowerExpr(s.condition)
            return [.branch(BranchIR(
                condition: .predicate(condExpr),
                thenBlock: thenBlock,
                elseBlock: elseBlock,
                sourceRange: sourceRange(s.sourceLine)
            ))]

        case .iteration(let s):
            let body = try lowerBlock(s.body, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig)
            let range = sourceRange(s.sourceLine)
            switch s.mode {
            case .forEach(let variable, let collection):
                let param = variable.trimmingCharacters(in: .whitespaces)
                let coll  = lowerExpr(collection)
                return [.iterate(IterateIR(
                    mode: .overCollection(parameter: param, kind: KindRef("Any"), collection: coll),
                    body: body, sourceRange: range
                ))]
            case .whileCondition(let cond):
                return [.iterate(IterateIR(
                    mode: .whileCondition(lowerExpr(cond)),
                    body: body, sourceRange: range
                ))]
            case .untilCondition(let cond):
                return [.iterate(IterateIR(
                    mode: .untilCondition(lowerExpr(cond)),
                    body: body, sourceRange: range
                ))]
            }

        case .simultaneously(let s):
            let branches = try s.branches.map { try lowerBlock($0, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig) }
            return [.simultaneously(SimultaneouslyIR(
                branches: branches,
                detached: s.detached,
                sourceRange: sourceRange(s.sourceLine)
            ))]

        case .phraseInvocation(let s):
            return try lowerPhraseInvocation(s, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig)

        case .recover(let s):
            return try lowerRecover(s, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig)

        case .labelled(let s):
            return try lowerStatement(s.statement, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig)

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
                effectiveAutonomy = s.autonomy.map(lowerAutonomyConfig)
                    ?? autonomyConfig ?? AutonomyConfigIR()
            case .none:
                effectiveMode = proseDispatchMode
                effectiveAutonomy = autonomyConfig
            }
            guard let mode = effectiveMode else {
                throw CompilerError.semanticError(
                    message: "free-form prose is only allowed in workflows marked `with discretion` or `with autonomy`, or inside an explicit `use judgment to …:` marker",
                    range: sourceRange(s.sourceLine)
                )
            }
            return [.proseStep(ProseStepIR(
                text: s.text,
                scopedTools: effectiveScopedTools,
                dispatchMode: mode,
                autonomy: effectiveAutonomy,
                sourceRange: sourceRange(s.sourceLine)
            ))]

        case .modal:
            return []  // handled at block level
        }
    }

    // MARK: - Recover lowering

    private func lowerRecover(
        _ s: RecoverStatementAST,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: PhraseParameterAST? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil
    ) throws -> [IRPrimitive] {
        let pattern = lowerRecoverPattern(s.pattern)
        let handlerBlock = try lowerBlock(s.handler, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig)
        // Lower the attached statement into an IRBlock so the recover wraps
        // the full set of IR primitives, even when a phrase inlines to several.
        let attachedPrimitives = try lowerStatement(s.attached, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig)
        let attachedBlock = IRBlock(statements: attachedPrimitives, sourceRange: sourceRange(s.attached.sourceLine))
        return [.recover(RecoverIR(
            pattern: pattern,
            handler: handlerBlock,
            attachedTo: attachedBlock,
            sourceRange: sourceRange(s.sourceLine)
        ))]
    }

    private func lowerRecoverPattern(_ p: RecoverPatternAST) -> ErrorPattern {
        switch p {
        case .any:              return .anyError
        case .named(let n):     return .named(n)
        case .typed(let t):     return .typed(KindRef(t))
        case .predicate(let e): return .predicate(lowerExpr(e))
        }
    }

    // MARK: - Bind lowering

    private func lowerBind(_ s: BindStatementAST, mode: ExecutionMode, depth: Int) throws -> [IRPrimitive] {
        let bindName = camelCase(s.name)
        if case .invoke(let toolID, let args) = s.value {
            let invokeIR = InvokeIR(
                toolID: toolID,
                arguments: args.map { InvokeArg($0.0, lowerExpr($0.1)) },
                resultBinding: bindName,
                sourceRange: sourceRange(s.sourceLine)
            )
            return [.invoke(invokeIR)]
        }
        return [.bind(BindIR(name: bindName, expression: lowerExpr(s.value), sourceRange: sourceRange(s.sourceLine)))]
    }

    private func lowerRebind(_ s: RebindStatementAST, mode: ExecutionMode, depth: Int) throws -> [IRPrimitive] {
        let bindName = camelCase(s.name)
        if case .invoke(let toolID, let args) = s.value {
            let invokeIR = InvokeIR(
                toolID: toolID,
                arguments: args.map { InvokeArg($0.0, lowerExpr($0.1)) },
                resultBinding: bindName,
                sourceRange: sourceRange(s.sourceLine)
            )
            return [.invoke(invokeIR)]
        }
        return [.bind(BindIR(name: bindName, expression: lowerExpr(s.value), isRebind: true, sourceRange: sourceRange(s.sourceLine)))]
    }

    private func camelCase(_ s: String) -> String {
        let words = s.split(whereSeparator: { $0 == " " || $0 == "_" }).map(String.init)
        guard let first = words.first else { return s }
        return first + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// Inverse of `camelCase`: `"mailerServer"` → `"mailer server"`. Used by
    /// phrase-invocation text substitution so a body written as
    /// `the mailer server` matches a camelCase parameter name.
    private func decamel(_ s: String) -> String {
        var out = ""
        for ch in s {
            if ch.isUppercase, !out.isEmpty { out.append(" ") }
            out.append(Character(ch.lowercased()))
        }
        return out
    }

    // MARK: - Phrase invocation

    func lowerPhraseInvocation(
        _ s: PhraseInvocationAST,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: PhraseParameterAST? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil
    ) throws -> [IRPrimitive] {
        let token = trace.push(.phraseInline, "phrase invocation @L\(s.sourceLine) depth=\(depth): \"\(s.words)\"")
        defer { trace.pop(token) }

        guard depth < maxInlineDepth else {
            trace.log(.phraseInline, "  depth limit reached — bailing out")
            return []
        }

        // Command surface: a verbatim shell command (from a fenced ```bash
        // block or an inline backticked command) lowers to a deterministic
        // `shell.run` invoke. This sits before the prose gate so literal
        // commands stay deterministic even inside a discretion/autonomy
        // workflow — exactly like an explicit `invoke …`.
        if let command = decodeShellCommand(s.words) {
            trace.log(.phraseInline, "  shell command → shell.run")
            return [.invoke(InvokeIR(
                toolID: "shell.run",
                arguments: [InvokeArg("command", .literal(.string(command)))],
                sourceRange: sourceRange(s.sourceLine)
            ))]
        }

        if s.words.lowercased().hasPrefix("invoke ") {
            let sp = StatementParser(symbols: symbols, trace: trace, lexicon: lexicon)
            let expr = sp.buildInvokeExpr(s.words)
            if case .invoke(let toolID, let args) = expr {
                trace.log(.phraseInline, "  bare invoke: tool=\(toolID) args=\(args.count)")
                return autoBindIfNeeded([.invoke(InvokeIR(
                    toolID: toolID,
                    arguments: args.map { InvokeArg($0.0, lowerExpr($0.1)) },
                    sourceRange: sourceRange(s.sourceLine)
                ))], invocationWords: s.words)
            }
        }

        // When a workflow is declared `with discretion` or `with autonomy`,
        // EVERY body line is prose — never a deterministic phrase invocation.
        // Without this gate a prose sentence whose first word happens to match
        // a vocabulary phrase (e.g. "Inspect the failing job…" overlapping
        // with the deterministic phrase "inspect the ci status of a pull
        // request") would silently bypass the planner and lower to the wrong
        // tool call. Phrase resolution is only consulted in non-prose
        // workflows.
        if let proseDispatchMode {
            return [.proseStep(ProseStepIR(
                text: s.words,
                scopedTools: effectiveScopedTools,
                dispatchMode: proseDispatchMode,
                autonomy: autonomyConfig,
                sourceRange: sourceRange(s.sourceLine)
            ))]
        }

        guard let (phrase, args) = symbols.matchPhrase(s.words, defaultParam: defaultParam) else {
            if fallbackPolicy.allows(.unresolvedPhrases) {
                trace.log(.phraseInline, "  UNRESOLVED — emitting placeholder (allow-fallbacks: unresolved-phrases)")
                return [.bind(BindIR(
                    name: "_unresolved",
                    expression: .literal(.string("/* unresolved: \(s.words) */")),
                    sourceRange: sourceRange(s.sourceLine)
                ))]
            } else {
                throw CompilerError.semanticError(
                    message: "unresolved phrase: \"\(s.words)\". Add a matching phrase or workflow, or set frontmatter `allow-fallbacks: unresolved-phrases` to allow placeholders.",
                    range: sourceRange(s.sourceLine)
                )
            }
        }

        if let structName = phrase.workflowStructName {
            // Argument order MUST match the pattern's declared parameter order
            // (which is what `IRWorkflow.parameters` and the generated init
            // signature use). Dict iteration is unordered, so iterate the
            // pattern instead.
            //
            // `extractArgs` stores values under `param.name` verbatim (which is
            // already camelCased). Try the verbatim form first and fall back to
            // a few common case/spacing variants so a body written with snake
            // or space-separated parameter names still resolves.
            let ordered: [InvokeArg] = phrase.pattern.parameters.compactMap { p in
                let candidates = [
                    p.name,
                    p.name.lowercased(),
                    p.kind.lowercased(),
                    p.name.replacingOccurrences(of: " ", with: ""),
                ]
                for candidate in candidates {
                    if let val = args[candidate] {
                        return InvokeArg(p.name, lowerExpr(val))
                    }
                }
                return nil
            }
            trace.log(.phraseInline, "  workflow call → \(structName)  args=\(ordered.map(\.key))")
            return [.invoke(InvokeIR(
                toolID: "workflow:\(structName)",
                arguments: ordered,
                sourceRange: sourceRange(s.sourceLine)
            ))]
        }

        trace.log(.phraseInline, "  matched @L\(phrase.sourceLine)  args=\(args.keys.sorted())")
        let inlined = try inlinePhrase(
            phrase,
            args: args,
            mode: mode,
            depth: depth + 1,
            defaultParam: defaultParam,
            proseDispatchMode: proseDispatchMode,
            autonomyConfig: autonomyConfig
        )
        return autoBindIfNeeded(inlined, invocationWords: s.words)
    }

    private func autoBindIfNeeded(_ primitives: [IRPrimitive], invocationWords: String) -> [IRPrimitive] {
        guard primitives.count == 1,
              case .invoke(let invoke) = primitives[0],
              invoke.resultBinding == nil,
              toolReturnsValue(invoke.toolID),
              let bindName = implicitBindName(from: invocationWords) else {
            return primitives
        }
        trace.log(.lowering, "implicit bind \(bindName) for \(invoke.toolID)")
        return [.invoke(InvokeIR(
            toolID: invoke.toolID,
            arguments: invoke.arguments,
            resultBinding: bindName,
            sourceRange: invoke.sourceRange
        ))]
    }

    private func toolReturnsValue(_ toolID: String) -> Bool {
        guard !toolID.hasPrefix("workflow:") else {
            return false
        }
        guard let tool = symbols.tools[toolID] ?? symbols.tools.values.first(where: {
            $0.methodName.caseInsensitiveCompare(toolID) == .orderedSame
        }) else { return false }
        let ret = tool.returnType.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return !ret.isEmpty && !["void", "unit", "none"].contains(ret)
    }

    private func implicitBindName(from invocationWords: String) -> String? {
        var text = invocationWords.trimmingCharacters(in: .whitespaces)
        if text.lowercased().hasPrefix("invoke ") {
            text = String(text.dropFirst("invoke ".count)).trimmingCharacters(in: .whitespaces)
        }
        let tokens = text.split(separator: " ").map(String.init)
        guard tokens.count > 1 else { return nil }

        var objectWords: [String] = []
        for token in tokens.dropFirst() {
            let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",;:."))
            let lower = cleaned.lowercased()
            if lexicon.prepositions.contains(lower) || lower == "with" {
                break
            }
            if lexicon.articles.contains(lower) { continue }
            objectWords.append(cleaned)
        }
        guard !objectWords.isEmpty else { return nil }
        return camelCase(objectWords.joined(separator: " "))
    }

    // MARK: - Phrase inlining

    private func inlinePhrase(
        _ phrase: PhraseDefinition,
        args: [String: ExpressionAST],
        mode: ExecutionMode,
        depth: Int,
        defaultParam: PhraseParameterAST? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil
    ) throws -> [IRPrimitive] {
        let token = trace.push(.phraseInline, "inline phrase @L\(phrase.sourceLine)")
        defer { trace.pop(token) }
        let inlinedBlock = substituteArgs(phrase.body, args: args)
        return try lowerBlock(inlinedBlock, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig).statements
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
                for v in variants {
                    words = wholeWordReplace(words, of: "the \(v)", with: argText)
                }
                for v in variants {
                    words = wholeWordReplace(words, of: v, with: argText)
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
            let camel = lower.split(whereSeparator: { $0 == " " || $0 == "_" })
                .enumerated()
                .map { i, w in i == 0 ? String(w) : w.prefix(1).uppercased() + w.dropFirst() }
                .joined()
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
        case .instanceRef, .constantRef, .literal, .envVar, .now, .decideWhether:
            return expr
        case .interpolatedString(let segs):
            return .interpolatedString(segs.map { seg in
                switch seg {
                case .literal:           return seg
                case .expression(let e): return .expression(subExpr(e, args: args))
                }
            })
        }
    }

    /// Replace whole-word occurrences of `needle` (case-insensitive) with
    /// `replacement`, keeping any internal text untouched. Used for phrase
    /// argument substitution to avoid mangling words like "ordered" when
    /// substituting "order".
    private func wholeWordReplace(_ haystack: String, of needle: String, with replacement: String) -> String {
        guard !needle.isEmpty else { return haystack }
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: needle))\\b"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return haystack.replacingOccurrences(of: needle, with: replacement, options: .caseInsensitive)
        }
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        return re.stringByReplacingMatches(in: haystack, options: [], range: range, withTemplate: NSRegularExpression.escapedTemplate(for: replacement))
    }

    /// Render an ExpressionAST back to a text fragment for phrase text substitution.
    /// Identifiers render bare (without "the ") so substitution into a body that
    /// already has "the {param}" produces clean possessive forms like "order's id".
    /// `ExpressionParser` handles bare possessives in `parseAtom`.
    private func exprToText(_ expr: ExpressionAST) -> String {
        switch expr {
        case .identifierRef(let n):             return n
        case .instanceRef(let n):               return "the \(n)"
        case .constantRef(let n):               return "the \(n)"
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

    // MARK: - Expression lowering

    func lowerExpr(_ expr: ExpressionAST) -> IRExpression {
        switch expr {
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
            return .propertyAccess(lowerExpr(base), propertyName: prop)
        case .comparison(let lhs, let op, let rhs):
            return .comparison(lowerExpr(lhs), lowerCompOp(op), lowerExpr(rhs))
        case .logical(let op, let exprs):
            return .logical(lowerLogicalOp(op), exprs.map(lowerExpr))
        case .envVar(let name):
            return .envVar(name: name)
        case .now:
            return .nowExpression
        case .invoke(let toolID, let args):
            return .invocation(InvokeIR(
                toolID: toolID,
                arguments: args.map { InvokeArg($0.0, lowerExpr($0.1)) }
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
            let irSegs = segs.map { seg -> IRInterpolationSegment in
                switch seg {
                case .literal(let s):    return .literal(s)
                case .expression(let e): return .expression(lowerExpr(e))
                }
            }
            return .interpolatedString(irSegs)
        }
    }

    private func lowerLiteral(_ lit: LiteralAST) -> IRLiteral {
        switch lit {
        case .string(let s):                return .string(s)
        case .integer(let n):               return .number(Decimal(n))
        case .double(let d):                return .number(Decimal(d))
        case .boolean(let b):               return .boolean(b)
        case .money(let a, let c):          return .money(Decimal(a), currency: c)
        case .duration(let v, let unit):    return .duration(Duration.seconds(Int64(v * Double(unit.inSeconds))))
        }
    }

    private func lowerCompOp(_ op: ComparisonOpAST) -> ComparisonOp {
        switch op {
        case .equal:          return .equal
        case .notEqual:       return .notEqual
        case .lessThan:       return .lessThan
        case .lessOrEqual:    return .lessOrEqual
        case .greaterThan:    return .greaterThan
        case .greaterOrEqual: return .greaterOrEqual
        case .within:         return .withinDuration
        }
    }

    private func lowerLogicalOp(_ op: LogicalOpAST) -> LogicalOp {
        switch op {
        case .and: return .and
        case .or:  return .or
        case .not: return .not
        }
    }

    private func lowerWaitCondition(_ cond: WaitConditionAST) -> WaitConditionIR {
        switch cond {
        case .duration(let v, let unit):
            return .duration(Duration.seconds(Int64(v * Double(unit.inSeconds))))
        case .signal(let id):
            return .signal(id)
        case .approval(let subj, let role):
            return .approval(of: lowerExpr(subj), by: role)
        case .event(let id, let matching):
            return .event(id, matching: matching.map { lowerExpr($0) })
        case .choice(let prompt, let options):
            return .choice(prompt: prompt, options: options)
        }
    }

    // MARK: - Source range helper

    func sourceRange(_ line: Int) -> SourceRange {
        SourceRange(file: sourceFile, line: line, column: 0)
    }
}
