import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Monitor lifecycle")
struct MonitorLifecycleTests {
    @Test("Monitor lifecycle emits assertion outcome on cadence")
    func emitsAssertionOutcome() async throws {
        let observer = InMemoryObserver()
        let store = InMemoryTraceStore()
        let clock = TestClock(start: Date(timeIntervalSince1970: 0))
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            traceStore: store,
            clock: clock,
            runID: "run-1",
            traceConfiguration: TraceConfiguration(sampleFloor: 1),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )
        try await store.append(record(id: "A", at: 1, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))

        await runtime.registerMonitor(
            query: TraceStatisticalQuery(
                pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
                bound: .atLeast(0.9),
                denominator: .occurrences
            ),
            cadence: .seconds(5),
            message: "Expected deploy stability"
        )

        await settle()
        await clock.advance(by: .seconds(5))
        await settle()

        let events = await observer.events
        #expect(events.contains { $0.kind == .assertPassed && $0.payload["outcome"] == .string(TruthValue.true.rawValue) })
    }

    @Test("8D monitor tick emits an indeterminate assertPassed when the sample floor is not met")
    func emitsIndeterminateBelowSampleFloor() async throws {
        let observer = InMemoryObserver()
        let store = InMemoryTraceStore()
        let clock = TestClock(start: Date(timeIntervalSince1970: 0))
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            traceStore: store,
            clock: clock,
            runID: "run-1",
            // Sample floor of 5 is never reached by the single appended event below.
            traceConfiguration: TraceConfiguration(sampleFloor: 5),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )
        try await store.append(record(id: "A", at: 1, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))

        await runtime.registerMonitor(
            query: TraceStatisticalQuery(
                pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
                bound: .atLeast(0.9),
                denominator: .occurrences
            ),
            cadence: .seconds(5),
            message: "Expected deploy stability"
        )

        await settle()
        await clock.advance(by: .seconds(5))
        await settle()

        let events = await observer.events
        #expect(events.contains {
            $0.kind == .assertPassed && $0.payload["outcome"] == .string(TruthValue.indeterminate.rawValue)
        }, Comment(rawValue: "\(events)"))
    }

    @Test("Monitor lifecycle cancels registered monitors on completion")
    func cancelsOnCompletion() async throws {
        let observer = InMemoryObserver()
        let store = InMemoryTraceStore()
        let clock = TestClock(start: Date(timeIntervalSince1970: 0))
        let runtime = Runtime(
            toolRegistry: ToolRegistry(),
            observer: observer,
            traceStore: store,
            clock: clock,
            runID: "run-1",
            traceConfiguration: TraceConfiguration(sampleFloor: 1),
            traceSkillIdentity: TraceSkillIdentity(name: "deploy", versionHash: "v1")
        )
        try await store.append(record(id: "A", at: 1, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))

        await runtime.registerMonitor(
            query: TraceStatisticalQuery(
                pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
                bound: .atLeast(0.9),
                denominator: .occurrences
            ),
            cadence: .seconds(5),
            message: "Expected deploy stability"
        )
        await settle()
        await runtime.complete(reason: nil)
        await clock.advance(by: .seconds(5))
        await settle()

        let assertEvents = await observer.events.filter { $0.kind == .assertPassed || $0.kind == .assertFailed }
        #expect(assertEvents.isEmpty)
    }

    private func record(
        id: String,
        at seconds: TimeInterval,
        run: String,
        skill: String,
        tag: TraceTag,
        subject: String,
        outcome: TraceOutcome? = nil
    ) -> TraceRecord {
        TraceRecord(
            id: id,
            at: Date(timeIntervalSince1970: seconds),
            ingestOrder: Int(seconds),
            run: run,
            step: subject,
            skillName: skill,
            skillVersionHash: "v1",
            tag: tag,
            subject: subject,
            payload: [:],
            payloadHash: "payload-\(id)",
            outcome: outcome,
            operationalDetail: nil,
            legacyKind: nil
        )
    }

    private func settle() async {
        try? await Task.sleep(for: .milliseconds(10))
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}
