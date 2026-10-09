import Foundation
import Testing
@testable import MeridianRuntime

@Suite("TraceEvaluator")
struct TraceEvaluatorTests {
    @Test("SEM_5_01 pure-past evaluation ignores future events")
    func sem501() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy"))
        try await store.append(record(id: "B", at: 20, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy"))

        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .withinWindow(pattern(.step("deploy"), .failed), duration: .seconds(5))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(12))
        )

        #expect(value == .true)
    }

    @Test("SEM_5_02 ever matches retained scoped history")
    func sem502() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy"))

        let query = TraceTemporalQuery(kind: .ever(pattern(.step("deploy"), .failed)))
        let result = try await TraceEvaluator.evaluate(
            temporal: query,
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        let miss = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(pattern(.step("deploy"), .succeeded))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )

        #expect(result == .true)
        #expect(miss == .false)
    }

    @Test("SEM_5_03 withinWindow uses inclusive old end")
    func sem503() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy"))

        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .withinWindow(pattern(.step("deploy"), .failed), duration: .seconds(10))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )

        #expect(value == .true)
    }

    @Test("SEM_5_04 countInWindow compares at least at most exactly")
    func sem504() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy"))
        try await store.append(record(id: "B", at: 11, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy"))
        try await store.append(record(id: "C", at: 12, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy"))

        let atLeast = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .countInWindow(pattern(.step("deploy"), .failed), comparator: .atLeast(2), duration: .seconds(5))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(14))
        )
        let atMost = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .countInWindow(pattern(.step("deploy"), .failed), comparator: .atMost(2), duration: .seconds(5))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(14))
        )
        let exactly = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .countInWindow(pattern(.step("deploy"), .failed), comparator: .exactly(3), duration: .seconds(5))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(14))
        )

        #expect(atLeast == .true)
        #expect(atMost == .false)
        #expect(exactly == .true)
    }

    @Test("SEM_5_05 inARow uses qualifying subsequence and prevented invoke does not qualify")
    func sem505() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))
        try await store.append(record(id: "B", at: 11, run: "run-1", skill: "deploy", tag: .violated, subject: "deploy", operationalDetail: "prevented"))
        try await store.append(record(id: "C", at: 12, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "D", at: 13, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))

        let twoInARow = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .inARow(pattern(.step("deploy"), .failed), count: 2)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )

        #expect(twoInARow == .true)
    }

    @Test("SEM_5_06 sinceLast is strict after anchor and indeterminate without anchor")
    func sem506() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))

        let strict = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .sinceLast(anchor: pattern(.step("deploy"), .succeeded), holds: pattern(.step("deploy"), .succeeded), holdsStatePredicateJSON: nil, holdsUsesStateHistory: false)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        let indeterminate = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .sinceLast(anchor: pattern(.step("missing"), .succeeded), holds: pattern(.step("deploy"), .succeeded), holdsStatePredicateJSON: nil, holdsUsesStateHistory: false)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )

        #expect(strict == .true, "same-timestamp anchor should exclude the anchor event itself")
        #expect(indeterminate == .indeterminate)
    }

    @Test("SEM_5_08 fixed context yields deterministic result")
    func sem507() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy"))
        let query = TraceTemporalQuery(kind: .ever(pattern(.step("deploy"), .failed)))
        let context = TraceEvaluationContext(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))

        let first = try await TraceEvaluator.evaluate(temporal: query, store: store, context: context)
        let second = try await TraceEvaluator.evaluate(temporal: query, store: store, context: context)
        #expect(first == second)
    }

    @Test("SEM_5_08 replay semantics depend only on explicit evaluation instant")
    func sem508() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 20, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy"))
        let query = TraceTemporalQuery(kind: .withinWindow(pattern(.step("deploy"), .failed), duration: .seconds(5)))

        let before = try await TraceEvaluator.evaluate(
            temporal: query,
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(19))
        )
        let after = try await TraceEvaluator.evaluate(
            temporal: query,
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(22))
        )

        #expect(before == .false)
        #expect(after == .true)
    }

    @Test("SEM_5_09 subject key restricts temporal matching")
    func sem510() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", subjectKey: "svc-a"))
        try await store.append(record(id: "B", at: 11, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", subjectKey: "svc-b"))

        let query = TraceTemporalQuery(kind: .ever(pattern(.step("deploy"), .failed, subjectKey: "svc-a")))
        let result = try await TraceEvaluator.evaluate(
            temporal: query,
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )

        #expect(result == .true)
    }

    @Test("SEM_4_03 across-all-runs uses skill scope and global ordering")
    func sem511() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "B", at: 11, run: "run-2", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "C", at: 12, run: "run-3", skill: "other-skill", tag: .failed, subject: "deploy", outcome: .failure))

        let result = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(scope: .acrossAllRuns, kind: .inARow(pattern(.step("deploy"), .failed), count: 2)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )

        #expect(result == .true)
    }

    @Test("SEM_4_09 across-all-runs ignores version hash when skill identity is stable")
    func sem409() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", versionHash: "v1", outcome: .failure))
        try await store.append(record(id: "B", at: 11, run: "run-2", skill: "deploy", tag: .failed, subject: "deploy", versionHash: "v2", outcome: .failure))

        let result = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(scope: .acrossAllRuns, kind: .countInWindow(pattern(.step("deploy"), .failed), comparator: .exactly(2), duration: .seconds(20))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )

        #expect(result == .true)
    }

    @Test("RISK-W8-01 north-star contrast covers both orderings plus prevented invoke")
    func northStarOrderings() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-a", skill: "release", tag: .completed, subject: "deploy", outcome: .success))
        try await store.append(record(id: "B", at: 11, run: "run-b", skill: "release", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "C", at: 12, run: "run-c", skill: "release", tag: .violated, subject: "deploy", operationalDetail: "prevented"))
        try await store.append(record(id: "D", at: 13, run: "run-d", skill: "release", tag: .failed, subject: "deploy", outcome: .failure))

        let across = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(scope: .acrossAllRuns, kind: .inARow(pattern(.step("deploy"), .failed), count: 2)),
            store: store,
            context: .init(runID: "run-a", skillName: "release", evaluationInstant: date(20))
        )
        let current = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(scope: .currentRun, kind: .inARow(pattern(.step("deploy"), .failed), count: 2)),
            store: store,
            context: .init(runID: "run-d", skillName: "release", evaluationInstant: date(20))
        )

        #expect(across == .true)
        #expect(current == .false)
    }

    private func pattern(
        _ subject: TraceEventPatternQuery.Subject,
        _ outcome: TraceEventPatternQuery.Outcome,
        subjectKey: String? = nil
    ) -> TraceEventPatternQuery {
        TraceEventPatternQuery(subject: subject, outcome: outcome, subjectKey: subjectKey)
    }

    private func record(
        id: String,
        at seconds: TimeInterval,
        run: String,
        skill: String,
        tag: TraceTag,
        subject: String,
        versionHash: String = "v1",
        subjectKey: String? = nil,
        outcome: TraceOutcome? = nil,
        operationalDetail: String? = nil,
        payload: [String: Value]? = [:]
    ) -> TraceRecord {
        TraceRecord(
            id: id,
            at: date(seconds),
            ingestOrder: Int(seconds),
            run: run,
            step: subject,
            skillName: skill,
            skillVersionHash: versionHash,
            tag: tag,
            subject: subject,
            subjectKey: subjectKey,
            payload: payload,
            payloadHash: "payload-\(id)",
            outcome: outcome,
            operationalDetail: operationalDetail
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }

    @Test("inARow with a non-positive count is trivially true")
    func inARowZeroCountIsTriviallyTrue() async throws {
        let store = InMemoryTraceStore()
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .inARow(pattern(.step("deploy"), .failed), count: 0)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .true)
    }

    @Test("sinceLast with a negated holds pattern is true when no trailing event qualifies")
    func sinceLastNegatedHoldsTrueWithNoTrailingEvent() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))

        let negatedHolds = TraceEventPatternQuery(subject: .named("critical alert"), outcome: .occurred, negated: true)
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .sinceLast(anchor: pattern(.step("deploy"), .succeeded), holds: negatedHolds, holdsStatePredicateJSON: nil, holdsUsesStateHistory: false)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .true)
    }

    @Test("sinceLast with a negated holds pattern is false when a trailing event qualifies")
    func sinceLastNegatedHoldsFalseWithTrailingEvent() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))
        try await store.append(record(id: "B", at: 15, run: "run-1", skill: "deploy", tag: .violated, subject: "critical alert"))

        let negatedHolds = TraceEventPatternQuery(subject: .named("critical alert"), outcome: .occurred, negated: true)
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .sinceLast(anchor: pattern(.step("deploy"), .succeeded), holds: negatedHolds, holdsStatePredicateJSON: nil, holdsUsesStateHistory: false)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .false)
    }

    @Test("sinceLast across all runs orders the trailing check with cross-run ordering")
    func sinceLastAcrossAllRunsUsesCrossRunOrdering() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))
        try await store.append(record(id: "B", at: 11, run: "run-2", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))

        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(scope: .acrossAllRuns, kind: .sinceLast(anchor: pattern(.step("deploy"), .succeeded), holds: pattern(.step("deploy"), .failed), holdsStatePredicateJSON: nil, holdsUsesStateHistory: false)),
            store: store,
            context: .init(runID: "run-2", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .true)
    }

    @Test("a payloadContains predicate that fully matches the record's payload does not reject via commonMatch")
    func fullyMatchingPayloadPredicateIsAccepted() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(
            id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy",
            payload: ["channel": .string("#incidents"), "severity": .string("high"), "region": .string("us-east")]
        ))

        // Two-plus matching keys are needed to exercise the loop's
        // continue-to-next-key edge, not just a single-iteration exit.
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(TraceEventPatternQuery(
                subject: .step("deploy"), outcome: .failed,
                payloadContains: ["channel": .string("#incidents"), "severity": .string("high")]
            ))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .true)
    }

    @Test("fullMatch and qualifiesIgnoringOutcome resolve every outcome verb, not just failed/succeeded")
    func everyOutcomeVerbResolves() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .invoked, subject: "deploy"))
        try await store.append(record(id: "B", at: 11, run: "run-1", skill: "deploy", tag: .emitted, subject: "alert"))
        try await store.append(record(id: "C", at: 12, run: "run-1", skill: "deploy", tag: .violated, subject: "guard", operationalDetail: "prevented the rollout"))
        try await store.append(record(id: "D", at: 13, run: "run-1", skill: "deploy", tag: .violated, subject: "policy"))
        try await store.append(record(id: "E", at: 14, run: "run-1", skill: "deploy", tag: .branched, subject: "anything"))

        let context = TraceEvaluationContext(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))

        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(pattern(.step("deploy"), .invoked))), store: store, context: context) == .true)
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(pattern(.named("alert"), .emitted))), store: store, context: context) == .true)
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(pattern(.named("guard"), .prevented))), store: store, context: context) == .true)
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(pattern(.named("policy"), .prevented))), store: store, context: context) == .false,
            "a `violated` tag without an operational-detail mention of \"prevented\" does not satisfy `.prevented`")
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(pattern(.named("policy"), .violated))), store: store, context: context) == .true)
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(pattern(.named("anything"), .occurred))), store: store, context: context) == .true)

        // `qualifiesIgnoringOutcome` (the `inARow`/`sinceLast` streak-membership
        // check, as opposed to `fullMatch`'s pass/fail check) over the same
        // outcome verbs: `.prevented` never qualifies (there is no partial
        // "prevented-ish" streak membership), unlike `.violated`.
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .inARow(pattern(.named("guard"), .prevented), count: 1)), store: store, context: context) == .false)
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .inARow(pattern(.step("deploy"), .invoked), count: 1)), store: store, context: context) == .true)
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .inARow(pattern(.named("alert"), .emitted), count: 1)), store: store, context: context) == .true)
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .inARow(pattern(.named("policy"), .violated), count: 1)), store: store, context: context) == .true)
        #expect(try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .inARow(pattern(.named("anything"), .occurred), count: 1)), store: store, context: context) == .true)
    }
}

