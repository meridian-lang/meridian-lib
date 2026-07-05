import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - MeridianTestRunner gaps

@Suite("MeridianTestRunner — uncovered error and reporting paths")
struct MeridianTestRunnerExtendedCoverageTests {

    private func tmpDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mer-runner-ext-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func meridianRepoRoot() -> URL {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fm = FileManager.default
        for _ in 0..<12 {
            let manifest = current.appendingPathComponent("Package.swift")
            if fm.fileExists(atPath: manifest.path),
               let text = try? String(contentsOf: manifest, encoding: .utf8),
               text.contains("name: \"meridian\""),
               text.contains("MeridianRuntime") {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        Issue.record("could not locate meridian Package.swift from test file")
        return current
    }

    @Test("SpecError descriptions cover every case")
    func specErrorDescriptions() {
        #expect(
            MeridianTestRunner.SpecError.missingRequiredKey("source", file: "t.test").description
                .contains("missing required key")
        )
        #expect(
            MeridianTestRunner.SpecError.readFailure("/nope", underlying: NSError(domain: "t", code: 1)).description
                .contains("could not read")
        )
        #expect(
            MeridianTestRunner.SpecError.parseError("bad key", file: "t.test").description
                .contains("bad key")
        )
    }

    @Test("Outcome and Report accessors")
    func outcomeAccessors() {
        #expect(MeridianTestRunner.Outcome.success(detail: "ok").isSuccess)
        #expect(!MeridianTestRunner.Outcome.failure(reasons: ["x"]).isSuccess)
        #expect(MeridianTestRunner.Outcome.skipped(reason: "later").isSkipped)
        #expect(!MeridianTestRunner.Outcome.success(detail: "").isSkipped)
        let report = MeridianTestRunner.Report(
            spec: MeridianTestRunner.Spec(displayName: "x", baseDir: FileManager.default.temporaryDirectory, source: .inline("")),
            outcome: .success(detail: "ok")
        )
        #expect(report.spec.displayName == "x")
    }

    @Test("loadSpec readFailure when the spec file is missing")
    func loadSpecReadFailure() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("definitely-missing-\(UUID().uuidString).meridian.test")
        do {
            _ = try MeridianTestRunner().loadSpec(url)
            Issue.record("expected read failure")
        } catch let err as MeridianTestRunner.SpecError {
            #expect(err.description.contains("could not read"))
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("loadSpec maps unrecognized keys through diagnostic parse errors")
    func loadSpecUnrecognizedKey() throws {
        let dir = try tmpDir()
        let url = dir.appendingPathComponent("bad.meridian.test")
        try "source: w.meridian\nnot_a_real_key: value".write(to: url, atomically: true, encoding: .utf8)
        do {
            _ = try MeridianTestRunner().loadSpec(url)
            Issue.record("expected parse error")
        } catch let err as MeridianTestRunner.SpecError {
            if case .parseError(let msg, _) = err {
                #expect(msg.contains("invalidTestSpecKey") || msg.contains("test-spec"))
            } else {
                Issue.record("expected parseError, got \(err)")
            }
        }
    }

    @Test("run fails for a missing on-disk source path")
    func missingSourcePath() throws {
        let dir = try tmpDir()
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: dir,
            source: .path("missing.meridian")
        )
        if case .failure(let reasons) = MeridianTestRunner().run(spec) {
            #expect(reasons.contains { $0.contains("source not found") })
        } else {
            Issue.record("expected failure")
        }
    }

    @Test("run fails for a missing vocab path")
    func missingVocabPath() throws {
        let dir = try tmpDir()
        let missingVocab = dir.appendingPathComponent("nope.merconfig").path
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: dir,
            source: .inline("To run:\n  complete.\n"),
            vocab: [.path(missingVocab)]
        )
        switch MeridianTestRunner().run(spec) {
        case .failure(let reasons):
            #expect(reasons.contains { $0.contains("vocab not found") })
        default:
            Issue.record("expected failure for missing vocab")
        }
    }

    @Test("run surfaces describeError when compile is expected to pass but fails")
    func compileFailureUsesDescribeError() {
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: FileManager.default.temporaryDirectory,
            source: .inline("---\nvocabulary: missing.merconfig\n---\nTo run:\n  complete.\n"),
            compileExpectation: .pass
        )
        if case .failure(let reasons) = MeridianTestRunner().run(spec) {
            #expect(reasons.contains { $0.contains("compilation failed") })
        } else {
            Issue.record("expected failure")
        }
    }

    @Test("runAll wraps spec parse failures in a failure outcome")
    func runAllParseFailure() throws {
        let dir = try tmpDir()
        let url = dir.appendingPathComponent("broken.meridian.test")
        try "name: broken".write(to: url, atomically: true, encoding: .utf8)
        let reports = MeridianTestRunner().runAll(roots: [dir])
        #expect(reports.count == 1)
        if case .failure(let reasons) = reports[0].outcome {
            #expect(reasons.contains { $0.contains("spec parse error") })
        } else {
            Issue.record("expected failure outcome")
        }
    }

    @Test("run reads vocab from an on-disk path before compiling")
    func runReadsVocabFromPath() throws {
        let dir = try tmpDir()
        let vocabURL = dir.appendingPathComponent("mini.merconfig")
        try "Kind: order is a thing.\n".write(to: vocabURL, atomically: true, encoding: .utf8)
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: dir,
            source: .inline("To run:\n  complete.\n"),
            vocab: [.path(vocabURL.path)]
        )
        if case .failure(let reasons) = MeridianTestRunner().run(spec) {
            Issue.record("expected success, got: \(reasons)")
        }
    }

}

