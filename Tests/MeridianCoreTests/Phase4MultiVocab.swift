import Testing
import Foundation
@testable import MeridianCore

// MARK: - multi-vocabulary
//
// deliverable (docs/status.md):
//   "Multi-vocabulary — support `import` of multiple `.merconfig` files."
//
// These tests exercise the `Compiler.compile(_:)` entry point with a
// multi-vocabulary `CompilationUnit`. We don't depend on any on-disk fixture
// so the test stays focused on the merge + import-validation logic.

@Suite("Phase 4 Multi-vocab — merging .merconfig files")
struct Phase4MultiVocab {

    // MARK: - Fixtures

    /// Minimal vocabulary that defines a couple of kinds + a `validate`
    /// phrase. The phrase makes the workflow body resolvable end-to-end so
    /// the test fails on real merge bugs rather than on missing-symbol
    /// noise.
    private let coreConfig = """
    === vocabulary ===

    An order is a kind of thing.
    An order has an id.

    A customer is a kind of thing.
    A customer has an id.

    To validate an order:
      emit order.validated with id = the order's id.

    === tools ===

    validate order
      method: validateOrder
      returns: ValidationResult.
    """

    /// Second vocabulary supplying constants. The merge-success test asserts
    /// these constants appear in the generated `Constants` struct.
    private let shippingConfig = """
    === constants ===

    The shipping threshold is $25.
    The default carrier is "ups".
    """

    /// A workflow that imports both vocabularies. Body uses only the `core`
    /// phrase; the merge is what gives the workflow access to the
    /// `shipping` constants in codegen.
    private let workflow = """
    ---
    vocabulary: core, shipping
    ---

    To process an order placed by a customer:
      validate the order.
      complete.
    """

    // MARK: - Tests

    @Test("two .merconfig inputs merge into a single symbol table")
    func mergesTwoVocabularies() throws {
        let vocabs: [Compiler.VocabularyInput] = [
            .init(name: "core",     file: "core.merconfig",     source: coreConfig),
            .init(name: "shipping", file: "shipping.merconfig", source: shippingConfig),
        ]
        let opts = Compiler.Options(
            emitterOptions: .init(emitSourceLineComments: false)
        )
        let swift = try Compiler(options: opts).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: workflow, file: "workflow.meridian")], vocabularies: vocabs))["workflow.meridian"]!.swift

        // Constants from `shipping` and the kind from `core` both made it
        // into the merged config.
        #expect(swift.contains("public struct Constants: Sendable"))
        #expect(swift.contains("shippingThreshold"))
        #expect(swift.contains("public struct Order"))
    }

    @Test("frontmatter vocabulary entry that names no supplied vocabulary is rejected")
    func unknownImportFails() {
        let vocabs: [Compiler.VocabularyInput] = [
            .init(name: "core", file: "core.merconfig", source: coreConfig)
        ]
        let workflow = """
        ---
        vocabulary: core, nonexistent
        ---

        To process an order placed by a customer:
            validate the order.
            complete.
        """
        #expect(throws: CompilerError.self) {
            _ = try Compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: workflow, file: "workflow.meridian")], vocabularies: vocabs))["workflow.meridian"]!.swift
        }
    }

    @Test("duplicate kind across vocabularies is rejected")
    func duplicateKindFails() {
        let dupCore = """
        === vocabulary ===

        An order is a kind of thing.
        An order has an id.
        """
        let dupOther = """
        === vocabulary ===

        An order is a kind of thing.
        """
        let vocabs: [Compiler.VocabularyInput] = [
            .init(name: "core",  file: "core.merconfig",  source: dupCore),
            .init(name: "extra", file: "extra.merconfig", source: dupOther),
        ]
        let workflow = """
        ---
        vocabulary: core, extra
        ---

        To process an order placed by a customer:
            validate the order.
            complete.
        """
        #expect(throws: CompilerError.self) {
            _ = try Compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: workflow, file: "workflow.meridian")], vocabularies: vocabs))["workflow.meridian"]!.swift
        }
    }

    @Test("merging LanguageSynonyms entries prefers the other side on key collision")
    func languageSynonymDictMergeConflictsPreferOther() throws {
        let base = MerConfigFile(languageSynonyms: LanguageSynonyms(entries: [
            .duration: [.duration("tick", .second)],
            .superlative: [.superlative("biggest", .largest)],
            .fenceTool: [.mapping("python", "python.run")],
        ]))
        let overlay = MerConfigFile(languageSynonyms: LanguageSynonyms(entries: [
            .duration: [.duration("tick", .minute)],
            .superlative: [.superlative("biggest", .smallest)],
            .fenceTool: [.mapping("python", "interpreter.run")],
        ]))

        let merged = try base.merging(overlay)

        #expect(merged.languageSynonyms.entries[.duration] == [.duration("tick", .minute)])
        #expect(merged.languageSynonyms.entries[.superlative] == [.superlative("biggest", .smallest)])
        #expect(merged.languageSynonyms.entries[.fenceTool] == [.mapping("python", "interpreter.run")])
    }

    @Test("duplicate vocabulary name (same logical import) is rejected")
    func duplicateVocabNameFails() {
        let vocabs: [Compiler.VocabularyInput] = [
            .init(name: "core", file: "core.merconfig",  source: coreConfig),
            .init(name: "core", file: "core2.merconfig", source: coreConfig),
        ]
        #expect(throws: CompilerError.self) {
            _ = try Compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: workflow, file: "workflow.meridian")], vocabularies: vocabs))["workflow.meridian"]!.swift
        }
    }
}
