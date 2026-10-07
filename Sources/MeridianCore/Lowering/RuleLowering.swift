import Foundation
import MeridianRuntime

// MARK: - ParsedRule

/// A rule classified from RuleAST text into a strongly-typed variant that
/// the RuleInjector can act on without re-parsing the text.
public enum ParsedRule: Sendable {
    case invariant(
        subjectKind: String,
        subjectFilter: ExpressionAST?,
        forbiddenActionText: String,
        sourceLine: Int,
        originalText: String
    )
    case parameterGuard(
        subjectKind: String,
        actionText: String,
        predicate: ExpressionAST,
        sourceLine: Int,
        originalText: String
    )
    case precondition(
        subjectKind: String,
        subjectFilter: ExpressionAST?,
        actionText: String,
        gate: GateKind,
        sourceLine: Int,
        originalText: String
    )
    case trigger(
        conditionText: String,
        actionText: String,
        sourceLine: Int,
        originalText: String
    )
    /// A `When <condition>, <action>` rule whose condition structurally
    /// names a real, checkable predicate (comparison, emptiness/temporal-
    /// window check, duration mention, quantifier, relation traversal,
    /// description, aggregate, superlative, table lookup, or declared-verb
    /// predicate) rather than opaque externally-raised-event prose. `.trigger`
    /// compiles to an external-event stub with no scheduler/poller to
    /// re-evaluate such a predicate — see `isSelfEvaluatingTriggerCondition`.
    /// `RuleInjector.synthesizeTriggers` raises `MER3017` for this case
    /// instead of silently minting a `trigger.<opaque>.fired` event that
    /// would never fire.
    case unsupportedTriggerCondition(
        conditionText: String,
        actionText: String,
        sourceLine: Int,
        originalText: String
    )
    case permission(
        subjectKind: String,
        subjectFilter: ExpressionAST?,
        allowedActionText: String,
        conditions: ExpressionAST?,
        isBounded: Bool,
        sourceLine: Int,
        originalText: String
    )
    case deonticProhibition(norm: NormIR)
    case deonticObligation(norm: NormIR)
    case deonticPermission(norm: NormIR)
}

public enum GateKind: Sendable {
    case approval(by: String)
    case event(named: String)
}

// MARK: - RuleAnalyzer

/// Classifies a `RuleAST` text string into a typed `ParsedRule` using
/// structural pattern matching on natural-language constructs.
public struct RuleAnalyzer {

    public let lexicon: EnglishLexicon
    private let exprParser: ExpressionParser
    private let trace: ParserTrace

    /// `symbols` has no default — every caller must decide explicitly.
    /// Every real pipeline call site (`Compiler.compile`, `ASTToIR.lower`,
    /// `SkillSectionBuilder`, `SkillMigrator`'s rule-aware classifier hook)
    /// passes its already-built `SymbolTable`; only synthetic unit tests that
    /// exercise pure shape-matching pass `nil` explicitly. Without a table,
    /// `exprParser` can only recognize literals/comparisons/bare identifiers;
    /// a filter/predicate clause shaped like a relation traversal, quantifier,
    /// aggregate, superlative, or declared-verb predicate degrades to a bare
    /// identifier or a naive word-split guess instead of its real
    /// `ExpressionAST` form — see `buildSubjectFilter`'s use of `exprParser`
    /// below and `corpora/GENERATING_A_CORPUS.md` gotcha #7. `ExpressionParser`
    /// only ever reads `symbols` (`kinds`/`resolveVerbForm`/…) to resolve
    /// lookups during parsing — never mutates it — so sharing the live,
    /// already-fully-populated table here has no ordering/side-effect risk.
    public init(
        lexicon: EnglishLexicon = .default,
        trace: ParserTrace = .shared,
        symbols: SymbolTable?
    ) {
        self.lexicon = lexicon
        self.trace = trace
        self.exprParser = ExpressionParser(symbols: symbols, trace: trace, lexicon: lexicon)
    }