// MARK: - RuntimeExecutor gaps

@Suite("RuntimeExecutor — build/run and assertion evaluation", .serialized)
struct RuntimeExecutorExtendedCoverageTests {

    private func meridianRepoRoot() -> URL {
        var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fm = FileManager.default
        for _ in 0..<12 {
            let manifest = current.appendingPathComponent("Package.swift")
            if fm.fileExists(atPath: manifest.path),
               let text = try? String(contentsOf: manifest, encoding: .utf8),
               text.contains("name: \"meridian\"") {
                return current
            }
            current = current.deletingLastPathComponent()
        }
        Issue.record("repo root not found")
        return current
    }

    // Lives in this `.serialized` suite (not the plain MeridianTestRunner suite
    // above) because it drives a real RuntimeExecutor subprocess run: the other
    // tests below fault-inject via *global* env vars (setenv/PATH), and Swift
    // Testing parallelizes across suites by default, so an end-to-end happy-path
    // run sharing a suite with those fault-injection tests would intermittently
    // observe an unrelated test's transient env mutation mid-run.
    @Test("runtime_happy spec drives the subprocess executor success path")
    func runtimeHappyEndToEnd() throws {
        let specURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("MeridianTestSpecs/runtime_happy.meridian.test")
        let spec = try MeridianTestRunner().loadSpec(specURL)
        if case .failure(let reasons) = MeridianTestRunner().run(spec) {
            Issue.record("runtime_happy failed: \(reasons.joined(separator: "; "))")
        }
    }

