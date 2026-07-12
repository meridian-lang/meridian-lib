import Foundation

struct IndeterminateAnalysis {
    let symbols: SymbolTable

    func possiblyIndeterminate(_ expression: IRExpression) -> Bool {
        possiblyIndeterminate(expression, visitedDefinitions: [])
    }

    private func possiblyIndeterminate(_ expression: IRExpression, visitedDefinitions: Set<String>) -> Bool {
        switch expression {
        case .traceTemporal(let temporal):
            if case .sinceLast = temporal.kind {
                return true
            }
            return false
        case .traceStatistical:
            return true
        case .logical(_, let expressions):
            return expressions.contains { possiblyIndeterminate($0, visitedDefinitions: visitedDefinitions) }
        case .comparison(let lhs, _, let rhs):
            return possiblyIndeterminate(lhs, visitedDefinitions: visitedDefinitions)
                || possiblyIndeterminate(rhs, visitedDefinitions: visitedDefinitions)
        case .propertyAccess(let base, _):
            return possiblyIndeterminate(base, visitedDefinitions: visitedDefinitions)
        case .invocation(let invoke):
            return invoke.arguments.contains { possiblyIndeterminate($0.value, visitedDefinitions: visitedDefinitions) }
        case .eventPattern(let pattern):
            return pattern.payloadPredicate.map { possiblyIndeterminate($0, visitedDefinitions: visitedDefinitions) } ?? false
        case .definitionPredicate(let functionName, _):
            guard !visitedDefinitions.contains(functionName),
                  let record = symbols.definitions.values.first(where: { $0.functionName == functionName }) else {
                return false
            }
            return possiblyIndeterminate(record.body, visitedDefinitions: visitedDefinitions.union([functionName]))
        default:
            return false
        }
    }

    private func possiblyIndeterminate(_ expression: ExpressionAST, visitedDefinitions: Set<String>) -> Bool {
        switch expression {
        case .traceTemporal(let temporal):
            if case .sinceLast = temporal.kind {
                return true
            }
            return false
        case .traceStatistical:
            return true
        case .logical(_, let expressions):
            return expressions.contains { possiblyIndeterminate($0, visitedDefinitions: visitedDefinitions) }
        case .comparison(let lhs, _, let rhs):
            return possiblyIndeterminate(lhs, visitedDefinitions: visitedDefinitions)
                || possiblyIndeterminate(rhs, visitedDefinitions: visitedDefinitions)
        case .propertyAccess(let base, _):
            return possiblyIndeterminate(base, visitedDefinitions: visitedDefinitions)
        case .invoke(_, let args):
            return args.contains { possiblyIndeterminate($0.1, visitedDefinitions: visitedDefinitions) }
        case .eventPattern(let pattern):
            return pattern.payloadPredicate.map { possiblyIndeterminate($0, visitedDefinitions: visitedDefinitions) } ?? false
        case .identifierRef(let name):
            guard !visitedDefinitions.contains(name.lowercased()),
                  let record = symbols.definition(forAdjective: name) else {
                return false
            }
            return possiblyIndeterminate(record.body, visitedDefinitions: visitedDefinitions.union([record.adjective]))
        default:
            return false
        }
    }
}