/// `TraceEvaluator`'s `commonMatch` subject/subjectKey/payload guards are
/// redundant re-checks over what `InMemoryTraceStore`/`JSONLTraceStore`
/// already filter via `TraceQueryPattern.matches` before records ever reach
/// the evaluator — so they can never actually observe a mismatch through
/// either shipped store. They remain load-bearing defense-in-depth for any
/// third-party `TraceStore` conformance that filters more loosely (or not at
/// all) on those fields; this permissive test double exercises exactly that.
private struct PermissiveTraceStore: TraceStore {
    let records: [TraceRecord]

    func append(_ event: TraceRecord) async throws {}

    func query(
        scope: TraceScope,
        scopeSkills: [String],
        runID: String?,
        skillName: String?,
        window: TraceWindow?,
        pattern: TraceQueryPattern?
    ) async throws -> [TraceRecord] {
        // Deliberately ignores `pattern` entirely — only scope/run/skill/window
        // are honored, leaving subject/subjectKey/payload matching up to the
        // evaluator's own `commonMatch`.
        records.filter { record in
            if scope == .currentRun, let runID, record.run != runID { return false }
            if let skillName, record.skillName != skillName { return false }
            if let window, !window.contains(record.at) { return false }
            return true
        }
    }

    func compact(retention: Duration, now: Date) async throws {}