    /// True when `text` has the shape a genuine Phase-8 rule sentence starts
    /// with: a leading parameter article ("A"/"An"/"The …") or the `when `
    /// trigger prefix — the exact same gate `MeridianParser`'s flat
    /// (heading-less) top-level rule extraction has always used. `classify`
    /// itself is intentionally loose (`mustNotMarker`/`mayMarker`/`byMarker`
    /// etc. are unanchored substring matches, so a rule's own subject/action
    /// clauses can contain the marker anywhere), which makes it unsafe to
    /// trial against arbitrary narrative — an unrelated sentence merely
    /// mentioning "may" ("the file may exist outside the indexed brain") can
    /// spuriously satisfy `classifyPermission`. Callers that trial-classify
    /// prose outside the flat top-level loop (`SkillSectionBuilder`'s
    /// sectioned-rule extraction, `SkillMigrator`'s rule-aware classifier
    /// hook) must gate on this shape check FIRST, exactly like the flat path
    /// always has, before calling `classify`.
    public func looksLikeRuleShapedSentence(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        let startsWithParameterArticle = lexicon.findEarliestArticle(t)?
            .intro.trimmingCharacters(in: .whitespaces).isEmpty == true
        return startsWithParameterArticle || t.lowercased().hasPrefix(lexicon.grammar.topLevelRulePrefix)
    }

    /// Reject non-norm modals and outcome-as-action phrasing before shape classification.
    public func deonticRejection(for rule: RuleAST, sourceFile: String) -> Diagnostic? {
        guard let base = DeonticLowering.deonticRejectionDiagnostic(for: rule.text, lexicon: lexicon) else {
            return nil
        }
        return Diagnostic.error(
            base.code,
            message: base.message,
            range: SourceRange(file: sourceFile, line: rule.sourceLine, column: 0),
            help: base.help)
    }

    /// Classify a single RuleAST into a typed ParsedRule. Returns nil if the
    /// rule text does not match any known pattern. Throws when a matched
    /// deontic norm carries a condition that cannot be lowered to checkable IR.
    public func classify(_ rule: RuleAST) throws -> ParsedRule? {
        let text = rule.text.trimmingCharacters(in: .whitespaces)
        let lower = text.lowercased()
        let markers = lexicon.grammar.ruleMarkers
        trace.log(.lowering, "classify rule @L\(rule.sourceLine): \(ParserTrace.short(text))")

        if let obligation = try classifyDeonticObligation(text, rule: rule) {
            trace.log(.lowering, "  → deontic obligation")
            return obligation
        }

        // TRIGGER: "When ..."
        if lower.hasPrefix(markers.whenPrefix) {
            trace.log(.lowering, "  → trigger")
            return classifyTrigger(text, rule: rule)
        }

        // PRECONDITION: "... must be <participle> by <role> before ..."
        if lower.contains(markers.mustBeMarker)
            && lower.contains(markers.byMarker)
            && lower.contains(markers.beforeMarker) {
            trace.log(.lowering, "  → precondition")
            return classifyPrecondition(text, rule: rule)
        }

        // INVARIANT / PARAMETER GUARD: "... must not ..."
        if lower.contains(markers.mustNotMarker) {
            if let prohibition = try classifyDeonticProhibition(text, rule: rule) {
                trace.log(.lowering, "  → deontic prohibition (invoke)")
                return prohibition
            }
            trace.log(.lowering, "  → must-not (invariant/parameter-guard)")
            return classifyMustNot(text, rule: rule)
        }

        // PERMISSION: "... may ..."
        if lower.contains(markers.mayMarker) {
            if let permission = try classifyDeonticPermission(text, rule: rule) {
                trace.log(.lowering, "  → deontic permission (invoke)")
                return permission
            }
            trace.log(.lowering, "  → permission")
            return classifyPermission(text, rule: rule)
        }

        trace.log(.lowering, "  → unclassified")
        return nil
    }

    // MARK: - Deontic invoke / obligation shapes

