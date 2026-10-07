import Foundation
import MeridianRuntime

enum DeonticLowering {

    static func normID(sourceLine: Int, kind: NormKind) -> String {
        "deontic:\(kind.rawValue):L\(sourceLine)"
    }

    static func deonticRejectionDiagnostic(for text: String, lexicon: EnglishLexicon) -> Diagnostic? {
        let lower = text.lowercased()
        let markers = lexicon.grammar.ruleMarkers
        for phrase in markers.outcomeAsActionPhrases where lower.contains(phrase) {
            return Diagnostic.error(
                .deonticOutcomeAsAction,
                message: "outcome phrasing is not a prohibitable action: \"\(text.trimmingCharacters(in: .whitespaces))\"",
                range: SourceRange(file: "", line: 0, column: 0),
                help: "Prohibit a concrete tool invoke (for example `must not invoke <tool>`) or assert a condition (`<predicate> must hold`) instead of banning an outcome word such as fail.")
        }
        for marker in markers.nonNormModalMarkers where lower.contains(marker) {
            return Diagnostic.error(
                .deonticNonNormModal,
                message: "non-norm modal in rule text: \"\(text.trimmingCharacters(in: .whitespaces))\"",
                range: SourceRange(file: "", line: 0, column: 0),
                help: "Deontic norms use `must`, `must not`, and `may` only. Rewrite with a normative modal or move advisory wording into a reference section.")
        }
        return nil
    }

    static func parseInvokeActionPattern(
        _ actionText: String,
        exprParser: ExpressionParser,
        lexicon: EnglishLexicon
    ) throws -> ActionPatternIR? {
        var trimmed = actionText.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix(".") { trimmed = String(trimmed.dropLast()) }
        let head = lexicon.grammar.ruleMarkers.invokeActionHead
        guard trimmed.lowercased().hasPrefix(head) else { return nil }
        var rest = String(trimmed.dropFirst(head.count)).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return nil }

