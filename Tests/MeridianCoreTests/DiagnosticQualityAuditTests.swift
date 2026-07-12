import Foundation
import Testing
@testable import MeridianCore

// Phase 1 diagnostic quality audit — complements `DiagnosticTests` with a
// machine-readable completeness contract over the active catalog.

@Suite("Diagnostic quality audit")
struct DiagnosticQualityAuditTests {
    @Test("every active diagnostic code has a non-empty explanation")
    func activeCodesHaveExplanations() {
        for entry in DiagnosticCode.catalog where entry.status == .active {
            #expect(
                !entry.code.explanation.isEmpty,
                Comment(rawValue: "\(entry.code.id) missing explanation")
            )
        }
    }

    @Test("every active diagnostic code lists at least one production emitter")
    func activeCodesHaveEmitters() {
        for entry in DiagnosticCode.catalog where entry.status == .active {
            #expect(
                !entry.emitters.isEmpty,
                Comment(rawValue: "\(entry.code.id) missing emitter inventory")
            )
        }
    }

    @Test("catalog covers every DiagnosticCode.all entry")
    func catalogIsComplete() {
        #expect(DiagnosticCode.catalog.count == DiagnosticCode.all.count)
        for code in DiagnosticCode.all {
            #expect(DiagnosticCode.catalogByID[code.id] != nil, Comment(rawValue: "missing catalog entry for \(code.id)"))
        }
    }
}
