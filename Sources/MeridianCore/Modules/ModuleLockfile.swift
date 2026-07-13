import Foundation

/// Deterministic lock of a resolved module graph (content-addressed entries,
/// sorted by module id). Hosts may persist this beside a skill for reproducible
/// builds.
public struct ModuleLockfile: Sendable, Equatable, Codable {
    public static let formatVersion = 1

    public struct Entry: Sendable, Equatable, Codable {
        public let id: String
        public let path: String
        public let contentHash: String
        public let alias: String?

        public init(id: String, path: String, contentHash: String, alias: String? = nil) {
            self.id = id
            self.path = path
            self.contentHash = contentHash
            self.alias = alias
        }
    }

    public let version: Int
    public let modules: [Entry]

    public init(modules: [Entry], version: Int = ModuleLockfile.formatVersion) {
        self.version = version
        self.modules = modules.sorted { $0.id < $1.id }
    }

    public func encodeJSON(pretty: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        let data = try encoder.encode(self)
        guard let text = String(data: data, encoding: .utf8) else {
            throw ModuleResolverError.encodingFailed
        }
        return text
    }

    public static func decodeJSON(_ text: String) throws -> ModuleLockfile {
        guard let data = text.data(using: .utf8) else {
            throw ModuleResolverError.decodingFailed
        }
        return try JSONDecoder().decode(ModuleLockfile.self, from: data)
    }
}