    private func compileMinimalRunWorkflow() throws -> (swift: String, workflow: IRWorkflow) {
        let mer = "To run:\n  complete.\n"
        let compiler = Compiler(options: .init(
            emitterOptions: SwiftEmitter.Options(
                includeTimestamp: false,
                sourceFileName: "t.meridian",
                emitSourceLineComments: false
            )
        ))
        let swift = try compiler.compile(
            meridianSource: mer,
            meridianFile: "t.meridian",
            vocabularies: []
        )
        let ast = try MeridianParser(symbols: SymbolTable.build(from: MerConfigFile()), trace: .silent())
            .parse(mer, file: "t.meridian")
        let workflows = try ASTToIR(symbols: SymbolTable.build(from: MerConfigFile()), sourceFile: "t.meridian")
            .lower(ast)
        guard let wf = workflows.first else {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "no workflow"])
        }
        return (swift, wf)
    }

    private func compileParameterizedWorkflow() throws -> (swift: String, workflow: IRWorkflow) {
        let structName = "Run"
        let swift = """
        import MeridianRuntime

        public struct Widget: Codable, Sendable {
            public init() {}
        }

        public struct \(structName): MeridianWorkflow {
            public let runtime: Runtime
            public let widget: Widget
            public init(runtime: Runtime, widget: Widget) {
                self.runtime = runtime
                self.widget = widget
            }
            public func run() async throws -> WorkflowResult {
                await runtime.workflowStarted(workflowName: "\(structName)", parameters: [:])
                await runtime.complete(reason: nil)
                return WorkflowResult(reason: nil)
            }
        }
        """
        let wf = IRWorkflow(
            name: "run",
            parameters: [IRParameter(name: "widget", kind: KindRef("widget"))],
            body: IRBlock(statements: [.complete(CompleteIR())]),
            explicitStructName: structName
        )
        return (swift, wf)
    }

    private func swiftWithFatalRun(_ swift: String, structName: String) -> String {
        guard let structStart = swift.range(of: "struct \(structName)") else { return swift }
        let tail = swift[structStart.lowerBound...]
        guard let runStart = tail.range(of: "func run() async throws -> WorkflowResult {") else { return swift }
        let insertOffset = swift.distance(from: structStart.lowerBound, to: runStart.upperBound)
        let insertIndex = swift.index(structStart.lowerBound, offsetBy: insertOffset)
        var copy = swift
        copy.insert(contentsOf: "fatalError(\"run failed\"); ", at: insertIndex)
        return copy
    }

    @Test("swift unavailable returns a toolchain message")
    func swiftUnavailable() {
        let originalPath = getenv("PATH").map { String(cString: $0) }
        setenv("PATH", "", 1)
        defer {
            if let originalPath { setenv("PATH", originalPath, 1) } else { unsetenv("PATH") }
        }
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(),
            swiftSource: "",
            workflows: [IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures == ["expect_run requires swift toolchain on PATH"])
    }

    @Test("swift --version non-zero exit is treated as unavailable")
    func swiftVersionNonZero() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fake-swift-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let swiftScript = dir.appendingPathComponent("swift")
        try "#!/bin/sh\nexit 1\n".write(to: swiftScript, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: swiftScript.path)

        let originalPath = getenv("PATH").map { String(cString: $0) } ?? ""
        setenv("PATH", "\(dir.path):\(originalPath)", 1)
        defer { setenv("PATH", originalPath, 1) }

        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(),
            swiftSource: "",
            workflows: [IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures == ["expect_run requires swift toolchain on PATH"])
    }

    @Test("explicit workflow name missing from compiled output is reported")
    func workflowNotFound() {
        let workflow = IRWorkflow(
            name: "run",
            parameters: [],
            body: IRBlock(statements: [.complete(CompleteIR())]),
            explicitStructName: "RunWorkflow"
        )
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(workflowName: "MissingWorkflow"),
            swiftSource: "",
            workflows: [workflow],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.contains { $0.contains("workflow 'MissingWorkflow' not found") })
        #expect(failures.contains { $0.contains("RunWorkflow") })
    }

    @Test("empty compiled workflow list is reported")
    func noWorkflowsInOutput() {
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(),
            swiftSource: "",
            workflows: [],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures == ["no workflows in compiled output to run"])
    }

    @Test("tempdir creation failure surfaces a clear message")
    func tempdirFailure() {
        let original = ProcessInfo.processInfo.environment["MERIDIAN_TEST_SWIFTPM_TEMP_FAIL"]
        setenv("MERIDIAN_TEST_SWIFTPM_TEMP_FAIL", "1", 1)
        defer {
            if let original { setenv("MERIDIAN_TEST_SWIFTPM_TEMP_FAIL", original, 1) }
            else { unsetenv("MERIDIAN_TEST_SWIFTPM_TEMP_FAIL") }
        }
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(),
            swiftSource: "",
            workflows: [IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.contains { $0.contains("failed to create tempdir") })
    }

    @Test("package scaffold failure surfaces a clear message")
    func scaffoldFailure() {
        let original = ProcessInfo.processInfo.environment["MERIDIAN_TEST_SWIFTPM_SCAFFOLD_FAIL"]
        setenv("MERIDIAN_TEST_SWIFTPM_SCAFFOLD_FAIL", "1", 1)
        defer {
            if let original { setenv("MERIDIAN_TEST_SWIFTPM_SCAFFOLD_FAIL", original, 1) }
            else { unsetenv("MERIDIAN_TEST_SWIFTPM_SCAFFOLD_FAIL") }
        }
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(),
            swiftSource: "import MeridianRuntime\n",
            workflows: [IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.contains { $0.contains("failed to scaffold package") })
    }

    @Test("parameterized workflows decode inputs in the generated driver")
    func parameterizedWorkflowRun() throws {
        let compiled = try compileParameterizedWorkflow()
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(
                workflowName: compiled.workflow.structName,
                inputs: compiled.workflow.parameters.map { ($0.name, "{}") }
            ),
            swiftSource: compiled.swift,
            workflows: [compiled.workflow],
            repoRoot: meridianRepoRoot()
        )
        #expect(!failures.contains { $0.contains("swift build failed") })
        #expect(!failures.contains { $0.contains("swift run failed") })
    }

    @Test("matching runtime assertions return no failures")
    func matchingRuntimeAssertions() throws {
        let compiled = try compileMinimalRunWorkflow()
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(
                workflowName: compiled.workflow.structName,
                expectEventKinds: ["workflow.started", "workflow.completed"],
                expectEventKindsPrefix: ["workflow.started"],
                expectFinalEventKind: "workflow.completed",
                expectRunSucceeded: true
            ),
            swiftSource: compiled.swift,
            workflows: [compiled.workflow],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "; ")))
    }

    @Test("swift run failure is reported (non-verbose truncates)")
    func runFailureMessage() throws {
        let compiled = try compileMinimalRunWorkflow()
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(),
            swiftSource: swiftWithFatalRun(compiled.swift, structName: compiled.workflow.structName),
            workflows: [compiled.workflow],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.contains { $0.contains("swift run failed") })
    }

    @Test("verbose mode keeps the full swift run failure text")
    func verboseRunFailure() throws {
        let compiled = try compileMinimalRunWorkflow()
        let failures = RuntimeExecutor(verbose: true).run(
            spec: .init(),
            swiftSource: swiftWithFatalRun(compiled.swift, structName: compiled.workflow.structName),
            workflows: [compiled.workflow],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.contains { $0.contains("swift run failed") })
    }

    @Test("expectations fail when the run emits no workflow events")
    func noWorkflowEvents() throws {
        let structName = "Run"
        let swift = """
        import MeridianRuntime

        public struct \(structName): MeridianWorkflow {
            public let runtime: Runtime
            public init(runtime: Runtime) { self.runtime = runtime }
            public func run() async throws -> WorkflowResult {
                WorkflowResult(reason: nil)
            }
        }
        """
        let wf = IRWorkflow(
            name: "run",
            parameters: [],
            body: IRBlock(statements: [.complete(CompleteIR())]),
            explicitStructName: structName
        )
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(
                expectEventKinds: ["workflow.started", "workflow.completed"],
                expectEventKindsPrefix: ["workflow.started"],
                expectFinalEventKind: "workflow.completed",
                expectRunSucceeded: true
            ),
            swiftSource: swift,
            workflows: [wf],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.contains { $0.contains("expected event kinds") })
        #expect(failures.contains { $0.contains("(none)") })
        #expect(failures.contains { $0.contains("expected run to succeed") })
    }

    @Test("invalid generated Swift surfaces a swift build failure")
    func buildFailureMessage() {
        let wf = IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(),
            swiftSource: "this is not valid swift {{{",
            workflows: [wf],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.contains { $0.contains("swift build failed") })
    }

    @Test("verbose mode keeps the full build failure text")
    func verboseBuildFailure() {
        let wf = IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))
        let failures = RuntimeExecutor(verbose: true).run(
            spec: .init(),
            swiftSource: "this is not valid swift {{{",
            workflows: [wf],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.contains { $0.contains("swift build failed") })
    }

    @Test("runtime assertion mismatches are collected after a successful run")
    func runtimeAssertionFailures() throws {
        let compiled = try compileMinimalRunWorkflow()
        let failures = RuntimeExecutor(verbose: false).run(
            spec: .init(
                toolStubs: [("demo.tool", "{\"ok\":true}")],
                expectEventKinds: ["workflow.started", "invoke.start"],
                expectEventKindsPrefix: ["workflow.failed"],
                expectFinalEventKind: "workflow.failed",
                expectRunSucceeded: false
            ),
            swiftSource: compiled.swift,
            workflows: [compiled.workflow],
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.contains { $0.contains("expected event kinds") })
        #expect(failures.contains { $0.contains("expected event kinds prefix") })
        #expect(failures.contains { $0.contains("expected final event kind") })
        #expect(failures.contains { $0.contains("expected run to fail") })
    }
}

