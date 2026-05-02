import Foundation

// MARK: - Generated comparison helpers
//
// Used by codegen for non-infix comparison forms. Generated Swift calls these
// instead of trying to inline the math; that keeps the codepath readable and
// gives one place to change semantics later.

public enum MeridianComparison {

    // MARK: within

    /// Return `true` iff the moment `subject` is within `window` of `reference`.
    /// Used to lower the natural-language form `X is within Y`, where X is a
    /// date/time and Y is a Duration. Caller passes `reference: Date()` for the
    /// most common "within Y of now" reading.
    public static func isWithin(_ subject: Date, _ window: Duration, of reference: Date = Date()) -> Bool {
        let delta = abs(reference.timeIntervalSince(subject))
        let secs = window.components.seconds
        let attos = Double(window.components.attoseconds) / 1.0e18
        return delta <= Double(secs) + attos
    }

    /// Optional form for callers that store a `Value` instead of a typed Date.
    public static func isWithin(_ subject: Value?, _ window: Duration, of reference: Date = Date()) -> Bool {
        guard let s = subject, case .date(let d) = s else { return false }
        return isWithin(d, window, of: reference)
    }

    /// Value-to-Value comparison helpers used by codegen so generated Swift
    /// can write `MeridianComparison.lt(state.get("a"), state.get("b"))`
    /// without inlining Value-unwrapping boilerplate. Overloads cover the
    /// common case where one side is a typed constant (Decimal, Money, …).

    // MARK: equality

    public static func eq(_ a: Value?, _ b: Value?) -> Bool { (a ?? .null) == (b ?? .null) }
    public static func neq(_ a: Value?, _ b: Value?) -> Bool { !eq(a, b) }

    // MARK: ordering — Value <-> Value

    public static func lt(_ a: Value?, _ b: Value?) -> Bool { compare(numeric(a), numeric(b), op: <) }
    public static func le(_ a: Value?, _ b: Value?) -> Bool { compare(numeric(a), numeric(b), op: <=) }
    public static func gt(_ a: Value?, _ b: Value?) -> Bool { compare(numeric(a), numeric(b), op: >) }
    public static func ge(_ a: Value?, _ b: Value?) -> Bool { compare(numeric(a), numeric(b), op: >=) }

    // MARK: ordering — Value vs typed constant (Decimal / Money / Duration / Int / Double)

    public static func lt<T: NumericConvertible>(_ a: Value?, _ b: T) -> Bool { compare(numeric(a), b.asDecimal, op: <) }
    public static func le<T: NumericConvertible>(_ a: Value?, _ b: T) -> Bool { compare(numeric(a), b.asDecimal, op: <=) }
    public static func gt<T: NumericConvertible>(_ a: Value?, _ b: T) -> Bool { compare(numeric(a), b.asDecimal, op: >) }
    public static func ge<T: NumericConvertible>(_ a: Value?, _ b: T) -> Bool { compare(numeric(a), b.asDecimal, op: >=) }

    public static func lt<T: NumericConvertible>(_ a: T, _ b: Value?) -> Bool { compare(a.asDecimal, numeric(b), op: <) }
    public static func le<T: NumericConvertible>(_ a: T, _ b: Value?) -> Bool { compare(a.asDecimal, numeric(b), op: <=) }
    public static func gt<T: NumericConvertible>(_ a: T, _ b: Value?) -> Bool { compare(a.asDecimal, numeric(b), op: >) }
    public static func ge<T: NumericConvertible>(_ a: T, _ b: Value?) -> Bool { compare(a.asDecimal, numeric(b), op: >=) }

    private static func compare(_ a: Decimal?, _ b: Decimal?, op: (Decimal, Decimal) -> Bool) -> Bool {
        guard let aN = a, let bN = b else { return false }
        return op(aN, bN)
    }

    private static func numeric(_ v: Value?) -> Decimal? {
        switch v {
        case .number(let n)?:                 return n
        case .money(let m)?:                  return m.amount
        case .duration(let d)?:               return Decimal(d.components.seconds)
        case .string(let s)?:                 return Decimal(string: s)
        case .record(let dict)?:
            // Codable round-tripping a typed Money/Duration through `State`
            // flattens it into a record (e.g. `{"amount": …, "currency": …}`).
            // Treat that shape as the underlying scalar so generated
            // comparisons stay numeric across the boundary.
            if case .number(let n)? = dict["amount"]   { return n }
            if case .number(let n)? = dict["seconds"]  { return n }
            return nil
        default:                              return nil
        }
    }
}

// MARK: - NumericConvertible

/// Adopted by typed constants so codegen can pass them straight to the
/// `MeridianComparison.*` helpers. Bridges Money / Duration / Int / Double /
/// Decimal to a common Decimal form.
public protocol NumericConvertible {
    var asDecimal: Decimal { get }
}

extension Decimal: NumericConvertible { public var asDecimal: Decimal { self } }
extension Int:     NumericConvertible { public var asDecimal: Decimal { Decimal(self) } }
extension Double:  NumericConvertible { public var asDecimal: Decimal { Decimal(self) } }
extension Money:   NumericConvertible { public var asDecimal: Decimal { amount } }
extension Duration: NumericConvertible { public var asDecimal: Decimal { Decimal(components.seconds) } }
