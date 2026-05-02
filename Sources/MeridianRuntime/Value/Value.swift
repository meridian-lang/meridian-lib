import Foundation

// MARK: - Money

/// A monetary value with an amount and currency code.
public struct Money: Sendable, Hashable, Codable {
    public let amount: Decimal
    public let currency: String

    public init(amount: Decimal, currency: String) {
        self.amount = amount
        self.currency = currency
    }
}

extension Money: Comparable {
    public static func < (lhs: Money, rhs: Money) -> Bool {
        lhs.amount < rhs.amount
    }
}

extension Money: CustomStringConvertible {
    public var description: String {
        "<Money \(amount) \(currency)>"
    }
}

// MARK: - Value

/// Type-erased value passed through the runtime.
/// Every state binding, tool argument, tool return value, and event payload
/// field is a Value.
public enum Value: Sendable {
    case string(String)
    case number(Decimal)
    case boolean(Bool)
    case money(Money)
    case duration(Duration)
    case date(Date)
    case dateTime(Date)
    case enumValue(String, kind: String)
    case record([String: Value])
    case list([Value])
    case reference(String)
    case null
    /// Holds custom Swift types not in the canonical set.
    /// The wrapped type must be both AnyObject (for equality) and Sendable.
    case opaque(AnyHashableSendable)

    public static let unit = Value.null
}

extension Value {
    /// Convenience for generated `iterate` codegen: returns the wrapped
    /// `[Value]` if the value is a `.list`, or `nil` otherwise. Optional so
    /// callers can chain through `state.get("items")?.asList ?? []` without
    /// guarding the binding existence separately.
    public var asList: [Value]? {
        if case .list(let arr) = self { return arr }
        return nil
    }
}

// MARK: - AnyHashableSendable box

/// Type-erasing box that satisfies Sendable + Hashable for .opaque values.
///
/// When the wrapped type also conforms to `Encodable`, the conformance is
/// captured at construction time as a closure (`encoder`). `State`'s opaque
/// traversal uses that closure for JSON round-tripping; without this capture
/// a runtime existential cast (`AnyHashable.base as? any Encodable`) silently
/// loses the conformance and the traversal returns `nil`.
public struct AnyHashableSendable: @unchecked Sendable, Hashable {
    private let base: AnyHashable
    private let encoder: (@Sendable (Encoder) throws -> Void)?

    public init<T: Hashable & Sendable>(_ value: T) {
        self.base = AnyHashable(value)
        self.encoder = nil
    }

    /// Initialise with an Encodable value; the captured `encoder` closure
    /// preserves the conformance for `State`'s Codable round-trip.
    public init<T: Hashable & Sendable & Encodable>(_ value: T) {
        self.base = AnyHashable(value)
        self.encoder = { try value.encode(to: $0) }
    }

    public static func == (lhs: AnyHashableSendable, rhs: AnyHashableSendable) -> Bool {
        lhs.base == rhs.base
    }

    public func hash(into hasher: inout Hasher) {
        base.hash(into: &hasher)
    }

    /// Attempt to cast the wrapped value to T.
    public func unwrap<T>(as type: T.Type) -> T? {
        base.base as? T
    }

    /// Encode the wrapped value into `encoder` if it was constructed with an
    /// `Encodable` conformance. Returns `false` when no conformance was
    /// captured (e.g. `init<T: Hashable & Sendable>`).
    @discardableResult
    public func encodeIfEncodable(to encoder: Encoder) throws -> Bool {
        guard let fn = self.encoder else { return false }
        try fn(encoder)
        return true
    }
}

// MARK: - Value equality

extension Value: Equatable {
    public static func == (lhs: Value, rhs: Value) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): return a == b
        case (.number(let a), .number(let b)): return a == b
        case (.boolean(let a), .boolean(let b)): return a == b
        case (.money(let a), .money(let b)): return a == b
        case (.duration(let a), .duration(let b)): return a == b
        case (.date(let a), .date(let b)): return a == b
        case (.dateTime(let a), .dateTime(let b)): return a == b
        case (.enumValue(let a, let ak), .enumValue(let b, let bk)): return a == b && ak == bk
        case (.record(let a), .record(let b)): return a == b
        case (.list(let a), .list(let b)): return a == b
        case (.reference(let a), .reference(let b)): return a == b
        case (.null, .null): return true
        case (.opaque(let a), .opaque(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Hashable

extension Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .string(let v): hasher.combine(0); hasher.combine(v)
        case .number(let v): hasher.combine(1); hasher.combine(v)
        case .boolean(let v): hasher.combine(2); hasher.combine(v)
        case .money(let v): hasher.combine(3); hasher.combine(v)
        case .duration(let v): hasher.combine(4); hasher.combine(v)
        case .date(let v): hasher.combine(5); hasher.combine(v)
        case .dateTime(let v): hasher.combine(6); hasher.combine(v)
        case .enumValue(let v, let k): hasher.combine(7); hasher.combine(v); hasher.combine(k)
        case .record(let d): hasher.combine(8); hasher.combine(d)
        case .list(let a): hasher.combine(9); hasher.combine(a)
        case .reference(let r): hasher.combine(10); hasher.combine(r)
        case .null: hasher.combine(11)
        case .opaque(let v): hasher.combine(12); hasher.combine(v)
        }
    }
}

// MARK: - Construction helpers

public extension Value {
    static func number<N: BinaryInteger>(_ n: N) -> Value {
        .number(Decimal(Int(n)))
    }

    static func number<F: BinaryFloatingPoint>(_ f: F) -> Value {
        .number(Decimal(Double(f)))
    }

    static func money(_ amount: Decimal, currency: String = "USD") -> Value {
        .money(Money(amount: amount, currency: currency))
    }

    static func wrap<T: Hashable & Sendable>(_ value: T) -> Value {
        .opaque(AnyHashableSendable(value))
    }
}

// MARK: - CustomStringConvertible

extension Value: CustomStringConvertible {
    public var description: String {
        switch self {
        case .string(let s): return "\"\(s)\""
        case .number(let n): return n.description
        case .boolean(let b): return b.description
        case .money(let m): return m.description
        case .duration(let d): return d.description
        case .date(let d): return ISO8601DateFormatter().string(from: d)
        case .dateTime(let d): return ISO8601DateFormatter().string(from: d)
        case .enumValue(let v, _): return v
        case .record(let d): return "<Record \(d.keys.joined(separator: ","))>"
        case .list(let a): return "<List count=\(a.count)>"
        case .reference(let r): return "<Ref \(r)>"
        case .null: return "null"
        case .opaque(let v): return "<opaque \(v)>"
        }
    }
}
