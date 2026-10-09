import ArgumentParser
import Foundation

/// Marker for commands that declare a `--module-path` option. The command
/// catalog derives `Entry.supportsModulePath` from this conformance instead of
/// hand-maintaining a parallel list.
public protocol ModulePathSupporting {}

/// Single source of truth for every leaf `meridian` CLI command path, derived
/// from `MeridianCLIRegistration.topLevelCommands` so the catalog cannot drift
/// from the ArgumentParser registration: `purpose` is the command's
/// `configuration.abstract`, nested children come from
/// `configuration.subcommands`, and `--module-path` support is the
/// `ModulePathSupporting` marker.
public enum MeridianCommandCatalog {

    public struct Entry: Sendable, Hashable {
        public let path: String
        public let purpose: String
        public let supportsModulePath: Bool
        /// When true, the path is a top-level alias for a nested `trace` subcommand.
        public let isTopLevelAlias: Bool

        public init(path: String, purpose: String, supportsModulePath: Bool,
                    isTopLevelAlias: Bool = false) {
            self.path = path
            self.purpose = purpose
            self.supportsModulePath = supportsModulePath
            self.isTopLevelAlias = isTopLevelAlias
        }
    }

    /// Every documented leaf command path (includes top-level `trace-eval` /
    /// `trace-verify` aliases), in registration order.
    public static let leafCommands: [Entry] = makeLeafCommands()

    /// Top-level `ArgumentParser` registration order.
    public static var registeredTopLevelCommandNames: [String] {
        MeridianCLIRegistration.topLevelCommandNames
    }

    public static var leafPaths: [String] {
        leafCommands.map(\.path)
    }

    public static func entry(forPath path: String) -> Entry? {
        leafCommands.first { $0.path == path }
    }

    private static func makeLeafCommands() -> [Entry] {
        var entries: [Entry] = []
        for command in MeridianCLIRegistration.topLevelCommands {
            let configuration = command.configuration
            let name = MeridianCLIRegistration.displayName(commandName: configuration.commandName)
            if configuration.subcommands.isEmpty {
                entries.append(Entry(
                    path: name,
                    purpose: purpose(of: configuration),
                    supportsModulePath: command is ModulePathSupporting.Type
                ))
                continue
            }
            for sub in configuration.subcommands {
                let subName = MeridianCLIRegistration.displayName(commandName: sub.configuration.commandName)
                entries.append(Entry(
                    path: "\(name) \(subName)",
                    purpose: purpose(of: sub.configuration),
                    supportsModulePath: sub is ModulePathSupporting.Type
                ))
            }
        }
        // A top-level command whose dash-joined name matches a nested leaf path
        // (`trace-eval` for `trace eval`) is the discoverability alias
        // ArgumentParser registers alongside the nested command.
        let nestedPaths = Set(entries.map(\.path).filter { $0.contains(" ") })
        return entries.map { entry in
            guard nestedPaths.contains(entry.path.replacingOccurrences(of: "-", with: " ")) else {
                return entry
            }
            return Entry(path: entry.path, purpose: entry.purpose,
                         supportsModulePath: entry.supportsModulePath, isTopLevelAlias: true)
        }
    }

    /// Catalog purpose for one command: its `configuration.abstract`, falling
    /// back to the command name when a command declares no abstract.
    static func purpose(of configuration: CommandConfiguration) -> String {
        let abstract = configuration.abstract
        if !abstract.isEmpty { return abstract }
        return MeridianCLIRegistration.displayName(commandName: configuration.commandName)
    }
}
