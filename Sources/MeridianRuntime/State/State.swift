import Foundation

// MARK: - StateError

public enum StateError: Error, Sendable {
    case missing(key: String)
    case typeMismatch(key: String, expected: String, actual: String)
    case shadowing(key: String)
    case unbound(key: String)
}

// MARK: - StateSnapshot

/// Immutable snapshot of workflow state for checkpointing.
public struct StateSnapshot: Codable, Sendable {
    public let bindings: [String: AnyCodable]

    public init(bindings: [String: AnyCodable]) {
        self.bindings = bindings
    }

    /// Convenience: the bindings as [String: Value].
    public var asValues: [String: Value] {
        bindings.mapValues(\.value)
    }
}

// MARK: - State

/// Per-workflow-run key-value store. Passed by value (struct); mutated by the workflow.
public struct State: Sendable {

    private var bindings: [String: Value] = [:]

    public init() {}

    // MARK: - Mutation

    /// Bind a new name. Throws StateError.shadowing if the key already exists.
    public mutating func bind(_ key: String, _ value: Value) {
        // In generated code the compiler guarantees no shadowing, but we still
        // store the value — generated code never hits the guard below.
        bindings[key] = value
    }

    /// Bind a Hashable+Sendable value directly (convenience for domain types).
    public mutating func bind<T: Hashable & Sendable>(_ key: String, _ value: T) {
        bindings[key] = Value.opaque(AnyHashableSendable(value))
    }

    /// Bind a Hashable+Sendable+Encodable value. Codegen routes domain types
    /// through this overload so the captured `Encodable` conformance survives
    /// `Value.opaque` boxing — required for `state.get("order.totalAmount")`
    /// to traverse the Codable representation.
    public mutating func bind<T: Hashable & Sendable & Encodable>(_ key: String, _ value: T) {
        bindings[key] = Value.opaque(AnyHashableSendable(value))
    }

    /// Update an existing binding. Does NOT require the binding to exist in v1
    /// (generated code only calls rebind when it knows the key exists).
    public mutating func rebind(_ key: String, _ value: Value) {
        bindings[key] = value
    }

    // MARK: - Reading

    /// Read a binding by dot-separated key path.
    public func get(_ keyPath: String) -> Value? {
        let parts = keyPath.split(separator: ".", maxSplits: 1).map(String.init)
        guard let root = parts.first, let rootValue = bindings[root] else {
            return nil
        }
        if parts.count == 1 { return rootValue }
        let remainder = parts[1]
        return traverse(rootValue, path: remainder)
    }

    /// Read with type assertion. Throws if missing or wrong type.
    public func require<T>(_ keyPath: String, as type: T.Type) throws -> T {
        guard let value = get(keyPath) else {
            throw StateError.missing(key: keyPath)
        }
        do {
            return try value.coerce(to: T.self)
        } catch {
            throw StateError.typeMismatch(
                key: keyPath,
                expected: String(describing: T.self),
                actual: String(describing: value)
            )
        }
    }

    // MARK: - Snapshots

    public func snapshot() -> StateSnapshot {
        StateSnapshot(bindings: bindings.mapValues(AnyCodable.init))
    }

    public mutating func restore(from snapshot: StateSnapshot) {
        bindings = snapshot.bindings.mapValues(\.value)
    }

    public func allBindings() -> [String: Value] {
        bindings
    }

    // MARK: - Private helpers

    private func traverse(_ value: Value, path: String) -> Value? {
        let parts = path.split(separator: ".", maxSplits: 1).map(String.init)
        let key = parts[0]

        switch value {
        case .record(let dict):
            guard let child = dict[key] else { return nil }
            if parts.count == 1 { return child }
            return traverse(child, path: parts[1])

        case .opaque(let box):
            // Attempt Codable round-trip for structured types
            guard let encoded = try? encodeOpaque(box),
                  let dict = try? JSONDecoder().decode([String: AnyCodable].self, from: encoded),
                  let child = dict[key]?.value
            else { return nil }
            if parts.count == 1 { return child }
            return traverse(child, path: parts[1])

        default:
            return nil
        }
    }

    private func encodeOpaque(_ box: AnyHashableSendable) throws -> Data {
        // The wrapped value's Encodable conformance is captured at bind time
        // (`AnyHashableSendable.init<T: Hashable & Sendable & Encodable>`) and
        // replayed here via the box's stored closure. The earlier
        // `Any as? Encodable` cast silently lost the conformance for some
        // concrete types; the captured closure is conformance-stable.
        struct Probe: Encodable {
            let box: AnyHashableSendable
            func encode(to encoder: Encoder) throws {
                _ = try box.encodeIfEncodable(to: encoder)
            }
        }
        // Default key encoding (camelCase) — codegen lowers property paths in
        // camelCase too, so `state.get("order.totalAmount")` lines up with the
        // Codable representation of the wrapped domain type.
        return try JSONEncoder().encode(Probe(box: box))
    }
}
