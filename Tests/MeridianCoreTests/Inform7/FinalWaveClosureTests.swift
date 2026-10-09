import Foundation
import Testing
@testable import MeridianCore

@Suite("Final Wave closure conformance")
struct FinalWaveClosureTests {
    @Test("SEM_3_01 commit lowers to checkpoint boundary without implicit rollback")
    func sem301CommitRecoverHonesty() throws {
        let out = try Compiler(options: .init()).compile(
            meridianSource: """
            ---
            vocabulary: t.merconfig
            ---
            To inspect a service:
              commit.
              invoke demo tool with value = 1.
              recover from any:
                complete with reason "handled".
            """,
            meridianFile: "commit.meridian",
            merconfigSource: """
            === vocabulary ===
            A service is a kind of thing.

            === tools ===
            Demo Tool
            =========
            ~ demoTool(value: Number) : String
            """,
            merconfigFile: "t.merconfig"
        )
        #expect(out.contains("runtime.checkpoint"), Comment(rawValue: out))
        #expect(out.contains("catch let _recoveredError"), Comment(rawValue: out))
        #expect(!out.contains("rollback"), Comment(rawValue: "no automatic external rollback"))
    }

    @Test("D11 unless and if not round-trip with authored-form metadata")
    func d11UnlessAndIfNotRoundTrip() throws {
        let unlessSource = """
        ---
        vocabulary: test.merconfig
        ---
        To guard a page:
          complete with reason "ok" unless the page's status equals "blocked".
        """
        let (_, unlessCanonical, _) = try VerbalizerTestSupport.canonicalRoundTrip(unlessSource)
        #expect(unlessCanonical.contains("unless"), Comment(rawValue: unlessCanonical))
        #expect(!unlessCanonical.contains("if not"), Comment(rawValue: "suffix unless must not rewrite to if not"))

        let ifNotSource = """
        ---
        vocabulary: test.merconfig
        ---
        To guard a page:
          if not the page's status equals "blocked",
            complete with reason "ok".
        """
        let (_, ifNotCanonical, _) = try VerbalizerTestSupport.canonicalRoundTrip(ifNotSource)
        #expect(ifNotCanonical.contains("if not"), Comment(rawValue: ifNotCanonical))
        #expect(!ifNotCanonical.contains("unless"), Comment(rawValue: "branch if not must not rewrite to unless"))
    }
}
