import ArgumentParser
import Foundation
import MeridianCore

public struct GrammarDocCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "grammar-doc",
        abstract: "Emit a markdown reference for Meridian's canonical surface grammar."
    )

    public func run() throws {
        print(Self.markdown())
    }

    static func markdown() -> String {
        """
        # Meridian Grammar Reference

        Canonical forms are the deterministic surfaces Meridian emits when it verbalizes lowered IR back to source. They are meant to be stable audit targets, not the only authored phrasing accepted by the parser.

        \(GrammarDocumentation.markdownReference())
        """
    }
}
