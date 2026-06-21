import Foundation

public final class SwiftPMPackageRunner {
    public struct MeridianRunDriverOptions: Sendable {
        public let inputJSON: [String]
        public let toolStubs: [String]
        public let runID: String
        public let checkpointRoot: String?

        public init(
            inputJSON: [String] = [],
            toolStubs: [String] = [],
            runID: String = "cli-run",
            checkpointRoot: String? = nil
        ) {
            self.inputJSON = inputJSON
            self.toolStubs = toolStubs
            self.runID = runID
            self.checkpointRoot = checkpointRoot
        }
    }

    public struct SourceFile: Sendable {
        public let relativePath: String
        public let contents: String

        public init(relativePath: String, contents: String) {
            self.relativePath = relativePath
            self.contents = contents
        }
    }

    public struct ProcessResult: Sendable {
        public let stdout: String
        public let stderr: String
        public let exitCode: Int32

        public var combinedOutput: String {
            [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
        }

        public init(stdout: String, stderr: String, exitCode: Int32) {
            self.stdout = stdout
            self.stderr = stderr
            self.exitCode = exitCode
        }

        public func requireSuccess(_ command: [String]) throws -> ProcessResult {
            guard exitCode == 0 else {
                let text = combinedOutput.isEmpty ? "exit code \(exitCode)" : combinedOutput
                throw SwiftPMPackageRunnerError.processFailed(command: command, output: text)
            }
            return self
        }
    }

    public let packageURL: URL

    public init(packageURL: URL) {
        self.packageURL = packageURL.standardizedFileURL
    }

    public static func temporary(prefix: String = "meridian-swiftpm") throws -> SwiftPMPackageRunner {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return SwiftPMPackageRunner(packageURL: url)
    }

    public func writePackage(manifest: String, files: [SourceFile]) throws {
        try writeFile("Package.swift", contents: manifest)
        for file in files {
            try writeFile(file.relativePath, contents: file.contents)
        }
    }

    public func writeMeridianRunDriverPackage(
        repoRoot: URL,
        generatedSource: String,
        workflow: IRWorkflow,
        options: MeridianRunDriverOptions = .init()
    ) throws {
        try writePackage(
            manifest: meridianRunPackageManifest(repoRoot: repoRoot),
            files: [
                .init(relativePath: "Sources/GeneratedWorkflow/Generated.swift", contents: generatedSource),
                .init(relativePath: "Sources/Driver/Driver.swift", contents: try meridianRunDriverSource(
                    workflow: workflow,
                    options: options
                ))
            ]
        )
    }

    public func writeFile(_ relativePath: String, contents: String) throws {
        let url = packageURL.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    public func readFile(_ relativePath: String) throws -> String {
        try String(
            contentsOf: packageURL.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    public func remove() throws {
        if FileManager.default.fileExists(atPath: packageURL.path) {
            try FileManager.default.removeItem(at: packageURL)
        }
    }

    @discardableResult
    public func build(configuration: String = "debug") throws -> ProcessResult {
        let command = ["swift", "build", "-c", configuration, "--package-path", packageURL.path]
        return try runProcess(command).requireSuccess(command)
    }

    @discardableResult
    public func run(executable: String, arguments: [String] = []) throws -> ProcessResult {
        let command = ["swift", "run", "--package-path", packageURL.path, executable] + arguments
        return try runProcess(command).requireSuccess(command)
    }

    @discardableResult
    public func runProcess(_ arguments: [String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw SwiftPMPackageRunnerError.launchFailed(command: arguments, underlying: error)
        }

        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }

    private func meridianRunPackageManifest(repoRoot: URL) -> String {
        let packageIdentity = repoRoot.lastPathComponent
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
                        .product(name: "MeridianRuntime", package: "\(packageIdentity)"),
                        .product(name: "MeridianTools", package: "\(packageIdentity)")
                    ],
                    path: "Sources/Driver"
                )
            ],
            swiftLanguageModes: [.v5]
        )
        """
    }

    private func meridianRunDriverSource(
        workflow: IRWorkflow,
        options: MeridianRunDriverOptions
    ) throws -> String {
        var lines: [String] = [
            "import Foundation",
            "import MeridianRuntime",
            "import MeridianTools",
            "import GeneratedWorkflow",
            "",
        ]
        lines.append(contentsOf: DriverSourceBuilder.jsonBridge(includeMoneyCoercion: false))
        lines.append(contentsOf: [
            "",
            "@main",
            "struct Driver {",
            "    static func main() async throws {",
            "        let registry = ToolRegistry()",
            "        await registry.registerBuiltins()"
        ])

        for pair in try parseAssignments(options.toolStubs, option: "--tool-stub") {
            lines.append(contentsOf: DriverSourceBuilder.toolStub(name: pair.name, json: pair.json, indent: "        "))
        }

        let checkpointRootExpr: String
        if let checkpointRoot = options.checkpointRoot {
            checkpointRootExpr = "try FilesystemCheckpointer(rootURL: URL(fileURLWithPath: \"\(escapeSwiftStringLiteral(checkpointRoot))\"))"
        } else {
            checkpointRootExpr = "InMemoryCheckpointer()"
        }

        lines.append(contentsOf: [
            "        let observer = JSONLObserver.stdout",
            "        let runtime = Runtime(toolRegistry: registry, observer: observer, checkpointer: \(checkpointRootExpr), runID: \"\(escapeSwiftStringLiteral(options.runID))\")"
        ])

        let inputs = try parseAssignments(options.inputJSON, option: "--input-json")
        let inputsByName = Dictionary(inputs.map { ($0.name, $0.json) }, uniquingKeysWith: { _, new in new })
        for param in workflow.parameters {
            let swiftType = IdentifierNaming.pascalCase(param.kind.name)
            let json = inputsByName[param.name] ?? "{}"
            lines.append(contentsOf: DriverSourceBuilder.paramDecode(
                name: param.name, swiftType: swiftType, json: json, indent: "        ", force: true))
        }

        let params = (["runtime: runtime"] + workflow.parameters.map { "\($0.name): \($0.name)" }).joined(separator: ", ")
        lines.append(contentsOf: [
            "        _ = try await \(workflow.structName)(\(params)).run()",
            "    }",
            "}"
        ])
        return lines.joined(separator: "\n") + "\n"
    }

    private func parseAssignments(_ raw: [String], option: String) throws -> [(name: String, json: String)] {
        try raw.map { item in
            guard let eq = item.firstIndex(of: "=") else {
                throw SwiftPMPackageRunnerError.invalidOption("\(option) must be name=JSON, got: \(item)")
            }
            let name = String(item[..<eq]).trimmingCharacters(in: .whitespaces)
            let json = String(item[item.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !json.isEmpty else {
                throw SwiftPMPackageRunnerError.invalidOption("\(option) must be name=JSON, got: \(item)")
            }
            return (name, json)
        }
    }

}

public enum SwiftPMPackageRunnerError: Error, CustomStringConvertible {
    case launchFailed(command: [String], underlying: any Error)
    case processFailed(command: [String], output: String)
    case invalidOption(String)

    public var description: String {
        switch self {
        case .launchFailed(let command, let underlying):
            "could not launch \(command.joined(separator: " ")): \(underlying)"
        case .processFailed(let command, let output):
            "process failed: \(command.joined(separator: " "))\n\(output)"
        case .invalidOption(let message):
            message
        }
    }
}
