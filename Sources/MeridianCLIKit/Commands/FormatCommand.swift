import ArgumentParser
import Foundation
import MeridianCore

// MARK: - `meridian format`
//
// Conservative whitespace-only formatter for `.meridian` and `.merconfig`
// files. Default behaviour writes formatted content back in-place. The
// `--check` flag turns the command into a CI gate: exit 1 when any file
// would have been changed, exit 0 when all files are already canonical.

public struct FormatCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "format",
        abstract: "Canonicalise the whitespace of .meridian / .merconfig sources."
    )

    @Argument(help: "Files to format. Pass `-` (or omit) to read stdin.")
    var inputs: [String] = []

    @Flag(name: .long, help: "Don't write changes; exit 1 if any file would be reformatted.")
    var check: Bool = false

    @Flag(name: .long, help: "Write the formatted result to stdout instead of in-place.")
    var stdout: Bool = false

    public func run() throws {
        let formatter = MeridianFormatter()

        if inputs.isEmpty || inputs == ["-"] {
            // stdin → stdout shortcut.
            let data = FileHandle.standardInput.readDataToEndOfFile()
            let source = String(data: data, encoding: .utf8) ?? ""
            print(formatter.format(source), terminator: "")
            return
        }

        var dirtyCount = 0
        for path in inputs {
            let url = URL(fileURLWithPath: path).standardized
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ValidationError("File not found: \(path)")
            }
            let original = try String(contentsOf: url, encoding: .utf8)
            let formatted = formatter.format(original)

            if check {
                if formatted != original {
                    dirtyCount += 1
                    FileHandle.standardError.write(
                        Data("✗ would reformat: \(path)\n".utf8)
                    )
                }
                continue
            }
            if stdout {
                print(formatted, terminator: "")
                continue
            }
            if formatted != original {
                try formatted.write(to: url, atomically: true, encoding: .utf8)
                print("✓ formatted \(path)")
            }
        }

        if check && dirtyCount > 0 { throw ExitCode(1) }
    }
}
