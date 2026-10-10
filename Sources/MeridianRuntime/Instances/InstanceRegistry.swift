import Foundation

// MARK: - PropertyValue

public enum PropertyValue: Sendable, Hashable, Codable {
    case literal(Value)
    case envVar(String)

    private enum CodingKeys: String, CodingKey { case literal, envVar }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let env = try container.decodeIfPresent(String.self, forKey: .envVar) {
            self = .envVar(env)
        } else {
            self = .literal(try container.decode(AnyCodable.self, forKey: .literal).value)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .literal(let value): try container.encode(AnyCodable(value), forKey: .literal)
        case .envVar(let name):   try container.encode(name, forKey: .envVar)
        }
    }
}

// MARK: - InstanceHandle

public struct InstanceHandle: Sendable, Hashable, Codable {
    public let kind: String
    public let name: String
    let properties: [String: PropertyValue]

    public init(kind: String, name: String, properties: [String: PropertyValue]) {
        self.kind = kind
        self.name = name
        self.properties = properties
    }
}

// MARK: - InstanceRegistry

public final class InstanceRegistry: Sendable {

    private let instances: [String: InstanceHandle]

    public init() {
        self.instances = [:]
    }

    private init(instances: [String: InstanceHandle]) {
        self.instances = instances
    }

    public static var empty: InstanceRegistry { InstanceRegistry() }

    public func register(kind: String, name: String, properties: [String: PropertyValue]) -> InstanceRegistry {
        var updated = instances
        updated[name] = InstanceHandle(kind: kind, name: name, properties: properties)
        return InstanceRegistry(instances: updated)
    }

    public func handle(for name: String) -> InstanceHandle? {
        instances[name]
    }

    // MARK: - Builder

    public class Builder {
        private var instances: [String: InstanceHandle] = [:]

        public init() {}

        @discardableResult
        public func register(kind: String, name: String, properties: [String: PropertyValue]) -> Builder {
            instances[name] = InstanceHandle(kind: kind, name: name, properties: properties)
            return self
        }

        public func build() -> InstanceRegistry {
            InstanceRegistry(instances: instances)
        }
    }
}
