import Foundation
import MeridianRuntime

// MARK: - Skill triggers
//
// `triggers:` frontmatter entries describe HOW a skill is activated. They are
// classified into a closed `TriggerKind` (keyword / ambient / event / schedule)
// and synthesised into one parameter-less trigger workflow each. Following the
// existing event-trigger design (see `RuleInjector.synthesizeTriggers`), the
// synthetic workflow waits for the trigger to fire and fans out a
// `trigger.<name>.fired` event carrying the typed kind + original spec; the
// HOST owns actual firing (running the cron schedule, watching the ambient
// stream, matching the keyword/intent). The typed kind + spec are also recorded
// in the manifest under `meridian_skill.triggers` for discovery/routing.
//
// Determinism contract: a trigger never reaches the LLM. It compiles to a
// deterministic `wait` + `emit`; routing to the actual skill is the resolver
// workflow's job (a `branch`/`match` over the fired event), also deterministic.

/// The closed set of trigger activation kinds. New kinds are a compile-time
/// TODO list (exhaustive switches, no `default:`).
public enum TriggerKind: String, Sendable, CaseIterable, Equatable {
    /// An intent / keyword phrase the host matches against user input.
    case keyword
    /// An always-on / continuous stream ("every inbound message").
    case ambient
    /// A discrete external event ("meeting transcript received").
    case event
    /// A time schedule ("nightly", "every morning", a cron expression).
    case schedule
}

/// A typed trigger projected from one `triggers:` frontmatter entry.
public struct SkillTrigger: Sendable, Equatable {
    public let kind: TriggerKind
    /// The original frontmatter text (verbatim), preserved for the manifest.
    public let spec: String
    /// Canonical event name (camelCase of the leading spec tokens).
    public let name: String
    public let sourceLine: Int

    public init(kind: TriggerKind, spec: String, name: String, sourceLine: Int) {
        self.kind = kind
        self.spec = spec
        self.name = name
        self.sourceLine = sourceLine
    }
}

/// Classify a `triggers:` entry into a typed `SkillTrigger`. Pure + data-driven
/// over keyword sets sourced from `Rulebook` (built-in defaults in
/// `Rulebook.defaultTriggers`, extended by an author's `=== triggers ===`
/// block) so the words are obvious and extensible without recompiling.
struct TriggerClassifier {
    let lexicon: EnglishLexicon
    private let wordSets: [TriggerKind: Set<String>]

    init(lexicon: EnglishLexicon, rulebook: Rulebook = .empty) {
        self.lexicon = lexicon
        self.wordSets = rulebook.triggerWordSets()
    }

    func classify(_ raw: String, sourceLine: Int) -> SkillTrigger {
        let spec = raw.trimmingCharacters(in: .whitespaces)
        let kind = kindOf(spec)
        return SkillTrigger(kind: kind, spec: spec, name: canonicalName(spec), sourceLine: sourceLine)
    }

    private func kindOf(_ spec: String) -> TriggerKind {
        let lower = spec.lowercased()
        // Cron-style: contains a `*` or several space-separated time fields.
        if lower.contains("*") || isCronLike(lower) { return .schedule }
        let words = Set(lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        // Schedule keywords beat ambient (e.g. "every morning" is a schedule).
        if !words.isDisjoint(with: wordSets[.schedule] ?? []) { return .schedule }
        if !words.isDisjoint(with: wordSets[.ambient] ?? []) { return .ambient }
        if !words.isDisjoint(with: wordSets[.event] ?? []) { return .event }
        return .keyword
    }

    private func isCronLike(_ s: String) -> Bool {
        let fields = s.split(separator: " ")
        guard fields.count >= 5 else { return false }
        return fields.prefix(5).allSatisfy { f in
            f.allSatisfy { $0.isNumber || $0 == "*" || $0 == "/" || $0 == "," || $0 == "-" }
        }
    }

    private func canonicalName(_ spec: String) -> String {
        let stopwords = lexicon.articles.union(lexicon.prepositions)
        let tokens = spec.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopwords.contains($0) }
        let head = tokens.prefix(5)
        guard let first = head.first else { return "trigger" }
        return first + head.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
}

/// Build one synthetic trigger workflow per typed trigger.
struct TriggerSynthesizer {
    let lexicon: EnglishLexicon
    let trace: ParserTrace

    func synthesize(_ triggers: [SkillTrigger], sourceFile: String) -> [IRWorkflow] {
        // Distinct trigger phrases can normalise to the same struct name
        // (e.g. "perplexity research" and "perplexity-research" both →
        // WhenPerplexityResearchFires). The workflows stay semantically
        // distinct (different event IDs), so disambiguate the Swift struct
        // name with a numeric suffix to avoid an invalid redeclaration.
        var used: [String: Int] = [:]
        return triggers.map { trigger in
            let base = lexicon.structName(from: "when \(trigger.name) fires")
            let seen = used[base, default: 0]
            used[base] = seen + 1
            let explicit = seen == 0 ? base : "\(base)\(seen + 1)"
            return synthesizeOne(trigger, sourceFile: sourceFile, explicitStructName: explicit)
        }
    }

    private func synthesizeOne(_ trigger: SkillTrigger, sourceFile: String,
                               explicitStructName: String) -> IRWorkflow {
        trace.log(.lowering, "trigger @L\(trigger.sourceLine) [\(trigger.kind.rawValue)] → when \(trigger.name)")
        return TriggerWorkflowBuilder.make(
            name: "when \(trigger.name) fires",
            waitEvent: trigger.name,
            fireEventID: "trigger.\(trigger.name).fired",
            payload: [
                EmitField("kind", .literal(.string(trigger.kind.rawValue))),
                EmitField("spec", .literal(.string(trigger.spec)))
            ],
            sourceFile: sourceFile,
            line: trigger.sourceLine,
            explicitStructName: explicitStructName
        )
    }
}
