import Foundation

// MARK: - Rulebook model
//
// A rulebook is an externally-authored, declarative `.merrules` file that
// extends Meridian's deterministic English surface without touching the
// compiler core. Three families of rule live here:
//
//   1. Desugar rules     — rewrite a surface English form into a canonical
//                          Meridian statement (the `RewriteEngine` applies
//                          these before the StatementParser's own fallback).
//   2. Section-role rules — map a markdown heading alias to one of the closed
//                          `SkillSectionRole` values used by skill lowering.
//   3. Conventions        — Inform-style behavioral rules (`before/after/check/
//                          instead of/carry out/report`) injected into matching
//                          workflows (see `InformRulebookParser`).
//
// Every rule is a *compile-time equivalence*: its output is re-parsed and
// lowered through the same strict path as hand-authored source, so a rulebook
// can never widen tool scope, bypass strict mode, or introduce an LLM call.

/// The closed set of roles a markdown section can play in a skill document.
/// New roles are a compile-time TODO list (exhaustive switches, no `default:`).
public enum SkillSectionRole: String, Sendable, CaseIterable, Equatable {
    /// `## Contract` / `## Guarantees` → invariants lowered to `assert`.
    case invariants
    /// `## Phases` / `## Workflow` → the executable procedure.
    case procedure
    /// `## When To Use` → deterministic applicability (dispatch + preconditions).
    case applicability
    /// `## When NOT To Use` → negative applicability (soft-skip + negative dispatch).
    case negativeApplicability = "negative-applicability"
    /// `## Anti-Patterns` → `must not` guards where structurally checkable.
    case prohibitions
    /// `## Output Format` → a declared result template.
    case template
    /// `## Tools Used` → metadata-extracting: bullets name the tools the skill
    /// is scoped to. Non-executable, but mined into `scopedTools` + manifest.
    case tools
    /// A section whose body restates an external rulebook convention verbatim
    /// (`(( inert, role: convention-ref ))`). Non-executable metadata.
    case conventionRef = "convention-ref"
    /// Anything else (Philosophy, examples, prose rationale) → inert metadata.
    case inert

    /// True for roles whose lowered body runs (asserts, preconditions,
    /// procedure). False for documentation/metadata roles (`template`/`tools`/
    /// `convention-ref`/`inert`) whose content is recorded but never executed.
    public var isExecutable: Bool {
        switch self {
        case .invariants, .procedure, .applicability, .negativeApplicability, .prohibitions:
            return true
        case .template, .tools, .conventionRef, .inert:
            return false
        }
    }

    /// The built-in heading→role alias seed, expressed as data so it is the
    /// single trackable source of the default `=== sections ===` aliases. These
    /// mirror the canonical SKILL.md section names so a skill compiles even
    /// without a `=== sections ===` rulebook block; a rulebook extends or
    /// overrides them (author rules are consulted first — see
    /// `Rulebook.role(forHeading:)`). Aliases are stored pre-normalised
    /// (lower-cased, whitespace-collapsed) to match `normalizeHeading` output.
    ///
    /// The open-ended numbered-phase heading (`Phase 1: …`, `Phase A.5: …`)
    /// cannot be an exact-match alias and is recognised by prefix in
    /// `builtinRole(forHeading:)`.
    public static let builtinSectionAliases: [(alias: String, role: SkillSectionRole)] = [
        ("contract", .invariants), ("guarantees", .invariants),
        ("contract & guarantees", .invariants), ("invariants", .invariants),
        ("phases", .procedure), ("workflow", .procedure), ("pipeline", .procedure),
        ("protocol", .procedure), ("steps", .procedure), ("process", .procedure),
        ("procedure", .procedure),
        ("when to use", .applicability), ("use when", .applicability),
        ("primary triggers", .applicability), ("when this applies", .applicability),
        ("when to invoke", .applicability), ("when to run", .applicability),
        ("when to use this", .applicability), ("prerequisites", .applicability),
        ("preconditions", .applicability),
        ("when not to use", .negativeApplicability), ("do not use", .negativeApplicability),
        ("skip when", .negativeApplicability),
        ("anti-patterns", .prohibitions), ("anti patterns", .prohibitions),
        ("avoid", .prohibitions), ("pitfalls", .prohibitions),
        ("quality rules", .invariants), ("hard rules", .invariants),
        ("verification", .invariants), ("verification checklist", .invariants),
        ("output format", .template), ("output", .template), ("report format", .template),
        ("result format", .template), ("output structure", .template),
        ("brain page format", .template),
        ("tools used", .tools), ("tools", .tools), ("tools required", .tools),
        ("required tools", .tools),
    ]

