import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

/// Focused acceptance tests for observability DX fault-injection paths.
/// Broader coverage lives in `SuggesterTests`, `DiagnosticTests`,
/// `NoSilentFallbackTests`, and `ParserTraceSpanConcurrencyTests`.
@Suite("ObservabilityFaultInjection")
struct ObservabilityFaultInjectionTests {

    // MARK: - Did-you-mean ambiguity

    @Test("equal-distance near-misses surface alternates, not a single suggestion")
    func ambiguousSuggestionsEqualDistance() {
        let d = Diagnostic.unresolved(
            .unknownTool,
            target: "paymnt",
            among: ["payment", "paymet"],
            range: SourceRange(file: "t.meridian", line: 1, column: 1),
            noun: "tool")
        #expect(d.suggestions.isEmpty)
        let note = d.notes.first?.message ?? ""
        #expect(note.contains("payment"))
        #expect(note.contains("paymet"))
        #expect(Suggester().closestAmbiguous("paymnt", among: ["payment", "paymet"])?.alternates.isEmpty == false)
    }

    // MARK: - Duplicate diagnostic prevention

    @Test("recovering does not double-report lowering diagnostics")
    func duplicateDiagnosticPrevention() throws {
        let engine = DiagnosticEngine()
        let r = SourceRange(file: "t.meridian", line: 1, column: 1)
        let diag = Diagnostic.error(.unresolvedPhrase, message: "unknown phrase", range: r, help: "fix it")
        _ = try engine.recovering(context: "workflow test") {
            throw CompilerError.diagnostics([diag])
        }
        let matches = engine.diagnostics.filter { $0.code == .unresolvedPhrase && $0.message == "unknown phrase" }
        #expect(matches.count == 1)
    }

    // MARK: - Explicit allow-fallbacks visibility

    private let cfg = """
    === vocabulary ===

    An order is a kind of thing.

    === tools ===

    Charge Payment
    ==============
    ~ chargePayment(order: Order) : Order
    """

    @Test("allow-fallbacks: unknown-tools emits warning and lowering trace line")
    func explicitAllowFallbacksEmitsWarningAndTrace() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        allow-fallbacks: unknown-tools
        ---
        To process an order:
          invoke chargePaymnt with order = the order.
        """
        let cap = ParserTrace.capturing(categories: [.diagnostics, .lowering])
        _ = try Compiler(options: .init(trace: cap.trace)).compile(
            meridianSource: mer,
            meridianFile: "t.meridian",
            merconfigSource: cfg,
            merconfigFile: "t.merconfig")
        let lines = cap.lines()
        #expect(lines.contains {
            $0.contains("warning MER2002")
                && $0.contains("unknown tool allowed by fallback")
        })
        #expect(lines.contains { $0.contains("fallback") || $0.contains("allow-fallbacks") })
    }

    // MARK: - DiagnosticRenderer JSON

    @Test("renderJSON is throwing and round-trips a representative diagnostic")
    func renderJSONThrowingContract() throws {
        let d = Diagnostic.unresolved(
            .unknownTool,
            target: "x",
            among: ["y"],
            range: SourceRange(file: "t.meridian", line: 1, column: 1),
            noun: "tool")
        let json = try DiagnosticRenderer().renderJSON([d])
        let data = Data(json.utf8)
        let arr = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        #expect(arr.count == 1)
        #expect(arr[0]["code"] as? String == DiagnosticCode.unknownTool.id)
    }

    // MARK: - Malformed IR → MER4002

    @Test("malformed IR reports MER4002 with non-empty catalog help")
    func malformedIRMer4002WithHelp() {
        do {
            try IRValidator.validate(IRExpression.logical(.and, []), sourceFile: "invalid.ir")
            Issue.record("expected invalidIR")
        } catch IRValidationError.diagnostics(let diagnostics) {
            let invalid = diagnostics.first { $0.code == .invalidIR }
            #expect(invalid != nil)
            #expect(invalid?.help?.isEmpty == false)
            #expect(invalid?.phase == "validation")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}
