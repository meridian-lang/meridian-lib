import ArgumentParser
import Foundation
import MeridianCore

// MARK: - `meridian decisions`
//
// Makes the design-decision log queryable from the CLI: list/search every
// record, print one in full (`--id`), or regenerate the human-readable
// `docs/15_DECISIONS.md` from the catalog (`--render`). The render mode is what
// keeps the doc from drifting — a test re-renders and diffs.

struct DecisionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "decisions",
        abstract: "List, search, or render the design-decision catalog."
    )

    @Option(name: .long, help: "Print one decision in full by id (e.g. D-DX-5).")
    var id: String?

    @Argument(help: "Optional search term to filter decisions by title/rationale.")
    var query: String?

    @Option(name: .long, help: "Render the full catalog as Markdown to this path (regenerates docs/15_DECISIONS.md).")
    var render: String?

    func run() throws {
        if let render {
            let markdown = DecisionCatalog.renderMarkdown()
            try markdown.write(to: URL(fileURLWithPath: render), atomically: true, encoding: .utf8)
            print("✓ rendered \(DecisionCatalog.all.count) decisions to \(render)")
            return
        }

        if let id {
            guard let decision = DecisionCatalog.lookup(id) else {
                var hint = ""
                if let close = Suggester().closest(id, among: DecisionCatalog.all.map(\.id)) {
                    hint = " Did you mean \(close)?"
                }
                FileHandle.standardError.write(Data("unknown decision '\(id)'.\(hint)\n".utf8))
                throw ExitCode(1)
            }
            ExplainCommand.printDecision(decision)
            return
        }

        let records: [DecisionRecord]
        if let q = query?.lowercased(), !q.isEmpty {
            records = DecisionCatalog.all.filter {
                $0.id.lowercased().contains(q) || $0.title.lowercased().contains(q)
                    || $0.rationale.lowercased().contains(q)
            }
            if records.isEmpty {
                print("No decisions match '\(query!)'.")
                return
            }
        } else {
            records = DecisionCatalog.all
        }

        for d in records {
            print("\(d.id)  [\(d.status.rawValue)]  \(d.title)")
            if !d.seeAlso.isEmpty {
                print("    see also: \(d.seeAlso.joined(separator: ", "))")
            }
        }
        print("\nRun `meridian explain <id>` for the full rationale + alternatives.")
    }
}

extension ExplainCommand {
    /// Shared full-decision printer reused by `meridian decisions --id`.
    static func printDecision(_ decision: DecisionRecord) {
        print("\(decision.id) — \(decision.title)  [\(decision.status.rawValue)]\n")
        print(decision.rationale)
        if !decision.alternatives.isEmpty {
            print("\nAlternatives considered:")
            for a in decision.alternatives { print("  - \(a)") }
        }
        if !decision.consequences.isEmpty {
            print("\nConsequences:")
            for c in decision.consequences { print("  - \(c)") }
        }
        if !decision.seeAlso.isEmpty {
            print("\nSee also: \(decision.seeAlso.joined(separator: ", "))")
        }
    }
}
