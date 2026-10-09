import Foundation
import MeridianRuntime

// Expression / comparison / trace-query emission — extracted from
// SwiftEmitter for Phase 3 readability.

extension SwiftEmitter {

    // MARK: - Expression emission

    func emitExpr(_ expr: IRExpression) throws -> String {
        try validateExpressionForDirectEmission(expr)
        return emitExprUnchecked(expr)
    }

    func emitExprUnchecked(_ expr: IRExpression) -> String {
        switch expr {
        case .literal(let lit):
            return emitLiteral(lit)
        case .constantRef(let name):
            return "constants.\(IdentifierNaming.camelPreservingCase(name))"
        case .instanceRef(let name):
            return "instances.\(IdentifierNaming.camelPreservingCase(name))"
        case .identifierRef(let name):
            return "state.get(\"\(escapeSwiftStringLiteral(name))\")"
        case .propertyAccess(let base, let prop):
            // Property paths use camelCase end-to-end so they line up with
            // generated Swift property names *and* with the keys produced by
            // Codable's default encoding when an opaque domain value is
            // traversed by `State.get`.
            let path = propertyPath(base) + "." + IdentifierNaming.camelPreservingCase(prop)
            return "state.get(\"\(escapeSwiftStringLiteral(path))\")"
        case .comparison(let lhs, let op, let rhs):
            switch op {
            case .withinDuration:
                return "MeridianComparison.isWithin(\(emitExprUnchecked(lhs)), \(emitExprUnchecked(rhs)))"
            case .withinPast:
                return "MeridianComparison.isWithinPast(\(emitExprUnchecked(lhs)), \(emitExprUnchecked(rhs)))"
            case .withinFuture:
                return "MeridianComparison.isWithinFuture(\(emitExprUnchecked(lhs)), \(emitExprUnchecked(rhs)))"
            case .matchesPattern:
                return "meridianRegexMatches(\(emitExprUnchecked(lhs)), \(emitExprUnchecked(rhs)))"
            case .isEmpty:
                return "MeridianComparison.isEmpty(\(emitComparisonOperand(lhs)))"
            case .isNotEmpty:
                return "MeridianComparison.isNotEmpty(\(emitComparisonOperand(lhs)))"
            case .contains:
                return "(\(emitStringOperand(lhs))).contains(\(emitStringOperand(rhs)))"
            case .startsWith:
                return "(\(emitStringOperand(lhs))).hasPrefix(\(emitStringOperand(rhs)))"
            case .endsWith:
                return "(\(emitStringOperand(lhs))).hasSuffix(\(emitStringOperand(rhs)))"
            case .oneOf:
                let needle = needsValueComparison(lhs) ? "(\(emitExprUnchecked(lhs)) ?? .null)" : "(\(emitExprUnchecked(lhs)))"
                return "(\(emitExprUnchecked(rhs))).contains(\(needle))"
            case .identifies:
                return "MeridianComparison.identifies(\(emitComparisonOperand(lhs)), \(emitComparisonOperand(rhs)))"
            case .equal, .notEqual, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual:
                // Use Value-aware helpers when either side reads from state
                // (returns Value?) — Swift can't compare Optional<Value> with `<`.
                if needsValueComparison(lhs) || needsValueComparison(rhs) {
                    let helper = compHelper(op)
                    return "MeridianComparison.\(helper)(\(emitComparisonOperand(lhs)), \(emitComparisonOperand(rhs)))"
                }
                return "(\(emitExprUnchecked(lhs))) \(compOp(op)) (\(emitExprUnchecked(rhs)))"
            }
        case .logical(let op, let operands):
            switch op {
            case .and: return operands.map { "(\(emitExprUnchecked($0)))" }.joined(separator: " && ")
            case .or:  return operands.map { "(\(emitExprUnchecked($0)))" }.joined(separator: " || ")
            case .not: return "!(\(operands.first.map { emitExprUnchecked($0) } ?? "true"))"
            }
        case .envVar(let name):
            return "ProcessInfo.processInfo.environment[\"\(name)\"] ?? \"\""
        case .nowExpression:
            return "Date()"
        case .invocation(let ir):
            if ir.toolID == "runtime.discretion.decide" {
                return "try await runtime.discretion.decide(DiscretionContext(question: \(discretionQuestionExpr(ir)), snapshot: state.snapshot()))"
            }
            return emitInlineInvocationExpr(ir)
        case .relationTraversal(let base, let rel, _):
            return "\(emitExprUnchecked(base)).\(IdentifierNaming.camelPreservingCase(rel))"
        case .interpolatedString(let segs):
            // B7: Build a Swift string by concatenating literal parts and
            // stringified expression parts via `meridianStringify`.
            if segs.isEmpty { return "\"\"" }
            return "(\(interpolationParts(segs)))"
        case .definitionPredicate(let fn, let subject):
            return emitDefinitionPredicate(fn, subject: subject,
                subjectText: emitComparisonOperand(subject),
                nonOptionalSubjectText: emitNonOptionalComparisonOperand(subject))
        case .quantified(let q):
            let param = freshElementParam([:])
            return emitQuantifier(q, elementParam: param, operand: { self.emitComparisonOperand($0) },
                                  element: { e, ev in self.emitElementExpr(e, env: [ev: param]) })
        case .description(let d):
            return "Value.list(\(emitDescriptionList(d)))"
        case .aggregate(let kind, let d):
            switch kind {
            // Wrap the element count in `Decimal` so it compares against the
            // `Decimal` numeric literals produced elsewhere (`> 5`).
            case .count: return "Decimal(\(emitDescriptionList(d)).count)"
            case .list:  return "Value.list(\(emitDescriptionList(d)))"
            }
        case .superlative(let s):
            return "(\(emitSuperlativeList(s)).first)"
        case .recordList(let fields, let rows):
            return emitRecordList(fields: fields, rows: rows)
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return emitTableLookup(table: table, keyColumn: keyColumn, key: key, valueColumn: valueColumn)
        case .eventPattern:
            return "false"
        case .traceTemporal(let temporal):
            return "(\(emitTruthValueExpr(.traceTemporal(temporal))) == .true)"
        case .traceStatistical(let statistical):
            return "(\(emitTruthValueExpr(.traceStatistical(statistical))) == .true)"
        }
    }

