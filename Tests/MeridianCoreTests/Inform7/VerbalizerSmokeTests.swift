import Foundation
import Testing
@testable import MeridianCore

@Suite("Wave 7 verbalizer smoke")
struct VerbalizerSmokeTests {
    private let cfg = """
    === vocabulary ===
    An order is a kind of thing.
    An order has a score, which is Number.
    A page is a kind of thing.
    A page has a summary, which is String.

    === tools ===
    Demo Tool
    =========
    ~ demoTool(value: Number) : String
    """

    @Test("canonical source re-parses to structurally equal IR")
    func roundTripBasics() throws {
        let source = """
        ---
        vocabulary: test.merconfig
        ---
        Definition: a page is stale if its summary is empty.

        To validate an order:
          bind score = 1.
          assert score equals 1.
          if score equals 1,
            invoke demo tool with value = score.
          complete.
        """
        let compiler = Compiler(options: .init(trace: .silent()))
        let vocab = [Compiler.VocabularyInput(name: "test", file: "test.merconfig", source: cfg)]
        let first = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: source, file: "test.meridian")], vocabularies: vocab))["test.meridian"]!.model
        let canonical = try Verbalizer(model: first).verbalize()
        let second = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: canonical, file: "canonical.meridian")], vocabularies: vocab))["canonical.meridian"]!.model

        #expect(IREquality.structurallyEqual(first.workflows, second.workflows), Comment(rawValue: canonical))
        #expect(first.loweredDefinitions.count == 1)
        #expect(second.loweredDefinitions.count == 1)
        #expect(canonical.contains("Definition: a page is stale if"))
        #expect(canonical.contains("invoke demoTool with value = score."))
    }

    @Test("drift diff classifies unchanged lines away")
    func driftBasic() {
        let report = DriftEngine.diff(
            authored: "assert score is greater than 1.\ncomplete.",
            canonical: "assert score is more than 1.\ncomplete."
        )
        #expect(report.hunks.count == 1)
        #expect(report.counts[.synonymCanonicalized] == 1)
    }
}
