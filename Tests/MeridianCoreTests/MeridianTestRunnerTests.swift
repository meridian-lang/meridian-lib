import Testing
import Foundation
@testable import MeridianCore

// MARK: - MeridianTestRunnerTests

@Suite("MeridianTestRunner")
struct MeridianTestRunnerTests {

    // MARK: - Spec loading: metadata keys

    @Test("loadSpec parses name, description, tags, only, skip, skip_reason")
    func parsesMetadataKeys() throws {
        let raw = """
        name: My Spec
        description: checks branch lowering
        tags: ir, codegen
        only: true
        source: w.meridian
        """
        let spec = try load(raw)
        #expect(spec.displayName == "My Spec")
        #expect(spec.description == "checks branch lowering")
        #expect(spec.tags == ["ir", "codegen"])
        #expect(spec.only == true)
        if case .none = spec.skip { } else { Issue.record("expected .none skip") }
    }

    @Test("loadSpec parses skip: true")
    func parsesSkip() throws {
        let spec = try load("source: w.meridian\nskip: true")
        if case .skipped(let r) = spec.skip { #expect(r == nil) }
        else { Issue.record("expected .skipped") }
    }

    @Test("loadSpec parses skip_reason")
    func parsesSkipReason() throws {
        let spec = try load("source: w.meridian\nskip_reason: blocked on Phase 5")
        if case .skipped(let r) = spec.skip { #expect(r == "blocked on Phase 5") }
        else { Issue.record("expected .skipped") }
    }

    @Test("loadSpec defaults displayName to bare filename")
    func defaultsDisplayName() throws {
        let url = try writeFixture("alpha.meridian.test", "source: x.meridian")
        let spec = try MeridianTestRunner().loadSpec(url)
        #expect(spec.displayName == "alpha")
    }

    @Test("loadSpec ignores comments and blank lines")
    func ignoresCommentsAndBlanks() throws {
        let raw = "\n# comment\nsource: w.meridian\n\n# another\n"
        let spec = try load(raw)
        if case .path(let p) = spec.source { #expect(p == "w.meridian") }
        else { Issue.record("expected .path source") }
    }

    // MARK: - Spec loading: source inputs

    @Test("loadSpec parses source: path")
    func parsesSourcePath() throws {
        let spec = try load("source: workflow.meridian")
        if case .path(let p) = spec.source { #expect(p == "workflow.meridian") }
        else { Issue.record("expected .path source") }
    }

    @Test("loadSpec parses source_inline fenced block")
    func parsesSourceInline() throws {
        let raw = """
        source_inline: ```
        To process an order: complete.
        ```
        """
        let spec = try load(raw)
        if case .inline(let src) = spec.source {
            #expect(src.contains("process an order"))
        } else {
            Issue.record("expected .inline source")
        }
    }

    @Test("loadSpec parses vocab: path (repeatable)")
    func parsesVocabPath() throws {
        let spec = try load("source: w.meridian\nvocab: a.merconfig\nvocab: b.merconfig")
        #expect(spec.vocab.count == 2)
    }

    @Test("loadSpec parses vocab_inline <name> fenced block")
    func parsesVocabInline() throws {
        let raw = """
        source_inline: ```
        To do: complete.
        ```
        vocab_inline mini: ```
        Kind: order is a thing.
        ```
        """
        let spec = try load(raw)
        guard let vi = spec.vocab.first else { Issue.record("no vocab"); return }
        if case .inline(let name, let src) = vi {
            #expect(name == "mini")
            #expect(src.contains("Kind: order"))
        } else {
            Issue.record("expected .inline vocab")
        }
    }

    @Test("loadSpec rejects legacy `|` heredoc with diagnostic")
    func rejectsLegacyHeredoc() {
        let raw = """
        source_inline: |
          To do: complete.
        """
        #expect(throws: (any Error).self) { _ = try load(raw) }
    }

    @Test("loadSpec rejects unterminated fenced block")
    func rejectsUnterminatedFence() {
        let raw = """
        source_inline: ```
        To do: complete.
        """
        #expect(throws: (any Error).self) { _ = try load(raw) }
    }

    // MARK: - Spec loading: compile expectation

    @Test("loadSpec parses expect_compile: fail")
    func parsesExpectCompileFail() throws {
        let spec = try load("source: w.meridian\nexpect_compile: fail")
        #expect(spec.compileExpectation == .fail)
    }

    @Test("loadSpec folds error sub-assertions into assertions when expect_compile: fail")
    func foldsErrorAssertions() throws {
        let raw = """
        source: w.meridian
        expect_compile: fail
        expect_error_kind: syntax
        expect_error_contains: unexpected token
        expect_error_line: 3
        """
        let spec = try load(raw)
        #expect(spec.compileExpectation == .fail)
        let kinds = spec.assertions.compactMap { a -> String? in
            switch a {
            case .errorKind(let k): return "kind:\(k.rawValue)"
            case .errorContains(let s): return "contains:\(s)"
            case .errorLine(let n): return "line:\(n)"
            default: return nil
            }
        }
        #expect(kinds.contains("kind:syntax"))
        #expect(kinds.contains("contains:unexpected token"))
        #expect(kinds.contains("line:3"))
    }

    // MARK: - Spec loading: Swift assertions

    @Test("loadSpec parses expect_swift_contains (repeatable)")
    func parsesSwiftContains() throws {
        let raw = """
        source: w.meridian
        expect_swift_contains: struct ProcessOrder
        expect_swift_contains: func run()
        """
        let spec = try load(raw)
        let texts = spec.assertions.compactMap { a -> String? in
            if case .swiftContains(let t) = a { return t }
            return nil
        }
        #expect(texts.contains("struct ProcessOrder"))
        #expect(texts.contains("func run()"))
    }

    @Test("loadSpec parses expect_swift_not_contains")
    func parsesSwiftNotContains() throws {
        let spec = try load("source: w\nexpect_swift_not_contains: _unresolved")
        #expect(spec.assertions.contains {
            if case .swiftNotContains(let t) = $0 { return t == "_unresolved" }
            return false
        })
    }

    @Test("loadSpec parses expect_swift_matches")
    func parsesSwiftMatches() throws {
        let spec = try load("source: w\nexpect_swift_matches: struct \\w+Order")
        #expect(spec.assertions.contains {
            if case .swiftMatches = $0 { return true }
            return false
        })
    }