    /// Data table → `Value.list([.record([...]), ...])`. Field names are
    /// camelCased so `for each row in <name>` property access (`row.fieldName`)
    /// resolves against the record keys.
    func emitRecordList(fields: [String], rows: [[IRExpression]]) -> String {
        let records = rows.map { row -> String in
            let pairs = zip(fields, row).map { field, cell in
                "\"\(escapeSwiftStringLiteral(IdentifierNaming.camelPreservingCase(field)))\": \(emitValueExprUnchecked(cell))"
            }.joined(separator: ", ")
            return ".record([\(pairs)])"
        }.joined(separator: ", ")
        return "Value.list([\(records)])"
    }

    func emitTableLookup(table: String, keyColumn: String, key: IRExpression, valueColumn: String) -> String {
        let tableKey = escapeSwiftStringLiteral(IdentifierNaming.camelPreservingCase(table))
        let keyField = escapeSwiftStringLiteral(IdentifierNaming.camelPreservingCase(keyColumn))
        let valueField = escapeSwiftStringLiteral(IdentifierNaming.camelPreservingCase(valueColumn))
        let keyExpr = emitComparisonOperand(key)
        return "try ({ () throws -> Value? in guard let __rows = state.get(\"\(tableKey)\")?.asList else { throw ToolError.implementation(code: \"table.lookup_miss\", message: \"table \(tableKey) is not bound\", cause: nil) }; for __row in __rows { if MeridianComparison.eq(__row.member(\"\(keyField)\"), \(keyExpr)) { return __row.member(\"\(valueField)\") } }; throw ToolError.implementation(code: \"table.lookup_miss\", message: \"no row in \(tableKey) where \(keyField) matches\", cause: nil) })()"
    }

    /// Render `expr` as a bare Swift `[Value]` array — the form a `for each`
    /// loop source or a quantifier's base collection needs. Most collection
    /// expressions (`state.get(...)` via `.identifierRef`/`.propertyAccess`)
    /// emit as `Value?`, so the general case unwraps with `?.asList ?? []`.
    /// But a noun-phrase collection that already carries its own filter/sort
    /// (`the flaky services owned by the user`) lowers to a *non-optional*
    /// `.description`/`.aggregate(.list, …)` `IRExpression` — `emitExprUnchecked`
    /// renders those as `Value.list(emitDescriptionList(d))` for the general
    /// value-expression position, but re-wrapping/re-unwrapping that here
    /// (`Value.list(...)?.asList ?? []`) is invalid Swift (optional chaining
    /// on a non-optional `Value`). Route those two cases straight to the
    /// already-`[Value]` `emitDescriptionList` pipeline instead of through
    /// the generic `Value`-returning emission.
    /// `env` (default empty) resolves an *outer* element/loop variable that
    /// the collection expression itself references — e.g. the template-loop
    /// or nested-quantifier variable a `description`'s own source noun
    /// phrase is keyed against. Threaded through so a description nested
    /// inside another element context (a template `[for each]` body, or a
    /// nested quantifier) can still see its enclosing variable; the
    /// description's *own* `elementVar` is merged in separately, in
    /// `emitDescriptionList`, only for its filter/sort clauses.
    func emitCollectionArray(_ expr: IRExpression, env: [String: String] = [:]) -> String {
        switch expr {
        case .description(let d):
            return emitDescriptionList(d, env: env)
        case .aggregate(.list, let d):
            return emitDescriptionList(d, env: env)
        case .identifierRef(let name) where env[name] != nil:
            // Bound to an outer element/loop variable: that Swift text is
            // already a non-optional `Value` (a closure parameter), so
            // `.asList` applies directly — optional-chaining it would be
            // invalid Swift.
            return "((\(emitNonOptionalElementOperand(expr, env: env))).asList ?? [])"
        case .propertyAccess(.identifierRef(let name), _) where env[name] != nil:
            return "((\(emitNonOptionalElementOperand(expr, env: env))).asList ?? [])"
        default:
            // Not resolvable through `env` (e.g. a bare `state.get(...)`
            // top-level binding): keep the original optional-chaining form
            // so unrelated golden/emitter tests don't drift in spelling.
            return "((\(emitComparisonOperand(expr)))?.asList ?? [])"
        }
    }

    /// 3C: render a description as a `[Value]` pipeline — `(coll.asList ?? [])`
    /// filtered (element context), sorted, then `prefix`-taken. Shared by the
    /// description / aggregate / superlative emitters. See `emitCollectionArray`
    /// for what `env` carries; it is merged with this description's own
    /// `elementVar` (→ `__e`) for the filter clauses only — sort/take never
    /// reference the outer variable.
    func emitDescriptionList(_ d: DescriptionIR, env: [String: String] = [:]) -> String {
        let ev = d.elementVar
        var pipeline = emitCollectionArray(d.collection, env: env)
        if !d.filters.isEmpty {
            let param = freshElementParam(env)
            let filterEnv = env.merging([ev: param]) { _, new in new }
            let parts = d.filters
                .map { "(\(emitElementExpr($0, env: filterEnv)))" }
                .joined(separator: " && ")
            pipeline += ".filter { \(param) in \(parts) }"
        }
        if let sort = d.sort {
            let key = escapeSwiftStringLiteral(sort.path)
            pipeline += ".sorted { __a, __b in MeridianComparison.orderedBefore(__a.member(\"\(key)\"), __b.member(\"\(key)\"), ascending: \(sort.ascending)) }"
        }
        if let take = d.take {
            pipeline = "Array(\(pipeline).prefix(\(take)))"
        } else if let takeEnd = d.takeFromEnd {
            pipeline = "Array(\(pipeline).suffix(\(takeEnd)))"
        }
        return pipeline
    }

    /// 3C: a superlative reuses the description pipeline but forces its own sort
    /// key/direction so `.first` is the min (ascending) or max element.
    func emitSuperlativeList(_ s: SuperlativeIR, env: [String: String] = [:]) -> String {
        let forced = DescriptionIR(collection: s.description.collection,
                                   elementVar: s.description.elementVar,
                                   filters: s.description.filters,
                                   sort: IRSortSpec(path: s.sortPath, ascending: s.ascending),
                                   take: nil)
        return emitDescriptionList(forced, env: env)
    }

