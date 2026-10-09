import Foundation

/// Timing summary for `meridian bench-parse`.
public struct ParserBenchmarkResult: Sendable, Equatable {
    public let sentenceCount: Int
    public let unscreenedSeconds: Double
    public let screenedSeconds: Double
    public let screenedCandidateCount: Int

    public init(
        sentenceCount: Int,
        unscreenedSeconds: Double,
        screenedSeconds: Double,
        screenedCandidateCount: Int
    ) {
        self.sentenceCount = sentenceCount
        self.unscreenedSeconds = unscreenedSeconds
        self.screenedSeconds = screenedSeconds
        self.screenedCandidateCount = screenedCandidateCount
    }
}

/// Runs the expression-parser dispatcher with `NonterminalScreen` gating
/// disabled vs enabled over a sentence corpus — the speedup Wave 5B's screen
/// is meant to buy on top of the (now sole) per-production dispatcher.
public struct ParserBenchmark: Sendable {
    public let lexicon: EnglishLexicon

    public init(lexicon: EnglishLexicon = .default) {
        self.lexicon = lexicon
    }

    public func run(sentences: [String]) -> ParserBenchmarkResult {
        // The benchmark measures raw parser cost — install a silent trace so an
        // active `MERIDIAN_TRACE` cannot skew the timing with trace I/O.
        ParserTrace.silent().run {
            runInSilence(sentences: sentences)
        }
    }

    private func runInSilence(sentences: [String]) -> ParserBenchmarkResult {
        let cleaned = sentences
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let screen = NonterminalScreen(table: PegexSurfaceGrammar(lexicon: lexicon).table)
        var screenedCandidateCount = 0

        let unscreened = measure {
            let parser = ExpressionParser(symbols: nil, lexicon: lexicon, useScreen: false)
            for sentence in cleaned {
                _ = parser.parse(sentence)
            }
        }

        let screened = measure {
            let parser = ExpressionParser(symbols: nil, lexicon: lexicon, useScreen: true)
            for sentence in cleaned {
                screenedCandidateCount += screen.candidates(for: sentence).count
                _ = parser.parse(sentence)
            }
        }

        return ParserBenchmarkResult(
            sentenceCount: cleaned.count,
            unscreenedSeconds: unscreened,
            screenedSeconds: screened,
            screenedCandidateCount: screenedCandidateCount
        )
    }
}

private func measure(_ body: () -> Void) -> Double {
    let start = Date()
    body()
    return Date().timeIntervalSince(start)
}
