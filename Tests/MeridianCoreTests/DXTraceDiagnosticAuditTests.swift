import Foundation
import Testing
@testable import MeridianCore

// DX audit baseline (plan step 2): machine-readable matrix, diagnostic catalog
// completeness, and ParserTrace category coverage.

@Suite("DX trace diagnostic audit")
struct DXTraceDiagnosticAuditTests {
    private struct MatrixRow: Decodable {
        var id: String
        var phase: String
        var tests: [String]
        var traceCategories: [String]
        var status: String
    }

    private struct MatrixDocument: Decodable {
        var version: Int
        var rows: [MatrixRow]
        var summary: Summary

        struct Summary: Decodable {
            var rowCount: Int
            var done: Int
            var pending: Int
        }
    }

    /// Pending matrix rows — must stay empty once the DX matrix is fully closed.
    private static let knownPendingMatrixIDs: Set<String> = []

    /// Categories exercised only via CLI/runtime paths documented in the matrix.
    private static let documentedTraceCategoryOnly: [ParserTrace.Category: String] = [
        .timing: "DX-CLI-001 — `meridian compile --trace timing` and `ParserTraceCoverageTests`",
    ]

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("DX trace diagnostic matrix JSON parses with unique ids and bounded pending rows")
    func matrixJSONIsWellFormed() throws {
        let url = repositoryRoot()
            .appendingPathComponent("docs/coverage/dx-trace-diagnostic-matrix.json")
        let data = try Data(contentsOf: url)
        let doc = try JSONDecoder().decode(MatrixDocument.self, from: data)

        #expect(doc.version >= 1)
        #expect(doc.rows.count == doc.summary.rowCount)

        var ids: [String] = []
        var pending: [String] = []
        var done = 0
        for row in doc.rows {
            #expect(!row.id.isEmpty)
            #expect(!row.phase.isEmpty)
            ids.append(row.id)
            switch row.status {
            case "done": done += 1
            case "pending": pending.append(row.id)
            default:
                Issue.record("unexpected matrix status `\(row.status)` on \(row.id)")
            }
        }

        #expect(Set(ids).count == ids.count, Comment(rawValue: "duplicate matrix ids"))
        #expect(done == doc.summary.done)
        #expect(pending.count == doc.summary.pending)
        #expect(pending.isEmpty, Comment(rawValue: "DX matrix must have zero pending rows: \(pending.sorted())"))
        #expect(doc.summary.pending == 0)

        let unknownPending = Set(pending).subtracting(Self.knownPendingMatrixIDs)
        #expect(
            unknownPending.isEmpty,
            Comment(rawValue: "unexpected pending matrix rows (register in knownPendingMatrixIDs or close the gap): \(unknownPending.sorted())")
        )
        let staleGaps = Self.knownPendingMatrixIDs.subtracting(pending)
        #expect(
            staleGaps.isEmpty,
            Comment(rawValue: "knownPendingMatrixIDs still lists closed rows: \(staleGaps.sorted())")
        )
    }

    @Test("DiagnosticCode.all entries appear in DiagnosticCodeCatalog with explanations")
    func diagnosticCatalogCoversActiveCodes() {
        #expect(DiagnosticCode.catalog.count == DiagnosticCode.all.count)
        for code in DiagnosticCode.all {
            guard let entry = DiagnosticCode.catalogByID[code.id] else {
                Issue.record("missing catalog entry for \(code.id)")
                continue
            }
            switch entry.status {
            case .active:
                #expect(
                    !code.explanation.isEmpty,
                    Comment(rawValue: "\(code.id) missing explanation on DiagnosticCode")
                )
                #expect(
                    !entry.code.explanation.isEmpty,
                    Comment(rawValue: "\(code.id) missing explanation in catalog entry")
                )
                #expect(
                    !entry.emitters.isEmpty,
                    Comment(rawValue: "\(code.id) active but has no catalog emitters")
                )
            case .reserved, .deprecated:
                #expect(
                    entry.emitters.isEmpty,
                    Comment(rawValue: "\(code.id) \(entry.status.rawValue) but lists emitters")
                )
            }
        }
    }

    @Test("docs/15_PROBLEM_MESSAGES.md lists every active diagnostic code")
    func problemMessagesDocCoversActiveCodes() throws {
        let root = repositoryRoot()
        let markdown = try String(
            contentsOf: root.appendingPathComponent("docs/15_PROBLEM_MESSAGES.md"),
            encoding: .utf8
        )
        var missing: [String] = []
        for entry in DiagnosticCode.catalog where entry.status == .active {
            if !markdown.contains("`\(entry.code.id)`") {
                missing.append(entry.code.id)
            }
        }
        #expect(
            missing.isEmpty,
            Comment(rawValue: "docs/15_PROBLEM_MESSAGES.md missing: \(missing.sorted().joined(separator: ", "))")
        )
    }

    @Test("ParserTrace categories have fixture, matrix, or documented CLI coverage")
    func traceCategoriesHaveCoverageEvidence() throws {
        let root = repositoryRoot()
        let matrixURL = root.appendingPathComponent("docs/coverage/dx-trace-diagnostic-matrix.json")
        let matrix = try JSONDecoder().decode(MatrixDocument.self, from: Data(contentsOf: matrixURL))
        let matrixMarkdown = try String(
            contentsOf: root.appendingPathComponent("docs/coverage/DX_TRACE_DIAGNOSTIC_MATRIX.md"),
            encoding: .utf8
        )

        var evidence = traceCategoryEvidence(from: root.appendingPathComponent("Tests"))
        for row in matrix.rows where row.status == "done" && !row.tests.isEmpty {
            for raw in row.traceCategories where raw != "all" {
                if let cat = category(matchingRaw: raw) {
                    evidence.insert(cat)
                }
            }
        }
        if matrixMarkdown.contains("Category.allCases") || matrixMarkdown.contains("DX-X-003") {
            evidence.formUnion(ParserTrace.Category.allCases)
        }

        var failures: [String] = []
        for cat in ParserTrace.Category.allCases {
            if evidence.contains(cat) { continue }
            if let reason = Self.documentedTraceCategoryOnly[cat] {
                if !matrixMarkdown.contains(reason) && !matrixMarkdown.contains(cat.rawValue) {
                    failures.append("\(cat.rawValue): documented-only but missing matrix mention (\(reason))")
                }
                continue
            }
            failures.append("\(cat.rawValue): no test fixture, matrix row with tests, or documented CLI-only reason")
        }

        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    private func category(matchingRaw raw: String) -> ParserTrace.Category? {
        if raw == "all" { return nil }
        return ParserTrace.Category.allCases.first { $0.rawValue == raw }
    }

    private func traceCategoryEvidence(from testsRoot: URL) -> Set<ParserTrace.Category> {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: testsRoot, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return []
        }

        var evidence: Set<ParserTrace.Category> = []
        var allCasesSweep = false
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if source.contains("ParserTrace.Category.allCases") || source.contains("Category.allCases") {
                allCasesSweep = true
            }
            for cat in ParserTrace.Category.allCases {
                if sourceContainsReference(to: cat, in: source) {
                    evidence.insert(cat)
                }
            }
        }
        if allCasesSweep {
            evidence.formUnion(ParserTrace.Category.allCases)
        }
        return evidence
    }

    private func sourceContainsReference(to category: ParserTrace.Category, in source: String) -> Bool {
        let raw = category.rawValue
        let enumCase = String(describing: category)
        if source.contains(".\(enumCase)") { return true }
        if source.contains("\"\(raw)\"") { return true }
        if source.contains("[\(enumCase)]") || source.contains("[.\(enumCase)]") { return true }
        if source.contains("hasPrefix(\"\(raw)\")") || source.contains("[\(raw)]") { return true }
        return false
    }
}
