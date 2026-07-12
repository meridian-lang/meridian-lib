import ArgumentParser
import Foundation

public struct TraceDriftCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "drift",
        abstract: "Compare trace step identities between two manifests."
    )

    @Argument(help: "Baseline manifest path.")
    var baseline: String

    @Argument(help: "Candidate manifest path.")
    var candidate: String

    public func run() throws {
        let baselineManifest = try loadManifest(at: baseline)
        let candidateManifest = try loadManifest(at: candidate)

        let removed = baselineManifest.stepPaths.subtracting(candidateManifest.stepPaths).sorted()
        let added = candidateManifest.stepPaths.subtracting(baselineManifest.stepPaths).sorted()
        let versionChanged = baselineManifest.skillVersionHash != candidateManifest.skillVersionHash

        var lines: [String] = []
        lines.append("Trace drift \(removed.isEmpty && added.isEmpty && !versionChanged ? "clean" : "detected")")
        lines.append("Baseline: \(baseline)")
        lines.append("Candidate: \(candidate)")
        lines.append("Skill version hash: \(baselineManifest.skillVersionHash) -> \(candidateManifest.skillVersionHash)")
        lines.append("Removed step paths: \(removed.count)")
        for path in removed {
            lines.append("  - \(path)")
        }
        lines.append("Added step paths: \(added.count)")
        for path in added {
            lines.append("  + \(path)")
        }

        FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
        if !(removed.isEmpty && added.isEmpty && !versionChanged) {
            throw ExitCode(1)
        }
    }

    private func loadManifest(at path: String) throws -> LoadedManifest {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw ValidationError("Manifest at \(path) is not a JSON object.")
        }
        let skillVersionHash = dict["skill_version_hash"] as? String ?? "unknown"
        let workflows = dict["workflows"] as? [[String: Any]] ?? []
        let stepPaths = workflows
            .flatMap { $0["step_paths"] as? [String] ?? [] }
            .filter { !$0.isEmpty }
        return LoadedManifest(skillVersionHash: skillVersionHash, stepPaths: Set(stepPaths))
    }
}

private struct LoadedManifest {
    let skillVersionHash: String
    let stepPaths: Set<String>
}
