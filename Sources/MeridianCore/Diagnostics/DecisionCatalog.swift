import Foundation

/// A structured design decision behind the diagnostics/developer-experience
/// surface. Decisions are reachable *at the point of error*: a `DiagnosticCode`
/// may carry a `DecisionRef`, and both `meridian explain` and the rendered
/// diagnostic surface the linked rationale. `docs/15_DECISIONS.md` is generated
/// from this catalog (`meridian decisions --render`) so the human-readable log
/// can never drift from the source of truth.
public struct DecisionRecord: Sendable, Hashable {
    public enum Status: String, Sendable, Hashable {
        case accepted
        case superseded
        case proposed
    }

    public let id: String
    public let title: String
    public let status: Status
    public let rationale: String
    public let alternatives: [String]
    public let consequences: [String]
    public let seeAlso: [String]

    public init(id: String, title: String, status: Status = .accepted,
                rationale: String, alternatives: [String] = [],
                consequences: [String] = [], seeAlso: [String] = []) {
        self.id = id
        self.title = title
        self.status = status
        self.rationale = rationale
        self.alternatives = alternatives
        self.consequences = consequences
        self.seeAlso = seeAlso
    }
}

/// The dependency-free source of truth for design decisions surfaced in
/// diagnostics. See `DecisionRecord`.
public enum DecisionCatalog {

    public static let all: [DecisionRecord] = [

        DecisionRecord(
            id: "D-DX-1",
            title: "Unresolved phrases are hard errors by default",
            rationale: "An invocation that matches no phrase or workflow is almost always a typo or a missing declaration. Emitting a silent `_unresolved` placeholder hid real bugs until runtime. Strict-by-default surfaces them at compile time; the `allow-fallbacks: unresolved-phrases` escape hatch keeps early-authoring ergonomic.",
            alternatives: [
                "Always emit an `_unresolved` placeholder (the old behaviour) — hides typos until runtime.",
                "Warn instead of error — warnings are routinely ignored in CI.",
            ],
            consequences: [
                "Every phrase must resolve, or the file must opt into the fallback.",
                "The error funnels through `Diagnostic.unresolved`, so it always carries a did-you-mean or candidate list.",
            ],
            seeAlso: ["MER2001", "D-DX-2"]),

        DecisionRecord(
            id: "D-DX-2",
            title: "No silent compile-time fallbacks; batch-report with coarse recovery",
            rationale: "Silent drops (malformed headers, unparseable rules/statements, unknown config keys/sections) erased authoring mistakes. Every former silent site is now a coded diagnostic. The DiagnosticEngine collects rather than aborts, recovering at construct boundaries (workflow / rule / statement) so one compile reports many errors instead of one-at-a-time.",
            alternatives: [
                "Abort on the first error — slow edit/compile loops; hides co-occurring errors.",
                "Token-level resync recovery — produces cascade/phantom errors.",
            ],
            consequences: [
                "Constructs are skipped wholesale on error (cascade-resistant); phrase stubs are pre-registered so dependents still resolve.",
                "Structural codes carry a mandatory `help` string with the concrete fix.",
            ],
            seeAlso: ["MER1001", "MER1002", "MER1003", "MER1004", "MER3006", "MER3007"]),

        DecisionRecord(
            id: "D-DX-3",
            title: "swift-format failure is a recoverable warning, not an error",
            rationale: "Formatting is cosmetic. If swift-format chokes on otherwise-valid generated Swift, keeping the unformatted output is strictly better than failing the compile. The condition is surfaced as a warning so it is visible but non-fatal.",
            alternatives: [
                "Fail the compile when formatting fails — loses valid output over a cosmetic step.",
                "Swallow the failure silently — hides a real formatter/codegen interaction bug.",
            ],
            consequences: [
                "`compile` always writes Swift; a formatting failure is reported as a warning.",
            ],
            seeAlso: ["MER5001"]),

        DecisionRecord(
            id: "D-DX-4",
            title: "Always-on did-you-mean for every name-resolution error",
            rationale: "A name-resolution failure is, by definition, a mismatch against a finite candidate set, so a remediation can always be named. Every such failure funnels through `Diagnostic.unresolved(code:target:among:range:)`, which attaches a `did you mean \"X\"?` suggestion when within edit-distance budget, or an enumerated candidate-list note otherwise — never a bare \"unknown X\".",
            alternatives: [
                "Per-site ad-hoc messages — drift and inconsistency; easy to forget the hint.",
                "Only suggest when very close — leaves the user stuck when nothing is close.",
            ],
            consequences: [
                "A guard test enumerates all `.nameResolution` codes and asserts each yields a suggestion or candidate-list note.",
                "Suggestions carry `replacement` + `range`, powering `--fix` and editor quick-fixes.",
            ],
            seeAlso: ["MER2003", "MER2004", "MER2007", "MER2008"]),

        DecisionRecord(
            id: "D-DX-5",
            title: "Unknown tools are errors; Core mirrors the runtime built-in catalog",
            rationale: "A misspelled or undeclared tool id silently compiled to an invoke that failed only at runtime. Core cannot import MeridianTools, so `BuiltinToolCatalog` hand-mirrors the runtime's built-in ids (kept in lockstep by a guard test). Every `InvokeIR.toolID` is validated against built-ins ∪ vocabulary `=== tools ===` ∪ frontmatter `tools:` ∪ workflow references, with did-you-mean.",
            alternatives: [
                "Trust every emitted tool id — runtime-only failures, far from the source.",
                "Validate only vocabulary tools — false positives on built-ins and frontmatter tools.",
            ],
            consequences: [
                "Recognition mirrors the invoke path (case-insensitive against methodName; methodized built-ins).",
                "`allow-fallbacks: unknown-tools` downgrades per-file for host-provided tools.",
            ],
            seeAlso: ["MER2002"]),
    ]

    public static func lookup(_ id: String) -> DecisionRecord? {
        let needle = id.uppercased()
        return all.first { $0.id.uppercased() == needle }
    }

    /// Render the catalog as the canonical `docs/15_DECISIONS.md`. The
    /// `decisions --render` CLI mode writes this; a staleness test re-renders
    /// and diffs against the committed file so the doc never drifts.
    public static func renderMarkdown() -> String {
        var out = """
        # Meridian design decisions (diagnostics & developer experience)

        > Generated from `DecisionCatalog` by `meridian decisions --render docs/15_DECISIONS.md`.
        > Do not edit by hand — update `Sources/MeridianCore/Diagnostics/DecisionCatalog.swift`
        > and re-render. A test fails if this file drifts from the catalog.

        Each decision is reachable from the errors it governs: run
        `meridian explain <code>` (e.g. `meridian explain MER2002`) or
        `meridian explain <decision-id>` (e.g. `meridian explain D-DX-5`).

        """
        for d in all {
            out += "\n## \(d.id) — \(d.title)\n\n"
            out += "**Status:** \(d.status.rawValue)\n\n"
            out += "\(d.rationale)\n"
            if !d.alternatives.isEmpty {
                out += "\n**Alternatives considered:**\n\n"
                for a in d.alternatives { out += "- \(a)\n" }
            }
            if !d.consequences.isEmpty {
                out += "\n**Consequences:**\n\n"
                for c in d.consequences { out += "- \(c)\n" }
            }
            if !d.seeAlso.isEmpty {
                out += "\n**See also:** \(d.seeAlso.joined(separator: ", "))\n"
            }
        }
        return out
    }
}
