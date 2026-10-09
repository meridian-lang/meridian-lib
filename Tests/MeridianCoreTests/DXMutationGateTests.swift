import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

/// Negative-space / mutation gates for observability DX (plan step 8).
/// Each test documents a gate that must fail loudly when regressed.
@Suite("DX mutation gate")
struct DXMutationGateTests {
    private let cfg = """
    === vocabulary ===

    An order is a kind of thing.

    === tools ===

    Charge Payment
    ==============
    ~ chargePayment(order: Order) : Order
    """

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    // MARK: - MER-DEO-007: silent deontic condition drop

    @Test("mutation gate: unlowerable deontic obligation condition raises MER-DEO-007")
    func deonticUnlowerableConditionIsNotSilentlyDropped() throws {
        let analyzer = RuleAnalyzer(symbols: nil)
        let rule = RuleAST(text: "Every order is shipped must hold.", sourceLine: 3)
        do {
            _ = try analyzer.classify(rule)
            Issue.record("expected MER-DEO-007 — silent drop would return nil without throwing")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .deonticUnlowerableCondition })
        }
    }

    @Test("mutation gate: DeonticLowering rejects unlowerable whose constraint values")
    func deonticLoweringConstraintValueGate() throws {
        let exprParser = ExpressionParser()
        let lexicon = EnglishLexicon.default
        do {
            _ = try DeonticLowering.parseArgumentConstraints(
                "owner is every active user",
                exprParser: exprParser,
                lexicon: lexicon
            )
            Issue.record("expected MER-DEO-007 from lowerConstraintValue")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .deonticUnlowerableCondition })
        }
    }

    @Test("mutation gate: DeonticLowering conflict detection is not bypassed")
    func deonticLoweringConflictGate() {
        let prohibition = NormIR(
            id: "n1",
            kind: .prohibition,
            scope: .skill,
            actionPattern: ActionPatternIR(toolID: "timeNow", argumentConstraints: []),
            sourceRange: SourceRange(file: "t.meridian", line: 1, column: 1),
            originalText: "must not invoke time.now"
        )
        let permission = NormIR(
            id: "n2",
            kind: .permission,
            scope: .skill,
            actionPattern: ActionPatternIR(toolID: "timeNow", argumentConstraints: []),
            sourceRange: SourceRange(file: "t.meridian", line: 2, column: 1),
            originalText: "may invoke time.now"
        )
        let diags = DeonticLowering.detectConflicts([prohibition, permission])
        #expect(diags.contains { $0.code == DiagnosticCode.deonticSameScopeConflict })
    }

    // MARK: - Recover colon hard error

    @Test("mutation gate: recover header without colon is a hard MER1003 error")
    func recoverMissingColonHardError() throws {
        let mer = """
        To handle failures:
          recover from any
            complete.
        """
        do {
            _ = try Compiler(options: .init()).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "t.meridian")], vocabularies: []))["t.meridian"]!.swift
            Issue.record("expected malformed recover header to throw")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .unparseableStatement })
            #expect(diags.first?.message.contains("malformed `recover` header") == true)
        }
    }

    // MARK: - MER2001 without allow-fallbacks

    @Test("mutation gate: unresolved phrase without allow-fallbacks is MER2001")
    func unresolvedPhraseStrictGate() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          frobnicate the gizmo using the order.
        """
        do {
            _ = try Compiler(options: .init(fallbackPolicy: .strict)).compile(
                meridianSource: mer,
                meridianFile: "t.meridian",
                merconfigSource: cfg,
                merconfigFile: "t.merconfig"
            )
            Issue.record("expected MER2001 — silent fallback would emit _unresolved Swift")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .unresolvedPhrase })
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    // MARK: - nameResolution did-you-mean contract

    @Test("mutation gate: Diagnostic.unresolved always guides nameResolution codes")
    func nameResolutionDidYouMeanContract() {
        let range = SourceRange(file: "t.meridian", line: 1, column: 1)
        for code in DiagnosticCode.all where code.kind == .nameResolution {
            let near = Diagnostic.unresolved(
                code, target: "chargePaymnt", among: ["chargePayment"], range: range, noun: "tool")
            #expect(
                !near.suggestions.isEmpty,
                Comment(rawValue: "\(code.id) lost did-you-mean for a near candidate")
            )
            let far = Diagnostic.unresolved(
                code, target: "zzzzzzzzzz", among: ["alpha", "beta"], range: range, noun: "tool")
            #expect(
                !far.suggestions.isEmpty || !far.notes.isEmpty,
                Comment(rawValue: "\(code.id) lost candidate-list note for far misses")
            )
        }
    }

    @Test("mutation gate: stripping suggestions from unresolved would fail compile guidance")
    func nameResolutionCompilePathCarriesGuidance() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          invoke chargePaymnt with order = the order.
        """
        do {
            _ = try Compiler(options: .init()).compile(
                meridianSource: mer,
                meridianFile: "t.meridian",
                merconfigSource: cfg,
                merconfigFile: "t.merconfig"
            )
            Issue.record("expected unknown tool diagnostic")
        } catch let CompilerError.diagnostics(diags) {
            let diag = try #require(diags.first { $0.code == .unknownTool })
            #expect(
                !diag.suggestions.isEmpty || diag.notes.contains { $0.message.contains("chargePayment") },
                Comment(rawValue: "compile path lost did-you-mean for chargePaymnt")
            )
        }
    }

    // MARK: - ParserTrace secret redaction

    @Test("mutation gate: trace sink redacts secrets before output")
    func traceSecretRedactionGate() {
        let cap = ParserTrace.capturing(categories: [.lowering])
        cap.trace.log(.lowering, "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9")
        cap.trace.log(.lowering, "api_key=supersecretvalue")
        cap.trace.log(.lowering, "password: hunter2")

        let joined = cap.lines().joined(separator: "\n")
        #expect(!joined.contains("eyJhbGciOiJIUzI1NiJ9"))
        #expect(!joined.contains("supersecretvalue"))
        #expect(!joined.contains("hunter2"))
        #expect(joined.contains("<redacted>"))
    }

    // MARK: - Diagnostic catalog linkage (DXTraceDiagnosticAuditTests)

    @Test("mutation gate: active DiagnosticCode entries exist in catalog")
    func activeDiagnosticCodesInCatalog() {
        #expect(DiagnosticCode.catalog.count == DiagnosticCode.all.count)
        for code in DiagnosticCode.all {
            guard let entry = DiagnosticCode.catalogByID[code.id] else {
                Issue.record("missing catalog entry for \(code.id)")
                continue
            }
            if entry.status == .active {
                #expect(!code.explanation.isEmpty)
                #expect(!entry.emitters.isEmpty)
            }
        }
    }

    // MARK: - Problem messages doc coverage

    @Test("mutation gate: docs/15_PROBLEM_MESSAGES.md lists every active code")
    func problemMessagesDocListsActiveCodes() throws {
        let docURL = repositoryRoot().appendingPathComponent("docs/15_PROBLEM_MESSAGES.md")
        let markdown = try String(contentsOf: docURL, encoding: .utf8)
        var missing: [String] = []
        for entry in DiagnosticCode.catalog where entry.status == .active {
            let token = "`\(entry.code.id)`"
            if !markdown.contains(token) {
                missing.append(entry.code.id)
            }
        }
        #expect(
            missing.isEmpty,
            Comment(rawValue: "docs/15_PROBLEM_MESSAGES.md missing active codes: \(missing.sorted().joined(separator: ", "))")
        )
    }

    // MARK: - Trace phase strings (remove-trace-phase sentinel)

    @Test("mutation gate: compile(_:) emits required post-lower timing phases")
    func requiredTracePhasesPresent() throws {
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        let examples = url.appendingPathComponent("examples")
        let mer = try String(
            contentsOf: examples.appendingPathComponent("order_processing.meridian"), encoding: .utf8)
        let cfg = try String(
            contentsOf: examples.appendingPathComponent("ecommerce.merconfig"), encoding: .utf8)

        let cap = ParserTrace.capturing(categories: [.timing, .codegen])
        _ = try Compiler(options: .init(trace: cap.trace)).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "order_processing.meridian")], vocabularies: [.init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)]))["order_processing.meridian"]!

        let joined = cap.lines().joined(separator: "\n")
        let required = [
            "traceIdentity.annotate:", "trace identity: annotated",
            "normIdStamp:", "norm id stamp: contract asserts stamped"
        ]
        let absent = required.filter { !joined.contains($0) }
        #expect(
            absent.isEmpty,
            Comment(rawValue: "missing timing phase strings (remove-trace-phase regression): \(absent)")
        )
    }
}
