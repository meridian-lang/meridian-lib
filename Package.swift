// swift-tools-version: 6.2
//
// Meridian — controlled natural language compiler and runtime.
//
// Five products:
//   MeridianCore     — compiler (parser, IR, codegen)
//   MeridianRuntime  — runtime library consumed by emitted Swift
//   MeridianTools    — built-in tool implementations (opt-in)
//   MeridianTestKit  — test helpers
//   meridian         — CLI executable
//
// A future MeridianMCP executable target will sit alongside MeridianCLI,
// sharing MeridianCore + MeridianRuntime + MeridianTools unchanged.
//
// See meridian-handoff/docs/09_PROJECT_STRUCTURE.md for the full layout.

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
        .executable(name: "order-processing-handwritten", targets: ["OrderProcessingDemo"])
    ],
    dependencies: [
        // Parser combinators — foundation for PegexBuilder (needed from Week 3)
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.14.1"),

        // PegexBuilder — custom DSL on top of swift-parsing (needed from Week 3)
        .package(url: "https://github.com/modelhike/pegex.git", branch: "main"),

        // ModelHike — StringTemplate and codegen utilities for SwiftEmitter
        .package(url: "https://github.com/modelhike/modelhike-lib", branch: "main"),

        // CLI argument parsing
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),

        // Subprocess management (needed from Week 5)
        .package(url: "https://github.com/swiftlang/swift-subprocess", branch: "main"),

        // Code formatting for emitted Swift (needed from Week 3)
        .package(url: "https://github.com/apple/swift-format", from: "601.0.0"),

        // Ordered collections for symbol tables (needed from Week 3)
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.0"),

        // DocC plugin so `swift package generate-documentation
        // --target MeridianRuntime` (and ditto for MeridianCore) builds
        // the .docc bundles that live next to those targets' sources.
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.0")
    ],
    targets: [

        // MARK: - MeridianRuntime — runtime library (Week 1+)
        .target(
            name: "MeridianRuntime",
            dependencies: [],
            path: "Sources/MeridianRuntime"
        ),

        // MARK: - MeridianCore — compiler (Week 2+; parser/PegexBuilder wired Week 3)
        .target(
            name: "MeridianCore",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "PegexBuilder", package: "pegex"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "ModelHike", package: "modelhike-lib")
            ],
            path: "Sources/MeridianCore"
        ),

        // MARK: - MeridianTools — built-in tools (Week 6)
        .target(
            name: "MeridianTools",
            dependencies: ["MeridianRuntime"],
            path: "Sources/MeridianTools"
        ),

        // MARK: - MeridianCLI — meridian executable (Week 3+)
        .executableTarget(
            name: "MeridianCLI",
            dependencies: [
                "MeridianCore",
                "MeridianRuntime",
                "MeridianTools",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftFormat", package: "swift-format")
            ],
            path: "Sources/MeridianCLI"
        ),

        // MARK: - MeridianTestKit — test helpers (Week 1+)
        .target(
            name: "MeridianTestKit",
            dependencies: ["MeridianRuntime"],
            path: "Sources/MeridianTestKit"
        ),

        // MARK: - SampleDemoFlows — Phase 1 hand-written reference workflows
        // All sample/demo targets live under Sources/SampleDemoFlows/.
        // EcommerceWorkflows: domain types + workflow structs (library).
        // OrderProcessingDemo: driver executable for the Phase 1 forcing function.
        // Both targets will be replaced by compiler-generated output in Phase 3.
        .target(
            name: "EcommerceWorkflows",
            dependencies: ["MeridianRuntime"],
            path: "Sources/SampleDemoFlows/EcommerceWorkflows"
        ),

        // MARK: - OrderProcessingDemo — Week 1 forcing function executable
        .executableTarget(
            name: "OrderProcessingDemo",
            dependencies: ["MeridianRuntime", "MeridianTestKit", "EcommerceWorkflows"],
            path: "Sources/SampleDemoFlows/OrderProcessingDemo"
        ),

        // MARK: - GeneratedOrderProcessing — Phase 4 round-trip target.
        // Holds the *committed* compiler-generated Swift for the example
        // pair (examples/order_processing.meridian + examples/ecommerce.merconfig).
        // The Phase 4 round-trip test imports this target, runs the workflow
        // against canned tools, and diffs the resulting event JSONL against
        // a checked-in golden. Re-baseline by copying:
        //   examples/golden/order_processing_expected.swift
        //   → Sources/SampleDemoFlows/GeneratedOrderProcessing/OrderProcessing.swift
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
            resources: [.copy("Fixtures")]
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
        // MeridianCLI is exercised end-to-end via integration tests
        // (`Tests/MeridianIntegrationTests`) and the `examples/*.meridian.test`
        // suite run via `swift run meridian test examples/`. The dedicated
        // `Tests/MeridianCLITests` unit target was removed to silence
        // SwiftPM's empty-test-target warning until we have CLI-only unit
        // tests that are awkward to express integration-style.
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
        )
    ],
    swiftLanguageModes: [.v6]
)
