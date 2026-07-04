import Foundation

/// The registry of deterministic surface productions.
///
/// Adding a production is intentionally a small, reviewable edit:
/// 1. Add one `GrammarProduction` block in `PegexSurfaceGrammar`.
/// 2. Add one test with the same production name, in table order.
/// 3. Run the ambiguity and differential suites.
struct GrammarTable: Sendable {
    let productions: [GrammarProduction]

    init(productions: [GrammarProduction]) {
        self.productions = productions
    }

    var anchors: [String] {
        stableUnique(productions.flatMap(\.anchors))
    }

    func production(named name: String) -> GrammarProduction? {
        productions.first { $0.name == name }
    }

    func markdownReference() -> String {
        var lines = [
            "| Production | Implementation | Canonical Example | Anchors |",
            "|---|---|---|---|",
        ]
        for production in productions {
            let anchors = production.anchors.isEmpty
                ? "(none)"
                : production.anchors.map { "`\($0)`" }.joined(separator: ", ")
            lines.append("| `\(production.name)` | \(production.implementation.rawValue) | \(production.canonicalExample) | \(anchors) |")
        }
        return lines.joined(separator: "\n")
    }
}

struct GrammarProduction: Sendable, Equatable {
    enum Category: String, Sendable {
        case expression
        case description
        case template
        case statementIdiom
    }

    /// Which tool builds this production's parser. A per-pattern choice, not a
    /// migration status: `handWritten` productions are first-class, permanent
    /// implementations chosen because a dynamic scan over runtime state (verb
    /// resolution, symbol-table lookups) is clearer than forcing a fixed
    /// grammar, not because they're pending a future port. See
    /// `IMPLEMENTATION_LOG.md` ("Per-production expression grammar") for the
    /// full rationale per production.
    enum Implementation: String, Sendable {
        case pegex
        case handWritten = "hand-written"
    }

    let name: String
    let category: Category
    let implementation: Implementation
    let canonicalExample: String
    let summary: String
    let anchors: [String]

    init(
        name: String,
        category: Category,
        implementation: Implementation,
        canonicalExample: String,
        summary: String,
        anchors: [String]
    ) {
        self.name = name
        self.category = category
        self.implementation = implementation
        self.canonicalExample = canonicalExample
        self.summary = summary
        self.anchors = stableUnique(anchors.map(cleanAnchor).filter { !$0.isEmpty })
    }
}

func stableUnique(_ values: [String]) -> [String] {
    var seen: Set<String> = []
    var out: [String] = []
    for value in values where seen.insert(value).inserted {
        out.append(value)
    }
    return out
}

private func cleanAnchor(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}
