import ArgumentParser
import Foundation
import MeridianRuntime

// MARK: - `meridian trace render`
//
// Read a JSONL event stream (file or stdin) and print it as an indented
// tree using `TraceTreeRenderer`. The point is to make a long, dense
// `events.jsonl` digestible at a glance — useful when triaging a failed
// CI run or a flaky integration test.

struct TraceRenderCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trace",
        abstract: "Pretty-print a Meridian JSONL event stream as a tree.",
        subcommands: [Render.self],
        defaultSubcommand: Render.self
    )

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
}
