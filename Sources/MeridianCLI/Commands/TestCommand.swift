import ArgumentParser
import Foundation
import MeridianCore

// MARK: - `meridian test`
//
// Thin CLI wrapper around `MeridianTestRunner`. Discovery, spec parsing,
// compile + assertion evaluation, and diff formatting all live in
// `MeridianCore.MeridianTestRunner` so other consumers (IDE plugins, CI
// status checks, MCP endpoints) can run the same logic without depending
// on `ArgumentParser` or stdout text formatting.
//
// All this command does is:
//   1. Take a list of paths from argv (defaulting to cwd).
//   2. Call `runner.runAll(roots:)`.
//   3. Print one status line per report; tally pass/fail/skip.
//   4. Print full failure reasons.
//   5. Exit non-zero if any report failed.

struct TestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Discover and run .meridian.test specs."
    )

    @Argument(help: "Directories or files to scan for .meridian.test specs. Defaults to cwd.")
    var paths: [String] = ["."]

    @Flag(name: .long, help: "Print full diff on golden mismatches.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Overwrite golden files with current output instead of failing.")
    var updateGolden: Bool = false

    @Flag(name: .long, help: "Suppress individual success lines; only print summary.")
    var quiet: Bool = false

    @Option(name: .long, help: "Run only specs that carry this tag. Repeatable.")
    var tag: [String] = []

    @Option(name: .long, help: "Run only specs whose name contains this string (case-insensitive).")
    var filter: String? = nil

    func run() throws {
        let runner = MeridianTestRunner(
            verbose:      verbose,
            updateGolden: updateGolden,
            tagFilter:    tag,
            nameFilter:   filter
        )

        let roots   = paths.map { URL(fileURLWithPath: $0).standardized }
        let reports = runner.runAll(roots: roots)

        if reports.isEmpty {
            FileHandle.standardError.write(Data("no .meridian.test files found\n".utf8))
            throw ExitCode(1)
        }

        var passed   = 0
        var failed   = 0
        var skipped  = 0
        var failures: [(name: String, reasons: [String])] = []

        for report in reports {
            switch report.outcome {
            case .success(let detail):
                passed += 1
                if !quiet {
                    print("✓ \(report.spec.displayName)\(detail.isEmpty ? "" : "  — \(detail)")")
                }

            case .failure(let reasons):
                failed += 1
                failures.append((name: report.spec.displayName, reasons: reasons))
                print("✗ \(report.spec.displayName)")

            case .skipped(let reason):
                skipped += 1
                if !quiet {
                    let suffix = reason.map { " — \($0)" } ?? ""
                    print("⊘ \(report.spec.displayName)\(suffix)")
                }
            }
        }

        print("")
        let total = passed + failed + skipped
        let summary: String
        if skipped > 0 {
            summary = "\(total) tests, \(passed) passed, \(failed) failed, \(skipped) skipped"
        } else {
            summary = "\(total) tests, \(passed) passed, \(failed) failed"
        }
        print(summary)

        if !failures.isEmpty {
            print("")
            for (name, reasons) in failures {
                print("--- \(name) ---")
                for reason in reasons {
                    print(reason)
                }
                print("")
            }
            throw ExitCode(1)
        }
    }
}
