import Foundation

public struct InvokeInverter: Sendable {
    public let symbols: SymbolTable

    public init(symbols: SymbolTable) {
        self.symbols = symbols
    }

    public func phrase(for workflow: IRWorkflow) -> PhrasePattern? {
        symbols.phrases.first { phrase in
            phrase.workflowStructName == workflow.structName
                || phrase.workflowStructName == workflow.explicitStructName
        }?.pattern
    }

    public func surface(
        for invoke: InvokeIR,
        renderExpression: (IRExpression) -> String
    ) -> String {
        if invoke.toolID.hasPrefix("workflow:") {
            let structName = String(invoke.toolID.dropFirst("workflow:".count))
            if let pattern = symbols.phrases.first(where: { $0.workflowStructName == structName })?.pattern {
                guard hasRequiredArguments(pattern: pattern, arguments: invoke.arguments) else {
                    return renderToolInvoke(invoke, renderExpression: renderExpression)
                }
                return render(pattern: pattern, arguments: invoke.arguments, renderExpression: renderExpression)
            }
        }
        if invoke.toolID == "runtime.discretion.decide",
           let question = invoke.arguments.first(where: { $0.key == "question" })?.value {
            if case .literal(.string(let text)) = question {
                return "decide whether \(text)"
            }
            return "decide whether \(renderExpression(question))"
        }
        return renderToolInvoke(invoke, renderExpression: renderExpression)
    }

    private func render(pattern: PhrasePattern, arguments: [InvokeArg], renderExpression: (IRExpression) -> String) -> String {
        let byKey = Dictionary(uniqueKeysWithValues: arguments.map { ($0.key, $0.value) })
        let orderedValues = pattern.segments.compactMap { segment -> IRExpression? in
            guard case .parameter(let parameter) = segment else { return nil }
            return byKey[parameter.name]
        }
        var parameterIndex = 0
        var parts: [String] = []
        for segment in pattern.segments {
            switch segment {
            case .literal(let text):
                parts.append(text)
            case .parameter:
                let value = orderedValues[parameterIndex]
                parameterIndex += 1
                parts.append(renderExpression(value))
            }
        }
        return parts.joined(separator: " ")
    }

    private func hasRequiredArguments(pattern: PhrasePattern, arguments: [InvokeArg]) -> Bool {
        let keys = Set(arguments.map(\.key))
        return pattern.segments.allSatisfy { segment in
            guard case .parameter(let parameter) = segment else { return true }
            return keys.contains(parameter.name)
        }
    }

    private func renderToolInvoke(_ invoke: InvokeIR, renderExpression: (IRExpression) -> String) -> String {
        let name = symbols.tools[invoke.toolID]?.methodName ?? invoke.toolID
        guard !invoke.arguments.isEmpty else {
            return "invoke \(name)"
        }
        let args = invoke.arguments
            .map { "\($0.key) = \(renderExpression($0.value))" }
            .joined(separator: ", ")
        return "invoke \(name) with \(args)"
    }
}
