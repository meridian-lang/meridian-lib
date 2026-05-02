import Foundation

// MARK: - ValueError

public enum ValueError: Error, Sendable {
    case cannotCoerce(from: String, to: String)
    case invalidLiteral(String)
}

// MARK: - Value coercion

public extension Value {
    /// Attempt to coerce this value to the given Swift type.
    func coerce<T>(to type: T.Type) throws -> T {
        // .opaque fast-path
        if let v = (self as? AnyHashableSendable)?.unwrap(as: T.self) {
            return v
        }
        switch self {
        case .opaque(let box):
            if let v = box.unwrap(as: T.self) { return v }

        case .string(let s):
            if T.self == String.self, let v = s as? T { return v }
            if T.self == URL.self, let url = URL(string: s), let v = url as? T { return v }
            if T.self == Date.self {
                if let d = ISO8601DateFormatter().date(from: s), let v = d as? T { return v }
            }

        case .number(let n):
            if T.self == Int.self, let v = (n as NSDecimalNumber).intValue as? T { return v }
            if T.self == Double.self, let v = (n as NSDecimalNumber).doubleValue as? T { return v }
            if T.self == Float.self, let v = (n as NSDecimalNumber).floatValue as? T { return v }
            if T.self == Decimal.self, let v = n as? T { return v }

        case .boolean(let b):
            if T.self == Bool.self, let v = b as? T { return v }

        case .money(let m):
            if T.self == Money.self, let v = m as? T { return v }
            if T.self == String.self, let v = m.description as? T { return v }
            if T.self == Decimal.self, let v = m.amount as? T { return v }

        case .duration(let d):
            if T.self == Duration.self, let v = d as? T { return v }
            if T.self == Double.self {
                let seconds = Double(d.components.seconds)
                if let v = seconds as? T { return v }
            }

        case .date(let d):
            if T.self == Date.self, let v = d as? T { return v }

        case .dateTime(let d):
            if T.self == Date.self, let v = d as? T { return v }

        case .enumValue(let raw, _):
            if T.self == String.self, let v = raw as? T { return v }

        case .reference(let id):
            if T.self == String.self, let v = id as? T { return v }

        case .record(let dict):
            // Attempt JSON round-trip to a Codable type
            if let codable = T.self as? any Decodable.Type {
                let data = try JSONEncoder().encode(dict.mapValues { AnyCodable($0) })
                let decoded = try JSONDecoder().decode(codable, from: data)
                if let v = decoded as? T { return v }
            }

        case .list(let items):
            // Coerce to [T] if T is an array element
            if T.self == [Value].self, let v = items as? T { return v }

        case .null:
            break
        }

        throw ValueError.cannotCoerce(
            from: String(describing: self),
            to: String(describing: T.self)
        )
    }
}

// MARK: - Value.from — typed → Value bridge

public extension Value {
    /// Bridge a typed Swift value (constants, instances, primitives) into a
    /// `Value` for use in `[String: Value]` payloads. Used by codegen so it can
    /// write `.from(constants.highValueThreshold)` without case-by-case
    /// emission for every constant kind.
    static func from(_ v: String) -> Value     { .string(v) }
    static func from(_ v: Bool) -> Value       { .boolean(v) }
    static func from(_ v: Int) -> Value        { .number(Decimal(v)) }
    static func from(_ v: Double) -> Value     { .number(Decimal(v)) }
    static func from(_ v: Decimal) -> Value    { .number(v) }
    static func from(_ v: Money) -> Value      { .money(v) }
    static func from(_ v: Duration) -> Value   { .duration(v) }
    static func from(_ v: Date) -> Value       { .date(v) }
    static func from(_ v: Value) -> Value      { v }

    /// Generic overload for opaque/typed instances that conform to Hashable +
    /// Sendable but aren't one of the canonical primitives above. Wraps in
    /// `.opaque` so the runtime can later unwrap with `coerce(to:)`.
    static func from<T: Hashable & Sendable>(_ v: T) -> Value {
        .opaque(AnyHashableSendable(v))
    }
}

// MARK: - AnyCodable (minimal, for record round-trip)

/// Minimal type-erased Codable wrapper for Value round-trips.
public struct AnyCodable: Codable, Sendable {
    public let value: Value

    public init(_ value: Value) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            value = .null
        } else if let b = try? c.decode(Bool.self) {
            value = .boolean(b)
        } else if let n = try? c.decode(Decimal.self) {
            value = .number(n)
        } else if let s = try? c.decode(String.self) {
            value = .string(s)
        } else if let arr = try? c.decode([AnyCodable].self) {
            value = .list(arr.map(\.value))
        } else if let dict = try? c.decode([String: AnyCodable].self) {
            value = .record(dict.mapValues(\.value))
        } else {
            value = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case .null: try c.encodeNil()
        case .boolean(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .enumValue(let v, _): try c.encode(v)
        case .reference(let r): try c.encode(r)
        case .money(let m): try c.encode(m.description)
        case .date(let d): try c.encode(ISO8601DateFormatter().string(from: d))
        case .dateTime(let d): try c.encode(ISO8601DateFormatter().string(from: d))
        case .duration(let d): try c.encode(d.description)
        case .list(let arr): try c.encode(arr.map { AnyCodable($0) })
        case .record(let dict): try c.encode(dict.mapValues { AnyCodable($0) })
        case .opaque(let box): try c.encode(String(describing: box))
        }
    }
}
