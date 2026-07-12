import Foundation

public struct MeridianCLIProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
}

public enum MeridianCLIProcessSupport {
    public static func locateBinary(
        packageRoot: URL,
        product: String = "meridian"
    ) throws -> URL {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        proc.arguments = ["swift", "build", "--product", product, "--show-bin-path"]
        proc.currentDirectoryURL = packageRoot
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let binPath = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard proc.terminationStatus == 0, !binPath.isEmpty else {
            throw MeridianCLIProcessError.locateBinaryFailed(output: binPath)
        }
        let url = URL(fileURLWithPath: binPath).appendingPathComponent(product)
        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw MeridianCLIProcessError.missingBinary(path: url.path)
        }
        return url
    }

    public static func run(
        binary: URL,
        arguments: [String],
        workingDirectory: URL
    ) throws -> MeridianCLIProcessResult {
        let proc = Process()
        proc.executableURL = binary
        proc.arguments = arguments
        proc.currentDirectoryURL = workingDirectory
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        try proc.run()
        proc.waitUntilExit()
        return MeridianCLIProcessResult(
            exitCode: proc.terminationStatus,
            stdout: String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }
}

public enum MeridianCLIProcessError: Error, CustomStringConvertible {
    case locateBinaryFailed(output: String)
    case missingBinary(path: String)

    public var description: String {
        switch self {
        case .locateBinaryFailed(let output):
            return "swift build --show-bin-path failed: \(output)"
        case .missingBinary(let path):
            return "missing executable at \(path)"
        }
    }
}
