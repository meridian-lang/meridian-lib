import Foundation
import Testing
@testable import MeridianCLIKit
@testable import MeridianRuntime
import MeridianTestKit

@Suite("CLI command — trace eval (process)")
struct TraceReplayCLISlowTests {
    @Test("trace eval JSON schema is stable")
    func jsonSchemaGolden() async throws {
        let fixture = try await makeTraceEvalFixture(singleRun: true)
        let bin = try slowLocateMeridianBinary()
        let result = try slowRunMeridian(bin, [
            "trace", "eval",
            fixture.fileURL.path,
            "the deploy step has ever failed",
            "--at", fixture.instant,
            "--format", "json"
        ])

        let expected = """
        {
          "expression" : "the deploy step has ever failed",
          "instant" : "\(fixture.instant)",
          "query_type" : "temporal",
          "scope" : "currentRun",
          "truth_value" : "true",
          "witness_event_ids" : [
            "rec-1"
          ]
        }

        """
        #expect(result.exitCode == 0, Comment(rawValue: result.stderr + result.stdout))
        #expect(result.stdout == expected, Comment(rawValue: result.stdout))
    }

    @Test("trace-eval alias is byte-identical across repeated replays")
    func aliasDeterministic() async throws {
        let fixture = try await makeTraceEvalFixture(singleRun: true)
        let bin = try slowLocateMeridianBinary()
        let args = [
            "trace-eval",
            fixture.fileURL.path,
            "the deploy step has ever failed",
            "--at", fixture.instant,
            "--format", "json"
        ]

        let first = try slowRunMeridian(bin, args)
        let second = try slowRunMeridian(bin, args)

        #expect(first.exitCode == 0, Comment(rawValue: first.stderr + first.stdout))
        #expect(second.exitCode == 0, Comment(rawValue: second.stderr + second.stdout))
        #expect(first.stdout == second.stdout, Comment(rawValue: first.stdout + "\n---\n" + second.stdout))
    }

    @Test("trace eval rejects ambiguous current-run replay")
    func ambiguousRunFails() async throws {
        let fixture = try await makeTraceEvalFixture(singleRun: false)
        let bin = try slowLocateMeridianBinary()
        let result = try slowRunMeridian(bin, [
            "trace", "eval",
            fixture.fileURL.path,
            "the deploy step has ever failed",
            "--at", fixture.instant
        ])

        #expect(result.exitCode != 0)
        #expect(result.stderr.contains("exactly one run"), Comment(rawValue: result.stderr))
    }

    @Test("8D trace eval replays a statistical expression across all runs")
    func statisticalExpressionReplay() async throws {
        let dir = SlowTempDir(prefix: "meridian-trace-eval-stats")
        let fileURL = dir.url.appendingPathComponent("stats-trace.jsonl")
        let store = try JSONLTraceStore(fileURL: fileURL)
        let base = Date(timeIntervalSince1970: 1_719_792_000)
        for (index, outcome) in [TraceOutcome.success, .success, .failure].enumerated() {
            try await store.append(TraceRecord(
                id: "rec-\(index)",
                at: base.addingTimeInterval(Double(index)),
                ingestOrder: index + 1,
                run: "run-\(index)",
                step: "deploy",
                skillName: "TraceEvalFlow",
                skillVersionHash: "v1",
                tag: outcome == .success ? .completed : .failed,
                subject: "deploy",
                payload: ["tool": .string("deploy")],
                payloadHash: try CanonicalJSON.sha256Hex(for: ["tool": .string("deploy")]),
                outcome: outcome
            ))
        }
        let instant = ISO8601DateFormatter.meridianFormatter.string(from: base.addingTimeInterval(10))
        let merconfigURL = dir.url.appendingPathComponent("stats.merconfig")
        try "=== trace ===\nsample floor: 2\n".write(to: merconfigURL, atomically: true, encoding: .utf8)

        let bin = try slowLocateMeridianBinary()
        let result = try slowRunMeridian(bin, [
            "trace-eval",
            fileURL.path,
            "across all runs, the deploy step succeeds in at least 50% of runs",
            "--at", instant,
            "--merconfig", merconfigURL.path,
            "--format", "json"
        ])

        #expect(result.exitCode == 0, Comment(rawValue: result.stderr + result.stdout))
        #expect(result.stdout.contains("\"query_type\" : \"statistical\""), Comment(rawValue: result.stdout))
        #expect(result.stdout.contains("\"scope\" : \"acrossAllRuns\""), Comment(rawValue: result.stdout))
        #expect(result.stdout.contains("\"truth_value\" : \"true\""), Comment(rawValue: result.stdout))
    }

    @Test("trace eval replays a whose-qualified event payload predicate")
    func payloadPredicateReplay() async throws {
        let fixture = try await makeTraceEvalFixture(singleRun: true)
        let bin = try slowLocateMeridianBinary()

        let matching = try slowRunMeridian(bin, [
            "trace", "eval",
            fixture.fileURL.path,
            "the deploy step whose tool is \"deploy\" has ever failed",
            "--at", fixture.instant,
            "--format", "json"
        ])
        #expect(matching.exitCode == 0, Comment(rawValue: matching.stderr + matching.stdout))
        #expect(matching.stdout.contains("\"truth_value\" : \"true\""), Comment(rawValue: matching.stdout))
        #expect(matching.stdout.contains("\"rec-1\""), Comment(rawValue: matching.stdout))

        let nonMatching = try slowRunMeridian(bin, [
            "trace", "eval",
            fixture.fileURL.path,
            "the deploy step whose tool is \"rollback\" has ever failed",
            "--at", fixture.instant,
            "--format", "json"
        ])
        #expect(nonMatching.exitCode == 0, Comment(rawValue: nonMatching.stderr + nonMatching.stdout))
        #expect(nonMatching.stdout.contains("\"truth_value\" : \"false\""), Comment(rawValue: nonMatching.stdout))
    }
}

private struct TraceEvalFixture {
    let dir: SlowTempDir
    let fileURL: URL
    let instant: String
}

private func makeTraceEvalFixture(singleRun: Bool) async throws -> TraceEvalFixture {
    let dir = SlowTempDir(prefix: "meridian-trace-eval")
    let fileURL = dir.url.appendingPathComponent("events.jsonl")
    let store = try JSONLTraceStore(fileURL: fileURL)
    let base = Date(timeIntervalSince1970: 1_719_792_000)

    try await store.append(TraceRecord(
        id: "rec-1",
        at: base,
        ingestOrder: 1,
        run: "run-1",
        step: "deploy",
        skillName: "TraceEvalFlow",
        skillVersionHash: "v1",
        tag: .failed,
        subject: "deploy",
        payload: ["tool": .string("deploy")],
        payloadHash: try CanonicalJSON.sha256Hex(for: ["tool": .string("deploy")]),
        outcome: .failure
    ))

    try await store.append(TraceRecord(
        id: "rec-2",
        at: base.addingTimeInterval(2),
        ingestOrder: 2,
        run: singleRun ? "run-1" : "run-2",
        step: "deploy",
        skillName: "TraceEvalFlow",
        skillVersionHash: "v1",
        tag: .completed,
        subject: "deploy",
        payload: ["tool": .string("deploy")],
        payloadHash: try CanonicalJSON.sha256Hex(for: ["tool": .string("deploy")]),
        outcome: .success
    ))

    return TraceEvalFixture(
        dir: dir,
        fileURL: fileURL,
        instant: ISO8601DateFormatter.meridianFormatter.string(from: base.addingTimeInterval(5))
    )
}
