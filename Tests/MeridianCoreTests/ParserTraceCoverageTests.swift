import Testing
@testable import MeridianCore

@Suite("ParserTrace — activation, hierarchy, logging, timing")
struct ParserTraceCoverageTests {
    @Test("enable(parsing:) with category names and group hierarchy")
    func enableParsing() {
        let t = ParserTrace(); t.disableAll()
        t.enable(parsing: "phrase, lowering")
        #expect(t.isEnabled(.phraseMatch))   // enabled via the "phrase" group prefix
        #expect(t.isEnabled(.phraseParse))
        #expect(t.isEnabled(.lowering))
        #expect(!t.isEnabled(.codegen))
    }

    @Test("enable(parsing: all) turns on everything")
    func enableAll() {
        let t = ParserTrace(); t.disableAll()
        t.enable(parsing: "all")
        for c in ParserTrace.Category.allCases { #expect(t.isEnabled(c)) }
    }

    @Test("enable([leaf]) does not over-enable siblings")
    func leafOnly() {
        let t = ParserTrace(); t.disableAll()
        t.enable([.phraseParse])
        #expect(t.isEnabled(.phraseParse))
        #expect(!t.isEnabled(.phraseMatch))   // sibling not enabled
    }

    @Test("log/detail/push/pop write through a custom sink, indented")
    func logging() {
        let cap = ParserTrace.capturing(categories: [.lowering])
        cap.trace.log(.lowering, "top")
        let tok = cap.trace.push(.lowering, "scope")
        cap.trace.detail(.lowering, "k", "v")
        cap.trace.pop(tok, "done")
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("top") })
        #expect(lines.contains { $0.contains("▶ scope") })
        #expect(lines.contains { $0.contains("k: v") })
        #expect(lines.contains { $0.contains("◀ done") })
    }

    @Test("disabled category logs nothing")
    func disabledNoOutput() {
        let cap = ParserTrace.capturing(categories: [.lowering])
        cap.trace.log(.codegen, "should not appear")
        #expect(cap.lines().isEmpty)
    }

    @Test("phase records timing and profileSummary emits when .timing is on")
    func timing() {
        let cap = ParserTrace.capturing(categories: [.timing])
        cap.trace.phase("parse") { _ = (1...100).reduce(0, +) }
        cap.trace.recordDiagnostic("a diagnostic")
        cap.trace.profileSummary()
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("compile profile") })
        #expect(lines.contains { $0.contains("parse") })
        cap.trace.resetProfile()
        // After reset, a fresh summary has nothing to print.
        let cap2 = ParserTrace.capturing(categories: [.timing])
        cap2.trace.profileSummary()
        #expect(cap2.lines().isEmpty)
    }

    @Test("async phase variant records timing too")
    func asyncPhase() async {
        let cap = ParserTrace.capturing(categories: [.timing])
        await cap.trace.phase("async-step") { try? await Task.sleep(for: .milliseconds(1)) }
        #expect(cap.lines().contains { $0.contains("async-step") })
    }

    @Test("short elides long strings; silent() suppresses output")
    func helpers() {
        #expect(ParserTrace.short("abc", max: 80) == "abc")
        let long = String(repeating: "x", count: 100)
        #expect(ParserTrace.short(long, max: 10).hasSuffix("..."))
        let silent = ParserTrace.silent()
        silent.log(.lowering, "nothing")   // sink discards; no crash
        #expect(!silent.isEnabled(.lowering))
    }

    @Test("Category summary and groups are populated")
    func categoryMeta() {
        #expect(!ParserTrace.Category.phraseMatch.summary.isEmpty)
        #expect(ParserTrace.Category.phraseMatch.groups.contains("phrase"))
        #expect(ParserTrace.Category.lowering.groups == ["lowering"])
    }
}
