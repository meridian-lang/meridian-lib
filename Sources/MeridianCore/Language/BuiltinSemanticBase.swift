import Foundation

enum BuiltinSemanticBase: String, CaseIterable, Sendable {
    case thing
    case event
    case action
    case tool
    case system
    case integration
    case artifact
    case service
    case agent
    case model
    case dataset
    case storage
    case credential
    case policy
    case environment
    case resource
    case metric
    case memory
    case process
    case message
    case signal
    case fact
    case role
    case verdict

    static let root: BuiltinSemanticBase = .thing

    static func isRoot(_ raw: String) -> Bool {
        Self(rawValue: raw.lowercased()) == root
    }

    var runtimeProtocolName: String {
        "Meridian\(IdentifierNaming.pascalCase(rawValue))"
    }

    static func runtimeProtocolName(for raw: String) -> String? {
        Self(rawValue: raw.lowercased())?.runtimeProtocolName
    }
}
