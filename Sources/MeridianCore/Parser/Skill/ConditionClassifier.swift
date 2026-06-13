import Foundation

// MARK: - ConditionClassifier
//
// Shared deterministic classification of a one-line condition into:
//   • checkable      — parses to a comparison/logical over concrete operands
//                      (lowers to a real `assert` / precondition).
//   • dispatchPhrase  — reads as a descriptive intent (no copula/comparison);
//                      used as a literal applicability/dispatch phrase.
//   • fuzzy          — reads as a condition (has a copula/comparison marker) but
//                      is not structurally checkable (a hard error at the call
//                      site — the author rephrases or marks the section inert).
//
// Used by `SkillSectionBuilder` (Contract / When-To-Use lowering) and by
// `StatementParser` (task-list checklist items). House rule: one source of
// truth for the checkable predicate, no duplicated word lists.

struct ConditionClassifier {
    let symbols: SymbolTable?
    let lexicon: EnglishLexicon
    let trace: ParserTrace

    enum Classification: Sendable {
        case checkable
        case dispatchPhrase(String)
        case fuzzy
    }

    func classify(_ text: String) -> Classification {
        let parser = ExpressionParser(symbols: symbols, trace: trace, lexicon: lexicon)
        let expr = parser.parse(text)
        if isCheckable(expr) { return .checkable }
        if readsAsCondition(text) { return .fuzzy }
        return .dispatchPhrase(text)
    }

    /// Normalize a format-invariant phrasing to a checkable condition. An output
    /// invariant `every emitted <noun> <predicate>` (1D, generalized to ANY
    /// checkable predicate — `matches pattern`, `contains`, `is at least`, `is
    /// empty`, …) becomes `the <noun> <predicate>` so the comparison's LHS
    /// resolves to the bound result `<noun>`. Returns the text unchanged when no
    /// quantifier prefix is present. Single source of truth for the rewrite
    /// shared by Contract invariants and task-list checklist items.
    func normalizeFormatInvariant(_ text: String) -> String {
        let lower = text.lowercased()
        // `emitted` is the signal that this is an output-format invariant on a
        // single bound result — NOT a `every <plural>` collection quantifier
        // (Wave 2C), which must keep its quantifier meaning.
        for prefix in lexicon.grammar.emittedInvariantPrefixes where lower.hasPrefix(prefix) {
            return "the " + text.dropFirst(prefix.count)
        }
        return text
    }

    func isCheckable(_ expr: ExpressionAST) -> Bool {
        switch expr {
        case .comparison(let lhs, let op, let rhs):
            switch op {
            case .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual, .within, .contains,
                 .oneOf, .matchesPattern, .withinPast, .withinFuture, .isEmpty, .isNotEmpty:
                return true
            case .equal, .notEqual:
                return isConcrete(rhs) || isConcrete(lhs)
            }
        case .logical(let logOp, let parts):
            switch logOp {
            case .and, .or: return !parts.isEmpty && parts.allSatisfy(isCheckable)
            case .not:      return parts.first.map(isCheckable) ?? false
            }
        default:
            return false
        }
    }

    /// A "concrete" operand is structurally determinate at runtime: a literal, a
    /// named constant/instance, `now`, or a property access. A bare identifier
    /// (an adjective like `notable`) is NOT concrete.
    private func isConcrete(_ expr: ExpressionAST) -> Bool {
        switch expr {
        case .literal, .constantRef, .instanceRef, .envVar, .now, .propertyAccess:
            return true
        default:
            return false
        }
    }

    /// True when the text grammatically reads as a *condition* (contains a
    /// copula or comparison marker) — separates fuzzy conditions from
    /// descriptive dispatch phrases.
    func readsAsCondition(_ text: String) -> Bool {
        let lower = " \(text.lowercased()) "
        let conditionCues = lexicon.copulas.union(lexicon.grammar.conditionCueWords)
        if conditionCues.contains(where: { lower.contains(" \($0) ") }) { return true }
        for marker in lexicon.comparisonMarkers.map(\.0) {
            if lower.contains(" \(marker.lowercased()) ") { return true }
        }
        return false
    }
}
