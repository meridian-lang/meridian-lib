import Foundation
import MeridianRuntime

enum LLMJSONParsers {
    static func parseBooleanDecision(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "true" || normalized == "yes" || normalized.hasPrefix("true ") {
            return true
        }
        if let data = normalized.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let verdict = object["verdict"] as? Bool { return verdict }
            if let answer = object["answer"] as? Bool { return answer }
            if let value = object["value"] as? Bool { return value }
        }
        return false
    }

    static func parsePlanProposal(from text: String) throws -> PlanProposal {
        let root = try parseJSONObject(text)
        let actionsValue = root["actions"] as? [[String: Any]] ?? []
        let actions = try actionsValue.map { try parseProposedAction($0) }
        let rationale = root["rationale"] as? String
        return PlanProposal(actions: actions, rationale: rationale)
    }

    static func parseActProposal(from text: String) throws -> ActProposal {
        let root = try parseJSONObject(text)
        let kind = (root["kind"] as? String)?.lowercased()
        if kind == "done" {
            return .done(reason: root["reason"] as? String)
        }
        if kind == "action" || root["tool_id"] != nil || root["toolID"] != nil {
            return .action(try parseProposedAction(root))
        }
        return .done(reason: root["reason"] as? String)
    }

    private static func parseProposedAction(_ object: [String: Any]) throws -> ProposedAction {
        guard let toolID = (object["tool_id"] as? String) ?? (object["toolID"] as? String),
              !toolID.isEmpty else {
            throw LLMProviderError.decode("LLM planner JSON missing tool_id")
        }
        let arguments = parseArguments(object["arguments"])
        let resultBinding = (object["result_binding"] as? String) ?? (object["resultBinding"] as? String)
        return ProposedAction(toolID: toolID, arguments: arguments, resultBinding: resultBinding)
    }

    private static func parseArguments(_ value: Any?) -> [String: Value] {
        guard let record = value as? [String: Any] else { return [:] }
        return record.mapValues { jsonValue($0) }
    }

    private static func jsonValue(_ value: Any) -> Value {
        switch value {
        case let string as String:
            return .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .boolean(number.boolValue)
            }
            return .number(number.decimalValue)
        case let bool as Bool:
            return .boolean(bool)
        case let dict as [String: Any]:
            return .record(dict.mapValues { jsonValue($0) })
        case let array as [Any]:
            return .list(array.map { jsonValue($0) })
        default:
            return .string(String(describing: value))
        }
    }

    private static func parseJSONObject(_ text: String) throws -> [String: Any] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else {
            throw LLMProviderError.decode("LLM JSON response was not UTF-8")
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMProviderError.decode("LLM JSON response was not an object")
        }
        return object
    }
}
