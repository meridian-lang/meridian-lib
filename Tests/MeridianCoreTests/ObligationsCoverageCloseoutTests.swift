import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Obligations coverage closeout")
struct ObligationsCoverageCloseoutTests {

    // MARK: - ProofIRReader

    @Test("ProofIRReader decodes action constraints and comparison ops")
    func proofIRActionConstraints() {
        let ops = [
            "equal", "notEqual", "lessThan", "lessOrEqual", "greaterThan", "greaterOrEqual",
            "oneOf", "contains", "startsWith", "endsWith", "withinDuration", "withinPast",
            "withinFuture", "matchesPattern", "isEmpty", "isNotEmpty", "identifies",
        ]
        let constraints = ops.enumerated().map { i, op in
            """
            {"path":"f\(i)","op":"\(op)","value":{"kind":"literal","value":{"kind":"string","value":"v\(i)"}}}
            """
        }.joined(separator: ",")
        let json = """
        {"tool_id":"send.email","argument_constraints":[\(constraints),{"path":"n","op":"equal","value":{"kind":"literal","value":{"kind":"number","value":3}}},{"path":"b","op":"equal","value":{"kind":"literal","value":{"kind":"boolean","value":true}}},{"path":"id","op":"equal","value":{"kind":"identifierRef","name":"order"}},{"bad":true}]}
        """
        let pattern = ProofIRReader.actionPattern(from: json)
        #expect(pattern?.toolID == "send.email")
        #expect((pattern?.argumentConstraints.count ?? 0) >= ops.count)
        #expect(ProofIRReader.actionPattern(from: "[]") == nil)
        #expect(ProofIRReader.actionPattern(from: #"{"no_tool":true}"#) == nil)
    }

    @Test("ProofIRReader temporal kind matrix")
    func proofIRTemporalMatrix() {
        func temporal(_ value: String, scope: String = "currentRun") -> TraceTemporalQuery? {
            ProofIRReader.traceTemporalQuery(from: """
            {"kind":"traceTemporal","scope":"\(scope)","value":\(value)}
            """)
        }
        let pattern = #"{"kind":"eventPattern","value":{"subject":{"kind":"step","name":"deploy"},"outcome":"failed"}}"#
        let named = #"{"kind":"eventPattern","value":{"subject":{"kind":"named","name":"alert"},"outcome":"emitted"}}"#
        #expect(temporal(#"{"kind":"ever","pattern":\#(pattern)}"#) != nil)
        #expect(temporal(#"{"kind":"withinWindow","pattern":\#(pattern),"duration":{"seconds":5}}"#) != nil)
        #expect(temporal(#"{"kind":"countInWindow","pattern":\#(pattern),"duration":{"seconds":60},"comparator":{"kind":"atLeast","value":1}}"#) != nil)
        #expect(temporal(#"{"kind":"countInWindow","pattern":\#(pattern),"duration":{"seconds":60},"comparator":{"kind":"atMost","value":2}}"#) != nil)
        #expect(temporal(#"{"kind":"countInWindow","pattern":\#(pattern),"duration":{"seconds":60},"comparator":{"kind":"exactly","value":3}}"#) != nil)
        #expect(temporal(#"{"kind":"inARow","pattern":\#(pattern),"count":2}"#) != nil)
        #expect(temporal(#"{"kind":"sinceLast","anchor":\#(pattern),"holds":\#(named)}"#) != nil)
        #expect(temporal(#"{"kind":"sinceLast","anchor":\#(pattern),"holdsUsesStateHistory":true}"#) != nil)
        #expect(temporal(#"{"kind":"sinceLast","anchor":\#(pattern),"holdsUsesStateHistory":false}"#) == nil)
        #expect(temporal(#"{"kind":"unknown"}"#) == nil)
        #expect(temporal(#"{"kind":"ever","pattern":\#(pattern)}"#, scope: "acrossAllRuns")?.scope == .acrossAllRuns)
        #expect(ProofIRReader.traceTemporalQuery(from: #"{"kind":"traceTemporal"}"#) == nil)
        #expect(ProofIRReader.traceTemporalQuery(from: "[]") == nil)
    }

