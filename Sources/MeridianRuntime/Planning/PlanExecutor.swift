import Foundation

internal struct PlanExecutor: Sendable {
    private let toolRegistry: ToolRegistry

    internal init(toolRegistry: ToolRegistry) {
        self.toolRegistry = toolRegistry
    }

    internal func validate(
        _ action: ProposedAction,
        scopedTools: Set<String>,
        sourceRange: SourceRange? = nil
    ) async throws {
        guard scopedTools.contains(action.toolID) else {
            throw MeridianRuntimeError.planningFailure(
                .toolOutOfScope,
                message: "planner proposed out-of-scope tool `\(action.toolID)`",
                sourceRange: sourceRange
            )
        }
        guard await toolRegistry.has(tool: action.toolID) else {
            throw MeridianRuntimeError.planningFailure(
                .toolNotRegistered,
                message: "planner proposed unregistered tool `\(action.toolID)`",
                sourceRange: sourceRange
            )
        }
        guard let schema = await toolRegistry.schema(for: action.toolID), !schema.arguments.isEmpty else {
            return
        }
        let specsByName = Dictionary(uniqueKeysWithValues: schema.arguments.map { ($0.name, $0) })
        for spec in schema.arguments where spec.required && action.arguments[spec.name] == nil {
            throw MeridianRuntimeError.planningFailure(
                .missingToolArgument,
                message: "planner omitted required argument `\(spec.name)` for tool `\(action.toolID)`",
                sourceRange: sourceRange
            )
        }
        for key in action.arguments.keys where specsByName[key] == nil {
            throw MeridianRuntimeError.planningFailure(
                .unexpectedToolArgument,
                message: "planner supplied unexpected argument `\(key)` for tool `\(action.toolID)`",
                sourceRange: sourceRange
            )
        }
        for (key, value) in action.arguments {
            guard let spec = specsByName[key], matches(value, type: spec.type) else {
                throw MeridianRuntimeError.planningFailure(
                    .invalidToolArgumentType,
                    message: "planner supplied invalid value for argument `\(key)` on tool `\(action.toolID)`",
                    sourceRange: sourceRange
                )
            }
        }
    }

    private func matches(_ value: Value, type rawType: String) -> Bool {
        switch rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "value", "any":
            return true
        case "string", "text":
            if case .string = value { return true }
            return false
        case "number", "decimal", "int", "integer", "double":
            if case .number = value { return true }
            return false
        case "boolean", "bool":
            if case .boolean = value { return true }
            return false
        case "money":
            if case .money = value { return true }
            return false
        case "duration":
            if case .duration = value { return true }
            return false
        case "date":
            if case .date = value { return true }
            return false
        case "datetime", "date_time":
            if case .dateTime = value { return true }
            return false
        case "record", "object":
            if case .record = value { return true }
            return false
        case "list", "array":
            if case .list = value { return true }
            return false
        case "reference", "ref":
            if case .reference = value { return true }
            return false
        default:
            return true
        }
    }
}
