import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

@Suite("DriverSourceBuilder — both branches of every emitter")
struct DriverSourceBuilderCoverageTests {

    @Test("jsonBridge with and without money coercion")
    func jsonBridge() {
        let withMoney = DriverSourceBuilder.jsonBridge(includeMoneyCoercion: true)
        #expect(withMoney.contains { $0.contains(".money(") })
        let withoutMoney = DriverSourceBuilder.jsonBridge(includeMoneyCoercion: false)
        #expect(!withoutMoney.contains { $0.contains(".money(") })
        #expect(withoutMoney.contains { $0.contains(".record(dict.mapValues") })
    }

    @Test("toolStub escapes name and json")
    func toolStub() {
        let lines = DriverSourceBuilder.toolStub(name: "http.get", json: "{\"a\":1}", indent: "  ")
        #expect(lines.first?.contains("registry.register(tool: \"http.get\"") == true)
        #expect(lines.contains { $0.contains("\\\"a\\\"") })
    }

    @Test("paramDecode forced (try) and tolerant (try?) variants")
    func paramDecode() {
        let forced = DriverSourceBuilder.paramDecode(name: "order", swiftType: "Order", json: "{}", indent: "  ", force: true)
        #expect(forced.contains { $0.contains("try JSONDecoder().decode(Order.self") })
        let tolerant = DriverSourceBuilder.paramDecode(name: "order", swiftType: "Order", json: "{}", indent: "  ", force: false)
        #expect(tolerant.contains { $0.contains("(try? JSONDecoder().decode(Order.self") && $0.contains("?? Order()") })
    }
}

@Suite("RuntimeExecutor — early-return branches (no subprocess build)")
struct RuntimeExecutorEarlyReturnTests {

    private func wf(_ name: String) -> IRWorkflow {
        IRWorkflow(name: name, parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))
    }

    @Test("no workflows → reports nothing to run")
    func noWorkflows() {
        let ex = RuntimeExecutor(verbose: false)
        let failures = ex.run(spec: .init(), swiftSource: "",
                              workflows: [], repoRoot: FileManager.default.temporaryDirectory)
        #expect(failures.contains { $0.contains("no workflows") || $0.contains("requires swift toolchain") })
    }

    @Test("named workflow not found → reports available set")
    func workflowNotFound() {
        let ex = RuntimeExecutor(verbose: false)
        let failures = ex.run(spec: .init(workflowName: "DoesNotExist"), swiftSource: "",
                              workflows: [wf("do a thing")], repoRoot: FileManager.default.temporaryDirectory)
        #expect(failures.contains { $0.contains("not found") || $0.contains("requires swift toolchain") })
    }
}

@Suite("SwiftPMPackageRunner — temp package lifecycle and process helper")
struct SwiftPMPackageRunnerCoverageTests {

    @Test("temporary creates a unique dir, writePackage writes files, remove cleans up")
    func lifecycle() throws {
        let runner = try SwiftPMPackageRunner.temporary(prefix: "mer-cov")
        try runner.writePackage(
            manifest: "// swift-tools-version: 6.0\n",
            files: [.init(relativePath: "Sources/Foo/Foo.swift", contents: "let x = 1\n")]
        )
        let manifestURL = runner.packageURL.appendingPathComponent("Package.swift")
        #expect(FileManager.default.fileExists(atPath: manifestURL.path))
        let fooURL = runner.packageURL.appendingPathComponent("Sources/Foo/Foo.swift")
        #expect(FileManager.default.fileExists(atPath: fooURL.path))
        try runner.remove()
        #expect(!FileManager.default.fileExists(atPath: runner.packageURL.path))
    }

    @Test("runProcess captures stdout and a nonzero exit code")
    func runProcess() throws {
        let runner = SwiftPMPackageRunner(packageURL: FileManager.default.temporaryDirectory)
        let ok = try runner.runProcess(["echo", "hello"])
        #expect(ok.exitCode == 0)
        #expect(ok.stdout.contains("hello"))
        let fail = try runner.runProcess(["false"])
        #expect(fail.exitCode != 0)
    }

    @Test("run-driver package manifest uses the path dependency identity")
    func runDriverManifestIdentity() throws {
        let runner = try SwiftPMPackageRunner.temporary(prefix: "mer-cov")
        defer { try? runner.remove() }
        let repo = FileManager.default.temporaryDirectory.appendingPathComponent("meridian checkout with spaces")
        let workflow = IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))
        try runner.writeMeridianRunDriverPackage(
            repoRoot: repo,
            generatedSource: "import MeridianRuntime\n",
            workflow: workflow
        )
        let manifest = try runner.readFile("Package.swift")
        #expect(manifest.contains("package: \"meridian checkout with spaces\""), Comment(rawValue: manifest))
    }
}
