import ArgumentParser
import Foundation
import MeridianCore
import MeridianRuntime

// MARK: - `meridian trace render`
//
// Read a JSONL event stream (file or stdin) and print it as an indented
// tree using `TraceTreeRenderer`. The point is to make a long, dense
// `events.jsonl` digestible at a glance — useful when triaging a failed
// CI run or a flaky integration test.

public struct TraceRenderCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "trace",
        abstract: "Pretty-print a Meridian JSONL event stream as a tree.",
        subcommands: [Render.self, Categories.self, Verify.self, Eval.self, TraceDriftCommand.self],
        defaultSubcommand: Render.self
    )

    struct Categories: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "categories",
            abstract: "List the compile-time trace categories accepted by --trace."
        )

        func run() throws {
            print("Compile-time trace categories (use with --trace, comma-separated, or `all`):\n")
            let width = ParserTrace.Category.allCases.map { $0.rawValue.count }.max() ?? 12
            for cat in ParserTrace.Category.allCases {
                let name = cat.rawValue.padding(toLength: width, withPad: " ", startingAt: 0)
                print("  \(name)  \(cat.summary)")
            }
            print("\nGroup prefixes enable every sub-category (e.g. `phrase` enables phrase.parse/match/args/inline).")
            print("`.timing` is off by default and excluded from captured trace assertions.")
        }
    }

    struct Render: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "render",
            abstract: "Render a JSONL trace as an indented tree."
        )

        @Argument(help: "Path to a .jsonl file. Reads stdin when omitted.")
        var input: String?

        @Flag(name: .long, help: "Use ASCII glyphs instead of Unicode box-drawing characters.")
        var ascii: Bool = false

        @Flag(name: .long, help: "Hide invoke/wait timing column.")
        var noTimings: Bool = false

        @Flag(name: .long, help: "Hide @file:line source-range suffixes.")
        var noSources: Bool = false

        func run() throws {
            let jsonl: String
            if let path = input {
                let url = URL(fileURLWithPath: path).standardized
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw ValidationError("File not found: \(path)")
                }
                jsonl = try String(contentsOf: url, encoding: .utf8)
            } else {
                let data = FileHandle.standardInput.readDataToEndOfFile()
                jsonl = String(data: data, encoding: .utf8) ?? ""
            }

            let renderer = TraceTreeRenderer(options: .init(
                showSourceRanges: !noSources,
                showTimings:      !noTimings,
                unicodeGlyphs:    !ascii
            ))
            print(renderer.render(jsonl: jsonl), terminator: "")
        }
    }

    struct Verify: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "verify",
            abstract: "Verify a semantic trace store JSONL file for tampering and chain integrity."
        )

        @Argument(help: "Path to a semantic trace-store .jsonl file.")
        var input: String

        @Option(name: .customLong("run"), help: "Run ID whose semantic chain should be verified.")
        var runID: String

        @Flag(name: .long, help: "Emit a stable JSON report instead of human-readable text.")
        var json: Bool = false

        func run() throws {
            try TraceVerifyRunner.run(input: input, runID: runID, json: json)
        }
    }

    struct Eval: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "eval",
            abstract: "Replay-evaluate a trace-temporal or trace-statistical expression."
        )

        @Argument(help: "Path to a semantic trace-store .jsonl file.")
        var input: String

        @Argument(help: "Expression to evaluate against the stored trace.")
        var expression: String

        @Option(name: .customLong("at"), help: "Replay instant as an ISO8601 timestamp.")
        var instant: String

        @Option(name: [.customLong("merconfig"), .customLong("vocab")], help: "Optional merconfig file(s) used when parsing the expression.")
        var merconfig: [String] = []

        @Option(name: .customLong("format"), help: "Output format: json or text.")
        var format: TraceEvalOutputFormat = .text

        @OptionGroup var cliTrace: CLITraceOptions

        func run() async throws {
            let traceInstance = try cliTrace.makeTrace()
            try await traceInstance.run {
                try await TraceEvalRunner.run(
                    input: input,
                    expression: expression,
                    instant: instant,
                    merconfig: merconfig,
                    format: format
                )
            }
        }
    }
}
