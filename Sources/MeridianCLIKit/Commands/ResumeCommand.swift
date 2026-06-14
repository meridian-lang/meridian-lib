import ArgumentParser
import Foundation
import MeridianRuntime

public struct ResumeCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "resume",
        abstract: "Load the latest checkpoint for a run and print the restored context."
    )

    @Argument(help: "Run ID to resume.")
    var runID: String

    @Option(name: .long, help: "Checkpoint root directory.")
    var checkpointRoot: String?

    public func run() async throws {
        let rootURL: URL
        if let checkpointRoot {
            rootURL = URL(fileURLWithPath: checkpointRoot).standardizedFileURL
        } else {
            rootURL = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("meridian-checkpoints", isDirectory: true)
        }

        let checkpointer = try FilesystemCheckpointer(rootURL: rootURL)
        let runtime = Runtime(toolRegistry: ToolRegistry(), checkpointer: checkpointer, runID: runID)
        let context = try await runtime.prepareResume(runID: runID)

        let payload: [String: Any] = [
            "run_id": context.runID,
            "last_checkpoint_label": context.lastCheckpointLabel as Any,
            "bindings": context.restoredState.asValues.mapValues { String(describing: $0) }
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
