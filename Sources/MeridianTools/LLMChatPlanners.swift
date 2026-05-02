import Foundation
import MeridianRuntime

public struct LLMChatProvider: LLMProvider {
    private let completeHandler: @Sendable (LLMRequest) async throws -> LLMResponse

    public init(complete: @escaping @Sendable (LLMRequest) async throws -> LLMResponse) {
        self.completeHandler = complete
    }

    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        try await completeHandler(request)
    }
}

public struct LLMChatDiscretion: LLMBackedDiscretion {
    private let provider: any LLMProvider

    public init(provider: any LLMProvider) {
        self.provider = provider
    }

    public func decide(_ context: DiscretionContext) async throws -> Bool {
        let response = try await provider.complete(LLMRequest(
            messages: [
                LLMMessage(role: .system, content: "Answer only true or false."),
                LLMMessage(role: .user, content: context.question)
            ],
            temperature: 0,
            maxTokens: 8,
            responseFormat: .text
        ))
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return text == "true" || text == "yes" || text.hasPrefix("true ")
    }
}

public struct LLMChatPlanner: LLMBackedPlanner {
    private let provider: any LLMProvider

    public init(provider: any LLMProvider) {
        self.provider = provider
    }

    public func plan(_ context: PlanContext) async throws -> PlanProposal {
        _ = try await provider.complete(LLMRequest(
            messages: [
                LLMMessage(role: .system, content: "Return a Meridian PlanProposal JSON object."),
                LLMMessage(role: .user, content: context.prose)
            ],
            temperature: 0,
            responseFormat: .jsonObject
        ))
        return PlanProposal(actions: [])
    }
}

public struct LLMChatActPlanner: LLMBackedActPlanner {
    private let provider: any LLMProvider

    public init(provider: any LLMProvider) {
        self.provider = provider
    }

    public func act(_ context: ActContext) async throws -> ActProposal {
        _ = try await provider.complete(LLMRequest(
            messages: [
                LLMMessage(role: .system, content: "Return one Meridian ActProposal JSON object."),
                LLMMessage(role: .user, content: context.prose)
            ],
            temperature: 0,
            responseFormat: .jsonObject
        ))
        return .done(reason: "provider response parsing is not configured")
    }
}