    var capabilities: TraceStoreCapabilities {
        TraceStoreCapabilities(isPersistent: false, supportsCompaction: false)
    }
}

@Suite("TraceEvaluator commonMatch defense-in-depth against a non-filtering store")
struct TraceEvaluatorCommonMatchTests {
    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

    private func record(
        id: String, at seconds: TimeInterval, run: String, skill: String, tag: TraceTag,
        subject: String?, subjectKey: String? = nil, payload: [String: Value]? = [:]
    ) -> TraceRecord {
        TraceRecord(
            id: id, at: date(seconds), ingestOrder: Int(seconds), run: run, step: subject ?? "?",
            skillName: skill, skillVersionHash: "v1", tag: tag, subject: subject, subjectKey: subjectKey,
            payload: payload, payloadHash: "payload-\(id)"
        )
    }

    @Test("a record whose subject does not match the pattern is rejected by commonMatch")
    func mismatchedSubjectRejected() async throws {
        let store = PermissiveTraceStore(records: [
            record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "other-step"),
        ])
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .false)
    }

    @Test("a record whose subjectKey does not match the pattern's subjectKey is rejected by commonMatch")
    func mismatchedSubjectKeyRejected() async throws {
        let store = PermissiveTraceStore(records: [
            record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", subjectKey: "svc-b"),
        ])
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed, subjectKey: "svc-a"))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .false)
    }

    @Test("a record with a nil payload is rejected by commonMatch when the pattern requires a payload field")
    func nilPayloadRejectedWhenPayloadPredicateRequired() async throws {
        let store = PermissiveTraceStore(records: [
            record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", payload: nil),
        ])
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed, payloadContains: ["channel": .string("#incidents")]))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .false)
    }

    @Test("a mismatched-subject record is also rejected by qualifiesIgnoringOutcome's own commonMatch guard, not just fullMatch's")
    func mismatchedSubjectRejectedByQualifiesIgnoringOutcomeToo() async throws {
        let store = PermissiveTraceStore(records: [
            record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "other-step"),
        ])
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .inARow(TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed), count: 1)),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .false)
    }

    @Test("a record whose payload field value differs from the pattern's is rejected by commonMatch")
    func mismatchedPayloadFieldRejected() async throws {
        let store = PermissiveTraceStore(records: [
            record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", payload: ["channel": .string("#other")]),
        ])
        let value = try await TraceEvaluator.evaluate(
            temporal: TraceTemporalQuery(kind: .ever(TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed, payloadContains: ["channel": .string("#incidents")]))),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20))
        )
        #expect(value == .false)
    }
}