    /// Emit a checkable-adjective helper. The body is rendered in element
    /// context with the subject variable bound to the `__subject` parameter, so
    /// `it`/`its <prop>` (preprocessed to `<subject>.<prop>`) becomes
    /// `__subject.member("prop")` and bare emptiness/comparisons resolve too.
    /// A `Definition:` whose lowered body requires async trace evaluation
    /// (`has ever …` / windowed / statistical trace queries, or a raw event
    /// pattern) cannot be emitted as the synchronous `private static func …
    /// -> Bool` helper `emitDefinitionFunction` produces — its body is
    /// `try await runtime.evaluateTrace(…)`, which needs `runtime`/`state` and
    /// `await`, neither available in a static, non-async helper. Wave 8
    /// event-backed adjectives (e.g. `a service is recovered if the deploy
    /// step has ever succeeded`, INFORM7 §9/§12) are only valid *inline* in a
    /// since-clause / trace context, where the emitter inlines the query into
    /// the async workflow body directly and never calls the helper. Emitting
    /// the standalone helper would ship dead, malformed Swift (see pitfall
    /// #22), so it is skipped. A bare static-predicate use of such an
    /// adjective then surfaces as a missing-symbol compile error rather than
    /// an async body smuggled into a sync function.
    func definitionRequiresAsyncTrace(_ expr: IRExpression) -> Bool {
        switch expr {
        case .traceTemporal, .traceStatistical, .eventPattern:
            return true
        case .propertyAccess(let inner, _):
            return definitionRequiresAsyncTrace(inner)
        case .relationTraversal(let inner, _, let target):
            return definitionRequiresAsyncTrace(inner) || (target.map(definitionRequiresAsyncTrace) ?? false)
        case .comparison(let lhs, _, let rhs):
            return definitionRequiresAsyncTrace(lhs) || definitionRequiresAsyncTrace(rhs)
        case .logical(_, let operands):
            return operands.contains(where: definitionRequiresAsyncTrace)
        default:
            return false
        }
    }

    /// A `Definition:` body may quantify/aggregate over a collection that is
    /// *not* the subject's own property (Gallery-3: "at least 1 critical alert
    /// whose service name is its name is fresh" — `alerts` is a separate
    /// `bind`-produced workflow variable, not `service.alerts`). Such a body,
    /// rendered by `emitElementExpr`, falls through to `emitExprUnchecked` for
    /// that bare identifier, which reads `state.get(...)` — but `state` does
    /// not exist inside `emitDefinitionFunction`'s free `private func …
    /// (_ __subjectValue: Value?) -> Bool`. `bound` tracks every identifier
    /// resolvable without `state` at this point in the tree: the definition's
    /// own subject var, plus every elementVar introduced by a quantifier/
    /// description/superlative nested inside it. Any other bare identifier
    /// (or anything inherently dynamic — an invocation, `now`, an env var, a
    /// trace query) means the body can only be emitted *inlined* at a real
    /// call site where `state` is in scope — see the `.definitionPredicate`
    /// cases in `emitExprUnchecked`/`emitElementExpr`.
    func definitionRequiresState(_ expr: IRExpression, bound: Set<String>) -> Bool {
        switch expr {
        case .identifierRef(let name):
            return !bound.contains(name)
        case .literal, .constantRef, .instanceRef:
            return false
        case .propertyAccess(let inner, _):
            return definitionRequiresState(inner, bound: bound)
        case .relationTraversal(let inner, _, let target):
            return definitionRequiresState(inner, bound: bound)
                || (target.map { definitionRequiresState($0, bound: bound) } ?? false)
        case .comparison(let lhs, _, let rhs):
            return definitionRequiresState(lhs, bound: bound) || definitionRequiresState(rhs, bound: bound)
        case .logical(_, let operands):
            return operands.contains { definitionRequiresState($0, bound: bound) }
        case .definitionPredicate(_, let subject):
            return definitionRequiresState(subject, bound: bound)
        case .quantified(let q):
            if definitionRequiresState(q.description.collection, bound: bound) { return true }
            let inner = bound.union([q.description.elementVar])
            if q.description.filters.contains(where: { definitionRequiresState($0, bound: inner) }) { return true }
            return q.body.map { definitionRequiresState($0, bound: inner) } ?? false
        case .aggregate(_, let d), .description(let d):
            if definitionRequiresState(d.collection, bound: bound) { return true }
            let inner = bound.union([d.elementVar])
            return d.filters.contains { definitionRequiresState($0, bound: inner) }
        case .superlative(let s):
            if definitionRequiresState(s.description.collection, bound: bound) { return true }
            let inner = bound.union([s.description.elementVar])
            return s.description.filters.contains { definitionRequiresState($0, bound: inner) }
        case .envVar, .nowExpression, .invocation, .interpolatedString, .recordList, .tableLookup,
             .eventPattern, .traceTemporal, .traceStatistical:
            return true
        }
    }

    func emitDefinitionFunction(_ def: LoweredDefinition) -> StringTemplate {
        let cond = emitElementExpr(def.body, env: [def.subjectVar: "__subject"])
        // Nested inside a namespace `enum`, a bare `func` is an instance
        // method and unreachable without an instance — the enum is used
        // purely as a namespace, so it must be `static` there. At true file
        // scope (no namespace) `static` would be redundant/invalid, so this
        // must match `emitConstants`'s namespace check.
        let keyword = options.namespaceEnum == nil ? "private func" : "private static func"
        return StringTemplate {
            "\(keyword) \(def.functionName)(_ __subjectValue: Value?) -> Bool {"
            "    let __subject = __subjectValue ?? .null"
            "    return \(cond)"
            "}"
        }
    }

