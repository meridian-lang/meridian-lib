import Testing
import Foundation
@testable import MeridianRuntime

@Suite("ToolRegistry — registration, schema, dispatch")
struct ToolRegistryCoverageTests {
    @Test("register / has / unregister / toolIDs")
    func registration() async {
        let reg = ToolRegistry()
        await reg.register(tool: "a.tool", .closure { _ in .null })
        #expect(await reg.has(tool: "a.tool"))
        #expect(await reg.toolIDs().contains("a.tool"))
        await reg.unregister(tool: "a.tool")
        #expect(!(await reg.has(tool: "a.tool")))
    }

    @Test("schema, schemas, and redaction policy lookups")
    func schemaLookups() async {
        let reg = ToolRegistry()
        await reg.register(tool: "x", .closure { _ in .null },
                           redactionPolicy: .redactKeys(["secret"]),
                           schema: ToolSchema(id: "x", arguments: [ToolArgSpec(name: "a")]))
        await reg.register(tool: "y", .closure { _ in .null })   // default schema
        #expect(await reg.schema(for: "x")?.arguments.count == 1)
        #expect(await reg.schema(for: "missing") == nil)
        #expect(await reg.schemas(["x", "y"]).map(\.id) == ["x", "y"])
        if case .redactKeys(let keys) = await reg.redactionPolicy(for: "x") {
            #expect(keys == ["secret"])
        } else { Issue.record("expected redactKeys") }
        if case .none = await reg.redactionPolicy(for: "missing") {} else { Issue.record("expected none") }
    }

    @Test("closure dispatch returns its value")
    func closureSuccess() async throws {
        let reg = ToolRegistry()
        await reg.register(tool: "echo", .closure { args in args["v"] ?? .null })
        #expect(try await reg.dispatch(tool: "echo", args: ["v": .string("hi")]) == .string("hi"))
    }

    @Test("a ToolError from a closure is wrapped as MeridianRuntimeError.toolError")
    func closureToolError() async {
        let reg = ToolRegistry()
        await reg.register(tool: "boom", .closure { _ in
            throw ToolError.implementation(code: "my.code", message: "nope", cause: nil)
        })
        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await reg.dispatch(tool: "boom", args: [:])
        }
    }

    @Test("a generic error from a closure is wrapped with tool_error code")
    func closureGenericError() async {
        struct E: Error {}
        let reg = ToolRegistry()
        await reg.register(tool: "boom", .closure { _ in throw E() })
        do {
            _ = try await reg.dispatch(tool: "boom", args: [:])
            Issue.record("expected throw")
        } catch let MeridianRuntimeError.toolError(.implementation(code, _, _), _) {
            #expect(code == "tool_error")
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test("dispatching an unknown tool throws toolNotFound")
    func unknownTool() async {
        let reg = ToolRegistry()
        do {
            _ = try await reg.dispatch(tool: "nope", args: [:])
            Issue.record("expected throw")
        } catch let MeridianRuntimeError.toolNotFound(id) {
            #expect(id == "nope")
        } catch { Issue.record("unexpected \(error)") }
    }

    @Test("subprocess dispatch captures stdout for a successful command")
    func subprocessSuccess() async throws {
        let reg = ToolRegistry()
        await reg.register(tool: "echo", .subprocess(SubprocessSpec(binary: "/bin/echo", argTemplate: ["{msg}"])))
        let result = try await reg.dispatch(tool: "echo", args: ["msg": .string("hello")])
        if case .record(let r) = result, case .string(let out)? = r["stdout"] {
            #expect(out.contains("hello"))
            #expect(r["exitCode"] == .number(0))
        } else { Issue.record("expected record with stdout") }
    }

    @Test("subprocess dispatch surfaces a non-zero exit as a subprocess ToolError")
    func subprocessFailure() async {
        let reg = ToolRegistry()
        await reg.register(tool: "false", .subprocess(SubprocessSpec(binary: "/usr/bin/false")))
        do {
            _ = try await reg.dispatch(tool: "false", args: [:])
            Issue.record("expected throw")
        } catch let MeridianRuntimeError.toolError(.subprocess(err), _) {
            #expect(err.exitCode != 0)
        } catch { Issue.record("unexpected \(error)") }
    }

    @Test("MCP dynamic transport without a url is an argument coercion error")
    func mcpMissingURL() async {
        let reg = ToolRegistry()
        await reg.register(tool: "mcp", .mcp(MCPSpec(transport: .dynamic)))
        await #expect(throws: MeridianRuntimeError.self) {
            _ = try await reg.dispatch(tool: "mcp", args: ["method": .string("ping")])
        }
    }
}
