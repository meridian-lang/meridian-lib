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
        sourceFile: String = ""
    ) {
        self.symbols = symbols
        self.lexicon = lexicon
        self.trace = trace
        self.lowerAction = lowerAction
        self.fallbackPolicy = fallbackPolicy
        self.sourceFile = sourceFile
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
                        if let cond = buildInvariantCondition(filter: filter) {
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
                        let negated = IRExpression.logical(.not, [lowerExprSimple(predicate)])
                        prepended.append(.assert(AssertIR(
                            condition: negated,
                            message: originalText,
                            otherwiseAction: nil,
                            sourceRange: SourceRange(file: sourceFile, line: sourceLine, column: 0)
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
                            attached.insert(rIdx)
                            continue
                        }
                        if let waitIR = buildPreconditionWait(
                            gate: gate, workflow: workflow,
                            sourceLine: sourceLine, sourceFile: sourceFile
                        ) {
                            let sr = SourceRange(file: sourceFile, line: sourceLine, column: 0)
                            if let filter = filter {
                                let cond = lowerExprSimple(filter)
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

                case .trigger:
                    break  // synthesised separately as new workflows

                case .permission(let kind, _, let allowedAction, let conditions, let isBounded, let sourceLine, let originalText):
                    // Permissions match by either:
                    //   - actor + verb (rule subject is the actor, workflow takes
                    //     that actor as a parameter, and the verbs overlap), OR
                    //   - object + verb (the action mentions a noun that matches
                    //     a workflow parameter; e.g. "may approve any order"
                    //     matches a workflow that operates on an order).
                    if permissionMatches(actorKind: kind, allowedAction: allowedAction, workflow: workflow) {
                        if isBounded, let conditions = conditions {
                            let gateExpr = lowerExprSimple(conditions)
                            insertGateAtZero = .assert(AssertIR(
                                condition: gateExpr,
                                message: "Permission required: \(originalText)",
                                otherwiseAction: nil,
                                sourceRange: SourceRange(file: sourceFile, line: sourceLine, column: 0)
                            ))
                        }
                        attached.insert(rIdx)
                    }
                }

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
            unattachedRules.append((rule, "no workflow matched the rule's action"))
        }

        result = applyPermissions(rules: rules, to: result, sourceFile: sourceFile)
        return result
    }

    // MARK: - Trigger synthesis

    func synthesizeTriggers(_ rules: [ParsedRule], sourceFile: String) throws -> [IRWorkflow] {
        var triggers: [IRWorkflow] = []
        for rule in rules {
            guard case .trigger(let conditionText, let actionText, let sourceLine, _) = rule else { continue }
            triggers.append(
                try buildTriggerWorkflow(
                    conditionText: conditionText,
                    actionText: actionText,
                    sourceLine: sourceLine,
                    sourceFile: sourceFile
                )
            )
        }
        return triggers
    }

    // MARK: - Permission softening

    private func applyPermissions(rules: [ParsedRule], to workflows: [IRWorkflow], sourceFile: String) -> [IRWorkflow] {
        let permissions = rules.compactMap { rule -> ParsedRule? in
            if case .permission = rule { return rule } else { return nil }
        }
        guard !permissions.isEmpty else { return workflows }

        return workflows.map { workflow in
            var changed = false
            let newStatements = workflow.body.statements.map { stmt -> IRPrimitive in
                guard case .assert(let assertIR) = stmt else { return stmt }
                let softened = permissions.compactMap { perm -> IRExpression? in
                    guard case .permission(let kind, let filter, let allowedAction, let conditions, _, _, _) = perm else {
                        return nil
                    }
                    guard permissionMatches(actorKind: kind, allowedAction: allowedAction, workflow: workflow) else { return nil }
                    var parts: [IRExpression] = []
                    if let f = filter { parts.append(lowerExprSimple(f)) }
                    if let c = conditions { parts.append(lowerExprSimple(c)) }
                    if parts.isEmpty { return .literal(.boolean(true)) }
                    if parts.count == 1 { return parts[0] }
                    return .logical(.and, parts)
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
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        let words = lower.components(separatedBy: " ").filter { !$0.isEmpty }
        let articles: Set<String> = ["a", "an", "the", "any", "some", "all"]
        for (i, w) in words.enumerated() {
            if articles.contains(w), i + 1 < words.count {
                return words[(i + 1)...].joined(separator: " ")
            }
        }
        // No article — return the last word (heuristic: action verbs precede nouns).
        return words.last ?? ""
    }

    /// Count how many stems of the rule's action verb tokens appear in the
    /// workflow's display-name tokens. Stop-words and the subject's own
    /// kind tokens are filtered out so they don't inflate overlap.
    private func verbOverlap(_ actionText: String, workflow: IRWorkflow) -> Int {
        let stopwords = lexicon.toolStopwords.union(lexicon.articles).union(lexicon.prepositions)
        let actionTokens = Set(tokenize(actionText, stopwords: stopwords).flatMap { stems(of: $0) })
        let workflowTokens = Set(tokenize(workflow.name, stopwords: stopwords).flatMap { stems(of: $0) })
        return actionTokens.intersection(workflowTokens).count
    }

    /// True when a workflow body already contains an approval step — either
    /// a `WaitIR(.approval)` directly or a tool/workflow call whose name
    /// includes "approval" / "approve". Used by precondition injection to
    /// avoid deadlocking on a duplicate runtime approval the host never
    /// delivers.
    private func workflowAlreadyHandlesApproval(_ block: IRBlock) -> Bool {
        for stmt in block.statements {
            switch stmt {
            case .wait(let w):
                if case .approval = w.condition { return true }
            case .invoke(let inv):
                let id = inv.toolID.lowercased()
                if id.contains("approval") || id.contains("approve") { return true }
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
            let paramStems = Set(tokenize(p.kind.name, stopwords: stopwords).flatMap { stems(of: $0) })
            if !kindStems.intersection(paramStems).isEmpty { return true }
        }
        return false
    }

    /// Generate simple morphological stems for an English word.
    /// Strips well-known suffixes so `orders`, `ordered`, `ordering`, `order`
    /// all collapse onto the same stem set. We always include the original
    /// to keep exact matches working too.
    private func stems(of word: String) -> [String] {
        var out: [String] = [word]
        let lower = word.lowercased()
        // Plurals (cars → car, batches → batch, parties → party)
        if lower.hasSuffix("ies") && lower.count > 4 {
            out.append(String(lower.dropLast(3)) + "y")
        } else if lower.hasSuffix("es") && lower.count > 3 {
            out.append(String(lower.dropLast(2)))
        } else if lower.hasSuffix("s") && lower.count > 2 {
            out.append(String(lower.dropLast()))
        }
        // Past tense / progressive
        if lower.hasSuffix("ed") && lower.count > 3 {
            out.append(String(lower.dropLast(2)))     // placed → plac
            out.append(String(lower.dropLast()))      // placed → place (e-stem)
        }
        if lower.hasSuffix("ing") && lower.count > 4 {
            out.append(String(lower.dropLast(3)))     // placing → plac
            out.append(String(lower.dropLast(3)) + "e")  // placing → place
        }
        return out
    }

    private func tokenize(_ s: String, stopwords: Set<String>) -> [String] {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopwords.contains($0) }
    }

    private func buildInvariantCondition(filter: ExpressionAST?) -> IRExpression? {
        guard let filter = filter else { return nil }
        return .logical(.not, [lowerExprSimple(filter)])
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
        let waitIR = WaitIR(condition: .event(eventName, matching: nil), timeout: nil, sourceRange: sr)

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
            } catch let CompilerError.semanticError(message: m, range: r) {
                if fallbackPolicy.allows(.unresolvedTriggerActions) {
                    trace.log(.lowering, "trigger action unresolved (allow-fallbacks: unresolved-trigger-actions): \(actionText) — \(m)")
                } else {
                    throw CompilerError.semanticError(
                        message: "trigger action does not resolve: \"\(actionText)\". \(m). Add a matching workflow/phrase, or set frontmatter `allow-fallbacks: unresolved-trigger-actions` to skip this check.",
                        range: r
                    )
                }
            } catch {
                throw error
            }
        }

        let emitIR = EmitIR(
            eventID: actionEvent,
            payload: [
                EmitField("action", .literal(.string(actionText))),
                EmitField("condition", .literal(.string(conditionText)))
            ],
            strict: true,
            sourceRange: sr
        )
        let body = IRBlock(statements: [.wait(waitIR), .emit(emitIR)], sourceRange: sr)
        return IRWorkflow(
            name: "when " + conditionText,
            parameters: [],
            body: body,
            mode: .strict,
            sourceFile: sourceFile,
            sourceRange: sr
        )
    }

    // MARK: - Simple expression lowering (rule predicates only)
    // Intentionally avoids symbol-table lookups so rule predicates are
    // lowered without side-effects on the symbol table.

    private func lowerExprSimple(_ expr: ExpressionAST) -> IRExpression {
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
            return .identifierRef(name: n)
        case .propertyAccess(let b, let p):
            return .propertyAccess(lowerExprSimple(b), propertyName: p)
        case .comparison(let l, let op, let r):
            return .comparison(lowerExprSimple(l), lowerOpSimple(op), lowerExprSimple(r))
        case .logical(let op, let exprs):
            return .logical(lowerLogicalOpSimple(op), exprs.map { lowerExprSimple($0) })
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
                arguments: args.map { InvokeArg($0.0, lowerExprSimple($0.1)) }
            ))
        case .interpolatedString(let segs):
            return .interpolatedString(segs.map { seg -> IRInterpolationSegment in
                switch seg {
                case .literal(let s):    return .literal(s)
                case .expression(let e): return .expression(lowerExprSimple(e))
                }
            })
        case .decideWhether(let q):
            return .invocation(InvokeIR(
                toolID: "runtime.discretion.decide",
                arguments: [InvokeArg("question", .literal(.string(q)))]
            ))
        }
    }

    private func lowerLiteralSimple(_ lit: LiteralAST) -> IRExpression {
        switch lit {
        case .string(let s):        return .literal(.string(s))
        case .integer(let n):       return .literal(.number(Decimal(n)))
        case .double(let d):        return .literal(.number(Decimal(d)))
        case .boolean(let b):       return .literal(.boolean(b))
        case .money(let a, let c):  return .literal(.money(Decimal(a), currency: c))
        case .duration(let v, let u):
            return .literal(.duration(.seconds(Int64(v * Double(u.inSeconds)))))
        }
    }

    private func lowerOpSimple(_ op: ComparisonOpAST) -> ComparisonOp {
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

    private func lowerLogicalOpSimple(_ op: LogicalOpAST) -> LogicalOp {
        switch op {
        case .and: return .and
        case .or:  return .or
        case .not: return .not
        }
    }

    private func camelCase(_ s: String) -> String {
        let parts = s.split(whereSeparator: { $0 == " " || $0 == "_" }).map(String.init)
        guard let first = parts.first else { return s }
        return first + parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
}
