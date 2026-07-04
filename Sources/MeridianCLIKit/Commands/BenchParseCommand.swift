import ArgumentParser
import Foundation
import MeridianCore

public struct BenchParseCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "bench-parse",
        abstract: "Benchmark unscreened vs NonterminalScreen-gated expression parsing over text files."
    )

    @Argument(help: "Text files containing one expression or sentence per line.")
    var inputs: [String]

    public func run() throws {
        let sentences = try inputs.flatMap { path -> [String] in
            let text = try String(contentsOfFile: path, encoding: .utf8)
            return text.components(separatedBy: .newlines)
        }
        let result = ParserBenchmark().run(sentences: sentences)

        print("sentences: \(result.sentenceCount)")
        print(String(format: "unscreened: %.6f s", result.unscreenedSeconds))
        print(String(format: "screened:   %.6f s", result.screenedSeconds))
        print("screened candidates: \(result.screenedCandidateCount)")
    }
}
