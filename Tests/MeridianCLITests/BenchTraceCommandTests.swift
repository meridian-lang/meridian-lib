import Testing
@testable import MeridianCLIKit

@Suite("CLI command — bench-trace")
struct BenchTraceCommandTests {
    @Test("bench-trace JSON schema covers all measurement combinations")
    func jsonSchema() async throws {
        let report = try await BenchTraceRunner.run(sizes: [100, 1_000])
        #expect(report.schemaVersion == 1)
        #expect(report.measurements.count == 48)
        #expect(report.measurements.contains {
            $0.datasetSize == 100
                && $0.store == "jsonl"
                && $0.cacheState == "warm"
                && $0.operatorFamily == "statistical_frequency"
        })
    }
}
