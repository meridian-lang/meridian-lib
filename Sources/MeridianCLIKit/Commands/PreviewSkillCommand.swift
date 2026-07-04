import ArgumentParser
import Foundation
import MeridianCore

public struct PreviewSkillCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "preview-skill",
        abstract: "Preview a SKILL.md file as Meridian surface syntax."
    )

    @Argument(help: "Path to a SKILL.md file.")
    var input: String

    @Option(help: "Name to place in generated frontmatter.")
    var name: String = "imported skill"

    @Option(name: .long,
            help: "Activate parser/lowering trace categories (comma-separated). Examples: skill, all.")
    var trace: String?

    @Option(name: .long,
            help: "Write trace output to a file instead of stderr.")
    var traceFile: String?

    public func run() throws {
        let markdown = try String(contentsOfFile: input, encoding: .utf8)
        let traceInstance = makeCLITrace(spec: trace, file: traceFile)
        print(SkillMarkdownImporter(trace: traceInstance).preview(markdown, name: name))
    }
}
