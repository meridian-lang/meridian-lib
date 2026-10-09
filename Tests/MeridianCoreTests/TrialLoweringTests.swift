import Testing
@testable import MeridianCore
import MeridianRuntime

// Unit tests for the shared `TrialLowering` primitive (AGENTS.md Phase 1 item
// 1/2: real symbols + per-line trial-lowering as the oracle). These pin the
// 5-way `LineClass` scheme (`executable`/`checkable`/`annotationLabel`/
// `normativeNarrative`/`documentation`) that both `SkillMigrator`'s marking
// pass and the upcoming auto-split pass rely on.

@Suite("TrialLowering")
struct TrialLoweringTests {

    static let orderVocab = Compiler.VocabularyInput(
        name: "order", file: "order.merconfig",
        source: """
        === vocabulary ===

        To validate the order:
          invoke inventory.check.
        """
    )

    static func knowledge(vocab: Bool) throws -> Compiler.KnowledgeContext {
        try Compiler(options: .init(trace: .silent())).bootstrap(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: "", file: "<test>")], vocabularies: vocab ? [orderVocab] : []))
    }

    @Test("a whole-line command/fence line is always executable, independent of vocabulary")
    func commandOrFenceIsExecutable() throws {
        let trial = TrialLowering(knowledge: try Self.knowledge(vocab: false))
        let result = trial.classifyLine("`gbrain search foo`", isCommandOrFence: true, precedesExecutable: false)
        #expect(result == .executable)
    }

    @Test("a statement that trial-lowers with real vocabulary classifies as executable")
    func lowerableStatementIsExecutable() throws {
        let trial = TrialLowering(knowledge: try Self.knowledge(vocab: true))
        let result = trial.classifyLine("Validate the order.", isCommandOrFence: false, precedesExecutable: false)
        #expect(result == .executable)
    }

    @Test("the same statement without vocabulary is not executable")
    func unresolvedStatementIsNotExecutable() throws {
        let trial = TrialLowering(knowledge: try Self.knowledge(vocab: false))
        let result = trial.classifyLine("Validate the order.", isCommandOrFence: false, precedesExecutable: false)
        #expect(result != .executable)
    }

    @Test("a checkable predicate classifies as checkable even without vocabulary")
    func checkablePredicateIsCheckable() throws {
        let trial = TrialLowering(knowledge: try Self.knowledge(vocab: false))
        let result = trial.classifyLine("the order total is greater than 100", isCommandOrFence: false, precedesExecutable: false)
        #expect(result == .checkable)
    }

    @Test("a colon-terminated label immediately before an executable line is an annotation label")
    func labelBeforeExecutableIsAnnotation() throws {
        let trial = TrialLowering(knowledge: try Self.knowledge(vocab: false))
        let result = trial.classifyLine("Run the health check:", isCommandOrFence: false, precedesExecutable: true)
        #expect(result == .annotationLabel)
    }

    @Test("a colon-terminated label NOT before an executable line is not an annotation label")
    func labelNotBeforeExecutableIsNotAnnotation() throws {
        let trial = TrialLowering(knowledge: try Self.knowledge(vocab: false))
        let result = trial.classifyLine("Consider the following:", isCommandOrFence: false, precedesExecutable: false)
        #expect(result != .annotationLabel)
    }

    @Test("a must/never/always cue sentence that does not lower is normative narrative")
    func cueWordSentenceIsNormativeNarrative() throws {
        let trial = TrialLowering(knowledge: try Self.knowledge(vocab: false))
        let result = trial.classifyLine("Authors must never delete original SKILL.md files.",
                                        isCommandOrFence: false, precedesExecutable: false)
        #expect(result == .normativeNarrative)
    }

    @Test("plain prose with no cue words and no lowering path is documentation")
    func plainProseIsDocumentation() throws {
        let trial = TrialLowering(knowledge: try Self.knowledge(vocab: false))
        let result = trial.classifyLine("This section explains the overall design rationale.",
                                        isCommandOrFence: false, precedesExecutable: false)
        #expect(result == .documentation)
    }

    @Test("lowersAsStatement matches classifyLine's executable determination")
    func lowersAsStatementConsistentWithClassify() throws {
        let trial = TrialLowering(knowledge: try Self.knowledge(vocab: true))
        #expect(trial.lowersAsStatement("Validate the order."))
        #expect(!trial.lowersAsStatement(""))
    }

    // A bare `Definition:`-backed adjective quantifier check (e.g. "make sure
    // any X.") probes through `TrialLowering.probe`'s standalone
    // `ASTToIR.lowerBlock` call, which never runs the top-level `lower(_
    // file:)` setup that materializes `symbols.pendingDefinitions` into
    // `symbols.definitions`. Before the fix this spuriously failed with
    // "unknown adjective", demoting a real, compiler-lowerable "Check: any
    // <adjective> <plural>." line to documentation during migration (see
    // AGENTS.md pitfall — merconfig-declared adjectives must resolve inside
    // the probe too).
    static let productVocab = Compiler.VocabularyInput(
        name: "product", file: "product.merconfig",
        source: """
        === vocabulary ===
        A product is a kind of thing.
        A product has a quantity on hand, and a reorder point.
        Definition: a product is short if its quantity on hand is less than its reorder point.
        """
    )

    @Test("a checkable quantifier condition over a merconfig-declared adjective trial-lowers")
    func merconfigAdjectiveQuantifierIsCheckable() throws {
        let knowledge = try Compiler(options: .init(trace: .silent())).bootstrap(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: "", file: "<test>")], vocabularies: [Self.productVocab]))
        let trial = TrialLowering(knowledge: knowledge)
        #expect(trial.isCheckableCondition("any short products"))
        #expect(trial.lowersAsStatement("make sure any short products."))
    }

    @Test("custom Assertion synonyms: drive the checkable probe introducer")
    func customAssertionSynonymProbe() throws {
        let vocab = Compiler.VocabularyInput(name: "assert", file: "assert.merconfig", source: """
        === vocabulary ===
        A product is a kind of thing.
        A product has a quantity on hand, and a reorder point.
        Definition: a product is short if its quantity on hand is less than its reorder point.

        === language ===
        Assertion synonyms:
          verify that
        """)
        let knowledge = try Compiler(options: .init(trace: .silent())).bootstrap(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: "", file: "<test>")], vocabularies: [vocab]))
        #expect(knowledge.lexicon.assertionMarkers.first == "verify that")
        let trial = TrialLowering(knowledge: knowledge)
        #expect(trial.isCheckableCondition("any short products"))
    }

    @Test("failureOutcome maps compiler and non-compiler errors")
    func failureOutcomeCoverage() {
        struct ProbeError: Error {}
        let diagnostic = Diagnostic(
            code: .internalError,
            severity: .error,
            message: "boom",
            primaryRange: SourceRange(file: "<test>", line: 1, column: 1)
        )

        #expect(TrialLowering.failureOutcome(for: ProbeError()) == .failure([]))
        #expect(TrialLowering.failureOutcome(for: CompilerError.diagnostics([diagnostic])) == .failure([diagnostic]))
    }
}
