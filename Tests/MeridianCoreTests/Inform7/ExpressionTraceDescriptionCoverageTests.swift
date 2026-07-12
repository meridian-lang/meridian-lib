import Foundation
import Testing
@testable import MeridianCore

/// `ExpressionAST.traceDescription`'s `.eventPattern`/`.traceTemporal`/
/// `.traceStatistical` cases are never exercised through the full parser:
/// `TraceTemporalGrammar`/`TraceStatisticalGrammar` always wrap their result
/// in `.traceTemporal`/`.traceStatistical` at the top level (so
/// `ExpressionParser.parse`'s own trace call only ever renders those two
/// wrapper cases, never a bare `.eventPattern`), and `.traceDescription` does
/// not recurse into a `.traceTemporal`/`.traceStatistical` payload the way it
/// recurses into `.logical`/`.comparison` sub-expressions. Exercised here via
/// direct AST construction instead.
@Suite("ExpressionAST.traceDescription trace-family branch coverage")
struct ExpressionTraceDescriptionCoverageTests {
    @Test("an event-pattern node traces as event(<outcome>)")
    func eventPatternTraces() {
        let pattern = EventPatternAST(subject: .step("deploy"), outcome: .failed, payloadPredicate: nil, negated: false)
        #expect(ExpressionAST.eventPattern(pattern).traceDescription(detail: .verbose) == "event(failed)")
        #expect(ExpressionAST.eventPattern(pattern).traceDescription(detail: .compact) == "event(failed)")
    }

    @Test("a trace-temporal node traces as the literal `traceTemporal`, regardless of detail")
    func traceTemporalTraces() {
        let temporal = TraceTemporalAST(kind: .ever(EventPatternAST(subject: .step("deploy"), outcome: .failed, payloadPredicate: nil, negated: false)))
        #expect(ExpressionAST.traceTemporal(temporal).traceDescription(detail: .verbose) == "traceTemporal")
        #expect(ExpressionAST.traceTemporal(temporal).traceDescription(detail: .compact) == "traceTemporal")
    }

    @Test("a trace-statistical node traces as the literal `traceStatistical`, regardless of detail")
    func traceStatisticalTraces() {
        let statistical = TraceStatisticalAST(
            pattern: TraceStatisticalPatternAST(subject: .step("deploy")),
            outcome: .succeeds,
            bound: .atLeast(90),
            denominator: .runs
        )
        #expect(ExpressionAST.traceStatistical(statistical).traceDescription(detail: .verbose) == "traceStatistical")
        #expect(ExpressionAST.traceStatistical(statistical).traceDescription(detail: .compact) == "traceStatistical")
    }
}
