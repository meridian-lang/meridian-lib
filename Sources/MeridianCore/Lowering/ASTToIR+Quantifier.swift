import Foundation
import MeridianRuntime

// MARK: - Quantifier / iteration / wait helpers

extension ASTToIR {
    func lowerQuantifier(_ q: QuantifierAST, line: Int) throws -> IRExpression {
        let noun = q.description.noun.trimmingCharacters(in: .whitespaces)
        guard !noun.isEmpty else {
            throw semanticError("quantifier is missing a collection noun.", line, code: .quantifierSemantic,
                                help: "Write `every/all/no … <plural>` with a collection noun.")
        }
        // Camel-case the singular element so it matches `lowerExpr` identifier
        // keys (`vital signs` → `vitalSign`), not a spaced surface form that
        // later `qualifyToLoopVar` would mis-read as a distinct property.
        let singularNoun = lexicon.singularize(noun.lowercased())
        let elementVar = camelCase(singularNoun)

        // Source: a bound collection identifier, fetched once. Invocations are
        // rejected so the collection isn't re-evaluated per reducer.
        // Normalize to the plural collection name the author binds in scope —
        // count quantifiers conventionally use a singular noun after the
        // number (`at least 1 alert`, not `at least 1 alerts`), unlike
        // `all`/`any`/`no`, which are already plural on the surface. Mirrors
        // the same normalization `lowerDescriptionPlan` already applies.
        // Pluralize the still-spaced singular noun (not the already-camelCased
        // `elementVar`) and leave it spaced — `lowerExpr(.identifierRef)`
        // camelCases identifier text itself by splitting on spaces, so
        // pre-camelCasing here first would glue the words into one lowercase
        // run (`vitalSign` → pluralize → `vitalsigns`, no space left to split
        // on) that no longer matches the `vitalSigns` bind key.
        let collection = try lowerExpr(.identifierRef(lexicon.pluralize(singularNoun)), line: line)
        if case .invocation = collection {
            throw semanticError(
                "quantifier source must be a bound collection name (a parameter or earlier bind), not a tool call.",
                line, code: .quantifierSemantic,
                help: "Bind the collection with `let`/`bind` first, then quantify over the bound name.")
        }

        // 3B: a `that <verb> …` / `<participle> by …` relative clause
        // restricts the quantified collection through a declared relation —
        // the closed-grammar route for relation-backed conditions (`no pages
        // that mention the entity`), since relations have no bare-noun surface
        // form of their own. Quantifiers evaluate as a pure boolean expression
        // with no prelude slot, so a tool-backed clause here is rejected with
        // the same "bind it first" guidance used for inline verb tests.
        let (clauseFilters, _) = try lowerVerbClauses(
            q.description.verbClauses, elementVar: elementVar, allowToolFetch: false, scope: nil, line: line)
        var filters = clauseFilters
        for adj in q.description.adjectives {
            filters.append(try resolveAdjectiveFilter(
                adjective: adj, subject: .identifierRef(name: elementVar), sourceLine: line))
        }
        if let wherePred = q.description.wherePredicate {
            filters.append(qualifyToLoopVar(try lowerExpr(wherePred, line: line), loopVar: elementVar))
        }

        let body = try q.body.map { qualifyToLoopVar(try lowerExpr($0, line: line), loopVar: elementVar) }
        if case .all = q.kind, body == nil, filters.isEmpty {
            throw semanticError(
                "`all <description>` needs a body (e.g. `all pages have a summary`) or a `whose`/adjective restriction.",
                line, code: .quantifierSemantic,
                help: "Add a `whose` clause, adjective filter, or body predicate after the collection.")
        }

        let desc = DescriptionIR(collection: collection, elementVar: elementVar, filters: filters)
        return .quantified(QuantifierIR(kind: lowerQuantKind(q.kind), description: desc, body: body))
    }

    func lowerQuantKind(_ k: QuantifierKindAST) -> QuantifierKind {
        switch k {
        case .all:           return .all
        case .any:           return .any
        case .none:          return .none
        case .atLeast(let n): return .atLeast(n)
        case .atMost(let n):  return .atMost(n)
        case .exactly(let n): return .exactly(n)
        }
    }

    func lowerLiteral(_ lit: LiteralAST) -> IRLiteral { LiteralLowering.toIRLiteral(lit) }

    /// Lower a 1C iteration refinement, qualifying the `whose` predicate's bare
    /// property LHS to a property access on the loop variable and turning the
    /// temporal clause into a one-sided window comparison.
    func lowerIterationRefinement(_ r: IterationRefinementAST, loopVar: String) throws -> IRIterationRefinement {
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
        return IRIterationRefinement(filters: filters, sort: sort, take: r.take, takeFromEnd: r.takeFromEnd)
    }

    /// Rewrite a comparison's LHS (a bare property name) into a property access
    /// on the loop variable, so `whose status is "open"` becomes
    /// `<loopVar>.status == "open"`.
    func qualifyToLoopVar(_ e: IRExpression, loopVar: String) -> IRExpression {
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

    func qualifyOperand(_ e: IRExpression, loopVar: String) -> IRExpression {
        switch e {
        case .identifierRef(let name):
            // The loop variable itself is the element, not a property of it.
            // Compare after camel/space normalization so a spaced elementVar
            // from `singularize("vital signs")` ("vital sign") still matches
            // the camelCased identifier produced by `lowerExpr` ("vitalSign").
            if name == loopVar || scopeKey(name) == scopeKey(loopVar) { return e }
            return .propertyAccess(.identifierRef(name: loopVar), propertyName: name)
        default:
            return e
        }
    }

    func lowerCompOp(_ op: ComparisonOpAST) -> ComparisonOp { LiteralLowering.mapComparisonOp(op) }

    func lowerLogicalOp(_ op: LogicalOpAST) -> LogicalOp { LiteralLowering.mapLogicalOp(op) }

    func lowerWaitCondition(_ cond: WaitConditionAST) throws -> WaitConditionIR {
        switch cond {
        case .duration(let v, let unit):
            return .duration(LiteralLowering.durationSeconds(v, unit: unit))
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


}