    /// Emit a quantified description as a self-contained `Bool` IIFE.
    /// `operand` renders the source collection expression in the current
    /// context (plain → `state.get`, element → closure member access).
    func emitQuantifier(_ q: QuantifierIR, elementParam: String = "__e",
                        operand: (IRExpression) -> String,
                        element: (IRExpression, String) -> String) -> String {
        let ev = q.description.elementVar
        let filterParts = q.description.filters.map { "(\(element($0, ev)))" }
        let filterClause = filterParts.isEmpty ? "" : ".filter { \(elementParam) in \(filterParts.joined(separator: " && ")) }"
        let bodyClause = q.body.map { ".filter { \(elementParam) in \(element($0, ev)) }" } ?? ""
        // `q.description.collection` is almost always a plain `state.get(...)`-
        // shaped reference resolved via the context-appropriate `operand`
        // closure (element context threads the caller's `env`, e.g. an outer
        // subject var — see the two call sites below). The one exception is a
        // *nested* noun-phrase-as-collection (`the flaky services owned by the
        // user` used as a quantifier subject) — that already lowers to a
        // non-optional `.description`/`.aggregate(.list, …)` `IRExpression`
        // (see `emitCollectionArray`), which `operand` (built on
        // `emitComparisonOperand`/`emitElementOperand`, both `Value?`-shaped)
        // would wrap in an invalid extra `Value.list(...)?.asList`.
        let coll: String
        switch q.description.collection {
        case .description, .aggregate(.list, _):
            coll = emitCollectionArray(q.description.collection)
        default:
            coll = "(\(operand(q.description.collection))?.asList ?? [])"
        }
        let base = "\(coll)\(filterClause)"
        switch q.kind {
        case .all:
            if let body = q.body {
                return "(\(base).allSatisfy { \(elementParam) in \(element(body, ev)) })"
            }
            return "(!\(base).isEmpty)"
        case .any:
            return "(!(\(base)\(bodyClause)).isEmpty)"
        case .none:
            return "((\(base)\(bodyClause)).isEmpty)"
        case .atLeast(let n):
            return "((\(base)\(bodyClause)).count >= \(n))"
        case .atMost(let n):
            return "((\(base)\(bodyClause)).count <= \(n))"
        case .exactly(let n):
            return "((\(base)\(bodyClause)).count == \(n))"
        }
    }

    /// Render a comparison operand for `MeridianComparison.{eq,neq,lt,le,gt,ge}`,
    /// which all take `Value?`. State reads (`identifierRef` / `propertyAccess`)
    /// already return `Value?` and are passed through unchanged. Literals and
    /// constants/instances are wrapped via the same `Value`-bridging helpers
    /// used for invoke args and emit payloads, so the surrounding helper call
    /// type-checks regardless of which side the literal sits on.
    func emitComparisonOperand(_ expr: IRExpression) -> String {
        switch expr {
        case .identifierRef, .propertyAccess:
            return emitExprUnchecked(expr)
        default:
            return emitValueExprUnchecked(expr)
        }
    }

    /// Like `emitComparisonOperand`, but guarantees a non-optional `Value` —
    /// needed when the result becomes an inlined-definition `env` entry (see
    /// `emitDefinitionPredicate`), since those are dereferenced with
    /// `.member(...)`, never `?.member(...)`. `emitValueExprUnchecked`
    /// (the `default` case below) already coerces every one of its cases to a
    /// bare `Value`; only the `identifierRef`/`propertyAccess` `state.get(...)`
    /// reads need the extra `?? .null`.
    func emitNonOptionalComparisonOperand(_ expr: IRExpression) -> String {
        switch expr {
        case .identifierRef, .propertyAccess:
            return "(\(emitExprUnchecked(expr)) ?? .null)"
        default:
            return emitValueExprUnchecked(expr)
        }
    }

    /// Render an operand as a plain Swift `String` for `.contains`/
    /// `.startsWith`/`.endsWith` — the one comparison family that always
    /// wants a native `String`, never a `Value`/`Value?`, on *both* sides
    /// (`"foo" contains "f"` and `the report contains "f"` should emit the
    /// same shape either way). A `Value?`-producing operand
    /// (`needsValueComparison`) is stringified via `?.description ?? ""`;
    /// anything else (a string literal, an interpolated string, …) already
    /// renders as a raw Swift `String` via `emitExpr` and passes through
    /// unchanged. Mirrors `emitElementExpr`'s already-correct whose-clause
    /// version of the same three ops — this was the missing top-level
    /// counterpart (see IMPLEMENTATION_LOG.md: shipped as
    /// `(state.get("x")).contains(...)`, `Value?` has no member `contains`).
    func emitStringOperand(_ expr: IRExpression) -> String {
        if needsValueComparison(expr) {
            return "((\(emitExprUnchecked(expr)))?.description ?? \"\")"
        }
        return "(\(emitExprUnchecked(expr)))"
    }

    /// Like `emitExpr` but wraps the result so it satisfies `Value` in places
    /// the runtime expects a `[String: Value]` dictionary (invoke args, emit
    /// payloads). Strings, numbers, etc. become `.string(...)`/`.number(...)`;
    /// `state.get(...)` (which returns `Value?`) becomes `... ?? .null`.
    func emitValueExpr(_ expr: IRExpression) throws -> String {
        try validateExpressionForDirectEmission(expr)
        return emitValueExprUnchecked(expr)
    }

