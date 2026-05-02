import Foundation

public protocol LLMProvider: Sendable {
    func complete(_ request: LLMRequest) async throws -> LLMResponse
}

public struct LLMRequest: Sendable {
    public let messages: [LLMMessage]
    public let temperature: Double
    public let maxTokens: Int?
    public let responseFormat: LLMResponseFormat
    public let stop: [String]?

    public init(
        messages: [LLMMessage],
        temperature: Double = 0,
        maxTokens: Int? = nil,
        responseFormat: LLMResponseFormat = .text,
        stop: [String]? = nil
    ) {
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.responseFormat = responseFormat
        self.stop = stop
    }
}

public enum LLMResponseFormat: Sendable, Equatable {
    case text
    case jsonObject
    case jsonSchema(String)
}

public struct LLMMessage: Sendable, Equatable {
    public let role: LLMRole
    public let content: String

    public init(role: LLMRole, content: String) {
        self.role = role
        self.content = content
    }
}

public enum LLMRole: String, Sendable, Hashable {
    case system
    case user
    case assistant
}

public struct LLMResponse: Sendable, Equatable {
    public let text: String
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let stopReason: String?

    public init(
        text: String,
        model: String,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        stopReason: String? = nil
    ) {
        self.text = text
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.stopReason = stopReason
    }
}
