import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Targeted coverage for `Compiler.swift` entry points and bootstrap branches
// that the example corpus doesn't reach directly (Phase-2 emit, manifest
// wrapper, no-vocab compile, duplicate rulebook, unknown allow-fallbacks token).

@Suite("Compiler — entry point and bootstrap coverage")
struct CompilerCoverageTests {

    @Test("emit(workflows:) lowers IR to Swift without parsing")
    func emitFromIR() throws {
        let wf = IRWorkflow(
            name: "run",
            parameters: [],
            body: IRBlock(statements: [.complete(CompleteIR(reason: "ok"))])
        )
        let swift = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false)
        )).emit(workflows: [wf])
        #expect(swift.contains("struct Run"))
        #expect(swift.contains("WorkflowResult"))
    }

    @Test("emitManifest delegates to ManifestEmitter")
    func emitManifestWrapper() throws {
        let wf = IRWorkflow(name: "run", parameters: [], body: IRBlock(statements: []))
        let input = ManifestEmitter.Input(workflows: [wf])
        let json = try Compiler().emitManifest(input)
        #expect(json.contains("\"workflows\""))
    }

    @Test("compile without a merconfig uses an empty vocabulary list")
    func compileWithoutMerconfig() throws {
        let swift = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false)
        )).compile(
            meridianSource: """
            To run:
              complete with reason "ok".
            """,
            meridianFile: "t.meridian"
        )
        #expect(swift.contains("struct"))
    }

    @Test("duplicate rulebook names are rejected at bootstrap")
    func duplicateRulebookNameFails() {
        let emptyRules = "=== sections ===\n"
        #expect(throws: CompilerError.self) {
            _ = try Compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: "To run:\n  complete.\n", file: "t.meridian")], vocabularies: [], rulebooks: [ RulebookInput(name: "shared", file: "a.merrules", source: emptyRules), RulebookInput(name: "shared", file: "b.merrules", source: emptyRules), ]))["t.meridian"]!.swift
        }
    }

    @Test("an unknown allow-fallbacks token is reported through the batch engine")
    func unknownAllowFallbacksTokenReports() throws {
        let caught = #expect(throws: CompilerError.self) {
            _ = try Compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: """
                ---
                allow-fallbacks: unresolved-phrases, not-a-real-kind
                ---
                To run:
                  complete.
                """, file: "t.meridian")], vocabularies: []))["t.meridian"]!.swift
        }
        let err = try #require(caught)
        #expect(err.diagnostics.contains { $0.code == .unknownFallbackKind })
    }

    private static let listPagesToolCfg = """
    === vocabulary ===
    A page is a kind of thing.
    === tools ===

    List Pages
    ==========
    ~ listPages(owner: String) : List
    """

    @Test("scoped frontmatter tools resolve exact and display-name tokens")
    func scopedToolsResolveDeclaredTools() throws {
        let swift = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false)
        )).compile(
            meridianSource: """
            ---
            vocabulary: t.merconfig
            tools: listPages, List Pages
            with discretion
            ---
            To run:
              use judgment to triage:
                check pages.
            """,
            meridianFile: "t.meridian",
            merconfigSource: Self.listPagesToolCfg,
            merconfigFile: "t.merconfig"
        )
        #expect(swift.contains("listPages"))
        #expect(swift.contains("scopedTools"))
    }

    @Test("vocabulary frontmatter with no supplied configs is rejected")
    func unknownVocabularyWithEmptyHostFails() {
        #expect(throws: CompilerError.self) {
            _ = try Compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: """
                ---
                vocabulary: missing.merconfig
                ---
                To run:
                  complete.
                """, file: "t.meridian")], vocabularies: []))["t.meridian"]!.swift
        }
    }

    @Test("vocabulary frontmatter must match a supplied config name")
    func unknownVocabularyNameFails() {
        let caught = #expect(throws: CompilerError.self) {
            _ = try Compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: """
                ---
                vocabulary: other.merconfig
                ---
                To run:
                  complete.
                """, file: "t.meridian")], vocabularies: [ .init(name: "t", file: "t.merconfig", source: "=== vocabulary ===\nA thing is a kind of thing.\n"), ]))["t.meridian"]!.swift
        }
        let err = try? #require(caught)
        #expect(err?.diagnostics.contains { $0.code == .unknownVocabulary } == true)
    }

    @Test("rulebook frontmatter must match a supplied rulebook input")
    func unknownRulebookReferenceFails() {
        let caught = #expect(throws: CompilerError.self) {
            _ = try Compiler().compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: """
                ---
                vocabulary: t.merconfig
                rulebook: missing.merrules
                ---
                To run:
                  complete.
                """, file: "t.meridian")], vocabularies: [ .init(name: "t", file: "t.merconfig", source: "=== vocabulary ===\nA thing is a kind of thing.\n"), ], rulebooks: []))["t.meridian"]!.swift
        }
        let err = try? #require(caught)
        #expect(err?.diagnostics.contains { $0.code == .unknownRulebook } == true)
    }

    @Test("ambiguous usually defaults across enum properties are rejected")
    func ambiguousEnumDefaultFails() {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        A page can be archived or shared.
        A page can be live or shared.
        A page is usually shared.
        """
        #expect(throws: CompilerError.self) {
            _ = try Compiler().compile(
                meridianSource: """
                ---
                vocabulary: t.merconfig
                ---
                To run:
                  complete.
                """,
                meridianFile: "t.meridian",
                merconfigSource: cfg,
                merconfigFile: "t.merconfig"
            )
        }
    }
}
