// MeridianCLI — command-line tool entry point.
// Full implementation in Phase 3 (compile) and Phase 6 (all subcommands).

import ArgumentParser
import MeridianCLIKit

@main
struct MeridianCLI: AsyncParsableCommand {
    // Leaf paths and registration order are validated against `MeridianCommandCatalog`
    // in `CLICommandCatalogTests`.
    static let configuration = CommandConfiguration(
        commandName: "meridian",
        abstract: "Compiler and runtime tools for the Meridian language.",
        version: "0.1.0-alpha",
        subcommands: MeridianCLIRegistration.topLevelCommands
    )
}
