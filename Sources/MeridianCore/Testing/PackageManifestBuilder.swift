import Foundation

/// Emits temporary SwiftPM `Package.swift` manifests shared by workflow run
/// drivers — `RuntimeExecutor` (`.meridian.test` subprocess runner) and
/// `SwiftPMPackageRunner` (CLI `run` driver).
enum PackageManifestBuilder {

    /// Build a manifest for a temp package that depends on the meridian repo.
    /// - Parameter includeMeridianTools: when `true`, the Driver target also
    ///   links `MeridianTools` (CLI `run` registers builtins); the test runner
    ///   omits it and uses closure stubs only.
    static func meridianRunDriverPackageManifest(
        repoRoot: URL,
        includeMeridianTools: Bool
    ) -> String {
        let packageIdentity = repoRoot.lastPathComponent
        let toolsDependency = includeMeridianTools
            ? ",\n                        .product(name: \"MeridianTools\", package: \"\(packageIdentity)\")"
            : ""
        return """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "MeridianRunDriver",
            platforms: [.macOS(.v14)],
            dependencies: [
                .package(path: \"\(repoRoot.path)\")
            ],
            targets: [
                .target(
                    name: "GeneratedWorkflow",
                    dependencies: [
                        .product(name: "MeridianRuntime", package: "\(packageIdentity)")
                    ],
                    path: "Sources/GeneratedWorkflow"
                ),
                .executableTarget(
                    name: "Driver",
                    dependencies: [
                        "GeneratedWorkflow",
                        .product(name: "MeridianRuntime", package: "\(packageIdentity)")\(toolsDependency)
                    ],
                    path: "Sources/Driver"
                )
            ],
            swiftLanguageModes: [.v5]
        )
        """
    }
}
