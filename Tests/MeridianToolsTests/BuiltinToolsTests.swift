import Testing
import Foundation
@testable import MeridianTools
import MeridianRuntime
import MeridianCore

@Suite("MeridianTools built-ins")
struct BuiltinToolsTests {

    @Test("allToolIDs lists Blueprint tool families and they are unique")
    func toolListIsCanonical() {
        #expect(MeridianTools.allToolIDs.count == 21)
        #expect(Set(MeridianTools.allToolIDs).count == MeridianTools.allToolIDs.count)
        #expect(MeridianTools.allToolIDs.contains("http.get"))
        #expect(MeridianTools.allToolIDs.contains("uuid.generate"))
        #expect(!MeridianTools.allToolIDs.contains("validateOrder"))
    }

    @Test("json.parse and json.stringify round-trip basic values")
    func jsonRoundTrip() async throws {
        let parsed = try await MeridianTools.invoke("json.parse", args: ["text": .string(#"{"name":"Ada","n":2}"#)])
        guard case .record(let dict) = parsed else {
            Issue.record("Expected parsed record")
            return
        }
        #expect(dict["name"] == .string("Ada"))

        let stringified = try await MeridianTools.invoke("json.stringify", args: ["value": parsed])
        guard case .string(let text) = stringified else {
            Issue.record("Expected string")
            return
        }
        #expect(text.contains(#""name":"Ada""#))
    }

    @Test("regex.match returns matches and matched flag")
    func regexMatch() async throws {
        let result = try await MeridianTools.invoke("regex.match", args: [
            "pattern": .string("[0-9]+"),
            "text": .string("order 42")
        ])
        guard case .record(let dict) = result else {
            Issue.record("Expected record")
            return
        }
        #expect(dict["matched"] == .boolean(true))
        guard case .list(let matches)? = dict["matches"],
              case .record(let first)? = matches.first
        else {
            Issue.record("Expected structured regex match")
            return
        }
        #expect(first["text"] == .string("42"))
        #expect(first["groups"] == .list([.string("42")]))
    }

    @Test("json.transform supports nested object and array paths")
    func jsonTransformPath() async throws {
        let result = try await MeridianTools.invoke("json.transform", args: [
            "value": .record([
                "orders": .list([
                    .record(["id": .string("a")]),
                    .record(["id": .string("b")])
                ])
            ]),
            "path": .string("orders[1].id")
        ])
        #expect(result == .string("b"))
    }

    @Test("time.format supports explicit format and timezone")
    func timeFormat() async throws {
        let result = try await MeridianTools.invoke("time.format", args: [
            "value": .dateTime(Date(timeIntervalSince1970: 0)),
            "format": .string("yyyy-MM-dd HH:mm"),
            "timezone": .string("UTC")
        ])
        #expect(result == .string("1970-01-01 00:00"))
    }

    @Test("validate.json_schema catches missing required fields")
    func validateJSONSchema() async throws {
        let result = try await MeridianTools.invoke("validate.json_schema", args: [
            "schema": .record(["required": .list([.string("id")])]),
            "value": .record([:])
        ])
        guard case .record(let dict) = result else {
            Issue.record("Expected record")
            return
        }
        #expect(dict["valid"] == .boolean(false))
    }

    @Test("unknown tool ID returns .null instead of trapping")
    func unknownToolReturnsNull() async throws {
        #expect(try await MeridianTools.invoke("totallyMadeUpTool") == .null)
    }

    @Test("llm.chat throws explicit not-implemented error")
    func llmChatThrows() async throws {
        do {
            _ = try await MeridianTools.invoke("llm.chat", args: [:])
            Issue.record("Expected llm.chat to throw")
        } catch {
            #expect(meridianMatches(error, named: "llm.not_implemented"))
        }
    }

    @Test("llm.decide default returns false deterministically")
    func llmDecideDefault() async throws {
        let result = try await MeridianTools.invoke("llm.decide", args: [
            "question": .string("Should we ship this PR?")
        ])
        #expect(result == .boolean(false),
                Comment(rawValue: "Default llm.decide must be deterministic .boolean(false), got: \(result)"))
    }

    @Test("llm.decide host override via ToolRegistry closure replaces default")
    func llmDecideHostOverride() async throws {
        // The default `llm.decide` returns .boolean(false). A host can
        // register their own closure to delegate to a real LLM (or a mock
        // that captures the question text). This proves the override path
        // works end-to-end with the runtime dispatcher, which is the
        // mechanism documented for hosts in docs/06_RUNTIME.md.
        let registry = ToolRegistry()
        await registry.registerBuiltins()
        // Override after the default was registered. ToolRegistry's
        // last-write-wins semantics replace the default closure.
        await registry.register(tool: "llm.decide", .closure { args in
            guard case .string(let question)? = args["question"] else {
                return .boolean(false)
            }
            // Mock: yes if the question contains "ship".
            return .boolean(question.lowercased().contains("ship"))
        })
        let yes = try await registry.dispatch(tool: "llm.decide", args: [
            "question": .string("Should we ship this PR?")
        ])
        #expect(yes == .boolean(true))

        let no = try await registry.dispatch(tool: "llm.decide", args: [
            "question": .string("Should we abandon the project?")
        ])
        #expect(no == .boolean(false))
    }

    @Test("`bind X = decide whether ...` lowers to runtime discretion protocol call")
    func decideWhetherCompilesToLLMDecide() async throws {
        // End-to-end: compile a meridian source that uses `decide whether ...`
        // as a bind expression and verify codegen routes through the
        // `Discretion` protocol instead of the normal tool registry.
        let mer = """
        ---
        vocabulary: test.merconfig
        ---

        To assess a request:
          bind should act = decide whether the request looks risky.
          complete.
        """
        let cfg = """
        === vocabulary ===
        request is a kind of thing.
        """
        let out = try MeridianCore.Compiler(options: .init()).compile(
            meridianSource: mer, meridianFile: "decide.meridian",
            merconfigSource: cfg, merconfigFile: "test.merconfig"
        )
        #expect(out.contains("runtime.discretion.decide"),
                Comment(rawValue: "Expected runtime.discretion.decide in generated Swift:\n\(String(out.prefix(2000)))"))
        #expect(out.contains("DiscretionContext"),
                Comment(rawValue: "Expected DiscretionContext in generated Swift:\n\(String(out.prefix(2000)))"))
        // The bind name is camelCased.
        #expect(out.contains("shouldAct"),
                Comment(rawValue: "Expected the bind variable in:\n\(String(out.prefix(2000)))"))
    }

    @Test("registerBuiltins wires every tool into a ToolRegistry and dispatch round-trips")
    func registryIntegration() async throws {
        let registry = ToolRegistry()
        await registry.registerBuiltins()
        for toolID in MeridianTools.allToolIDs {
            let has = await registry.has(tool: toolID)
            #expect(has, "expected \(toolID) registered")
        }
        let result = try await registry.dispatch(tool: "shell.run", args: ["command": .string("printf hi")])
        guard case .record(let dict) = result else {
            Issue.record("shell.run did not return a record")
            return
        }
        #expect(dict["stdout"] == .string("hi"))
    }
}