    /// O(1) lookup table built from `builtinSectionAliases`.
    private static let builtinAliasTable: [String: SkillSectionRole] =
        Dictionary(builtinSectionAliases.map { ($0.alias, $0.role) }, uniquingKeysWith: { a, _ in a })

    /// Built-in heading aliases applied when no rulebook rule matches. Backed by
    /// `builtinSectionAliases` (the single data source) plus the open-ended
    /// numbered-phase prefix rule. Returns nil for unmapped headings (which,
    /// absent a marker, are `unresolved` — a hard error if the section has
    /// content).
    public static func builtinRole(forHeading heading: String) -> SkillSectionRole? {
        let normalized = Rulebook.normalizeHeading(heading)
        if let role = builtinAliasTable[normalized] { return role }
        // A numbered phase heading (`Phase 1: Inventory`, `Phase A.5: …`) is an
        // executable procedure section; the open-ended N/A suffix can't be an
        // exact alias, so recognise the `phase` prefix here.
        if normalized.hasPrefix("phase ") { return .procedure }
        return nil
    }

    /// A non-executable / role marker mined from a heading's trailing
    /// `(( … ))` suffix. `inert` is set by the `inert` keyword; `role` by a
    /// `role: <name>` term. The marker is authoritative: when present, the
    /// heading text is NOT used to derive a role.
    public struct SectionMarker: Sendable, Equatable {
        public let inert: Bool
        public let role: SkillSectionRole?
        public init(inert: Bool, role: SkillSectionRole?) {
            self.inert = inert
            self.role = role
        }
    }

    /// Result of stripping a heading's trailing `(( … ))` marker.
    /// `unknownRole` carries an unrecognized `role: <name>` token so the caller
    /// can raise a located hard error.
    public struct MarkerParse: Sendable, Equatable {
        public let cleanHeading: String
        public let marker: SectionMarker?
        public let unknownRole: String?
    }

    /// Parse a single trailing `(( … ))` marker from a heading line. The inner
    /// text is split on commas; each term is either the `inert` keyword or a
    /// `role: <name>` assignment (`<name>` via `SkillSectionRole(rawValue:)`).
    /// Whitespace/case tolerant. Returns the heading with the marker removed,
    /// the parsed marker (nil when absent), and any unrecognized role token.
    public static func parseMarker(from heading: String) -> MarkerParse {
        let trimmed = heading.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix("))"), let open = trimmed.range(of: "((", options: .backwards) else {
            return MarkerParse(cleanHeading: trimmed, marker: nil, unknownRole: nil)
        }
        let inner = String(trimmed[open.upperBound...].dropLast(2))
        let clean = String(trimmed[..<open.lowerBound]).trimmingCharacters(in: .whitespaces)
        var inert = false
        var role: SkillSectionRole? = nil
        var unknownRole: String? = nil
        for rawTerm in inner.split(separator: ",") {
            let term = rawTerm.trimmingCharacters(in: .whitespaces)
            if term.isEmpty { continue }
            let lower = term.lowercased()
            if lower == "inert" {
                inert = true
            } else if lower.hasPrefix("role:") {
                let name = String(term[term.index(term.startIndex, offsetBy: 5)...])
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                if let parsed = SkillSectionRole(rawValue: name) {
                    role = parsed
                } else {
                    unknownRole = name
                }
            } else {
                // An unrecognized bare term — surface as an unknown role token
                // so the author gets a precise error instead of a silent drop.
                unknownRole = lower
            }
        }
        return MarkerParse(cleanHeading: clean,
                           marker: SectionMarker(inert: inert, role: role),
                           unknownRole: unknownRole)
    }
}

