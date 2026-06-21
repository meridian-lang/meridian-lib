import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Diagnostic")
struct DiagnosticTests {

    private func range(_ file: String = "t.meridian", line: Int = 6, col: Int = 10, endCol: Int = 22) -> SourceRange {
        SourceRange(file: file, startLine: line, startColumn: col, endLine: line, endColumn: endCol)
    }

    // MARK: Always-on guarantee

    @Test("unresolved within budget attaches a did-you-mean suggestion")
    func unresolvedSuggests() {
        let d = Diagnostic.unresolved(.unknownTool, target: "chargePaymnt",
                                      among: ["chargePayment", "refundPayment"],
                                      range: range(), noun: "tool")
        #expect(d.suggestions.count == 1)
        #expect(d.suggestions.first?.replacement == "chargePayment")
        #expect(d.suggestions.first?.range != nil)
        #expect(d.suggestions.first?.rationale.contains("did you mean") == true)
    }

    @Test("unresolved with nothing close attaches a candidate-list note, never bare")
    func unresolvedFallsBackToNote() {
        let d = Diagnostic.unresolved(.unknownTool, target: "zzzzzz",
                                      among: ["chargePayment", "refundPayment"],
                                      range: range(), noun: "tool")
        #expect(d.suggestions.isEmpty)
        #expect(d.notes.count == 1)
        #expect(d.notes.first?.message.contains("chargePayment") == true)
    }

    @Test("unresolved with empty candidate set still gives an actionable note")
    func unresolvedEmptyCandidates() {
        let d = Diagnostic.unresolved(.unknownVocabulary, target: "missing",
                                      among: [], range: range(), noun: "vocabulary")
        #expect(d.suggestions.isEmpty)
        #expect(d.notes.count == 1)
    }

    // MARK: The guard test that makes "always-on" load-bearing (D-DX-4)

    @Test("every nameResolution code yields a suggestion or candidate-list note")
    func everyNameResolutionCodeIsGuided() {
        let r = range()
        for code in DiagnosticCode.all where code.kind == .nameResolution {
            // With a near candidate → suggestion.
            let near = Diagnostic.unresolved(code, target: "chargePaymnt",
                                             among: ["chargePayment"], range: r)
            #expect(!near.suggestions.isEmpty,
                    Comment(rawValue: "\(code.id) produced no suggestion for a near candidate"))
            // With only far candidates → candidate-list note (never bare).
            let far = Diagnostic.unresolved(code, target: "zzzzzzzzzz",
                                            among: ["alpha", "beta"], range: r)
            #expect(!far.suggestions.isEmpty || !far.notes.isEmpty,
                    Comment(rawValue: "\(code.id) produced neither suggestion nor note"))
        }
    }

    @Test("every structural code can carry non-empty help")
    func structuralCodesCarryHelp() {
        let r = range()
        for code in DiagnosticCode.all where code.kind == .structural {
            let d = Diagnostic.structural(code, message: "x", range: r, help: "do the fix")
            #expect(d.help?.isEmpty == false,
                    Comment(rawValue: "\(code.id) lost its help"))
        }
    }

    // MARK: Catalog integrity

    @Test("catalog ids are unique and explanations non-empty")
    func catalogIntegrity() {
        let ids = DiagnosticCode.all.map(\.id)
        #expect(Set(ids).count == ids.count, Comment(rawValue: "duplicate diagnostic code ids"))
        for code in DiagnosticCode.all {
            #expect(!code.explanation.isEmpty, Comment(rawValue: "\(code.id) has no explanation"))
            #expect(DiagnosticCode.lookup(code.id) != nil)
        }
    }

    // MARK: Human rendering (UI snapshot of the marquee shape)

    @Test("human renderer draws a caret and the did-you-mean hint")
    func humanRender() {
        let source = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          invoke chargePaymnt with order = the order.
        """
        let d = Diagnostic.unresolved(.unknownTool, target: "chargePaymnt",
                                      among: ["chargePayment"],
                                      range: SourceRange(file: "t.meridian", startLine: 5, startColumn: 10, endLine: 5, endColumn: 22),
                                      noun: "tool")
        let out = DiagnosticRenderer(sources: ["t.meridian": source]).render(d)
        #expect(out.contains("[MER2002]"))
        #expect(out.contains("^"))
        #expect(out.contains("did you mean \"chargePayment\"?"))
        #expect(out.contains("meridian explain MER2002"))
        // D-DX-5 rationale surfaced inline.
        #expect(out.contains("D-DX-5"))
    }

    @Test("JSON renderer emits a stable schema incl. decision id")
    func jsonRender() throws {
        let d = Diagnostic.unresolved(.unknownTool, target: "chargePaymnt",
                                      among: ["chargePayment"], range: range(), noun: "tool")
        let json = DiagnosticRenderer().renderJSON([d])
        let data = json.data(using: .utf8)!
        let arr = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        #expect(arr.count == 1)
        #expect(arr[0]["code"] as? String == "MER2002")
        #expect(arr[0]["severity"] as? String == "error")
        #expect(arr[0]["decision"] as? String == "D-DX-5")
        let suggestions = arr[0]["suggestions"] as! [[String: Any]]
        #expect(suggestions.first?["replacement"] as? String == "chargePayment")
    }

    // MARK: CompilerError projection

    @Test("CompilerError.diagnostics projects the structured case")
    func compilerErrorProjection() {
        let d = Diagnostic.unresolved(.unknownTool, target: "x", among: ["y"], range: range(), noun: "tool")
        let err = CompilerError.diagnostics([d])
        #expect(err.diagnostics.count == 1)
        #expect(err.diagnostics.first?.code.id == "MER2002")
    }

    @Test("catalog metadata covers every DiagnosticCode.all entry")
    func catalogMetadataComplete() {
        #expect(DiagnosticCode.catalog.count == DiagnosticCode.all.count)
        for code in DiagnosticCode.all {
            guard let entry = DiagnosticCode.catalogByID[code.id] else {
                Issue.record("missing catalog metadata for \(code.id)")
                continue
            }
            switch entry.status {
            case .reserved:
                #expect(entry.emitters.isEmpty, Comment(rawValue: "\(code.id) reserved but has emitters"))
            case .active, .deprecated:
                #expect(!entry.emitters.isEmpty, Comment(rawValue: "\(code.id) has no production emitter listed"))
            }
        }
    }

    @Test("unknown trace category validates to MER2010")
    func unknownTraceCategory() {
        let ds = ParserTrace.validateTraceSpec("not-a-real-category")
        #expect(ds.count == 1)
        #expect(ds.first?.code.id == "MER2010")
    }

    @Test("unknown test-spec key validates to MER1007")
    func unknownTestSpecKey() {
        let spec = """
        source_inline: ```
        to x:
          emit y.
        ```
        bad_key: oops
        """
        do {
            _ = try SpecParser().parse(spec, fileURL: URL(fileURLWithPath: "/tmp/t.meridian.test"))
            Issue.record("expected MER1007")
        } catch let e as CompilerError {
            #expect(e.diagnostics.first?.code.id == "MER1007")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}
