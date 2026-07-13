import MeridianCLIKit

@main
struct MeridianMCP {
    static func main() async throws {
        try await MCPServeCommand().run()
    }
}
