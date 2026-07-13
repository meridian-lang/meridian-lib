import Foundation
import MeridianRuntime
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// OpenAI-compatible chat-completions HTTP adapter. Requires `MERIDIAN_LLM_API_URL`.
public struct HTTPLLMProvider: LLMProvider {
    public let config: LLMEnvironment.Configuration
    private let session: URLSession
    private let maxRetries: Int

    public init(config: LLMEnvironment.Configuration, session: URLSession = .shared, maxRetries: Int = 1) {
        self.config = config
        self.session = session
        self.maxRetries = max(0, maxRetries)
    }

    public static func fromEnvironment() throws -> HTTPLLMProvider {
        guard let config = LLMEnvironment.configuration() else {
            throw LLMProviderError.notConfigured
        }
        return HTTPLLMProvider(config: config)
    }

    public func complete(_ request: LLMRequest) async throws -> LLMResponse {
        var urlRequest = URLRequest(url: config.apiURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = config.apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "model": config.model,
            "messages": request.messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "temperature": request.temperature,
        ]
        if let maxTokens = request.maxTokens { body["max_tokens"] = maxTokens }
        switch request.responseFormat {
        case .text:
            break
        case .jsonObject:
            body["response_format"] = ["type": "json_object"]
        case .jsonSchema(let schema):
            body["response_format"] = ["type": "json_schema", "json_schema": ["schema": schema]]
        }
        if let stop = request.stop { body["stop"] = stop }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        var lastError: Error?
        let attempts = maxRetries + 1
        for attempt in 0..<attempts {
            do {
                let (data, response) = try await session.data(for: urlRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw LLMProviderError.transport("LLM HTTP response was not HTTP")
                }
                let raw = String(data: data, encoding: .utf8) ?? ""
                if (200..<300).contains(http.statusCode) {
                    return try decodeResponse(data)
                }
                let retriable = http.statusCode == 429 || (500..<600).contains(http.statusCode)
                let error = LLMProviderError.transport("LLM HTTP \(http.statusCode): \(raw.prefix(512))")
                if retriable && attempt + 1 < attempts {
                    lastError = error
                    continue
                }
                throw error
            } catch let error as LLMProviderError {
                lastError = error
                if attempt + 1 < attempts, case .transport = error {
                    continue
                }
                throw error
            } catch {
                throw error
            }
        }
        throw lastError ?? LLMProviderError.transport("LLM request failed")
    }

    private func decodeResponse(_ data: Data) throws -> LLMResponse {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMProviderError.decode("LLM response was not a JSON object")
        }
        if let error = root["error"] as? [String: Any] {
            let message = (error["message"] as? String) ?? String(describing: error)
            throw LLMProviderError.transport(message)
        }
        guard let choices = root["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            throw LLMProviderError.decode("LLM response missing choices[0].message.content")
        }
        let model = (root["model"] as? String) ?? config.model
        let usage = root["usage"] as? [String: Any]
        let inputTokens = usage?["prompt_tokens"] as? Int ?? 0
        let outputTokens = usage?["completion_tokens"] as? Int ?? 0
        let stopReason = first["finish_reason"] as? String
        return LLMResponse(
            text: content,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            stopReason: stopReason
        )
    }
}