    func emitValueExprUnchecked(_ expr: IRExpression) -> String {
        switch expr {
        case .literal(let lit):
            return emitValueLiteral(lit)
        case .nowExpression:
            return ".date(Date())"
        case .identifierRef, .propertyAccess:
            return "\(emitExprUnchecked(expr)) ?? .null"
        case .constantRef, .instanceRef:
            // Typed constants & instances bridge into Value via Value.from(_:).
            return "Value.from(\(emitExprUnchecked(expr)))"
        case .envVar(let name):
            return ".string(ProcessInfo.processInfo.environment[\"\(escapeSwiftStringLiteral(name))\"] ?? \"\")"
        case .interpolatedString(let segs):
            // B7: Produce a Value.string(...) built from concatenated segments.
            if segs.isEmpty { return ".string(\"\")" }
            return ".string(\(interpolationParts(segs)))"
        case .description(let d):
            return "Value.list(\(emitDescriptionList(d)))"
        case .aggregate(let kind, let d):
            switch kind {
            case .count: return ".number(Decimal(\(emitDescriptionList(d)).count))"
            case .list:  return "Value.list(\(emitDescriptionList(d)))"
            }
        case .superlative(let s):
            return "(\(emitExprUnchecked(.superlative(s))) ?? .null)"
        case .recordList(let fields, let rows):
            return emitRecordList(fields: fields, rows: rows)
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return "(\(emitTableLookup(table: table, keyColumn: keyColumn, key: key, valueColumn: valueColumn)) ?? .null)"
        case .comparison, .logical, .definitionPredicate, .quantified:
            // These all lower to a bare Swift `Bool`, not a `Value` — bridge
            // through the same `Value.from(_:)` used for constants/instances
            // rather than the generic `.init(...)` fallback (which requires
            // the wrapped expression to already be `Value`-typed).
            return "Value.from(\(emitExprUnchecked(expr)))"
        case .traceTemporal, .traceStatistical:
            return "Value.from(\(emitTruthValueExpr(expr)) == .true)"
        case .invocation:
            return emitExprUnchecked(expr)
        default:
            // For derived expressions we rely on the runtime `Value(...)` init,
            // wrapping the bare emission so it survives Swift type-checking.
            return ".init(\(emitExprUnchecked(expr)))"
        }
    }

    func emitInlineInvocationExpr(_ ir: InvokeIR) -> String {
        let args = ir.arguments
            .map { "\"\(escapeSwiftStringLiteral($0.key))\": \(emitValueExprUnchecked($0.value))" }
            .joined(separator: ", ")
        return "try await runtime.invoke(tool: \"\(escapeSwiftStringLiteral(ir.toolID))\", args: [\(args)])"
    }

    /// The ` + `-joined Swift fragments of an interpolated string's segments.
    /// Shared by the plain (`emitExpr`) and Value-wrapped (`emitValueExpr`)
    /// interpolation emitters, which differ only in the empty-case literal and
    /// the wrapper they place around this body.
    func interpolationParts(_ segs: [IRInterpolationSegment]) -> String {
        segs.map { seg -> String in
            switch seg {
            case .literal(let s):
                return "\"\(escapeSwiftStringLiteral(s))\""
            case .expression(let e):
                return "meridianStringify(\(emitValueExprUnchecked(e)))"
            case .formatted(let e, let f):
                return "meridianFormat(\(emitValueExprUnchecked(e)), as: \"\(escapeSwiftStringLiteral(f))\")"
            case .conditional(let condition, let thenSegs, let elseSegs):
                return "({ () -> String in if \(emitExprUnchecked(condition)) { return \(interpolationParts(thenSegs)) } else { return \(interpolationParts(elseSegs)) } })()"
            case .forEach(let variable, let collection, let body):
                let coll = emitCollectionArray(collection)
                return "({ () -> String in var __out = \"\"; for __item in \(coll) { __out += \(interpolationParts(body, loopVariable: variable, elementName: "__item")) }; return __out })()"
            case .shellEscapedExpression(let e):
                return "meridianShellQuote(\(emitValueExprUnchecked(e)))"
            }
        }.joined(separator: " + ")
    }

    func expressionMayBeIndeterminate(_ expr: IRExpression) -> Bool {
        switch expr {
        case .traceTemporal(let temporal):
            if case .sinceLast = temporal.kind { return true }
            if case .boundedFutureMonitor = temporal.kind { return true }
            return false
        case .traceStatistical:
            return true
        case .logical(_, let operands):
            return operands.contains(where: expressionMayBeIndeterminate)
        case .comparison(let lhs, _, let rhs):
            return expressionMayBeIndeterminate(lhs) || expressionMayBeIndeterminate(rhs)
        case .propertyAccess(let base, _):
            return expressionMayBeIndeterminate(base)
        default:
            return false
        }
    }

    func emitTruthValueExpr(_ expr: IRExpression) -> String {
        switch expr {
        case .traceTemporal(let temporal):
            return "try await runtime.evaluateTrace(\(emitTraceTemporalQuery(temporal)), evaluationInstant: await runtime.currentDate())"
        case .traceStatistical(let statistical):
            return "try await runtime.evaluateTrace(\(emitTraceStatisticalQuery(statistical)), evaluationInstant: await runtime.currentDate())"
        case .logical(let op, let operands):
            switch op {
            case .and:
                let items = operands.map(emitTruthValueExpr)
                guard let first = items.first else { return ".true" }
                return items.dropFirst().reduce(first) { partial, next in "(\(partial)).and(\(next))" }
            case .or:
                let items = operands.map(emitTruthValueExpr)
                guard let first = items.first else { return ".false" }
                return items.dropFirst().reduce(first) { partial, next in "(\(partial)).or(\(next))" }
            case .not:
                return "(\(operands.first.map(emitTruthValueExpr) ?? ".true")).not()"
            }
        default:
            return "TruthValue.from(\(emitExprUnchecked(expr)))"
        }
    }