    private func classifyDeonticObligation(_ text: String, rule: RuleAST) throws -> ParsedRule? {
        let markers = lexicon.grammar.ruleMarkers
        guard let holdRange = text.range(of: markers.mustHoldMarker, options: [.caseInsensitive]) else {
            return nil
        }
        var conditionText = String(text[text.startIndex..<holdRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        if conditionText.hasSuffix(".") { conditionText = String(conditionText.dropLast()) }
        guard !conditionText.isEmpty else { return nil }

        var blocking = false
        var tail = String(text[holdRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        if tail.hasSuffix(".") { tail = String(tail.dropLast()) }
        for suffix in markers.blockingSuffixes where tail.lowercased() == suffix.trimmingCharacters(in: .whitespaces) {
            blocking = true
        }

        let sr = SourceRange(file: "", line: rule.sourceLine, column: 0)
        let condition = try lowerExprForDeontic(exprParser.parse(conditionText), sourceRange: sr)
        let norm = NormIR(
            id: DeonticLowering.normID(sourceLine: rule.sourceLine, kind: .obligation),
            kind: .obligation,
            scope: .skill,
            actionPattern: nil,
            condition: condition,
            blocking: blocking,
            sourceRange: sr,
            originalText: rule.text
        )
        return .deonticObligation(norm: norm)
    }

    private func classifyDeonticProhibition(_ text: String, rule: RuleAST) throws -> ParsedRule? {
        let markers = lexicon.grammar.ruleMarkers
        guard let mustNotRange = text.range(of: markers.mustNotMarker, options: [.caseInsensitive]) else {
            return nil
        }
        let subjectPart = String(text[text.startIndex..<mustNotRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var actionText = String(text[mustNotRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        if actionText.hasSuffix(".") { actionText = String(actionText.dropLast()) }

        guard let pattern = try DeonticLowering.parseInvokeActionPattern(
            actionText, exprParser: exprParser, lexicon: lexicon) else { return nil }

        let (subjectKind, _, _) = parseSubject(subjectPart)
        let scope: NormScope = subjectKind.isEmpty ? .skill : .kind(subjectKind)
        let sr = SourceRange(file: "", line: rule.sourceLine, column: 0)
        let norm = NormIR(
            id: DeonticLowering.normID(sourceLine: rule.sourceLine, kind: .prohibition),
            kind: .prohibition,
            scope: scope,
            actionPattern: pattern,
            condition: nil,
            blocking: actionText.lowercased().contains(markers.blockingSpaceSuffix.trimmingCharacters(in: .whitespaces)),
            sourceRange: sr,
            originalText: rule.text
        )
        return .deonticProhibition(norm: norm)
    }

    private func classifyDeonticPermission(_ text: String, rule: RuleAST) throws -> ParsedRule? {
        let markers = lexicon.grammar.ruleMarkers
        guard let mayRange = text.range(of: markers.mayMarker, options: [.caseInsensitive]) else {
            return nil
        }
        let subjectPart = String(text[text.startIndex..<mayRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var actionText = String(text[mayRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        if actionText.hasSuffix(".") { actionText = String(actionText.dropLast()) }

        var conditionExpr: IRExpression? = nil
        if let onlyWhere = actionText.range(of: markers.onlyWhereMarker, options: [.caseInsensitive]) {
            let condText = String(actionText[onlyWhere.upperBound...]).trimmingCharacters(in: .whitespaces)
            actionText = String(actionText[actionText.startIndex..<onlyWhere.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let sr = SourceRange(file: "", line: rule.sourceLine, column: 0)
            conditionExpr = try lowerExprForDeontic(exprParser.parse(condText), sourceRange: sr)
        }

        guard let pattern = try DeonticLowering.parseInvokeActionPattern(
            actionText, exprParser: exprParser, lexicon: lexicon) else { return nil }

        var constraints = pattern.argumentConstraints
        if constraints.isEmpty, let onlyWhereExpr = conditionExpr {
            constraints = [ActionArgumentConstraint(path: "_where", op: .equal, value: onlyWhereExpr)]
        }

        let (subjectKind, _, _) = parseSubject(subjectPart)
        let scope: NormScope = subjectKind.isEmpty ? .skill : .kind(subjectKind)
        let sr = SourceRange(file: "", line: rule.sourceLine, column: 0)
        let norm = NormIR(
            id: DeonticLowering.normID(sourceLine: rule.sourceLine, kind: .permission),
            kind: .permission,
            scope: scope,
            actionPattern: ActionPatternIR(toolID: pattern.toolID, argumentConstraints: constraints),
            condition: conditionExpr,
            blocking: false,
            sourceRange: sr,
            originalText: rule.text
        )
        return .deonticPermission(norm: norm)
    }

    private func lowerExprForDeontic(_ expr: ExpressionAST, sourceRange: SourceRange) throws -> IRExpression {
        try DeonticLowering.lowerCheckableDeonticExpr(
            expr,
            sourceRange: sourceRange,
            symbols: exprParser.symbols)
    }

    // MARK: - Trigger

    private func classifyTrigger(_ text: String, rule: RuleAST) -> ParsedRule? {
        let lower = text.lowercased()
        let markers = lexicon.grammar.ruleMarkers
        guard lower.hasPrefix(markers.whenPrefix) else { return nil }
        let rest = String(text.dropFirst(markers.whenPrefix.count))
        guard let commaRange = rest.range(of: markers.commaSeparator) else { return nil }
        let conditionText = String(rest[rest.startIndex..<commaRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var actionText = String(rest[commaRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        if actionText.hasSuffix(".") { actionText = String(actionText.dropLast()) }
        // A blank condition/action (`When , do X.` / `When Y,.`) would still
        // synthesize a syntactically valid trigger workflow — `buildTriggerWorkflow`
        // has no non-emptiness check of its own, so a malformed rule like this
        // would silently mint a garbage `trigger..fired` event name instead of
        // failing to classify. Returning `nil` here routes it through the same
        // `MER1004: unparseable rule` path every other malformed rule shape hits.
        guard !conditionText.isEmpty, !actionText.isEmpty else { return nil }
        if isSelfEvaluatingTriggerCondition(conditionText) {
            return .unsupportedTriggerCondition(
                conditionText: conditionText,
                actionText: actionText,
                sourceLine: rule.sourceLine,
                originalText: rule.text
            )
        }
        return .trigger(
            conditionText: conditionText,
            actionText: actionText,
            sourceLine: rule.sourceLine,
            originalText: rule.text
        )
    }

    /// True when `conditionText` structurally names a real, checkable
    /// predicate Meridian itself could in principle evaluate over persisted
    /// state, as opposed to opaque prose describing an externally-raised
    /// event (`"a refund is requested"`, `"payment clears"`). `When` triggers
    /// compile to external-event stubs (`RuleInjector.buildTriggerWorkflow`)
    /// with no scheduler/poller to re-evaluate a self-evaluating predicate,
    /// so recognizing one here routes the rule to a loud `MER3017` instead of
    /// silently minting an event nobody will ever raise.
    ///
    /// Two independent signals, deliberately conservative (a false negative
    /// just keeps today's opaque-stub behavior; a false positive would wrongly
    /// block a legitimate external-event trigger):
    ///   1. A duration mention (`"7 days"`, `"3 hours"`) anywhere in the
    ///      condition — the hallmark of an elapsed-time/age check over
    ///      existing state (`"on hold for more than 7 days"`), which no
    ///      `.comparison` marker is guaranteed to catch on its own (e.g. a
    ///      bare `"for 7 days"` with no explicit magnitude word).
    ///   2. The full symbol-aware `ExpressionParser` recognizing one of the
    ///      structurally rich shapes: a magnitude/pattern/set comparison, an
    ///      emptiness/temporal-window check (also surfaced as `.comparison`
    ///      by `EmptinessTemporalGrammar`), a quantifier, a relation
    ///      traversal, a description, an aggregate, a superlative, a table
    ///      lookup, a parse-error carrier, or a declared-verb predicate.
    ///      Bare equality/inequality (`.equal`/`.notEqual`, from the lexicon's
    ///      copula-based `"is"`/`"is not"` markers) is deliberately EXCLUDED:
    ///      it is indistinguishable from idiomatic passive-voice event
    ///      phrasing (`"a refund is requested"`, `"the order is not
    ///      shipped"`) and must keep working as an external-event hook.
    private func isSelfEvaluatingTriggerCondition(_ conditionText: String) -> Bool {
        if containsDurationMention(conditionText) { return true }
        return isSelfEvaluatingExpression(exprParser.parse(conditionText))
    }

    private func isSelfEvaluatingExpression(_ expr: ExpressionAST) -> Bool {
        switch expr {
        case .quantified, .relationTraversal, .description, .aggregate, .superlative,
             .tableLookup, .malformed, .verbPredicate, .recordList:
            return true
        case .comparison(_, let op, _):
            switch op {
            case .equal, .notEqual: return false
            default: return true
            }
        case .logical(_, let exprs):
            return exprs.contains { isSelfEvaluatingExpression($0) }
        default:
            return false
        }
    }

    /// Narrow, lexicon-driven structural check: does `text` contain an
    /// adjacent "<number> <duration unit>" bigram anywhere (`"7 days"`,
    /// `"3.5 hours"`)? Independent of `ExpressionParser` dispatch order so a
    /// duration mention is caught even when no `ComparisonGrammar` marker
    /// happens to precede it.
    private func containsDurationMention(_ text: String) -> Bool {
        let words = text.split(separator: " ").map(String.init)
        guard words.count >= 2 else { return false }
        for i in 0..<(words.count - 1) {
            if lexicon.parseDuration("\(words[i]) \(words[i + 1])") != nil { return true }
        }
        return false
    }

    // MARK: - Precondition

    private func classifyPrecondition(_ text: String, rule: RuleAST) -> ParsedRule? {
        let markers = lexicon.grammar.ruleMarkers
        guard let mustBeRange = text.range(of: markers.mustBeMarker, options: [.caseInsensitive]) else { return nil }
        let subjectPart = String(text[text.startIndex..<mustBeRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        let afterMustBe = String(text[mustBeRange.upperBound...])

        guard let byRange = afterMustBe.range(of: markers.byMarker, options: [.caseInsensitive]) else { return nil }
        guard let beforeRange = afterMustBe.range(of: markers.beforeMarker, options: [.caseInsensitive]) else { return nil }

        let roleText = String(afterMustBe[byRange.upperBound..<beforeRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        let cleanRole = lexicon.stripLeadingArticle(roleText)

        let (subjectKind, subjectFilter, _) = parseSubject(subjectPart)
        let actionText = subjectPart.lowercased()

        return .precondition(
            subjectKind: subjectKind,
            subjectFilter: subjectFilter,
            actionText: actionText,
            gate: .approval(by: cleanRole),
            sourceLine: rule.sourceLine,
            originalText: rule.text
        )
    }

    // MARK: - Must not

    private func classifyMustNot(_ text: String, rule: RuleAST) -> ParsedRule? {
        let markers = lexicon.grammar.ruleMarkers
        guard let mustNotRange = text.range(of: markers.mustNotMarker, options: [.caseInsensitive]) else { return nil }
        let subjectPart = String(text[text.startIndex..<mustNotRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var actionText = String(text[mustNotRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        if actionText.hasSuffix(".") { actionText = String(actionText.dropLast()) }

        let (subjectKind, subjectFilter, _) = parseSubject(subjectPart)

        if let whoseRange = actionText.range(of: markers.whoseMarker, options: [.caseInsensitive]) {
            let objectPart = String(actionText[actionText.startIndex..<whoseRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let predicatePart = String(actionText[whoseRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            // The predicate's bare identifiers are properties of the action
            // OBJECT (e.g. "place an order whose total amount …" → object=order),
            // and possessive pronouns ("their", "his/her", "its") refer back
            // to the rule's SUBJECT (e.g. customer). Qualify the predicate
            // so codegen reads `state.get("order.totalAmount")` and
            // `state.get("customer.creditLimit")` instead of bare names that
            // never resolve.
            //
            // For `objectPart` like "place an order", the noun follows the
            // article. We extract the post-article words; if no article is
            // present (e.g. just "orders"), fall back to the whole string.
            let objectKind = extractObjectKind(from: objectPart)
            let rawPredicate = exprParser.parse(predicatePart)
            let predicate = qualifyPredicate(rawPredicate, objectKind: objectKind, subjectKind: subjectKind)
            return .parameterGuard(
                subjectKind: subjectKind,
                actionText: objectPart,
                predicate: predicate,
                sourceLine: rule.sourceLine,
                originalText: rule.text
            )
        }

        return .invariant(
            subjectKind: subjectKind,
            subjectFilter: subjectFilter,
            forbiddenActionText: actionText,
            sourceLine: rule.sourceLine,
            originalText: rule.text
        )
    }

    // MARK: - Permission

    private func classifyPermission(_ text: String, rule: RuleAST) -> ParsedRule? {
        guard let mayRange = text.range(of: lexicon.grammar.ruleMarkers.mayMarker, options: [.caseInsensitive]) else { return nil }
        let subjectPart = String(text[text.startIndex..<mayRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var actionText = String(text[mayRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        if actionText.hasSuffix(".") { actionText = String(actionText.dropLast()) }

        let (subjectKind, subjectFilter, _) = parseSubject(subjectPart)

        var conditions: ExpressionAST? = nil
        var isBounded = false
        for boundedMarker in lexicon.grammar.permissionBoundMarkers {
            if let markerRange = actionText.range(of: " " + boundedMarker, options: [.caseInsensitive]) {
                let condText = String(actionText[markerRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                let actionOnly = String(actionText[actionText.startIndex..<markerRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                conditions = exprParser.parse(condText)
                actionText = actionOnly
                isBounded = true
                break
            }
        }

        return .permission(
            subjectKind: subjectKind,
            subjectFilter: subjectFilter,
            allowedActionText: actionText,
            conditions: conditions,
            isBounded: isBounded,
            sourceLine: rule.sourceLine,
            originalText: rule.text
        )
    }

    // MARK: - Subject parsing helper

    /// Parse `"A customer with status suspended"` → kind=`"customer"`,
    /// filter=`(customer.status == "suspended")`.
    /// Parse `"An order with total amount more than X"` → kind=`"order"`,
    /// filter=`(order.totalAmount > X)`.
    ///
    /// The filter clause introduced by `with`/`whose`/`having`/`that`/`which`
    /// describes properties of the subject. We rewrite it into a property
    /// access on the subject so identifier references like `status` become
    /// `subject's status` (handled by ExpressionParser's possessive parser).
    private func parseSubject(_ text: String) -> (kind: String, filter: ExpressionAST?, actionHint: String?) {
        var s = lexicon.stripLeadingArticle(text)
        if s.hasSuffix(".") { s = String(s.dropLast()) }

        let words = s.components(separatedBy: " ")
        var kindWords: [String] = []
        var filterText: String? = nil
        var filterIntroducer: String? = nil
        var filterIsNegated = false
        let introducers = lexicon.grammar.subjectFilterIntroducers
        let negatedIntroducers = lexicon.grammar.negatedSubjectFilterIntroducers
        for (i, word) in words.enumerated() {
            let lowerWord = word.lowercased()
            if introducers.contains(lowerWord) || negatedIntroducers.contains(lowerWord) {
                filterIntroducer = lowerWord
                filterIsNegated = negatedIntroducers.contains(lowerWord)
                let after = words[(i + 1)...].joined(separator: " ")
                filterText = after.trimmingCharacters(in: .whitespaces)
                break
            }
            kindWords.append(word)
        }

        let kind = kindWords.joined(separator: " ").lowercased()
        let filter = filterText.flatMap { ft in
            buildSubjectFilter(introducer: filterIntroducer, filterText: ft, subject: kind)
        }.map { filterIsNegated ? ExpressionAST.logical(.not, [$0]) : $0 }
        return (kind, filter, nil)
    }

    /// Extract the object noun from a parameterGuard action object like
    /// `"place an order"` → `"order"` or `"approve any orders"` → `"orders"`.
    /// We pick the words after the first noun-phrase determiner. Without one,
    /// return the full string lowercased so `parseSubject`-style fallback can run.
    private func extractObjectKind(from text: String) -> String {
        ObjectKindExtractor(lexicon: lexicon).extract(from: text, noArticleFallback: .fullText)
    }

    /// Walk a parsed predicate expression and qualify its bare identifiers:
    ///   - `"total amount"` (no possessive) → `objectKind.totalAmount`
    ///   - `"their X"` / `"his X"` / `"her X"` / `"its X"` → `subjectKind.X`
    ///
    /// Used by parameter-guard predicate lowering so `state.get("order.totalAmount")`
    /// and `state.get("customer.creditLimit")` actually resolve at runtime.
    private func qualifyPredicate(_ expr: ExpressionAST, objectKind: String, subjectKind: String) -> ExpressionAST {
        switch expr {
        case .identifierRef(let name):
            return qualifyIdentifier(name, objectKind: objectKind, subjectKind: subjectKind)
        case .comparison(let lhs, let op, let rhs):
            return .comparison(
                qualifyPredicate(lhs, objectKind: objectKind, subjectKind: subjectKind),
                op,
                qualifyPredicate(rhs, objectKind: objectKind, subjectKind: subjectKind)
            )
        case .logical(let op, let exprs):
            return .logical(op, exprs.map { qualifyPredicate($0, objectKind: objectKind, subjectKind: subjectKind) })
        case .propertyAccess(let base, let prop):
            return .propertyAccess(qualifyPredicate(base, objectKind: objectKind, subjectKind: subjectKind), prop)
        default:
            return expr
        }
    }

    private func qualifyIdentifier(_ raw: String, objectKind: String, subjectKind: String) -> ExpressionAST {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        // Possessive pronouns refer to the subject (e.g. "their credit limit").
        for prefix in lexicon.possessivePronouns where lower.hasPrefix(prefix) {
            let rest = String(trimmed.dropFirst(prefix.count))
            if !subjectKind.isEmpty {
                return .propertyAccess(.identifierRef(subjectKind), rest)
            }
        }
        // Bare property reference → object's property.
        if !objectKind.isEmpty && !lower.contains(lexicon.grammar.ruleMarkers.possessiveOfMarker) {
            return .propertyAccess(.identifierRef(objectKind), trimmed)
        }
        return .identifierRef(trimmed)
    }

    /// Translate a raw filter clause (e.g. `"status suspended"` or
    /// `"total amount more than the high value threshold"`) into an
    /// `ExpressionAST` whose left-hand operand is qualified by the subject.
    /// Returns nil if the clause doesn't contain enough structure to lower.
    ///
    /// Two grammar shapes are recognised:
    ///   1. **Shorthand comparison** — `<property> <op-phrase> <value>`
    ///      where `<op-phrase>` is a comparison phrase that is allowed to
    ///      drop the leading "is" (e.g. `more than`, `less than`,
    ///      `at least`, `at most`). We rewrite this to `subject's <property> <op> <value>`.
    ///   2. **Property-equality shorthand** — `<property> <value>` with no
    ///      comparison phrase. We rewrite to `subject's <property> == <value>`.
    private func buildSubjectFilter(introducer: String?, filterText: String, subject: String) -> ExpressionAST? {
        let trimmed = filterText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !subject.isEmpty else { return nil }

        // Try the longest comparison phrase that appears in the clause.
        // We use the lexicon-tracked phrases minus a leading copula so
        // shorthand rule clauses still parse.
        let comparisonPhrases: [(phrase: String, op: ComparisonOpAST)] = lexicon.comparisonMarkers.compactMap { (m, op) in
            let stripped = stripLeadingCopula(m)
            return stripped.isEmpty ? nil : (stripped, op)
        }
        var bestMatch: (phrase: String, op: ComparisonOpAST, range: Range<String.Index>)? = nil
        for (phrase, op) in comparisonPhrases {
            if let r = trimmed.range(of: " " + phrase + " ", options: [.caseInsensitive]) {
                if bestMatch == nil || phrase.count > bestMatch!.phrase.count {
                    bestMatch = (phrase, op, r)
                }
            }
        }

        if let m = bestMatch {
            // <property> <op-phrase> <value>
            // Use the offsets of the matched phrase to slice trimmed.
            let propertyText = String(trimmed[trimmed.startIndex..<m.range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let valueText = String(trimmed[m.range.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            guard !propertyText.isEmpty, !valueText.isEmpty else { return nil }
            let lhs = ExpressionAST.propertyAccess(.identifierRef(subject), propertyText.replacingOccurrences(of: " ", with: "_"))
            // Build a propertyAccess that uses spaces as the property name —
            // codegen reads property as a key into `state.get("subject.<key>")`.
            let lhsWithSpaces = ExpressionAST.propertyAccess(.identifierRef(subject), propertyText)
            _ = lhs
            let rhs = exprParser.parse(valueText)
            return .comparison(lhsWithSpaces, m.op, rhs)
        }

        // No comparison phrase — treat as <property> <value> shorthand.
        // Multi-word properties end at the last word that's followed by a value.
        // Heuristic: split into 2 halves at the *last* whitespace whose right
        // half parses as a non-trivial value (string / enum case / number).
        let parts = trimmed.split(separator: " ").map(String.init)
        guard parts.count >= 2 else {
            // Single token — probably just a property name with no value.
            // Lower as `subject.<property>` so the assert checks truthiness.
            return .propertyAccess(.identifierRef(subject), trimmed)
        }

        // When `exprParser` carries a real symbol table (every non-test call
        // site — see `RuleAnalyzer.init`), try the FULL grammar on the whole
        // clause before guessing a shorthand split, but ONLY act on it when it
        // recognizes one of the exact forms `RuleInjector.lowerExprSimple`
        // explicitly rejects (`.quantified`/`.malformed`/`.recordList`/
        // `.tableLookup`/`.verbPredicate`/`.relationTraversal`/`.description`/
        // `.aggregate`/`.superlative`) — e.g. a clause like "active
        // prescriptions include a contraindicated drug" (a relation traversal
        // over a declared verb). Returning that form as-is routes the rule to
        // a precise, loud `MER3016` naming the actual unsupported construct,
        // which is strictly better than the shorthand split below silently
        // producing a syntactically valid but semantically meaningless
        // predicate (see the guard rail below, and
        // `corpora/GENERATING_A_CORPUS.md` gotcha #7).
        //
        // Every OTHER shape — bare identifier (no structure found), but also
        // `.comparison`/`.propertyAccess`/`.literal`/etc. — falls through to
        // the shorthand heuristic unchanged: those shapes are ambiguous with
        // (or already produced by) the split heuristic itself. For instance
        // `parseAtom` recognizes bare possessives ("order's id") as a
        // `.propertyAccess` chain with NO symbol table at all (AGENTS.md
        // pitfall #3), which would otherwise hijack legitimate shorthand
        // clauses like "note order's id" (property = "note order's", value =
        // "id") that the split heuristic is specifically designed to handle.
        let fullParse = exprParser.parse(trimmed)
        switch fullParse {
        case .quantified, .malformed, .recordList, .tableLookup,
             .verbPredicate, .relationTraversal, .description, .aggregate, .superlative:
            return fullParse
        default:
            break
        }

        // Guard rail: reachable in two overlapping cases — every unit test
        // that constructs `RuleAnalyzer(symbols: nil)` builds `exprParser`
        // with no symbol table at all, so the full-parse attempt above always
        // bottoms out here; and even a REAL symbol table only recognizes
        // structure whose kind vocabulary is actually declared, so a relation
        // traversal naming an undeclared kind ("active prescriptions include a
        // contraindicated drug" when `drug` isn't a declared kind) also falls
        // through to a bare identifier above and lands here. Either way there
        // is no way to confirm a split is real, so refuse to guess rather than
        // silently accept a plausible-looking-but-wrong one. Two structural
        // (not vocabulary) signals rule out a genuine short property/value
        // pair and route the whole rule to a loud `unattachedRule`/MER3006
        // instead (`nil` here →
        // `buildSubjectFilter` → `parseSubject` filter=nil → `buildInvariantCondition`
        // returns nil → the rule is never marked attached):
        //   1. A mid-clause article ("a"/"an"/"the") — real shorthand values
        //      are bare enums/numbers/quoted strings ("status suspended",
        //      "clearance \"denied\""), never articled noun phrases; a clause
        //      like "active prescriptions include a contraindicated drug"
        //      (relation traversal) always carries one.
        //   2. More than a handful of words — every real corpus/test
        //      shorthand clause is 1-3 words; a longer clause is prose, not a
        //      terse key-value pair, and greedily splitting it produces an
        //      `ExpressionAST` shape (`propertyAccess`/`comparison`/
        //      `identifierRef`) that `RuleInjector.lowerExprSimple` happily
        //      accepts as-is — i.e. a WRONG predicate that silently compiles
        //      and enforces nothing meaningful, which is strictly worse than
        //      today's loud `MER3016` for a quantifier/table it at least
        //      recognizes as unsupported. See `corpora/GENERATING_A_CORPUS.md`
        //      gotcha #7.
        guard parts.count <= 5, !parts.contains(where: { lexicon.articles.contains($0.lowercased()) }) else {
            return nil
        }
        // Greedy: try longest property first (drop one trailing word at a time).
        for splitAt in stride(from: parts.count - 1, to: 0, by: -1) {
            let property = parts[0..<splitAt].joined(separator: " ")
            let value = parts[splitAt..<parts.count].joined(separator: " ")
            // Property side must not contain comparison phrases (already handled above).
            let lhs = ExpressionAST.propertyAccess(.identifierRef(subject), property)
            let rhs = exprParser.parse(value)
            // If parser returns something useful (literal or non-empty identifier),
            // accept this split.
            if case .literal = rhs { return .comparison(lhs, .equal, rhs) }
            if case .identifierRef(let n) = rhs, !n.isEmpty {
                return .comparison(lhs, .equal, rhs)
            }
        }
        return nil
    }

    private func stripLeadingCopula(_ marker: String) -> String {
        let lower = marker.lowercased()
        for copula in lexicon.copulas.sorted(by: { $0.count > $1.count }) {
            let prefix = copula + " "
            if lower.hasPrefix(prefix) {
                return String(marker.dropFirst(prefix.count)).lowercased()
            }
        }
        return lower
    }
}
