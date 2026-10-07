import Foundation
import Testing
@testable import MeridianCLIKit

@Suite("MeridianMCP executable smoke")
struct MeridianMCPSmokeTests {
    @Test("initialize handshake via MCPServer")
    func initializeHandshake() throws {
        let server = MCPServer()
        let response = try server.handle([
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [:] as [String: Any],
        ])
        let result = response["result"] as? [String: Any]
        #expect(result?["protocolVersion"] as? String == "2024-11-05")
        let info = result?["serverInfo"] as? [String: Any]
        #expect(info?["name"] as? String == "meridian")
    }

    @Test("tools/list exposes Meridian compile tools")
    func toolsList() throws {
        let server = MCPServer()
        let response = try server.handle([
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/list",
            "params": [:] as [String: Any],
        ])
        let result = response["result"] as? [String: Any]
        let tools = result?["tools"] as? [[String: Any]] ?? []
        let names = Set(tools.compactMap { $0["name"] as? String })
        #expect(names.contains("meridian_compile"))
        #expect(names.contains("meridian_explain"))
        #expect(names.count == 3)
    }

    @Test("MCP routes check, explain, and error paths")
    func toolRouting() throws {
        let server = MCPServer()
        let source = """
        ---
        vocabulary: t.merconfig
        ---
        To greet:
          complete.
        """
        let merconfig = "=== vocabulary ===\n"

        let checkOK = try server.callTool([
            "name": "meridian_check",
            "arguments": [
                "source": source, "file": "greet.meridian",
                "merconfig": merconfig, "merconfig_file": "t.merconfig",
                "rulebook": "=== desugar ===\n", "rulebook_file": "t.merrules",
            ] as [String: Any],
        ])
        #expect((checkOK["content"] as? [[String: Any]])?.first?["text"] as? String == "ok")

        let checkBad = try server.callTool([
            "name": "meridian_check",
            "arguments": ["source": "to frobnicate:\n  wibble", "file": "bad.meridian"] as [String: Any],
        ])
        #expect(checkBad["isError"] as? Bool == true)

        let explain = try server.callTool([
            "name": "meridian_explain",
            "arguments": ["source": source, "file": "greet.meridian", "merconfig": merconfig, "merconfig_file": "t.merconfig"] as [String: Any],
        ])
        let explainText = (explain["content"] as? [[String: Any]])?.first?["text"] as? String ?? ""
        #expect(explainText.contains("greet"))

        let routed = try server.handle([
            "jsonrpc": "2.0",
            "id": 5,
            "method": "tools/call",
            "params": [
                "name": "meridian_explain",
                "arguments": ["source": source, "file": "greet.meridian", "merconfig": merconfig, "merconfig_file": "t.merconfig"] as [String: Any],
            ] as [String: Any],
        ])
        #expect(routed["result"] != nil)

        let missingMethod = try server.handle([
            "jsonrpc": "2.0",
            "id": 3,
            "method": "nope",
        ])
        #expect((missingMethod["error"] as? [String: Any])?["code"] as? Int == -32601)

        let missingMethodField = try server.handle(["jsonrpc": "2.0", "id": 4])
        #expect((missingMethodField["error"] as? [String: Any])?["code"] as? Int == -32600)

        let initialized = try server.handle([
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
        ])
        #expect(initialized.isEmpty)

        #expect(throws: MCPRoutingError.self) {
            try server.callTool(["name": "missing_tool", "arguments": [:] as [String: Any]])
        }
    }
}
