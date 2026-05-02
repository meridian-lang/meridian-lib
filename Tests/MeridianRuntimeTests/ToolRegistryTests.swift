import Testing
import Foundation
import Network
@testable import MeridianRuntime

@Suite("ToolRegistry")
struct ToolRegistryTests {

    @Test("register and dispatch closure tool")
    func closureDispatch() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "greet", .closure { args in
            let name = (args["name"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }) ?? "World"
            return .string("Hello, \(name)!")
        })
        let hasTool = await registry.has(tool: "greet")
        #expect(hasTool)
        let result = try await registry.dispatch(tool: "greet", args: ["name": .string("Alice")])
        #expect(result == .string("Hello, Alice!"))
    }

    @Test("dispatch unknown tool throws toolNotFound")
    func unknownToolThrows() async throws {
        let registry = ToolRegistry()
        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await registry.dispatch(tool: "nonexistent", args: [:])
        }
    }

    @Test("unregister removes tool")
    func unregister() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "t", .closure { _ in .null })
        await registry.unregister(tool: "t")
        let hasTool = await registry.has(tool: "t")
        #expect(!hasTool)
    }

    @Test("toolIDs lists registered tools")
    func toolIDs() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "a", .closure { _ in .null })
        await registry.register(tool: "b", .closure { _ in .null })
        let ids = Set(await registry.toolIDs())
        #expect(ids.contains("a"))
        #expect(ids.contains("b"))
    }

    @Test("invoke.start redacts configured keys recursively")
    func invokeStartRedactsConfiguredKeys() async throws {
        let registry = ToolRegistry()
        let observer = InMemoryObserver()
        await registry.register(
            tool: "secret.tool",
            .closure { _ in .string("ok") },
            redactionPolicy: .redactKeys(["token"])
        )
        let runtime = Runtime(toolRegistry: registry, observer: observer)

        _ = try await runtime.invoke(tool: "secret.tool", args: [
            "token": .string("root-secret"),
            "nested": .record(["token": .string("nested-secret"), "safe": .string("visible")])
        ])

        let event = try #require(await observer.events.first { $0.kind == .invokeStart })
        guard case .record(let args)? = event.payload["args"] else {
            Issue.record("Expected invoke.start args record")
            return
        }
        #expect(args["token"] == .string("<redacted>"))
        guard case .record(let nested)? = args["nested"] else {
            Issue.record("Expected nested record")
            return
        }
        #expect(nested["token"] == .string("<redacted>"))
        #expect(nested["safe"] == .string("visible"))
    }

    @Test("closure tool error wraps in MeridianRuntimeError")
    func closureToolError() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "fail", .closure { _ in
            throw ToolError.implementation(code: "boom", message: "test error", cause: nil)
        })
        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await registry.dispatch(tool: "fail", args: [:])
        }
    }

    @Test("subprocess tool captures stdout, stderr, and exit code")
    func subprocessDispatchSuccess() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "echo", .subprocess(SubprocessSpec(
            binary: "/bin/sh",
            argTemplate: ["-c", "printf hello"]
        )))

        let result = try await registry.dispatch(tool: "echo", args: [:])
        guard case .record(let record) = result else {
            Issue.record("Expected record, got \(result)")
            return
        }
        #expect(record["stdout"] == .string("hello"))
        #expect(record["exitCode"] == .number(0))
    }

    @Test("subprocess non-zero exit throws a named recoverable error")
    func subprocessDispatchFailureMatchesRecoverName() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "fail-script", .subprocess(SubprocessSpec(
            binary: "/bin/sh",
            argTemplate: ["-c", "printf nope >&2; exit 7"]
        )))

        do {
            _ = try await registry.dispatch(tool: "fail-script", args: [:])
            Issue.record("Expected subprocess failure")
        } catch {
            #expect(meridianMatches(error, named: "subprocess.exit_failure"))
        }
    }

    @Test("subprocess can fail once and then succeed, matching the recover forcing shape")
    func subprocessFirstFailSecondSucceeds() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-subprocess-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let marker = dir.appendingPathComponent("marker").path
        let script = """
        if [ ! -f "\(marker)" ]; then
          touch "\(marker)"
          echo first >&2
          exit 42
        fi
        echo second
        """

        let registry = ToolRegistry()
        await registry.register(tool: "flaky", .subprocess(SubprocessSpec(
            binary: "/bin/sh",
            argTemplate: ["-c", script]
        )))

        do {
            _ = try await registry.dispatch(tool: "flaky", args: [:])
            Issue.record("Expected first call to fail")
        } catch {
            #expect(meridianMatches(error, named: "subprocess.exit_failure"))
        }

        let result = try await registry.dispatch(tool: "flaky", args: [:])
        guard case .record(let record) = result else {
            Issue.record("Expected record, got \(result)")
            return
        }
        #expect(record["stdout"] == .string("second\n"))
    }

    @Test("subprocess timeout terminates and throws a named timeout")
    func subprocessTimeoutThrows() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "slow", .subprocess(SubprocessSpec(
            binary: "/bin/sh",
            argTemplate: ["-c", "sleep 2"],
            timeout: .milliseconds(100)
        )))

        do {
            _ = try await registry.dispatch(tool: "slow", args: [:])
            Issue.record("Expected subprocess timeout")
        } catch {
            #expect(meridianMatches(error, named: "subprocess.timeout"))
        }
    }

    @Test("http tool rejects malformed URL through argument coercion")
    func httpMalformedURLThrows() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "http", .http(HTTPSpec(url: "not a url")))

        do {
            _ = try await registry.dispatch(tool: "http", args: [:])
            Issue.record("Expected malformed URL to throw")
        } catch {
            #expect(meridianMatches(error, named: "tool.argument_coercion"))
        }
    }

    @Test("http tool returns status headers and body on success")
    func httpSuccessReturnsStructuredResult() async throws {
        let server = try await JSONRPCServer.start(responseBody: #"{"ok":true}"#)
        defer { server.cancel() }

        let registry = ToolRegistry()
        await registry.register(tool: "http", .http(HTTPSpec(url: server.url, method: "POST", headers: ["X-Test": "yes"])))
        let result = try await registry.dispatch(tool: "http", args: [
            "body": .record(["hello": .string("world")])
        ])

        guard case .record(let dict) = result else {
            Issue.record("Expected HTTP record result")
            return
        }
        #expect(dict["status"] == .number(200))
        #expect(dict["body"] == .string(#"{"ok":true}"#))
        guard case .record(let headers)? = dict["headers"] else {
            Issue.record("Expected response headers")
            return
        }
        #expect(headers["Content-Type"] == .string("application/json"))
    }

    @Test("mcp.call supports subprocess stdio transport")
    func mcpStdioTransport() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "mcp.call", .mcp(MCPSpec()))

        let result = try await registry.dispatch(tool: "mcp.call", args: [
            "transport": .string("stdio"),
            "binary": .string("/bin/sh"),
            "arguments": .list([
                .string("-c"),
                .string(#"cat >/dev/null; printf '{"jsonrpc":"2.0","id":1,"result":{"ok":true}}'"#)
            ]),
            "method": .string("ping"),
            "params": .record([:])
        ])

        guard case .record(let dict) = result else {
            Issue.record("Expected MCP record result")
            return
        }
        #expect(dict["ok"] == .boolean(true))
    }

    @Test("mcp.call supports HTTP JSON-RPC transport")
    func mcpHTTPTransport() async throws {
        let server = try await JSONRPCServer.start(responseBody: #"{"jsonrpc":"2.0","id":1,"result":{"pong":true}}"#)
        defer { server.cancel() }

        let registry = ToolRegistry()
        await registry.register(tool: "mcp.call", .mcp(MCPSpec()))
        let result = try await registry.dispatch(tool: "mcp.call", args: [
            "transport": .string("http"),
            "url": .string(server.url),
            "method": .string("ping"),
            "params": .record(["name": .string("Meridian")])
        ])

        guard case .record(let dict) = result else {
            Issue.record("Expected MCP record result")
            return
        }
        #expect(dict["pong"] == .boolean(true))
    }
}

private final class JSONRPCServer: @unchecked Sendable {
    let listener: NWListener
    let url: String

    private init(listener: NWListener, port: UInt16) {
        self.listener = listener
        self.url = "http://127.0.0.1:\(port)"
    }

    static func start(responseBody: String) async throws -> JSONRPCServer {
        let listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { _, _, _, _ in
                let response = """
                HTTP/1.1 200 OK\r
                Content-Type: application/json\r
                Content-Length: \(responseBody.utf8.count)\r
                Connection: close\r
                \r
                \(responseBody)
                """
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: .global())
        }

        guard let port = listener.port?.rawValue else {
            throw ToolError.implementation(code: "test.server", message: "listener did not expose a port", cause: nil)
        }
        return JSONRPCServer(listener: listener, port: port)
    }

    func cancel() {
        listener.cancel()
    }
}
