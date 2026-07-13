import Foundation
import MeridianRuntime

// MARK: - RuleInjector
// Applies parsed rules to lowered IR workflows.

struct RuleInjector {
    let symbols: SymbolTable
    let lexicon: EnglishLexicon
    let trace: ParserTrace
    /// Closure used to lower an action text as if it were a phrase invocation
    /// inside a workflow body. Trigger synthesis uses this to produce real
    /// IR for the action, instead of a stub comment. Injected to break the
    /// import cycle between RuleInjector and ASTToIR.
    let lowerAction: ((String, SourceRange) throws -> [IRPrimitive])?
    /// What kinds of resolution failure are tolerated (rather than thrown).
    /// Constructed by the lowerer from frontmatter + Compiler.Options.
    let fallbackPolicy: FallbackPolicy
    /// Source file used when constructing SourceRanges for diagnostics.
    let sourceFile: String
    let reportFallback: ((Diagnostic) -> Void)?
    /// Rules that parsed but did not attach to any workflow. Surfaced by
    /// the lowerer as a hard error (or warning, if the policy allows
    /// `unattached-rules`).
    private(set) var unattachedRules: [(rule: ParsedRule, reason: String)] = []

    init(
        symbols: SymbolTable,
        lexicon: EnglishLexicon = .default,
        trace: ParserTrace = .shared,
        lowerAction: ((String, SourceRange) throws -> [IRPrimitive])? = nil,
        fallbackPolicy: FallbackPolicy = .strict,
        sourceFile: String = "",
        reportFallback: ((Diagnostic) -> Void)? = nil
    ) {
        self.symbols = symbols
        self.lexicon = lexicon
        self.trace = trace
        self.lowerAction = lowerAction
        self.fallbackPolicy = fallbackPolicy
        self.sourceFile = sourceFile
        self.reportFallback = reportFallback
    }

    // MARK: - Injection

