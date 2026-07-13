import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

/// End-to-end guidance for did-you-mean and candidate-list diagnostics (plan step 4).
@Suite("Diagnostic guidance")
struct DiagnosticGuidanceTests {

    private let trivialWorkflow = """
    ---
    vocabulary: t.merconfig
    ---
    To run:
      complete with reason "ok".
    """

    private func compileVocab(_ cfg: String) throws -> CompilerError {
        do {
            _ = try Compiler().compile(
                meridianSource: trivialWorkflow,
                meridianFile: "t.meridian",
                merconfigSource: cfg,
                merconfigFile: "t.merconfig")
            Issue.record("expected compile to fail")
            throw CompilerError.diagnostics([])
        } catch let err as CompilerError {
            return err
        }
    }

    private func toolCfg() -> String {
        """
        === vocabulary ===
        An order is a kind of thing.
        === tools ===
        Charge Payment
        ==============
        ~ chargePayment(order: Order) : Order
        """
    }

    // MARK: - Did-you-mean / candidate list

    @Test("close tool typo yields a did-you-mean suggestion")
    func closeToolTypoSuggests() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          invoke chargePaymnt with order = the order.
        """
        do {
            _ = try Compiler().compile(
                meridianSource: mer, meridianFile: "t.meridian",
                merconfigSource: toolCfg(), merconfigFile: "t.merconfig")
            Issue.record("expected unknown tool")
        } catch let err as CompilerError {
            let diag = try #require(err.diagnostics.first { $0.code == .unknownTool })
            #expect(diag.suggestions.first?.replacement == "chargePayment")
            #expect(diag.suggestions.first?.rationale.contains("did you mean") == true)
        }
    }

    @Test("far tool typo yields a candidate-list note")
    func farToolTypoListsCandidates() throws {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          invoke zzzzzzzzzz with order = the order.
        """
        do {
            _ = try Compiler().compile(
                meridianSource: mer, meridianFile: "t.meridian",
                merconfigSource: toolCfg(), merconfigFile: "t.merconfig")
            Issue.record("expected unknown tool")
        } catch let err as CompilerError {
            let diag = try #require(err.diagnostics.first { $0.code == .unknownTool })
            #expect(diag.suggestions.isEmpty)
            let note = try #require(diag.notes.first?.message)
            #expect(!note.isEmpty)
            #expect(note.contains("tool") || note.contains("chargePayment"),
                    Comment(rawValue: "note was: \(note)"))
        }
    }

    @Test("relation backing property typo yields a did-you-mean suggestion")
    func relationBackingPropertyTypoSuggests() throws {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.
        Ownership relates one user to various pages.
        Ownership is read from the page's ownr.
        """
        let err = try compileVocab(cfg)
        let codes = err.diagnostics.map(\.code.id).joined(separator: ", ")
        let diag = try #require(
            err.diagnostics.first { $0.code == .unknownProperty },
            Comment(rawValue: "expected MER2004, got: \(codes) messages: \(err.diagnostics.map(\.message))"))
        #expect(diag.suggestions.first?.replacement == "owner")
        #expect(diag.suggestions.first?.rationale.contains("did you mean") == true)
    }

    @Test("relation backing property far miss lists declared properties")
    func relationBackingPropertyFarMissListsCandidates() throws {
        let cfg = """
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.
        Ownership relates one user to various pages.
        Ownership is read from the page's zzzzzzzzzz.
        """
        let err = try compileVocab(cfg)
        let diag = try #require(err.diagnostics.first { $0.code == .unknownProperty })
        #expect(diag.suggestions.isEmpty)
        #expect(diag.notes.first?.message.contains("owner") == true)
    }

    @Test("relation backing tool typo yields a did-you-mean suggestion")
    func relationBackingToolTypoSuggests() throws {
        let cfg = """
        === vocabulary ===
        A page is a kind of thing.
        An entity is a kind of thing.
        Mentioning relates various pages to various entities.
        Mentioning is read via the lnk tool.
        === tools ===
        Link
        ==============
        ~ link(entity: String) : List
        """
        let err = try compileVocab(cfg)
        let diag = try #require(err.diagnostics.first { $0.code == .unknownTool })
        #expect(!diag.suggestions.isEmpty || diag.notes.first?.message.contains("link") == true)
    }

    // MARK: - Anaphora referent notes

    @Test("anaphora ambiguity lists possible referents")
    func anaphoraAmbiguityListsReferents() throws {
        do {
            _ = try AnaphoraResolver().resolve(
                "summarize it",
                referents: ["comment", "job"],
                file: "t.meridian",
                line: 3)
            Issue.record("expected ambiguous anaphora")
        } catch let err as CompilerError {
            let diag = try #require(err.diagnostics.first { $0.code == .ambiguousAnaphora })
            let note = try #require(diag.notes.first?.message)
            #expect(note.contains("comment"))
            #expect(note.contains("job"))
            #expect(note.contains("possible referents"))
        }
    }

    @Test("linter anaphora ambiguity lists possible referents")
    func linterAnaphoraListsReferents() {
        let diagnostics = MeridianLinter().lint(source: """
        bind comment = "c1".
        bind job = "j1".
        resolve it.
        """, file: "t.meridian")
        let diag = diagnostics.first { $0.code == .ambiguousAnaphora }
        #expect(diag != nil)
        let note = diag?.notes.first?.message ?? ""
        #expect(note.contains("comment"))
        #expect(note.contains("job"))
    }

    // MARK: - JSON renderer

    @Test("JSON renderer preserves suggestions, notes, and help")
    func jsonPreservesGuidanceFields() throws {
        let range = SourceRange(file: "t.meridian", startLine: 5, startColumn: 10,
                                endLine: 5, endColumn: 22)
        let d = Diagnostic.unresolved(
            .unknownTool, target: "chargePaymnt", among: ["chargePayment"],
            range: range, noun: "tool",
            help: "Declare it in === tools ===.")
        let withNotes = Diagnostic(
            code: d.code, severity: d.severity, message: d.message,
            primaryRange: d.primaryRange, suggestions: d.suggestions,
            notes: [DiagnosticNote("available tools: chargePayment")],
            help: d.help, phase: "lower")
        let json = try DiagnosticRenderer().renderJSON([withNotes])
        let arr = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [[String: Any]]
        let obj = try #require(arr.first)
        #expect(obj["help"] as? String == "Declare it in === tools ===.")
        #expect(obj["phase"] as? String == "lower")
        let suggestions = obj["suggestions"] as! [[String: Any]]
        #expect(suggestions.first?["replacement"] as? String == "chargePayment")
        let notes = obj["notes"] as! [[String: Any]]
        #expect(notes.first?["message"] as? String == "available tools: chargePayment")
    }
}
