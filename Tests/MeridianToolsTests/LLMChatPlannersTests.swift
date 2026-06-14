import Testing
import Foundation
@testable import MeridianTools
import MeridianRuntime

private actor RecordingProvider: LLMProvider {
    private(set) var lastRequest: LLMRequest?
    private let reply: String
    init(reply: String) { self.reply = reply }
    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        lastRequest = request
        return LLMResponse(text: reply, model: "mock")
    }
    func recorded() -> LLMRequest? { lastRequest }
}

@Suite("LLMChat planners wrap an LLMProvider")
struct LLMChatPlannersTests {
    private let snapshot = StateSnapshot(bindings: [:])

    @Test("LLMChatProvider forwards to its closure")
    func provider() async throws {
        let p = LLMChatProvider { _ in LLMResponse(text: "hi", model: "m") }
        let r = try await p.complete(LLMRequest(messages: []))
        #expect(r.text == "hi")
    }

    @Test("discretion maps true/yes replies to true and others to false")
    func discretion() async throws {
        for (reply, expected) in [("true", true), ("YES", true), ("true (because)", true),
                                  ("no", false), ("maybe", false)] {
            let d = LLMChatDiscretion(provider: LLMChatProvider { _ in LLMResponse(text: reply, model: "m") })
            let result = try await d.decide(DiscretionContext(question: "ship?", snapshot: snapshot))
            #expect(result == expected, "reply=\(reply)")
        }
    }

    @Test("discretion sends a true/false system prompt and the question")
    func discretionPrompt() async throws {
        let provider = RecordingProvider(reply: "true")
        let d = LLMChatDiscretion(provider: provider)
        _ = try await d.decide(DiscretionContext(question: "should we?", snapshot: snapshot))
        let req = await provider.recorded()
        #expect(req?.messages.last?.content == "should we?")
        #expect(req?.responseFormat == .text)
    }

    @Test("planner queries the provider and returns a proposal")
    func planner() async throws {
        let provider = RecordingProvider(reply: "{}")
        let pl = LLMChatPlanner(provider: provider)
        let proposal = try await pl.plan(PlanContext(prose: "do work", snapshot: snapshot, tools: []))
        #expect(proposal.actions.isEmpty)
        #expect(await provider.recorded()?.responseFormat == .jsonObject)
    }

    @Test("act planner queries the provider and returns done")
    func actPlanner() async throws {
        let provider = RecordingProvider(reply: "{}")
        let ap = LLMChatActPlanner(provider: provider)
        let proposal = try await ap.act(ActContext(prose: "act", snapshot: snapshot, tools: [], remainingSteps: 5))
        if case .done = proposal { } else { Issue.record("expected .done") }
        #expect(await provider.recorded() != nil)
    }
}
