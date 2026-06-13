import Foundation
import Testing
@testable import MeridianCore

@Suite("DecisionCatalog")
struct DecisionCatalogTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MeridianCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
    }

    @Test("every DiagnosticCode.decision resolves to a real DecisionRecord")
    func codeDecisionsResolve() {
        for code in DiagnosticCode.all {
            if let ref = code.decision {
                #expect(DecisionCatalog.lookup(ref.id) != nil,
                        Comment(rawValue: "\(code.id) references missing decision \(ref.id)"))
            }
        }
    }

    @Test("every decision is referenced by at least one diagnostic code (no orphans)")
    func noOrphanDecisions() {
        let referenced = Set(DiagnosticCode.all.compactMap { $0.decision?.id })
        for d in DecisionCatalog.all {
            #expect(referenced.contains(d.id),
                    Comment(rawValue: "decision \(d.id) is not referenced by any DiagnosticCode"))
        }
    }

    @Test("decision ids are unique and lookups are case-insensitive")
    func idsUnique() {
        let ids = DecisionCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(DecisionCatalog.lookup("d-dx-5")?.id == "D-DX-5")
    }

    @Test("docs/15_DECISIONS.md matches the rendered catalog (no drift)")
    func docIsInSync() throws {
        let docURL = repoRoot.appendingPathComponent("docs/15_DECISIONS.md")
        let onDisk = try String(contentsOf: docURL, encoding: .utf8)
        #expect(onDisk == DecisionCatalog.renderMarkdown(),
                Comment(rawValue: "docs/15_DECISIONS.md is stale — run `meridian decisions --render docs/15_DECISIONS.md`"))
    }
}
