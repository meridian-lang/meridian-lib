import Testing
import Foundation
@testable import MeridianRuntime

// Phase 1 (pure-helper tail, runtime side): TraceTreeRenderer label arms and the
// heterogeneous `stringValue` type ladder. Driven through the public
// render(events:)/render(jsonl:) entry points.

@Suite("Reachable coverage — TraceTreeRenderer")
struct ReachableCoverageRuntimeTailTests {

    private func ev(_ kind: String, _ seq: Int, _ payload: [String: Any] = [:]) -> TraceTreeRenderer.RawEvent {
        TraceTreeRenderer.RawEvent(runID: "R1", sequence: seq, kind: kind, payload: payload)
    }

    @Test("render(events:) labels every event kind and reads Int/Double/Bool payloads")
    func rendersAllKinds() {
        let events: [TraceTreeRenderer.RawEvent] = [
            ev("workflow.started", 0, ["workflowName": "Demo"]),
            ev("invoke.start", 1, ["tool": "t.run"]),
            ev("invoke.end", 2, ["duration_ms": 4.5]),                // Double arm
            ev("invoke.error", 3, ["error_code": "boom"]),
            ev("branch.taken", 4, ["into": "then", "condition": "ok"]),
            ev("iterate.start", 5, ["over": "items"]),
            ev("iterate.iteration", 6, ["index": 2]),                 // Int arm
            ev("iterate.end", 7),
            ev("assert.passed", 8, ["message": "good"]),
            ev("assert.failed", 9, ["message": "bad"]),
            ev("wait.start", 10),
            ev("wait.resume", 11, ["duration_ms": 12]),
            ev("emit", 12, ["event": "thing.happened"]),
            ev("emit.error", 13, ["event": "thing.failed"]),
            ev("commit", 14, ["label": "checkpoint"]),
            ev("recover.engaged", 15, ["pattern": "any"]),
            ev("bind", 16, ["name": "result", "ok": true]),           // Bool arm
            ev("workflow.failed", 17, ["error": "kaput"]),
            ev("workflow.cancelled", 18),
            ev("workflow.suspended", 19),
            ev("workflow.resumed", 20),
            ev("workflow.completed", 21, ["reason": "ok", "duration_ms": 99.0]),
        ]
        let out = TraceTreeRenderer().render(events: events)
        for needle in ["invoke      t.run", "branch", "→ then", "iterate", "#2", "assert ✓",
                       "assert ✗", "emit        thing.happened", "commit      checkpoint",
                       "recover     any", "bind        result", "failed      kaput",
                       "cancelled", "suspended", "resumed", "complete    (reason: ok)",
                       "↳ error boom"] {
            #expect(out.contains(needle), Comment(rawValue: "missing \(needle) in:\n\(out)"))
        }
    }

    @Test("render(jsonl:) parses NSNumber payloads and groups multiple runs")
    func rendersJSONL() {
        let jsonl = """
        {"run_id":"A","seq":0,"kind":"workflow.started","payload":{"workflowName":"First"}}
        {"run_id":"A","seq":1,"kind":"invoke.start","tool":"alpha"}
        {"run_id":"B","seq":0,"kind":"workflow.started","payload":{"workflowName":"Second"}}
        {"run_id":"B","seq":1,"kind":"workflow.completed","payload":{"reason":"done","duration_ms":3}}
        not-json-skip-me
        """
        let out = TraceTreeRenderer().render(jsonl: jsonl)
        #expect(out.contains("First"))
        #expect(out.contains("Second"))
        #expect(out.contains("alpha"))
    }

    @Test("empty stream renders the empty marker; RawEvent equality compares identity fields")
    func emptyAndEquality() {
        #expect(TraceTreeRenderer().render(events: []) == "(empty trace)\n")
        let a = ev("emit", 1, ["event": "x"])
        let b = ev("emit", 1, ["event": "DIFFERENT"])   // payload ignored by ==
        let c = ev("emit", 2)
        #expect(a == b)
        #expect(a != c)
    }
}
