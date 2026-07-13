// swift-tools-version: 6.2
//
// Meridian — controlled natural language compiler and runtime.
//
// Products:
//   MeridianCore     — compiler (parser, IR, codegen)
//   MeridianRuntime  — runtime library consumed by emitted Swift
//   MeridianTools    — built-in tool implementations (opt-in)
//   MeridianTestKit  — test helpers
//   meridian         — CLI executable
//   MeridianMCP      — MCP server executable (stdio JSON-RPC)
//
// See docs/02_ARCHITECTURE.md and AGENTS.md for the full layout.

import PackageDescription

let package = Package(
    name: "meridian",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MeridianCore", targets: ["MeridianCore"]),
        .library(name: "MeridianRuntime", targets: ["MeridianRuntime"]),
        .library(name: "MeridianTools", targets: ["MeridianTools"]),
        .library(name: "MeridianTestKit", targets: ["MeridianTestKit"]),
        .executable(name: "meridian", targets: ["MeridianCLI"]),
        .executable(name: "MeridianMCP", targets: ["MeridianMCP"]),
        .executable(name: "order-processing-handwritten", targets: ["OrderProcessingDemo"])
    ],
    dependencies: [
        // Parser combinators — foundation for PegexBuilder
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.14.1"),

        // PegexBuilder — custom DSL on top of swift-parsing
        .package(url: "https://github.com/modelhike/pegex.git", branch: "main"),

        // CLI argument parsing
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),

        // Subprocess management for CLI run/test and integration drivers
        .package(url: "https://github.com/swiftlang/swift-subprocess", branch: "main"),

        // Code formatting for emitted Swift
        .package(url: "https://github.com/apple/swift-format", from: "601.0.0"),

        // Ordered collections for symbol tables
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.0"),

        // DocC plugin so `swift package generate-documentation
        // --target MeridianRuntime` (and ditto for MeridianCore) builds
        // the .docc bundles that live next to those targets' sources.
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0")
    ],
    targets: [

        // MARK: - MeridianRuntime — runtime library
        .target(
            name: "MeridianRuntime",
            dependencies: [],
            path: "Sources/MeridianRuntime",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),

        // MARK: - MeridianCore — compiler (parser, IR, lowering, codegen)
        .target(
            name: "MeridianCore",
            dependencies: [
                "MeridianRuntime",
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "PegexBuilder", package: "pegex"),
                .product(name: "Collections", package: "swift-collections"),
            ],
            path: "Sources/MeridianCore"
        ),

        // MARK: - MeridianTools — built-in tool implementations
        .target(
            name: "MeridianTools",
            dependencies: ["MeridianRuntime"],
            path: "Sources/MeridianTools"
        ),

        // MARK: - MeridianCLIKit — CLI command library
        // Holds every subcommand body + shared CLI support so the logic is
        // unit-testable in-process (an executable target's symbols can't be
        // imported by a test target). `MeridianCLI` is a thin @main shell.
        .target(
            name: "MeridianCLIKit",
            dependencies: [
                "MeridianCore",
                "MeridianRuntime",
                "MeridianTools",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftFormat", package: "swift-format")
            ],
            path: "Sources/MeridianCLIKit"
        ),

        // MARK: - MeridianCLI — meridian executable
        .executableTarget(
            name: "MeridianCLI",
            dependencies: [
                "MeridianCLIKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/MeridianCLI"
        ),

        // MARK: - MeridianMCP — standalone MCP server executable
        .executableTarget(
            name: "MeridianMCP",
            dependencies: ["MeridianCLIKit"],
            path: "Sources/MeridianMCP"
        ),

        // MARK: - MeridianTestKit — test helpers
        .target(
            name: "MeridianTestKit",
            dependencies: ["MeridianRuntime"],
            path: "Sources/MeridianTestKit"
        ),

        // MARK: - SampleDemoFlows — hand-written reference workflows
        // EcommerceWorkflows: domain types + workflow structs (library).
        // OrderProcessingDemo: driver executable for the order-processing forcing function.
        // GeneratedOrderProcessing: committed compiler-generated Swift for golden round-trip tests.
        .target(
            name: "EcommerceWorkflows",
            dependencies: ["MeridianRuntime"],
            path: "Sources/SampleDemoFlows/EcommerceWorkflows"
        ),

        // MARK: - OrderProcessingDemo — order-processing forcing-function executable
        .executableTarget(
            name: "OrderProcessingDemo",
            dependencies: ["MeridianRuntime", "MeridianTestKit", "EcommerceWorkflows"],
            path: "Sources/SampleDemoFlows/OrderProcessingDemo"
        ),

        // MARK: - GeneratedOrderProcessing — committed compiler output for round-trip tests
        .target(
            name: "GeneratedOrderProcessing",
            dependencies: ["MeridianRuntime"],
            path: "Sources/SampleDemoFlows/GeneratedOrderProcessing"
        ),

        // MARK: - Test targets
        .testTarget(
            name: "MeridianCoreTests",
            dependencies: ["MeridianCore", "MeridianTestKit"],
            path: "Tests/MeridianCoreTests",
            resources: [
                .copy("Fixtures"),
                .copy("MeridianTestSpecs"),
            ]
        ),
        .testTarget(
            name: "MeridianRuntimeTests",
            dependencies: ["MeridianRuntime", "MeridianTestKit"],
            path: "Tests/MeridianRuntimeTests"
        ),
        .testTarget(
            name: "MeridianToolsTests",
            dependencies: ["MeridianTools", "MeridianTestKit", "MeridianCore"],
            path: "Tests/MeridianToolsTests"
        ),
        .testTarget(
            name: "MeridianCLITests",
            dependencies: ["MeridianCLIKit", "MeridianCore", "MeridianRuntime", "MeridianTools"],
            path: "Tests/MeridianCLITests"
        ),
        .testTarget(
            name: "MeridianMCPTests",
            dependencies: ["MeridianCLIKit"],
            path: "Tests/MeridianMCPTests"
        ),
        // End-to-end CLI coverage also lives in MeridianIntegrationTests,
        // MeridianSlowIntegrationTests, and `meridian test` over examples/.
        .testTarget(
            name: "MeridianIntegrationTests",
            dependencies: [
                "MeridianCore",
                "MeridianRuntime",
                "MeridianTools",
                "MeridianTestKit",
                "EcommerceWorkflows",
                "GeneratedOrderProcessing"
            ],
            path: "Tests/MeridianIntegrationTests",
            resources: [.copy("Fixtures")]
        ),

        // MARK: - SampleGbrainTests — the ported gbrain corpus lives under
        // sample-gbrain/, and its tests live alongside it (not in
        // MeridianCoreTests) so the whole skillpack is self-contained: vocab,
        // rulebook, skills, original SKILL.md sources, deviation notes,
        // compiled outputs, and the tests that gate them. The codegen test
        // additionally validates that every emitted Swift file is syntactically
        // well-formed and (opt-in) type-checks against MeridianRuntime.
        .testTarget(
            name: "SampleGbrainTests",
            dependencies: ["MeridianCore", "MeridianRuntime"],
            path: "sample-gbrain/Tests"
        ),
        .testTarget(
            name: "CorporaTests",
            dependencies: ["MeridianCore", "MeridianRuntime"],
            path: "Tests/CorporaTests"
        ),

        // MARK: - MeridianSlowIntegrationTests — tests that spawn a *live external
        // process*: `swift build`/`swift run` through a temporary SwiftPM package,
        // subprocess-executing CLI specs, `swiftc -typecheck` over generated Swift,
        // and process-level `meridian` binary E2E checks. These dominate wall-clock
        // time (minutes, not seconds) versus every other in-process test target.
        // Kept as a separate target so `swift test --skip MeridianSlowIntegrationTests`
        // gives a fast inner loop; the full local gate (and CI) still runs it via
        // plain `swift test`. See Tests/README.md.
        .testTarget(
            name: "MeridianSlowIntegrationTests",
            dependencies: ["MeridianCLIKit", "MeridianCore", "MeridianRuntime", "MeridianTestKit"],
            path: "Tests/MeridianSlowIntegrationTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
