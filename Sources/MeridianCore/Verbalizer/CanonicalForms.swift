import Foundation
import MeridianRuntime

public enum CanonicalForms {
    public static let indent = "  "

    public static func indented(_ lines: [String], depth: Int = 1) -> [String] {
        let prefix = String(repeating: indent, count: depth)
        return lines.map { $0.isEmpty ? $0 : prefix + $0 }
    }

    public static func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "." }
        if trimmed.hasSuffix(".") || trimmed.hasSuffix(":") || trimmed.hasSuffix(",") {
            return trimmed
        }
        return trimmed + "."
    }

    public static func quoted(_ value: String) -> String {
        // Unescape first so values that still carry parser-preserved
        // `\"` / `\\` sequences (LiteralGrammar does not decode escapes)
        // re-quote to a byte-stable fixpoint instead of accumulating
        // backslashes on each verbalize pass.
        "\"\(escaped(unescaped(value)))\""
    }

    public static func backticked(_ value: String) -> String {
        "`\(value.replacingOccurrences(of: "`", with: "\\`"))`"
    }

    public static func unescaped(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        var index = value.startIndex
        while index < value.endIndex {
            let ch = value[index]
            let next = value.index(after: index)
            if ch == "\\", next < value.endIndex {
                switch value[next] {
                case "\\":
                    result.append("\\")
                case "\"":
                    result.append("\"")
                case "n":
                    result.append("\n")
                case "r":
                    result.append("\r")
                case "t":
                    result.append("\t")
                default:
                    result.append(ch)
                    result.append(value[next])
                }
                index = value.index(after: next)
                continue
            }
            result.append(ch)
            index = next
        }
        return result
    }

    public static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    public static func words(fromIdentifier identifier: String) -> String {
        var scalars: [String] = []
        for scalar in identifier.unicodeScalars {
            let text = String(scalar)
            if CharacterSet.uppercaseLetters.contains(scalar), !scalars.isEmpty {
                scalars.append(" ")
                scalars.append(text.lowercased())
            } else if scalar == "_" || scalar == "-" {
                scalars.append(" ")
            } else {
                scalars.append(text)
            }
        }
        return scalars.joined().split(separator: " ").joined(separator: " ")
    }

    public static func comparison(_ op: ComparisonOp) -> String {
        switch op {
        case .equal:
            return "equals"
        case .notEqual:
            return "is not"
        case .lessThan:
            return "is less than"
        case .lessOrEqual:
            return "is at most"
        case .greaterThan:
            return "is more than"
        case .greaterOrEqual:
            return "is at least"
        case .oneOf:
            return "is one of"
        case .contains:
            return "contains"
        case .startsWith:
            return "starts with"
        case .endsWith:
            return "ends with"
        case .withinDuration:
            return "is within"
        case .withinPast:
            return "is within the last"
        case .withinFuture:
            return "is in the next"
        case .matchesPattern:
            return "matches pattern"
        case .isEmpty:
            return "is empty"
        case .isNotEmpty:
            return "is not empty"
        case .identifies:
            return "identifies"
        }
    }

    public static func quantifier(_ kind: QuantifierKind, noun: String) -> String {
        switch kind {
        case .all:
            return "all \(noun)"
        case .any:
            return "any \(noun)"
        case .none:
            return "no \(noun)"
        case .atLeast(let count):
            return "at least \(count) \(noun)"
        case .atMost(let count):
            return "at most \(count) \(noun)"
        case .exactly(let count):
            return "exactly \(count) \(noun)"
        }
    }

    public static func duration(_ duration: Duration) -> String {
        let seconds = duration.components.seconds
        if seconds == 1 { return "1 second" }
        return "\(seconds) seconds"
    }

    public static func literal(_ literal: IRLiteral) -> String {
        switch literal {
        case .string(let value):
            return quoted(value)
        case .number(let value):
            return "\(value)"
        case .boolean(let value):
            return value ? "true" : "false"
        case .money(let amount, let currency):
            return "$\(amount) \(currency)"
        case .duration(let value):
            return duration(value)
        case .date(let value):
            return date(value)
        case .dateTime(let value):
            return dateTime(value)
        case .enumValue(let value, kind: _):
            return value
        }
    }

    public static func date(_ value: Date) -> String {
        "@\(Int(value.timeIntervalSince1970))"
    }

    public static func dateTime(_ value: Date) -> String {
        "@\(Int(value.timeIntervalSince1970))"
    }
}
