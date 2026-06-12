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
        guard let d = dateValue(subject) else { return false }
        return isWithin(d, window, of: reference)
    }

    /// One-sided window: `subject` is in the past, no more than `window` ago.
    /// Lowers `within the last N <unit>`. `subject` in the future fails.
    public static func isWithinPast(_ subject: Value?, _ window: Duration, of reference: Date = Date()) -> Bool {
        guard let d = dateValue(subject) else { return false }
        let delta = reference.timeIntervalSince(d)   // positive when subject is past
        return delta >= 0 && delta <= seconds(window)
    }

    /// One-sided window: `subject` is in the future, no more than `window` ahead.
    /// Lowers `in the next N <unit>`. `subject` in the past fails.
    public static func isWithinFuture(_ subject: Value?, _ window: Duration, of reference: Date = Date()) -> Bool {
        guard let d = dateValue(subject) else { return false }
        let delta = d.timeIntervalSince(reference)   // positive when subject is future
        return delta >= 0 && delta <= seconds(window)
    }

    private static func seconds(_ window: Duration) -> Double {
        Double(window.components.seconds) + Double(window.components.attoseconds) / 1.0e18
    }

    private static func dateValue(_ v: Value?) -> Date? {
        switch v {
        case .date(let d)?, .dateTime(let d)?: return d
        default: return nil
        }
    }

    // MARK: total order (for `sorted by`)

    /// A deterministic total order across the orderable Value kinds, used by
    /// generated `sorted by` closures. `date`/`dateTime` order by instant,
    /// `number`/`money`/`duration` numerically, `string` lexicographically.
    /// `nil`, mixed, and unorderable values sort last (stable: equal-rank items
    /// keep their relative order because `false` is returned for ties).
    public static func orderedBefore(_ a: Value?, _ b: Value?, ascending: Bool = true) -> Bool {
        let ra = orderRank(a)
        let rb = orderRank(b)
        if ra == nil && rb == nil { return false }
        if ra == nil { return false }            // a sorts last
        if rb == nil { return true }
        if let da = dateValue(a), let db = dateValue(b) {
            if da == db { return false }
            return ascending ? da < db : da > db
        }
        if let na = numeric(a), let nb = numeric(b) {
            if na == nb { return false }
            return ascending ? na < nb : na > nb
        }
        if case .string(let sa)? = a, case .string(let sb)? = b {
            if sa == sb { return false }
            return ascending ? sa < sb : sa > sb
        }
        return false
    }

    /// Sortability rank: 0 = date-like, 1 = numeric, 2 = string, nil = unorderable.
    private static func orderRank(_ v: Value?) -> Int? {
        if dateValue(v) != nil { return 0 }
        if numeric(v) != nil { return 1 }
        if case .string? = v { return 2 }
        return nil
    }

    /// Value-to-Value comparison helpers used by codegen so generated Swift
    /// can write `MeridianComparison.lt(state.get("a"), state.get("b"))`
    /// without inlining Value-unwrapping boilerplate. Overloads cover the
    /// common case where one side is a typed constant (Decimal, Money, …).

    // MARK: equality

    public static func eq(_ a: Value?, _ b: Value?) -> Bool { (a ?? .null) == (b ?? .null) }
    public static func neq(_ a: Value?, _ b: Value?) -> Bool { !eq(a, b) }

    // MARK: emptiness (2: `has no <prop>` / `is empty`)

    /// `true` when a property-backed value is "empty": `nil`/`.null`, an empty
    /// string (after trimming whitespace), an empty list, or an empty record.
    /// Numbers/booleans/dates are never empty (a present scalar is content).
    public static func isEmpty(_ v: Value?) -> Bool {
        switch v {
        case nil, .null?:               return true
        case .string(let s)?:           return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .list(let xs)?:            return xs.isEmpty
        case .record(let d)?:           return d.isEmpty
        default:                        return false
        }
    }

    public static func isNotEmpty(_ v: Value?) -> Bool { !isEmpty(v) }

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
