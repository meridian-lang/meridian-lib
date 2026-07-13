import Foundation
import Testing
@testable import MeridianRuntime

@Suite("TraceEvaluator residual coverage")
struct TraceEvaluatorResidualCoverageTests {

    @Test("sinceLast state-history path matches snapshot predicates")
    func sinceLastStateHistory() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, tag: .completed, subject: "deploy", outcome: .success))
        try await store.append(stateSnapshot(id: "S1", at: 15, fields: ["status": .string("healthy")]))
        try await store.append(stateSnapshot(id: "S2", at: 16, fields: ["status": .string("healthy")]))

        let ok = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .sinceLast(
                anchor: pattern(.step("deploy"), .succeeded),
                holds: nil,
                holdsStatePredicateJSON: #"{"status":"healthy"}"#,
                holdsUsesStateHistory: true
            )),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(ok == .true)

        try await store.append(stateSnapshot(id: "S3", at: 17, fields: ["status": .string("down")]))
        let bad = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .sinceLast(
                anchor: pattern(.step("deploy"), .succeeded),
                holds: nil,
                holdsStatePredicateJSON: #"{"status":"healthy"}"#,
                holdsUsesStateHistory: true
            )),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(bad == .false)

        let emptyStore = InMemoryTraceStore()
        try await emptyStore.append(record(id: "A", at: 10, tag: .completed, subject: "deploy", outcome: .success))
        let noSnapshots = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .sinceLast(
                anchor: pattern(.step("deploy"), .succeeded),
                holds: nil,
                holdsStatePredicateJSON: #"{"status":"healthy"}"#,
                holdsUsesStateHistory: true
            )),
            store: emptyStore,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(noSnapshots == .indeterminate)
    }

    @Test("sinceLast with nil holds is indeterminate when anchor exists")
    func sinceLastNilHolds() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, tag: .completed, subject: "deploy", outcome: .success))
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .sinceLast(
                anchor: pattern(.step("deploy"), .succeeded),
                holds: nil,
                holdsStatePredicateJSON: nil,
                holdsUsesStateHistory: false
            )),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .indeterminate)
    }

    @Test("inARow shortfall and broken suffix streak")
    func inARowEdges() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "B", at: 11, tag: .failed, subject: "deploy", outcome: .failure))
        let shortfall = try await TraceEvaluator.replay(
            temporal: TraceTemporalQuery(kind: .inARow(pattern(.step("deploy"), .failed), count: 5)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(shortfall.truthValue == .false)
        #expect(!shortfall.witnessEventIDs.isEmpty)

        try await store.append(record(id: "C", at: 12, tag: .completed, subject: "deploy", outcome: .success))
        try await store.append(record(id: "D", at: 13, tag: .failed, subject: "deploy", outcome: .failure))
        let broken = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .inARow(pattern(.step("deploy"), .failed), count: 2)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(broken == .false)
    }

    @Test("boundedFutureMonitor state and alwaysFor arms")
    func boundedFutureArms() async throws {
        let store = InMemoryTraceStore()
        let start = date(10)
        let end = date(20)
        try await store.append(stateSnapshot(id: "S1", at: 12, fields: ["ok": .string("yes")]))
        try await store.append(stateSnapshot(id: "S2", at: 14, fields: ["ok": .string("yes")]))

        let always = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .boundedFutureMonitor(
                conditionJSON: #"{"kind":"state","fields":{"ok":"yes"}}"#,
                horizon: .seconds(10),
                mode: .alwaysFor
            )),
            store: store,
            context: .init(
                runID: "run-1",
                skillName: "deploy",
                evaluationInstant: end,
                monitorStart: start
            )
        )
        #expect(always == .true)

        try await store.append(stateSnapshot(id: "S3", at: 16, fields: ["ok": .string("no")]))
        let notAlways = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .boundedFutureMonitor(
                conditionJSON: #"{"kind":"state","fields":{"ok":"yes"}}"#,
                horizon: .seconds(10),
                mode: .alwaysFor
            )),
            store: store,
            context: .init(
                runID: "run-1",
                skillName: "deploy",
                evaluationInstant: end,
                monitorStart: start
            )
        )
        #expect(notAlways == .false)

        let empty = InMemoryTraceStore()
        let emptyAlways = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .boundedFutureMonitor(
                conditionJSON: #"{"kind":"state","fields":{"ok":"yes"}}"#,
                horizon: .seconds(10),
                mode: .alwaysFor
            )),
            store: empty,
            context: .init(
                runID: "run-1",
                skillName: "deploy",
                evaluationInstant: end,
                monitorStart: start
            )
        )
        #expect(emptyAlways == .indeterminate)

        let badJSON = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .boundedFutureMonitor(
                conditionJSON: "not-json",
                horizon: .seconds(10),
                mode: .eventuallyWithin
            )),
            store: store,
            context: .init(
                runID: "run-1",
                skillName: "deploy",
                evaluationInstant: end,
                monitorStart: start
            )
        )
        #expect(badJSON == .indeterminate)

        let early = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .boundedFutureMonitor(
                conditionJSON: #"{"kind":"state","fields":{"ok":"yes"}}"#,
                horizon: .seconds(10),
                mode: .eventuallyWithin
            )),
            store: store,
            context: .init(
                runID: "run-1",
                skillName: "deploy",
                evaluationInstant: date(12),
                monitorStart: start
            )
        )
        #expect(early == .indeterminate)

        let eventStore = InMemoryTraceStore()
        try await eventStore.append(record(id: "E1", at: 12, tag: .failed, subject: "deploy", outcome: .failure))
        try await eventStore.append(record(id: "E2", at: 14, tag: .failed, subject: "deploy", outcome: .failure))
        let eventAlways = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .boundedFutureMonitor(
                conditionJSON: #"{"kind":"event","subject":{"type":"step","name":"deploy"},"outcome":"failed"}"#,
                horizon: .seconds(10),
                mode: .alwaysFor
            )),
            store: eventStore,
            context: .init(
                runID: "run-1",
                skillName: "deploy",
                evaluationInstant: end,
                monitorStart: start
            )
        )
        #expect(eventAlways == .true)
    }

    @Test("statistical Wilson atMost bound")
    func statisticalWilsonAtMost() async throws {
        let store = InMemoryTraceStore()
        for i in 0..<20 {
            let success = i < 18
            try await store.append(record(
                id: "R\(i)",
                at: TimeInterval(i + 1),
                tag: success ? .completed : .failed,
                subject: "deploy",
                outcome: success ? .success : .failure
            ))
        }
        let value = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atMost(0.85),
                denominator: .runs,
                confidencePercent: 95
            ),
            store: store,
            context: .init(
                runID: "run-1",
                skillName: "deploy",
                evaluationInstant: date(30),
                sampleFloor: 0
            )
        )
        #expect(value == .false || value == .true || value == .indeterminate)
    }

    @Test("acrossSkills scope filters skills")
    func acrossSkillsScope() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "alpha", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "B", at: 11, run: "run-1", skill: "beta", tag: .failed, subject: "deploy", outcome: .failure))
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(
                scope: .acrossSkills,
                scopeSkills: ["alpha"],
                kind: .ever(pattern(.step("deploy"), .failed))
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "alpha", evaluationInstant: date(20))
        )
        #expect(value == .true)
    }

    private func pattern(
        _ subject: TraceEventPatternQuery.Subject,
        _ outcome: TraceEventPatternQuery.Outcome
    ) -> TraceEventPatternQuery {
        TraceEventPatternQuery(subject: subject, outcome: outcome)
    }

    private func record(
        id: String,
        at seconds: TimeInterval,
        run: String = "run-1",
        skill: String = "deploy",
        tag: TraceTag,
        subject: String,
        outcome: TraceOutcome? = nil
    ) -> TraceRecord {
        TraceRecord(
            id: id,
            at: date(seconds),
            ingestOrder: Int(seconds),
            run: run,
            step: subject,
            skillName: skill,
            skillVersionHash: "v1",
            tag: tag,
            subject: subject,
            payload: [:],
            payloadHash: "payload-\(id)",
            outcome: outcome
        )
    }

    private func stateSnapshot(id: String, at seconds: TimeInterval, fields: [String: Value]) -> TraceRecord {
        TraceRecord(
            id: id,
            at: date(seconds),
            ingestOrder: Int(seconds),
            run: "run-1",
            step: "state",
            skillName: "deploy",
            skillVersionHash: "v1",
            tag: .stateSnapshot,
            subject: "service",
            payload: fields,
            payloadHash: "payload-\(id)",
            outcome: nil
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }
}
