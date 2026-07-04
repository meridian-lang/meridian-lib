// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PegexSyntaxPOC",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/modelhike/pegex.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "PegexSyntaxPOC",
            dependencies: [
                .product(name: "PegexBuilder", package: "pegex")
            ]
        )
    ]
)
