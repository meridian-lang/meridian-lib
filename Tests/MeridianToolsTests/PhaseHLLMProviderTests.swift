import Testing
import Foundation
@testable import MeridianTools
import MeridianRuntime

@Suite("Phase H — LLM provider and fail-closed tools", .serialized)
struct PhaseHLLMProviderTests {
    @Test("llm.chat fails closed when provider is not configured")
    func llmChatNotConfigured() async {
        await #expect(throws: (any Error).self) {
            _ = try await MeridianTools.invoke("llm.chat", args: ["prompt": .string("hi")])
        }
        do {
            _ = try await MeridianTools.invoke("llm.chat", args: ["prompt": .string("hi")])
            Issue.record("expected throw")
        } catch {
            #expect(meridianMatches(error, named: "llm.not_configured"))
        }
    }

    @Test("llm.chat uses deterministic override for tests")
    func llmChatOverride() async throws {
        let result = try await LLMProviderRegistry.withOverride(DeterministicLLMProvider()) {
            try await MeridianTools.invoke("llm.chat", args: ["prompt": .string("hello")])
        }
        guard case .record(let dict) = result else {
            Issue.record("expected record")
            return
        }
        #expect(dict["content"] == .string("hello"))
        #expect(dict["role"] == .string("assistant"))
    }

    @Test("llm.decide uses deterministic provider when unset")
    func llmDecideDeterministic() async throws {
        let yes = try await MeridianTools.invoke("llm.decide", args: ["question": .string("yes please")])
        #expect(yes == .boolean(true))
        let no = try await MeridianTools.invoke("llm.decide", args: ["question": .string("no way")])
        #expect(no == .boolean(false))
    }

    @Test("mcp.call fails closed with typed error")
    func mcpCallFailsClosed() async {
        do {
            _ = try await MeridianTools.invoke("mcp.call", args: [:])
            Issue.record("expected throw")
        } catch {
            #expect(meridianMatches(error, named: "mcp.not_configured"))
        }
    }

    @Test("http.get fails closed when URL template is unresolved")
    func httpUnresolvedTemplate() async {
        let registry = ToolRegistry()
        await registry.registerBuiltins()
        do {
            _ = try await registry.dispatch(tool: "http.get", args: [:])
            Issue.record("expected throw")
        } catch let runtimeError as MeridianRuntimeError {
            if case .toolError(let toolError, _) = runtimeError,
               case .implementation(let code, _, _) = toolError {
                #expect(code == "http.not_configured")
            } else {
                Issue.record("unexpected runtime error \(runtimeError)")
            }
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }

    @Test("LLMEnvironment reads MERIDIAN_LLM_* variables")
    func environmentParsing() {
        let config = LLMEnvironment.configuration(from: [
            LLMEnvironment.apiURLKey: "https://example.com/v1/chat/completions",
            LLMEnvironment.apiKeyKey: "secret",
            LLMEnvironment.modelKey: "test-model",
        ])
        #expect(config?.model == "test-model")
        #expect(config?.apiKey == "secret")
        #expect(config?.apiURL.absoluteString == "https://example.com/v1/chat/completions")
        #expect(LLMEnvironment.configuration(from: [:]) == nil)
    }
}