    mutating func inject(rules: [ParsedRule], into workflows: [IRWorkflow], sourceFile: String) throws -> [IRWorkflow] {
        var result = workflows

        // Track which rules attached to at least one workflow. Anything left
        // in `unattached` after the pass is reported as a warning or hard
        // error depending on the fallback policy.
        var attached: Set<Int> = []
        for (rIdx, rule) in rules.enumerated() {
            for idx in result.indices {
                let workflow = result[idx]
                var prepended: [IRPrimitive] = []
                var insertGateAtZero: IRPrimitive?

                switch rule {
                case .invariant(let kind, let filter, let actionText, let sourceLine, let originalText):
                    if verbAndSubjectMatch(actionText: actionText, subjectKind: kind, workflow: workflow) {
                        if let cond = try buildInvariantCondition(
                            filter: filter,
                            sourceRange: SourceRange(file: sourceFile, line: sourceLine, column: 0)
                        ) {
                            prepended.append(.assert(AssertIR(
                                condition: cond,
                                message: originalText,
                                otherwiseAction: nil,
                                sourceRange: SourceRange(file: sourceFile, line: sourceLine, column: 0)
                            )))
                            attached.insert(rIdx)
                        }
                    }

                case .parameterGuard(let kind, let actionText, let predicate, let sourceLine, let originalText):
                    if verbAndSubjectMatch(actionText: actionText, subjectKind: kind, workflow: workflow) {
                        let sr = SourceRange(file: sourceFile, line: sourceLine, column: 0)
                        let negated = IRExpression.logical(.not, [try lowerExprSimple(predicate, sourceRange: sr)])
                        prepended.append(.assert(AssertIR(
                            condition: negated,
                            message: originalText,
                            otherwiseAction: nil,
                            sourceRange: sr
                        )))
                        attached.insert(rIdx)
                    }

                case .precondition(let kind, let filter, _, let gate, let sourceLine, _):
                    // Preconditions match by SUBJECT KIND alone — the rule's
                    // action is implicit ("before X" applies to any workflow
                    // that handles the subject). Verb overlap is not required.
                    //
                    // The subjectFilter (if any) gates the wait — we only
                    // wait when the filter holds. Without this gating the
                    // wait would fire on every invocation, blocking workflows
                    // that the rule wasn't supposed to touch.
                    //
                    // SAFETY: if the workflow body already contains an
                    // approval step (a WaitIR(.approval) or a sub-workflow
                    // call whose name suggests approval), we skip injection.
                    // The rule is still recorded in the manifest as
                    // documentation. Without this guard, a workflow that
                    // already handles approval would deadlock waiting for a
                    // duplicate runtime approval that the host never delivers.
                    if hasParameter(of: kind, in: workflow) {
                        if workflowAlreadyHandlesApproval(workflow.body) {
                            trace.log(.lowering, "precondition L\(sourceLine): workflow '\(workflow.name)' already handles approval; recording rule in manifest only")
                            trace.log(.lowering, "rule matrix L\(sourceLine) precondition x '\(workflow.name)': skip (approval handled)")
                            attached.insert(rIdx)
                            continue
                        }
                        if let waitIR = buildPreconditionWait(
                            gate: gate, workflow: workflow,
                            sourceLine: sourceLine, sourceFile: sourceFile
                        ) {
                            let sr = SourceRange(file: sourceFile, line: sourceLine, column: 0)
                            if let filter = filter {
                                let cond = try lowerExprSimple(filter, sourceRange: sr)
                                let then = IRBlock(statements: [.wait(waitIR)], sourceRange: sr)
                                prepended.append(.branch(BranchIR(
                                    condition: .predicate(cond),
                                    thenBlock: then,
                                    elseBlock: nil,
                                    sourceRange: sr
                                )))
                            } else {
                                prepended.append(.wait(waitIR))
                            }
                            attached.insert(rIdx)
                        }
                    }

                case .trigger, .unsupportedTriggerCondition:
                    break  // synthesised (or rejected) separately by synthesizeTriggers

                case .deonticProhibition, .deonticObligation, .deonticPermission:
                    attached.insert(rIdx)

                case .permission(let kind, _, let allowedAction, let conditions, let isBounded, let sourceLine, let originalText):
                    // Permissions match by either:
                    //   - actor + verb (rule subject is the actor, workflow takes
                    //     that actor as a parameter, and the verbs overlap), OR
                    //   - object + verb (the action mentions a noun that matches
                    //     a workflow parameter; e.g. "may approve any order"
                    //     matches a workflow that operates on an order).
                    if permissionMatches(actorKind: kind, allowedAction: allowedAction, workflow: workflow) {
                        if isBounded, let conditions = conditions {
                            let sr = SourceRange(file: sourceFile, line: sourceLine, column: 0)
                            let gateExpr = try lowerExprSimple(conditions, sourceRange: sr)
                            guard isPlausibleGateCondition(gateExpr) else {
                                throw CompilerError.diagnostics([
                                    Diagnostic.error(
                                        .unlowerableRulePredicate,
                                        message: "bounded permission's clause has no comparison to check: \"\(originalText)\"",
                                        range: sr,
                                        help: "The clause after \"up to\"/\"whose\"/\"if\" must be a real comparison against a property (e.g. \"whose queue position is at most 3\"), not a bare number or bare value — a bare bound has no meaningful truthiness and would silently gate as always-true instead of actually enforcing the cap.")
                                ])
                            }
                            insertGateAtZero = .assert(AssertIR(
                                condition: gateExpr,
                                message: "Permission required: \(originalText)",
                                otherwiseAction: nil,
                                sourceRange: sr
                            ))
                        }
                        attached.insert(rIdx)
                    }
                }

                let (ruleLine, ruleKind) = ruleTraceLabel(rule)
                let attachedHere = !prepended.isEmpty || insertGateAtZero != nil
                trace.log(.lowering,
                          "rule matrix L\(ruleLine) \(ruleKind) x '\(workflow.name)': \(attachedHere ? "attach" : "skip")")

                if !prepended.isEmpty || insertGateAtZero != nil {
                    var stmts = result[idx].body.statements
                    stmts = prepended + stmts
                    if let g = insertGateAtZero { stmts.insert(g, at: 0) }
                    let newBody = IRBlock(statements: stmts, sourceRange: result[idx].body.sourceRange)
                    result[idx] = IRWorkflow(
                        name: result[idx].name,
                        parameters: result[idx].parameters,
                        body: newBody,
                        mode: result[idx].mode,
                        sourceFile: result[idx].sourceFile,
                        sourceRange: result[idx].sourceRange,
                        explicitStructName: result[idx].explicitStructName,
                        allowsDiscretion: result[idx].allowsDiscretion
                    )
                }
            }
        }

        // Anything that didn't attach (and isn't a trigger, which doesn't need
        // a workflow target) goes into unattachedRules for diagnostic surfacing.
        for (rIdx, rule) in rules.enumerated() where !attached.contains(rIdx) {
            if case .trigger = rule { continue }
            if case .unsupportedTriggerCondition = rule { continue }
            if case .deonticProhibition = rule { continue }
            if case .deonticObligation = rule { continue }
            if case .deonticPermission = rule { continue }
            unattachedRules.append((rule, "no workflow matched the rule's action"))
        }

        result = try applyPermissions(rules: rules, to: result, sourceFile: sourceFile)
        return result
    }

