import ArgumentParser
import Foundation
import MeridianCore

public struct ExplainSwiftCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "explain-swift",
        abstract: "Explain Meridian-generated Swift using a companion .meridian.ir.json sidecar."
    )

    @Argument(help: "Path to generated Swift source.")
    var swift: String

    @Option(name: .long, help: "Path to the .meridian.ir.json sidecar. Defaults to <swift>.meridian.ir.json beside the Swift file.")
    var sidecar: String?

    public func run() throws {
        let swiftURL = URL(fileURLWithPath: swift).standardizedFileURL
        guard FileManager.default.fileExists(atPath: swiftURL.path) else {
            throw ValidationError("Swift file not found: \(swift)")
        }
        let sidecarURL: URL
        if let sidecar {
            sidecarURL = URL(fileURLWithPath: sidecar).standardizedFileURL
        } else {
            sidecarURL = swiftURL.deletingPathExtension().appendingPathExtension("meridian.ir.json")
        }
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            throw ValidationError("IR sidecar not found: \(sidecarURL.path)")
        }
        let swiftSource = try String(contentsOf: swiftURL, encoding: .utf8)
        let sidecarJSON = try String(contentsOf: sidecarURL, encoding: .utf8)
        print(try ExplainSwiftRunner.explain(swiftSource: swiftSource, sidecarJSON: sidecarJSON))
    }
}