    @Test("ProofIRReader statistical variants")
    func proofIRStatisticalVariants() {
        let q = ProofIRReader.traceStatisticalQuery(from: """
        {"kind":"traceStatistical","scope":"acrossAllRuns","value":{"pattern":{"subject":{"kind":"named","name":"charge"}},"outcome":"fails","bound":{"kind":"atMost","ratio":0.1},"denominator":"occurrences","window":{"seconds":3600}}}
        """)
        if case .atMost(let ratio) = q?.bound {
            #expect(ratio == 0.1)
        } else {
            Issue.record("expected atMost bound")
        }
        #expect(q?.denominator == .occurrences)
        #expect(q?.window != nil)
        #expect(ProofIRReader.traceStatisticalQuery(from: #"{"kind":"traceStatistical","value":{}}"#) == nil)
        #expect(ProofIRReader.traceStatisticalQuery(from: nil) == nil)
    }

    // MARK: - CanonicalIRSerializer

    @Test("CanonicalIRSerializer payload helpers and expression sweep")
    func canonicalSerializerMatrix() throws {
        let cond = IRExpression.comparison(
            .propertyAccess(.identifierRef(name: "order"), propertyName: "status"),
            .equal,
            .literal(.string("open"))
        )
        for scope in [NormScope.skill, .workflow("Notify"), .section(stablePath: "a/b"), .kind("order")] {
            let assertPayload = CanonicalIRSerializer.contractAssertSemanticPayload(
                condition: cond, scope: scope, monitored: false
            )
            #expect(assertPayload["kind"] == .string("contract_invariant"))
            let monitored = CanonicalIRSerializer.contractAssertSemanticPayload(
                condition: cond, scope: scope, monitored: true
            )
            #expect(monitored["monitored"] == .boolean(true))
            let deny = CanonicalIRSerializer.defaultDenySemanticPayload(toolID: "timeNow", scope: scope)
            #expect(deny["kind"] == .string("default_deny"))
        }

        let norm = NormIR(
            kind: .obligation,
            scope: .workflow("Notify"),
            actionPattern: ActionPatternIR(
                toolID: "sendEmail",
                argumentConstraints: [
                    ActionArgumentConstraint(path: "to", op: .equal, value: .literal(.string("a@b.c"))),
                ]
            ),
            condition: .logical(.and, [
                cond,
                .invocation(InvokeIR(toolID: "check", arguments: [InvokeArg("x", .literal(.number(1)))])),
                .quantified(QuantifierIR(
                    kind: .all,
                    description: DescriptionIR(
                        collection: .identifierRef(name: "pages"),
                        elementVar: "page",
                        filters: []
                    ),
                    body: .literal(.boolean(true))
                )),
                .traceTemporal(TraceTemporalIR(kind: .ever(EventPatternIR(subject: .step("x"), outcome: .failed)))),
                .traceTemporal(TraceTemporalIR(kind: .withinWindow(
                    EventPatternIR(subject: .step("x"), outcome: .failed),
                    duration: .seconds(5)
                ))),
                .traceTemporal(TraceTemporalIR(kind: .countInWindow(
                    EventPatternIR(subject: .step("x"), outcome: .failed),
                    comparator: .atLeast(1),
                    duration: .seconds(5)
                ))),
                .traceTemporal(TraceTemporalIR(kind: .inARow(
                    EventPatternIR(subject: .step("x"), outcome: .failed),
                    count: 2
                ))),
                .traceTemporal(TraceTemporalIR(kind: .sinceLast(
                    anchor: EventPatternIR(subject: .step("x"), outcome: .succeeded),
                    holds: .eventPattern(EventPatternIR(subject: .step("x"), outcome: .failed)),
                    holdsPattern: EventPatternIR(subject: .step("x"), outcome: .failed),
                    holdsUsesStateHistory: false
                ))),
                .traceTemporal(TraceTemporalIR(kind: .boundedFutureMonitor(
                    condition: .literal(.boolean(true)),
                    horizon: .seconds(10),
                    mode: .eventuallyWithin
                ))),
                .traceStatistical(TraceStatisticalIR(
                    pattern: TraceStatisticalPatternIR(subject: .step("x")),
                    outcome: .succeeds,
                    bound: .atLeast(0.9),
                    denominator: .runs,
                    window: .seconds(60)
                )),
                .interpolatedString([
                    .literal("a"),
                    .expression(.identifierRef(name: "x")),
                    .shellEscapedExpression(.identifierRef(name: "y")),
                    .formatted(.identifierRef(name: "z"), formatter: "iso"),
                    .conditional(
                        condition: .literal(.boolean(true)),
                        then: [.literal("t")],
                        otherwise: [.literal("o")]
                    ),
                    .forEach(
                        variable: "row",
                        collection: .identifierRef(name: "rows"),
                        body: [.literal("b")]
                    ),
                ]),
                .recordList(fields: ["n"], rows: [[.literal(.string("1"))]]),
                .tableLookup(
                    table: "t",
                    keyColumn: "k",
                    key: .literal(.string("1")),
                    valueColumn: "v"
                ),
                .literal(.money(Decimal(1), currency: "USD")),
                .literal(.duration(.seconds(2))),
                .literal(.boolean(true)),
                .literal(.date(Date(timeIntervalSince1970: 0))),
                .literal(.enumValue("open", kind: "Status")),
                .literal(.calendarAmount(CalendarAmountIR(magnitude: 2, unit: .businessDays))),
                .envVar(name: "HOME"),
                .nowExpression,
            ]),
            sourceRange: SourceRange(file: "t.meridian", line: 1, column: 1),
            originalText: "must …"
        )
        let payload = CanonicalIRSerializer.normSemanticPayload(norm)
        #expect(payload["condition"] != nil)
        let data = try CanonicalIRSerializer.normSemanticJSON(norm)
        #expect(!data.isEmpty)

        let wrapped = try CanonicalIRSerializer.proofIRJSONString(.string("x"))
        #expect(wrapped.contains("value"))
        let recordProof = try CanonicalIRSerializer.proofIRJSONString(.record(["tool_id": .string("t")]))
        #expect(ProofIRReader.actionPattern(from: recordProof)?.toolID == "t")
    }

