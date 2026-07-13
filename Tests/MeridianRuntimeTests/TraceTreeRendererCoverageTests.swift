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

    @Test("semantic trace envelopes render TraceTag labels while legacy JSONL still works")
    func semanticEnvelopeParsing() {
        let jsonl = """
        {"record":{"schemaVersion":1,"id":"01HX1","at":"2026-07-11T00:00:00.000Z","ingestOrder":1,"run":"run-1","step":"root","skillName":"SemanticFlow","skillVersionHash":"abc123","tag":"invoked","subject":"workflow","payloadHash":"ph1","outcome":"success"},"checksum":"ignored-by-renderer"}
        {"record":{"schemaVersion":1,"id":"01HX2","at":"2026-07-11T00:00:01.000Z","ingestOrder":2,"run":"run-1","step":"root/tool","skillName":"SemanticFlow","skillVersionHash":"abc123","tag":"judged","subject":"risk-check","payloadHash":"ph2","outcome":"failure"},"checksum":"ignored-by-renderer"}
        {"record":{"schemaVersion":1,"id":"01HX3","at":"2026-07-11T00:00:02.000Z","ingestOrder":3,"run":"run-1","step":"root","skillName":"SemanticFlow","skillVersionHash":"abc123","tag":"completed","subject":"workflow","payloadHash":"ph3","outcome":"success"},"checksum":"ignored-by-renderer"}
        {"run_id":"run-2","seq":1,"kind":"workflow.started","payload":{"workflowName":"LegacyFlow"}}
        {"run_id":"run-2","seq":2,"kind":"workflow.completed","payload":{"reason":"ok","duration_ms":5}}
        """
        let out = TraceTreeRenderer().render(jsonl: jsonl)
        for needle in ["SemanticFlow", "invoked     workflow", "judged      risk-check (failure)", "completed   workflow (success)", "LegacyFlow"] {
            #expect(out.contains(needle), Comment(rawValue: "missing \(needle) in:\n\(out)"))
        }
    }

    @Test("numeric and boolean payload values stringify in labels")
    func numericPayloadLabels() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "W"]),
            ev("iterate.iteration", ["index": 3], seq: 1),
            ev("branch.taken", ["into": "then", "condition": true], seq: 2),
            ev("wait.resume", ["duration_ms": 2.5], seq: 3),
            ev("workflow.completed", ["reason": "ok", "duration_ms": NSNumber(value: 9)], seq: 4),
        ]
        let out = TraceTreeRenderer(options: .init(showSourceRanges: false, showTimings: true)).render(events: events)
        #expect(out.contains("#3"))
        #expect(out.contains("(1)"))
        #expect(out.contains("→ 2.5ms"))
        #expect(out.contains("9ms)"))
        #expect(!out.contains("@"))
    }

    @Test("invoke.end without duration omits the timing suffix")
    func invokeEndWithoutDuration() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "W"]),
            ev("invoke.end", [:], seq: 1),
            ev("workflow.completed", ["reason": "ok"], seq: 2),
        ]
        let out = TraceTreeRenderer().render(events: events)
        #expect(out.contains("↳ ok"))
        #expect(!out.contains("→"))
    }

    // MARK: - Frame stack: iterate nesting

    @Test("a single iterate block indents its body one level and closes with an end glyph")
    func iterateBodyIndented() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "W"]),
            ev("iterate.start", ["over": "items"], seq: 1),
            ev("iterate.iteration", ["index": 0], seq: 2),
            ev("invoke.start", ["tool": "charge"], seq: 3),
            ev("iterate.end", [:], seq: 4),
            ev("workflow.completed", ["reason": "ok"], seq: 5),
        ]
        let out = TraceTreeRenderer().render(events: events)
        let lines = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        // The loop header itself is not indented (top-level sibling of `complete`).
        #expect(lines.contains { $0.contains("├─") && $0.contains("iterate") && !$0.contains("│") })
        // Body rows (iteration, invoke) are indented one level under the loop.
        #expect(lines.contains { $0.contains("│  ├─") && $0.contains("#0") })
        #expect(lines.contains { $0.contains("│  ├─") && $0.contains("invoke") })
        // The closing marker renders as the loop's last (nested) child, with
        // an end glyph, not as a flat sibling of the loop header.
        #expect(lines.contains { $0.contains("│  └─") && $0.contains("↳ done") })
        // `complete` returns to the top level after the loop closes.
        #expect(lines.contains { $0.contains("└─") && $0.contains("complete") && !$0.contains("│") })
    }

    @Test("a loop nested inside another loop indents two levels deep")
    func nestedIterateTwoLevels() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "W"]),
            ev("iterate.start", ["over": "orders"], seq: 1),
            ev("iterate.start", ["over": "lineItems"], seq: 2),
            ev("invoke.start", ["tool": "priceLine"], seq: 3),
            ev("iterate.end", [:], seq: 4),
            ev("iterate.end", [:], seq: 5),
            ev("workflow.completed", ["reason": "ok"], seq: 6),
        ]
        let out = TraceTreeRenderer().render(events: events)
        let lines = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines.contains { $0.contains("orders") && $0.contains("iterate") && !$0.contains("│") })
        #expect(lines.contains { $0.contains("│  ├─") && $0.contains("lineItems") })
        #expect(lines.contains { $0.contains("│  │  ├─") && $0.contains("invoke") })
        // Inner loop's own close is nested two levels; outer loop's close one level.
        #expect(lines.contains { $0.contains("│  │  └─") && $0.contains("↳ done") })
        #expect(lines.contains { $0.contains("│  └─") && $0.contains("↳ done") && !$0.contains("│  │") })
    }

    @Test("an event after a closed loop returns to the outer indent level")
    func afterLoopReturnsToOuterLevel() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "W"]),
            ev("iterate.start", ["over": "items"], seq: 1),
            ev("invoke.start", ["tool": "t"], seq: 2),
            ev("iterate.end", [:], seq: 3),
            ev("emit", ["event": "done.emitting"], seq: 4),
            ev("workflow.completed", ["reason": "ok"], seq: 5),
        ]
        let out = TraceTreeRenderer().render(events: events)
        let lines = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines.contains { $0.contains("emit") && $0.contains("done.emitting") && !$0.contains("│") })
    }

    @Test("an unmatched iterate.end (no open frame) does not underflow the stack")
    func unmatchedIterateEndIsSafe() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "W"]),
            ev("iterate.end", [:], seq: 1),
            ev("workflow.completed", ["reason": "ok"], seq: 2),
        ]
        let out = TraceTreeRenderer().render(events: events)
        #expect(out.contains("↳ done"))
        #expect(out.contains("complete"))
    }

    @Test("branch.taken/end nest the arm body under the decision")
    func branchNestsBody() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "W"]),
            ev("branch.taken", ["into": "then", "condition": "valid"], seq: 1),
            ev("invoke.start", ["tool": "charge"], seq: 2),
            ev("branch.end", ["into": "then"], seq: 3),
            ev("workflow.completed", ["reason": "ok"], seq: 4),
        ]
        let out = TraceTreeRenderer().render(events: events)
        let lines = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines.contains { $0.contains("branch") && !$0.contains("│") })
        #expect(lines.contains { $0.contains("invoke") && $0.contains("│") })
        #expect(lines.contains { $0.contains("↳ end") })
        #expect(lines.contains { $0.contains("complete") && !$0.contains("│") })
    }

    @Test("ASCII glyph mode draws the ancestor guide with `|` instead of `│`")
    func asciiAncestorGuide() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "W"]),
            ev("iterate.start", ["over": "items"], seq: 1),
            ev("invoke.start", ["tool": "t"], seq: 2),
            ev("iterate.end", [:], seq: 3),
            ev("workflow.completed", ["reason": "ok"], seq: 4),
        ]
        let out = TraceTreeRenderer(options: .init(unicodeGlyphs: false)).render(events: events)
        #expect(!out.contains("│"))
        #expect(out.contains("|  |-") || out.contains("|  \\-"))
    }

    @Test("semanticTag labels cover TraceTag surface forms and header fallbacks")
    func semanticTagLabelMatrix() {
        func sem(
            _ tag: String,
            payload: [String: Any] = [:],
            seq: Int
        ) -> RE {
            RE(
                runID: "r1",
                sequence: seq,
                kind: "ignored.kind",
                payload: payload,
                semanticTag: tag
            )
        }
        let events: [RE] = [
            sem("invoked", payload: ["skillName": "OnlySkill", "tool": "http.get", "subject": "workflow"], seq: 0),
            sem("emitted", payload: ["event": "order.placed"], seq: 1),
            sem("asserted", payload: ["message": "ok"], seq: 2),
            sem("assert-failed", payload: ["message": "nope"], seq: 3),
            sem("branched", payload: ["into": "then"], seq: 4),
            sem("iterated", payload: ["index": 2], seq: 5),
            sem("iterated", payload: ["over": "items"], seq: 6),
            sem("judged", payload: ["subject": "risk"], seq: 7),
            sem("committed", payload: ["label": "cp"], seq: 8),
            sem("recovered", payload: ["pattern": "any"], seq: 9),
            sem("violated", payload: ["subject": "charge"], seq: 10),
            sem("failed", payload: ["subject": "tool"], seq: 11),
            sem("completed", payload: ["subject": "workflow", "duration_ms": 12], seq: 12),
            RE(
                runID: "r1",
                sequence: 13,
                kind: "ignored",
                payload: ["subject": ["nested": true] as [String: Any]],
                semanticTag: "emitted"
            ),
        ]
        let out = TraceTreeRenderer(options: .init(showSourceRanges: false, showTimings: true)).render(events: events)
        for needle in [
            "OnlySkill", "invoked", "workflow", "emitted", "order.placed",
            "asserted", "branched", "iterated", "judged",
            "committed", "recovered", "violated", "failed", "completed",
        ] {
            #expect(out.contains(needle), Comment(rawValue: "missing \(needle) in:\n\(out)"))
        }
    }

    @Test("semantic JSONL promotes ingestOrder string and skill-only header")
    func semanticJSONLFieldPromotion() {
        let jsonl = """
        {"record":{"schemaVersion":1,"id":"01","at":"2026-07-11T00:00:00.000Z","ingestOrder":"1","run":"run-1","step":"root","skillName":"SkillOnly","skillVersionHash":"h","tag":"invoked","subject":"tool","payload":{"tool":"t1","outcome":"success","witness":"w","operationalDetail":"d","legacyKind":"invoke.start"},"payloadHash":"ph","outcome":"success"},"checksum":"x"}
        {"record":{"schemaVersion":1,"id":"02","at":"2026-07-11T00:00:01.000Z","ingestOrder":2,"run":"run-1","step":"root","skillName":"SkillOnly","skillVersionHash":"h","tag":"completed","subject":"workflow","payloadHash":"ph2","outcome":"success"},"checksum":"x"}
        """
        let out = TraceTreeRenderer().render(jsonl: jsonl)
        #expect(out.contains("SkillOnly"))
        #expect(out.contains("invoked") || out.contains("t1"))
        #expect(out.contains("completed"))
    }

    @Test("workflow-only tree with no body still renders header and complete")
    func workflowOnlyHeader() {
        let events: [RE] = [
            ev("workflow.started", ["workflowName": "Solo"]),
            ev("workflow.completed", ["reason": "ok", "duration_ms": 3], seq: 1),
        ]
        let out = TraceTreeRenderer().render(events: events)
        #expect(out.contains("Solo"))
        #expect(out.contains("complete"))
    }
}
