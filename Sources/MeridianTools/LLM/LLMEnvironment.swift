import Foundation
import MeridianRuntime

public enum LLMEnvironment {
    public static let apiURLKey = "MERIDIAN_LLM_API_URL"
    public static let apiKeyKey = "MERIDIAN_LLM_API_KEY"
    public static let modelKey = "MERIDIAN_LLM_MODEL"

    public struct Configuration: Sendable, Equatable {
        public let apiURL: URL
        public let apiKey: String?
        public let model: String

        public init(apiURL: URL, apiKey: String?, model: String) {
            self.apiURL = apiURL
            self.apiKey = apiKey
            self.model = model
        }
    }

    public static func configuration(from environment: [String: String] = ProcessInfo.processInfo.environment) -> Configuration? {
        guard let urlText = environment[apiURLKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlText.isEmpty,
              let url = URL(string: urlText),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else { return nil }

        let model = environment[modelKey]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? "gpt-4o-mini"
        let apiKey = environment[apiKeyKey]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        return Configuration(apiURL: url, apiKey: apiKey, model: model)
    }
}

public enum LLMProviderError: Error, Sendable, Equatable {
    case notConfigured
    case transport(String)
    case decode(String)
}

public enum LLMProviderRegistry {
    /// Task-scoped provider override. Task-local rather than a process global so
    /// parallel tests (and any concurrent host work) cannot observe each
    /// other's override; child tasks inherit it.
    @TaskLocal public static var override: (any LLMProvider)?

    public static func withOverride<T>(
        _ provider: (any LLMProvider)?,
        _ body: () async throws -> T
    ) async rethrows -> T {
        try await $override.withValue(provider, operation: body)
    }

    public static func resolve(requireConfigured: Bool) throws -> any LLMProvider {
        if let override { return override }
        if let config = LLMEnvironment.configuration() {
            return HTTPLLMProvider(config: config)
        }
        if requireConfigured {
            throw LLMProviderError.notConfigured
        }
        return DeterministicLLMProvider()
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

public func llmToolError(_ error: LLMProviderError) -> ToolError {
    switch error {
    case .notConfigured:
        return .implementation(
            code: "llm.not_configured",
            message: "LLM provider is not configured — set \(LLMEnvironment.apiURLKey) (and optionally \(LLMEnvironment.apiKeyKey), \(LLMEnvironment.modelKey))",
            cause: nil
        )
    case .transport(let message):
        return .implementation(code: "llm.transport", message: message, cause: nil)
    case .decode(let message):
        return .implementation(code: "llm.decode", message: message, cause: nil)
    }
}
