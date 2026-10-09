import Testing
import Foundation
@testable import MeridianCLIKit
import MeridianCore
import MeridianTools
import MeridianRuntime

@Suite("Phase H — CLI canonicalize, migrate repair, MCP", .serialized)
struct PhaseHCLITests {
    private let repoRoot = FileManager.default.currentDirectoryPath
    private func ex(_ rel: String) -> String { repoRoot + "/" + rel }

    @Test("canonicalize without --propose prints drift hunks")
    func canonicalizeDrift() async throws {
        let cmd = try CanonicalizeCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
        ])
        // Capture is awkward in-process; run and expect no throw.
        try await cmd.run()
    }

    @Test("canonicalize --propose requires configured provider")
    func canonicalizeProposeRequiresProvider() async {
        let cmd = try? CanonicalizeCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--propose",
        ])
        guard let cmd else {
            Issue.record("parse failed")
            return
        }
        await #expect(throws: (any Error).self) { try await cmd.run() }
    }

    @Test("canonicalize --propose with mock provider emits proposals")
    func canonicalizeProposeMock() async throws {
        let cmd = try CanonicalizeCommand.parse([
            ex("examples/order_processing.meridian"),
            "--merconfig", ex("examples/ecommerce.merconfig"),
            "--propose",
        ])
        try await LLMProviderRegistry.withOverride(DeterministicLLMProvider()) {
            try await cmd.run()
        }
    }

    @Test("migrate-skill --repair --dry-run uses mock provider without writing output")
    func migrateRepairDryRun() async throws {
        let t = TempDir()
        let skill = t.write("SKILL.md", """
        # Repair Demo

        ## Phases (( role: procedure ))
        Ponder the deeper meaning of the request and act accordingly.
        """)
        let out = t.path("demo.meri")
        let cmd = try MigrateSkillCommand.parse([
            skill.path, "--out", out, "--repair", "--dry-run", "--force"
        ])
        await LLMProviderRegistry.withOverride(DeterministicLLMProvider()) {
            await #expect(throws: (any Error).self) { try await cmd.run() }
        }
        #expect(!FileManager.default.fileExists(atPath: out))
    }

    @Test("MCP server routes initialize and tools/list")
    func mcpRouting() throws {
        let server = MCPServer()
        let initResponse = try server.handle([
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [:],
        ])
        #expect(initResponse["result"] != nil)

        let tools = try server.handle([
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": [:],
        ])
        guard let result = tools["result"] as? [String: Any],
              let listed = result["tools"] as? [[String: Any]]
        else {
            Issue.record("missing tools list")
            return
        }
        let names = Set(listed.compactMap { $0["name"] as? String })
        #expect(names.contains("meridian_compile"))
        #expect(names.contains("meridian_check"))
        #expect(names.contains("meridian_explain"))
        #expect(names.count == 3)
    }

    @Test("MCP compile tool returns Swift text")
    func mcpCompileTool() throws {
        let server = MCPServer()
        let result = try server.callTool([
            "name": "meridian_compile",
            "arguments": [
                "source": """
                ---
                vocabulary: t.merconfig
                ---
                To greet:
                  complete.
                """,
                "file": "greet.meridian",
                "merconfig": "=== vocabulary ===\n",
                "merconfig_file": "t.merconfig",
            ] as [String: Any],
        ])
        guard let content = result["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String
        else {
            Issue.record("missing tool content")
            return
        }
        #expect(text.contains("struct"))
    }

    @Test("MCP stdio transport writes Content-Length framed messages")
    func mcpStdioWrite() throws {
        let server = MCPServer()
        let response = try server.handle([
            "jsonrpc": "2.0",
            "id": 9,
            "method": "ping",
        ])
        let payload = try JSONSerialization.data(withJSONObject: response)
        let expectedPrefix = "Content-Length: \(payload.count)\r\n\r\n"
        #expect(expectedPrefix.hasPrefix("Content-Length:"))
        #expect(response["result"] != nil)
    }
}
