// MeridianCLI — command-line tool entry point.
// Full implementation in Phase 3 (compile) and Phase 6 (all subcommands).

import ArgumentParser
import MeridianCore
import MeridianRuntime
import MeridianTools

@main
struct MeridianCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "meridian",
        abstract: "Compiler and runtime tools for the Meridian language.",
        version: "0.1.0-alpha",
        subcommands: [
            CompileCommand.self,
            LintCommand.self,
            PreviewSkillCommand.self,
            MigrateSkillCommand.self,
            SkillDeviationCommand.self,
            CheckCommand.self,
            FormatCommand.self,
            DocsCommand.self,
            TestCommand.self,
            TraceRenderCommand.self,
            RunCommand.self,
            VerifyCommand.self,
            ResumeCommand.self,
            ExplainCommand.self,
            DecisionsCommand.self
        ]
    )
}