    func emitTraceTemporalQuery(_ temporal: TraceTemporalIR) -> String {
        let scope = emitTraceScope(temporal.scope)
        let scopeSkills = emitTraceScopeSkills(temporal.scope)
        let kind: String
        switch temporal.kind {
        case .ever(let pattern):
            kind = ".ever(\(emitTraceEventPattern(pattern, subjectKeyExpr: temporal.subjectKeyExpr)))"
        case .withinWindow(let pattern, let duration):
            kind = ".withinWindow(\(emitTraceEventPattern(pattern, subjectKeyExpr: temporal.subjectKeyExpr)), duration: .seconds(\(duration.components.seconds)))"
        case .countInWindow(let pattern, let comparator, let duration):
            let comparatorExpr: String
            switch comparator {
            case .atLeast(let value):
                comparatorExpr = ".atLeast(\(value))"
            case .atMost(let value):
                comparatorExpr = ".atMost(\(value))"
            case .exactly(let value):
                comparatorExpr = ".exactly(\(value))"
            }
            kind = ".countInWindow(\(emitTraceEventPattern(pattern, subjectKeyExpr: temporal.subjectKeyExpr)), comparator: \(comparatorExpr), duration: .seconds(\(duration.components.seconds)))"
        case .inARow(let pattern, let count):
            kind = ".inARow(\(emitTraceEventPattern(pattern, subjectKeyExpr: temporal.subjectKeyExpr)), count: \(count))"
        case .sinceLast(let anchor, let holds, let holdsPattern, let usesStateHistory):
            if usesStateHistory, holdsPattern == nil {
                let predicateJSON = emitStatePredicateJSON(holds)
                kind = ".sinceLast(anchor: \(emitTraceEventPattern(anchor, subjectKeyExpr: temporal.subjectKeyExpr)), holds: nil, holdsStatePredicateJSON: \(predicateJSON), holdsUsesStateHistory: true)"
            } else if let holdsPattern {
                kind = ".sinceLast(anchor: \(emitTraceEventPattern(anchor, subjectKeyExpr: temporal.subjectKeyExpr)), holds: \(emitTraceEventPattern(holdsPattern, subjectKeyExpr: temporal.subjectKeyExpr)), holdsStatePredicateJSON: nil, holdsUsesStateHistory: false)"
            } else {
                kind = ".sinceLast(anchor: \(emitTraceEventPattern(anchor, subjectKeyExpr: temporal.subjectKeyExpr)), holds: nil, holdsStatePredicateJSON: nil, holdsUsesStateHistory: false)"
            }
        case .boundedFutureMonitor(let condition, let horizon, let mode):
            let modeExpr = mode == .eventuallyWithin ? ".eventuallyWithin" : ".alwaysFor"
            kind = ".boundedFutureMonitor(conditionJSON: \(emitBoundedFutureConditionJSON(condition)), horizon: .seconds(\(horizon.components.seconds)), mode: \(modeExpr))"
        }
        return "TraceTemporalQuery(scope: \(scope), scopeSkills: \(scopeSkills), kind: \(kind))"
    }

    func emitTraceScope(_ scope: TraceScope) -> String {
        switch scope {
        case .currentRun: return ".currentRun"
        case .acrossAllRuns: return ".acrossAllRuns"
        case .acrossSkills(let skills):
            let quoted = skills.map { "\"\(escapeSwiftStringLiteral($0))\"" }.joined(separator: ", ")
            return ".acrossSkills"
        }
    }

    func emitTraceScopeSkills(_ scope: TraceScope) -> String {
        if case .acrossSkills(let skills) = scope {
            let quoted = skills.map { "\"\(escapeSwiftStringLiteral($0))\"" }.joined(separator: ", ")
            return "[\(quoted)]"
        }
        return "[]"
    }

    func emitStatePredicateJSON(_ expr: IRExpression) -> String {
        if case .comparison(let lhs, .equal, let rhs) = expr,
           case .identifierRef(let name) = lhs,
           case .literal(.string(let value)) = rhs {
            return "\"{\\\"\\(escapeSwiftStringLiteral(name))\\\": \\\"\(escapeSwiftStringLiteral(value))\\\"}\""
        }
        return "\"{}\""
    }

    func emitBoundedFutureConditionJSON(_ expr: IRExpression) -> String {
        if case .traceTemporal(let temporal) = expr,
           case .ever(let pattern) = temporal.kind,
           !pattern.negated {
            let subjectType: String
            let subjectName: String
            switch pattern.subject {
            case .step(let name):
                subjectType = "step"
                subjectName = name
            case .named(let name):
                subjectType = "named"
                subjectName = name
            }
            return "\"{\\\"kind\\\":\\\"event\\\",\\\"subject\\\":{\\\"type\\\":\\\"\(escapeSwiftStringLiteral(subjectType))\\\",\\\"name\\\":\\\"\(escapeSwiftStringLiteral(subjectName))\\\"},\\\"outcome\\\":\\\"\(escapeSwiftStringLiteral(pattern.outcome.rawValue))\\\"}\""
        }
        if case .comparison(let lhs, .equal, let rhs) = expr,
           case .identifierRef(let name) = lhs,
           case .literal(.string(let value)) = rhs {
            return "\"{\\\"kind\\\":\\\"state\\\",\\\"fields\\\":{\\\"\\(escapeSwiftStringLiteral(name))\\\":\\\"\(escapeSwiftStringLiteral(value))\\\"}}\""
        }
        return "\"{}\""
    }

    func emitTraceStatisticalQuery(_ statistical: TraceStatisticalIR) -> String {
        let scope = emitTraceScope(statistical.scope)
        let scopeSkills = emitTraceScopeSkills(statistical.scope)
        let subject: String
        switch statistical.pattern.subject {
        case .step(let name):
            subject = ".step(\"\(escapeSwiftStringLiteral(name))\")"
        case .named(let name):
            subject = ".named(\"\(escapeSwiftStringLiteral(name))\")"
        }
        let outcome: String = statistical.outcome == .succeeds ? ".succeeded" : ".failed"
        let bound: String
        switch statistical.bound {
        case .atLeast(let ratio):
            bound = ".atLeast(\(ratio))"
        case .atMost(let ratio):
            bound = ".atMost(\(ratio))"
        }
        let denominator = statistical.denominator == .runs ? ".runs" : ".occurrences"
        let window = statistical.window.map { ".seconds(\($0.components.seconds))" } ?? "nil"
        let confidence = statistical.confidencePercent.map { String($0) } ?? "nil"
        return """
TraceStatisticalQuery(
    scope: \(scope),
    scopeSkills: \(scopeSkills),
    pattern: TraceEventPatternQuery(subject: \(subject), outcome: \(outcome), subjectKey: \(statistical.subjectKeyExpr.map { "meridianStringify(\(emitValueExprUnchecked($0)))" } ?? "nil"), payloadContains: \(emitPayloadContains(statistical.pattern.payloadPredicate))),
    bound: \(bound),
    denominator: \(denominator),
    window: \(window),
    confidencePercent: \(confidence)
)
"""
    }

