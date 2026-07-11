import Foundation

/// Worked before/after rewrites for `meridian explain-diag`. Kept separate from
/// `DiagnosticCode` so the code type stays a simple `Hashable` value.
public enum ExplainDiagExamples {
    public struct Example: Sendable, Hashable {
        public let before: String
        public let after: String
        public init(before: String, after: String) {
            self.before = before
            self.after = after
        }
    }

    public static func examples(for code: DiagnosticCode) -> [Example] {
        switch code.id {
        case "MER1012":
            return [
                .init(before: #"branch on status: / "ready" / complete."#,
                      after: #"branch on status: / "ready": / complete."#),
                .init(before: "anythng / complete.",
                      after: "anything: / complete."),
            ]
        case "MER3016":
            return [
                .init(
                    before: "A patient whose active prescriptions include a contraindicated drug must not receive the new order.",
                    after: "if any of the patient's active prescriptions is contraindicated: stop with \"cannot administer: contraindicated prescription\"."
                )
            ]
        case "MER3017":
            return [
                .init(
                    before: "When an order has been on hold for more than 7 days, escalate the order.",
                    after: "When an order is flagged as stale, escalate the order."
                )
            ]
        case "MER3018":
            return [
                .init(before: #"duplicate "ready": arms"#,
                      after: #"one "ready": arm plus anything: default"#),
                .init(before: "anything: and otherwise: together",
                      after: "keep a single wildcard/default arm"),
            ]
        case "MER4002":
            return [
                .init(before: "hand-built IR `.logical(.and, [])`",
                      after: "author `if A and B:` (operands required)"),
                .init(before: "expression-position inline invoke",
                      after: "bind the invoke in a statement, then use the bound name"),
            ]
        case "MER5011":
            return [
                .init(before: "meridian compile x.meri --trace all --trace-file /root/nope.log",
                      after: "meridian compile x.meri --trace all --trace-file /tmp/meridian-trace.log")
            ]
        case "MER6001":
            return [
                .init(before: "please charge the order.",
                      after: "charge the order.")
            ]
        case "MER6002":
            return [
                .init(before: "maybe escalate the order.",
                      after: "with discretion: escalate the order.")
            ]
        case "MER6003":
            return [
                .init(before: "migrate-skill --route-fuzzy (section demoted to reference)",
                      after: "reword the section into lowerable steps, then migrate without --route-fuzzy")
            ]
        case "MER6004":
            return [
                .init(before: "fix only the first unresolved phrase and recompile",
                      after: "fix every listed primary diagnostic; the MER6004 note names skipped constructs")
            ]
        default:
            return []
        }
    }
}