/// One segment of a desugar rule's `match:` template.
public enum RuleToken: Sendable, Equatable {
    /// Literal text that must appear verbatim (case-insensitive) in the input.
    case literal(String)
    /// A `{name}` capture hole; its text is bound and substituted into `rewrite:`.
    case hole(String)
}

/// A desugar rule: `If {c} -> {a}.` ⇒ `if {c}, {a}.`
public struct DesugarRule: Sendable {
    public let name: String
    public let priority: Int
    public let match: [RuleToken]
    public let rewrite: String
    /// True when the rule used the `lowers to:` escape hatch (its `rewrite`
    /// text targets a primitive statement directly). Purely informational —
    /// both paths re-parse + lower through the identical strict pipeline.
    public let targetsPrimitive: Bool
    public let sourceLine: Int

    public init(name: String, priority: Int = 0, match: [RuleToken],
                rewrite: String, targetsPrimitive: Bool = false, sourceLine: Int = 0) {
        self.name = name
        self.priority = priority
        self.match = match
        self.rewrite = rewrite
        self.targetsPrimitive = targetsPrimitive
        self.sourceLine = sourceLine
    }

    /// The capture hole names this rule binds, in declaration order.
    public var holeNames: [String] {
        match.compactMap { if case .hole(let n) = $0 { return n } else { return nil } }
    }
}

/// A section-role rule: `section "Contract" -> invariants`.
public struct SectionRoleRule: Sendable, Equatable {
    /// Lower-cased heading alias (e.g. `"contract"`, `"when to use"`).
    public let alias: String
    public let role: SkillSectionRole
    public let sourceLine: Int

    public init(alias: String, role: SkillSectionRole, sourceLine: Int = 0) {
        self.alias = alias
        self.role = role
        self.sourceLine = sourceLine
    }
}

/// A trigger-classification keyword rule: `schedule: nightly`. Maps a single
/// surface word to the `TriggerKind` it signals when it appears in a
/// `triggers:` frontmatter spec. The `keyword` kind is the fallback and needs
/// no words; the other three are keyword-driven.
public struct TriggerWordRule: Sendable, Equatable {
    public let kind: TriggerKind
    /// Lower-cased single surface word.
    public let word: String
    public let sourceLine: Int

    public init(kind: TriggerKind, word: String, sourceLine: Int = 0) {
        self.kind = kind
        self.word = word
        self.sourceLine = sourceLine
    }
}

/// A parsed rulebook. Empty by default, so existing `.meridian`/`.meri` files
/// (which reference no rulebook) are byte-for-byte unaffected.
public struct Rulebook: Sendable {
    public let desugars: [DesugarRule]
    public let sectionRoles: [SectionRoleRule]
    /// Inform-style behavioral conventions, already classified into phases.
    public let conventions: [RulebookRule]
    /// `=== triggers ===` keyword rules extending trigger classification.
    public let triggerWords: [TriggerWordRule]

    public init(desugars: [DesugarRule] = [],
                sectionRoles: [SectionRoleRule] = [],
                conventions: [RulebookRule] = [],
                triggerWords: [TriggerWordRule] = []) {
        self.desugars = desugars
        self.sectionRoles = sectionRoles
        self.conventions = conventions
        self.triggerWords = triggerWords
    }

    public static let empty = Rulebook()

