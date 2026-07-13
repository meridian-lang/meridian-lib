import Testing
import Foundation
@testable import MeridianTools
import MeridianRuntime

@Suite("HTTP LLM provider transport", .serialized)
struct HTTPLLMProviderTransportTests {
    @Test("HTTPLLMProvider parses OpenAI-compatible chat completion JSON")
    func parsesChatCompletion() async throws {
        MockLLMURLProtocol.response = (
            statusCode: 200,
            body: """
            {"id":"chatcmpl-test","model":"mock-model","choices":[{"index":0,"message":{"role":"assistant","content":"hello world"},"finish_reason":"stop"}],"usage":{"prompt_tokens":3,"completion_tokens":2}}
            """
        )
        defer { MockLLMURLProtocol.response = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockLLMURLProtocol.self]
        let session = URLSession(configuration: config)
        let provider = HTTPLLMProvider(
            config: LLMEnvironment.Configuration(
                apiURL: URL(string: "https://mock.local/v1/chat/completions")!,
                apiKey: "test",
                model: "mock-model"
            ),
            session: session
        )
        let response = try await provider.complete(LLMRequest(
            messages: [LLMMessage(role: .user, content: "hi")],
            temperature: 0
        ))
        #expect(response.text == "hello world")
        #expect(response.model == "mock-model")
        #expect(response.inputTokens == 3)
        #expect(response.outputTokens == 2)
    }

    @Test("HTTPLLMProvider fails closed on HTTP error payloads")
    func failsClosedOnHTTPError() async {
        MockLLMURLProtocol.response = (
            statusCode: 401,
            body: #"{"error":{"message":"invalid api key"}}"#
        )
        defer { MockLLMURLProtocol.response = nil }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockLLMURLProtocol.self]
        let session = URLSession(configuration: config)
        let provider = HTTPLLMProvider(
            config: LLMEnvironment.Configuration(
                apiURL: URL(string: "https://mock.local/v1/chat/completions")!,
                apiKey: "bad",
                model: "mock-model"
            ),
            session: session
        )
        await #expect(throws: (any Error).self) {
            _ = try await provider.complete(LLMRequest(messages: [LLMMessage(role: .user, content: "hi")]))
        }
    }
}

@Suite("LLM planner JSON parsing")
struct LLMJSONParserTests {
    @Test("parsePlanProposal reads actions array")
    func planProposal() throws {
        let proposal = try LLMJSONParsers.parsePlanProposal(from: """
        {"actions":[{"tool_id":"shell.run","arguments":{"command":"echo hi"},"result_binding":"out"}],"rationale":"run"}
        """)
        #expect(proposal.actions.count == 1)
        #expect(proposal.actions[0].toolID == "shell.run")
        #expect(proposal.rationale == "run")
    }

    @Test("parseActProposal reads done and action shapes")
    func actProposal() throws {
        let done = try LLMJSONParsers.parseActProposal(from: #"{"kind":"done","reason":"finished"}"#)
        #expect(done == .done(reason: "finished"))
        let action = try LLMJSONParsers.parseActProposal(from: #"{"kind":"action","tool_id":"noop","arguments":{}}"#)
        if case .action(let proposed) = action {
            #expect(proposed.toolID == "noop")
        } else {
            Issue.record("expected action proposal")
        }
    }

    @Test("LLMChatPlanner uses planner JSON")
    func plannerUsesJSON() async throws {
        let provider = LLMChatProvider { _ in
            LLMResponse(
                text: #"{"actions":[{"tool_id":"noop"}],"rationale":"ok"}"#,
                model: "mock"
            )
        }
        let proposal = try await LLMChatPlanner(provider: provider).plan(
            PlanContext(prose: "do something", snapshot: StateSnapshot(bindings: [:]), tools: [])
        )
        #expect(proposal.actions.map(\.toolID) == ["noop"])
        #expect(proposal.rationale == "ok")
    }
}

private final class MockLLMURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: (statusCode: Int, body: String)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let response = Self.response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let url = request.url ?? URL(string: "https://mock.local/")!
        let http = HTTPURLResponse(url: url, statusCode: response.statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
