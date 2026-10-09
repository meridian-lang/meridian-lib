import Testing
@testable import MeridianCore

// Unit tests for the Phase 0 measurement-spike trial-lowering oracle. These
// exercise the two-tier probe directly (no CLI, no corpus) against small
// synthetic `.meri` fragments with a tiny vocabulary, so the classification
// contract is pinned independent of the real gbrain corpus's numbers.

@Suite("InertYieldAnalyzer")
struct InertYieldAnalyzerTests {

    static let vocab = Compiler.VocabularyInput(
        name: "test", file: "test.merconfig",
        source: """
        === vocabulary ===

        To validate the order:
          invoke inventory.check.
        """
    )

    static func analyzer() -> InertYieldAnalyzer {
        InertYieldAnalyzer(
            compiler: Compiler(options: .init()),
            vocabularies: [vocab]
        )
    }

    @Test("a whole inert section that already lowers is lowers-as-is")
    func wholeSectionLowersAsIs() throws {
        let source = """
        ## Setup

        ## Steps (( inert ))

        Validate the order.
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        let steps = try require(result.sections.first { $0.heading == "Steps" })
        #expect(steps.overall == .lowersAsIs, Comment(rawValue: "\(steps)"))
        #expect(steps.lines.isEmpty)
    }

    @Test("an unresolved imperative line is needs-phrase and records the phrase text")
    func needsPhraseRecordsTarget() throws {
        let source = """
        ## Steps (( inert ))

        Whisk the batter vigorously.
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        let steps = try require(result.sections.first { $0.heading == "Steps" })
        #expect(steps.overall == .needsPhrase, Comment(rawValue: "\(steps)"))
        let line = try require(steps.lines.first)
        #expect(line.yield == .needsPhrase)
        #expect(line.unresolvedPhrase == "Whisk the batter vigorously")
    }

    @Test("a mixed section (executable + narrative) is lowers-after-split")
    func mixedSectionLowersAfterSplit() throws {
        let source = """
        ## Steps (( inert ))

        This phase exists to keep the brain tidy over time.

        Validate the order.
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        let steps = try require(result.sections.first { $0.heading == "Steps" })
        #expect(steps.overall == .lowersAfterSplit, Comment(rawValue: "\(steps)"))
        let executableLine = steps.lines.first { $0.text.contains("Validate the order") }
        #expect(executableLine?.yield == .lowersAsIs)
    }

    @Test("a checkable-shaped but unresolvable condition is fuzzy")
    func checkableShapedIsfuzzy() throws {
        let source = """
        ## Contract (( inert, role: invariants ))

        The reviewer's judgment about tone quality is sound.
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        let contract = try require(result.sections.first { $0.heading == "Contract" })
        #expect(contract.overall != .lowersAsIs, Comment(rawValue: "\(contract)"))
    }

    @Test("a question-arrow fragment that fails to even parse is doc")
    func unparseableFragmentIsDoc() throws {
        // Mirrors the real gbrain corpus's `brain_taxonomist` classification
        // list shape: `<question>? -> <label>` numbered items don't match any
        // statement production, so they fail before phrase resolution is ever
        // attempted (a genuine parse failure, not an unresolved phrase).
        let source = """
        ## Philosophy (( inert ))

        5. Is it RAW MEDIA (article, video, book, PDF)? -> media-typed directory
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        let phil = try require(result.sections.first { $0.heading == "Philosophy" })
        #expect(phil.overall == .doc, Comment(rawValue: "\(phil)"))
    }

    @Test("a non-executable fenced code block line displays its decoded language and first body line")
    func codeBlockLineDisplaysDecodedSentinel() throws {
        let source = """
        ## Notes (( inert ))

        ```python
        print("hi")
        ```

        Some narrative line that also does not lower.
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        let notes = try require(result.sections.first { $0.heading == "Notes" })
        let codeLine = try require(notes.lines.first { $0.text.hasPrefix("```python") })
        #expect(codeLine.text.contains("print(\"hi\")"), Comment(rawValue: "\(notes)"))
        #expect(codeLine.text.hasSuffix("…```"), Comment(rawValue: "\(notes)"))
    }

    @Test("a per-line failure with an inference cue is bucketed as judgment even when it also reads as fuzzy")
    func fuzzyLineWithInferenceCueIsJudgmentBucket() throws {
        let source = """
        ## Contract (( inert, role: invariants ))

        The reviewer must decide whether the tone is sound.
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        let contract = try require(result.sections.first { $0.heading == "Contract" })
        let line = try require(contract.lines.first)
        #expect(line.p1Bucket == .judgment, Comment(rawValue: "\(contract)"))
    }

    @Test("a section with no content lines at all aggregates to doc, not a crash")
    func contentlessSectionAggregatesToDoc() throws {
        let source = """
        ## Contract (( inert, role: invariants ))

        > just a blockquote comment, no content
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        let contract = try require(result.sections.first { $0.heading == "Contract" })
        #expect(contract.overall == .doc, Comment(rawValue: "\(contract)"))
        #expect(contract.lines.isEmpty)
    }

    @Test("a normative-cue line with no inference cue is bucketed as error")
    func normativeNarrativeWithoutInferenceCueIsErrorBucket() throws {
        let source = """
        ## Contract (( inert, role: invariants ))

        The system must log every request.
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        let contract = try require(result.sections.first { $0.heading == "Contract" })
        let line = try require(contract.lines.first)
        #expect(line.p1Bucket == .error, Comment(rawValue: "\(contract)"))
    }

    @Test("a file with no inert sections yields no sections")
    func noInertSectionsYieldsEmpty() throws {
        let source = """
        ## Steps

        Validate the order.
        """
        let result = try Self.analyzer().analyze(source, file: "probe.meri")
        #expect(result.sections.isEmpty)
    }

    private func require<T>(_ value: T?, _ message: String = "expected non-nil") throws -> T {
        guard let value else { throw TestFailure(message) }
        return value
    }

    private struct TestFailure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }
}
