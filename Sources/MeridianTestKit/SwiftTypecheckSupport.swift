import Foundation

public struct SwiftTypecheckArtifacts: Sendable {
    public let modulesDir: URL
    public let buildPath: URL
}

public enum SwiftTypecheckSupport {
    public static func packageRoot(from file: String = #file) -> URL {
        var url = URL(fileURLWithPath: file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url
    }

    public static func locateArtifacts(packageRoot: URL) throws -> SwiftTypecheckArtifacts {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["swift", "build", "--show-bin-path"]
        proc.currentDirectoryURL = packageRoot
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let bin = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard proc.terminationStatus == 0, !bin.isEmpty else {
            throw SwiftTypecheckError.locateArtifactsFailed(output: bin)
        }
        let buildPath = URL(fileURLWithPath: bin)
        return SwiftTypecheckArtifacts(
            modulesDir: buildPath.appendingPathComponent("Modules"),
            buildPath: buildPath
        )
    }

    public static func typecheck(file: URL, artifacts: SwiftTypecheckArtifacts) -> (ok: Bool, message: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = [
            "swiftc", "-typecheck",
            "-I", artifacts.modulesDir.path,
            "-I", artifacts.buildPath.path,
            "-L", artifacts.buildPath.path,
            "-lMeridianRuntime",
            file.path,
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        do {
            try proc.run()
        } catch {
            return (false, "failed to spawn swiftc: \(error)")
        }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (proc.terminationStatus == 0, output)
    }
}

public enum SwiftTypecheckError: Error, CustomStringConvertible {
    case locateArtifactsFailed(output: String)

    public var description: String {
        switch self {
        case .locateArtifactsFailed(let output):
            return "swift build --show-bin-path failed: \(output)"
        }
    }
}
