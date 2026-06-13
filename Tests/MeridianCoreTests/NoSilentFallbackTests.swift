import Foundation
import Testing
@testable import MeridianCore

/// Each former silent compile-time fallback is now a coded diagnostic. These
/// tests assert the *code* (the durable contract), not the message text.
@Suite("NoSilentFallback")
struct NoSilentFallbackTests {

    /// Compile and return the set of diagnostic codes thrown (empty if it
    /// compiled clean).
    private func codes(_ mer: String, _ cfg: String,
                       fallbacks: FallbackPolicy = .strict) -> Set<String> {
        do {
            _ = try Compiler(options: .init(fallbackPolicy: fallbacks)).compile(
                meridianSource: mer, meridianFile: "t.meridian",
                merconfigSource: cfg, merconfigFile: "t.merconfig")
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
}
