import Foundation
import MeridianRuntime

// Bind / rebind / note validation — extracted from ASTToIR for Phase 3 readability.

extension ASTToIR {

    // MARK: - Bind lowering

    func lowerBind(_ s: BindStatementAST, mode: ExecutionMode, depth: Int,
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

    func lowerRebind(_ s: RebindStatementAST, mode: ExecutionMode, depth: Int,
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

    /// INFORM7 §2.9 compound note form. `proceed, and note "<text>" in the
    /// <binding>` desugars to a `rebind` that appends the note text to the
    /// (already-declared, text-typed) binding via an interpolated string — no
    /// new IR primitive. The declared/text contract is enforced ahead of
    /// lowering by `validateNoteTargets` (MER-REF-004 / MER-TYP-001), so this
    /// only performs the deterministic append. The appended expression shape
    /// (`{{ binding }}<text>` where the interpolation references the same
    /// binding) is exactly what the Verbalizer recognizes to reprint the
    /// canonical note surface.
    func lowerNote(_ s: NoteStatementAST, scope: Set<String>? = nil) throws -> [IRPrimitive] {
        let bindName = camelCase(s.binding)
        let appended: IRExpression = .interpolatedString([
            .expression(.identifierRef(name: bindName)),
            .literal(s.text),
        ])
        return [.bind(BindIR(name: bindName, expression: appended, isRebind: true, sourceRange: sourceRange(s.sourceLine)))]
    }

    /// Enforce the compound note form's "already declared + text-typed" contract
    /// over a workflow body before lowering. Walks the AST in statement order
    /// tracking which bindings are declared and which of those are text-typed;
    /// block-bearing statements recurse with a scoped copy so sibling branches
    /// do not leak. Undeclared targets raise MER-REF-004; non-text targets raise
    /// MER-TYP-001.
    func validateNoteTargets(in block: ASTBlock, declared: Set<String>, textDeclared: Set<String>) throws {
        var declared = declared
        var textDeclared = textDeclared
        for stmt in block.statements {
            try validateNoteStmt(stmt, declared: &declared, textDeclared: &textDeclared)
        }
    }

    private func validateNoteStmt(_ stmt: StatementAST, declared: inout Set<String>, textDeclared: inout Set<String>) throws {
        switch stmt {
        case .note(let s):
            try checkNoteTarget(s, declared: declared, textDeclared: textDeclared)
        case .bind(let s):
            recordNoteBinding(s.name, value: s.value, declared: &declared, textDeclared: &textDeclared)
        case .rebind(let s):
            recordNoteBinding(s.name, value: s.value, declared: &declared, textDeclared: &textDeclared)
        case .conditional(let s):
            try validateNoteTargets(in: s.thenBlock, declared: declared, textDeclared: textDeclared)
            if let unknown = s.unknownBlock {
                try validateNoteTargets(in: unknown, declared: declared, textDeclared: textDeclared)
            }
            if let elseBlock = s.elseBlock {
                try validateNoteTargets(in: elseBlock, declared: declared, textDeclared: textDeclared)
            }
        case .matchBranch(let s):
            for branchCase in s.cases {
                try validateNoteTargets(in: branchCase.block, declared: declared, textDeclared: textDeclared)
            }
            if let otherwise = s.otherwiseBlock {
                try validateNoteTargets(in: otherwise, declared: declared, textDeclared: textDeclared)
            }
        case .iteration(let s):
            var bodyDeclared = declared
            if case .forEach(let variable, _) = s.mode {
                bodyDeclared.insert(scopeKey(variable))
            }
            try validateNoteTargets(in: s.body, declared: bodyDeclared, textDeclared: textDeclared)
        case .simultaneously(let s):
            for branch in s.branches {
                try validateNoteTargets(in: branch, declared: declared, textDeclared: textDeclared)
            }
        case .recover(let s):
            try validateNoteStmt(s.attached, declared: &declared, textDeclared: &textDeclared)
            try validateNoteTargets(in: s.handler, declared: declared, textDeclared: textDeclared)
        case .labelled(let s):
            try validateNoteStmt(s.statement, declared: &declared, textDeclared: &textDeclared)
        default:
            break
        }
    }

    private func recordNoteBinding(_ name: String, value: ExpressionAST,
                                   declared: inout Set<String>, textDeclared: inout Set<String>) {
        let key = scopeKey(name)
        declared.insert(key)
        if isTextValue(value) {
            textDeclared.insert(key)
        } else {
            textDeclared.remove(key)
        }
    }

    private func checkNoteTarget(_ s: NoteStatementAST, declared: Set<String>, textDeclared: Set<String>) throws {
        let key = scopeKey(s.binding)
        if !declared.contains(key) {
            let diag = Diagnostic.structural(
                .noteBindingUndeclared,
                message: "note target binding `\(s.binding)` is not declared in scope",
                range: sourceRange(s.sourceLine),
                help: "Declare it first with a text bind — e.g. `let the \(s.binding) be \"\".` — before `proceed, and note \"…\" in the \(s.binding)`."
            )
            try throwLoweringError(diag)
        }
        if !textDeclared.contains(key) {
            let diag = Diagnostic.structural(
                .noteBindingNonText,
                message: "note target binding `\(s.binding)` is not a text binding",
                range: sourceRange(s.sourceLine),
                help: "`proceed, and note \"…\"` appends text; note only into a binding first declared with a text value."
            )
            try throwLoweringError(diag)
        }
    }

    /// Conservative text classifier for the compound note form's target check.
    /// String / interpolated-string / template values are text; numeric,
    /// boolean, money, list, record, aggregate, and quantified values are
    /// unambiguously non-text. Everything else (tool results, property access,
    /// relation navigation, descriptions) is treated permissively as text so the
    /// note form never false-rejects a legitimately textual binding whose type
    /// Meridian does not statically track.
    private func isTextValue(_ expr: ExpressionAST) -> Bool {
        switch expr {
        case .literal(.string), .interpolatedString:
            return true
        case .literal(.integer), .literal(.double), .literal(.boolean), .literal(.money):
            return false
        case .recordList, .quantified, .aggregate:
            return false
        default:
            return true
        }
    }

    /// lower a bind right-hand side, hoisting a tool-backed relation fetch
    /// (description or scalar navigation) into a preceding `invoke` — so the
    /// `await` lives at statement scope, not inside the value expression.
    /// Non-relational values produce no prelude.
    private func lowerBindValue(_ expr: ExpressionAST, scope: Set<String>? = nil, line: Int) throws -> ([IRPrimitive], IRExpression) {
        // Statement position can host an `await`, so a tool-backed relation fetch
        // is allowed and its hoisted prelude is propagated.
        if let rel = try lowerRelationalExpr(expr, allowToolFetch: true, scope: scope, line: line) {
            return (rel.prelude, rel.expr)
        }
        return ([], try lowerExpr(expr, scope: scope, line: line))
    }

    /// Lower the four query-plan expression kinds (description / aggregate /
    /// superlative / scalar `relationTraversal`) that share the plan builders.
    /// Returns the hoisted prelude (tool fetches, only ever non-empty when
    /// `allowToolFetch`) and the value expression, or nil for any other
    /// expression (the caller falls back to `lowerExpr`). Single source for what
    /// were two near-identical blocks in `lowerBindValue` (fetch-allowed) and
    /// `lowerExpr` (value position, fetch-forbidden).
    func lowerRelationalExpr(_ expr: ExpressionAST, allowToolFetch: Bool, scope: Set<String>?, line: Int) throws -> (prelude: [IRPrimitive], expr: IRExpression)? {
        switch expr {
        case .description(let d):
            let plan = try lowerDescriptionPlan(d, allowToolFetch: allowToolFetch, scope: scope, line: line)
            return (plan.prelude, .description(plan.ir))
        case .aggregate(let k, let d):
            let plan = try lowerDescriptionPlan(d, allowToolFetch: allowToolFetch, scope: scope, line: line)
            return (plan.prelude, .aggregate(k == .count ? .count : .list, plan.ir))
        case .superlative(let s):
            let plan = try lowerDescriptionPlan(s.description, allowToolFetch: allowToolFetch, scope: scope, line: line)
            return (plan.prelude, .superlative(SuperlativeIR(description: plan.ir,
                                                             sortPath: camelCase(s.property),
                                                             ascending: s.ascending)))
        case .relationTraversal(let base, let relation, let navKind):
            let plan = try lowerScalarTraversalPlan(base: base, relationForm: relation, navKind: navKind,
                                                    allowToolFetch: allowToolFetch, scope: scope, line: line)
            return (plan.prelude, plan.expr)
        default:
            return nil
        }
    }

    func camelCase(_ s: String) -> String { IdentifierNaming.camelPreservingCase(s) }

    /// Inverse of `camelCase`: `"mailerServer"` → `"mailer server"`. Used by
    /// phrase-invocation text substitution so a body written as
    /// `the mailer server` matches a camelCase parameter name.
    func decamel(_ s: String) -> String {
        var out = ""
        for ch in s {
            if ch.isUppercase, !out.isEmpty { out.append(" ") }
            out.append(Character(ch.lowercased()))
        }
        return out
    }

}
