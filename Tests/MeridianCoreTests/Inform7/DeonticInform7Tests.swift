import Foundation
import Testing
@testable import MeridianCore

@Suite("Deontic Inform7 semantics (Wave 9A)")
struct DeonticInform7Tests {
    private let analyzer = RuleAnalyzer(symbols: nil)

    private let cfg = """
    === vocabulary ===
    A customer is a kind of thing.
    A service is a kind of thing.
    A service has a text called the status.
    """

    private func requireDiagnostic(
        mer: String,
        code: DiagnosticCode
    ) throws -> Diagnostic {
        do {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: mer,
                meridianFile: "test.meridian",
                merconfigSource: cfg,
                merconfigFile: "test.merconfig"
            )
            Issue.record("expected \(code.id)")
            throw CompilerError.codegenError(message: "expected \(code.id)")
        } catch let error as CompilerError {
            guard let diagnostic = error.diagnostics.first(where: { $0.code == code }) else {
                Issue.record("expected \(code.id), got \(error.diagnostics.map(\.code.id))")
                throw CompilerError.codegenError(message: "missing \(code.id)")
            }
            return diagnostic
        }
    }

    @Test("SEM_7_01 deontic compliance is trace-defined (prohibition lowers)")
    func sem701() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          invoke time.now.
          complete.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: mer,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains("recordViolation"))
    }

    @Test("SEM_7_02 prohibitions are attempt-time guards")
    func sem702() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          invoke time.now.
          complete.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: mer,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains("prevented"))
    }

    @Test("SEM_7_03 may invoke permission parses to deontic permission")
    func sem703() throws {
        let rule = RuleAST(text: "A customer may invoke time.now.", sourceLine: 4)
        guard let parsed = try analyzer.classify(rule) else {
            Issue.record("expected ParsedRule")
            return
        }
        if case .deonticPermission(let norm) = parsed {
            #expect(norm.actionPattern?.toolID == "timeNow")
        } else {
            Issue.record("expected deonticPermission, got \(parsed)")
        }
    }

    @Test("SEM_7_04 same-scope conflict is compile-time")
    func sem704() throws {
        _ = try requireDiagnostic(
            mer: """
            ---
            vocabulary: test.merconfig
            ---
            A customer must not invoke time.now.
            A customer may invoke time.now.

            To notify a customer:
              complete.
            """,
            code: .deonticSameScopeConflict
        )
    }

    @Test("SEM_7_05 obligation must hold lowers assert metadata")
    func sem705() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A service is healthy must hold.

        To inspect a service:
          commit.
          complete.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: mer,
            meridianFile: "test.meridian",
            merconfigSource: cfg,
            merconfigFile: "test.merconfig"
        )
        #expect(out.contains("runtime.assert"))
        #expect(out.contains("must hold"))
    }

    @Test("MER_DEO_001 same-scope prohibition and permission conflict")
    func merDeo001() throws {
        let diagnostic = try requireDiagnostic(
            mer: """
            ---
            vocabulary: test.merconfig
            ---
            A customer must not invoke time.now.
            A customer may invoke time.now.

            To notify a customer:
              complete.
            """,
            code: .deonticSameScopeConflict
        )
        #expect(diagnostic.message.contains("prohibition and permission overlap"))
    }

    @Test("MER_DEO_002 sticky deny for nested scopes")
    func merDeo002() {
        let prohibition = NormIR(
            id: "outer",
            kind: .prohibition,
            scope: .skill,
            actionPattern: ActionPatternIR(toolID: "time.now"),
            sourceRange: .unknown,
            originalText: "must not invoke time.now"
        )
        let permission = NormIR(
            id: "inner",
            kind: .permission,
            scope: .workflow("Notify"),
            actionPattern: ActionPatternIR(toolID: "time.now"),
            sourceRange: .unknown,
            originalText: "may invoke time.now"
        )
        let diagnostics = DeonticLowering.detectConflicts([prohibition, permission])
        #expect(diagnostics.contains { $0.code == .deonticStickyDeny })
    }

    @Test("MER_DEO_003 rejects should modal")
    func merDeo003() throws {
        let diagnostic = try requireDiagnostic(
            mer: """
            ---
            vocabulary: test.merconfig
            ---
            A customer should invoke time.now.

            To notify a customer:
              complete.
            """,
            code: .deonticNonNormModal
        )
        #expect(diagnostic.message.contains("non-norm modal"))
    }

    @Test("MER_DEO_004 rejects invoke outside permission set")
    func merDeo004() throws {
        let diagnostic = try requireDiagnostic(
            mer: """
            ---
            vocabulary: test.merconfig
            ---
            A customer may invoke time.now.

            To notify a customer:
              invoke time.format.
              complete.
            """,
            code: .deonticToolOutsidePermissions
        )
        #expect(diagnostic.message.contains("time.format") || diagnostic.message.contains("timeFormat"))
        #expect(diagnostic.message.contains("not covered"))
    }

    @Test("MER_DEO_005 rejects outcome-as-action")
    func merDeo005() throws {
        let diagnostic = try requireDiagnostic(
            mer: """
            ---
            vocabulary: test.merconfig
            ---
            A workflow must not fail.

            To notify a customer:
              complete.
            """,
            code: .deonticOutcomeAsAction
        )
        #expect(diagnostic.message.contains("outcome phrasing"))
    }

    @Test("legacy must-not participle still classifies as invariant")
    func legacyMustNotParticiple() throws {
        let rule = RuleAST(text: "A customer with status suspended must not place orders.", sourceLine: 8)
        guard let parsed = try analyzer.classify(rule) else {
            Issue.record("expected ParsedRule")
            return
        }
        if case .invariant = parsed {
            // expected legacy shape
        } else {
            Issue.record("expected .invariant, got \(parsed)")
        }
    }
}
