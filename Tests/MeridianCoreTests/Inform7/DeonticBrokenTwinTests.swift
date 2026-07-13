import Foundation
import Testing
@testable import MeridianCore

/// Broken Twin Part C lines 8+ (deontic) and the ordered aggregate snapshot for
/// lines 1–12 from `docs/cookbook/MERIDIAN_NORTHSTAR_EXAMPLE.md`.
@Suite("BrokenTwin deontic diagnostics")
struct DeonticBrokenTwinTests {
    private let deonticCfg = """
    === vocabulary ===
    A customer is a kind of thing.
    A service is a kind of thing.
    """

    private let brokenTwinLine8Mer = """
    ---
    vocabulary: test.merconfig
    ---
    A customer must not invoke time.now.
    A customer may invoke time.now.

    To notify a customer:
      complete.
    """

    private func requireDiagnostic(
        merBody: String,
        cfg: String,
        code: DiagnosticCode
    ) throws -> Diagnostic {
        let diagnostics = try requireDiagnostics(merBody, cfg: cfg)
        guard let diagnostic = diagnostics.first(where: { $0.code == code }) else {
            Issue.record("expected \(code.id), got \(diagnostics.map(\.code.id))")
            throw CompilerError.codegenError(message: "missing \(code.id)")
        }
        return diagnostic
    }

    private func requireDiagnostics(_ merBody: String, cfg: String) throws -> [Diagnostic] {
        do {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: merBody,
                meridianFile: "test.meridian",
                merconfigSource: cfg,
                merconfigFile: "test.merconfig"
            )
            Issue.record("expected diagnostics")
            throw CompilerError.codegenError(message: "expected diagnostics")
        } catch let error as CompilerError {
            return error.diagnostics
        }
    }

    private func requireExpressionDiagnostic(_ expression: String, code: DiagnosticCode) throws {
        let parsed = ExpressionParser(trace: .silent()).parse(expression)
        guard case .malformed(_, let actualCode, _, _) = parsed else {
            Issue.record("expected malformed expression for \(code.id), got \(parsed)")
            throw CompilerError.codegenError(message: "expected malformed expression \(code.id)")
        }
        #expect(actualCode == code)
    }

    @Test("NS-C-08 Broken Twin line 8 reports MER-DEO-001 on both spans")
    func brokenTwin8SameScopeConflict() throws {
        let diagnostics = try requireDiagnostics(brokenTwinLine8Mer, cfg: deonticCfg)
        let conflicts = diagnostics.filter { $0.code == .deonticSameScopeConflict }
        #expect(conflicts.count == 2, Comment(rawValue: "expected both spans flagged, got \(conflicts)"))
        #expect(conflicts.allSatisfy { $0.message.contains("prohibition and permission overlap") })
    }

    @Test("Broken Twin lines 1-12 aggregate diagnostic codes in north-star order")
    func brokenTwinLines1Through12AggregateSnapshot() throws {
        let retentionCfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.
        A service is keyed by the name.

        === trace ===
        retention: 30 days
        """

        let domainCfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page can be archived or live.
        A page is usually live.
        A page is usually archived.
        """

        let dealCfg = """
        === vocabulary ===
        A deal is a kind of thing.
        A deal has a text called the status.
        """

        let serviceCfg = """
        === vocabulary ===
        A service is a kind of thing.
        """

        struct Case {
            let label: String
            let cfg: String
            let body: String
            let expected: DiagnosticCode
        }

        let cases: [Case] = [
            Case(
                label: "line 1 bare perfect",
                cfg: retentionCfg,
                body: """
                To inspect a service:
                  if the deploy step has failed,
                    complete.
                """,
                expected: .traceBarePerfect
            ),
            Case(
                label: "line 2 window exceeds retention",
                cfg: retentionCfg,
                body: """
                To inspect a service:
                  if the deploy step has failed within the last 90 days,
                    complete.
                """,
                expected: .traceWindowExceedsRetention
            ),
            Case(
                label: "line 3 causal since expression",
                cfg: retentionCfg,
                body: """
                To inspect a service:
                  if the build step failed since the last deploy step succeeded,
                    complete.
                """,
                expected: .traceCausalSince
            ),
            Case(
                label: "line 4 vague recently definition",
                cfg: retentionCfg,
                body: """
                Definition: a service is flaky if the deploy step has failed recently.

                To inspect a service:
                  complete.
                """,
                expected: .traceRecently
            ),
            Case(
                label: "line 5 future tense definition",
                cfg: retentionCfg,
                body: """
                Definition: a deploy is risky if the deploy step will fail.

                To inspect a service:
                  complete.
                """,
                expected: .traceFuture
            ),
            Case(
                label: "line 6 missing unknown arm on branch",
                cfg: retentionCfg,
                body: """
                Definition: a service is stale if the deploy step has ever failed.

                To inspect a service:
                  if the service is stale since the last deploy step succeeded,
                    let the note be "missing fallback".
                """,
                expected: .traceMissingUnknownArm
            ),
            Case(
                label: "line 7 blocking obligation without default policy",
                cfg: retentionCfg,
                body: """
                Definition: a service is stale if the deploy step has ever failed.

                To inspect a service:
                  assert the service is stale since the last deploy step succeeded.
                """,
                expected: .traceMissingUnknownArm
            ),
            Case(
                label: "line 8 same-scope deontic conflict",
                cfg: deonticCfg,
                body: brokenTwinLine8Mer,
                expected: .deonticSameScopeConflict
            ),
            Case(
                label: "line 9 effectful judgment without produced value",
                cfg: serviceCfg,
                body: """
                ---
                vocabulary: test.merconfig
                ---
                To triage alerts:
                  use judgment to clean up old alerts:
                    Remove stale items from the queue.
                """,
                expected: .judgmentWithoutProducedValue
            ),
            Case(
                label: "line 10 ungraded superlative bind",
                cfg: serviceCfg,
                body: """
                ---
                vocabulary: test.merconfig
                ---
                To rank services:
                  let the best service be the best service.
                """,
                expected: .descriptionSuperlativeNeedsProperty
            ),
            Case(
                label: "line 11 vague whose-clause hedge",
                cfg: dealCfg,
                body: """
                ---
                vocabulary: test.merconfig
                ---
                To scan deals:
                  for each deal whose status looks active:
                    complete.
                """,
                expected: .conditionUnknownComparator
            ),
            Case(
                label: "line 12 contradictory domain defaults",
                cfg: domainCfg,
                body: """
                ---
                vocabulary: test.merconfig
                ---
                To archive a page:
                  complete.
                """,
                expected: .domainContradictoryDefault
            ),
        ]

        var observed: [String] = []
        for item in cases {
            let diagnostics = try requireDiagnostics(item.body, cfg: item.cfg)
            guard let first = diagnostics.first(where: { $0.code == item.expected }) else {
                Issue.record("\(item.label): expected \(item.expected.id), got \(diagnostics.map(\.code.id))")
                continue
            }
            observed.append(first.code.id)
        }

        let expectedIDs = cases.map(\.expected.id)
        #expect(observed == expectedIDs, Comment(rawValue: "aggregate snapshot mismatch:\nobserved: \(observed)\nexpected: \(expectedIDs)"))
    }
}
