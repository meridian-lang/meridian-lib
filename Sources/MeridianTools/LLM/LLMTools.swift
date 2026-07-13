import Foundation
import MeridianRuntime

enum LLMTools {
    static func chat(_ args: [String: Value], provider: any LLMProvider) async throws -> Value {
        let messages = parseMessages(args)
        let temperature = decimalArg(args, "temperature").map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0
        let maxTokens = intArg(args, "max_tokens")
        let response = try await provider.complete(LLMRequest(
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: .text
        ))
        return .record([
            "content": .string(response.text),
            "role": .string("assistant"),
            "model": .string(response.model),
            "input_tokens": .number(Decimal(response.inputTokens)),
            "output_tokens": .number(Decimal(response.outputTokens)),
        ])
    }

    static func decide(_ args: [String: Value], provider: any LLMProvider) async throws -> Value {
        let question = try requiredString(args, "question")
        let response = try await provider.complete(LLMRequest(
            messages: [
                LLMMessage(role: .system, content: "Answer only true or false."),
                LLMMessage(role: .user, content: question),
            ],
            temperature: 0,
            maxTokens: 8,
            responseFormat: .text
        ))
        let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return .boolean(LLMJSONParsers.parseBooleanDecision(text))
    }

    static func parseMessages(_ args: [String: Value]) -> [LLMMessage] {
        if let prompt = stringArg(args, "prompt"), !prompt.isEmpty {
            return [LLMMessage(role: .user, content: prompt)]
        }
        guard let list = args["messages"]?.asList else {
            return [LLMMessage(role: .user, content: "")]
        }
        return list.compactMap { value in
            guard case .record(let record) = value,
                  case .string(let roleText)? = record["role"],
                  case .string(let content)? = record["content"],
                  let role = LLMRole(rawValue: roleText)
            else { return nil }
            return LLMMessage(role: role, content: content)
        }
    }

    static func stringArg(_ args: [String: Value], _ key: String) -> String? {
        if case .string(let s)? = args[key] { return s }
        return nil
    }

    static func requiredString(_ args: [String: Value], _ key: String) throws -> String {
        guard let value = stringArg(args, key) else {
            throw ToolError.argumentCoercion(field: key, expected: "String", actual: String(describing: args[key] ?? .null))
        }
        return value
    }

    static func decimalArg(_ args: [String: Value], _ key: String) -> Decimal? {
        if case .number(let n)? = args[key] { return n }
        return nil
    }

    static func intArg(_ args: [String: Value], _ key: String) -> Int? {
        if case .number(let n)? = args[key] { return NSDecimalNumber(decimal: n).intValue }
        return nil
    }
}