// MARK: - SwiftPMPackageRunner gaps

@Suite("SwiftPMPackageRunner — process results, driver options, and errors")
struct SwiftPMPackageRunnerExtendedCoverageTests {

    @Test("ProcessResult combinedOutput joins stdout and stderr")
    func combinedOutput() {
        let result = SwiftPMPackageRunner.ProcessResult(stdout: "out", stderr: "err", exitCode: 1)
        #expect(result.combinedOutput.contains("out"))
        #expect(result.combinedOutput.contains("err"))
    }

    @Test("requireSuccess throws processFailed for a nonzero exit")
    func requireSuccessFailure() {
        let result = SwiftPMPackageRunner.ProcessResult(stdout: "", stderr: "boom", exitCode: 2)
        do {
            _ = try result.requireSuccess(["false"])
            Issue.record("expected throw")
        } catch let err as SwiftPMPackageRunnerError {
            if case .processFailed(let cmd, let output) = err {
                #expect(cmd == ["false"])
                #expect(output.contains("boom"))
            } else {
                Issue.record("expected processFailed")
            }
            #expect(!err.description.isEmpty)
        } catch {
            Issue.record("unexpected: \(error)")
        }
    }

    @Test("SwiftPMPackageRunnerError descriptions are non-empty")
    func errorDescriptions() {
        #expect(SwiftPMPackageRunnerError.invalidOption("bad opt").description == "bad opt")
        let pf = SwiftPMPackageRunnerError.processFailed(command: ["a"], output: "o")
        #expect(pf.description.contains("process failed"))
        let lf = SwiftPMPackageRunnerError.launchFailed(
            command: ["missing-binary"],
            underlying: NSError(domain: "t", code: 1)
        )
        #expect(lf.description.contains("could not launch"))
    }

