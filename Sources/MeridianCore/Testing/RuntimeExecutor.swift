import Foundation

// MARK: - RuntimeExecutor

/// Runs a compiled workflow in a subprocess using a tempdir SwiftPM package.
///
/// Flow:
///   1. Scaffold a tempdir `Package.swift` that depends on the meridian repo.
///   2. Write `Sources/GeneratedWorkflow/Generated.swift` with the compiler output.
///   3. Write `Sources/Driver/Driver.swift` that decodes inputs, stubs tools,
///      runs the workflow, and prints event kinds as JSONL to stdout.
///   4. `swift build -c debug` the package.
///   5. `swift run Driver` and parse the event kind JSONL.
///   6. Evaluate runtime assertions.
///
/// Returns a list of failure reasons (empty means all assertions passed).
struct RuntimeExecutor {

    let verbose: Bool

    func run(
        spec: MeridianTestRunner.RuntimeSpec,
        swiftSource: String,
        workflows: [IRWorkflow],
        repoRoot: URL
    ) -> [String] {
        guard swiftAvailable() else {
            return ["expect_run requires swift toolchain on PATH"]
        }

        // Pick the workflow to run: explicit name or first workflow.
        let targetWorkflow: IRWorkflow?
        if let name = spec.workflowName {
            targetWorkflow = workflows.first(where: { $0.structName == name })
            if targetWorkflow == nil {
                return ["workflow '\(name)' not found in compiled output (available: \(workflows.map(\.structName).joined(separator: ", ")))"]
            }
        } else {
            targetWorkflow = workflows.first
        }

        guard let workflow = targetWorkflow else {
            return ["no workflows in compiled output to run"]
        }

        let package: SwiftPMPackageRunner
        do {
            package = try SwiftPMPackageRunner.temporary(prefix: "meridian-test")
        } catch {
            return ["failed to create tempdir: \(error)"]
        }
        defer { try? package.remove() }

        do {
            try package.writePackage(
                manifest: packageManifest(repoRoot: repoRoot),
                files: [
                    .init(relativePath: "Sources/GeneratedWorkflow/Generated.swift", contents: swiftSource),
                    .init(relativePath: "Sources/Driver/Driver.swift", contents: driverSource(workflow: workflow, spec: spec))
                ]
            )
        } catch {
            return ["failed to scaffold package: \(error)"]
        }

        do {
            try package.build()
        } catch {
            let msg = verbose ? String(describing: error) : String(String(describing: error).prefix(500))
            return ["swift build failed:\n\(msg)"]
        }

        let output: String
        do {
            output = try package.run(executable: "Driver").stdout
        } catch {
            let msg = verbose ? String(describing: error) : String(String(describing: error).prefix(500))
            return ["swift run failed:\n\(msg)"]
        }

        // Parse event kinds from JSONL output (one kind per line)
        let eventKinds = output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return evaluateRuntimeAssertions(spec: spec, eventKinds: eventKinds)
    }

    // MARK: - Package scaffolding

    private func packageManifest(repoRoot: URL) -> String {
        """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "MeridianTestDriver",
            platforms: [.macOS(.v14)],
            dependencies: [
                .package(path: \"\(repoRoot.path)\")
            ],
            targets: [
                .target(
                    name: "GeneratedWorkflow",
                    dependencies: [
                        .product(name: "MeridianRuntime", package: "meridian")
                    ],
                    path: "Sources/GeneratedWorkflow"
                ),
                .executableTarget(
                    name: "Driver",
                    dependencies: [
                        "GeneratedWorkflow",
                        .product(name: "MeridianRuntime", package: "meridian")
                    ],
                    path: "Sources/Driver"
                )
            ],
            swiftLanguageModes: [.v5]
        )
        """
    }

