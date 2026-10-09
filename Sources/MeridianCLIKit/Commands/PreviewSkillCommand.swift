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

    @OptionGroup var cliTrace: CLITraceOptions

    public func run() throws {
        guard FileManager.default.fileExists(atPath: input) else {
            throw cliInputNotFound(input)
        }
        let markdown = try String(contentsOfFile: input, encoding: .utf8)
        let traceInstance = try cliTrace.makeTrace()
        print(traceInstance.run { SkillMarkdownImporter().preview(markdown, name: name) })
    }
}
