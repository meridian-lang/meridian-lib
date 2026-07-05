import Foundation
import Testing
@testable import MeridianCore

@Suite("Wave 5 nonterminal screening")
struct NonterminalScreeningTests {

    @Test("anchor masks include production anchors")
    func anchorMasks() throws {
        let table = PegexSurfaceGrammar().table
        let screen = NonterminalScreen(table: table)
        let comparison = try #require(table.production(named: "comparison"))

        #expect(screen.anchorCount > 0)
        #expect(screen.anchorMask(for: comparison) != 0)
        #expect(screen.mask(for: "total amount is more than 500") & screen.anchorMask(for: comparison) != 0)
    }

    @Test("candidates skip productions with missing anchors")
    func candidates() {
        let table = PegexSurfaceGrammar().table
        let screen = NonterminalScreen(table: table)
        let names = screen.candidates(for: "total amount is more than 500").map(\.name)

        #expect(names.contains("comparison"))
        #expect(!names.contains("template-loop"))
    }

    @Test("screening does not change parsed AST for supported expressions")
    func parserEquivalence() {
        let table = PegexSurfaceGrammar().table
        let screen = NonterminalScreen(table: table)
        let source = "status is not active"
        let hasComparison = screen.candidates(for: source).contains { $0.name == "comparison" }
        #expect(hasComparison)

        let screened = ExpressionParser(symbols: nil, trace: .silent(), lexicon: .default, useScreen: true)
            .parse(source)
        let unscreened = ExpressionParser(symbols: nil, trace: .silent(), lexicon: .default, useScreen: false)
            .parse(source)
        #expect(screened.traceDescription(detail: .verbose) == unscreened.traceDescription(detail: .verbose))
    }

    @Test("parser benchmark reports both unscreened and screened modes")
    func parserBenchmark() {
        let result = ParserBenchmark().run(sentences: [
            "total amount is more than 500",
            "status is not active",
        ])

        #expect(result.sentenceCount == 2)
        #expect(result.screenedCandidateCount > 0)
        #expect(result.unscreenedSeconds >= 0)
        #expect(result.screenedSeconds >= 0)
    }

    // MARK: - Wave 5B acceptance: corpus-scale screened/unscreened differential
    //
    // `NonterminalScreen` is a pure pre-filter optimization: it must never
    // change what a production parses to, only skip productions it can prove
    // have no chance of matching. `parserEquivalence` above checks exactly one
    // hand-picked sentence; this harness feeds every line of every real skill
    // file across `sample-gbrain`, `corpora/erp`, `corpora/procedures`, and
    // `examples` (thousands of lines spanning comparisons, quantifiers,
    // descriptions, relations, temporal windows, templates, and tables) through
    // both a screened and an unscreened `ExpressionParser` and asserts their
    // parsed trees are byte-identical. Lines that aren't expression-shaped at
    // all still parse to *some* AST (often `.identifierRef`/`.malformed`); the
    // guarantee under test is that both modes agree on every line, not that
    // every line is a "real" expression.
    @Test("screening is a no-op differential across the full corpus of real skill files")
    func corpusScaleScreeningDifferential() throws {
        let lines = try Self.corpusLines()
        #expect(lines.count > 2000, Comment(rawValue: "expected a corpus-scale line count, got \(lines.count)"))

        let screened = ExpressionParser(symbols: nil, trace: .silent(), lexicon: .default, useScreen: true)
        let unscreened = ExpressionParser(symbols: nil, trace: .silent(), lexicon: .default, useScreen: false)

        var mismatches: [String] = []
        for (source, text) in lines {
            let a = screened.parse(text).traceDescription(detail: .verbose)
            let b = unscreened.parse(text).traceDescription(detail: .verbose)
            if a != b {
                mismatches.append("\(source): \"\(text)\"\n    screened:   \(a)\n    unscreened: \(b)")
                if mismatches.count >= 20 { break }   // bounded — the count above proves scale
            }
        }
        #expect(mismatches.isEmpty,
                Comment(rawValue: "screened/unscreened parse diverged on \(mismatches.count)+ line(s):\n"
                    + mismatches.joined(separator: "\n")))
    }

    /// Every non-blank, non-fence line of every `.meri`/`.meridian` file under
    /// `sample-gbrain`, `corpora/{erp,procedures}`, and `examples` (excluding
    /// generated `compile-outputs`), paired with a `"<relative path>:<line>"`
    /// label for failure reporting.
    private static func corpusLines() throws -> [(source: String, text: String)] {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dirs = ["sample-gbrain", "corpora/erp", "corpora/procedures", "examples"]
        let fm = FileManager.default
        var result: [(String, String)] = []

        for dir in dirs {
            let dirURL = root.appendingPathComponent(dir)
            guard let enumerator = fm.enumerator(
                at: dirURL, includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]) else { continue }
            for case let fileURL as URL in enumerator {
                guard ["meri", "meridian"].contains(fileURL.pathExtension) else { continue }
                guard !fileURL.path.contains("/compile-outputs/") else { continue }
                guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let rel = fileURL.path.hasPrefix(root.path) ? String(fileURL.path.dropFirst(root.path.count + 1)) : fileURL.path
                for (i, line) in text.components(separatedBy: .newlines).enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, trimmed != "```", trimmed != "---" else { continue }
                    result.append(("\(rel):\(i + 1)", trimmed))
                }
            }
        }
        return result
    }

    @Test("screen keeps no-anchor productions eligible")
    func noAnchorProduction() {
        let production = GrammarProduction(
            name: "fallback",
            category: .expression,
            implementation: .pegex,
            canonicalExample: "`x`",
            summary: "Fallback production.",
            anchors: []
        )
        let screen = NonterminalScreen(table: GrammarTable(productions: [production]))

        #expect(screen.anchorCount == 0)
        #expect(screen.anchorMask(for: production) == 0)
        #expect(screen.candidates(for: "anything").map(\.name) == ["fallback"])
    }
}
