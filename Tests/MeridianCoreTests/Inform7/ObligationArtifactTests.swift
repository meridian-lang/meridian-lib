import Foundation
import Testing
@testable import MeridianCore

@Suite("Obligation artifacts (Wave 9B / SEM-8-02)")
struct ObligationArtifactTests {
    private let cfg = """
    === vocabulary ===
    A customer is a kind of thing.
    A service is a kind of thing.
    A service has a text called the status.
    """

    private func compileModel(mer: String, file: String = "test.meridian") throws -> VerbalizerModel {
        let compiler = Compiler(options: .init(trace: .silent()))
        return try compiler.compileToModel(
            meridianSource: mer,
            meridianFile: file,
            vocabularies: [.init(name: "test", file: "test.merconfig", source: cfg)]
        )
    }

    @Test("SEM_8_02 obligation artifact includes stable id and canonical english")
    func sem802ArtifactShape() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let model = try compileModel(mer: mer)
        let document = try ObligationDocumentBuilder.build(from: model)
        #expect(document.obligations.count == 1)
        let artifact = try #require(document.obligations.first)
        #expect(artifact.id.hasPrefix("OBL-"))
        #expect(artifact.id.count == 4 + OBLIGATION_ID_PREFIX_LENGTH)
        #expect(artifact.kind == .unreachability)
        #expect(artifact.canonicalEnglish == Verbalizer(model: model).verbalize(
            model.workflows.flatMap(\.norms).first!, annotateObligationID: false
        ))
    }

    @Test("SEM_8_02 id stable across clean builds")
    func sem802ByteStableAcrossBuilds() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let first = try ObligationDocumentBuilder.emitJSON(try ObligationDocumentBuilder.build(from: compileModel(mer: mer)))
        let second = try ObligationDocumentBuilder.emitJSON(try ObligationDocumentBuilder.build(from: compileModel(mer: mer)))
        #expect(first == second)
    }

    @Test("SEM_8_02 wording-only edit preserves obligation id")
    func sem802WordingOnlyPreservesId() throws {
        let base = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let reworded = """
        ---
        vocabulary: test.merconfig
        description: audit guard
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let baseID = try #require(try ObligationDocumentBuilder.build(from: compileModel(mer: base)).obligations.first?.id)
        let rewordedID = try #require(try ObligationDocumentBuilder.build(from: compileModel(mer: reworded)).obligations.first?.id)
        #expect(baseID == rewordedID)
    }

    @Test("SEM_8_02 meaning edit changes obligation id")
    func sem802MeaningEditChangesId() throws {
        let original = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let changed = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke shell.run.

        To notify a customer:
          complete.
        """
        let originalID = try #require(try ObligationDocumentBuilder.build(from: compileModel(mer: original)).obligations.first?.id)
        let changedID = try #require(try ObligationDocumentBuilder.build(from: compileModel(mer: changed)).obligations.first?.id)
        #expect(originalID != changedID)
    }

    @Test("SEM_8_02 line-only comment edit preserves obligation id")
    func sem802LineOnlyPreservesId() throws {
        let merA = """
        ---
        vocabulary: test.merconfig
        ---
        # guard clock access
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let merB = """
        ---
        vocabulary: test.merconfig
        ---
        # different comment placement
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let idA = try #require(try ObligationDocumentBuilder.build(from: compileModel(mer: merA)).obligations.first?.id)
        let idB = try #require(try ObligationDocumentBuilder.build(from: compileModel(mer: merB)).obligations.first?.id)
        #expect(idA == idB)
    }

    @Test("SEM_8_02 explain annotates deontic norm with OBL id")
    func sem802ExplainAnnotatesNorm() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let model = try compileModel(mer: mer)
        let annotated = try Verbalizer(model: model).verbalize(annotateObligationIDs: true)
        let obligationID = try #require(try ObligationDocumentBuilder.build(from: model).obligations.first?.id)
        #expect(annotated.contains("[\(obligationID)]"))
    }

    @Test("SEM_8_02 obligations CLI library path emits sorted JSON twice identically")
    func sem802EmitTwice() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A customer must not invoke time.now.

        To notify a customer:
          complete.
        """
        let model = try compileModel(mer: mer)
        let doc = try ObligationDocumentBuilder.build(from: model)
        let once = try ObligationDocumentBuilder.emitJSON(doc)
        let twice = try ObligationDocumentBuilder.emitJSON(doc)
        #expect(once == twice)
        #expect(once.contains("\"schema_version\""))
        #expect(once.contains("\"semantics_version\""))
    }

    @Test("SEM_8_02 canonical english matches verbalizer norm surface")
    func sem802CanonicalEnglishMatchesVerbalizer() throws {
        let mer = """
        ---
        vocabulary: test.merconfig
        ---
        A service is healthy must hold.

        To inspect a service:
          commit.
          complete.
        """
        let model = try compileModel(mer: mer)
        let norm = try #require(model.workflows.flatMap(\.norms).first)
        let artifact = try #require(try ObligationDocumentBuilder.build(from: model).obligations.first)
        #expect(artifact.canonicalEnglish == Verbalizer(model: model).verbalize(norm))
    }
}
