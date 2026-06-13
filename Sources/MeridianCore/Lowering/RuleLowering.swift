import Foundation

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
    case permission(
        subjectKind: String,
        subjectFilter: ExpressionAST?,
        allowedActionText: String,
        conditions: ExpressionAST?,
        isBounded: Bool,
        sourceLine: Int,
        originalText: String
    )
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

    public init(lexicon: EnglishLexicon = .default, trace: ParserTrace = .shared) {
        self.lexicon = lexicon
        self.trace = trace
        self.exprParser = ExpressionParser(symbols: nil, trace: trace, lexicon: lexicon)
    }

    /// Classify a single RuleAST into a typed ParsedRule. Returns nil if the
    /// rule text does not match any known pattern.
    public func classify(_ rule: RuleAST) -> ParsedRule? {
        let text = rule.text.trimmingCharacters(in: .whitespaces)
        let lower = text.lowercased()

        // TRIGGER: "When ..."
        if lower.hasPrefix("when ") {
            return classifyTrigger(text, rule: rule)
        }

        // PRECONDITION: "... must be <participle> by <role> before ..."
        if lower.contains(" must be ") && lower.contains(" by ") && lower.contains(" before ") {
            return classifyPrecondition(text, rule: rule)
        }

        // INVARIANT / PARAMETER GUARD: "... must not ..."
        if lower.contains(" must not ") {
            return classifyMustNot(text, rule: rule)
        }

        // PERMISSION: "... may ..."
        if lower.contains(" may ") {
            return classifyPermission(text, rule: rule)
        }

        return nil
    }

    // MARK: - Trigger

    private func classifyTrigger(_ text: String, rule: RuleAST) -> ParsedRule? {
        let lower = text.lowercased()
        guard lower.hasPrefix("when ") else { return nil }
        let rest = String(text.dropFirst(5))  // drop "When "
        guard let commaRange = rest.range(of: ", ") else { return nil }
        let conditionText = String(rest[rest.startIndex..<commaRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var actionText = String(rest[commaRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        if actionText.hasSuffix(".") { actionText = String(actionText.dropLast()) }
        return .trigger(
            conditionText: conditionText,
            actionText: actionText,
            sourceLine: rule.sourceLine,
            originalText: rule.text
        )
    }

    // MARK: - Precondition

    private func classifyPrecondition(_ text: String, rule: RuleAST) -> ParsedRule? {
        let lower = text.lowercased()
        guard let mustBeRange = lower.range(of: " must be ") else { return nil }
        let subjectPart = String(text[text.startIndex..<mustBeRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        let afterMustBe = String(lower[mustBeRange.upperBound...])

        guard let byRange = afterMustBe.range(of: " by ") else { return nil }
        guard let beforeRange = afterMustBe.range(of: " before ") else { return nil }

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
        let lower = text.lowercased()
        guard let mustNotRange = lower.range(of: " must not ") else { return nil }
        let subjectPart = String(text[text.startIndex..<mustNotRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var actionText = String(text[mustNotRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        if actionText.hasSuffix(".") { actionText = String(actionText.dropLast()) }

        let (subjectKind, subjectFilter, _) = parseSubject(subjectPart)

        let actionLower = actionText.lowercased()
        if let whoseRange = actionLower.range(of: " whose ") {
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
        let lower = text.lowercased()
        guard let mayRange = lower.range(of: " may ") else { return nil }
        let subjectPart = String(text[text.startIndex..<mayRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var actionText = String(text[mayRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        if actionText.hasSuffix(".") { actionText = String(actionText.dropLast()) }

        let (subjectKind, subjectFilter, _) = parseSubject(subjectPart)

        var conditions: ExpressionAST? = nil
        var isBounded = false
        let actionLower = actionText.lowercased()
        for boundedMarker in ["whose ", "up to ", "if "] {
            if let markerRange = actionLower.range(of: " " + boundedMarker) {
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
        let introducers: Set<String> = ["with", "whose", "that", "which", "having"]
        for (i, word) in words.enumerated() {
            if introducers.contains(word.lowercased()) {
                filterIntroducer = word.lowercased()
                let after = words[(i + 1)...].joined(separator: " ")
                filterText = after.trimmingCharacters(in: .whitespaces)
                break
            }
            kindWords.append(word)
        }

        let kind = kindWords.joined(separator: " ").lowercased()
        let filter = filterText.flatMap { ft in
            buildSubjectFilter(introducer: filterIntroducer, filterText: ft, subject: kind)
        }
        return (kind, filter, nil)
    }

    /// Extract the object noun from a parameterGuard action object like
    /// `"place an order"` → `"order"` or `"approve any orders"` → `"orders"`.
    /// We pick the words after the first article. Without an article, return
    /// the full string lowercased so `parseSubject`-style fallback can run.
    private func extractObjectKind(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        let words = trimmed.components(separatedBy: " ")
        let articles: Set<String> = ["a", "an", "the", "any", "some"]
        for (i, w) in words.enumerated() {
            if articles.contains(w), i + 1 < words.count {
                return words[(i + 1)...].joined(separator: " ")
            }
        }
        // No article — the whole string IS the kind (e.g. "orders").
        return trimmed
    }

    /// Walk a parsed predicate expression and qualify its bare identifiers:
    ///   - `"total amount"` (no possessive) → `objectKind.total_amount`
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
        let possessivePrefixes = ["their ", "his ", "her ", "its "]
        for prefix in possessivePrefixes where lower.hasPrefix(prefix) {
            let rest = String(trimmed.dropFirst(prefix.count))
            if !subjectKind.isEmpty {
                return .propertyAccess(.identifierRef(subjectKind), rest)
            }
        }
        // Bare property reference → object's property.
        if !objectKind.isEmpty && !lower.contains(" of ") {
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
        // We use the lexicon-tracked phrases minus their leading "is " so
        // shorthand rule clauses still parse.
        let comparisonPhrases: [(phrase: String, op: ComparisonOpAST)] = lexicon.comparisonMarkers.compactMap { (m, op) in
            let stripped = m.lowercased().hasPrefix("is ")
                ? String(m.dropFirst(3))
                : m.lowercased()
            return stripped.isEmpty ? nil : (stripped, op)
        }
        let lower = trimmed.lowercased()
        var bestMatch: (phrase: String, op: ComparisonOpAST, range: Range<String.Index>)? = nil
        for (phrase, op) in comparisonPhrases {
            if let r = lower.range(of: " " + phrase + " ") {
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
        // Fallback: split on first space.
        let property = parts[0]
        let value = parts.dropFirst().joined(separator: " ")
        let lhs = ExpressionAST.propertyAccess(.identifierRef(subject), property)
        let rhs = exprParser.parse(value)
        return .comparison(lhs, .equal, rhs)
    }
}
