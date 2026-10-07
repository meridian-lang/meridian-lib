import ArgumentParser
import Foundation
import MeridianRuntime

public struct BenchTraceCommand: AsyncParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "bench-trace",
        abstract: "Benchmark replay query latency over synthetic trace stores."
    )

    @Option(name: .customLong("format"), help: "Output format: json or text.")
    var format: BenchTraceOutputFormat = .text

    public func run() async throws {
        let report = try await BenchTraceRunner.run()
        switch format {
        case .json:
            try BenchTraceRunner.emitJSON(report)
        case .text:
            BenchTraceRunner.emitText(report)
        }
    }
}

enum BenchTraceOutputFormat: String, ExpressibleByArgument {
    case json
    case text
}

enum BenchTraceRunner {
    enum StoreKind: String, CaseIterable {
        case inMemory = "in_memory"
        case jsonl
    }

    enum CacheState: String, CaseIterable {
        case cold
        case warm
    }

    enum OperatorFamily: String, CaseIterable {
        case ever
        case window
        case count
        case streak
        case since
        case statisticalFrequency = "statistical_frequency"
    }

    struct Measurement: Codable, Equatable {
        let datasetSize: Int
        let store: String
        let cacheState: String
        let operatorFamily: String
        let iterations: Int
        let medianMilliseconds: Double

        enum CodingKeys: String, CodingKey {
            case datasetSize = "dataset_size"
            case store
            case cacheState = "cache_state"
            case operatorFamily = "operator_family"
            case iterations
            case medianMilliseconds = "median_ms"
        }
    }

