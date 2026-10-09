import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("one pipeline parity — model, manifest, and Swift agree")
struct CompilerPipelineParityTests {
    private let cfg = """
    === vocabulary ===
    A customer is a kind of thing.
    A service is a kind of thing.
    A service has a text called the status.
    """

    private let mer = """
    ---
    vocabulary: test.merconfig
    ---
    A customer must not invoke time.now.

    To notify a customer:
      assert the service's status is "ready".
      complete.
    """

    private var vocab: Compiler.VocabularyInput {
        .init(name: "test", file: "test.merconfig", source: cfg)
    }

    @Test("workflows, norms, and verbalizer model agree across compile paths")
    func compilePathsAgreeOnLoweredArtifacts() throws {
        let compiler = Compiler(options: .init())
        let model = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "parity.meri")], vocabularies: [vocab]))["parity.meri"]!.model
        let manifestResult = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "parity.meri")], vocabularies: [vocab]))["parity.meri"]!

        #expect(model.workflows.map(\.structName) == manifestResult.manifest.workflows.map(\.structName))
        #expect(model.workflows.flatMap(\.norms).map(\.id)
            == manifestResult.manifest.workflows.flatMap(\.norms).map(\.id))

        let verbalized = try Verbalizer(model: model).verbalize()
        let manifestVerbalized = try Verbalizer(model: VerbalizerModel(
            workflows: manifestResult.manifest.workflows,
            loweredDefinitions: model.loweredDefinitions,
            inlineDefinitions: model.inlineDefinitions,
            symbols: model.symbols,
            lexicon: model.lexicon,
            sourceFileName: model.sourceFileName,
            authoredSource: model.authoredSource,
            metadata: model.metadata,
            outline: model.outline,
            skillSections: model.skillSections,
            toolsUsed: model.toolsUsed
        )).verbalize()
        #expect(verbalized == manifestVerbalized)
    }
}

@Suite("CanonicalIRSerializer expression parity notes")
struct TraceIdentityCanonicalIRParityTests {
    @Test("norm identity payload uses stable comparison op names, not enum descriptions")
    func canonicalComparisonOpNamesAreStable() {
        let expr: IRExpression = .comparison(
            .identifierRef(name: "status"),
            .equal,
            .literal(.string("ready"))
        )
        let value = CanonicalIRSerializer.expressionValue(expr)
        guard case .record(let record) = value else {
            Issue.record("expected record payload")
            return
        }
        guard case .string(let op)? = record["op"] else {
            Issue.record("expected op field")
            return
        }
        #expect(op == "equal")
        // TraceIdentityPlanner's private workflow hasher uses `String(describing:)`
        // for comparison ops (`"equal"` for `.equal` today). Consolidation must
        // not assume byte-identical serializers — norm IDs rely on
        // CanonicalIRSerializer's explicit `comparisonOpName` table instead.
    }

    @Test("shared literal and identifier shapes match CanonicalIRSerializer records")
    func sharedExpressionShapesUseCanonicalRecords() {
        let literal = CanonicalIRSerializer.expressionValue(.literal(.boolean(true)))
        let identifier = CanonicalIRSerializer.expressionValue(.identifierRef(name: "customer"))
        guard case .record(let litRecord) = literal,
              case .record(let idRecord) = identifier else {
            Issue.record("expected record payloads")
            return
        }
        guard case .string(let litKind)? = litRecord["kind"],
              case .string(let idKind)? = idRecord["kind"] else {
            Issue.record("expected kind fields")
            return
        }
        #expect(litKind == "literal")
        #expect(idKind == "identifierRef")
    }
}
