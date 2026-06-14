import Testing
import Foundation
@testable import MeridianRuntime

@Suite("TraceTreeRenderer — every label, glyph mode, and JSONL parse path")
struct TraceTreeRendererCoverageTests {

    private typealias RE = TraceTreeRenderer.RawEvent

    private func ev(_ kind: String, _ payload: [String: Any] = [:], seq: Int = 0,
                    run: String = "r1", file: String? = nil, line: Int? = nil) -> RE {
        RE(runID: run, sequence: seq, kind: kind, payload: payload, sourceFile: file, sourceLine: line)
    }

    @Test("empty trace renders a placeholder")
    func empty() {
        #expect(TraceTreeRenderer().render(events: []) == "(empty trace)\n")
        #expect(TraceTreeRenderer().render(jsonl: "") == "(empty trace)\n")
    }

    @Test("every labelFor case is exercised")
    func allLabels() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "ProcessOrder"]),
            ev("invoke.start", ["tool": "http.get"], seq: 1),
            ev("invoke.end", ["duration_ms": 4], seq: 2),
            ev("invoke.error", ["error_code": "boom"], seq: 3),
            ev("branch.taken", ["into": "then", "condition": "valid"], seq: 4),
            ev("iterate.start", ["over": "items"], seq: 5),
            ev("iterate.iteration", ["index": 0], seq: 6),
            ev("iterate.end", [:], seq: 7),
            ev("assert.passed", ["message": "ok"], seq: 8),
            ev("assert.failed", ["message": "nope"], seq: 9),
            ev("wait.start", [:], seq: 10),
            ev("wait.resume", ["duration_ms": 2], seq: 11),
            ev("emit", ["event": "order.placed"], seq: 12),
            ev("emit.error", ["event": "order.placed"], seq: 13),
            ev("commit", ["label": "cp"], seq: 14),
            ev("recover.engaged", ["pattern": "anyError"], seq: 15),
            ev("bind", ["name": "x"], seq: 16),
            ev("workflow.failed", ["error": "oops"], seq: 17),
            ev("workflow.cancelled", [:], seq: 18),
            ev("workflow.suspended", [:], seq: 19),
            ev("workflow.resumed", [:], seq: 20),
            ev("some.unknown.kind", [:], seq: 21),
            ev("workflow.completed", ["reason": "done", "duration_ms": 81], seq: 22),
        ]
        let out = TraceTreeRenderer().render(events: events)
        for needle in ["ProcessOrder", "invoke", "http.get", "↳ ok", "↳ error boom",
                       "branch", "→ then", "iterate", "items", "#0", "↳ done",
                       "assert ✓", "assert ✗", "wait", "↳ resumed", "→ 2ms",
                       "emit", "order.placed", "emit ✗", "commit", "cp",
                       "recover", "anyError", "bind", "failed", "cancelled",
                       "suspended", "resumed", "some.unknown.kind", "complete", "done"] {
            #expect(out.contains(needle), Comment(rawValue: "missing \(needle) in:\n\(out)"))
        }
    }

    @Test("ASCII glyphs + timings off + source ranges")
    func optionVariants() {
        let opts = TraceTreeRenderer.Options(showSourceRanges: true, showTimings: false, unicodeGlyphs: false)
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "W"]),
            ev("invoke.start", ["tool": "t"], seq: 1, file: "f.meridian", line: 9),
            ev("workflow.completed", ["reason": "ok"], seq: 2),
        ]
        let out = TraceTreeRenderer(options: opts).render(events: events)
        #expect(out.contains("* W"))            // ASCII header glyph
        #expect(out.contains("|-") || out.contains("\\-"))  // ASCII tree glyphs
        #expect(out.contains("@f.meridian:9"))  // source suffix
    }

    @Test("multiple run_ids render as sibling trees")
    func multipleRuns() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "A"], run: "r1"),
            ev("workflow.completed", ["reason": "ok"], seq: 1, run: "r1"),
            ev("workflow.started", ["workflowName": "B"], run: "r2"),
            ev("workflow.completed", ["reason": "ok"], seq: 1, run: "r2"),
        ]
        let out = TraceTreeRenderer().render(events: events)
        #expect(out.contains("A"))
        #expect(out.contains("B"))
    }

    @Test("JSONL parsing: valid lines, promoted tool field, source, and skipped garbage")
    func jsonlParsing() {
        let jsonl = """
        not json at all
        {"run_id":"r1","seq":0,"kind":"workflow.started","payload":{"workflowName":"X"}}
        {"run_id":"r1","seq":1,"kind":"invoke.start","tool":"http.get","source":{"file":"a.meridian","line":3}}
        {"run_id":"r1","seq":2,"kind":"workflow.completed","payload":{"reason":"ok","duration_ms":5}}
        """
        let out = TraceTreeRenderer().render(jsonl: jsonl)
        #expect(out.contains("X"))
        #expect(out.contains("http.get"))
        #expect(out.contains("@a.meridian:3"))
    }
}
