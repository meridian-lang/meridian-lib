import Foundation
import Testing
@testable import MeridianCore

@Suite("Wave 7 verbalizer evidence matrix")
struct VerbalizerEvidenceTests {
    @Test("every IR primitive and GrammarTable production is covered")
    func matrixCoversPrimitiveAndGrammarRows() throws {
        let matrix = try evidenceMatrix()
        let rows = parseRows(matrix)
        let constructs = Set(rows.compactMap { $0.firstColumnCode })

        for primitive in IRPrimitiveKind.allCases.map(\.rawValue) {
            #expect(constructs.contains(primitive), Comment(rawValue: "Missing IR primitive row for `\(primitive)`"))
        }

        let productionNames = PegexSurfaceGrammar(lexicon: .default).table.productions.map(\.name)
        for production in productionNames {
            #expect(constructs.contains(production), Comment(rawValue: "Missing GrammarTable row for `\(production)`"))
        }
    }

    @Test("no matrix row is blocked")
    func matrixHasNoBlockedRows() throws {
        let rows = parseRows(try evidenceMatrix())
        let blocked = rows.filter { $0.status == "blocked" }
        #expect(blocked.isEmpty, Comment(rawValue: "Blocked verbalizer evidence rows:\n\(blocked.map(\.raw).joined(separator: "\n"))"))
    }

    private func evidenceMatrix() throws -> String {
        let url = VerbalizerTestSupport.repositoryRoot()
            .appendingPathComponent("docs/coverage/VERBALIZER_EVIDENCE.md")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func parseRows(_ markdown: String) -> [MatrixRow] {
        markdown.split(separator: "\n", omittingEmptySubsequences: false).compactMap { rawLine in
            let raw = String(rawLine)
            guard raw.hasPrefix("|"), !raw.contains("|---") else { return nil }
            let columns = raw
                .split(separator: "|", omittingEmptySubsequences: false)
                .dropFirst()
                .dropLast()
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard columns.count >= 2, columns[0] != "Construct", columns[0] != "Production",
                  columns[0] != "Form", columns[0] != "Source", columns[0] != "Item" else {
                return nil
            }
            return MatrixRow(raw: raw, columns: Array(columns))
        }
    }

    private struct MatrixRow {
        let raw: String
        let columns: [String]

        var firstColumnCode: String? {
            guard let column = columns.first else { return nil }
            if let first = codeSpans(in: column).first {
                return first
            }
            return column.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var status: String {
            columns.last?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        }

        private func codeSpans(in text: String) -> [String] {
            var spans: [String] = []
            var remainder = text[...]
            while let start = remainder.firstIndex(of: "`") {
                let afterStart = remainder.index(after: start)
                guard let end = remainder[afterStart...].firstIndex(of: "`") else { break }
                spans.append(String(remainder[afterStart..<end]))
                remainder = remainder[remainder.index(after: end)...]
            }
            return spans
        }
    }
}
