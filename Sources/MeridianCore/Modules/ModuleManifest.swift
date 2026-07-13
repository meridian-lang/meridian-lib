import Foundation

public enum ModuleVisibility: String, Sendable, Codable {
    case `public`
    case `internal`
}

/// Metadata for a resolved Meridian module package (`module.meridian` frontmatter
/// or inferred from the directory / `module.merconfig` stem).
public struct ModuleManifest: Sendable, Equatable {
    public let id: String
    public let version: String?
    public let visibility: ModuleVisibility
    /// Kind / tool / constant names that importers must not override.
    public let sealedExports: Set<String>

    public init(
        id: String,
        version: String? = nil,
        visibility: ModuleVisibility = .public,
        sealedExports: Set<String> = []
    ) {
        self.id = id
        self.version = version
        self.visibility = visibility
        self.sealedExports = sealedExports
    }

    /// Parse optional YAML frontmatter from a `module.meridian` (or any meridian
    /// wrapper) source. Returns `nil` when no `module:` key is present.
    public static func parse(fromMeridianSource source: String, file: String) -> ModuleManifest? {
        guard let metadata = parseFrontmatter(source) else { return nil }
        guard let rawID = metadata["module"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawID.isEmpty else { return nil }
        let version = metadata["version"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let visibility = ModuleVisibility(rawValue: metadata["exports"]?
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "public") ?? .public
        let sealed = parseSealedList(metadata["sealed"])
        return ModuleManifest(id: rawID, version: version?.isEmpty == true ? nil : version,
                              visibility: visibility, sealedExports: sealed)
    }

    /// Infer a manifest from a package directory name when no explicit manifest exists.
    public static func inferred(id: String) -> ModuleManifest {
        ModuleManifest(id: id)
    }

    private static func parseFrontmatter(_ source: String) -> [String: String]? {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        var entries: [String: String] = [:]
        var i = 1
        while i < lines.count {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            if let colon = line.firstIndex(of: ":") {
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
                var value = String(line[line.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }
                entries[key] = value
            }
            i += 1
        }
        return entries.isEmpty ? nil : entries
    }

    private static func parseSealedList(_ raw: String?) -> Set<String> {
        guard let raw else { return [] }
        return Set(raw.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty })
    }
}

/// A single `import <module> [as <alias>]` request harvested from frontmatter,
/// `=== imports ===`, or a module manifest.
public struct ModuleImportSpec: Sendable, Equatable {
    public let name: String
    public let alias: String?
    public let sourceFile: String
    public let sourceLine: Int

    public init(name: String, alias: String? = nil, sourceFile: String, sourceLine: Int) {
        self.name = name
        self.alias = alias
        self.sourceFile = sourceFile
        self.sourceLine = sourceLine
    }
}