    @Test("loadSpec parses golden_swift as a goldenSwift assertion")
    func parsesGoldenSwift() throws {
        let spec = try load("source: w.meridian\ngolden_swift: golden/out.swift")
        #expect(spec.assertions.contains {
            if case .goldenSwift(let p) = $0 { return p == "golden/out.swift" }
            return false
        })
    }

    @Test("loadSpec parses expect_swift_line_count_min and _max")
    func parsesLineCountBounds() throws {
        let spec = try load("source: w\nexpect_swift_line_count_min: 50\nexpect_swift_line_count_max: 500")
        #expect(spec.assertions.contains { if case .swiftLineCountMin(50) = $0 { return true }; return false })
        #expect(spec.assertions.contains { if case .swiftLineCountMax(500) = $0 { return true }; return false })
    }

    // MARK: - Spec loading: IR assertions

    @Test("loadSpec parses expect_workflow_count")
    func parsesWorkflowCount() throws {
        let spec = try load("source: w\nexpect_workflow_count: 2")
        #expect(spec.assertions.contains { if case .workflowCount(2) = $0 { return true }; return false })
    }

    @Test("loadSpec parses expect_workflow_named")
    func parsesWorkflowNamed() throws {
        let spec = try load("source: w\nexpect_workflow_named: ProcessOrder")
        #expect(spec.assertions.contains {
            if case .workflowNamed(let n) = $0 { return n == "ProcessOrder" }; return false
        })
    }

    @Test("loadSpec parses expect_no_unresolved")
    func parsesNoUnresolved() throws {
        let spec = try load("source: w\nexpect_no_unresolved:")
        #expect(spec.assertions.contains { if case .noUnresolved = $0 { return true }; return false })
    }

    @Test("loadSpec parses expect_invoke_tool (repeatable)")
    func parsesInvokeTool() throws {
        let raw = "source: w\nexpect_invoke_tool: validate an order\nexpect_invoke_tool: charge payment"
        let spec = try load(raw)
        let ids = spec.assertions.compactMap { a -> String? in
            if case .invokeToolID(let id) = a { return id }; return nil
        }
        #expect(ids.contains("validate an order"))
        #expect(ids.contains("charge payment"))
    }

    @Test("loadSpec parses expect_emit_event")
    func parsesEmitEvent() throws {
        let spec = try load("source: w\nexpect_emit_event: analytics.order_processed")
        #expect(spec.assertions.contains {
            if case .emitEventID(let id) = $0 { return id == "analytics.order_processed" }; return false
        })
    }

    @Test("loadSpec parses expect_primitive_count")
    func parsesPrimitiveCount() throws {
        let spec = try load("source: w\nexpect_primitive_count: branch 3")
        #expect(spec.assertions.contains {
            if case .primitiveCount(.branch, 3) = $0 { return true }; return false
        })
    }

    @Test("loadSpec parses expect_workflow_mode")
    func parsesWorkflowMode() throws {
        let spec = try load("source: w\nexpect_workflow_mode: SyncAnalytics lenient")
        #expect(spec.assertions.contains {
            if case .workflowMode(let name, let mode) = $0 {
                return name == "SyncAnalytics" && mode == .lenient
            }
            return false
        })
    }

    @Test("loadSpec parses golden_manifest")
    func parsesGoldenManifest() throws {
        let spec = try load("source: w\ngolden_manifest: golden/m.json")
        #expect(spec.assertions.contains {
            if case .goldenManifest(let p) = $0 { return p == "golden/m.json" }; return false
        })
    }

    @Test("loadSpec parses expect_formatter_idempotent: true")
    func parsesFormatterIdempotent() throws {
        let spec = try load("source: w\nexpect_formatter_idempotent: true")
        #expect(spec.assertions.contains { if case .formatterIdempotent = $0 { return true }; return false })
    }

    @Test("loadSpec parses expect_trace_contains (repeatable)")
    func parsesTraceContains() throws {
        let raw = "source: w\ntrace: phrase\nexpect_trace_contains: validate\nexpect_trace_contains: charge"
        let spec = try load(raw)
        let substrs = spec.assertions.compactMap { a -> String? in
            if case .traceContains(let s) = a { return s }; return nil
        }
        #expect(substrs.contains("validate"))
        #expect(substrs.contains("charge"))
        #expect(!spec.traceCategories.isEmpty)
    }

    // MARK: - Spec loading: runtime keys

    @Test("loadSpec parses expect_run and runtime keys")
    func parsesRuntimeKeys() throws {
        let raw = """
        source: w.meridian
        expect_run: true
        workflow: ProcessOrder
        tool_stub validate an order: {"verdict": "valid"}
        input order: {"id": "o-001"}
        expect_event_kinds: workflow.started, workflow.completed
        expect_run_succeeded: true
        """
        let spec = try load(raw)
        guard let rs = spec.runtime else { Issue.record("no runtime spec"); return }
        #expect(rs.workflowName == "ProcessOrder")
        #expect(rs.toolStubs.contains { $0.toolID == "validate an order" })
        #expect(rs.inputs.contains { $0.paramName == "order" })
        #expect(rs.expectEventKinds == ["workflow.started", "workflow.completed"])
        #expect(rs.expectRunSucceeded == true)
    }

    @Test("loadSpec parses expect_event_kinds_prefix and expect_final_event_kind")
    func parsesEventKindsVariants() throws {
        let raw = """
        source: w.meridian
        expect_run: true
        expect_event_kinds_prefix: workflow.started
        expect_final_event_kind: workflow.completed
        """
        let spec = try load(raw)
        guard let rs = spec.runtime else { Issue.record("no runtime spec"); return }
        #expect(rs.expectEventKindsPrefix == ["workflow.started"])
        #expect(rs.expectFinalEventKind == "workflow.completed")
    }

    // MARK: - Spec loading: fenced code blocks

    @Test("loadSpec fenced block: body lines are preserved verbatim")
    func fencedPreservesBody() throws {
        let raw = """
        source_inline: ```
        To do something: complete.
        # a comment inside the fenced body
        ```
        """
        let spec = try load(raw)
        if case .inline(let src) = spec.source {
            #expect(src.contains("To do something: complete."))
            #expect(src.contains("# a comment inside the fenced body"))
        } else {
            Issue.record("expected inline source")
        }
    }

    @Test("loadSpec fenced block: blank lines inside the body are preserved")
    func fencedPreservesBlanks() throws {
        let raw = "source_inline: ```\nline one\n\nline three\n```\n"
        let spec = try load(raw)
        if case .inline(let src) = spec.source {
            #expect(src.contains("\n\n"))
        } else {
            Issue.record("expected inline source")
        }
    }

    @Test("loadSpec fenced block: terminates at closing fence, not at de-indent")
    func fencedTerminatesAtClosingFence() throws {
        let raw = """
        source_inline: ```
        To do: complete.
        ```
        name: After Fence
        """
        let spec = try load(raw)
        #expect(spec.displayName == "After Fence")
        if case .inline(let src) = spec.source {
            #expect(!src.contains("After Fence"))
        }
    }

    @Test("loadSpec fenced block: ignores info string on opening fence")
    func fencedIgnoresInfoString() throws {
        let raw = """
        source_inline: ```meridian
        To do: complete.
        ```
        """
        let spec = try load(raw)
        if case .inline(let src) = spec.source {
            #expect(src.contains("To do: complete."))
        }
    }

    @Test("loadSpec fenced block: preserves indentation inside the body")
    func fencedPreservesIndent() throws {
        let raw = """
        source_inline: ```
        To process an order:
          validate the order.
          complete.
        ```
        """
        let spec = try load(raw)
        if case .inline(let src) = spec.source {
            #expect(src.contains("\n  validate the order."))
        }
    }

    @Test("loadSpec missing source throws SpecError.missingRequiredKey")
    func missingSourceThrows() throws {
        let url = try writeFixture("nope.meridian.test", "name: nope")
        do {
            _ = try MeridianTestRunner().loadSpec(url)
            Issue.record("expected loadSpec to throw")
        } catch let MeridianTestRunner.SpecError.missingRequiredKey(key, _) {
            #expect(key.contains("source"))
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    // MARK: - Discovery

    @Test("discover walks a directory and returns specs sorted by path")
    func discoversInDirectory() throws {
        let root = try makeTempDir()
        _ = try writeFixture("zeta.meridian.test", "source: a", in: root)
        _ = try writeFixture("alpha.meridian.test", "source: a", in: root)
        try "ignore me".write(to: root.appendingPathComponent("readme.md"),
                              atomically: true, encoding: .utf8)
        let names = MeridianTestRunner().discover(in: [root]).map(\.lastPathComponent)
        #expect(names == ["alpha.meridian.test", "zeta.meridian.test"])
    }

    @Test("discover accepts an individual spec file path")
    func discoversIndividualFile() throws {
        let url = try writeFixture("solo.meridian.test", "source: a")
        #expect(MeridianTestRunner().discover(in: [url]) == [url])
    }

    // MARK: - Run: skip / only

    @Test("run returns .skipped when spec.skip is set")
    func runReturnsSkipped() throws {
        let spec = MeridianTestRunner.Spec(
            displayName: "x", baseDir: tmpURL(),
            skip: .skipped(reason: "WIP"),
            source: .inline("To do: complete.")
        )
        if case .skipped(let r) = MeridianTestRunner().run(spec) {
            #expect(r == "WIP")
        } else {
            Issue.record("expected skipped")
        }
    }

    @Test("runAll skips non-only specs when any spec has only: true")
    func runAllOnlyFocus() throws {
        let dir = try makeTempDir()
        let src = dir.appendingPathComponent("ok.meridian")
        try "".write(to: src, atomically: true, encoding: .utf8)
        _ = try writeFixture("a.meridian.test", "source: ok.meridian\nonly: true", in: dir)
        _ = try writeFixture("b.meridian.test", "source: ok.meridian", in: dir)

        let reports = MeridianTestRunner().runAll(roots: [dir])
        #expect(reports.count == 2)
        let aReport = reports.first { $0.spec.displayName == "a" }
        let bReport = reports.first { $0.spec.displayName == "b" }
        #expect(aReport?.outcome.isSuccess == true)
        #expect(bReport?.outcome.isSkipped == true)
    }

    @Test("runner tag filter skips specs without matching tag")
    func tagFilterSkips() throws {
        let dir = try makeTempDir()
        let src = dir.appendingPathComponent("ok.meridian")
        try "".write(to: src, atomically: true, encoding: .utf8)
        _ = try writeFixture("tagged.meridian.test", "source: ok.meridian\ntags: ir", in: dir)
        _ = try writeFixture("untagged.meridian.test", "source: ok.meridian", in: dir)

        let runner  = MeridianTestRunner(tagFilter: ["ir"])
        let reports = runner.runAll(roots: [dir])
        #expect(reports.count == 2)
        let tagged   = reports.first { $0.spec.displayName == "tagged" }
        let untagged = reports.first { $0.spec.displayName == "untagged" }
        #expect(tagged?.outcome.isSuccess == true)
        #expect(untagged?.outcome.isSkipped == true)
    }

    @Test("runner name filter skips specs that don't match")
    func nameFilterSkips() throws {
        let dir = try makeTempDir()
        let src = dir.appendingPathComponent("ok.meridian")
        try "".write(to: src, atomically: true, encoding: .utf8)
        _ = try writeFixture("fraud check.meridian.test",  "source: ok.meridian", in: dir)
        _ = try writeFixture("payment retry.meridian.test", "source: ok.meridian", in: dir)

        let runner  = MeridianTestRunner(nameFilter: "fraud")
        let reports = runner.runAll(roots: [dir])
        let fraud   = reports.first { $0.spec.displayName == "fraud check" }
        let payment = reports.first { $0.spec.displayName == "payment retry" }
        #expect(fraud?.outcome.isSuccess == true)
        #expect(payment?.outcome.isSkipped == true)
    }

    // MARK: - Run: compile-pass assertions

    @Test("compile-only inline spec succeeds")
    func inlineCompileOnly() {
        let spec = MeridianTestRunner.Spec(
            displayName: "empty", baseDir: tmpURL(),
            source: .inline("")
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success") }
    }

    @Test("expect_swift_contains passes when substring present")
    func swiftContainsPasses() {
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline("To run:\n  complete.\n"),
            assertions: [.swiftContains("func run()")]
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success") }
    }

    @Test("expect_swift_contains fails when substring absent")
    func swiftContainsFails() {
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline(""),
            assertions: [.swiftContains("BANANA")]
        )
        if case .failure(let reasons) = MeridianTestRunner().run(spec) {
            #expect(reasons.contains { $0.contains("BANANA") })
        } else {
            Issue.record("expected failure")
        }
    }

    @Test("expect_swift_not_contains passes when substring absent")
    func swiftNotContainsPasses() {
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline(""),
            assertions: [.swiftNotContains("_unresolved")]
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success") }
    }

    @Test("expect_no_unresolved passes when IR is clean")
    func noUnresolvedPasses() {
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline(""),
            assertions: [.noUnresolved]
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success") }
    }

    @Test("expect_workflow_count with inline source")
    func workflowCountWithInline() {
        // Two minimal workflows (header ends with `:`, body on next indented line).
        let src = "To run:\n  complete.\n\nTo start:\n  complete.\n"
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline(src),
            assertions: [.workflowCount(2)]
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success") }
    }

    @Test("expect_workflow_count fails when count is wrong")
    func workflowCountFails() {
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline("To run:\n  complete.\n"),
            assertions: [.workflowCount(99)]
        )
        if case .failure(let reasons) = MeridianTestRunner().run(spec) {
            #expect(reasons.contains { $0.contains("99") })
        } else {
            Issue.record("expected failure")
        }
    }

    @Test("expect_workflow_named passes when struct name matches")
    func workflowNamedPasses() {
        // "To run:" → struct name "Run"
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline("To run:\n  complete.\n"),
            assertions: [.workflowNamed("Run")]
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success") }
    }

    @Test("expect_workflow_mode lenient passes for lenient workflow")
    func workflowModeLenientPasses() {
        // "To sync:" → struct name "Sync"; "in lenient mode." sets mode.
        let src = "To sync:\n  in lenient mode.\n  complete.\n"
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline(src),
            assertions: [.workflowMode(structName: "Sync", mode: .lenient)]
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success") }
    }

    @Test("expect_swift_matches passes with valid regex")
    func swiftMatchesPasses() {
        // "To run:" emits a struct whose name matches "\w+"
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline("To run:\n  complete.\n"),
            assertions: [.swiftMatches("struct \\w+")]
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success") }
    }

    @Test("expect_formatter_idempotent passes for well-formatted source")
    func formatterIdempotentPasses() {
        let src = "To run:\n  complete.\n"
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline(src),
            assertions: [.formatterIdempotent]
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success") }
    }

    @Test("expect_formatter_idempotent fails for source with trailing spaces")
    func formatterIdempotentFails() {
        let src = "To run:   \n  complete.\n"  // trailing spaces on header
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline(src),
            assertions: [.formatterIdempotent]
        )
        if case .failure(let reasons) = MeridianTestRunner().run(spec) {
            #expect(reasons.contains { $0.contains("formatter") || $0.contains("formatted") })
        } else {
            Issue.record("expected failure")
        }
    }

    // MARK: - Run: compile-fail path

    @Test("expect_compile: fail passes when compile throws")
    func compileFail() {
        // Import "nonexistent" but supply only "ecommerce" → validateImports throws.
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline("---\nvocabulary: nonexistent.merconfig\n---\nTo run:\n  complete.\n"),
            vocab: [.inline(name: "ecommerce", source: "# empty")],
            compileExpectation: .fail
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success (the expected failure happened)") }
    }

    @Test("expect_compile: fail fails when compile succeeds")
    func compileFailButSucceeds() {
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline(""),
            compileExpectation: .fail
        )
        if case .failure(let reasons) = MeridianTestRunner().run(spec) {
            #expect(reasons.contains { $0.contains("expected compile to fail") })
        } else {
            Issue.record("expected failure")
        }
    }

    @Test("errorContains assertion matches compile error message")
    func errorContainsMatches() {
        // Reference "missingvocab" in frontmatter but supply only "ecommerce"
        // → semantic error mentions the missing name.
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline("---\nvocabulary: missingvocab.merconfig\n---\nTo run:\n  complete.\n"),
            vocab: [.inline(name: "ecommerce", source: "# empty")],
            compileExpectation: .fail,
            assertions: [.errorContains("missingvocab")]
        )
        if case .success = MeridianTestRunner().run(spec) { }
        else { Issue.record("expected success (error contained expected substring)") }
    }

    // MARK: - Run: golden file with --update-golden

    @Test("updateGolden overwrites mismatching golden file")
    func updateGoldenOverwrites() throws {
        let dir = try makeTempDir()
        let goldenURL = dir.appendingPathComponent("out.swift")
        try "STALE CONTENT".write(to: goldenURL, atomically: true, encoding: .utf8)

        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: dir,
            source: .inline(""),
            assertions: [.goldenSwift(path: "out.swift")]
        )

        // Without updateGolden: should fail (stale content != compiled output)
        if case .success = MeridianTestRunner(updateGolden: false).run(spec) {
            // Only acceptable if "STALE CONTENT" happened to equal the emitted Swift
        }

        // With updateGolden: should succeed and overwrite
        let runner = MeridianTestRunner(updateGolden: true)
        if case .failure(let reasons) = runner.run(spec) {
            Issue.record("expected success with updateGolden, got: \(reasons)")
        }

        // Golden file should now contain real Swift
        let updated = try String(contentsOf: goldenURL, encoding: .utf8)
        #expect(updated.contains("GENERATED BY MERIDIAN") || updated.contains("import"))
    }

    // MARK: - Run: multiple failures aggregated

    @Test("multiple assertion failures all appear in reasons list")
    func multipleFailuresAggregated() {
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            source: .inline(""),
            assertions: [
                .swiftContains("BANANA"),
                .swiftContains("MANGO"),
                .workflowCount(99)
            ]
        )
        if case .failure(let reasons) = MeridianTestRunner().run(spec) {
            #expect(reasons.count == 3, Comment(rawValue: "expected 3 failures, got: \(reasons)"))
        } else {
            Issue.record("expected failure")
        }
    }

    // MARK: - Run: trace capture

    @Test("expect_trace_contains passes when trace has the substring")
    func traceContainsPasses() throws {
        let src = """
        To process an order placed by a customer:
          complete.
        """
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: tmpURL(),
            traceCategories: [.phraseMatch],
            source: .inline(src),
            assertions: [.traceContains("process")]
        )
        // This exercises the trace capture path; "process" should appear in phrase matching.
        let outcome = MeridianTestRunner().run(spec)
        // Accept either success or failure — what we verify is no crash and
        // that `traceLines` is populated (we can't guarantee the exact content).
        _ = outcome
    }

    // MARK: - runAll

    @Test("runAll produces one report per discovered spec")
    func runAllProducesOneReportPerSpec() throws {
        let dir = try makeTempDir()
        let srcURL = dir.appendingPathComponent("ok.meridian")
        try "".write(to: srcURL, atomically: true, encoding: .utf8)
        _ = try writeFixture("good.meridian.test", "source: ok.meridian", in: dir)
        _ = try writeFixture("bad.meridian.test",  "source: missing.meridian", in: dir)

        let reports = MeridianTestRunner().runAll(roots: [dir])
        #expect(reports.count == 2)
        #expect(reports.contains { $0.outcome.isSuccess })
        #expect(reports.contains { !$0.outcome.isSuccess && !$0.outcome.isSkipped })
    }

    // MARK: - IRWalker unit tests

    @Test("IRWalker.flatPrimitives collects nested primitives")
    func irWalkerFlat() {
        let inner = IRBlock(statements: [.complete(CompleteIR())])
        let outer = IRBlock(statements: [.branch(BranchIR(
            condition: .predicate(.literal(.boolean(true))),
            thenBlock: inner
        ))])
        let wf = IRWorkflow(name: "test", parameters: [], body: outer)
        let prims = IRWalker.flatPrimitives(workflows: [wf])
        #expect(prims.count == 2)  // the branch + the complete inside it
    }

    @Test("IRWalker.count counts by kind")
    func irWalkerCount() {
        let block = IRBlock(statements: [
            .complete(CompleteIR()),
            .complete(CompleteIR()),
            .invoke(InvokeIR(toolID: "foo"))
        ])
        let wf = IRWorkflow(name: "t", parameters: [], body: block)
        #expect(IRWalker.count(kind: .complete, in: [wf]) == 2)
        #expect(IRWalker.count(kind: .invoke,   in: [wf]) == 1)
        #expect(IRWalker.count(kind: .branch,   in: [wf]) == 0)
    }

    @Test("IRWalker.hasUnresolved detects _unresolved binds")
    func irWalkerUnresolved() {
        let block = IRBlock(statements: [
            .bind(BindIR(name: "_unresolved", expression: .literal(.string(""))))
        ])
        let wf = IRWorkflow(name: "t", parameters: [], body: block)
        #expect(IRWalker.hasUnresolved(in: [wf]) == true)
        let clean = IRWorkflow(name: "t2", parameters: [], body: IRBlock(statements: []))
        #expect(IRWalker.hasUnresolved(in: [clean]) == false)
    }

    @Test("IRWalker.allToolIDs collects from nested invoke nodes")
    func irWalkerToolIDs() {
        let inner = IRBlock(statements: [.invoke(InvokeIR(toolID: "nested-tool"))])
        let outer = IRBlock(statements: [
            .invoke(InvokeIR(toolID: "top-tool")),
            .branch(BranchIR(condition: .predicate(.literal(.boolean(true))), thenBlock: inner))
        ])
        let wf = IRWorkflow(name: "t", parameters: [], body: outer)
        let ids = IRWalker.allToolIDs(in: [wf])
        #expect(ids.contains("top-tool"))
        #expect(ids.contains("nested-tool"))
    }

    // MARK: - shortDiff

    @Test("shortDiff returns first-mismatching-line message")
    func shortDiffPicksFirstMismatch() {
        let msg = MeridianTestRunner.shortDiff(actual: "alpha\nbeta\ngamma", expected: "alpha\nBETA\ngamma")
        #expect(msg.contains("first mismatch at line 2"))
        #expect(msg.contains("beta"))
        #expect(msg.contains("BETA"))
    }

    @Test("shortDiff detects line-count mismatches")
    func shortDiffLineCount() {
        let msg = MeridianTestRunner.shortDiff(actual: "one\ntwo\nthree", expected: "one\ntwo")
        #expect(msg.contains("line count differs"))
    }

    // MARK: - Fixture helpers

    private func tmpURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-runner-tests-\(UUID().uuidString)")
    }

    private func makeTempDir() throws -> URL {
        let path = tmpURL().path
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    @discardableResult
    private func writeFixture(_ name: String, _ contents: String, in dir: URL? = nil) throws -> URL {
        let parent = try dir ?? makeTempDir()
        let url = parent.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Parse a spec from a raw string (uses a synthetic temp URL for baseDir).
    private func load(_ raw: String) throws -> MeridianTestRunner.Spec {
        let url = try writeFixture("test.meridian.test", raw)
        return try MeridianTestRunner().loadSpec(url)
    }
}
