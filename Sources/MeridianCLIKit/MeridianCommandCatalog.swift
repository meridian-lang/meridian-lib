import Foundation

/// Single source of truth for every leaf `meridian` CLI command path.
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

    /// Every documented leaf command path (includes top-level `trace-eval` / `trace-verify` aliases).
    public static let leafCommands: [Entry] = [
        Entry(path: "canonicalize",
              purpose: "Compare authored Meridian to canonical English and optionally propose surface rewrites.",
              supportsModulePath: true),
        Entry(path: "mcp serve",
              purpose: "Run a stdio MCP server exposing compile/check/explain tools.",
              supportsModulePath: false),
        Entry(path: "compile",
              purpose: "Compile a .meridian file to Swift source and a companion manifest.",
              supportsModulePath: true),
        Entry(path: "explain",
              purpose: "Print the canonical verbalized form of a .meridian/.meri skill.",
              supportsModulePath: true),
        Entry(path: "explain-swift",
              purpose: "Explain Meridian-generated Swift using a companion .meridian.ir.json sidecar.",
              supportsModulePath: false),
        Entry(path: "drift",
              purpose: "Compare authored Meridian source to its canonical verbalized form.",
              supportsModulePath: false),
        Entry(path: "grammar-doc",
              purpose: "Emit a markdown reference for Meridian's canonical surface grammar.",
              supportsModulePath: false),
        Entry(path: "lint",
              purpose: "Report Meridian authoring diagnostics without compiling.",
              supportsModulePath: false),
        Entry(path: "preview-skill",
              purpose: "Preview a SKILL.md file as Meridian surface syntax.",
              supportsModulePath: false),
        Entry(path: "migrate-skill",
              purpose: "Migrate a gbrain SKILL.md into a strict-compiling .meri file.",
              supportsModulePath: false),
        Entry(path: "skill-deviation",
              purpose: "Report how a ported .meri deviates from its original SKILL.md.",
              supportsModulePath: false),
        Entry(path: "inert-yield",
              purpose: "Measure how many inert sections would lower today with real vocabulary/rulebook knowledge.",
              supportsModulePath: false),
        Entry(path: "check",
              purpose: "Parse + lower a .meridian file and report diagnostics without writing output.",
              supportsModulePath: true),
        Entry(path: "format",
              purpose: "Canonicalise the whitespace of .meridian / .merconfig sources.",
              supportsModulePath: false),
        Entry(path: "docs",
              purpose: "Render .merconfig files to a static HTML reference.",
              supportsModulePath: false),
        Entry(path: "test",
              purpose: "Discover and run .meridian.test specs.",
              supportsModulePath: false),
        Entry(path: "trace categories",
              purpose: "List the compile-time trace categories accepted by --trace.",
              supportsModulePath: false),
        Entry(path: "trace render",
              purpose: "Render a JSONL trace as an indented tree.",
              supportsModulePath: false),
        Entry(path: "trace verify",
              purpose: "Verify a semantic trace-store JSONL file for tampering and chain integrity.",
              supportsModulePath: false),
        Entry(path: "trace eval",
              purpose: "Replay-evaluate a trace-temporal or trace-statistical expression.",
              supportsModulePath: false),
        Entry(path: "trace drift",
              purpose: "Compare trace step identities between two manifests.",
              supportsModulePath: false),
        Entry(path: "trace-eval",
              purpose: "Top-level alias for `trace eval`.",
              supportsModulePath: false,
              isTopLevelAlias: true),
        Entry(path: "trace-verify",
              purpose: "Top-level alias for `trace verify`.",
              supportsModulePath: false,
              isTopLevelAlias: true),
        Entry(path: "run",
              purpose: "Compile and execute a .meridian workflow in a temporary Swift package.",
              supportsModulePath: false),
        Entry(path: "verify",
              purpose: "Alias for check: parse, lower, and report diagnostics without writing output.",
              supportsModulePath: false),
        Entry(path: "resume",
              purpose: "Load the latest checkpoint for a run and print the restored context.",
              supportsModulePath: false),
        Entry(path: "explain-diag",
              purpose: "Explain a diagnostic code (MERxxxx) or a design decision (D-DX-n).",
              supportsModulePath: false),
        Entry(path: "decisions",
              purpose: "List, search, or render the design-decision catalog.",
              supportsModulePath: false),
        Entry(path: "bench-parse",
              purpose: "Benchmark unscreened vs NonterminalScreen-gated expression parsing over text files.",
              supportsModulePath: false),
        Entry(path: "bench-trace",
              purpose: "Benchmark replay query latency over synthetic trace stores.",
              supportsModulePath: false),
    ]

    /// Top-level `ArgumentParser` registration order — must match `MeridianCLI` in `CLI.swift`.
    public static let registeredTopLevelCommandNames: [String] = [
        "canonicalize",
        "mcp",
        "compile",
        "explain",
        "explain-swift",
        "drift",
        "grammar-doc",
        "lint",
        "preview-skill",
        "migrate-skill",
        "skill-deviation",
        "inert-yield",
        "check",
        "format",
        "docs",
        "test",
        "trace",
        "trace-eval",
        "trace-verify",
        "run",
        "verify",
        "resume",
        "explain-diag",
        "decisions",
        "bench-parse",
        "bench-trace",
    ]

    public static var leafPaths: [String] {
        leafCommands.map(\.path)
    }

    public static func entry(forPath path: String) -> Entry? {
        leafCommands.first { $0.path == path }
    }
}
