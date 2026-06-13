import Foundation

/// Single source of the mechanical AST→IR mappings that several lowerers share
/// verbatim: literal conversion and the comparison/logical operator maps. The
/// full lowerers (`ASTToIR.lowerExpr`, `RuleInjector.lowerExprSimple`) stay
/// separate — they differ in symbol-table use and Wave 2/3 handling — but these
/// leaf mappings must never drift apart.
enum LiteralLowering {

    static func toIRLiteral(_ lit: LiteralAST) -> IRLiteral {
        switch lit {
        case .string(let s):             return .string(s)
        case .integer(let n):            return .number(Decimal(n))
        case .double(let d):             return .number(Decimal(d))
        case .boolean(let b):            return .boolean(b)
        case .money(let a, let c):       return .money(Decimal(a), currency: c)
        case .duration(let v, let unit): return .duration(.seconds(Int64(v * Double(unit.inSeconds))))
        }
    }

    static func mapComparisonOp(_ op: ComparisonOpAST) -> ComparisonOp {
        switch op {
        case .equal:          return .equal
        case .notEqual:       return .notEqual
        case .lessThan:       return .lessThan
        case .lessOrEqual:    return .lessOrEqual
        case .greaterThan:    return .greaterThan
        case .greaterOrEqual: return .greaterOrEqual
        case .within:         return .withinDuration
        case .contains:       return .contains
        case .oneOf:          return .oneOf
        case .matchesPattern: return .matchesPattern
        case .withinPast:     return .withinPast
        case .withinFuture:   return .withinFuture
        case .isEmpty:        return .isEmpty
        case .isNotEmpty:     return .isNotEmpty
        }
    }

    /// `value × unit.inSeconds`, the canonical AST-duration → `Duration` idiom.
    static func durationSeconds(_ value: Double, unit: TimeUnitAST) -> Duration {
        .seconds(Int64(value * Double(unit.inSeconds)))
    }

    static func mapLogicalOp(_ op: LogicalOpAST) -> LogicalOp {
        switch op {
        case .and: return .and
        case .or:  return .or
        case .not: return .not
        }
    }
}
