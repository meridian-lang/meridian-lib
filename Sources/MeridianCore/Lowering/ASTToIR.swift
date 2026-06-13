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
        // 2B: Register checkable adjectives (merconfig + file-level) before any
        // workflow lowers, so `X is <adj>` and `for each <adj> <kind>` resolve
        // regardless of source order. Idempotent across repeated `lower` calls.
        try registerDefinitions(file.definitions)

        // 3A/3B: validate the relational layer (backings, verb→relation, form
        // collisions) before any workflow body lowers.
        try validateRelationsAndVerbs()

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
        let body = try lowerBlock(
            ast.body,
            mode: mode,
            depth: 0,
            defaultParam: defaultParam,
            proseDispatchMode: proseDispatchMode,
            autonomyConfig: autonomyConfig,
            scope: initialScope
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
    private func scopeKey(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    private func modeFromBlock(_ block: ASTBlock) -> ExecutionMode {
        for stmt in block.statements {
            if case .modal(let m) = stmt { return m == .lenient ? .lenient : .strict }
        }
        return .strict
    }

    private func lowerAutonomyConfig(_ config: AutonomyConfigAST) throws -> AutonomyConfigIR {
        AutonomyConfigIR(
            until: try config.until.map { try lowerExpr($0) },
            unless: try config.unless.map { try lowerExpr($0) },
            replanAfterFailures: config.replanAfterFailures,
            maxSteps: config.maxSteps
        )
    }

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
            guard let e, let msg = firstMalformed(e) else { return }
            throw CompilerError.semanticError(message: msg, range: sourceRange(stmt.sourceLine))
        }
        switch stmt {
        case .bind(let s):        try check(s.value)
        case .rebind(let s):      try check(s.value)
        case .emit(let s):        for (_, v) in s.payload { try check(v) }
        case .assertStmt(let s):  try check(s.condition)
        case .conditional(let s): try check(s.condition)
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
    /// expression tree. Returns its diagnostic message, or `nil` when clean.
    private func firstMalformed(_ e: ExpressionAST) -> String? {
        switch e {
        case .malformed(let m):
            return m
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
                if case .expression(let x) = s, let m = firstMalformed(x) { return m }
            }
            return nil
        case .recordList(_, let rows):
            for row in rows { for cell in row { if let m = firstMalformed(cell) { return m } } }
            return nil
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
        default:
            return nil
        }
    }

    private func firstMalformedInDescription(_ d: DescriptionAST) -> String? {
        if let wp = d.wherePredicate, let m = firstMalformed(wp) { return m }
        for c in d.verbClauses { if let m = firstMalformed(c.operand) { return m } }
        return nil
    }

    func lowerStatement(
        _ stmt: StatementAST,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: PhraseParameterAST? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil,
        scope: Set<String> = []
    ) throws -> [IRPrimitive] {
        try assertNoMalformed(stmt)
        switch stmt {

        case .bind(let s):
            return try lowerBind(s, mode: mode, depth: depth, scope: scope)

        case .rebind(let s):
            return try lowerRebind(s, mode: mode, depth: depth, scope: scope)

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
            let otherwise = try s.otherwise.map { try lowerBlock($0, mode: mode, depth: depth, scope: scope) }
            return [.assert(AssertIR(
                condition: try lowerExpr(s.condition, scope: scope, line: s.sourceLine),
                message: s.message,
                otherwiseAction: otherwise,
                sourceRange: sourceRange(s.sourceLine)
            ))]

        case .conditional(let s):
            let thenBlock = try lowerBlock(s.thenBlock, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope)
            let elseBlock = try s.elseBlock.map { try lowerBlock($0, mode: mode, depth: depth, defaultParam: defaultParam, proseDispatchMode: proseDispatchMode, autonomyConfig: autonomyConfig, scope: scope) }
            let condExpr  = try lowerExpr(s.condition, scope: scope, line: s.sourceLine)
            return [.branch(BranchIR(
                condition: .predicate(condExpr),
                thenBlock: thenBlock,
                elseBlock: elseBlock,
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

    // MARK: - Bind lowering

    private func lowerBind(_ s: BindStatementAST, mode: ExecutionMode, depth: Int,
                           scope: Set<String>? = nil) throws -> [IRPrimitive] {
        let bindName = camelCase(s.name)
        if case .invoke(let toolID, let args) = s.value {
            let invokeIR = InvokeIR(
                toolID: toolID,
                arguments: try args.map { InvokeArg($0.0, try lowerExpr($0.1, scope: scope, line: s.sourceLine)) },
                resultBinding: bindName,
                sourceRange: sourceRange(s.sourceLine)
            )
            return [.invoke(invokeIR)]
        }
        let (prelude, value) = try lowerBindValue(s.value, scope: scope, line: s.sourceLine)
        return prelude + [.bind(BindIR(name: bindName, expression: value, sourceRange: sourceRange(s.sourceLine)))]
    }

    private func lowerRebind(_ s: RebindStatementAST, mode: ExecutionMode, depth: Int,
                             scope: Set<String>? = nil) throws -> [IRPrimitive] {
        let bindName = camelCase(s.name)
        if case .invoke(let toolID, let args) = s.value {
            let invokeIR = InvokeIR(
                toolID: toolID,
                arguments: try args.map { InvokeArg($0.0, try lowerExpr($0.1, scope: scope, line: s.sourceLine)) },
                resultBinding: bindName,
                sourceRange: sourceRange(s.sourceLine)
            )
            return [.invoke(invokeIR)]
        }
        let (prelude, value) = try lowerBindValue(s.value, scope: scope, line: s.sourceLine)
        return prelude + [.bind(BindIR(name: bindName, expression: value, isRebind: true, sourceRange: sourceRange(s.sourceLine)))]
    }

    /// 3C: lower a bind right-hand side, hoisting a tool-backed relation fetch
    /// (description or scalar navigation) into a preceding `invoke` — so the
    /// `await` lives at statement scope, not inside the value expression.
    /// Non-relational values produce no prelude.
    private func lowerBindValue(_ expr: ExpressionAST, scope: Set<String>? = nil, line: Int) throws -> ([IRPrimitive], IRExpression) {
        switch expr {
        case .description(let d):
            let plan = try lowerDescriptionPlan(d, allowToolFetch: true, scope: scope, line: line)
            return (plan.prelude, .description(plan.ir))
        case .aggregate(let k, let d):
            let plan = try lowerDescriptionPlan(d, allowToolFetch: true, scope: scope, line: line)
            return (plan.prelude, .aggregate(k == .count ? .count : .list, plan.ir))
        case .superlative(let s):
            let plan = try lowerDescriptionPlan(s.description, allowToolFetch: true, scope: scope, line: line)
            return (plan.prelude, .superlative(SuperlativeIR(description: plan.ir,
                                                             sortPath: camelCase(s.property),
                                                             ascending: s.ascending)))
        case .relationTraversal(let base, let relation, let navKind):
            let plan = try lowerScalarTraversalPlan(base: base, relationForm: relation, navKind: navKind,
                                                    allowToolFetch: true, scope: scope, line: line)
            return (plan.prelude, plan.expr)
        default:
            return ([], try lowerExpr(expr, scope: scope, line: line))
        }
    }

    private func camelCase(_ s: String) -> String {
        let words = s.split(whereSeparator: { $0 == " " || $0 == "_" }).map(String.init)
        guard let first = words.first else { return s }
        return first + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    private func pascalCase(_ s: String) -> String {
        s.split(whereSeparator: { $0 == " " || $0 == "_" || $0 == "-" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
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

    // MARK: - Command holes (1B)

    /// Lower a decoded shell command into a string literal (no holes) or an
    /// interpolated string with `{…}` holes resolved. A `{…}` span is a typed
    /// hole: its content is parsed as an expression and its identifier roots are
    /// validated against `scope`. `{{`/`}}` are literal braces. A hole inside a
    /// double-quoted span is shell-escaped at runtime (`meridianShellQuote`); a
    /// hole outside quotes interpolates verbatim. An unresolved hole is a hard
    /// sourced error (it cannot silently become a literal).
    private func lowerShellCommand(_ command: String, scope: Set<String>, sourceLine: Int) throws -> IRExpression {
        var segments: [IRInterpolationSegment] = []
        var literal = ""
        var inQuote = false
        let chars = Array(command)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "{", i + 1 < chars.count, chars[i + 1] == "{" {
                literal.append("{"); i += 2; continue
            }
            if c == "}", i + 1 < chars.count, chars[i + 1] == "}" {
                literal.append("}"); i += 2; continue
            }
            if c == "{" {
                // `${…}` is shell parameter expansion, never a hole.
                let precededByDollar = i > 0 && chars[i - 1] == "$"
                var j = i + 1
                var holeText = ""
                var closed = false
                while j < chars.count {
                    if chars[j] == "}" { closed = true; break }
                    holeText.append(chars[j]); j += 1
                }
                guard closed else { literal.append(c); i += 1; continue }
                let exprText = holeText.trimmingCharacters(in: .whitespaces)
                // A `{…}` is a typed hole only when its content is reference-
                // shaped English (words/possessives) and it is not `${…}`. Code-
                // shaped braces (XML namespaces, awk `{print …}`, brace
                // expansion `{a,b}`, JSON) carry non-word characters and stay
                // literal — shell commands routinely contain them. A literal
                // brace whose content *is* word-shaped is written `{{…}}`.
                if !precededByDollar, isReferenceLikeHole(exprText) {
                    if !literal.isEmpty { segments.append(.literal(literal)); literal = "" }
                    let parsed = ExpressionParser(symbols: symbols, trace: trace, lexicon: lexicon).parse(exprText)
                    let lowered = try lowerExpr(parsed)
                    let unresolved = freeIdentifierRoots(lowered).filter { !scope.contains(scopeKey($0)) }
                    if let bad = unresolved.first {
                        let known = scope.sorted().joined(separator: ", ")
                        throw CompilerError.semanticError(
                            message: "command hole \"{\(exprText)}\" references \"\(bad)\", which is not in scope. In-scope names: [\(known)]. Reference a workflow parameter, an earlier bind, or the enclosing loop variable; write `{{`/`}}` for a literal brace.",
                            range: sourceRange(sourceLine)
                        )
                    }
                    segments.append(inQuote ? .shellEscapedExpression(lowered) : .expression(lowered))
                } else {
                    literal.append("{")
                    literal.append(contentsOf: holeText)
                    literal.append("}")
                }
                i = j + 1
                continue
            }
            if c == "\"" { inQuote.toggle() }
            literal.append(c)
            i += 1
        }
        if !literal.isEmpty { segments.append(.literal(literal)) }
        let hasExpr = segments.contains { if case .literal = $0 { return false } else { return true } }
        guard hasExpr else { return .literal(.string(command)) }
        return .interpolatedString(segments)
    }

    /// A `{…}` span is a typed hole only when its content is "reference-shaped":
    /// English words, possessives, articles — letters/digits/spaces plus
    /// apostrophes, hyphens, and underscores, with at least one letter. Any
    /// other character (`/ : . , $ ( ) ; | …`) marks it as code-shaped shell
    /// syntax that stays literal. This is what lets holes and ordinary shell
    /// braces (XML namespaces, awk, brace expansion, JSON) coexist.
    private func isReferenceLikeHole(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        var sawLetter = false
        for ch in s {
            if ch.isLetter { sawLetter = true; continue }
            if ch.isNumber || ch == " " || ch == "'" || ch == "\u{2019}" || ch == "-" || ch == "_" { continue }
            return false
        }
        return sawLetter
    }

    /// Free identifier roots referenced by a lowered expression (the base name
    /// of each property-access chain / bare reference). Constants, instances,
    /// literals, env vars, and `now` contribute nothing — they are always
    /// resolvable. Used to validate command holes against the scope set.
    private func freeIdentifierRoots(_ e: IRExpression) -> [String] {
        switch e {
        case .identifierRef(let n):
            return [n]
        case .propertyAccess(let base, _):
            return freeIdentifierRoots(base)
        case .comparison(let a, _, let b):
            return freeIdentifierRoots(a) + freeIdentifierRoots(b)
        case .logical(_, let xs):
            return xs.flatMap(freeIdentifierRoots)
        case .relationTraversal(let base, _, let target):
            return freeIdentifierRoots(base) + (target.map(freeIdentifierRoots) ?? [])
        case .invocation(let ir):
            return ir.arguments.flatMap { freeIdentifierRoots($0.value) }
        case .interpolatedString(let segs):
            return segs.flatMap { seg -> [String] in
                switch seg {
                case .literal:                       return []
                case .expression(let x):             return freeIdentifierRoots(x)
                case .shellEscapedExpression(let x):  return freeIdentifierRoots(x)
                }
            }
        default:
            return []
        }
    }

    // MARK: - Phrase invocation

    func lowerPhraseInvocation(
        _ s: PhraseInvocationAST,
        mode: ExecutionMode,
        depth: Int,
        defaultParam: PhraseParameterAST? = nil,
        proseDispatchMode: ProseDispatchMode? = nil,
        autonomyConfig: AutonomyConfigIR? = nil,
        scope: Set<String> = []
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
            let commandValue = try lowerShellCommand(command, scope: scope, sourceLine: s.sourceLine)
            return [.invoke(InvokeIR(
                toolID: "shell.run",
                arguments: [InvokeArg("command", commandValue)],
                comment: s.annotation,
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
                    arguments: try args.map { InvokeArg($0.0, try lowerExpr($0.1)) },
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
            let ordered: [InvokeArg] = try phrase.pattern.parameters.compactMap { p in
                let candidates = [
                    p.name,
                    p.name.lowercased(),
                    p.kind.lowercased(),
                    p.name.replacingOccurrences(of: " ", with: ""),
                ]
                for candidate in candidates {
                    if let val = args[candidate] {
                        return InvokeArg(p.name, try lowerExpr(val))
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
                }
            })
        case .recordList(let fields, let rows):
            return .recordList(fields: fields, rows: rows.map { $0.map { subExpr($0, args: args) } })
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
            sort: d.sort, take: d.take
        )
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

    /// Lower an expression. `scope`, when non-nil, is the set of in-scope names
    /// (workflow params + earlier binds + loop vars, normalized via `scopeKey`)
    /// used to validate Wave 3 relation operands; `nil` means "scope unknown here,
    /// skip operand validation" (the safe default for positions that don't thread
    /// it). `line` carries the enclosing statement's source line so Wave 3 errors
    /// point at the right place.
    func lowerExpr(_ expr: ExpressionAST, scope: Set<String>? = nil, line: Int = 0) throws -> IRExpression {
        switch expr {
        case .malformed(let message):
            throw CompilerError.semanticError(message: message, range: sourceRange(line))
        case .quantified(let q):
            return try lowerQuantifier(q)
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
                }
            }
            return .interpolatedString(irSegs)
        case .recordList(let fields, let rows):
            let irRows = try rows.map { row in try row.map { try lowerExpr($0, scope: scope, line: line) } }
            return .recordList(fields: fields, rows: irRows)
        case .verbPredicate(let subject, let verb, let object):
            return try lowerVerbPredicate(subject: subject, verbForm: verb, object: object, scope: scope, line: line)
        case .relationTraversal(let base, let relation, let navKind):
            let plan = try lowerScalarTraversalPlan(base: base, relationForm: relation, navKind: navKind,
                                                    allowToolFetch: false, scope: scope, line: line)
            return plan.expr
        case .description(let d):
            // Value position cannot host an `await` fetch, so a tool-backed
            // source is rejected here (bind it first). Property-backed sources
            // produce an empty prelude.
            return .description(try lowerDescriptionPlan(d, allowToolFetch: false, scope: scope, line: line).ir)
        case .aggregate(let kind, let d):
            let plan = try lowerDescriptionPlan(d, allowToolFetch: false, scope: scope, line: line)
            return .aggregate(kind == .count ? .count : .list, plan.ir)
        case .superlative(let s):
            let plan = try lowerDescriptionPlan(s.description, allowToolFetch: false, scope: scope, line: line)
            return .superlative(SuperlativeIR(description: plan.ir,
                                              sortPath: camelCase(s.property),
                                              ascending: s.ascending))
        }
    }

    /// Lower a comparison. Handles three special shapes before the generic
    /// path: checkable-adjective predicates (`X is/is not <adj>`), the emptiness
    /// operators (RHS is an ignored placeholder), and ordinary comparisons.
    private func lowerComparison(_ lhs: ExpressionAST, _ op: ComparisonOpAST, _ rhs: ExpressionAST,
                                 scope: Set<String>? = nil, line: Int = 0) throws -> IRExpression {
        // 2B: `X is <adj>` / `X is not <adj>` — a checkable-adjective predicate,
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

    // MARK: - 2B. Definition registration & lowering

    /// Register every checkable adjective (merconfig pending + file-level) into
    /// the symbol table, detecting surface-key collisions, then type-check each
    /// body (unknown property references, recursion cycles). Idempotent: a
    /// definition whose `functionName` already matches an identical record is
    /// skipped, so repeated `lower` calls (skillpack) don't false-collide.
    func registerDefinitions(_ fileDefinitions: [DefinitionDeclaration]) throws {
        let all = symbols.pendingDefinitions + fileDefinitions
        guard !all.isEmpty else { return }
        for d in all {
            let key = d.adjective.lowercased().trimmingCharacters(in: .whitespaces)
            let fn = definitionFunctionName(kind: d.kind, adjective: key)
            if let existing = symbols.definition(forAdjective: key) {
                if existing.functionName == fn { continue }   // benign re-register
                throw CompilerError.semanticError(
                    message: "duplicate definition for adjective \"\(d.adjective)\": already defined for kind \"\(existing.kind)\". Adjective names must be globally unique.",
                    range: sourceRange(d.sourceLine)
                )
            }
            symbols.registerDefinition(.init(
                adjective: key, kind: d.kind, subjectVar: d.subjectVar,
                body: d.body, functionName: fn, sourceLine: d.sourceLine
            ))
        }
        // Validate bodies after all are registered (so cross-references resolve).
        for d in all {
            let key = d.adjective.lowercased().trimmingCharacters(in: .whitespaces)
            guard let record = symbols.definition(forAdjective: key) else { continue }
            try typeCheckDefinitionBody(record)
            try detectDefinitionRecursion(start: key)
        }
    }

    private func definitionFunctionName(kind: String, adjective: String) -> String {
        "meridianDef_\(pascalCase(kind))_\(camelCase(adjective))"
    }

    /// Lower every registered adjective definition to a `LoweredDefinition`,
    /// sorted by function name for deterministic emission.
    func lowerRegisteredDefinitions() throws -> [LoweredDefinition] {
        try symbols.definitions.values
            .sorted { $0.functionName < $1.functionName }
            .map { rec in
                let qualified = qualifyDefinitionBody(try lowerExpr(rec.body), subjectVar: camelCase(rec.subjectVar))
                return LoweredDefinition(functionName: rec.functionName,
                                         subjectVar: camelCase(rec.subjectVar),
                                         body: qualified)
            }
    }

    /// Rewrite a definition body so bare property references resolve against the
    /// subject (the function parameter), mirroring loop-var qualification.
    private func qualifyDefinitionBody(_ e: IRExpression, subjectVar: String) -> IRExpression {
        qualifyToLoopVar(e, loopVar: subjectVar)
    }

    /// Type-check a definition body: any property access on the subject must name
    /// a declared property of the kind (only enforced when the kind declares
    /// properties — `.meri`-local kinds without a merconfig are left lenient).
    private func typeCheckDefinitionBody(_ record: SymbolTable.DefinitionRecord) throws {
        let declared = symbols.propertyNames(of: record.kind)
        guard !declared.isEmpty else { return }
        let subject = record.subjectVar.lowercased()
        try walkProperties(record.body) { base, prop in
            guard case .identifierRef(let n) = base, n.lowercased() == subject else { return }
            if !declared.contains(prop.lowercased()) {
                throw CompilerError.semanticError(
                    message: "definition \"\(record.adjective)\" references unknown property \"\(prop)\" on \(record.kind). Declared properties: [\(declared.sorted().joined(separator: ", "))].",
                    range: sourceRange(record.sourceLine)
                )
            }
        }
    }

    private func walkProperties(_ e: ExpressionAST, _ visit: (ExpressionAST, String) throws -> Void) rethrows {
        switch e {
        case .propertyAccess(let base, let prop):
            try visit(base, prop)
            try walkProperties(base, visit)
        case .comparison(let l, _, let r):
            try walkProperties(l, visit); try walkProperties(r, visit)
        case .logical(_, let xs):
            for x in xs { try walkProperties(x, visit) }
        default:
            break
        }
    }

    /// Detect a recursion cycle reachable from `start` through other adjectives
    /// referenced in definition bodies (`X is <other-adj>`).
    private func detectDefinitionRecursion(start: String) throws {
        var visiting: Set<String> = []
        func dfs(_ adj: String, path: [String]) throws {
            if visiting.contains(adj) {
                throw CompilerError.semanticError(
                    message: "recursive definition detected: \(path.joined(separator: " → ")) → \(adj). Definitions must not reference themselves (directly or transitively).",
                    range: sourceRange(symbols.definition(forAdjective: adj)?.sourceLine ?? 0)
                )
            }
            guard let record = symbols.definition(forAdjective: adj) else { return }
            visiting.insert(adj)
            for ref in referencedAdjectives(record.body) {
                try dfs(ref, path: path + [adj])
            }
            visiting.remove(adj)
        }
        try dfs(start, path: [])
    }

    /// Adjective surface forms referenced as `X is/is not <adj>` in a body.
    private func referencedAdjectives(_ e: ExpressionAST) -> [String] {
        switch e {
        case .comparison(_, let op, let rhs) where op == .equal || op == .notEqual:
            if case .identifierRef(let name) = rhs,
               symbols.definition(forAdjective: name) != nil {
                return [name.lowercased().trimmingCharacters(in: .whitespaces)]
            }
            return []
        case .logical(_, let xs):
            return xs.flatMap { referencedAdjectives($0) }
        default:
            return []
        }
    }

    /// Resolve a surface adjective to a definition-predicate filter over `subject`.
    private func resolveAdjectiveFilter(adjective: String, subject: IRExpression, sourceLine: Int) throws -> IRExpression {
        guard let record = symbols.definition(forAdjective: adjective) else {
            throw CompilerError.semanticError(
                message: "unknown adjective \"\(adjective)\". Declare it with `Definition: a <kind> is \(adjective) if <condition>.`",
                range: sourceRange(sourceLine)
            )
        }
        return .definitionPredicate(functionName: record.functionName, subject: subject)
    }

    // MARK: - 2C. Quantifier lowering

    private func lowerQuantifier(_ q: QuantifierAST) throws -> IRExpression {
        let noun = q.description.noun.trimmingCharacters(in: .whitespaces)
        guard !noun.isEmpty else {
            throw CompilerError.semanticError(
                message: "quantifier is missing a collection noun.", range: sourceRange(0))
        }
        let elementVar = lexicon.singularize(noun.lowercased())

        // Source: a bound collection identifier, fetched once. Invocations are
        // rejected so the collection isn't re-evaluated per reducer.
        let collection = try lowerExpr(.identifierRef(noun))
        if case .invocation = collection {
            throw CompilerError.semanticError(
                message: "quantifier source must be a bound collection name (a parameter or earlier bind), not a tool call.",
                range: sourceRange(0))
        }

        var filters: [IRExpression] = []
        for adj in q.description.adjectives {
            filters.append(try resolveAdjectiveFilter(
                adjective: adj, subject: .identifierRef(name: elementVar), sourceLine: 0))
        }
        if let wherePred = q.description.wherePredicate {
            filters.append(qualifyToLoopVar(try lowerExpr(wherePred), loopVar: elementVar))
        }

        let body = try q.body.map { qualifyToLoopVar(try lowerExpr($0), loopVar: elementVar) }
        if case .all = q.kind, body == nil, filters.isEmpty {
            throw CompilerError.semanticError(
                message: "`all <description>` needs a body (e.g. `all pages have a summary`) or a `whose`/adjective restriction.",
                range: sourceRange(0))
        }

        let desc = DescriptionIR(collection: collection, elementVar: elementVar, filters: filters)
        return .quantified(QuantifierIR(kind: lowerQuantKind(q.kind), description: desc, body: body))
    }

    private func lowerQuantKind(_ k: QuantifierKindAST) -> QuantifierKind {
        switch k {
        case .all:           return .all
        case .any:           return .any
        case .none:          return .none
        case .atLeast(let n): return .atLeast(n)
        case .atMost(let n):  return .atMost(n)
        case .exactly(let n): return .exactly(n)
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

    /// Lower a 1C iteration refinement, qualifying the `whose` predicate's bare
    /// property LHS to a property access on the loop variable and turning the
    /// temporal clause into a one-sided window comparison.
    private func lowerIterationRefinement(_ r: IterationRefinementAST, loopVar: String) throws -> IRIterationRefinement {
        var filters: [IRExpression] = []
        // 2B: leading adjective modifiers (`for each stale page`) resolve to
        // definition predicates over the loop variable.
        for adj in r.adjectives {
            filters.append(try resolveAdjectiveFilter(adjective: adj,
                                                      subject: .identifierRef(name: loopVar),
                                                      sourceLine: 0))
        }
        if let pred = r.predicate {
            filters.append(qualifyToLoopVar(try lowerExpr(pred), loopVar: loopVar))
        }
        if let temporal = r.temporal {
            let op: ComparisonOp = temporal.window == .past ? .withinPast : .withinFuture
            filters.append(.comparison(
                .propertyAccess(.identifierRef(name: loopVar), propertyName: temporal.property),
                op,
                .literal(.duration(.seconds(Int64(temporal.seconds))))
            ))
        }
        let sort = r.sort.map { (path: $0.property, ascending: $0.ascending) }
        return IRIterationRefinement(filters: filters, sort: sort, take: r.take)
    }

    /// Rewrite a comparison's LHS (a bare property name) into a property access
    /// on the loop variable, so `whose status is "open"` becomes
    /// `<loopVar>.status == "open"`.
    private func qualifyToLoopVar(_ e: IRExpression, loopVar: String) -> IRExpression {
        switch e {
        case .comparison(let lhs, let op, let rhs):
            // Only the LHS is the subject property; the RHS is a comparison value.
            return .comparison(qualifyOperand(lhs, loopVar: loopVar), op, rhs)
        case .logical(let op, let xs):
            return .logical(op, xs.map { qualifyToLoopVar($0, loopVar: loopVar) })
        case .definitionPredicate(let fn, let subj):
            return .definitionPredicate(functionName: fn, subject: qualifyOperand(subj, loopVar: loopVar))
        case .identifierRef:
            // A bare boolean property (`whose archived`) → `<loopVar>.archived`.
            return qualifyOperand(e, loopVar: loopVar)
        default:
            return e
        }
    }

    private func qualifyOperand(_ e: IRExpression, loopVar: String) -> IRExpression {
        switch e {
        case .identifierRef(let name):
            // The loop variable itself is the element, not a property of it.
            if name == loopVar { return e }
            return .propertyAccess(.identifierRef(name: loopVar), propertyName: name)
        default:
            return e
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
        case .contains:       return .contains
        case .oneOf:          return .oneOf
        case .matchesPattern: return .matchesPattern
        case .withinPast:     return .withinPast
        case .withinFuture:   return .withinFuture
        case .isEmpty:        return .isEmpty
        case .isNotEmpty:     return .isNotEmpty
        }
    }

    private func lowerLogicalOp(_ op: LogicalOpAST) -> LogicalOp {
        switch op {
        case .and: return .and
        case .or:  return .or
        case .not: return .not
        }
    }

    private func lowerWaitCondition(_ cond: WaitConditionAST) throws -> WaitConditionIR {
        switch cond {
        case .duration(let v, let unit):
            return .duration(Duration.seconds(Int64(v * Double(unit.inSeconds))))
        case .signal(let id):
            return .signal(id)
        case .approval(let subj, let role):
            return .approval(of: try lowerExpr(subj), by: role)
        case .event(let id, let matching):
            return .event(id, matching: try matching.map { try lowerExpr($0) })
        case .choice(let prompt, let options):
            return .choice(prompt: prompt, options: options)
        }
    }

    // MARK: - 3A/3B/3C. Relations, verbs, descriptions

    private func semanticError(_ message: String, _ line: Int) -> CompilerError {
        CompilerError.semanticError(message: message, range: sourceRange(line))
    }

    /// Validate the relational layer once per file. Backing is mandatory for any
    /// relation that is *used* relationally — i.e. referenced by a declared verb
    /// (every relational surface form goes through a verb). A bare legacy
    /// relation with no verb and no backing is left untouched for compatibility.
    /// Any backing that IS declared must be well-formed (a real side + property,
    /// or a declared tool); every verb must map to a declared, backed relation;
    /// and no conjugated verb form may be shared by two relations.
    func validateRelationsAndVerbs() throws {
        for (name, backing) in symbols.relationBackings.sorted(by: { $0.key < $1.key }) {
            guard let rel = symbols.relation(named: name) else {
                throw semanticError(
                    "evaluation backing names relation \"\(name)\", which is not declared (write `\(name.capitalized) relates …` first).", 0)
            }
            try validateBacking(backing, of: rel)
        }
        var formOwner: [String: String] = [:]
        for v in symbols.verbs.values.sorted(by: { $0.base < $1.base }) {
            guard let rel = symbols.relation(named: v.relation) else {
                throw semanticError(
                    "verb `to \(v.base)` means the \(v.relation) relation, which is not declared.",
                    v.sourceLine)
            }
            guard symbols.backing(forRelation: v.relation) != nil else {
                throw semanticError(
                    "verb `to \(v.base)` means the \(v.relation) relation, which has no evaluation backing. Add `\(rel.verb.capitalized) is read from the <kind>'s <property>.` or `\(rel.verb.capitalized) is read via the <tool> tool.`",
                    v.sourceLine)
            }
            for form in [v.base, v.thirdPerson, v.pastParticiple] {
                let f = form.lowercased()
                if let other = formOwner[f], other != v.relation {
                    throw semanticError(
                        "verb form \"\(form)\" is ambiguous between the \(other) and \(v.relation) relations.",
                        v.sourceLine)
                }
                formOwner[f] = v.relation
            }
        }
    }

    private func validateBacking(_ backing: RelationBackingAST, of rel: RelationDeclaration) throws {
        switch backing {
        case .property(let kind, let path):
            let k = kind.lowercased()
            guard k == rel.leftKind.lowercased() || k == rel.rightKind.lowercased() else {
                throw semanticError(
                    "relation \"\(rel.verb)\" is read from `\(kind)`, which is not one of its kinds (`\(rel.leftKind)`, `\(rel.rightKind)`).",
                    rel.sourceLine)
            }
            let props = symbols.propertyNames(of: k)
            if !props.isEmpty && !props.contains(path.lowercased()) {
                throw semanticError(
                    "relation \"\(rel.verb)\" reads `\(kind).\(path)`, but `\(kind)` has no declared property `\(path)`.",
                    rel.sourceLine)
            }
        case .tool(let toolID):
            guard symbols.tool(named: toolID) != nil else {
                throw semanticError(
                    "relation \"\(rel.verb)\" is read via tool `\(toolID)`, which is not declared in the vocabulary.",
                    rel.sourceLine)
            }
        }
    }

    /// The relation side that is not `elementKind` (used to key a tool-backed
    /// fetch by the fixed operand's kind, and to check scalar-nav cardinality).
    private func otherSide(of rel: RelationDeclaration, fromElementKind elementKind: String)
        -> (kind: String, cardinality: CardinalityAST) {
        if elementKind.lowercased() == rel.leftKind.lowercased() {
            return (rel.rightKind, rel.rightCardinality)
        }
        return (rel.leftKind, rel.leftCardinality)
    }

    /// 3B/3C: a relation operand must resolve to an in-scope name (a workflow
    /// parameter, an earlier bind, or an enclosing loop variable). Runs only when
    /// `scope` is known; constants/instances/literals/enum-cases contribute no
    /// free identifier roots, so they always pass.
    private func validateOperandScope(_ operand: IRExpression, scope: Set<String>?,
                                      role: String, line: Int) throws {
        guard let scope else { return }
        for root in freeIdentifierRoots(operand) where !scope.contains(scopeKey(root)) {
            let known = scope.sorted().joined(separator: ", ")
            throw semanticError(
                "\(role) references \"\(root)\", which is not in scope. In-scope names: [\(known)]. Reference a workflow parameter or an earlier bind.",
                line)
        }
    }

    /// 3B: a " (did you mean …?)" hint for an unknown verb form, or "" when no
    /// declared form is close enough.
    private func nearestVerbSuggestion(_ form: String) -> String {
        symbols.nearestVerbForm(to: form).map { " (did you mean \"\($0)\"?)" } ?? ""
    }

    /// 3B: lower an active verb condition (`the user owns the page`) to a
    /// property-backed `identifies` comparison. Tool-backed verbs can't be tested
    /// inline (they need an `await` fetch) — bind the related set first.
    private func lowerVerbPredicate(subject: ExpressionAST, verbForm: String,
                                    object: ExpressionAST, scope: Set<String>? = nil,
                                    line: Int) throws -> IRExpression {
        guard let resolved = symbols.resolveVerbForm(verbForm) else {
            throw semanticError("unknown verb \"\(verbForm)\"\(nearestVerbSuggestion(verbForm)). Declare it with `The verb to <base> (it <3rd>, it is <participle>) means the <relation> relation.`", line)
        }
        let relName = resolved.verb.relation
        guard let rel = symbols.relation(named: relName),
              let backing = symbols.backing(forRelation: relName) else {
            throw semanticError("relation \"\(relName)\" for verb \"\(verbForm)\" is undeclared or unbacked.", line)
        }
        switch backing {
        case .property(let bKind, let path):
            let subjIR = try lowerExpr(subject, scope: scope, line: line)
            let objIR = try lowerExpr(object, scope: scope, line: line)
            try validateOperandScope(subjIR, scope: scope, role: "verb subject", line: line)
            try validateOperandScope(objIR, scope: scope, role: "verb object", line: line)
            let bk = bKind.lowercased()
            if bk == rel.rightKind.lowercased() {
                return .comparison(.propertyAccess(objIR, propertyName: path), .identifies, subjIR)
            } else if bk == rel.leftKind.lowercased() {
                return .comparison(.propertyAccess(subjIR, propertyName: path), .identifies, objIR)
            }
            throw semanticError("relation backing kind `\(bKind)` is not a side of relation \"\(relName)\".", line)
        case .tool:
            throw semanticError("verb \"\(verbForm)\" is tool-backed and cannot be tested inline. Bind the related set first (e.g. `let related be \(rel.leftKind.lowercased())s that \(resolved.verb.thirdPerson) …`).", line)
        }
    }

    struct ScalarNavPlan { let expr: IRExpression; let prelude: [IRPrimitive] }

    /// 3C: lower scalar relation navigation (`the task assigned to the user`,
    /// navigating TO `navKind`) to a single related value. Property-backed → a
    /// `member` read from the operand. Tool-backed → a single fetch-once `invoke`
    /// (hoisted into `prelude` when `allowToolFetch`), whose result IS the related
    /// value (a one-to-one tool returns the entity, not a list). The navigated-to
    /// side must be `one` — a `various` side needs `the list of …`.
    private func lowerScalarTraversalPlan(base: ExpressionAST, relationForm: String, navKind: String,
                                          allowToolFetch: Bool, scope: Set<String>? = nil,
                                          line: Int) throws -> ScalarNavPlan {
        guard let resolved = symbols.resolveVerbForm(relationForm) else {
            throw semanticError("unknown relation form \"\(relationForm)\"\(nearestVerbSuggestion(relationForm)) in navigation.", line)
        }
        let relName = resolved.verb.relation
        guard let rel = symbols.relation(named: relName),
              let backing = symbols.backing(forRelation: relName) else {
            throw semanticError("relation \"\(relName)\" for \"\(relationForm)\" is undeclared or unbacked.", line)
        }
        // The navigated-to side must not be `various` (use `the list of …`).
        let navCardinality: CardinalityAST =
            navKind.lowercased() == rel.leftKind.lowercased() ? rel.leftCardinality : rel.rightCardinality
        if case .many = navCardinality {
            throw semanticError("relation \"\(relName)\" relates to various \(navKind)s; navigate it with `the list of …`, not scalar `the \(navKind)`.", line)
        }
        let baseIR = try lowerExpr(base, scope: scope, line: line)
        try validateOperandScope(baseIR, scope: scope, role: "navigation operand", line: line)
        switch backing {
        case .property(_, let path):
            return ScalarNavPlan(expr: .propertyAccess(baseIR, propertyName: path), prelude: [])
        case .tool(let toolID):
            guard allowToolFetch else {
                throw semanticError("tool-backed relation \"\(relName)\" cannot be navigated in an inline expression; bind it first (e.g. `let result be the \(navKind) \(relationForm) …`).", line)
            }
            // The operand is the side that is NOT navKind; key the invoke by it.
            let operandKind = navKind.lowercased() == rel.leftKind.lowercased() ? rel.rightKind : rel.leftKind
            let synth = "__nav\(pascalCase(navKind))"
            let resolvedID = symbols.tool(named: toolID)?.methodName ?? toolID
            let invoke = InvokeIR(
                toolID: resolvedID,
                arguments: [InvokeArg(camelCase(operandKind), baseIR)],
                resultBinding: synth,
                sourceRange: sourceRange(line))
            return ScalarNavPlan(expr: .identifierRef(name: synth), prelude: [.invoke(invoke)])
        }
    }

    struct DescriptionPlan { let ir: DescriptionIR; let prelude: [IRPrimitive] }

    /// 3C: lower a description to a fetch-once + filter + sort + take plan. A
    /// single tool-backed verb clause becomes the source (a hoisted `invoke`,
    /// returned in `prelude`); property-backed clauses, adjectives, and `whose`
    /// become element-context filters. `allowToolFetch` is false in value/condition
    /// positions that cannot host the `await` fetch.
    private func lowerDescriptionPlan(_ d: DescriptionAST, allowToolFetch: Bool,
                                      scope: Set<String>? = nil, line: Int) throws -> DescriptionPlan {
        let noun = d.noun.trimmingCharacters(in: .whitespaces)
        guard !noun.isEmpty else {
            throw semanticError("description is missing a collection noun.", line)
        }
        let elementVar = lexicon.singularize(noun.lowercased())

        var prelude: [IRPrimitive] = []
        var filters: [IRExpression] = []
        var toolSource: (verbForm: String, toolID: String, operandKey: String, operand: IRExpression)? = nil

        for clause in d.verbClauses {
            guard let resolved = symbols.resolveVerbForm(clause.verbForm) else {
                throw semanticError("unknown verb form \"\(clause.verbForm)\" in description.", line)
            }
            let relName = resolved.verb.relation
            guard let rel = symbols.relation(named: relName),
                  let backing = symbols.backing(forRelation: relName) else {
                throw semanticError("relation \"\(relName)\" for verb \"\(clause.verbForm)\" is undeclared or unbacked.", line)
            }
            let operandIR = try lowerExpr(clause.operand, scope: scope, line: line)
            try validateOperandScope(operandIR, scope: scope, role: "relation operand", line: line)
            switch backing {
            case .tool(let toolID):
                guard toolSource == nil else {
                    throw semanticError("a description may use at most one tool-backed relation clause.", line)
                }
                let other = otherSide(of: rel, fromElementKind: elementVar)
                let resolvedID = symbols.tool(named: toolID)?.methodName ?? toolID
                toolSource = (clause.verbForm, resolvedID, camelCase(other.kind), operandIR)
            case .property(let bKind, let path):
                guard bKind.lowercased() == elementVar.lowercased() else {
                    throw semanticError("property-backed relation \"\(relName)\" stores its link on `\(bKind)`, but the description iterates `\(elementVar)`. Use `the list of …` / scalar navigation, or back the relation with a tool, to traverse from a fixed entity.", line)
                }
                filters.append(.comparison(
                    .propertyAccess(.identifierRef(name: elementVar), propertyName: path),
                    .identifies, operandIR))
            }
        }

        let collection: IRExpression
        if let src = toolSource {
            guard allowToolFetch else {
                throw semanticError("a tool-backed relation (`\(src.verbForm)`) must be bound before use — e.g. `let matches be \(noun) that \(src.verbForm) …`, then read `matches`.", line)
            }
            let synth = "__rel\(camelCase(noun).prefix(1).uppercased())\(camelCase(noun).dropFirst())"
            prelude.append(.invoke(InvokeIR(
                toolID: src.toolID,
                arguments: [InvokeArg(src.operandKey, src.operand)],
                resultBinding: synth,
                sourceRange: sourceRange(line))))
            collection = .identifierRef(name: synth)
        } else {
            // Normalize the surface noun (singular in superlatives `the largest
            // deal`, plural in `the stale pages`) to the plural collection name
            // that the author binds in scope.
            let collectionName = lexicon.pluralize(elementVar)
            let c = try lowerExpr(.identifierRef(collectionName))
            if case .invocation = c {
                throw semanticError("description source must be a bound collection name (a parameter or earlier bind), not a tool call.", line)
            }
            collection = c
        }

        for adj in d.adjectives {
            filters.append(try resolveAdjectiveFilter(
                adjective: adj, subject: .identifierRef(name: elementVar), sourceLine: line))
        }
        if let wp = d.wherePredicate {
            filters.append(qualifyToLoopVar(try lowerExpr(wp), loopVar: elementVar))
        }

        let sort = d.sort.map { (path: camelCase($0.property), ascending: $0.ascending) }
        return DescriptionPlan(
            ir: DescriptionIR(collection: collection, elementVar: elementVar,
                              filters: filters, sort: sort, take: d.take),
            prelude: prelude)
    }

    // MARK: - Source range helper

    func sourceRange(_ line: Int) -> SourceRange {
        SourceRange(file: sourceFile, line: line, column: 0)
    }
}
