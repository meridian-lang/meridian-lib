import Foundation
import Testing
@testable import MeridianCore

@Suite("Wave 9 north-star fixtures")
struct Wave9NorthStarFixtureTests {
    private static let fixtureVocabulary = """
    === vocabulary ===
    A customer is a kind of thing.
    A service is a kind of thing.
    A service has a text called the name.
    A service has a text called the status.
    A service is keyed by the name.
    A ledger is a kind of thing.
    """

    private func compileModel(mer: String, file: String = "fixture.meridian") throws -> VerbalizerModel {
        let compiler = Compiler(options: .init(trace: .silent()))
        return try compiler.compileToModel(
            meridianSource: mer,
            meridianFile: file,
            vocabularies: [.init(name: "test", file: "test.merconfig", source: Self.fixtureVocabulary)]
        )
    }

    @Test("release-sentinel-wave9 compiles with non-empty norms and explain annotations")
    func releaseSentinelWave9Obligations() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.
        A customer may invoke shell.run.
        A service is healthy must hold.

        To notify a customer:
          complete with reason "release sentinel wave9 pass complete".
        """
        let model = try compileModel(mer: mer, file: "release-sentinel-wave9.meri")
        let norms = model.workflows.flatMap(\.norms)
        #expect(!norms.isEmpty)
        let annotated = try Verbalizer(model: model).verbalize(annotateNormIDs: true)
        #expect(annotated.contains("[OBL-"))
        #expect(norms.contains { $0.kind == .prohibition })
        #expect(norms.contains { $0.kind == .permission })
    }

    @Test("ledger-recon-wave9 compiles with prohibition and obligation norms")
    func ledgerReconWave9Obligations() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke shell.run.
        A service is healthy must hold.

        To notify a customer:
          complete with reason "ledger recon wave9 pass complete".
        """
        let model = try compileModel(mer: mer, file: "ledger-recon-wave9.meri")
        let norms = model.workflows.flatMap(\.norms)
        #expect(norms.count >= 2)
        #expect(norms.contains { $0.kind == .prohibition })
        #expect(norms.contains { $0.kind == .obligation })
        let annotated = try Verbalizer(model: model).verbalize(annotateNormIDs: true)
        #expect(annotated.contains("[OBL-"))
    }

    @Test("bundle release-sentinel-wave9 fixture still strict-compiles for workflow regression")
    func releaseSentinelBundleFixture() throws {
        guard let url = Bundle.module.url(forResource: "release-sentinel-wave9", withExtension: "meri", subdirectory: "Fixtures/Trace") else {
            Issue.record("missing bundle fixture")
            return
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        _ = try compileModel(mer: source, file: url.lastPathComponent)
    }
}