@Suite("TraceStatistical evaluator")
struct TraceStatisticalEvaluatorTests {
    @Test("SEM_6_01 TraceStatistical occurrences compare against explicit threshold")
    func sem601Occurrences() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))
        try await store.append(record(id: "B", at: 11, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "C", at: 12, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))

        let value = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atLeast(0.6),
                denominator: .occurrences
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 1)
        )

        #expect(value == .true)
    }

    @Test("SEM_6_02 TraceStatistical sample floor yields indeterminate")
    func sem602SampleFloor() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))

        let value = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atLeast(0.9),
                denominator: .occurrences
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 2)
        )

        #expect(value == .indeterminate)
    }

    @Test("SEM_6_03 TraceStatistical runs use the last qualifying event per run")
    func sem603RunsUseLastOutcomePerRun() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "B", at: 11, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))
        try await store.append(record(id: "C", at: 12, run: "run-2", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))
        try await store.append(record(id: "D", at: 13, run: "run-3", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))

        let value = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                scope: .acrossAllRuns,
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atLeast(0.66),
                denominator: .runs
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 1)
        )

        #expect(value == .true)
    }

    @Test("8D same-trace runs-vs-occurrences denominator divergence")
    func sameTraceRunsVsOccurrencesDivergence() async throws {
        // A single run with 3 occurrences: 2 failures then a final success.
        // Occurrences: 1/3 succeed (0.33); runs (last-per-run): 1/1 succeeds (1.0).
        // The same store, the same pattern, and the same bound diverge on
        // truth value purely from the denominator choice.
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "B", at: 11, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "C", at: 12, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))

        let byOccurrences = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                scope: .acrossAllRuns,
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atLeast(0.5),
                denominator: .occurrences
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 1)
        )
        let byRuns = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                scope: .acrossAllRuns,
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atLeast(0.5),
                denominator: .runs
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 1)
        )

        #expect(byOccurrences == .false)
        #expect(byRuns == .true)
    }

    @Test("an explicit window narrows the statistical query to a fixed lookback, not just up-to-now")
    func explicitWindowNarrowsSample() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 1, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "B", at: 10, run: "run-1", skill: "deploy", tag: .completed, subject: "deploy", outcome: .success))

        // Old failure at t=1 falls outside a 5-second lookback window ending at
        // t=20, leaving only the t=10 success in-sample.
        let value = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atLeast(1.0),
                denominator: .occurrences,
                window: .seconds(12)
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 1)
        )

        #expect(value == .true)
    }

    @Test("runs denominator supports an atMost bound")
    func runsDenominatorAtMostBound() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "B", at: 11, run: "run-2", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))

        let value = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                scope: .acrossAllRuns,
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atMost(0.5),
                denominator: .runs
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 1)
        )

        #expect(value == .true)
    }

    @Test("occurrences denominator supports an atMost bound")
    func occurrencesDenominatorAtMostBound() async throws {
        let store = InMemoryTraceStore()
        try await store.append(record(id: "A", at: 10, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))
        try await store.append(record(id: "B", at: 11, run: "run-1", skill: "deploy", tag: .failed, subject: "deploy", outcome: .failure))

        let value = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atMost(0.0),
                denominator: .occurrences
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 1)
        )

        #expect(value == .true)
    }

    @Test("runs denominator with zero matching runs and a zero sample floor compares a zero ratio, not indeterminate")
    func runsDenominatorZeroSampleSizeComparesZeroRatio() async throws {
        let store = InMemoryTraceStore()

        let value = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                scope: .acrossAllRuns,
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atMost(0.5),
                denominator: .runs
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 0)
        )

        #expect(value == .true)
    }

    @Test("occurrences denominator with zero matching records and a zero sample floor compares a zero ratio, not indeterminate")
    func occurrencesDenominatorZeroSampleSizeComparesZeroRatio() async throws {
        let store = InMemoryTraceStore()

        let value = try await TraceEvaluator.evaluate(
            statistical: TraceStatisticalQuery(
                pattern: pattern(.step("deploy"), .succeeded),
                bound: .atMost(0.5),
                denominator: .occurrences
            ),
            store: store,
            context: .init(runID: "run-1", skillName: "deploy", evaluationInstant: date(20), sampleFloor: 0)
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
        run: String,
        skill: String,
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
            outcome: outcome,
            operationalDetail: nil
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }
}
