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
    /// Test-only fault injection (instance-scoped — never process env vars).
    var forceTempdirFailure: Bool = false
    var forceScaffoldFailure: Bool = false

    /// Prefix for the sentinel stdout line carrying the final `reason`
    /// payload string (never a real event-kind line, so it can be filtered
    /// out of `eventKinds` unambiguously). Only printed when the run's final
    /// completion/failure event actually carries a non-nil string reason.
    private static let finalReasonSentinel = "__MERIDIAN_FINAL_REASON__:"
    /// Prefix for the sentinel stdout line carrying a specific final binding's
    /// `Value.scalarDescription`, printed only when `spec.expectFinalBindingContains`
    /// names a key. Same "won't collide with a real event-kind line" reasoning
    /// as `finalReasonSentinel`.
    private static let finalBindingSentinel = "__MERIDIAN_FINAL_BINDING__:"

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
            package = try SwiftPMPackageRunner.temporary(
                prefix: "meridian-test",
                forceTempdirFailure: forceTempdirFailure
            )
        } catch {
            return ["failed to create tempdir: \(error)"]
        }
        defer { try? package.remove() }

        do {
            try package.writePackage(
                manifest: PackageManifestBuilder.meridianRunDriverPackageManifest(
                    repoRoot: repoRoot,
                    includeMeridianTools: false
                ),
                files: [
                    .init(relativePath: "Sources/GeneratedWorkflow/Generated.swift", contents: swiftSource),
                    .init(relativePath: "Sources/Driver/Driver.swift", contents: driverSource(workflow: workflow, spec: spec))
                ],
                forceScaffoldFailure: forceScaffoldFailure
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

        // Parse event kinds from JSONL output (one kind per line). The final
        // completion/failure reason (if any) rides on a separate sentinel-
        // prefixed line so it can't be confused with a real event kind.
        var finalReason: String?
        var finalBinding: String?
        let eventKinds = output
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { line -> String? in
                if line.hasPrefix(Self.finalReasonSentinel) {
                    finalReason = String(line.dropFirst(Self.finalReasonSentinel.count))
                    return nil
                }
                if line.hasPrefix(Self.finalBindingSentinel) {
                    finalBinding = String(line.dropFirst(Self.finalBindingSentinel.count))
                    return nil
                }
                return line
            }

        return evaluateRuntimeAssertions(spec: spec, eventKinds: eventKinds, finalReason: finalReason, finalBinding: finalBinding)
    }

    /// Generate the driver Swift source that runs `workflow` with the given stubs/inputs.
    private func driverSource(workflow: IRWorkflow, spec: MeridianTestRunner.RuntimeSpec) -> String {
        DriverSourceBuilder.driver(spec: DriverSourceBuilder.DriverSpec(
            shell: .detachedTask,
            sectionSpacing: true,
            moneyCoercion: true,
            observerExpr: "InMemoryObserver()",
            checkpointRootExpr: "InMemoryCheckpointer()",
            runID: "test-run",
            workflowStructName: workflow.structName,
            hasTraceConfiguration: workflow.runtimeTraceConfiguration != nil,
            parameters: workflow.parameters.map { ($0.name, $0.kind.name) },
            inputs: spec.inputs.map { ($0.paramName, $0.json) },
            toolStubs: spec.toolStubs.map { ($0.toolID, $0.json) },
            reporting: .init(
                finalReasonSentinel: Self.finalReasonSentinel,
                finalBindingSentinel: Self.finalBindingSentinel,
                finalBindingKey: spec.expectFinalBindingContains?.key
            ),
            indent: "    "
        ))
    }

    // MARK: - Runtime assertion evaluation

    private func evaluateRuntimeAssertions(
        spec: MeridianTestRunner.RuntimeSpec,
        eventKinds: [String],
        finalReason: String? = nil,
        finalBinding: String? = nil
    ) -> [String] {
        var failures: [String] = []

        if let expectedReason = spec.expectFinalReason, expectedReason != finalReason {
            failures.append("expected final reason '\(expectedReason)', got '\(finalReason ?? "(none)")'")
        }

        if let expectBinding = spec.expectFinalBindingContains {
            let actual = finalBinding ?? ""
            if !actual.contains(expectBinding.substring) {
                failures.append("expected binding '\(expectBinding.key)' to contain '\(expectBinding.substring)', got '\(actual)'")
            }
        }

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

}
