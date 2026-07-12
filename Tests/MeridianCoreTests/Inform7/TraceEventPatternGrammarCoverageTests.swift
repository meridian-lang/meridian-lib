import Foundation
import Testing
@testable import MeridianCore

/// Direct-construction branch coverage for `TraceEventPatternGrammar`,
/// exercising shapes that never arise through the full compile pipeline
/// (which only ever hands this grammar pre-extracted "ever <verb>" /
/// "since ... <verb>" clauses) but are reachable through `parse`/`parseAnchor`
/// as a standalone production.
@Suite("TraceEventPatternGrammar direct branch coverage")
struct TraceEventPatternGrammarCoverageTests {
    private func grammar() -> TraceEventPatternGrammar {
        TraceEventPatternGrammar(lexicon: .default, atom: { .malformed($0) })
    }

    @Test("an outcome marker with trailing junk after it (mid-clause, not the terminal word) never matches")
    func midClauseOutcomeMarkerWithTrailingJunkFails() {
        // "failed" appears mid-string with a non-empty tail ("twice yesterday"),
        // so the mid-string scan (distinct from the terminal-suffix scan) finds
        // the marker but must reject it via its `tail.isEmpty` guard and fall
        // through to the next candidate marker instead of matching.
        let result = grammar().parse("the deploy step failed twice yesterday")
        #expect(result == nil, Comment(rawValue: "expected no strict match, got \(String(describing: result))"))
    }

    @Test("parseAnchor falls back to a bare occurred pattern over the same trailing-junk clause")
    func midClauseOutcomeMarkerAnchorFallback() {
        // Same shape as above, but through the bare-anchor entrypoint: since no
        // marker legally matches, `parseAnchor` falls back to treating the
        // whole clause as a `.occurred` pattern over the literal text.
        let result = grammar().parseAnchor("the deploy step failed twice yesterday")
        guard let result else {
            Issue.record("expected a bare-anchor fallback pattern")
            return
        }
        guard case .occurred = result.outcome else {
            Issue.record("expected `.occurred` outcome, got \(result.outcome)")
            return
        }
    }

    @Test("a skill-scoped subject with a step name reports stepOfSkill")
    func skillScopedSubjectResolves() {
        let subject = TraceEventPatternGrammar.parseSubject("the fetch step of the briefing skill", lexicon: .default)
        guard case .stepOfSkill(let step, let skill) = subject else {
            Issue.record("expected stepOfSkill, got \(subject)")
            return
        }
        #expect(step == "fetch")
        #expect(skill == "briefing")
    }

    @Test("a bare named subject with no step/skill suffix resolves to named")
    func bareNamedSubjectResolves() {
        let subject = TraceEventPatternGrammar.parseSubject("the widget", lexicon: .default)
        guard case .named("widget") = subject else {
            Issue.record("expected named(\"widget\"), got \(subject)")
            return
        }
    }
}