        var constraints: [ActionArgumentConstraint] = []
        if let whoseRange = rest.range(of: lexicon.grammar.ruleMarkers.whoseMarker, options: [.caseInsensitive]) {
            let toolPart = String(rest[rest.startIndex..<whoseRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let predicatePart = String(rest[whoseRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            rest = toolPart
            constraints = try parseArgumentConstraints(predicatePart, exprParser: exprParser, lexicon: lexicon)
        }

        let toolID = IdentifierNaming.methodize(rest.trimmingCharacters(in: .whitespaces))
        guard !toolID.isEmpty else { return nil }
        return ActionPatternIR(toolID: toolID, argumentConstraints: constraints)
    }

    static func parseArgumentConstraints(
        _ text: String,
        exprParser: ExpressionParser,
        lexicon: EnglishLexicon
    ) throws -> [ActionArgumentConstraint] {
        let markers = lexicon.comparisonMarkers
        var best: (path: String, op: ComparisonOpAST, valueText: String, phraseLen: Int)?
        for (marker, op) in markers {
            if let range = text.range(of: marker, options: [.caseInsensitive]) {
                let path = String(text[text.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let valueText = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                guard !path.isEmpty, !valueText.isEmpty else { continue }
                if best == nil || marker.count > best!.phraseLen {
                    best = (path, op, valueText, marker.count)
                }
            }
        }
        guard let match = best else { return [] }
        let path = IdentifierNaming.camelPreservingCase(match.path)
        let sr = SourceRange(file: "", line: 0, column: 0)
        let valueExpr = try lowerCheckableDeonticExpr(
            exprParser.parse(match.valueText),
            sourceRange: sr,
            symbols: exprParser.symbols,
            valueContext: true)
        return [ActionArgumentConstraint(path: path, op: LiteralLowering.mapComparisonOp(match.op), value: valueExpr)]
    }

    /// Lower a deontic obligation / permission `only where` condition or a
    /// `whose` constraint value to checkable `IRExpression`. Raises
    /// `MER-DEO-007` for quantifiers, descriptions, trace queries, and other
    /// shapes a norm guard cannot evaluate inline.
    static func lowerCheckableDeonticExpr(
        _ expr: ExpressionAST,
        sourceRange: SourceRange,
        symbols: SymbolTable?,
        valueContext: Bool = false
    ) throws -> IRExpression {
        func lower(_ nested: ExpressionAST) throws -> IRExpression {
            try lowerCheckableDeonticExpr(nested, sourceRange: sourceRange, symbols: symbols, valueContext: valueContext)
        }

        switch expr {
        case .literal(let lit):
            return .literal(LiteralLowering.toIRLiteral(lit))
        case .identifierRef(let n):
            let lowerName = n.lowercased().trimmingCharacters(in: .whitespaces)
            if let symbols {
                if symbols.constants[lowerName] != nil { return .constantRef(name: lowerName) }
                if symbols.instances[lowerName] != nil { return .instanceRef(name: lowerName) }
                if symbols.enumCases.contains(lowerName) { return .literal(.string(lowerName)) }
            }
            return .identifierRef(name: IdentifierNaming.camelPreservingCase(lowerName))
        case .propertyAccess(let base, let prop):
            return .propertyAccess(try lower(base), propertyName: prop)
        case .comparison(let lhs, let op, let rhs):
            return .comparison(try lower(lhs), LiteralLowering.mapComparisonOp(op), try lower(rhs))
        case .logical(let op, let exprs):
            return .logical(LiteralLowering.mapLogicalOp(op), try exprs.map { try lower($0) })
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return .tableLookup(
                table: table,
                keyColumn: keyColumn,
                key: try lower(key),
                valueColumn: valueColumn)
        case .envVar(let name):
            return .envVar(name: name)
        case .now:
            return .nowExpression
        case .instanceRef(let name):
            return .instanceRef(name: name)
        case .constantRef(let name):
            return .constantRef(name: name)
        case .verbPredicate(let subject, let verb, let object):
            return try lowerPropertyBackedVerbPredicate(
                subject: subject,
                verbForm: verb,
                object: object,
                symbols: symbols,
                sourceRange: sourceRange,
                lower: lower)
        case .quantified, .malformed, .recordList, .relationTraversal, .description,
             .aggregate, .superlative, .eventPattern, .traceTemporal, .traceStatistical,
             .invoke, .interpolatedString, .decideWhether:
            throw deonticUnlowerableDiagnostic(
                expr: expr,
                sourceRange: sourceRange,
                valueContext: valueContext)
        }
    }

    private static func lowerPropertyBackedVerbPredicate(
        subject: ExpressionAST,
        verbForm: String,
        object: ExpressionAST,
        symbols: SymbolTable?,
        sourceRange: SourceRange,
        lower: (ExpressionAST) throws -> IRExpression
    ) throws -> IRExpression {
        guard let symbols,
              let resolved = symbols.resolveVerbForm(verbForm),
              let rel = symbols.relation(named: resolved.verb.relation),
              let backing = symbols.backing(forRelation: resolved.verb.relation) else {
            throw deonticUnlowerableDiagnostic(
                expr: .verbPredicate(subject: subject, verb: verbForm, object: object),
                sourceRange: sourceRange,
                valueContext: false)
        }
        switch backing {
        case .property(let backingKind, let path):
            let subjectIR = try lower(subject)
            let objectIR = try lower(object)
            let kind = backingKind.lowercased()
            if kind == rel.rightKind.lowercased() {
                return .comparison(.propertyAccess(objectIR, propertyName: path), .identifies, subjectIR)
            }
            if kind == rel.leftKind.lowercased() {
                return .comparison(.propertyAccess(subjectIR, propertyName: path), .identifies, objectIR)
            }
            throw deonticUnlowerableDiagnostic(
                expr: .verbPredicate(subject: subject, verb: verbForm, object: object),
                sourceRange: sourceRange,
                valueContext: false)
        case .tool:
            throw deonticUnlowerableDiagnostic(
                expr: .verbPredicate(subject: subject, verb: verbForm, object: object),
                sourceRange: sourceRange,
                valueContext: false)
        }
    }

    private static func deonticUnlowerableDiagnostic(
        expr: ExpressionAST,
        sourceRange: SourceRange,
        valueContext: Bool
    ) -> CompilerError {
        let compact = expr.traceDescription(detail: .compact)
        let message = valueContext
            ? "deontic invoke constraint value is not lowerable: \"\(compact)\""
            : "deontic condition is not lowerable to checkable IR: \"\(compact)\""
        let help = valueContext
            ? "Rewrite the `whose` predicate value as a comparison, property access, table lookup, logical combination, or literal Meridian can lower."
            : "Rewrite the condition as a comparison, property access, logical combination, table lookup, or literal value Meridian can lower. Trace-backed `has ever` / `usually` predicates belong in workflow asserts, not bare `must hold` obligation rules unless the expression form is supported."
        return CompilerError.diagnostics([
            Diagnostic.error(.deonticUnlowerableCondition, message: message, range: sourceRange, help: help)
        ])
    }

    static func norms(from rules: [ParsedRule]) -> [NormIR] {
        rules.compactMap { rule in
            switch rule {
            case .deonticProhibition(let norm): return norm
            case .deonticObligation(let norm): return norm
            case .deonticPermission(let norm): return norm
            default: return nil
            }
        }
    }

    static func detectConflicts(_ norms: [NormIR]) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        for i in norms.indices {
            for j in norms.indices where j > i {
                guard normsOverlap(norms[i], norms[j]) else { continue }
                if norms[i].scope == norms[j].scope,
                   (norms[i].kind == .prohibition && norms[j].kind == .permission)
                    || (norms[i].kind == .permission && norms[j].kind == .prohibition) {
                    diagnostics.append(Diagnostic.error(
                        .deonticSameScopeConflict,
                        message: "prohibition and permission overlap in the same scope: \"\(norms[i].originalText)\" and \"\(norms[j].originalText)\"",
                        range: norms[i].sourceRange,
                        help: "Remove or narrow one of the norms so they no longer cover the same invoke pattern in the same scope."))
                    diagnostics.append(Diagnostic.error(
                        .deonticSameScopeConflict,
                        message: "prohibition and permission overlap in the same scope: \"\(norms[j].originalText)\" and \"\(norms[i].originalText)\"",
                        range: norms[j].sourceRange,
                        help: "Remove or narrow one of the norms so they no longer cover the same invoke pattern in the same scope."))
                } else if (scopeContains(outer: norms[i].scope, inner: norms[j].scope)
                            && norms[i].kind == .prohibition && norms[j].kind == .permission)
                    || (scopeContains(outer: norms[j].scope, inner: norms[i].scope)
                        && norms[j].kind == .prohibition && norms[i].kind == .permission) {
                    let permission = norms[i].kind == .permission ? norms[i] : norms[j]
                    diagnostics.append(Diagnostic.error(
                        .deonticStickyDeny,
                        message: "inner permission cannot override outer prohibition: \"\(permission.originalText)\"",
                        range: permission.sourceRange,
                        help: "Deny is sticky downward — remove the inner `may` grant or relax the outer `must not invoke` prohibition."))
                }
            }
        }
        return diagnostics
    }

    private static func scopeContains(outer: NormScope, inner: NormScope) -> Bool {
        switch (outer, inner) {
        case (.skill, _): return true
        case (.workflow(let o), .workflow(let i)): return o == i
        case (.workflow, .section), (.workflow, .kind): return true
        case (.section(let o), .section(let i)): return o == i
        case (.section, .kind): return true
        case (.kind(let o), .kind(let i)): return o == i
        case (.kind, .workflow), (.kind, .section): return false
        default: return false
        }
    }

    private static func normsOverlap(_ a: NormIR, _ b: NormIR) -> Bool {
        guard let ap = a.actionPattern, let bp = b.actionPattern else { return false }
        guard ap.toolID == bp.toolID else { return false }
        if ap.argumentConstraints.isEmpty || bp.argumentConstraints.isEmpty { return true }
        return !constraintsProvablyDisjoint(ap.argumentConstraints, bp.argumentConstraints)
    }

    private static func constraintsProvablyDisjoint(
        _ lhs: [ActionArgumentConstraint],
        _ rhs: [ActionArgumentConstraint]
    ) -> Bool {
        for l in lhs {
            for r in rhs where l.path == r.path && l.op == r.op {
                if case .literal(let ll) = l.value, case .literal(let rl) = r.value,
                   !IREquality.structurallyEqual(ll, rl) {
                    return true
                }
            }
        }
        return false
    }

    static func apply(
        norms: [NormIR],
        to workflows: [IRWorkflow],
        engine: DiagnosticEngine? = nil
    ) throws -> [IRWorkflow] {
        guard !norms.isEmpty else { return workflows }
        var registry = NormIdRegistry()
        for norm in norms {
            let fullHash = try CanonicalJSON.sha256Hex(for: CanonicalIRSerializer.normSemanticPayload(norm))
            try registry.register(id: norm.id, fullHash: fullHash)
        }
        return try workflows.map { workflow in
            let scoped = norms.filter { normApplies($0, to: workflow) }
            guard !scoped.isEmpty else {
                return IRWorkflow(
                    name: workflow.name,
                    parameters: workflow.parameters,
                    body: workflow.body,
                    mode: workflow.mode,
                    sourceFile: workflow.sourceFile,
                    sourceRange: workflow.sourceRange,
                    explicitStructName: workflow.explicitStructName,
                    allowsDiscretion: workflow.allowsDiscretion,
                    skillName: workflow.skillName,
                    skillVersionHash: workflow.skillVersionHash,
                    runtimeTraceConfiguration: workflow.runtimeTraceConfiguration,
                    norms: scoped
                )
            }
            var body = try transformBlock(
                workflow.body,
                workflow: workflow,
                norms: scoped,
                registry: &registry,
                engine: engine
            )
            body = insertObligations(into: body, norms: scoped.filter { $0.kind == .obligation })
            return IRWorkflow(
                name: workflow.name,
                parameters: workflow.parameters,
                body: body,
                mode: workflow.mode,
                sourceFile: workflow.sourceFile,
                sourceRange: workflow.sourceRange,
                explicitStructName: workflow.explicitStructName,
                allowsDiscretion: workflow.allowsDiscretion,
                skillName: workflow.skillName,
                skillVersionHash: workflow.skillVersionHash,
                runtimeTraceConfiguration: workflow.runtimeTraceConfiguration,
                norms: scoped
            )
        }
    }

    static func uncoveredInvokeDiagnostic(toolID: String, range: SourceRange) -> Diagnostic {
        Diagnostic.error(
            .deonticToolOutsidePermissions,
            message: "tool invoke `\(toolID)` is not covered by any permission in this default-deny scope",
            range: range,
            help: "Add a `may invoke \(toolID)` permission norm, or remove permission norms that enable default-deny for this workflow.")
    }

    private static func normApplies(_ norm: NormIR, to workflow: IRWorkflow) -> Bool {
        switch norm.scope {
        case .skill: return true
        case .workflow(let name):
            return workflow.structName == name
                || IdentifierNaming.camelPreservingCase(workflow.name) == IdentifierNaming.camelPreservingCase(name)
        case .section, .kind: return true
        }
    }

    private static func transformBlock(
        _ block: IRBlock,
        workflow: IRWorkflow,
        norms: [NormIR],
        registry: inout NormIdRegistry,
        engine: DiagnosticEngine?
    ) throws -> IRBlock {
        let statements = try block.statements.map { stmt -> IRPrimitive in
            try transformPrimitive(stmt, workflow: workflow, norms: norms, registry: &registry, engine: engine)
        }
        return IRBlock(statements: statements, sourceRange: block.sourceRange)
    }

    private static func transformPrimitive(
        _ primitive: IRPrimitive,
        workflow: IRWorkflow,
        norms: [NormIR],
        registry: inout NormIdRegistry,
        engine: DiagnosticEngine?
    ) throws -> IRPrimitive {
        switch primitive {
        case .invoke(let invoke):
            return try wrapInvokeIfNeeded(
                invoke, workflow: workflow, norms: norms, registry: &registry, engine: engine)
        case .branch(let branch):
            let thenBlock = try transformBlock(
                branch.thenBlock, workflow: workflow, norms: norms, registry: &registry, engine: engine)
            let unknownBlock = try branch.unknownBlock.map {
                try transformBlock($0, workflow: workflow, norms: norms, registry: &registry, engine: engine)
            }
            let elseBlock = try branch.elseBlock.map {
                try transformBlock($0, workflow: workflow, norms: norms, registry: &registry, engine: engine)
            }
            return .branch(BranchIR(
                condition: branch.condition,
                thenBlock: thenBlock,
                unknownBlock: unknownBlock,
                elseBlock: elseBlock,
                deonticGuard: branch.deonticGuard,
                sourceRange: branch.sourceRange,
                stableStepPath: branch.stableStepPath
            ))
        case .iterate(let iterate):
            return .iterate(IterateIR(
                mode: iterate.mode,
                body: try transformBlock(
                    iterate.body, workflow: workflow, norms: norms, registry: &registry, engine: engine),
                source: iterate.source,
                sourceRange: iterate.sourceRange,
                stableStepPath: iterate.stableStepPath
            ))
        case .recover(let recover):
            return .recover(RecoverIR(
                pattern: recover.pattern,
                handler: try transformBlock(
                    recover.handler, workflow: workflow, norms: norms, registry: &registry, engine: engine),
                attachedTo: try transformBlock(
                    recover.attachedTo, workflow: workflow, norms: norms, registry: &registry, engine: engine),
                sourceRange: recover.sourceRange,
                stableStepPath: recover.stableStepPath
            ))
        case .simultaneously(let sim):
            return .simultaneously(SimultaneouslyIR(
                branches: try sim.branches.map {
                    try transformBlock($0, workflow: workflow, norms: norms, registry: &registry, engine: engine)
                },
                detached: sim.detached,
                sourceRange: sim.sourceRange,
                stableStepPath: sim.stableStepPath
            ))
        case .assert(let assertIR):
            if let otherwise = assertIR.otherwiseAction {
                return .assert(AssertIR(
                    condition: assertIR.condition,
                    message: assertIR.message,
                    otherwiseAction: try transformBlock(
                        otherwise, workflow: workflow, norms: norms, registry: &registry, engine: engine),
                    monitored: assertIR.monitored,
                    cadence: assertIR.cadence,
                    blocking: assertIR.blocking,
                    normID: assertIR.normID,
                    violationDisposition: assertIR.violationDisposition,
                    sourceRange: assertIR.sourceRange,
                    stableStepPath: assertIR.stableStepPath
                ))
            }
            return primitive
        default:
            return primitive
        }
    }

    private static func wrapInvokeIfNeeded(
        _ invoke: InvokeIR,
        workflow: IRWorkflow,
        norms: [NormIR],
        registry: inout NormIdRegistry,
        engine: DiagnosticEngine?
    ) throws -> IRPrimitive {
        let prohibitions = norms.filter { $0.kind == .prohibition }
        let permissions = norms.filter { $0.kind == .permission }
        if let prohibition = prohibitions.first(where: { matchesInvoke($0.actionPattern, invoke: invoke) }) {
            guard let pattern = prohibition.actionPattern else { return .invoke(invoke) }
            let allowed = invokeAllowedCondition(pattern: pattern, invoke: invoke, negate: true)
            let guardIR = DeonticGuardIR(
                normID: prohibition.id,
                disposition: .prevented,
                blocking: prohibition.blocking,
                actionPattern: pattern
            )
            return .branch(BranchIR(
                condition: .predicate(allowed),
                thenBlock: IRBlock(statements: [.invoke(invoke)], sourceRange: invoke.sourceRange),
                elseBlock: IRBlock(statements: [], sourceRange: invoke.sourceRange),
                deonticGuard: guardIR,
                sourceRange: invoke.sourceRange,
                stableStepPath: invoke.stableStepPath
            ))
        }
        if !permissions.isEmpty {
            let covering = permissions.filter { permissionCovers($0, invoke: invoke) }
            if covering.isEmpty {
                let toolPermissions = permissionsMatchingTool(invoke.toolID, in: permissions)
                if toolPermissions.isEmpty {
                    let diag = uncoveredInvokeDiagnostic(toolID: invoke.toolID, range: invoke.sourceRange)
                    if let engine {
                        engine.report(diag)
                    }
                    throw CompilerError.diagnostics([diag])
                }
                return try runtimePermissionGuard(
                    invoke: invoke,
                    workflow: workflow,
                    permissions: toolPermissions,
                    registry: &registry
                )
            }
            if let conditioned = covering.first(where: { !($0.actionPattern?.argumentConstraints.isEmpty ?? true) }),
               let pattern = conditioned.actionPattern {
                let allowed = permissionAllowedCondition(pattern: pattern, invoke: invoke)
                let guardIR = DeonticGuardIR(
                    normID: conditioned.id,
                    disposition: .prevented,
                    blocking: conditioned.blocking,
                    actionPattern: pattern
                )
                return .branch(BranchIR(
                    condition: .predicate(allowed),
                    thenBlock: IRBlock(statements: [.invoke(invoke)], sourceRange: invoke.sourceRange),
                    elseBlock: IRBlock(statements: [], sourceRange: invoke.sourceRange),
                    deonticGuard: guardIR,
                    sourceRange: invoke.sourceRange,
                    stableStepPath: invoke.stableStepPath
                ))
            }
        }
        return .invoke(invoke)
    }

    private static func permissionsMatchingTool(_ toolID: String, in permissions: [NormIR]) -> [NormIR] {
        permissions.filter { norm in
            guard let pattern = norm.actionPattern else { return false }
            return normalizeToolID(pattern.toolID) == normalizeToolID(toolID)
        }
    }

    private static func runtimePermissionGuard(
        invoke: InvokeIR,
        workflow: IRWorkflow,
        permissions: [NormIR],
        registry: inout NormIdRegistry
    ) throws -> IRPrimitive {
        let patterns = permissions.compactMap(\.actionPattern)
        let allowedParts = patterns.map { permissionAllowedCondition(pattern: $0, invoke: invoke) }
        let allowed: IRExpression = allowedParts.count == 1
            ? allowedParts[0]
            : .logical(.or, allowedParts)
        let pattern = patterns.first ?? ActionPatternIR(toolID: invoke.toolID, argumentConstraints: [])
        let normID: String
        if let firstID = permissions.first?.id {
            normID = firstID
        } else {
            normID = try NormId.forDefaultDeny(
                toolID: invoke.toolID,
                scope: .workflow(workflow.structName),
                registry: &registry
            )
        }
        let guardIR = DeonticGuardIR(
            normID: normID,
            disposition: .prevented,
            blocking: permissions.first?.blocking ?? false,
            actionPattern: pattern
        )
        return .branch(BranchIR(
            condition: .predicate(allowed),
            thenBlock: IRBlock(statements: [.invoke(invoke)], sourceRange: invoke.sourceRange),
            elseBlock: IRBlock(statements: [], sourceRange: invoke.sourceRange),
            deonticGuard: guardIR,
            sourceRange: invoke.sourceRange,
            stableStepPath: invoke.stableStepPath
        ))
    }

    private static func normalizeToolID(_ id: String) -> String {
        IdentifierNaming.methodize(id.trimmingCharacters(in: .whitespaces))
    }

    private static func matchesInvoke(_ pattern: ActionPatternIR?, invoke: InvokeIR) -> Bool {
        guard let pattern else { return false }
        guard normalizeToolID(pattern.toolID) == normalizeToolID(invoke.toolID) else { return false }
        return argumentConstraintsMatch(pattern.argumentConstraints, invoke: invoke)
    }

    private static func permissionCovers(_ norm: NormIR, invoke: InvokeIR) -> Bool {
        guard let pattern = norm.actionPattern else { return false }
        guard normalizeToolID(pattern.toolID) == normalizeToolID(invoke.toolID) else { return false }
        if pattern.argumentConstraints.isEmpty { return true }
        return argumentConstraintsMatch(pattern.argumentConstraints, invoke: invoke)
    }

    private static func argumentConstraintsMatch(_ constraints: [ActionArgumentConstraint], invoke: InvokeIR) -> Bool {
        guard !constraints.isEmpty else { return true }
        for constraint in constraints {
            guard let arg = invoke.arguments.first(where: {
                $0.key == constraint.path
                    || IdentifierNaming.camelPreservingCase($0.key) == constraint.path
            }) else { return false }
            if case .literal(let lit) = constraint.value, case .literal(let argLit) = arg.value,
               !IREquality.structurallyEqual(lit, argLit) {
                return false
            }
        }
        return true
    }

    private static func invokeAllowedCondition(
        pattern: ActionPatternIR,
        invoke: InvokeIR,
        negate: Bool
    ) -> IRExpression {
        var parts: [IRExpression] = []
        for constraint in pattern.argumentConstraints {
            let lhs: IRExpression
            if let arg = invoke.arguments.first(where: { $0.key == constraint.path }) {
                lhs = arg.value
            } else {
                lhs = .propertyAccess(.identifierRef(name: "args"), propertyName: constraint.path)
            }
            parts.append(.comparison(lhs, constraint.op, constraint.value))
        }
        if parts.isEmpty {
            return .literal(.boolean(!negate))
        }
        let core: IRExpression = parts.count == 1 ? parts[0] : .logical(.and, parts)
        return negate ? .logical(.not, [core]) : core
    }

    private static func permissionAllowedCondition(pattern: ActionPatternIR, invoke: InvokeIR) -> IRExpression {
        invokeAllowedCondition(pattern: pattern, invoke: invoke, negate: false)
    }

    private static func insertObligations(into block: IRBlock, norms: [NormIR]) -> IRBlock {
        guard !norms.isEmpty else { return block }
        var statements: [IRPrimitive] = []
        for stmt in block.statements {
            if case .commit = stmt {
                statements.append(contentsOf: obligationAsserts(for: norms))
            }
            if case .complete = stmt {
                statements.append(contentsOf: obligationAsserts(for: norms))
            }
            statements.append(stmt)
        }
        return IRBlock(statements: statements, sourceRange: block.sourceRange)
    }

    private static func obligationAsserts(for norms: [NormIR]) -> [IRPrimitive] {
        norms.compactMap { norm in
            guard let condition = norm.condition else { return nil }
            return .assert(AssertIR(
                condition: condition,
                message: norm.originalText,
                otherwiseAction: nil,
                monitored: false,
                cadence: nil,
                blocking: norm.blocking,
                normID: norm.id,
                violationDisposition: .observed,
                sourceRange: norm.sourceRange
            ))
        }
    }
}
