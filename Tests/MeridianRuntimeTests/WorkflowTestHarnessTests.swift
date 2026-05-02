import Testing
import Foundation
import MeridianTestKit
@testable import MeridianRuntime

@Suite("WorkflowTestHarness")
struct WorkflowTestHarnessTests {

    @Test("captures invoke + workflow events in order, succeeded=true on completion")
    func happyPathRun() async throws {
        let harness = await WorkflowTestHarness()
        await harness.stub(tool: "validateOrder",
                            return: .record(["verdict": .string("valid")]))

        let outcome = try await harness.run { runtime in
            await runtime.workflowStarted(workflowName: "Demo", parameters: [:])
            let v = try await runtime.invoke(tool: "validateOrder", args: [:])
            await runtime.complete(reason: nil)
            return v
        }

        #expect(outcome.succeeded)
        let kinds = await harness.eventKinds()
        #expect(kinds.first == .workflowStarted)
        #expect(kinds.contains(.invokeStart))
        #expect(kinds.contains(.invokeEnd))
        #expect(kinds.last == .workflowCompleted)
    }

    @Test("stub(tool:return:) returns the fixed value for any args")
    func fixedReturnStub() async throws {
        let harness = await WorkflowTestHarness()
        await harness.stub(tool: "answer", return: .number(42))
        let outcome = try await harness.run { runtime in
            await runtime.workflowStarted(workflowName: "Q", parameters: [:])
            let v = try await runtime.invoke(tool: "answer", args: ["x": .string("?")])
            await runtime.complete(reason: nil)
            return v
        }
        if case .number(let n) = outcome.result {
            #expect(n == 42)
        } else {
            Issue.record("expected .number(42), got \(outcome.result)")
        }
    }

    @Test("a thrown error is captured in events with succeeded=false")
    func failureMarksRunResult() async throws {
        let harness = await WorkflowTestHarness()
        let outcome = try await harness.run { runtime in
            await runtime.workflowStarted(workflowName: "Boom", parameters: [:])
            throw MeridianRuntimeError.toolError(
                .implementation(code: "boom", message: "kaboom", cause: nil),
                sourceRange: nil
            )
        }
        #expect(!outcome.succeeded)
        let kinds = await harness.eventKinds()
        #expect(kinds.contains(.workflowStarted))
    }

    @Test("FixedClock keeps event timestamps deterministic across the run")
    func fixedClockIsDeterministic() async throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let harness = await WorkflowTestHarness(clockStart: start)
        await harness.stub(tool: "noop", return: .null)
        _ = try await harness.run { runtime in
            await runtime.workflowStarted(workflowName: "Tick", parameters: [:])
            harness.clock.advance(by: 0.001)
            _ = try await runtime.invoke(tool: "noop", args: [:])
            await runtime.complete(reason: nil)
            return .null
        }
        let events = await harness.events()
        #expect(events.first?.timestamp == start)
    }
}
