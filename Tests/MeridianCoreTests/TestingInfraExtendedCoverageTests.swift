import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - MeridianTestRunner gaps
//
// RuntimeExecutor / SwiftPMPackageRunner coverage that drives a real
// `swift build`/`swift run` lives in
// Tests/MeridianSlowIntegrationTests/RuntimeExecutorSlowTests.swift instead —
// see the target comment in Package.swift.

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
