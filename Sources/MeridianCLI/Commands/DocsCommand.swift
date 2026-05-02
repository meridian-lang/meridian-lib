import ArgumentParser
import Foundation
import MeridianCore

// MARK: - `meridian docs`
//
// Renders one or more `.merconfig` files into a static HTML reference
// document. The output is a single self-contained file (inline CSS, no
// JS, no external assets) that a CI job can publish and a developer can
// open directly from disk.

struct DocsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "docs",
        abstract: "Render .merconfig files to a static HTML reference."
    )

    @Argument(help: "Paths to .merconfig files to document.")
    var inputs: [String]

    @Option(name: .shortAndLong, help: "Output HTML file. Defaults to stdout.")
    var output: String?

    @Option(name: .long, help: "Page title shown in the rendered HTML.")
    var title: String = "Meridian vocabulary"

    func run() throws {
        guard !inputs.isEmpty else {
            throw ValidationError("at least one .merconfig path is required")
        }

        var configs: [(name: String, config: MerConfigFile)] = []
        for path in inputs {
            let url = URL(fileURLWithPath: path).standardized
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ValidationError("File not found: \(path)")
            }
            let src = try String(contentsOf: url, encoding: .utf8)
            // Pure-string parser; doesn't need a Compiler instance, doesn't
            // mutate any shared state, doesn't fail if vocab is empty.
            let parser = MerConfigParser()
            let parsed = try parser.parse(src, file: url.lastPathComponent)
            configs.append((name: url.lastPathComponent, config: parsed))
        }

        let renderer = MerconfigDocsRenderer(options: .init(pageTitle: title))
        let html: String = (configs.count == 1)
            ? renderer.render(configs[0].config)
            : renderer.render(configs)

        if let path = output {
            let url = URL(fileURLWithPath: path).standardized
            try html.write(to: url, atomically: true, encoding: .utf8)
            print("✓ wrote \(path)")
        } else {
            print(html)
        }
    }
}