    func emitTraceEventPattern(_ pattern: EventPatternIR, subjectKeyExpr: IRExpression?) -> String {
        let subject: String
        switch pattern.subject {
        case .step(let name):
            subject = ".step(\"\(escapeSwiftStringLiteral(name))\")"
        case .named(let name):
            subject = ".named(\"\(escapeSwiftStringLiteral(name))\")"
        }
        let outcome = "." + pattern.outcome.rawValue
        let subjectKey: String
        if let subjectKeyExpr {
            subjectKey = "meridianStringify(\(emitValueExprUnchecked(subjectKeyExpr)))"
        } else {
            subjectKey = "nil"
        }
        return "TraceEventPatternQuery(subject: \(subject), outcome: \(outcome), subjectKey: \(subjectKey), payloadContains: \(emitPayloadContains(pattern.payloadPredicate)), negated: \(pattern.negated))"
    }

    /// `whose <field> is <value>` (cookbook 17) lowers to a single-key
    /// `[String: Value]` dictionary literal matching
    /// `TraceEventPatternQuery.payloadContains`'s runtime shape. `ASTToIR`
    /// already restricts the predicate to `<identifier> is <literal>`
    /// (`payloadFieldName`/`validatePayloadField`), so this only needs to
    /// recognize that one shape, not a general comparison.
    func emitPayloadContains(_ predicate: IRExpression?) -> String {
        guard let predicate,
              case .comparison(let lhs, .equal, let rhs) = predicate,
              case .identifierRef(let field) = lhs else {
            return "nil"
        }
        return "[\"\(escapeSwiftStringLiteral(field))\": \(emitValueExprUnchecked(rhs))]"
    }

    func interpolationParts(_ segs: [IRInterpolationSegment], loopVariable: String, elementName: String) -> String {
        segs.map { seg -> String in
            switch seg {
            case .literal(let s):
                return "\"\(escapeSwiftStringLiteral(s))\""
            case .expression(let e):
                return "meridianStringify(\(emitLoopValueExpr(e, loopVariable: loopVariable, elementName: elementName)))"
            case .formatted(let e, let f):
                return "meridianFormat(\(emitLoopValueExpr(e, loopVariable: loopVariable, elementName: elementName)), as: \"\(escapeSwiftStringLiteral(f))\")"
            case .conditional(let condition, let thenSegs, let elseSegs):
                return "({ () -> String in if \(emitLoopBoolExpr(condition, loopVariable: loopVariable, elementName: elementName)) { return \(interpolationParts(thenSegs, loopVariable: loopVariable, elementName: elementName)) } else { return \(interpolationParts(elseSegs, loopVariable: loopVariable, elementName: elementName)) } })()"
            case .forEach:
                return "\"\""
            case .shellEscapedExpression(let e):
                return "meridianShellQuote(\(emitLoopValueExpr(e, loopVariable: loopVariable, elementName: elementName)))"
            }
        }.joined(separator: " + ")
    }

    func emitLoopValueExpr(_ e: IRExpression, loopVariable: String, elementName: String) -> String {
        switch e {
        case .identifierRef(let name) where name == loopVariable:
            return elementName
        case .identifierRef(let name) where name.hasPrefix(loopVariable + "."):
            let path = String(name.dropFirst(loopVariable.count + 1))
            return "\(elementName).member(\"\(escapeSwiftStringLiteral(IdentifierNaming.camelPreservingCase(path)))\") ?? .null"
        case .propertyAccess(.identifierRef(let name), let prop) where name == loopVariable:
            return "\(elementName).member(\"\(escapeSwiftStringLiteral(IdentifierNaming.camelPreservingCase(prop)))\") ?? .null"
        default:
            // Anything more than a direct reference/property read on the loop
            // variable (an aggregate/description/quantifier that itself
            // *references* the loop variable somewhere inside — e.g. `the
            // number of alerts whose service name is its name` inside a
            // `[for each service in …]` body) needs the loop variable
            // resolvable throughout its own nested filters/elements too, not
            // just at this top level — route through the env-threaded element
            // emitter instead of the env-blind `emitValueExprUnchecked`.
            return emitElementValueExpr(e, env: [loopVariable: elementName])
        }
    }

    func emitLoopBoolExpr(_ e: IRExpression, loopVariable: String, elementName: String) -> String {
        switch e {
        case .comparison(let l, let op, let r):
            return emitLoopComparison(l, op, r, loopVariable: loopVariable, elementName: elementName)
        default:
            return emitElementExpr(e, env: [loopVariable: elementName])
        }
    }

    /// Exhaustive over `ComparisonOp` (17 cases) — mirrors `emitElementExpr`'s
    /// `whose`-clause comparison switch, adapted to `emitLoopValueExpr`'s
    /// always-`Value` (never native/never-optional) operand emission. This
    /// replaces a bug where every op funnelled through `compHelper`, whose
    /// `default:` silently degraded any non-relational op (`contains`,
    /// `oneOf`, `isEmpty`, `matchesPattern`, `identifies`, `within*`) to an
    /// equality check — a silent-wrong-codegen gap (no compile error, wrong
    /// runtime semantics). Being exhaustive (no `default:`) means a future
    /// `ComparisonOp` case fails to compile here until wired, instead of
    /// silently reusing `eq`.
    func emitLoopComparison(
        _ l: IRExpression, _ op: ComparisonOp, _ r: IRExpression,
        loopVariable: String, elementName: String
    ) -> String {
        func lv(_ e: IRExpression) -> String { emitLoopValueExpr(e, loopVariable: loopVariable, elementName: elementName) }
        let lhs = lv(l)
        switch op {
        case .withinDuration: return "MeridianComparison.isWithin(\(lhs), \(emitExprUnchecked(r)))"
        case .withinPast:     return "MeridianComparison.isWithinPast(\(lhs), \(emitExprUnchecked(r)))"
        case .withinFuture:   return "MeridianComparison.isWithinFuture(\(lhs), \(emitExprUnchecked(r)))"
        case .matchesPattern: return "meridianRegexMatches(\(lhs), \(emitExprUnchecked(r)))"
        case .isEmpty:        return "MeridianComparison.isEmpty(\(lhs))"
        case .isNotEmpty:     return "MeridianComparison.isNotEmpty(\(lhs))"
        case .identifies:     return "MeridianComparison.identifies(\(lhs), \(lv(r)))"
        case .equal, .notEqual, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual:
            return "MeridianComparison.\(compHelper(op))(\(lhs), \(lv(r)))"
        case .contains:       return "(\(lhs).description).contains(\(emitExprUnchecked(r)))"
        case .startsWith:     return "(\(lhs).description).hasPrefix(\(emitExprUnchecked(r)))"
        case .endsWith:       return "(\(lhs).description).hasSuffix(\(emitExprUnchecked(r)))"
        case .oneOf:          return "(\(emitExprUnchecked(r))).contains(\(lhs))"
        }
    }