    @Test("writeMeridianRunDriverPackage emits checkpoint, stubs, and param decode")
    func runDriverFullOptions() throws {
        let runner = try SwiftPMPackageRunner.temporary(prefix: "mer-ext")
        defer { try? runner.remove() }
        let workflow = IRWorkflow(
            name: "process an order",
            parameters: [IRParameter(name: "order", kind: KindRef("order"))],
            body: IRBlock(statements: [.complete(CompleteIR())])
        )
        try runner.writeMeridianRunDriverPackage(
            repoRoot: FileManager.default.temporaryDirectory,
            generatedSource: "import MeridianRuntime\n",
            workflow: workflow,
            options: .init(
                inputJSON: ["order={\"id\":\"1\"}"],
                toolStubs: ["echo={\"ok\":true}"],
                runID: "cov-run",
                checkpointRoot: "/tmp/meridian-checkpoints"
            )
        )
        let driver = try runner.readFile("Sources/Driver/Driver.swift")
        #expect(driver.contains("FilesystemCheckpointer"))
        #expect(driver.contains("registry.register(tool: \"echo\""))
        #expect(driver.contains("order"))
        #expect(driver.contains("cov-run"))
    }

    @Test("invalid assignment strings throw invalidOption")
    func invalidAssignments() throws {
        let runner = try SwiftPMPackageRunner.temporary(prefix: "mer-ext")
        defer { try? runner.remove() }
        let workflow = IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))
        for bad in ["not-valid", "also-bad", "name="] {
            do {
                try runner.writeMeridianRunDriverPackage(
                    repoRoot: FileManager.default.temporaryDirectory,
                    generatedSource: "",
                    workflow: workflow,
                    options: .init(inputJSON: [bad], toolStubs: [])
                )
                Issue.record("expected throw for \(bad)")
            } catch let err as SwiftPMPackageRunnerError {
                #expect(!err.description.isEmpty)
            }
        }
    }

    @Test("build and run wire through requireSuccess on success")
    func buildAndRunSuccess() throws {
        let runner = try SwiftPMPackageRunner.temporary(prefix: "mer-ext")
        defer { try? runner.remove() }
        try runner.writePackage(
            manifest: """
            // swift-tools-version: 6.0
            import PackageDescription
            let package = Package(
                name: "EchoPkg",
                targets: [.executableTarget(name: "Echo", path: "Sources/Echo")]
            )
            """,
            files: [.init(relativePath: "Sources/Echo/main.swift", contents: "print(\"hi\")\n")]
        )
        let build = try runner.build()
        #expect(build.exitCode == 0)
        let run = try runner.run(executable: "Echo")
        #expect(run.stdout.contains("hi"))
    }
}
