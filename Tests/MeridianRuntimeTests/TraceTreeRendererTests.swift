import Testing
import Foundation
@testable import MeridianRuntime

@Suite("TraceTreeRenderer")
struct TraceTreeRendererTests {

    // MARK: - Fixtures

    /// A tiny JSONL stream representing a happy-path ProcessOrder run:
    /// validate → branch(valid → then) → charge → emit → complete.
    private let happyPath = """
    {"ts":"2025-01-01T00:00:00Z","run_id":"r-1","seq":1,"kind":"workflow.started","payload":{"workflowName":"ProcessOrder"}}
    {"ts":"2025-01-01T00:00:00Z","run_id":"r-1","seq":2,"kind":"invoke.start","tool":"validateOrder","payload":{}}
    {"ts":"2025-01-01T00:00:00Z","run_id":"r-1","seq":3,"kind":"invoke.end","tool":"validateOrder","payload":{"duration_ms":4}}
    {"ts":"2025-01-01T00:00:00Z","run_id":"r-1","seq":4,"kind":"branch.taken","payload":{"into":"then","condition":"verdict == valid"}}
    {"ts":"2025-01-01T00:00:00Z","run_id":"r-1","seq":5,"kind":"invoke.start","tool":"chargePayment","payload":{}}
    {"ts":"2025-01-01T00:00:00Z","run_id":"r-1","seq":6,"kind":"invoke.end","tool":"chargePayment","payload":{"duration_ms":12}}
    {"ts":"2025-01-01T00:00:00Z","run_id":"r-1","seq":7,"kind":"emit","payload":{"event":"order.charged"}}
    {"ts":"2025-01-01T00:00:00Z","run_id":"r-1","seq":8,"kind":"workflow.completed","payload":{"reason":null,"duration_ms":81}}
    """

    // MARK: - Tests

    @Test("renders a header line with workflow name + run_id + event count")
    func headerLine() {
        let out = TraceTreeRenderer().render(jsonl: happyPath)
        #expect(out.contains("ProcessOrder"))
        #expect(out.contains("run_id=r-1"))
        #expect(out.contains("8 events"))
        #expect(out.contains("81ms"))
    }

    @Test("each event lands on its own row with the right glyph")
    func perRowRendering() {
        let out = TraceTreeRenderer().render(jsonl: happyPath)
        let lines = out.split(separator: "\n").map(String.init)

        // Header + 7 body rows (workflow.started is the header).
        #expect(lines.count >= 8)
        #expect(lines.contains { $0.contains("invoke      validateOrder") })
        #expect(lines.contains { $0.contains("branch      (verdict == valid) → then") })
        #expect(lines.contains { $0.contains("invoke      chargePayment") })
        #expect(lines.contains { $0.contains("emit        order.charged") })
        #expect(lines.contains { $0.contains("complete") })
    }

    @Test("invoke.end carries duration_ms when timings are enabled")
    func invokeTimings() {
        let out = TraceTreeRenderer(options: .init(showTimings: true))
            .render(jsonl: happyPath)
        #expect(out.contains("→ 4ms"))
        #expect(out.contains("→ 12ms"))
    }

    @Test("disabling timings hides the duration column")
    func timingsHidden() {
        let out = TraceTreeRenderer(options: .init(showTimings: false))
            .render(jsonl: happyPath)
        #expect(!out.contains("→ 4ms"))
        #expect(!out.contains("→ 12ms"))
    }

    @Test("ASCII glyph mode does not emit Unicode box-drawing characters")
    func asciiGlyphs() {
        let out = TraceTreeRenderer(options: .init(unicodeGlyphs: false))
            .render(jsonl: happyPath)
        #expect(!out.contains("├"))
        #expect(!out.contains("└"))
        #expect(out.contains("|-") || out.contains("\\-"))
    }

    @Test("source ranges surface as suffix when present")
    func sourceRangeSuffix() {
        let withSource = """
        {"ts":"2025-01-01T00:00:00Z","run_id":"r-2","seq":1,"kind":"workflow.started","payload":{"workflowName":"X"}}
        {"ts":"2025-01-01T00:00:00Z","run_id":"r-2","seq":2,"kind":"emit","payload":{"event":"e1"},"source":{"file":"x.meridian","line":42,"col":1}}
        {"ts":"2025-01-01T00:00:00Z","run_id":"r-2","seq":3,"kind":"workflow.completed","payload":{}}
        """
        let out = TraceTreeRenderer().render(jsonl: withSource)
        #expect(out.contains("@x.meridian:42"))
    }

    @Test("multi-run streams render as sibling trees in arrival order")
    func multipleRuns() {
        let twoRuns = """
        {"ts":"2025-01-01T00:00:00Z","run_id":"r-A","seq":1,"kind":"workflow.started","payload":{"workflowName":"A"}}
        {"ts":"2025-01-01T00:00:00Z","run_id":"r-A","seq":2,"kind":"workflow.completed","payload":{}}
        {"ts":"2025-01-01T00:00:00Z","run_id":"r-B","seq":1,"kind":"workflow.started","payload":{"workflowName":"B"}}
        {"ts":"2025-01-01T00:00:00Z","run_id":"r-B","seq":2,"kind":"workflow.completed","payload":{}}
        """
        let out = TraceTreeRenderer().render(jsonl: twoRuns)
        let aIdx = out.range(of: "run_id=r-A")?.lowerBound
        let bIdx = out.range(of: "run_id=r-B")?.lowerBound
        #expect(aIdx != nil && bIdx != nil)
        if let a = aIdx, let b = bIdx { #expect(a < b) }
    }

    @Test("malformed lines are skipped rather than failing the whole render")
    func malformedSurvives() {
        let malformed = """
        not a json line at all
        {"ts":"2025-01-01T00:00:00Z","run_id":"r-X","seq":1,"kind":"workflow.started","payload":{"workflowName":"X"}}
        another non-json line
        {"ts":"2025-01-01T00:00:00Z","run_id":"r-X","seq":2,"kind":"workflow.completed","payload":{}}
        """
        let out = TraceTreeRenderer().render(jsonl: malformed)
        #expect(out.contains("X"))
        #expect(out.contains("complete"))
    }

    @Test("empty input renders an `(empty trace)` placeholder")
    func emptyInput() {
        let out = TraceTreeRenderer().render(jsonl: "")
        #expect(out == "(empty trace)\n")
    }
}
