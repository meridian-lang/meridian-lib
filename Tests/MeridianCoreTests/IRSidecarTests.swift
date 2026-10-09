import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

@Suite("IR sidecar and explain-swift")
struct IRSidecarTests {
    @Test("IR sidecar maps provenance comments to canonical statements")
    func sidecarExplainRoundTrip() throws {
        let mer = """
        To greet a customer:
          emit "hello".
        """
        let cfg = """
        === vocabulary ===
        A customer is a kind of thing.
        """
        let compiler = Compiler(options: .init())
        let compiled = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "greet.meridian")], vocabularies: [.init(name: "local", file: "local.merconfig", source: cfg)]))["greet.meridian"]!
        let model = compiled.model
        let swift = compiled.swift
        let sidecar = try IRSidecarEmitter().emit(
            workflows: model.workflows,
            verbalizer: Verbalizer(model: model),
            sourceFile: "greet.meridian",
            swiftFile: "greet.swift",
            sourceMap: Compiler.sourceMap(fromGeneratedSwift: swift)
        )
        let explanation = try ExplainSwiftRunner.explain(swiftSource: swift, sidecarJSON: sidecar)
        #expect(explanation.contains("[emit]:"))
        #expect(explanation.contains("emit"))
    }

    @Test("IRSidecarEmitter walks nested primitive bodies and sorts entries")
    func nestedPrimitiveSidecar() throws {
        let range = SourceRange(file: "nested.meridian", line: 2, column: 1)
        let inner = IRBlock(statements: [
            .complete(CompleteIR(sourceRange: SourceRange(file: "nested.meridian", line: 3, column: 1))),
        ])
        let body = IRBlock(statements: [
            .branch(BranchIR(
                condition: .predicate(.literal(.boolean(true))),
                thenBlock: inner,
                unknownBlock: inner,
                elseBlock: inner,
                sourceRange: range
            )),
            .iterate(IterateIR(
                mode: .whileCondition(.literal(.boolean(true))),
                body: inner,
                sourceRange: SourceRange(file: "nested.meridian", line: 4, column: 1)
            )),
            .assert(AssertIR(
                condition: .literal(.boolean(true)),
                otherwiseAction: inner,
                sourceRange: SourceRange(file: "nested.meridian", line: 5, column: 1)
            )),
            .recover(RecoverIR(
                pattern: .anyError,
                handler: inner,
                attachedTo: inner,
                sourceRange: SourceRange(file: "nested.meridian", line: 6, column: 1)
            )),
            .simultaneously(SimultaneouslyIR(
                branches: [inner, inner],
                sourceRange: SourceRange(file: "nested.meridian", line: 7, column: 1)
            )),
        ])
        let wf = IRWorkflow(name: "nested", parameters: [], body: body)
        let model = VerbalizerModel(
            workflows: [wf],
            loweredDefinitions: [],
            inlineDefinitions: [],
            symbols: SymbolTable.build(from: MerConfigFile()),
            lexicon: .default,
            sourceFileName: "nested.meridian",
            authoredSource: ""
        )
        let json = try IRSidecarEmitter().emit(
            workflows: [wf],
            verbalizer: Verbalizer(model: model),
            sourceFile: "nested.meridian",
            swiftFile: "nested.swift",
            sourceMap: [
                ManifestEmitter.SourceMapEntry(meridianLine: 2, swiftLine: 10),
                ManifestEmitter.SourceMapEntry(meridianLine: 4, swiftLine: 12),
            ]
        )
        #expect(json.contains("\"primitive\" : \"branch\""))
        #expect(json.contains("\"primitive\" : \"iterate\""))
        #expect(json.contains("\"primitive\" : \"assert\""))
        #expect(json.contains("\"primitive\" : \"recover\""))
        #expect(json.contains("\"primitive\" : \"simultaneously\""))
        #expect(json.contains("\"swift_line\" : 10"))
    }

    @Test("ExplainSwiftRunner surfaces missing mapping errors")
    func explainSwiftNoMappings() {
        let sidecar = """
        {"ir_version":"1","source_file":"t.meridian","swift_file":"t.swift","entries":[]}
        """
        #expect(throws: ExplainSwiftError.self) {
            try ExplainSwiftRunner.explain(swiftSource: "struct X {}", sidecarJSON: sidecar)
        }
    }
}
