import Foundation

/// Throwaway directory under the system temp root, removed on `deinit`.
/// Duplicated across slow-integration files because SwiftPM test targets cannot
/// share source files.
final class SlowTempDir {
    let url: URL
    init(prefix: String = "meridian-slow-tests") {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    @discardableResult
    func write(_ name: String, _ contents: String) -> URL {
        let dest = url.appendingPathComponent(name)
        try? FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? contents.write(to: dest, atomically: true, encoding: .utf8)
        return dest
    }

    func path(_ name: String) -> String { url.appendingPathComponent(name).path }
}

import MeridianTestKit

let slowRepoRoot = SwiftTypecheckSupport.packageRoot(from: #file)

func slowLocateMeridianBinary() throws -> URL {
    try MeridianCLIProcessSupport.locateBinary(packageRoot: slowRepoRoot)
}

func slowRunMeridian(_ binary: URL, _ arguments: [String]) throws -> MeridianCLIProcessResult {
    try MeridianCLIProcessSupport.run(
        binary: binary,
        arguments: arguments,
        workingDirectory: slowRepoRoot
    )
}
