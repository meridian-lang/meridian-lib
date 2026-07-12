import Foundation
import Testing
@testable import MeridianRuntime

@Suite("Trace replay")
struct TraceReplayTests {
    @Test("SEM_5_08 in-memory and JSONL replay results agree across operator families")
    func sem508DifferentialConformance() async throws {
        let dataset = try await makeReplayDataset()
        let context = TraceEvaluationContext(
            runID: dataset.currentRunID,
            skillName: "TraceReplayFlow",
            evaluationInstant: dataset.evaluationInstant,
            sampleFloor: 2
        )

        for plan in queryPlans() {
            let memoryResult = try await replay(plan, store: dataset.memoryStore, context: context)
            let jsonlResult = try await replay(plan, store: dataset.jsonlStore, context: context)
            #expect(memoryResult == jsonlResult, Comment(rawValue: plan.name))
        }
    }

    @Test("SEM_5_08 replay result encoding is byte-identical")
    func sem508DeterministicEncoding() async throws {
        let dataset = try await makeReplayDataset()
        let context = TraceEvaluationContext(
            runID: dataset.currentRunID,
            skillName: "TraceReplayFlow",
            evaluationInstant: dataset.evaluationInstant,
            sampleFloor: 2
        )
        let plan = queryPlans()[0]

        let first = try await replay(plan, store: dataset.jsonlStore, context: context)
        let second = try await replay(plan, store: dataset.jsonlStore, context: context)

        #expect(first == second)
        #expect(try encode(first) == encode(second))
    }

    private struct ReplayDataset {
        let memoryStore: InMemoryTraceStore
        let jsonlStore: JSONLTraceStore
        let currentRunID: String
        let evaluationInstant: Date
    }

    private enum ReplayQueryPlan {
        case temporal(String, TraceTemporalQuery)
        case statistical(String, TraceStatisticalQuery)

        var name: String {
            switch self {
            case .temporal(let name, _), .statistical(let name, _):
                return name
            }
        }
    }

    private func replay(
        _ plan: ReplayQueryPlan,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> TraceReplayResult {
        switch plan {
        case .temporal(_, let query):
            return try await TraceEvaluator.replay(temporal: query, store: store, context: context)
        case .statistical(_, let query):
            return try await TraceEvaluator.replay(statistical: query, store: store, context: context)
        }
    }

    private func queryPlans() -> [ReplayQueryPlan] {
        [
            .temporal(
                "ever",
                TraceTemporalQuery(scope: .currentRun, kind: .ever(.init(subject: .step("deploy"), outcome: .failed)))
            ),
            .temporal(
                "window",
                TraceTemporalQuery(scope: .currentRun, kind: .withinWindow(.init(subject: .step("deploy"), outcome: .failed), duration: .seconds(20)))
            ),
            .temporal(
                "count",
                TraceTemporalQuery(scope: .currentRun, kind: .countInWindow(.init(subject: .step("deploy"), outcome: .failed), comparator: .atLeast(2), duration: .seconds(20)))
            ),
            .temporal(
                "streak",
                TraceTemporalQuery(scope: .currentRun, kind: .inARow(.init(subject: .step("deploy"), outcome: .failed), count: 2))
            ),
            .temporal(
                "since",
                TraceTemporalQuery(
                    scope: .currentRun,
                    kind: .sinceLast(
                        anchor: .init(subject: .step("deploy"), outcome: .succeeded),
                        holds: .init(subject: .step("deploy"), outcome: .failed)
                    )
                )
            ),
            .statistical(
                "statistical_frequency",
                TraceStatisticalQuery(
                    scope: .acrossAllRuns,
                    pattern: .init(subject: .step("deploy"), outcome: .succeeded),
                    bound: .atLeast(0.5),
                    denominator: .runs
                )
            )
        ]
    }

    private func makeReplayDataset() async throws -> ReplayDataset {
        let tempRoot = try makeTempDirectory()
        let memoryStore = InMemoryTraceStore()
        let jsonlStore = try JSONLTraceStore(fileURL: tempRoot.appendingPathComponent("replay.jsonl"))
        let base = Date(timeIntervalSince1970: 1_720_000_000)
        let records = [
            makeRecord(id: "A", at: base, run: "run-1", ingestOrder: 1, tag: .completed, outcome: .success),
            makeRecord(id: "B", at: base.addingTimeInterval(1), run: "run-1", ingestOrder: 2, tag: .failed, outcome: .failure),
            makeRecord(id: "C", at: base.addingTimeInterval(2), run: "run-1", ingestOrder: 3, tag: .failed, outcome: .failure),
            makeRecord(id: "D", at: base.addingTimeInterval(3), run: "run-1", ingestOrder: 4, tag: .completed, outcome: .success),
            makeRecord(id: "E", at: base.addingTimeInterval(4), run: "run-2", ingestOrder: 5, tag: .failed, outcome: .failure),
            makeRecord(id: "F", at: base.addingTimeInterval(5), run: "run-2", ingestOrder: 6, tag: .completed, outcome: .success),
            makeRecord(id: "G", at: base.addingTimeInterval(6), run: "run-3", ingestOrder: 7, tag: .failed, outcome: .failure),
            makeRecord(id: "H", at: base.addingTimeInterval(7), run: "run-3", ingestOrder: 8, tag: .completed, outcome: .success)
        ]

        for record in records {
            try await memoryStore.append(record)
            try await jsonlStore.append(record)
        }

        return ReplayDataset(
            memoryStore: memoryStore,
            jsonlStore: jsonlStore,
            currentRunID: "run-1",
            evaluationInstant: base.addingTimeInterval(10)
        )
    }

    private func makeRecord(
        id: String,
        at: Date,
        run: String,
        ingestOrder: Int,
        tag: TraceTag,
        outcome: TraceOutcome
    ) -> TraceRecord {
        let payload: [String: Value] = ["id": .string(id)]
        return TraceRecord(
            id: id,
            at: at,
            ingestOrder: ingestOrder,
            run: run,
            step: "deploy",
            skillName: "TraceReplayFlow",
            skillVersionHash: "v1",
            tag: tag,
            subject: "deploy",
            subjectKey: nil,
            payload: payload,
            payloadHash: (try? CanonicalJSON.sha256Hex(for: payload)) ?? "",
            outcome: outcome
        )
    }

    private func encode(_ result: TraceReplayResult) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(result), as: UTF8.self)
    }
}

private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("trace-replay-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
