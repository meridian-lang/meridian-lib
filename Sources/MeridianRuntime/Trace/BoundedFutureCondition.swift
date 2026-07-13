import Foundation

public enum BoundedFutureCondition: Sendable {
    case state(fields: [String: Value])
    case event(TraceEventPatternQuery)

    public static func decode(_ json: String?) -> BoundedFutureCondition? {
        guard let json, let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let kind = object["kind"] as? String else {
            return nil
        }
        switch kind {
        case "state":
            guard let fields = object["fields"] as? [String: Any] else { return nil }
            var decoded: [String: Value] = [:]
            for (key, value) in fields {
                switch value {
                case let string as String:
                    decoded[key] = .string(string)
                case let number as Double:
                    decoded[key] = .number(Decimal(number))
                case let number as Int:
                    decoded[key] = .number(Decimal(number))
                case let boolean as Bool:
                    decoded[key] = .boolean(boolean)
                default:
                    return nil
                }
            }
            return .state(fields: decoded)
        case "event":
            guard let subject = object["subject"] as? [String: Any],
                  let subjectType = subject["type"] as? String,
                  let name = subject["name"] as? String,
                  let outcome = object["outcome"] as? String else {
                return nil
            }
            let parsedSubject: TraceEventPatternQuery.Subject
            switch subjectType {
            case "step": parsedSubject = .step(name)
            case "named": parsedSubject = .named(name)
            default: return nil
            }
            let parsedOutcome: TraceEventPatternQuery.Outcome
            switch outcome {
            case "succeeded": parsedOutcome = .succeeded
            case "failed": parsedOutcome = .failed
            case "invoked": parsedOutcome = .invoked
            case "emitted": parsedOutcome = .emitted
            case "prevented": parsedOutcome = .prevented
            case "violated": parsedOutcome = .violated
            case "occurred": parsedOutcome = .occurred
            default: return nil
            }
            return .event(TraceEventPatternQuery(
                subject: parsedSubject,
                outcome: parsedOutcome,
                subjectKey: nil,
                payloadContains: nil,
                negated: false
            ))
        default:
            return nil
        }
    }
}
