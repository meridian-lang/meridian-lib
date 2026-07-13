import Foundation
import MeridianRuntime

// MARK: - Definition registration & lowering

extension ASTToIR {
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
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .duplicateDeclaration,
                        message: "duplicate definition for adjective \"\(d.adjective)\": already defined for kind \"\(existing.kind)\"",
                        range: sourceRange(d.sourceLine),
                        help: "Adjective names must be globally unique across kinds — rename one of the definitions.")
                ])
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

    func definitionFunctionName(kind: String, adjective: String) -> String {
        "meridianDef_\(IdentifierNaming.pascalCaseSplittingHyphenPreservingCase(kind))_\(camelCase(adjective))"
    }

    /// Lower every registered adjective definition to a `LoweredDefinition`,
    /// sorted by function name for deterministic emission.
    public func lowerRegisteredDefinitions() throws -> [LoweredDefinition] {
        try symbols.definitions.values
            .sorted { $0.functionName < $1.functionName }
            .map { rec in
                trace.log(.lowering, "lower definition \(rec.functionName) (adjective on \(rec.kind))")
                // Rewrite the body so bare property references resolve against
                // the subject (the function parameter), mirroring loop-var
                // qualification.
                let lowered = try lowerExpr(rec.body)
                let qualified = qualifyToLoopVar(lowered, loopVar: camelCase(rec.subjectVar))
                let finalBody: IRExpression
                if containsTraceTemporal(qualified) {
                    guard let keyProperty = symbols.keyProperty(of: rec.kind) else {
                        let diag = Diagnostic.error(
                            .traceUnkeyedDefinition,
                            message: "trace-backed definition `\(rec.adjective)` on kind `\(rec.kind)` requires `\(rec.kind)` to declare a key property",
                            range: sourceRange(rec.sourceLine),
                            help: "Add `A \(rec.kind) is keyed by the <property>.` to the vocabulary before defining temporal or statistical adjectives on that kind."
                        )
                        try throwLoweringError(diag)
                    }
                    finalBody = attachSubjectKey(
                        qualified,
                        subjectVar: camelCase(rec.subjectVar),
                        keyProperty: keyProperty
                    )
                } else {
                    finalBody = qualified
                }
                return LoweredDefinition(functionName: rec.functionName,
                                         subjectVar: camelCase(rec.subjectVar),
                                         body: finalBody)
            }
    }

    func containsTraceTemporal(_ expression: IRExpression) -> Bool {
        switch expression {
        case .traceTemporal, .traceStatistical:
            return true
        case .comparison(let lhs, _, let rhs):
            return containsTraceTemporal(lhs) || containsTraceTemporal(rhs)
        case .logical(_, let items):
            return items.contains(where: containsTraceTemporal)
        case .propertyAccess(let base, _):
            return containsTraceTemporal(base)
        case .relationTraversal(let base, _, let target):
            return containsTraceTemporal(base) || target.map(containsTraceTemporal) == true
        case .invocation(let invoke):
            return invoke.arguments.contains { containsTraceTemporal($0.value) }
        case .definitionPredicate(_, let subject):
            return containsTraceTemporal(subject)
        case .quantified(let quantifier):
            return containsTraceTemporalInDescription(quantifier.description)
                || quantifier.body.map(containsTraceTemporal) == true
        case .description(let description):
            return containsTraceTemporalInDescription(description)
        case .aggregate(_, let description):
            return containsTraceTemporalInDescription(description)
        case .superlative(let superlative):
            return containsTraceTemporalInDescription(superlative.description)
        case .interpolatedString(let segments):
            return segments.contains { segment in
                switch segment {
                case .literal:
                    return false
                case .expression(let expression),
                     .shellEscapedExpression(let expression),
                     .formatted(let expression, _):
                    return containsTraceTemporal(expression)
                case .conditional(let condition, let thenSegs, let elseSegs):
                    return containsTraceTemporal(condition)
                        || thenSegs.contains { _containsTraceTemporal($0) }
                        || elseSegs.contains { _containsTraceTemporal($0) }
                case .forEach(_, let collection, let body):
                    return containsTraceTemporal(collection) || body.contains { _containsTraceTemporal($0) }
                }
            }
        case .recordList(_, let rows):
            return rows.flatMap { $0 }.contains(where: containsTraceTemporal)
        case .tableLookup(_, _, let key, _):
            return containsTraceTemporal(key)
        case .eventPattern(let pattern):
            return pattern.payloadPredicate.map(containsTraceTemporal) == true
        default:
            return false
        }
    }

    func assertNeedsExplicitDefaultPolicy(
        condition: IRExpression,
        otherwise: IRBlock?,
        monitored: Bool,
        blocking: Bool
    ) -> Bool {
        guard otherwise == nil else { return false }
        let blockingSite = !monitored || blocking
        guard blockingSite else { return false }
        return containsDirectSinceLast(condition)
    }

    func containsDirectSinceLast(_ expression: IRExpression) -> Bool {
        switch expression {
        case .traceTemporal(let temporal):
            if case .sinceLast = temporal.kind {
                return true
            }
            return false
        case .comparison(let lhs, _, let rhs):
            return containsDirectSinceLast(lhs) || containsDirectSinceLast(rhs)
        case .logical(_, let items):
            return items.contains(where: containsDirectSinceLast)
        case .propertyAccess(let base, _):
            return containsDirectSinceLast(base)
        case .relationTraversal(let base, _, let target):
            return containsDirectSinceLast(base) || target.map(containsDirectSinceLast) == true
        case .invocation(let invoke):
            return invoke.arguments.contains { containsDirectSinceLast($0.value) }
        case .definitionPredicate(_, let subject):
            return containsDirectSinceLast(subject)
        case .quantified(let quantifier):
            return containsDirectSinceLastInDescription(quantifier.description)
                || quantifier.body.map(containsDirectSinceLast) == true
        case .description(let description):
            return containsDirectSinceLastInDescription(description)
        case .aggregate(_, let description):
            return containsDirectSinceLastInDescription(description)
        case .superlative(let superlative):
            return containsDirectSinceLastInDescription(superlative.description)
        case .interpolatedString(let segments):
            return segments.contains { containsDirectSinceLast($0) }
        case .recordList(_, let rows):
            return rows.flatMap { $0 }.contains(where: containsDirectSinceLast)
        case .tableLookup(_, _, let key, _):
            return containsDirectSinceLast(key)
        case .eventPattern(let pattern):
            return pattern.payloadPredicate.map(containsDirectSinceLast) == true
        default:
            return false
        }
    }

    func containsDirectSinceLast(_ segment: IRInterpolationSegment) -> Bool {
        switch segment {
        case .literal:
            return false
        case .expression(let expression),
             .shellEscapedExpression(let expression),
             .formatted(let expression, _):
            return containsDirectSinceLast(expression)
        case .conditional(let condition, let thenSegs, let elseSegs):
            return containsDirectSinceLast(condition)
                || thenSegs.contains { containsDirectSinceLast($0) }
                || elseSegs.contains { containsDirectSinceLast($0) }
        case .forEach(_, let collection, let body):
            return containsDirectSinceLast(collection) || body.contains { containsDirectSinceLast($0) }
        }
    }

    func containsDirectSinceLastInDescription(_ description: DescriptionIR) -> Bool {
        containsDirectSinceLast(description.collection)
            || description.filters.contains(where: containsDirectSinceLast)
    }

    func _containsTraceTemporal(_ segment: IRInterpolationSegment) -> Bool {
        switch segment {
        case .literal:
            return false
        case .expression(let expression),
             .shellEscapedExpression(let expression),
             .formatted(let expression, _):
            return containsTraceTemporal(expression)
        case .conditional(let condition, let thenSegs, let elseSegs):
            return containsTraceTemporal(condition)
                || thenSegs.contains { _containsTraceTemporal($0) }
                || elseSegs.contains { _containsTraceTemporal($0) }
        case .forEach(_, let collection, let body):
            return containsTraceTemporal(collection) || body.contains { _containsTraceTemporal($0) }
        }
    }

    func containsTraceTemporalInDescription(_ description: DescriptionIR) -> Bool {
        containsTraceTemporal(description.collection)
            || description.filters.contains(where: containsTraceTemporal)
    }

    func attachSubjectKey(_ expression: IRExpression, subjectVar: String, keyProperty: String) -> IRExpression {
        let subjectKeyExpr = IRExpression.propertyAccess(.identifierRef(name: subjectVar), propertyName: keyProperty)
        switch expression {
        case .traceTemporal(let temporal):
            return .traceTemporal(TraceTemporalIR(
                scope: temporal.scope,
                kind: temporal.kind,
                subjectKeyExpr: temporal.subjectKeyExpr ?? subjectKeyExpr
            ))
        case .traceStatistical(let statistical):
            return .traceStatistical(TraceStatisticalIR(
                scope: statistical.scope,
                pattern: TraceStatisticalPatternIR(
                    subject: statistical.pattern.subject,
                    payloadPredicate: statistical.pattern.payloadPredicate.map {
                        attachSubjectKey($0, subjectVar: subjectVar, keyProperty: keyProperty)
                    }
                ),
                outcome: statistical.outcome,
                bound: statistical.bound,
                denominator: statistical.denominator,
                window: statistical.window,
                monitorCadence: statistical.monitorCadence,
                blocking: statistical.blocking,
                subjectKeyExpr: statistical.subjectKeyExpr ?? subjectKeyExpr
            ))
        case .comparison(let lhs, let op, let rhs):
            return .comparison(
                attachSubjectKey(lhs, subjectVar: subjectVar, keyProperty: keyProperty),
                op,
                attachSubjectKey(rhs, subjectVar: subjectVar, keyProperty: keyProperty)
            )
        case .logical(let op, let items):
            return .logical(op, items.map { attachSubjectKey($0, subjectVar: subjectVar, keyProperty: keyProperty) })
        case .propertyAccess(let base, let property):
            return .propertyAccess(attachSubjectKey(base, subjectVar: subjectVar, keyProperty: keyProperty), propertyName: property)
        case .relationTraversal(let base, let relation, let target):
            return .relationTraversal(
                attachSubjectKey(base, subjectVar: subjectVar, keyProperty: keyProperty),
                relationName: relation,
                target: target.map { attachSubjectKey($0, subjectVar: subjectVar, keyProperty: keyProperty) }
            )
        case .invocation(let invoke):
            return .invocation(InvokeIR(
                toolID: invoke.toolID,
                arguments: invoke.arguments.map {
                    InvokeArg($0.key, attachSubjectKey($0.value, subjectVar: subjectVar, keyProperty: keyProperty))
                },
                resultBinding: invoke.resultBinding,
                comment: invoke.comment,
                sourceRange: invoke.sourceRange,
                stableStepPath: invoke.stableStepPath
            ))
        case .definitionPredicate(let functionName, let subject):
            return .definitionPredicate(
                functionName: functionName,
                subject: attachSubjectKey(subject, subjectVar: subjectVar, keyProperty: keyProperty)
            )
        case .quantified(let quantifier):
            return .quantified(QuantifierIR(
                kind: quantifier.kind,
                description: DescriptionIR(
                    collection: attachSubjectKey(quantifier.description.collection, subjectVar: subjectVar, keyProperty: keyProperty),
                    elementVar: quantifier.description.elementVar,
                    filters: quantifier.description.filters.map { attachSubjectKey($0, subjectVar: subjectVar, keyProperty: keyProperty) },
                    sort: quantifier.description.sort,
                    take: quantifier.description.take
                ),
                body: quantifier.body.map { attachSubjectKey($0, subjectVar: subjectVar, keyProperty: keyProperty) }
            ))
        case .description(let description):
            return .description(DescriptionIR(
                collection: attachSubjectKey(description.collection, subjectVar: subjectVar, keyProperty: keyProperty),
                elementVar: description.elementVar,
                filters: description.filters.map { attachSubjectKey($0, subjectVar: subjectVar, keyProperty: keyProperty) },
                sort: description.sort,
                take: description.take
            ))
        case .aggregate(let kind, let description):
            return .aggregate(kind, DescriptionIR(
                collection: attachSubjectKey(description.collection, subjectVar: subjectVar, keyProperty: keyProperty),
                elementVar: description.elementVar,
                filters: description.filters.map { attachSubjectKey($0, subjectVar: subjectVar, keyProperty: keyProperty) },
                sort: description.sort,
                take: description.take
            ))
        case .superlative(let superlative):
            return .superlative(SuperlativeIR(
                description: DescriptionIR(
                    collection: attachSubjectKey(superlative.description.collection, subjectVar: subjectVar, keyProperty: keyProperty),
                    elementVar: superlative.description.elementVar,
                    filters: superlative.description.filters.map { attachSubjectKey($0, subjectVar: subjectVar, keyProperty: keyProperty) },
                    sort: superlative.description.sort,
                    take: superlative.description.take
                ),
                sortPath: superlative.sortPath,
                ascending: superlative.ascending
            ))
        case .interpolatedString, .recordList, .tableLookup, .literal, .constantRef, .identifierRef,
             .instanceRef, .envVar, .nowExpression, .eventPattern:
            return expression
        }
    }

    /// Type-check a definition body: any property access on the subject must name
    /// a declared property of the kind (only enforced when the kind declares
    /// properties — `.meri`-local kinds without a merconfig are left lenient).
    func typeCheckDefinitionBody(_ record: SymbolTable.DefinitionRecord) throws {
        let declared = symbols.propertyNames(of: record.kind)
        guard !declared.isEmpty else { return }
        let subject = record.subjectVar.lowercased()
        try walkProperties(record.body) { base, prop in
            guard case .identifierRef(let n) = base, n.lowercased() == subject else { return }
            if !declared.contains(prop.lowercased()) {
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .unknownProperty,
                        target: prop,
                        among: declared.sorted(),
                        range: sourceRange(record.sourceLine),
                        noun: "property",
                        help: "Declare property \"\(prop)\" on \(record.kind), or reference one of its declared properties.")
                ])
            }
        }
    }

    func walkProperties(_ e: ExpressionAST, _ visit: (ExpressionAST, String) throws -> Void) rethrows {
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
    func detectDefinitionRecursion(start: String) throws {
        var visiting: Set<String> = []
        func dfs(_ adj: String, path: [String]) throws {
            if visiting.contains(adj) {
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .definitionRecursion,
                        message: "recursive definition detected: \(path.joined(separator: " → ")) → \(adj). Definitions must not reference themselves (directly or transitively).",
                        range: sourceRange(symbols.definition(forAdjective: adj)?.sourceLine ?? 0))
                ])
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
    func referencedAdjectives(_ e: ExpressionAST) -> [String] {
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
    func resolveAdjectiveFilter(adjective: String, subject: IRExpression, sourceLine: Int) throws -> IRExpression {
        guard let record = symbols.definition(forAdjective: adjective) else {
            throw CompilerError.diagnostics([
                Diagnostic.unresolved(
                    .unknownAdjective,
                    target: adjective,
                    among: symbols.definitions.values.map { $0.adjective },
                    range: sourceRange(sourceLine),
                    noun: "adjective",
                    help: "Declare it with `Definition: a <kind> is \(adjective) if <condition>.`")
            ])
        }
        return .definitionPredicate(functionName: record.functionName, subject: subject)
    }

}
