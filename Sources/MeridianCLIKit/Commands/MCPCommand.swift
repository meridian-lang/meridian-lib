import ArgumentParser
import Foundation

public struct MCPCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Model Context Protocol integration for Meridian.",
        subcommands: [MCPServeCommand.self]
    )
}

public struct MCPServeCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Run a stdio MCP server exposing compile/check/explain tools."
    )

    @Flag(name: .long, help: "Handle one request from stdin and exit (for tests).")
    var once: Bool = false

    public func run() async throws {
        let server = MCPServer()
        if once {
            guard let request = try MCPStdioTransport.readMessage() else { return }
            let response = try server.handle(request)
            try MCPStdioTransport.writeMessage(response)
            return
        }

        while true {
            guard let request = try MCPStdioTransport.readMessage() else { break }
            let response = try server.handle(request)
            try MCPStdioTransport.writeMessage(response)
        }
    }
}
