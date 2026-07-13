import Foundation
import MeridianRuntime

// MARK: - Relations, verbs, descriptions

extension ASTToIR {
    func semanticError(_ message: String, _ line: Int, code: DiagnosticCode = .relationBackingInvalid,
                             help: String? = nil) -> CompilerError {
        CompilerError.diagnostics([
            Diagnostic.error(code, message: message, range: sourceRange(line), help: help)
        ])
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

    func validateBacking(_ backing: RelationBackingAST, of rel: RelationDeclaration) throws {
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
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .unknownProperty,
                        target: path,
                        among: props.sorted(),
                        range: sourceRange(rel.sourceLine),
                        noun: "property",
                        help: "Declare property \"\(path)\" on \(kind), or reference one of its declared properties on `\(kind)`.")
                ])
            }
        case .tool(let toolID):
            guard symbols.tool(named: toolID) != nil else {
                let candidates = Array(
                    Set(BuiltinToolCatalog.ids + symbols.tools.values.map(\.methodName))
                ).sorted()
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .unknownTool,
                        target: toolID,
                        among: candidates,
                        range: sourceRange(rel.sourceLine),
                        noun: "tool",
                        help: "Declare the tool in `=== tools ===` or reference a built-in tool id.")
                ])
            }
        }
    }

    /// The relation side that is not `elementKind` (used to key a tool-backed
    /// fetch by the fixed operand's kind, and to check scalar-nav cardinality).
    func otherSide(of rel: RelationDeclaration, fromElementKind elementKind: String)
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
    func validateOperandScope(_ operand: IRExpression, scope: Set<String>?,
                                      role: String, line: Int) throws {
        guard let scope else { return }
        for root in freeIdentifierRoots(operand) where !scope.contains(scopeKey(root)) {
            throw CompilerError.diagnostics([
                Diagnostic.unresolved(
                    .commandHoleOutOfScope,
                    target: root,
                    among: Array(scope),
                    range: sourceRange(line),
                    noun: "reference in \(role)",
                    help: "Reference a workflow parameter or an earlier bind.")
            ])
        }
    }

    /// The ONLY way to build an "unknown verb form" diagnostic — every
    /// verb-form lookup miss (inline predicate, scalar navigation, description
    /// clause) funnels through here so the candidate set and "did you mean" are
    /// always structured (`MER2008`), never a bare `semanticError` string.
    func unknownVerbError(_ verbForm: String, line: Int, extraHelp: String = "") -> CompilerError {
        CompilerError.diagnostics([
            Diagnostic.unresolved(
                .unknownVerb,
                target: verbForm,
                among: symbols.verbs.values.flatMap { [$0.base, $0.thirdPerson, $0.pastParticiple] },
                range: sourceRange(line),
                noun: "verb",
                help: "Declare it with `The verb to <base> (it <3rd>, it is <participle>) means the <relation> relation.`"
                    + (extraHelp.isEmpty ? "" : " \(extraHelp)"))
        ])
    }

    /// 3B: lower an active verb condition (`the user owns the page`) to a
    /// property-backed `identifies` comparison. Tool-backed verbs can't be tested
    /// inline (they need an `await` fetch) — bind the related set first.
    func lowerVerbPredicate(subject: ExpressionAST, verbForm: String,
                                    object: ExpressionAST, scope: Set<String>? = nil,
                                    line: Int) throws -> IRExpression {
        guard let resolved = symbols.resolveVerbForm(verbForm) else {
            throw unknownVerbError(verbForm, line: line)
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
            throw semanticError(
                "verb \"\(verbForm)\" is tool-backed and cannot be tested inline. Bind the related set first (e.g. `let related be \(rel.leftKind.lowercased())s that \(resolved.verb.thirdPerson) …`).",
                line, code: .toolBackedInlineDisallowed,
                help: "Tool-backed relations require an `await` fetch — bind them with `let`/`bind` in statement position first.")
        }
    }

    struct ScalarNavPlan { let expr: IRExpression; let prelude: [IRPrimitive] }

    /// 3C: lower scalar relation navigation (`the task assigned to the user`,
    /// navigating TO `navKind`) to a single related value. Property-backed → a
    /// `member` read from the operand. Tool-backed → a single fetch-once `invoke`
    /// (hoisted into `prelude` when `allowToolFetch`), whose result IS the related
    /// value (a one-to-one tool returns the entity, not a list). The navigated-to
    /// side must be `one` — a `various` side needs `the list of …`.
    func lowerScalarTraversalPlan(base: ExpressionAST, relationForm: String, navKind: String,
                                          allowToolFetch: Bool, scope: Set<String>? = nil,
                                          line: Int) throws -> ScalarNavPlan {
        guard let resolved = symbols.resolveVerbForm(relationForm) else {
            throw unknownVerbError(relationForm, line: line,
                                   extraHelp: "Navigation forms resolve the same verb table as inline verb tests.")
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
                throw semanticError(
                    "tool-backed relation \"\(relName)\" cannot be navigated in an inline expression; bind it first (e.g. `let result be the \(navKind) \(relationForm) …`).",
                    line, code: .toolBackedInlineDisallowed,
                    help: "Scalar navigation through a tool-backed relation requires a statement-position bind first.")
            }
            // The operand is the side that is NOT navKind; key the invoke by it.
            let operandKind = navKind.lowercased() == rel.leftKind.lowercased() ? rel.rightKind : rel.leftKind
            let synth = "__nav\(IdentifierNaming.pascalCaseSplittingHyphenPreservingCase(navKind))"
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

    /// 3B/3C shared: lower a description's relation verb clauses against
    /// `elementVar`. A property-backed clause becomes an element-scoped
    /// `identifies` filter. A tool-backed clause is returned via `toolSource`
    /// when `allowToolFetch` — the caller hoists it into a fetch-once
    /// `prelude` (as `lowerDescriptionPlan` does). Quantifiers evaluate as a
    /// pure boolean expression with no prelude slot, so they pass
    /// `allowToolFetch: false` and get the same sourced "bind it first"
    /// guidance used everywhere else a tool-backed relation is referenced
    /// inline (`lowerVerbPredicate`, `lowerScalarTraversalPlan`).
    func lowerVerbClauses(_ clauses: [VerbClauseAST], elementVar: String, allowToolFetch: Bool,
                                  scope: Set<String>?, line: Int) throws
        -> (filters: [IRExpression],
            toolSource: (verbForm: String, toolID: String, operandKey: String, operand: IRExpression)?) {
        var filters: [IRExpression] = []
        var toolSource: (verbForm: String, toolID: String, operandKey: String, operand: IRExpression)? = nil
        for clause in clauses {
            guard let resolved = symbols.resolveVerbForm(clause.verbForm) else {
                throw unknownVerbError(clause.verbForm, line: line,
                                       extraHelp: "Description verb clauses resolve the same verb table as inline verb tests.")
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
                guard allowToolFetch else {
                    throw semanticError(
                        "a tool-backed relation (`\(clause.verbForm)`) cannot be filtered inline here; bind the filtered set first — e.g. `let matches be \(elementVar)s that \(clause.verbForm) …`, then use `matches`.",
                        line, code: .toolBackedInlineDisallowed,
                        help: "Quantifiers and descriptions over tool-backed relations must be bound in statement position before use in an expression.")
                }
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
        return (filters, toolSource)
    }

    /// 3C: lower a description to a fetch-once + filter + sort + take plan. A
    /// single tool-backed verb clause becomes the source (a hoisted `invoke`,
    /// returned in `prelude`); property-backed clauses, adjectives, and `whose`
    /// become element-context filters. `allowToolFetch` is false in value/condition
    /// positions that cannot host the `await` fetch.
    func lowerDescriptionPlan(_ d: DescriptionAST, allowToolFetch: Bool,
                                      scope: Set<String>? = nil, line: Int) throws -> DescriptionPlan {
        let noun = d.noun.trimmingCharacters(in: .whitespaces)
        guard !noun.isEmpty else {
            throw semanticError("description is missing a collection noun.", line)
        }
        let elementVar = lexicon.singularize(noun.lowercased())

        var prelude: [IRPrimitive] = []
        let (clauseFilters, toolSource) = try lowerVerbClauses(
            d.verbClauses, elementVar: elementVar, allowToolFetch: allowToolFetch, scope: scope, line: line)
        var filters = clauseFilters

        let collection: IRExpression
        // `lowerVerbClauses` already rejects a tool-backed clause when
        // `allowToolFetch` is false, so `toolSource` is only ever non-nil here
        // when a hoisted prelude fetch is legal.
        if let src = toolSource {
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
                              filters: filters, sort: sort, take: d.take, takeFromEnd: d.takeFromEnd),
            prelude: prelude)
    }

}