    // MARK: - ObligationEvaluator helpers

    @Test("ObligationEvaluator coversInvoke and isPreventedViolation helpers")
    func obligationEvaluatorHelpers() {
        let pattern = ActionPatternIR(
            toolID: "sendEmail",
            argumentConstraints: [
                ActionArgumentConstraint(path: "to", op: .equal, value: .literal(.string("a@b.c"))),
            ]
        )
        let matching = TraceRecord(
            id: "1",
            at: Date(),
            ingestOrder: 0,
            run: "r",
            step: "s",
            skillName: "sk",
            skillVersionHash: "h",
            tag: .invoked,
            subject: "sendEmail",
            payload: ["tool_id": .string("sendEmail"), "to": .string("a@b.c")],
            payloadHash: "p",
            outcome: .success
        )
        #expect(ObligationEvaluator.coversInvoke(pattern: pattern, record: matching))

        let missingArg = TraceRecord(
            id: "2",
            at: Date(),
            ingestOrder: 1,
            run: "r",
            step: "s",
            skillName: "sk",
            skillVersionHash: "h",
            tag: .invoked,
            subject: "sendEmail",
            payload: ["tool_id": .string("sendEmail")],
            payloadHash: "p",
            outcome: .success
        )
        #expect(!ObligationEvaluator.coversInvoke(pattern: pattern, record: missingArg))

        let prevented = TraceRecord(
            id: "3",
            at: Date(),
            ingestOrder: 2,
            run: "r",
            step: "s",
            skillName: "sk",
            skillVersionHash: "h",
            tag: .violated,
            payload: ["disposition": .string(ViolationDisposition.prevented.rawValue)],
            payloadHash: "p",
            outcome: .failure,
            operationalDetail: nil
        )
        #expect(ObligationEvaluator.isPreventedViolation(prevented))

        let detailPrevented = TraceRecord(
            id: "4",
            at: Date(),
            ingestOrder: 3,
            run: "r",
            step: "s",
            skillName: "sk",
            skillVersionHash: "h",
            tag: .violated,
            payloadHash: "p",
            outcome: .failure,
            operationalDetail: "action was Prevented by policy"
        )
        #expect(ObligationEvaluator.isPreventedViolation(detailPrevented))
        #expect(ObligationEvaluator.payloadToolID(from: matching) == "sendEmail")
        #expect(ObligationEvaluator.payloadObligationId(from: TraceRecord(
            id: "5",
            at: Date(),
            ingestOrder: 4,
            run: "r",
            step: "s",
            skillName: "sk",
            skillVersionHash: "h",
            tag: .violated,
            payload: ["obligation_id": .string("obl-1")],
            payloadHash: "p",
            outcome: .failure
        )) == "obl-1")
    }
}
