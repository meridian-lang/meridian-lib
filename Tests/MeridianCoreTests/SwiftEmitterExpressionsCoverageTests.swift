import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

/// Extra coverage for `SwiftEmitter+Expressions` arms that the main
/// SwiftEmitterCoverageTests suite still leaves cold after the Phase 3 extract.
@Suite("SwiftEmitter+Expressions coverage")
struct SwiftEmitterExpressionsCoverageTests {
    private let e = SwiftEmitter()

    @Test("description takeFromEnd emits Array suffix")
    func descriptionTakeFromEnd() throws {
        let desc = DescriptionIR(
            collection: .identifierRef(name: "items"),
            elementVar: "item",
            takeFromEnd: 3
        )
        let out = try e.emitExpr(.description(desc))
        #expect(out.contains(".suffix(3)"))
    }

    @Test("calendarAmount literals emit in plain and Value contexts")
    func calendarAmountLiterals() throws {
        let amount = CalendarAmountIR(magnitude: 2, unit: .businessDays)
        #expect(e.emitLiteral(.calendarAmount(amount)).contains("businessDays"))
        #expect(try e.emitValueExpr(.literal(.calendarAmount(amount))).contains(".record"))
    }

    @Test("trace scope acrossSkills emits scopeSkills list")
    func acrossSkillsScope() throws {
        let temporal = TraceTemporalIR(
            scope: .acrossSkills(["alpha", "beta"]),
            kind: .ever(EventPatternIR(subject: .step("deploy"), outcome: .succeeded))
        )
        let out = try e.emitExpr(.traceTemporal(temporal))
        #expect(out.contains(".acrossSkills"))
        #expect(out.contains("\"alpha\""))
        #expect(out.contains("\"beta\""))
    }

    @Test("sinceLast with state-history and nil holdsPattern uses state predicate JSON")
    func sinceLastStateHistory() throws {
        let anchor = EventPatternIR(subject: .step("deploy"), outcome: .succeeded)
        let holds = IRExpression.comparison(
            .identifierRef(name: "status"),
            .equal,
            .literal(.string("ok"))
        )
        let temporal = TraceTemporalIR(
            kind: .sinceLast(
                anchor: anchor,
                holds: holds,
                holdsPattern: nil,
                holdsUsesStateHistory: true
            )
        )
        let out = try e.emitExpr(.traceTemporal(temporal))
        #expect(out.contains("holdsUsesStateHistory: true"))
        #expect(out.contains("holdsStatePredicateJSON"))
    }

    @Test("sinceLast with neither pattern nor state-history emits nil holds")
    func sinceLastNilHolds() {
        let anchor = EventPatternIR(subject: .step("deploy"), outcome: .succeeded)
        let temporal = TraceTemporalIR(
            kind: .sinceLast(
                anchor: anchor,
                holds: .literal(.boolean(true)),
                holdsPattern: nil,
                holdsUsesStateHistory: false
            )
        )
        // Bypass IRValidator — this arm is defensive emitter output for
        // hand-built IR that would otherwise fail MER4002 at emitExpr.
        let out = e.emitTraceTemporalQuery(temporal)
        #expect(out.contains("holds: nil"))
        #expect(out.contains("holdsUsesStateHistory: false"))
    }

    @Test("expressionMayBeIndeterminate is true for boundedFutureMonitor")
    func expressionMayBeIndeterminateBoundedFuture() {
        let expr = IRExpression.traceTemporal(TraceTemporalIR(
            kind: .boundedFutureMonitor(
                condition: .literal(.boolean(true)),
                horizon: .seconds(1),
                mode: .eventuallyWithin
            )
        ))
        #expect(e.expressionMayBeIndeterminate(expr))
    }

    @Test("boundedFutureMonitor covers event and state condition JSON arms")
    func boundedFutureMonitor() throws {
        let eventCond = IRExpression.traceTemporal(TraceTemporalIR(
            kind: .ever(EventPatternIR(subject: .named("payment"), outcome: .succeeded))
        ))
        let eventMonitor = TraceTemporalIR(
            kind: .boundedFutureMonitor(
                condition: eventCond,
                horizon: .seconds(60),
                mode: .eventuallyWithin
            )
        )
        let eventOut = try e.emitExpr(.traceTemporal(eventMonitor))
        #expect(eventOut.contains(".boundedFutureMonitor"))
        #expect(eventOut.contains(".eventuallyWithin"))
        #expect(eventOut.contains("\\\"type\\\":\\\"named\\\""))

        let stepCond = IRExpression.traceTemporal(TraceTemporalIR(
            kind: .ever(EventPatternIR(subject: .step("deploy"), outcome: .succeeded))
        ))
        let stepMonitor = TraceTemporalIR(
            kind: .boundedFutureMonitor(
                condition: stepCond,
                horizon: .seconds(10),
                mode: .eventuallyWithin
            )
        )
        #expect(try e.emitExpr(.traceTemporal(stepMonitor)).contains("\\\"type\\\":\\\"step\\\""))

        let stateCond = IRExpression.comparison(
            .identifierRef(name: "healthy"),
            .equal,
            .literal(.string("yes"))
        )
        let stateMonitor = TraceTemporalIR(
            kind: .boundedFutureMonitor(
                condition: stateCond,
                horizon: .seconds(30),
                mode: .alwaysFor
            )
        )
        let stateOut = try e.emitExpr(.traceTemporal(stateMonitor))
        #expect(stateOut.contains(".alwaysFor"))
        #expect(stateOut.contains("\\\"kind\\\":\\\"state\\\""))

        let emptyMonitor = TraceTemporalIR(
            kind: .boundedFutureMonitor(
                condition: .literal(.boolean(true)),
                horizon: .seconds(1),
                mode: .eventuallyWithin
            )
        )
        #expect(try e.emitExpr(.traceTemporal(emptyMonitor)).contains("\"{}\""))
    }

    @Test("emitStatePredicateJSON covers equality and fallback")
    func statePredicateJSON() {
        let ok = IRExpression.comparison(
            .identifierRef(name: "status"),
            .equal,
            .literal(.string("ok"))
        )
        // Equality arm is taken (not the `"{}"` fallback); the emitted Swift
        // source embeds `escapeSwiftStringLiteral(name)` as a runtime call.
        let rendered = e.emitStatePredicateJSON(ok)
        #expect(rendered != "\"{}\"")
        #expect(e.emitStatePredicateJSON(.literal(.boolean(true))) == "\"{}\"")
    }
}
