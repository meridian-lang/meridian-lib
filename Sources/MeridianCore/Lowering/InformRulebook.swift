import Foundation

public enum RulebookPhase: Int, Sendable, CaseIterable {
    case before = 0
    case instead = 1
    case check = 2
    case carryOut = 3
    case after = 4
    case report = 5
}

public enum RulebookOutcome: Sendable, Equatable {
    case continueRulebook
    case stopRulebook
    case success
    case failure
}

public struct RulebookRule: Sendable, Equatable {
    public let phase: RulebookPhase
    public let action: String
    public let body: String
    public let outcome: RulebookOutcome
    public let sourceLine: Int

    public init(phase: RulebookPhase, action: String, body: String, outcome: RulebookOutcome, sourceLine: Int) {
        self.phase = phase
        self.action = action
        self.body = body
        self.outcome = outcome
        self.sourceLine = sourceLine
    }
}

public struct InformRulebookParser {
    public init() {}

    public func parse(_ rules: [RuleAST]) -> [RulebookRule] {
        rules.compactMap(parse).sorted { lhs, rhs in
            if lhs.phase.rawValue == rhs.phase.rawValue {
                return lhs.sourceLine < rhs.sourceLine
            }
            return lhs.phase.rawValue < rhs.phase.rawValue
        }
    }

    public func parse(_ rule: RuleAST) -> RulebookRule? {
        let text = rule.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        let phasePrefixes: [(String, RulebookPhase)] = [
            ("before ", .before),
            ("instead of ", .instead),
            ("check ", .check),
            ("carry out ", .carryOut),
            ("after ", .after),
            ("report ", .report)
        ]
        guard let (prefix, phase) = phasePrefixes.first(where: { lower.hasPrefix($0.0) }) else {
            return nil
        }
        let rest = String(text.dropFirst(prefix.count))
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let action = String(rest[..<colon]).trimmingCharacters(in: .whitespaces)
        let body = String(rest[rest.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !action.isEmpty, !body.isEmpty else { return nil }
        return RulebookRule(
            phase: phase,
            action: action,
            body: body,
            outcome: outcome(from: body),
            sourceLine: rule.sourceLine
        )
    }

    private func outcome(from body: String) -> RulebookOutcome {
        let lower = body.lowercased()
        if lower.contains("stop") { return .stopRulebook }
        if lower.contains("success") { return .success }
        if lower.contains("fail") { return .failure }
        return .continueRulebook
    }
}
