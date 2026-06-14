import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("WordStemmer — tokenize and stems")
struct WordStemmerTests {
    @Test("tokenize splits on non-alphanumerics, lowercases, drops stopwords")
    func tokenize() {
        let toks = WordStemmer.tokenize("Place THE Order-now!", stopwords: ["the"])
        #expect(toks == ["place", "order", "now"])
    }

    @Test("stems generates plural/past/progressive variants plus the original")
    func stems() {
        #expect(Set(WordStemmer.stems(of: "categories")).contains("category"))
        #expect(Set(WordStemmer.stems(of: "boxes")).contains("box"))
        #expect(Set(WordStemmer.stems(of: "orders")).contains("order"))
        #expect(Set(WordStemmer.stems(of: "ordered")).contains("order"))
        let ing = Set(WordStemmer.stems(of: "ordering"))
        #expect(ing.contains("order"))
        #expect(ing.contains("ordere"))     // +e variant
        #expect(Set(WordStemmer.stems(of: "go")).contains("go"))   // too short → just original
    }

    @Test("stemSet unions every token's stems")
    func stemSet() {
        let set = WordStemmer.stemSet("orders closed", stopwords: [])
        #expect(set.contains("order"))
        #expect(set.contains("close"))   // "closed" → drop "d" → "close"
    }
}

@Suite("Diagnostic — builders and severity ordering")
struct DiagnosticCoverageTests {
    private let range = SourceRange(file: "f", startLine: 1, startColumn: 1, endLine: 1, endColumn: 5)

    @Test("severity is Comparable note < warning < error")
    func severity() {
        #expect(DiagnosticSeverity.note < .warning)
        #expect(DiagnosticSeverity.warning < .error)
    }

    @Test("unresolved with a close candidate yields a did-you-mean suggestion")
    func unresolvedClose() {
        let d = Diagnostic.unresolved(.unknownTool, target: "htpt.get",
                                      among: ["http.get", "file.read"], range: range, noun: "tool")
        #expect(d.message.contains("unknown tool"))
        #expect(d.suggestions.first?.replacement == "http.get")
        #expect(d.severity == .error)
    }

    @Test("unresolved with no close candidate enumerates the candidate set")
    func unresolvedFar() {
        let d = Diagnostic.unresolved(.unknownTool, target: "zzzzzzzzz",
                                      among: ["http.get", "file.read"], range: range, noun: "tool")
        #expect(d.suggestions.isEmpty)
        #expect(d.notes.first?.message.contains("available tool") == true)
    }

    @Test("unresolved with empty candidate set notes none available")
    func unresolvedEmpty() {
        let d = Diagnostic.unresolved(.unknownTool, target: "x", among: [], range: range, noun: "tool")
        #expect(d.notes.first?.message.contains("no tools are available") == true)
    }

    @Test("structural and error and warning builders")
    func builders() {
        let s = Diagnostic.structural(.malformedWorkflowHeader, message: "bad header",
                                      range: range, help: "add a colon")
        #expect(s.help == "add a colon")
        #expect(s.severity == .error)

        let e = Diagnostic.error(.codegenError, message: "boom", range: range)
        #expect(e.severity == .error)

        let w = Diagnostic.warning(.codegenError, message: "heads up", range: range)
        #expect(w.severity == .warning)
    }

    @Test("Suggestion and DiagnosticNote carry their fields")
    func payloads() {
        let sug = Suggestion(replacement: "x", range: range, rationale: "why")
        #expect(sug.replacement == "x")
        let note = DiagnosticNote("see here", range: range)
        #expect(note.message == "see here")
    }
}
