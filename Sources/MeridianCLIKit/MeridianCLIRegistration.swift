import ArgumentParser

/// Top-level `meridian` subcommand registration shared by the CLI entry point and tests.
public enum MeridianCLIRegistration {
    public static let topLevelCommands: [any ParsableCommand.Type] = [
        CanonicalizeCommand.self,
        MCPCommand.self,
        CompileCommand.self,
        ExplainCommand.self,
        ExplainSwiftCommand.self,
        DriftCommand.self,
        GrammarDocCommand.self,
        LintCommand.self,
        PreviewSkillCommand.self,
        MigrateSkillCommand.self,
        SkillDeviationCommand.self,
        InertYieldCommand.self,
        CheckCommand.self,
        FormatCommand.self,
        DocsCommand.self,
        TestCommand.self,
        TraceRenderCommand.self,
        TraceEvalCommand.self,
        TraceVerifyCommand.self,
        RunCommand.self,
        VerifyCommand.self,
        ResumeCommand.self,
        ExplainDiagCommand.self,
        DecisionsCommand.self,
        BenchParseCommand.self,
        BenchTraceCommand.self,
    ]

    public static var topLevelCommandNames: [String] {
        topLevelCommands.map { displayName(commandName: $0.configuration.commandName) }
    }

    /// Maps an ArgumentParser `commandName` to the catalog/docs spelling.
    /// Exposed for tests so the nil fallback stays reachable in-process.
    public static func displayName(commandName: String?) -> String {
        commandName ?? "<unnamed>"
    }
}