    struct Report: Codable, Equatable {
        let schemaVersion: Int
        let measurements: [Measurement]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case measurements
        }
    }

    private struct Dataset {
        let size: Int
        let records: [TraceRecord]
        let fileURL: URL
        let memoryStore: InMemoryTraceStore
        let jsonlStore: JSONLTraceStore
        let currentRunID: String
        let evaluationInstant: Date
    }

    private enum QueryPlan {
        case temporal(TraceTemporalQuery)
        case statistical(TraceStatisticalQuery)
    }

    private struct LineEnvelope: Codable {
        let record: TraceRecord
        let checksum: String
    }

    static func run(sizes: [Int] = [10_000, 100_000]) async throws -> Report {
        let root = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let datasets = try await makeDatasets(root: root, sizes: sizes)
        var measurements: [Measurement] = []

        for dataset in datasets {
            for store in StoreKind.allCases {
                for cacheState in CacheState.allCases {
                    for family in OperatorFamily.allCases {
                        let measurement = try await benchmark(
                            family: family,
                            dataset: dataset,
                            storeKind: store,
                            cacheState: cacheState
                        )
                        measurements.append(measurement)
                    }
                }
            }
        }

        return Report(schemaVersion: 1, measurements: measurements)
    }

    static func emitJSON(_ report: Report) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    static func emitText(_ report: Report) {
        var lines = ["bench-trace"]
        for measurement in report.measurements {
            lines.append(
                "\(measurement.datasetSize) events | \(measurement.store) | \(measurement.cacheState) | \(measurement.operatorFamily) | median \(String(format: "%.3f", measurement.medianMilliseconds)) ms"
            )
        }
        FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    private static func benchmark(
        family: OperatorFamily,
        dataset: Dataset,
        storeKind: StoreKind,
        cacheState: CacheState
    ) async throws -> Measurement {
        let plan = queryPlan(for: family)
        let context = TraceEvaluationContext(
            runID: dataset.currentRunID,
            skillName: "bench-trace",
            evaluationInstant: dataset.evaluationInstant,
            sampleFloor: 20
        )

        let samplesMS: [Double]
        switch (storeKind, cacheState) {
        case (.inMemory, .cold):
            samplesMS = [try await timedEvaluation(store: dataset.memoryStore, plan: plan, context: context)]
        case (.inMemory, .warm):
            _ = try await timedEvaluation(store: dataset.memoryStore, plan: plan, context: context)
            samplesMS = [try await timedEvaluation(store: dataset.memoryStore, plan: plan, context: context)]
        case (.jsonl, .cold):
            samplesMS = [try await timedEvaluation(store: dataset.jsonlStore, plan: plan, context: context)]
        case (.jsonl, .warm):
            _ = try await timedEvaluation(store: dataset.jsonlStore, plan: plan, context: context)
            samplesMS = [try await timedEvaluation(store: dataset.jsonlStore, plan: plan, context: context)]
        }

        return Measurement(
            datasetSize: dataset.size,
            store: storeKind.rawValue,
            cacheState: cacheState.rawValue,
            operatorFamily: family.rawValue,
            iterations: samplesMS.count,
            medianMilliseconds: median(samplesMS)
        )
    }

    private static func timedEvaluation(
        store: any TraceStore,
        plan: QueryPlan,
        context: TraceEvaluationContext
    ) async throws -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        switch plan {
        case .temporal(let query):
            _ = try await TraceEvaluator.replay(temporal: query, store: store, context: context)
        case .statistical(let query):
            _ = try await TraceEvaluator.replay(statistical: query, store: store, context: context)
        }
        let end = DispatchTime.now().uptimeNanoseconds
        return Double(end - start) / 1_000_000.0
    }

    private static func queryPlan(for family: OperatorFamily) -> QueryPlan {
        switch family {
        case .ever:
            return .temporal(.init(
                scope: .currentRun,
                kind: .ever(TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed))
            ))
        case .window:
            return .temporal(.init(
                scope: .currentRun,
                kind: .withinWindow(
                    TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed),
                    duration: .seconds(600)
                )
            ))
        case .count:
            return .temporal(.init(
                scope: .currentRun,
                kind: .countInWindow(
                    TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed),
                    comparator: .atLeast(3),
                    duration: .seconds(600)
                )
            ))
        case .streak:
            return .temporal(.init(
                scope: .currentRun,
                kind: .inARow(
                    TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed),
                    count: 3
                )
            ))
        case .since:
            return .temporal(.init(
                scope: .currentRun,
                kind: .sinceLast(
                    anchor: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
                    holds: TraceEventPatternQuery(subject: .step("deploy"), outcome: .failed),
                    holdsStatePredicateJSON: nil,
                    holdsUsesStateHistory: false
                )
            ))
        case .statisticalFrequency:
            return .statistical(.init(
                scope: .acrossAllRuns,
                pattern: TraceEventPatternQuery(subject: .step("deploy"), outcome: .succeeded),
                bound: .atLeast(0.45),
                denominator: .runs
            ))
        }
    }

    private static func makeDatasets(root: URL, sizes: [Int]) async throws -> [Dataset] {
        var datasets: [Dataset] = []
        for size in sizes {
            let records = try syntheticRecords(count: size)
            let fileURL = root.appendingPathComponent("trace-\(size).jsonl")
            try writeJSONL(records: records, to: fileURL)
            let memoryStore = try await makeInMemoryStore(records: records)
            let jsonlStore = try JSONLTraceStore(fileURL: fileURL)
            datasets.append(Dataset(
                size: size,
                records: records,
                fileURL: fileURL,
                memoryStore: memoryStore,
                jsonlStore: jsonlStore,
                currentRunID: "run-\((size - 1) / 10)",
                evaluationInstant: records.last?.at ?? Date(timeIntervalSince1970: 0)
            ))
        }
        return datasets
    }

    private static func makeInMemoryStore(records: [TraceRecord]) async throws -> InMemoryTraceStore {
        let store = InMemoryTraceStore()
        for record in records {
            try await store.append(record)
        }
        return store
    }

    private static func syntheticRecords(count: Int) throws -> [TraceRecord] {
        var records: [TraceRecord] = []
        records.reserveCapacity(count)
        for index in 0..<count {
            let runIndex = index / 10
            let slot = index % 10
            let tag: TraceTag
            let outcome: TraceOutcome
            let subject: String
            switch slot {
            case 0:
                tag = .completed
                outcome = .success
                subject = "deploy"
            case 1, 2, 3:
                tag = .failed
                outcome = .failure
                subject = "deploy"
            case 4:
                tag = .completed
                outcome = .success
                subject = "deploy"
            case 5:
                tag = .emitted
                outcome = .success
                subject = "alert"
            case 6:
                tag = .invoked
                outcome = .success
                subject = "deploy"
            case 7:
                tag = .failed
                outcome = .failure
                subject = "deploy"
            case 8:
                tag = runIndex.isMultiple(of: 2) ? .completed : .failed
                outcome = runIndex.isMultiple(of: 2) ? .success : .failure
                subject = "deploy"
            default:
                tag = .emitted
                outcome = .success
                subject = "audit"
            }

            let payload: [String: Value] = [
                "index": .number(Decimal(index)),
                "run": .string("run-\(runIndex)")
            ]
            let record = TraceRecord(
                id: String(format: "evt-%06d", index),
                at: Date(timeIntervalSince1970: TimeInterval(index)),
                ingestOrder: index + 1,
                run: "run-\(runIndex)",
                step: subject,
                skillName: "bench-trace",
                skillVersionHash: "wave8e",
                tag: tag,
                subject: subject,
                subjectKey: nil,
                payload: payload,
                payloadHash: try CanonicalJSON.sha256Hex(for: payload),
                outcome: outcome,
                operationalDetail: nil,
                legacyKind: nil
            )
            records.append(record)
        }
        return records
    }

    private static func writeJSONL(records: [TraceRecord], to fileURL: URL) throws {
        var data = Data()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        for record in records {
            let envelope = LineEnvelope(
                record: record,
                checksum: try CanonicalJSON.sha256Hex(for: record)
            )
            data.append(try encoder.encode(envelope))
            data.append(Data("\n".utf8))
        }
        try data.write(to: fileURL, options: .atomic)
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard let middle = sorted.indices.dropFirst(sorted.count / 2).first else { return 0 }
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle] + sorted[middle - 1]) / 2
        }
        return sorted[middle]
    }

    private static func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bench-trace-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
