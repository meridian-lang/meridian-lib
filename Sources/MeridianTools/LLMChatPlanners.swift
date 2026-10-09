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

public struct LLMChatDiscretion: Discretion {
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
        return LLMJSONParsers.parseBooleanDecision(text)
    }
}

public struct LLMChatPlanner: Planner {
    private let provider: any LLMProvider

    public init(provider: any LLMProvider) {
        self.provider = provider
    }

    public func plan(_ context: PlanContext) async throws -> PlanProposal {
        let response = try await provider.complete(LLMRequest(
            messages: [
                LLMMessage(role: .system, content: "Return a Meridian PlanProposal JSON object with keys actions (array of {tool_id, arguments, result_binding?}) and optional rationale."),
                LLMMessage(role: .user, content: context.prose)
            ],
            temperature: 0,
            responseFormat: .jsonObject
        ))
        return try LLMJSONParsers.parsePlanProposal(from: response.text)
    }
}

public struct LLMChatActPlanner: ActPlanner {
    private let provider: any LLMProvider

    public init(provider: any LLMProvider) {
        self.provider = provider
    }

    public func act(_ context: ActContext) async throws -> ActProposal {
        let response = try await provider.complete(LLMRequest(
            messages: [
                LLMMessage(role: .system, content: "Return one Meridian ActProposal JSON object: either {\"kind\":\"done\",\"reason\":...} or {\"kind\":\"action\",\"tool_id\":...,\"arguments\":{...}}."),
                LLMMessage(role: .user, content: context.prose)
            ],
            temperature: 0,
            responseFormat: .jsonObject
        ))
        return try LLMJSONParsers.parseActProposal(from: response.text)
    }
}

public extension Runtime.Builder {
    @discardableResult
    func wireLLMJudgmentTools(from provider: any LLMProvider) -> Runtime.Builder {
        setLLMProvider(provider)
            .setDiscretion(LLMChatDiscretion(provider: provider))
            .setPlanner(LLMChatPlanner(provider: provider))
            .setActPlanner(LLMChatActPlanner(provider: provider))
    }

    @discardableResult
    func wireLLMJudgmentToolsFromEnvironment() throws -> Runtime.Builder {
        let provider = try HTTPLLMProvider.fromEnvironment()
        return wireLLMJudgmentTools(from: provider)
    }
}

public extension ToolRegistry {
    func registerLLMJudgmentTools(provider: (any LLMProvider)? = nil) async {
        let resolved: any LLMProvider
        if let provider {
            resolved = provider
        } else if let config = LLMEnvironment.configuration() {
            resolved = HTTPLLMProvider(config: config)
        } else {
            resolved = DeterministicLLMProvider()
        }
        await register(tool: "llm.chat", .closure { args in
            let provider = try LLMProviderRegistry.resolve(requireConfigured: true)
            return try await LLMTools.chat(args, provider: provider)
        })
        await register(tool: "llm.decide", .closure { args in
            try await LLMTools.decide(args, provider: resolved)
        })
        await register(tool: "llm.judge", .closure { args in
            try await LLMTools.decide(args, provider: resolved)
        })
    }
}
