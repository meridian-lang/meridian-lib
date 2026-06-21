import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

/// Each former silent compile-time fallback is now a coded diagnostic. These
/// tests assert the *code* (the durable contract), not the message text.
@Suite("NoSilentFallback")
struct NoSilentFallbackTests {

    /// Compile and return the set of diagnostic codes thrown (empty if it
    /// compiled clean).
    private func codes(_ mer: String, _ cfg: String,
                       fallbacks: FallbackPolicy = .strict,
                       merFile: String = "t.meridian",
                       cfgFile: String = "t.merconfig") -> Set<String> {
        do {
            _ = try Compiler(options: .init(fallbackPolicy: fallbacks)).compile(
                meridianSource: mer, meridianFile: merFile,
                merconfigSource: cfg, merconfigFile: cfgFile)
            return []
        } catch let e as CompilerError {
            return Set(e.diagnostics.map(\.code.id))
        } catch {
            return ["<non-compiler-error>"]
        }
    }

    private func codesMerOnly(_ mer: String, fallbacks: FallbackPolicy = .strict) -> Set<String> {
        do {
            _ = try Compiler(options: .init(fallbackPolicy: fallbacks)).compile(
                meridianSource: mer, meridianFile: "t.meri", vocabularies: [])
            return []
        } catch let e as CompilerError {
            return Set(e.diagnostics.map(\.code.id))
        } catch {
            return ["<non-compiler-error>"]
        }
    }

    private let cfg = """
    === vocabulary ===

    An order is a kind of thing.

    === tools ===

    Charge Payment
    ==============
    ~ chargePayment(order: Order) : Order
    """

    @Test("unknown tool is MER2002 (was: invoke that failed only at runtime)")
    func unknownTool() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          invoke chargePaymnt with order = the order.
        """
        #expect(codes(mer, cfg).contains("MER2002"))
    }

    @Test("unknown tool downgraded by allow-fallbacks: unknown-tools")
    func unknownToolFallback() {
        let mer = """
        ---
        vocabulary: t.merconfig
        allow-fallbacks: unknown-tools
        ---
        To process an order:
          invoke chargePaymnt with order = the order.
        """
        #expect(!codes(mer, cfg).contains("MER2002"))
    }

    @Test("a declared tool with the right spelling compiles clean")
    func declaredToolClean() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          invoke chargePayment with order = the order.
        """
        #expect(codes(mer, cfg).isEmpty)
    }

    @Test("unresolved phrase is MER2001 (was: _unresolved placeholder)")
    func unresolvedPhrase() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          frobnicate the gizmo using the order.
        """
        let c = codes(mer, cfg)
        #expect(c.contains("MER2001") || c.contains("MER2002"),
                Comment(rawValue: "expected an unresolved phrase/tool code, got \(c.sorted())"))
    }

    @Test("unresolved phrase downgraded by allow-fallbacks: unresolved-phrases")
    func unresolvedPhraseFallback() {
        let mer = """
        ---
        vocabulary: t.merconfig
        allow-fallbacks: unresolved-phrases, unknown-tools
        ---
        To process an order:
          frobnicate the gizmo using the order.
        """
        #expect(!codes(mer, cfg).contains("MER2001"))
    }

    @Test("orphaned fenced code block is MER1002")
    func orphanedCodeBlock() {
        let mer = """
        ---
        name: orphan block
        ---
        ## Phases
        ```
        echo hi
        ```
        complete.
        """
        #expect(codesMerOnly(mer).contains("MER1002"))
    }

    @Test("malformed bind assignment is MER1003 not MER2001")
    func malformedBind() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          bind total
          complete.
        """
        #expect(codes(mer, cfg).contains("MER1003"))
    }

    @Test("ordinary unknown natural language stays MER2001 with guidance")
    func ordinaryPhraseNotMER1003() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          frobnicate the gizmo using the order.
        """
        let c = codes(mer, cfg)
        #expect(c.contains("MER2001"))
        #expect(!c.contains("MER1003"))
    }

    @Test("unknown merconfig section is MER5010")
    func unknownMerconfigSection() {
        let badCfg = """
        === widgets ===
        A widget is a kind of thing.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        complete.
        """
        #expect(codes(mer, badCfg).contains("MER5010"))
    }

    @Test("malformed tool declaration is MER5002")
    func malformedToolDeclaration() {
        let badCfg = """
        === tools ===

        Broken Tool
        ==============
        -- missing signature line
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        complete.
        """
        #expect(codes(mer, badCfg).contains("MER5002"))
    }

    @Test("misplaced frontmatter is MER1006")
    func misplacedFrontmatter() {
        let mer = """
        To do something:
          complete.
        ---
        name: late
        ---
        """
        #expect(codesMerOnly(mer).contains("MER1006"))
    }

    @Test("removed body import is MER1008")
    func removedImport() {
        let mer = """
        import vocabulary from "t.merconfig".
        To do something:
          complete.
        """
        #expect(codes(mer, cfg).contains("MER1008"))
    }

    @Test("warnings-only DiagnosticEngine does not throw")
    func warningsDoNotFailCompile() {
        let engine = DiagnosticEngine(trace: .silent())
        engine.report(Diagnostic.warning(.swiftFormatFailed, message: "cosmetic",
                                         range: SourceRange(file: "x.swift", line: 1, column: 1)))
        var threw = false
        do { try engine.throwIfErrors() } catch { threw = true }
        #expect(!threw)
    }
}
