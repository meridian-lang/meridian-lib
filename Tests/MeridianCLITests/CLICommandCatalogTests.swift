import Foundation
import Testing
@testable import MeridianCLIKit

@Suite("CLI command catalog")
struct CLICommandCatalogTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static let knownLeafPaths: Set<String> = Set(MeridianCommandCatalog.leafPaths)

    @Test("catalog leaf paths are unique and cover the known registration set")
    func catalogCoversKnownLeaves() {
        let paths = MeridianCommandCatalog.leafPaths
        #expect(Set(paths).count == paths.count,
                Comment(rawValue: "duplicate catalog paths: \(paths)"))

        let catalog = Set(paths)
        #expect(catalog == Self.knownLeafPaths,
                Comment(rawValue: """
                catalog drift — missing: \(Self.knownLeafPaths.subtracting(catalog).sorted())
                extra: \(catalog.subtracting(Self.knownLeafPaths).sorted())
                """))
        #expect(paths.count == 30)
    }

    @Test("top-level registration order matches MeridianCommandCatalog")
    func registrationOrderMatchesCatalog() {
        let expected = MeridianCommandCatalog.registeredTopLevelCommandNames
        let actual = MeridianCLIRegistration.topLevelCommandNames
        #expect(actual == expected,
                Comment(rawValue: """
                CLI registration order drift
                expected: \(expected)
                actual:   \(actual)
                """))
    }

    @Test("every catalog leaf path is documented in docs/07_CLI.md")
    func cliDocCoversCatalog() throws {
        let doc = try String(
            contentsOf: repoRoot.appendingPathComponent("docs/07_CLI.md"),
            encoding: .utf8
        )
        var missing: [String] = []
        for entry in MeridianCommandCatalog.leafCommands {
            if entry.isTopLevelAlias {
                if !doc.contains("meridian \(entry.path)") {
                    missing.append(entry.path)
                }
                continue
            }
            let heading = "## `meridian \(entry.path)`"
            if doc.contains(heading) { continue }
            if doc.contains("/ `meridian \(entry.path)`") { continue }
            missing.append(entry.path)
        }
        #expect(missing.isEmpty,
                Comment(rawValue: "docs/07_CLI.md missing sections for: \(missing.sorted())"))
    }

    @Test("AGENTS.md CLI table mentions every catalog leaf or nested parent")
    func agentsTableCoversCatalog() throws {
        let agents = try String(
            contentsOf: repoRoot.appendingPathComponent("AGENTS.md"),
            encoding: .utf8
        )
        guard let tableStart = agents.range(of: "### CLI commands"),
              let tableEnd = agents[tableStart.upperBound...].range(of: "\n---\n") else {
            Issue.record("AGENTS.md CLI commands table not found")
            return
        }
        let table = String(agents[tableStart.upperBound ..< tableEnd.lowerBound])
        var missing: [String] = []
        for entry in MeridianCommandCatalog.leafCommands {
            let top = entry.path.split(separator: " ").first.map(String.init) ?? entry.path
            let mentionsLeaf = table.contains("`\(entry.path)`")
                || table.contains("`meridian \(entry.path)`")
            let mentionsTop = table.contains("`\(top)`")
                || (top == "trace" && table.contains("`trace "))
                || (top == "mcp" && table.contains("`mcp "))
            if !(mentionsLeaf || mentionsTop) {
                missing.append(entry.path)
            }
        }
        #expect(missing.isEmpty,
                Comment(rawValue: "AGENTS.md CLI table missing: \(missing.sorted())"))
    }

    @Test("module-path support flags match compile-family commands")
    func modulePathFlags() {
        let withModule = Set(
            MeridianCommandCatalog.leafCommands
                .filter(\.supportsModulePath)
                .map(\.path)
        )
        #expect(withModule == ["canonicalize", "check", "compile", "explain"])
    }

    @Test("leafPaths mirrors leafCommands and entry(forPath:) resolves aliases")
    func leafPathsAndEntryLookup() {
        #expect(MeridianCommandCatalog.leafPaths ==
                MeridianCommandCatalog.leafCommands.map(\.path))

        let compile = MeridianCommandCatalog.entry(forPath: "compile")
        #expect(compile?.supportsModulePath == true)
        #expect(compile?.isTopLevelAlias == false)
        #expect(compile?.purpose.contains("Compile") == true)

        let alias = MeridianCommandCatalog.entry(forPath: "trace-eval")
        #expect(alias?.isTopLevelAlias == true)

        #expect(MeridianCommandCatalog.entry(forPath: "not-a-command") == nil)

        let explicit = MeridianCommandCatalog.Entry(
            path: "probe", purpose: "coverage", supportsModulePath: false, isTopLevelAlias: true)
        #expect(explicit.isTopLevelAlias)
        let defaulted = MeridianCommandCatalog.Entry(
            path: "probe2", purpose: "coverage", supportsModulePath: false)
        #expect(!defaulted.isTopLevelAlias)
    }

    @Test("registration displayName falls back when commandName is nil")
    func registrationDisplayNameFallback() {
        #expect(MeridianCLIRegistration.displayName(commandName: "compile") == "compile")
        #expect(MeridianCLIRegistration.displayName(commandName: nil) == "<unnamed>")
    }
}