    /// The built-in trigger-classification keywords as a `=== triggers ===`
    /// rulebook — the single data source `TriggerClassifier` seeds from. Author
    /// rulebooks union additional words on top (see `triggerWordSets`).
    public static let defaultTriggers = Rulebook(triggerWords:
        ([
            (TriggerKind.schedule, [
                "nightly", "daily", "hourly", "weekly", "monthly", "cron",
                "schedule", "scheduled", "morning", "evening", "midnight", "noon",
            ]),
            (TriggerKind.ambient, [
                "always", "ambient", "continuous", "continuously", "inbound",
                "every", "stream", "streaming", "watch", "watching", "ongoing",
            ]),
            (TriggerKind.event, [
                "received", "arrives", "arrived", "created", "updated", "deleted",
                "webhook", "fires", "fired", "pushed", "merged", "opened",
                "closed", "on",
            ]),
        ] as [(TriggerKind, [String])]).flatMap { kind, words in
            words.map { TriggerWordRule(kind: kind, word: $0) }
        }
    )

    /// Merge this rulebook's trigger words over the built-in defaults, grouped
    /// by kind for the classifier. Defaults are always included; author words
    /// add to (never remove from) the set for a kind.
    public func triggerWordSets() -> [TriggerKind: Set<String>] {
        var sets: [TriggerKind: Set<String>] = [:]
        for rule in Rulebook.defaultTriggers.triggerWords + triggerWords {
            sets[rule.kind, default: []].insert(rule.word.lowercased())
        }
        return sets
    }

    /// The built-in section-role aliases as a `=== sections ===` rulebook. This
    /// is the data form of `SkillSectionRole.builtinSectionAliases`; the
    /// compiler still applies the builtins via `builtinRole(forHeading:)` (so
    /// no resolution path changes), but exposing them as a `Rulebook` lets
    /// tooling and docs treat the defaults and author extensions uniformly.
    public static let defaultSections = Rulebook(
        sectionRoles: SkillSectionRole.builtinSectionAliases.map {
            SectionRoleRule(alias: $0.alias, role: $0.role)
        }
    )

    public var isEmpty: Bool {
        desugars.isEmpty && sectionRoles.isEmpty && conventions.isEmpty && triggerWords.isEmpty
    }

    /// Concatenate two rulebooks (left-hand entries take priority on ties:
    /// desugars are applied highest-priority-then-source-order, and the first
    /// matching section-role alias wins).
    public func merging(_ other: Rulebook) -> Rulebook {
        Rulebook(
            desugars: desugars + other.desugars,
            sectionRoles: sectionRoles + other.sectionRoles,
            conventions: conventions + other.conventions,
            triggerWords: triggerWords + other.triggerWords
        )
    }

    /// Resolve a markdown heading to its section role, if a rule maps it.
    /// Matching is case-insensitive and whitespace-normalised.
    public func role(forHeading heading: String) -> SkillSectionRole? {
        let key = Rulebook.normalizeHeading(heading)
        return sectionRoles.first { $0.alias == key }?.role
    }

    /// Normalise a line for alias/heading comparison: optionally strip a leading
    /// Markdown list marker, then lower-case, collapse internal whitespace, and
    /// trim trailing punctuation. Single source for `normalizeHeading` and the
    /// migrator's `normalizeConvention`.
    public static func normalizeLine(_ s: String, stripListMarkers: Bool = false) -> String {
        var t = s.trimmingCharacters(in: .whitespaces)
        if stripListMarkers {
            for marker in ["- ", "* ", "+ "] where t.hasPrefix(marker) {
                t = String(t.dropFirst(marker.count)); break
            }
        }
        let collapsed = t
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: ":.,;!?"))
    }

    /// Normalise a heading for alias comparison: lower-cased, trimmed, internal
    /// whitespace collapsed, trailing punctuation removed.
    public static func normalizeHeading(_ heading: String) -> String {
        normalizeLine(heading)
    }
}

// MARK: - RulebookInput

/// One rulebook input (a parsed `.merrules` source). The `name` is the logical
/// label referenced by the frontmatter `rulebook:` key — the `.merrules`
/// filename without the extension by convention.
public struct RulebookInput: Sendable {
    public let name: String
    public let file: String
    public let source: String
    public init(name: String, file: String, source: String) {
        self.name = name
        self.file = file
        self.source = source
    }
}