    // MARK: - Trigger synthesis

    func synthesizeTriggers(_ rules: [ParsedRule], sourceFile: String) throws -> [IRWorkflow] {
        var triggers: [IRWorkflow] = []
        for rule in rules {
            switch rule {
            case .trigger(let conditionText, let actionText, let sourceLine, _):
                triggers.append(
                    try buildTriggerWorkflow(
                        conditionText: conditionText,
                        actionText: actionText,
                        sourceLine: sourceLine,
                        sourceFile: sourceFile
                    )
                )
            case .unsupportedTriggerCondition(let conditionText, _, let sourceLine, let originalText):
                // See `RuleAnalyzer.isSelfEvaluatingTriggerCondition`: this
                // condition names a real, checkable predicate that
                // `buildTriggerWorkflow`'s external-event stub has no
                // scheduler/poller to re-evaluate — synthesizing it anyway
                // would silently mint a `trigger.<opaque>.fired` event that
                // no host ever raises. Always thrown; not gated behind any
                // `allow-fallbacks` token, matching `MER3016`'s treatment of
                // other unsupported rule-predicate shapes.
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .unsupportedTriggerCondition,
                        message: "when rule condition is self-evaluating and cannot be compiled as an external trigger: \"\(conditionText)\"",
                        range: SourceRange(file: sourceFile, line: sourceLine, column: 0),
                        help: "This `When …, …` rule cannot compile as-is — a `When` trigger only ever compiles to an external-event stub with no scheduler to re-check a self-evaluating condition. Delete this rule line and pick one of two fixes: (1) if the condition is something Meridian can check itself right now (a comparison, duration/age check, quantifier, etc.), move the check into the skill's own `## Workflow` (or `## Rules`) body as a real `if …`/`assert …`/`wait until …` statement — do NOT just swap the word `When` for `wait until` in place, since a bare rule line is not a workflow statement; or (2) if this is meant to react to a real external event, reword \"\(originalText)\" so the condition itself is an opaque event/signal phrase a host raises (e.g. \"a refund is requested\", \"payment clears\") and keep it as a `When …, …` trigger. Worked example (fix 2, renaming a duration check to an opaque event): `When an order has been on hold for more than 7 days, escalate the order.` → `When an order is flagged as stale, escalate the order.` Worked example (fix 1, polling a duration live): `## Workflow` `while any orders whose hold duration is more than 7 days, for each order whose hold duration is more than 7 days: escalate the order. wait 1 hour.` — the same shape as `corpora/incident/skills/cooldownwatch.meri`'s `while any alerts whose status is \"firing\", for each alert …` loop.")
                ])
            default:
                continue
            }
        }
        return triggers
    }

    // MARK: - Permission softening

    private func applyPermissions(rules: [ParsedRule], to workflows: [IRWorkflow], sourceFile: String) throws -> [IRWorkflow] {
        let permissions = rules.compactMap { rule -> ParsedRule? in
            if case .permission = rule { return rule } else { return nil }
        }
        guard !permissions.isEmpty else { return workflows }

        return try workflows.map { workflow in
            var changed = false
            let newStatements = try workflow.body.statements.map { stmt -> IRPrimitive in
                guard case .assert(let assertIR) = stmt else { return stmt }
                var softened: [IRExpression] = []
                for case .permission(let kind, let filter, let allowedAction, let conditions, _, let sourceLine, let originalText) in permissions {
                    guard permissionMatches(actorKind: kind, allowedAction: allowedAction, workflow: workflow) else { continue }
                    let sr = SourceRange(file: sourceFile, line: sourceLine, column: 0)
                    var parts: [IRExpression] = []
                    if let f = filter { parts.append(try lowerExprSimple(f, sourceRange: sr)) }
                    if let c = conditions {
                        let condExpr = try lowerExprSimple(c, sourceRange: sr)
                        guard isPlausibleGateCondition(condExpr) else {
                            throw CompilerError.diagnostics([
                                Diagnostic.error(
                                    .unlowerableRulePredicate,
                                    message: "bounded permission's clause has no comparison to check: \"\(originalText)\"",
                                    range: sr,
                                    help: "The clause after \"up to\"/\"whose\"/\"if\" must be a real comparison against a property (e.g. \"whose queue position is at most 3\"), not a bare number or bare value.")
                            ])
                        }
                        parts.append(condExpr)
                    }
                    if parts.isEmpty { softened.append(.literal(.boolean(true))); continue }
                    softened.append(parts.count == 1 ? parts[0] : .logical(.and, parts))
                }
                guard !softened.isEmpty else { return stmt }
                changed = true
                let permOrExpr: IRExpression = softened.count == 1
                    ? softened[0]
                    : .logical(.or, softened)
                let softenedAssert = AssertIR(
                    condition: .logical(.or, [assertIR.condition, permOrExpr]),
                    message: assertIR.message,
                    otherwiseAction: assertIR.otherwiseAction,
                    sourceRange: assertIR.sourceRange
                )
                return .assert(softenedAssert)
            }
            guard changed else { return workflow }
            let newBody = IRBlock(statements: newStatements, sourceRange: workflow.body.sourceRange)
            return IRWorkflow(
                name: workflow.name,
                parameters: workflow.parameters,
                body: newBody,
                mode: workflow.mode,
                sourceFile: workflow.sourceFile,
                sourceRange: workflow.sourceRange,
                explicitStructName: workflow.explicitStructName,
                allowsDiscretion: workflow.allowsDiscretion
            )
        }
    }

    // MARK: - Helpers

    /// Decide whether a rule with both a subject kind and an action verb
    /// applies to a given workflow. Both signals are required, because
    /// neither alone is reliable:
    ///
    /// - **Subject kind alone is too weak:** a rule
    ///   `"a customer must not place orders"` would otherwise attach to
    ///   `"escalate an order"` simply because that workflow takes a
    ///   `customer` parameter.
    /// - **Verb overlap alone is too weak:** a rule
    ///   `"a customer must not place orders"` would otherwise attach to a
    ///   workflow `"place a comment"` just because both contain "place".
    ///
    /// We require:
    ///   1. The workflow declares a parameter whose kind (after stemming)
    ///      matches the rule's subjectKind, AND
    ///   2. At least one stem of the rule's action verb tokens appears in
    ///      the workflow's name tokens.
    private func verbAndSubjectMatch(actionText: String, subjectKind: String, workflow: IRWorkflow) -> Bool {
        guard hasParameter(of: subjectKind, in: workflow) else { return false }
        return verbOverlap(actionText, workflow: workflow) >= 1
    }

    /// Permission-matching: does this workflow correspond to the action that
    /// the actor is permitted to perform? Matches if either:
    ///   - the workflow takes the actor as a parameter and verbs overlap, OR
    ///   - the action's object kind (e.g. `"any order"` → `"order"`) matches
    ///     a workflow parameter and the action's verb is in the workflow name.
    private func permissionMatches(actorKind: String, allowedAction: String, workflow: IRWorkflow) -> Bool {
        // Path 1: actor-driven match.
        if verbAndSubjectMatch(actionText: allowedAction, subjectKind: actorKind, workflow: workflow) {
            return true
        }
        // Path 2: object-driven match. Pull the noun out of the action text.
        let objectKind = extractObjectKindForPermission(allowedAction)
        if !objectKind.isEmpty,
           hasParameter(of: objectKind, in: workflow) {
            return verbOverlap(allowedAction, workflow: workflow) >= 1
        }
        return false
    }

    /// Best-effort noun extraction from a permission action text.
    /// `"approve any order"` → `"order"`, `"approve orders"` → `"orders"`,
    /// `"escalate the order"` → `"order"`.
    private func extractObjectKindForPermission(_ text: String) -> String {
        ObjectKindExtractor(lexicon: lexicon).extract(from: text, noArticleFallback: .lastWord)
    }

    /// Count how many stems of the rule's action verb tokens appear in the
    /// workflow's display-name tokens. Stop-words and the subject's own
    /// kind tokens are filtered out so they don't inflate overlap.
    private func verbOverlap(_ actionText: String, workflow: IRWorkflow) -> Int {
        WorkflowActionMatcher.actionStemOverlap(action: actionText, workflow: workflow,
                                      scope: .nameOnly, lexicon: lexicon)
    }

    /// True when a workflow body already contains an approval step — either
    /// a `WaitIR(.approval)` directly or a tool/workflow call whose ID
    /// contains a lexicon `approvalToolIDSubstrings` cue. Used by
    /// precondition injection to avoid deadlocking on a duplicate runtime
    /// approval the host never delivers.
    private func workflowAlreadyHandlesApproval(_ block: IRBlock) -> Bool {
        for stmt in block.statements {
            switch stmt {
            case .wait(let w):
                if case .approval = w.condition { return true }
            case .invoke(let inv):
                let id = inv.toolID.lowercased()
                if lexicon.approvalToolIDSubstrings.contains(where: { id.contains($0) }) { return true }
            case .branch(let b):
                if workflowAlreadyHandlesApproval(b.thenBlock) { return true }
                if let e = b.elseBlock, workflowAlreadyHandlesApproval(e) { return true }
            case .iterate(let it):
                if workflowAlreadyHandlesApproval(it.body) { return true }
            case .recover(let r):
                if workflowAlreadyHandlesApproval(r.handler) { return true }
                if workflowAlreadyHandlesApproval(r.attachedTo) { return true }
            default: break
            }
        }
        return false
    }

    /// True when the workflow declares a parameter whose kind matches the
    /// supplied subject kind (case-insensitive, after tokenisation+stems).
    private func hasParameter(of subjectKind: String, in workflow: IRWorkflow) -> Bool {
        guard !subjectKind.isEmpty else { return false }
        let stopwords = lexicon.toolStopwords.union(lexicon.articles).union(lexicon.prepositions)
        let kindStems = Set(tokenize(subjectKind, stopwords: stopwords).flatMap { stems(of: $0) })
        guard !kindStems.isEmpty else { return false }
        for p in workflow.parameters {
            let paramStems = Set(tokenize(IdentifierNaming.decamelize(p.kind.name), stopwords: stopwords).flatMap { stems(of: $0) })
            if !kindStems.intersection(paramStems).isEmpty { return true }
        }
        return false
    }

    /// Shared lightweight stem expansion used by workflow/action matching.
    private func stems(of word: String) -> [String] { WordStemmer.stems(of: word) }

    private func tokenize(_ s: String, stopwords: Set<String>) -> [String] {
        WordStemmer.tokenize(s, stopwords: stopwords)
    }

    private func buildInvariantCondition(filter: ExpressionAST?, sourceRange: SourceRange) throws -> IRExpression? {
        guard let filter = filter else { return nil }
        return .logical(.not, [try lowerExprSimple(filter, sourceRange: sourceRange)])
    }

    private func buildPreconditionWait(
        gate: GateKind,
        workflow: IRWorkflow,
        sourceLine: Int,
        sourceFile: String
    ) -> WaitIR? {
        let sr = SourceRange(file: sourceFile, line: sourceLine, column: 0)
        switch gate {
        case .approval(let role):
            let subject: IRExpression = workflow.parameters.first
                .map { .identifierRef(name: $0.name) } ?? .literal(.string(""))
            return WaitIR(condition: .approval(of: subject, by: role), timeout: nil, sourceRange: sr)
        case .event(let named):
            return WaitIR(condition: .event(named, matching: nil), timeout: nil, sourceRange: sr)
        }
    }

    private func buildTriggerWorkflow(
        conditionText: String,
        actionText: String,
        sourceLine: Int,
        sourceFile: String
    ) throws -> IRWorkflow {
        let sr = SourceRange(file: sourceFile, line: sourceLine, column: 0)
        let stopwords = lexicon.toolStopwords.union(lexicon.articles).union(lexicon.prepositions)
        let condTokens = tokenize(conditionText, stopwords: stopwords)
        let eventName = camelCase(condTokens.prefix(5).joined(separator: " "))
        let actionEvent = "trigger." + eventName + ".fired"

        // Trigger workflow has no parameters because the wait condition is
        // an external event whose payload supplies the subjects at runtime.
        // We can't safely lower the action text into a typed workflow call
        // here (the subjects aren't bound in the trigger's scope), so we
        // emit a fan-out event instead. Hosts subscribe to
        // `trigger.<event>.fired` and dispatch the named action with their
        // own parameter resolution. The action text and target are recorded
        // in the manifest under `meridian_rules` for discoverability.
        //
        // We *validate* that the action text resolves to a known workflow
        // or phrase (using the same lookup the action lowerer uses). If it
        // doesn't, strict mode raises a hard error pointing at the rule's
        // source line. Hosts that want to skip this check can opt in via
        // `allow-fallbacks: unresolved-trigger-actions`.
        if let lower = lowerAction {
            do {
                _ = try lower(actionText, sr)
            } catch let error as CompilerError {
                // The action lowerer may throw a legacy `.semanticError` or a
                // modern `.diagnostics`. Project uniformly so the trigger
                // fallback works regardless of which form fired.
                let first = error.diagnostics.first
                let m = first?.message ?? "\(error)"
                let r = first?.primaryRange ?? sr
                if fallbackPolicy.allows(.unresolvedTriggerActions) {
                    trace.log(.lowering, "trigger action unresolved (allow-fallbacks: unresolved-trigger-actions): \(actionText) — \(m)")
                    reportFallback?(Diagnostic.warning(
                        .unresolvedTriggerAction,
                        message: "trigger action unresolved but allowed by fallback: \"\(actionText)\". \(m)",
                        range: r,
                        help: "Add a matching workflow/phrase when possible; keep `allow-fallbacks: unresolved-trigger-actions` only while authoring."))
                } else {
                    throw CompilerError.diagnostics([
                        Diagnostic.error(
                            .unresolvedTriggerAction,
                            message: "trigger action does not resolve: \"\(actionText)\". \(m)",
                            range: r,
                            help: "Add a matching workflow/phrase, or set frontmatter `allow-fallbacks: unresolved-trigger-actions` to skip this check.")
                    ])
                }
            }
        }

        return TriggerWorkflowBuilder.make(
            name: "when " + conditionText,
            waitEvent: eventName,
            fireEventID: actionEvent,
            payload: [
                EmitField("action", .literal(.string(actionText))),
                EmitField("condition", .literal(.string(conditionText)))
            ],
            sourceFile: sourceFile,
            line: sourceLine
        )
    }

    /// A bounded permission's clause (`up to N`, `whose …`, `if …`) must lower
    /// to something with actual truthiness once evaluated — a bare literal
    /// like `.literal(.number(3))` (from a mis-worded `"up to 3 <plural noun>"`
    /// with no comparison) is never false, so inserting it directly as a gate
    /// `assert` would silently compile as an always-true no-op instead of
    /// enforcing anything. Property access, comparisons, logical combinations,
    /// invocations, and boolean literals are all legitimate truthiness checks
    /// (bare property access is the same "assert checks truthiness" convention
    /// `buildSubjectFilter`'s single-token fallback already relies on); only a
    /// bare non-boolean literal is rejected.
    private func isPlausibleGateCondition(_ expr: IRExpression) -> Bool {
        if case .literal(let lit) = expr, case .boolean = lit { return true }
        if case .literal = expr { return false }
        return true
    }

    // MARK: - Simple expression lowering (rule predicates only)
    // Intentionally avoids symbol-table lookups so rule predicates are
    // lowered without side-effects on the symbol table.

    /// Rule predicates lower a constrained subset of `ExpressionAST` — the
    /// shapes a boolean condition can actually take (literals, identifiers,
    /// comparisons, logical combinations, property access, invokes,
    /// interpolation, discretion). Quantifiers, relational traversals,
    /// descriptions/aggregates/superlatives, data tables, and parse-error
    /// carriers are NOT silently coerced to `false` (that would make a rule
    /// silently never fire) — they raise `MER3016` instead. `RuleAnalyzer`'s
    /// `ExpressionParser` now carries the real `SymbolTable` in every
    /// production call site (see `RuleAnalyzer.init`), so
    /// `.description`/`.aggregate`/`.superlative`/`.relationTraversal`/
    /// `.verbPredicate` ARE reachable here — a rule filter/predicate/condition
    /// shaped like a relation traversal over a declared verb (e.g. "active
    /// prescriptions include a contraindicated drug") now surfaces as its
    /// real `ExpressionAST` form instead of degrading to a bare identifier or
    /// a plausible-looking-but-wrong shorthand comparison (`corpora/
    /// GENERATING_A_CORPUS.md` gotcha #7). `.recordList` is still never
    /// produced by `ExpressionParser.parse`. All nine forms still raise so a
    /// rich shape is recognized and rejected loudly, never silently accepted
    /// as a meaningless predicate or coerced to `false`.
    private func lowerExprSimple(_ expr: ExpressionAST, sourceRange: SourceRange) throws -> IRExpression {
        switch expr {
        case .literal(let lit):
            return lowerLiteralSimple(lit)
        case .identifierRef(let n):
            // Mirror ASTToIR.lowerExpr: bare identifiers that match a known
            // enum case lower to a string literal so `state.get("status") ==
            // "suspended"` actually compares against the enum's raw value.
            // Constants / instances follow the same rule for symmetry.
            let lower = n.lowercased().trimmingCharacters(in: .whitespaces)
            if symbols.constants[lower] != nil { return .constantRef(name: lower) }
            if symbols.instances[lower] != nil { return .instanceRef(name: lower) }
            if symbols.enumCases.contains(lower) { return .literal(.string(lower)) }
            // Mirror ASTToIR.lowerExpr: multi-word identifiers (e.g. a rule
            // subject/object kind like "medication order") become camelCase
            // so `state.get(...)` reads the same key the workflow bound the
            // parameter under (`medicationOrder`), not a literal space that
            // can never match a binding.
            return .identifierRef(name: IdentifierNaming.camelPreservingCase(lower))
        case .propertyAccess(let b, let p):
            return .propertyAccess(try lowerExprSimple(b, sourceRange: sourceRange), propertyName: p)
        case .comparison(let l, let op, let r):
            return .comparison(
                try lowerExprSimple(l, sourceRange: sourceRange),
                lowerOpSimple(op),
                try lowerExprSimple(r, sourceRange: sourceRange))
        case .logical(let op, let exprs):
            return .logical(lowerLogicalOpSimple(op), try exprs.map { try lowerExprSimple($0, sourceRange: sourceRange) })
        case .envVar(let n):
            return .envVar(name: n)
        case .now:
            return .nowExpression
        case .instanceRef(let n):
            return .instanceRef(name: n)
        case .constantRef(let n):
            return .constantRef(name: n)
        case .invoke(let tool, let args):
            return .invocation(InvokeIR(
                toolID: tool,
                arguments: try args.map { InvokeArg($0.0, try lowerExprSimple($0.1, sourceRange: sourceRange)) }
            ))
        case .interpolatedString(let segs):
            return .interpolatedString(try segs.map { seg in
                try lowerInterpolationSegmentSimple(seg, sourceRange: sourceRange)
            })
        case .decideWhether(let q):
            return .invocation(InvokeIR(
                toolID: "runtime.discretion.decide",
                arguments: [InvokeArg("question", .literal(.string(q)))]
            ))
        case .quantified, .malformed, .recordList, .tableLookup,
             .eventPattern, .traceTemporal, .traceStatistical,
             .verbPredicate, .relationTraversal, .description, .aggregate, .superlative:
            throw CompilerError.diagnostics([
                Diagnostic.error(
                    .unlowerableRulePredicate,
                    message: "rule predicate uses an expression form a rule body cannot express (\(expr.traceDescription(detail: .compact)))",
                    range: sourceRange,
                    help: "If the check can be restated as a direct comparison, boolean combination (and/or/not), property access, or checkable adjective, rewrite the rule's condition that way. Quantifiers, relation traversals, descriptions, aggregates, superlatives, and data tables are permanently unsupported inside a rule's filter/predicate/conditions — this is not a temporary gap. If the check genuinely needs one of those forms, it cannot be expressed as an in-section rule at all: remove this rule line and add an equivalent `if`/`assert …`/`for each` statement to the skill's own `## Workflow` (or `## Rules`) body instead, where the full expression grammar has no restriction. Worked example: `A patient whose active prescriptions include a contraindicated drug must not receive the new order.` (a relation traversal — unsupported here) → `## Workflow` `if any of the patient's active prescriptions is contraindicated: stop with \"cannot administer: contraindicated prescription\".` — the same `if any of … is …` quantifier shape `corpora/clinical/skills/triagepatient.meri` already uses (`if any of the vital signs is critical, escalate the patient.`).")
            ])
        }
    }

    private func lowerLiteralSimple(_ lit: LiteralAST) -> IRExpression { .literal(LiteralLowering.toIRLiteral(lit)) }

    private func lowerInterpolationSegmentSimple(_ seg: InterpolationSegment, sourceRange: SourceRange) throws -> IRInterpolationSegment {
        switch seg {
        case .literal(let s): return .literal(s)
        case .expression(let e): return .expression(try lowerExprSimple(e, sourceRange: sourceRange))
        case .conditional(let c, let t, let o):
            return .conditional(
                condition: try lowerExprSimple(c, sourceRange: sourceRange),
                then: try t.map { try lowerInterpolationSegmentSimple($0, sourceRange: sourceRange) },
                otherwise: try o.map { try lowerInterpolationSegmentSimple($0, sourceRange: sourceRange) })
        case .forEach(let v, let c, let b):
            return .forEach(
                variable: v,
                collection: try lowerExprSimple(c, sourceRange: sourceRange),
                body: try b.map { try lowerInterpolationSegmentSimple($0, sourceRange: sourceRange) })
        case .formatted(let e, let f):
            guard FormatterRegistry.isValid(f) else {
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .unknownTemplateFormatter,
                        target: f,
                        among: FormatterRegistry.available,
                        range: sourceRange,
                        noun: "template formatter",
                        help: "Available formatters: \(FormatterRegistry.available.joined(separator: ", ")).")
                ])
            }
            return .formatted(try lowerExprSimple(e, sourceRange: sourceRange), formatter: f)
        }
    }

    private func lowerOpSimple(_ op: ComparisonOpAST) -> ComparisonOp { LiteralLowering.mapComparisonOp(op) }

    private func lowerLogicalOpSimple(_ op: LogicalOpAST) -> LogicalOp { LiteralLowering.mapLogicalOp(op) }

    private func camelCase(_ s: String) -> String { IdentifierNaming.camelPreservingCase(s) }

    private func ruleTraceLabel(_ rule: ParsedRule) -> (line: Int, kind: String) {
        switch rule {
        case .invariant(_, _, _, let line, _): return (line, "invariant")
        case .parameterGuard(_, _, _, let line, _): return (line, "parameterGuard")
        case .precondition(_, _, _, _, let line, _): return (line, "precondition")
        case .trigger(_, _, let line, _): return (line, "trigger")
        case .unsupportedTriggerCondition(_, _, let line, _): return (line, "unsupportedTriggerCondition")
        case .permission(_, _, _, _, _, let line, _): return (line, "permission")
        case .deonticProhibition(let norm): return (norm.sourceRange.startLine, "deonticProhibition")
        case .deonticObligation(let norm): return (norm.sourceRange.startLine, "deonticObligation")
        case .deonticPermission(let norm): return (norm.sourceRange.startLine, "deonticPermission")
        }
    }
}
