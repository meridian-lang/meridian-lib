import Foundation
import Testing
@testable import MeridianRuntime

@Suite("EventMigration coverage")
struct EventMigrationCoverageTests {

    private func record(
        _ kind: EventKind,
        payload: [String: Value] = [:],
        sequence: Int = 0
    ) throws -> TraceRecord {
        try TraceRecord(
            kind: kind,
            at: Date(timeIntervalSince1970: Double(sequence)),
            run: "run-1",
            ingestOrder: sequence,
            skillName: "skill",
            skillVersionHash: "h",
            id: "id-\(sequence)",
            payload: payload
        )
    }

    @Test("the kind table maps every EventKind with subject priority")
    func mappingMatrix() throws {
        var seq = 0
        func next(_ kind: EventKind, payload: [String: Value]) throws -> TraceRecord {
            defer { seq += 1 }
            return try record(kind, payload: payload, sequence: seq)
        }

        let workflow = try next(.workflowStarted, payload: ["workflow": .string("OrderFlow")])
        #expect(workflow.tag == .invoked)
        #expect(workflow.subject == "OrderFlow")
        #expect(workflow.kind == .workflowStarted)

        let completed = try next(.workflowCompleted, payload: [:])
        #expect(completed.tag == .completed)
        #expect(completed.subject == "workflow")

        let cancelled = try next(.workflowCancelled, payload: ["kind": .string("signal")])
        #expect(cancelled.tag == .emitted)
        #expect(cancelled.outcome == .indeterminate)
        #expect(cancelled.subject == "signal")

        let invoke = try next(.invokeStart, payload: ["tool": .string("sendEmail")])
        #expect(invoke.tag == .invoked)
        #expect(invoke.subject == "sendEmail")

        let planError = try next(.planError, payload: ["event": .string("plan.x")])
        #expect(planError.tag == .judged)
        #expect(planError.outcome == .failure)
        #expect(planError.subject == "plan.x")

        let autonomyFail = try next(.autonomyStep, payload: [
            "tool": .string("act"),
            "status": .string("failure"),
        ])
        #expect(autonomyFail.outcome == .failure)

        let autonomyOK = try next(.autonomyEnd, payload: ["tool": .string("act")])
        #expect(autonomyOK.outcome == .success)

        let assertedIndeterminate = try next(.assertPassed, payload: [
            "outcome": .string(TruthValue.indeterminate.rawValue),
        ])
        #expect(assertedIndeterminate.tag == .asserted)
        #expect(assertedIndeterminate.outcome == .indeterminate)

        let emitError = try next(.emitError, payload: ["event": .string("x")])
        #expect(emitError.tag == .failed)
        #expect(emitError.operationalDetail == EventKind.emitError.rawValue)

        let violated = try next(.violated, payload: [
            "tool_id": .string("charge"),
            "disposition": .string("blocked"),
        ])
        #expect(violated.tag == .violated)
        #expect(violated.operationalDetail == "blocked")
        #expect(violated.subject == "charge")

        let planStart = try next(.planStart, payload: [
            "scoped_tools": .list([.string("ci.fix")]),
            "input_payload_hash": .string("deadbeef"),
            "output_kind": .string("record"),
            "step": .string("root/aiJudgment"),
        ])
        #expect(planStart.tag == .judged)
        #expect(planStart.step == "root/aiJudgment")
        #expect(planStart.payload?["scoped_tools"] == .list([.string("ci.fix")]))
        #expect(planStart.payload?["input_payload_hash"] == .string("deadbeef"))
        #expect(!planStart.payloadHash.isEmpty)

        // Sweep remaining kinds so every switch arm is warm.
        for kind in EventKind.allCases {
            _ = try next(kind, payload: samplePayload(for: kind))
        }
    }

    @Test("subjectKey and empty payloads keep the legacy record shape")
    func payloadShape() throws {
        let keyed = try record(.emit, payload: [
            "event": .string("order.placed"),
            "subject_key": .string("orders"),
        ])
        #expect(keyed.subjectKey == "orders")
        #expect(keyed.payload?["event"] == .string("order.placed"))

        let empty = try record(.waitResume, payload: [:])
        #expect(empty.payload == nil)
        #expect(empty.step == EventKind.waitResume.rawValue)
    }

    private func samplePayload(for kind: EventKind) -> [String: Value] {
        switch kind {
        case .workflowStarted, .workflowCompleted, .workflowFailed:
            return ["workflow": .string("workflow")]
        case .invokeStart, .invokeEnd, .invokeError, .autonomyStep:
            return ["tool": .string("tool")]
        case .emit, .emitError:
            return ["event": .string("event")]
        case .waitStart:
            return ["kind": .string("signal")]
        case .assertPassed:
            return ["outcome": .string("true")]
        case .violated:
            return ["tool_id": .string("t"), "disposition": .string("prevented")]
        default:
            return ["message": .string(kind.rawValue)]
        }
    }
}
