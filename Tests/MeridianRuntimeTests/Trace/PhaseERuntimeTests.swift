import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Phase E runtime semantics")
struct PhaseERuntimeTests {
    @Test("SEM_6_04 Wilson interval compares lower bound against threshold")
    func sem604WilsonInterval() {
        let interval = WilsonScore.interval(successes: 18, sampleSize: 20, confidencePercent: 95)
        guard let interval else {
            Issue.record("expected Wilson interval")
            return
        }
        #expect(interval.lower < 0.9)
        #expect(interval.upper > 0.9)
    }

    @Test("SEM_6_04 Wilson intervals apply to runs denominator")
    func sem604WilsonRunsDenominator() async throws {
        let store = InMemoryTraceStore()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for run in 1...20 {
            let tag: TraceTag = run <= 18 ? .completed : .failed
            let outcome: TraceOutcome = run <= 18 ? .success : .failure
            try await store.append(phaseERecord(
                id: "r\(run)",
                at: base.addingTimeInterval(Double(run)),
                run: "run-\(run)",
                tag: tag,
                subject: "deploy",
                outcome: outcome
            ))
        }
        let context = TraceEvaluationContext(
            runID: "run-1",
            skillName: "flow",
            evaluationInstant: base.addingTimeInterval(30),
            sampleFloor: 20
        )
        let query = TraceStatisticalQuery(
            scope: .acrossAllRuns,
            pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
            bound: .atLeast(0.85),
            denominator: .runs
        )
        let rawRatio = try await TraceEvaluator.evaluate(
            statistical: query,
            store: store,
            context: context
        )
        let wilson = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                scope: query.scope,
                pattern: query.pattern,
                bound: query.bound,
                denominator: query.denominator,
                confidencePercent: 95
            ),
            store: store,
            context: context
        )
        #expect(rawRatio == .true)
        #expect(wilson == .false)
    }

    @Test("SEM_4_12 runtime emits state snapshots when history enabled")
    func sem412StateSnapshotEmission() async throws {
        let store = InMemoryTraceStore()
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: InMemoryObserver(),
            traceStore: store,
            traceConfiguration: TraceConfiguration(stateHistoryRetention: true),
            traceSkillIdentity: TraceSkillIdentity(name: "flow", versionHash: "v1")
        )
        var state = State()
        state.bind("status", .string("healthy"))
        try await runtime.recordStateSnapshotIfEnabled(
            state: state.snapshot(),
            operation: "bind",
            key: "status",
            step: "root/bind"
        )
        let snapshots = try await store.query(
            scope: .currentRun,
            scopeSkills: [],
            runID: runtime.runID,
            skillName: "flow",
            window: nil,
            pattern: TraceQueryPattern(tags: [.stateSnapshot])
        )
        #expect(snapshots.count == 1)
        #expect(snapshots[0].payload?["status"] == .string("healthy"))
        #expect(snapshots[0].payload?["operation"] == .string("bind"))
    }

    @Test("SEM_5_12 bounded future monitor resolves after horizon closes")
    func sem512BoundedFutureAfterHorizon() async throws {
        let store = InMemoryTraceStore()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let horizonEnd = start.addingTimeInterval(300)
        try await store.append(phaseERecord(
            id: "deploy-ok",
            at: start.addingTimeInterval(60),
            run: "run-1",
            tag: .completed,
            subject: "deploy",
            outcome: .success
        ))
        let beforeHorizon = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(
                kind: .boundedFutureMonitor(
                    conditionJSON: "{\"kind\":\"event\",\"subject\":{\"type\":\"step\",\"name\":\"deploy\"},\"outcome\":\"succeeded\"}",
                    horizon: .seconds(300),
                    mode: .eventuallyWithin
                )
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "flow", evaluationInstant: start.addingTimeInterval(100), monitorStart: start)
        )
        #expect(beforeHorizon == .indeterminate)
        let afterHorizon = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(
                kind: .boundedFutureMonitor(
                    conditionJSON: "{\"kind\":\"event\",\"subject\":{\"type\":\"step\",\"name\":\"deploy\"},\"outcome\":\"succeeded\"}",
                    horizon: .seconds(300),
                    mode: .eventuallyWithin
                )
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "flow", evaluationInstant: horizonEnd, monitorStart: start)
        )
        #expect(afterHorizon == .true)
    }

    @Test("SEM_4_11 trace ordering breaks ties by ingest order then id")
    func sem411ClockSkewOrdering() {
        let instant = Date(timeIntervalSince1970: 1_700_000_000)
        let first = TraceRecord(
            id: "b",
            at: instant,
            ingestOrder: 2,
            run: "run-a",
            step: "deploy",
            skillName: "flow",
            skillVersionHash: "hash",
            tag: .completed,
            subject: "deploy",
            subjectKey: nil,
            payload: [:],
            payloadHash: "payload-b"
        )
        let second = TraceRecord(
            id: "a",
            at: instant,
            ingestOrder: 1,
            run: "run-a",
            step: "deploy",
            skillName: "flow",
            skillVersionHash: "hash",
            tag: .completed,
            subject: "deploy",
            subjectKey: nil,
            payload: [:],
            payloadHash: "payload-a"
        )
        #expect(TraceRecordOrdering.crossRun(second, first))
        #expect(!TraceRecordOrdering.crossRun(first, second))
    }
}

private func phaseERecord(
    id: String,
    at: Date,
    run: String,
    tag: TraceTag,
    subject: String,
    outcome: TraceOutcome
) -> TraceRecord {
    let payload: [String: Value] = ["id": .string(id)]
    return TraceRecord(
        id: id,
        at: at,
        ingestOrder: 1,
        run: run,
        step: subject,
        skillName: "flow",
        skillVersionHash: "hash",
        tag: tag,
        subject: subject,
        subjectKey: nil,
        payload: payload,
        payloadHash: (try? CanonicalJSON.sha256Hex(for: payload)) ?? "",
        outcome: outcome
    )
}