    /// Wrap an IRLiteral for use in `[String: Value]`.
    func emitValueLiteral(_ lit: IRLiteral) -> String {
        switch lit {
        case .string(let s):              return ".string(\"\(escapeSwiftStringLiteral(s))\")"
        case .number(let n):              return ".number(Decimal(\(n)))"
        case .boolean(let b):             return ".boolean(\(b))"
        case .money(let a, let c):        return ".money(Money(amount: Decimal(\(a)), currency: \"\(c)\"))"
        case .duration(let d):            return ".duration(Duration.seconds(\(d.components.seconds)))"
        case .date(let d):                return ".date(Date(timeIntervalSince1970: \(d.timeIntervalSince1970)))"
        case .dateTime(let d):            return ".date(Date(timeIntervalSince1970: \(d.timeIntervalSince1970)))"
        case .enumValue(let v, _):        return ".string(\"\(v)\")"
        case .calendarAmount(let amount):
            return ".record([\"magnitude\": .number(Decimal(\(amount.magnitude))), \"unit\": .string(\"\(amount.unit.rawValue)\")])"
        }
    }

    func discretionQuestionExpr(_ ir: InvokeIR) -> String {
        guard let question = ir.arguments.first(where: { $0.key == "question" })?.value else {
            return "\"\""
        }
        switch question {
        case .literal(.string(let s)):
            return "\"\(escapeSwiftStringLiteral(s))\""
        case .interpolatedString:
            return emitExprUnchecked(question)
        default:
            return "meridianStringify(\(emitValueExprUnchecked(question)))"
        }
    }

    func emitLiteral(_ lit: IRLiteral) -> String {
        switch lit {
        case .string(let s):              return "\"\(escapeSwiftStringLiteral(s))\""
        case .number(let n):              return "Decimal(\(n))"
        case .boolean(let b):             return b ? "true" : "false"
        case .money(let a, let c):        return "Money(amount: Decimal(\(a)), currency: \"\(c)\")"
        case .duration(let d):            return "Duration.seconds(\(d.components.seconds))"
        case .date(let d):                return "Date(timeIntervalSince1970: \(d.timeIntervalSince1970))"
        case .dateTime(let d):            return "Date(timeIntervalSince1970: \(d.timeIntervalSince1970))"
        case .enumValue(let v, let kind): return "\(kind).\(v)"
        case .calendarAmount(let amount):
            return "\"\(amount.magnitude) \(amount.unit.rawValue)\""
        }
    }

    func propertyPath(_ expr: IRExpression) -> String {
        switch expr {
        case .identifierRef(let name):      return name
        case .propertyAccess(let b, let p): return propertyPath(b) + "." + IdentifierNaming.camelPreservingCase(p)
        default:                            return emitExprUnchecked(expr)
        }
    }

    func validateExpressionForDirectEmission(_ expr: IRExpression) throws {
        do {
            try IRValidator.validate(expr, sourceFile: options.sourceFileName)
        } catch IRValidationError.diagnostics(let diagnostics) {
            throw CompilerError.diagnostics(diagnostics)
        }
    }

    /// Callers gate on the 6 relational ops before calling this (the
    /// exhaustive `.comparison` switches in `emitExpr`/`emitLoopComparison`
    /// only reach `compOp` from that arm), so `default:` is UNREACHABLE
    /// today. Hardened rather than silently formatting a bogus operator
    /// comment (MER0004-class defensive guard; no behavior change for any
    /// currently-reachable op).
    func compOp(_ op: ComparisonOp) -> String {
        switch op {
        case .equal:          return "=="
        case .notEqual:       return "!="
        case .lessThan:       return "<"
        case .lessOrEqual:    return "<="
        case .greaterThan:    return ">"
        case .greaterOrEqual: return ">="
        default:
            preconditionFailure("internal: compOp(\(op)) called with a non-relational op — MER0004 (compiler bug: all callers must gate on the 6 relational ops)")
        }
    }

    /// Map a comparison op to the corresponding `MeridianComparison.X` helper
    /// name. Same unreachable-`default:` guarantee as `compOp` (see above).
    func compHelper(_ op: ComparisonOp) -> String {
        switch op {
        case .equal:          return "eq"
        case .notEqual:       return "neq"
        case .lessThan:       return "lt"
        case .lessOrEqual:    return "le"
        case .greaterThan:    return "gt"
        case .greaterOrEqual: return "ge"
        default:
            preconditionFailure("internal: compHelper(\(op)) called with a non-relational op — MER0004 (compiler bug: all callers must gate on the 6 relational ops)")
        }
    }

    /// True when an expression resolves to `state.get(...)` (Value?), which
    /// Swift can't compare with `<` / `>` / `==` directly.
    func needsValueComparison(_ expr: IRExpression) -> Bool {
        switch expr {
        case .identifierRef, .propertyAccess: return true
        // 3C: a superlative is a `Value?`; a `.list` aggregate / description is a
        // `Value`. A `.count` aggregate is a bare `Int` and compares directly.
        case .superlative, .description:      return true
        case .aggregate(let kind, _):         return kind == .list
        default:                              return false
        }
    }

    func emitPattern(_ p: IRPattern) -> String {
        switch p {
        case .literal(let lit):         return emitLiteral(lit)
        case .enumValue(let v, _):      return ".\(v)"
        case .wildcard:                 return "default"
        }
    }

    func patternTraceName(_ p: IRPattern) -> String {
        switch p {
        case .literal(let lit): return "literal(\(lit))"
        case .enumValue(let value, let kind): return kind.isEmpty ? "enum(\(value))" : "enum(\(kind).\(value))"
        case .wildcard: return "wildcard"
        }
    }

}