    /// Generate the driver Swift source that runs `workflow` with the given stubs/inputs.
    private func driverSource(workflow: IRWorkflow, spec: MeridianTestRunner.RuntimeSpec) -> String {
        var lines: [String] = []
        lines.append("import Foundation")
        lines.append("import MeridianRuntime")
        lines.append("import GeneratedWorkflow")
        lines.append("")
        lines.append("// Value JSON helper")
        lines.append(contentsOf: valueJSONHelper())
        lines.append("")
        lines.append("// Entry point")
        lines.append("let _task = Task {")
        lines.append("    let registry = ToolRegistry()")

        // Register tool stubs
        for (toolID, json) in spec.toolStubs {
            lines.append(contentsOf: DriverSourceBuilder.toolStub(name: toolID, json: json, indent: "    "))
        }

        lines.append("    let observer = InMemoryObserver()")
        lines.append("    let runtime = Runtime(toolRegistry: registry, observer: observer, runID: \"test-run\")")
        lines.append("")

        // Decode inputs
        let inputsByParam = Dictionary(spec.inputs.map { ($0.paramName, $0.json) }, uniquingKeysWith: { _, new in new })
        for param in workflow.parameters {
            let swiftType = pascalCase(param.kind.name)
            let json      = inputsByParam[param.name] ?? "{}"
            lines.append(contentsOf: DriverSourceBuilder.paramDecode(
                name: param.name, swiftType: swiftType, json: json, indent: "    ", force: false))
        }

        lines.append("")
        lines.append("    do {")
        let params = (["runtime: runtime"] + workflow.parameters.map { "\($0.name): \($0.name)" }).joined(separator: ", ")
        lines.append("        _ = try await \(workflow.structName)(\(params)).run()")
        lines.append("    } catch {}")
        lines.append("")
        lines.append("    let events = await observer.events")
        lines.append("    for event in events {")
        lines.append("        print(event.kind.rawValue)")
        lines.append("    }")
        lines.append("}")
        lines.append("await _task.value")

        return lines.joined(separator: "\n") + "\n"
    }

    /// Inline Value-from-JSON helper included in the driver (avoids extra deps).
    private func valueJSONHelper() -> [String] {
        DriverSourceBuilder.jsonBridge(includeMoneyCoercion: true)
    }

    // MARK: - Runtime assertion evaluation

    private func evaluateRuntimeAssertions(
        spec: MeridianTestRunner.RuntimeSpec,
        eventKinds: [String]
    ) -> [String] {
        var failures: [String] = []

        if let expected = spec.expectEventKinds {
            if eventKinds != expected {
                failures.append("""
                expected event kinds:
                  \(expected.joined(separator: ", "))
                got:
                  \(eventKinds.isEmpty ? "(none)" : eventKinds.joined(separator: ", "))
                """)
            }
        }

        if let prefix = spec.expectEventKindsPrefix {
            let actual = Array(eventKinds.prefix(prefix.count))
            if actual != prefix {
                failures.append("""
                expected event kinds prefix:
                  \(prefix.joined(separator: ", "))
                got first \(prefix.count) event(s):
                  \(actual.isEmpty ? "(none)" : actual.joined(separator: ", "))
                """)
            }
        }

        if let final_ = spec.expectFinalEventKind {
            if eventKinds.last != final_ {
                failures.append("expected final event kind '\(final_)', got '\(eventKinds.last ?? "(none)")'")
            }
        }

        if let succeeded = spec.expectRunSucceeded {
            let didSucceed = eventKinds.last == "workflow.completed"
            if didSucceed != succeeded {
                failures.append("expected run \(succeeded ? "to succeed" : "to fail"), but it \(didSucceed ? "succeeded" : "failed")")
            }
        }

        return failures
    }

    // MARK: - Process helpers

    private func swiftAvailable() -> Bool {
        let runner = SwiftPMPackageRunner(packageURL: FileManager.default.temporaryDirectory)
        guard let result = try? runner.runProcess(["swift", "--version"]) else { return false }
        return result.exitCode == 0
    }

    private func pascalCase(_ raw: String) -> String { IdentifierNaming.pascalCase(raw) }
}
