import ArgumentParser
import Foundation
import MeridianCore

struct PreviewSkillCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preview-skill",
        abstract: "Preview a SKILL.md file as Meridian surface syntax."
    )

    @Argument(help: "Path to a SKILL.md file.")
    var input: String

    @Option(help: "Name to place in generated frontmatter.")
    var name: String = "imported skill"

    func run() throws {
        let markdown = try String(contentsOfFile: input, encoding: .utf8)
        print(SkillMarkdownImporter().preview(markdown, name: name))
    }
}
