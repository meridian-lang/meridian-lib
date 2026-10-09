import Foundation
import Testing
@testable import MeridianCore

/// COOK-14 / NS-B-COMPOUND (INFORM7 §2.9): the compound note form
/// `proceed, and note "<text>" in the <binding>` desugars to a `rebind` that
/// appends the note text to an already-declared text binding — no new IR
/// primitive — and is a compile error when the target is undeclared
/// (MER-REF-004) or non-text (MER-TYP-001).
@Suite("COOK-14 compound note form")
struct CompoundNoteTests {

    private func lower(_ mer: String) throws -> [IRWorkflow] {
        let config = try MerConfigParser().parse("=== vocabulary ===\n", file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig")
        let file = try MeridianParser(symbols: symbols).parse(mer, file: "t.meridian")
        // The lowerer's batch engine collects; this helper checkpoints so
        // direct-lower tests still observe errors as thrown `CompilerError`s.
        let engine = DiagnosticEngine()
        let lowering = ASTToIR(symbols: symbols, sourceFile: "t.meridian", engine: engine)
        let workflows = try lowering.lower(file)
        try engine.throwIfErrors()
        return workflows
    }

    private func firstNoteRebind(in workflows: [IRWorkflow]) -> BindIR? {
        for workflow in workflows {
            for statement in workflow.body.statements {
                if case .bind(let bind) = statement,
                   bind.isRebind,
                   case .interpolatedString = bind.expression {
                    return bind
                }
            }
        }
        return nil
    }

    @Test("COOK-14 compound note desugars to a rebind that appends text (no new IR primitive)")
    func compoundNoteSuccess() throws {
        let workflows = try lower("""
        To reconcile a batch:
          let the receipt trailer be "".
          proceed, and note "thin history" in the receipt trailer.
          complete.
        """)
        guard let bind = firstNoteRebind(in: workflows) else {
            Issue.record("expected a rebind desugared from the compound note form")
            return
        }
        #expect(bind.name == "receiptTrailer")
        guard case .interpolatedString(let segments) = bind.expression, segments.count == 2 else {
            Issue.record("expected an interpolated-string append, got \(bind.expression)")
            return
        }
        guard case .expression(.identifierRef(let ref)) = segments[0] else {
            Issue.record("expected the binding read as the first interpolation segment, got \(segments[0])")
            return
        }
        guard case .literal(let text) = segments[1] else {
            Issue.record("expected the note text as the second interpolation segment, got \(segments[1])")
            return
        }
        #expect(ref == "receiptTrailer")
        #expect(text == "thin history")
    }

    @Test("COOK-14 compound note into an undeclared binding reports MER-REF-004")
    func compoundNoteUndeclared() throws {
        do {
            _ = try lower("""
            To reconcile a batch:
              proceed, and note "thin history" in the receipt trailer.
              complete.
            """)
            Issue.record("expected MER-REF-004 for an undeclared note target")
        } catch let error as CompilerError {
            #expect(error.diagnostics.contains { $0.code == .noteBindingUndeclared },
                    Comment(rawValue: "expected MER-REF-004, got \(error.diagnostics.map(\.code.id))"))
        }
    }

    @Test("COOK-14 compound note into a non-text binding reports MER-TYP-001")
    func compoundNoteNonText() throws {
        do {
            _ = try lower("""
            To reconcile a batch:
              let the retry count be 3.
              proceed, and note "thin history" in the retry count.
              complete.
            """)
            Issue.record("expected MER-TYP-001 for a non-text note target")
        } catch let error as CompilerError {
            #expect(error.diagnostics.contains { $0.code == .noteBindingNonText },
                    Comment(rawValue: "expected MER-TYP-001, got \(error.diagnostics.map(\.code.id))"))
        }
    }
}
