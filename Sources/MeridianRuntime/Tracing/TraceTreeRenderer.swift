import Foundation

// MARK: - TraceTreeRenderer
//
// Pretty-prints a JSONL event stream as an indented tree:
//
//   ▶ ProcessOrder  (run_id=… 12 events 81ms)
//     ├─ invoke validateOrder        →  4ms
//     ├─ iterate over items
//     │  ├─ · #0
//     │  │  ├─ invoke chargePayment  → 12ms
//     │  │  └─ emit   order.charged
//     │  └─ ↳ done
//     └─ complete
//
// Pure: takes events in, returns a String. No process/file IO. The CLI's
// `meridian trace render` subcommand wraps this with stdin/stdout glue.
//
// Why this shape? Three rules of thumb:
//   1. **One line per IR statement**, so the tree mirrors the workflow source
//      a developer wrote. invoke / emit / branch / iterate / wait /
//      complete each get their own row.
//   2. **Children indent under their parent — for blocks with a paired
//      start/end marker in the event stream.** `iterate.start`/`iterate.end`
//      and `branch.taken`/`branch.end` are explicitly paired, so a loop or
//      branch arm body (and any nesting inside it) renders as indented
//      children via the `Frame` stack in `renderRun`.
//   3. **Right-aligned timing where it matters.** invoke → duration_ms.
//      assert/emit/etc. don't get a duration column unless the event
//      itself carries one.

public struct TraceTreeRenderer {

    public struct Options: Sendable {
        /// Show each event's source-range suffix (`@order_processing.meridian:42`).
        public var showSourceRanges: Bool
        /// Show timing column for invoke/wait events.
        public var showTimings: Bool
        /// Use Unicode box-drawing characters (`├─ └─ │`) versus ASCII (`|- \- |`).
        public var unicodeGlyphs: Bool

        public init(
            showSourceRanges: Bool = true,
            showTimings: Bool = true,
            unicodeGlyphs: Bool = true
        ) {
            self.showSourceRanges = showSourceRanges
            self.showTimings = showTimings
            self.unicodeGlyphs = unicodeGlyphs
        }

        public static let `default` = Options()
    }

    public let options: Options

    public init(options: Options = .default) {
        self.options = options
    }

    // MARK: - Public entry points

    /// Render a JSONL stream (one event per line) into an indented tree.
    /// Events that don't parse as JSON objects are skipped silently.
    public func render(jsonl: String) -> String {
        let events = parseJSONL(jsonl)
        return render(events: events)
    }

    /// Render an already-parsed sequence of `RawEvent`s. Useful for tests
    /// that don't want to round-trip through string serialisation.
    public func render(events: [RawEvent]) -> String {
        guard !events.isEmpty else { return "(empty trace)\n" }
        var lines: [String] = []
        var stack: [Frame] = []

        // Group events by run_id so multi-workflow streams render as
        // sibling trees rather than one long, ambiguous trunk.
        let groups = groupByRun(events)
        for (i, group) in groups.enumerated() {
            renderRun(group, into: &lines, stack: &stack)
            if i < groups.count - 1 { lines.append("") }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Raw event model
    //
    // A minimal projection of the JSONL shape — keeps the renderer free of
    // any direct dependency on `TraceRecord` / `EventKind`. CLI callers can
    // feed raw decoded JSON in too.

    /// `payload` is `[String: Any]` because the renderer reads heterogeneous
    /// JSON shapes the runtime promotes (numbers, bools, nested dicts, …)
    /// without converting them back into `Value`. The struct is marked
    /// `@unchecked Sendable` because the renderer never mutates the
    /// payload after construction; callers passing values across actor
    /// boundaries are responsible for the underlying types.
    public struct RawEvent: @unchecked Sendable, Equatable {
        public let runID: String
        public let parentRunID: String?
        public let sequence: Int
        public let kind: String
        public let payload: [String: Any]
        public let sourceFile: String?
        public let sourceLine: Int?
        public let semanticTag: String?

        public init(
            runID: String,
            parentRunID: String? = nil,
            sequence: Int,
            kind: String,
            payload: [String: Any] = [:],
            sourceFile: String? = nil,
            sourceLine: Int? = nil,
            semanticTag: String? = nil
        ) {
            self.runID = runID
            self.parentRunID = parentRunID
            self.sequence = sequence
            self.kind = kind
            self.payload = payload
            self.sourceFile = sourceFile
            self.sourceLine = sourceLine
            self.semanticTag = semanticTag
        }

        public static func == (lhs: RawEvent, rhs: RawEvent) -> Bool {
            lhs.runID == rhs.runID
                && lhs.sequence == rhs.sequence
                && lhs.kind == rhs.kind
        }
    }

    // MARK: - Private rendering

    /// A pushed block scope. `isLast` mirrors whether the frame's own opening
    /// row (`iterate.start` / `branch.taken`) was itself the last row at its
    /// enclosing depth — that decides whether the continuation guide drawn
    /// under it should keep a vertical bar (more siblings follow once the
    /// block closes) or go blank (nothing follows).
    private struct Frame {
        let label: String
        let isLast: Bool
    }

    private func renderRun(_ events: [RawEvent], into lines: inout [String], stack: inout [Frame]) {
        guard let first = events.first else { return }
        let header = headerLine(events: events)
        lines.append(header)

        var pending: [RawEvent] = events
        // Drop the workflowStarted event — it's the header line.
        if first.kind == "workflow.started" { pending.removeFirst() }
        guard !pending.isEmpty else { return }

        // Depth per row. `iterate.start`/`iterate.end` and `branch.taken`/
        // `branch.end` are the paired markers that push/pop reliably.
        // End events are computed at the *inner* depth (still nested) so they
        // render as the block's final child, then depth pops for what follows.
        var depths: [Int] = []
        var depth = 0
        for ev in pending {
            depths.append(depth)
            switch ev.kind {
            case "iterate.start", "branch.taken": depth += 1
            case "iterate.end", "branch.end": if depth > 0 { depth -= 1 }
            default: break
            }
        }

        stack.removeAll()
        for (i, ev) in pending.enumerated() {
            let isLastAtLevel = (i == pending.count - 1) || depths[i + 1] < depths[i]
            renderRow(ev, isLast: isLastAtLevel, stack: stack, into: &lines)
            switch ev.kind {
            case "iterate.start", "branch.taken":
                stack.append(Frame(label: labelFor(ev), isLast: isLastAtLevel))
            case "iterate.end", "branch.end":
                if !stack.isEmpty { stack.removeLast() }
            default:
                break
            }
        }
    }

    private func renderRow(_ ev: RawEvent, isLast: Bool, stack: [Frame], into lines: inout [String]) {
        let glyph = isLast ? endGlyph : midGlyph
        let label = labelFor(ev)
        let timing = options.showTimings ? timingSuffix(ev) : ""
        let source = options.showSourceRanges ? sourceSuffix(ev) : ""
        lines.append("  \(ancestorGuide(stack))\(glyph) \(label)\(timing)\(source)")
    }

    /// Two columns of guide per open ancestor frame: a continuation bar when
    /// the ancestor still has siblings coming after its block closes, blank
    /// otherwise.
    private func ancestorGuide(_ stack: [Frame]) -> String {
        let bar = options.unicodeGlyphs ? "│  " : "|  "
        return stack.map { $0.isLast ? "   " : bar }.joined()
    }

    private func labelFor(_ ev: RawEvent) -> String {
        // Paired end markers keep their glyph even when a semantic TraceTag
        // (e.g. `branched` / `iterated`) is attached to the JSONL row.
        switch ev.kind {
        case "branch.end": return "  ↳ end"
        case "iterate.end": return "  ↳ done"
        default: break
        }
        switch ev.semanticTag ?? ev.kind {
        case "invoked":
            let subject = stringValue(ev.payload["subject"]) ?? stringValue(ev.payload["tool"]) ?? "?"
            return "invoked     \(subject)"
        case "completed":
            let subject = stringValue(ev.payload["subject"]) ?? "workflow"
            let outcome = stringValue(ev.payload["outcome"]).map { " (\($0))" } ?? ""
            return "completed   \(subject)\(outcome)"
        case "failed":
            let subject = stringValue(ev.payload["subject"]) ?? "workflow"
            return "failed      \(subject)"
        case "emitted":
            let subject = stringValue(ev.payload["subject"]) ?? stringValue(ev.payload["event"]) ?? ""
            return "emitted     \(subject)"
        case "asserted":
            let subject = stringValue(ev.payload["subject"]) ?? stringValue(ev.payload["message"]) ?? ""
            return "asserted ✓  \(subject)"
        case "assert-failed":
            let subject = stringValue(ev.payload["subject"]) ?? stringValue(ev.payload["message"]) ?? ""
            return "asserted ✗  \(subject)"
        case "branched":
            let subject = stringValue(ev.payload["subject"]) ?? stringValue(ev.payload["condition"]) ?? ""
            return "branched    \(subject)"
        case "iterated":
            if let index = stringValue(ev.payload["index"]) {
                return "iterated    #\(index)"
            }
            let subject = stringValue(ev.payload["subject"]) ?? stringValue(ev.payload["over"]) ?? ""
            return "iterated    \(subject)"
        case "judged":
            let subject = stringValue(ev.payload["subject"]) ?? "judgment"
            let outcome = stringValue(ev.payload["outcome"]).map { " (\($0))" } ?? ""
            return "judged      \(subject)\(outcome)"
        case "committed":
            let subject = stringValue(ev.payload["subject"]) ?? stringValue(ev.payload["label"]) ?? ""
            return "committed   \(subject)"
        case "recovered":
            let subject = stringValue(ev.payload["subject"]) ?? stringValue(ev.payload["pattern"]) ?? ""
            return "recovered   \(subject)"
        case "violated":
            let subject = stringValue(ev.payload["subject"]) ?? ""
            return "violated    \(subject)"
        case "invoke.start":      return "invoke      \(stringValue(ev.payload["tool"]) ?? "?")"
        case "invoke.end":        return "  ↳ ok"
        case "invoke.error":      return "  ↳ error \(stringValue(ev.payload["error_code"]) ?? "")"
        case "branch.taken":
            let into = stringValue(ev.payload["into"]) ?? ""
            let cond = stringValue(ev.payload["condition"]).map { "(\($0))" } ?? ""
            return "branch      \(cond) → \(into)"
        case "iterate.start":     return "iterate     \(stringValue(ev.payload["over"]) ?? "")"
        case "iterate.iteration": return "  · #\(stringValue(ev.payload["index"]) ?? "?")"
        case "assert.passed":     return "assert ✓    \(stringValue(ev.payload["message"]) ?? "")"
        case "assert.failed":     return "assert ✗    \(stringValue(ev.payload["message"]) ?? "")"
        case "wait.start":        return "wait"
        case "wait.resume":       return "  ↳ resumed"
        case "emit":              return "emit        \(stringValue(ev.payload["event"]) ?? "")"
        case "emit.error":        return "emit ✗      \(stringValue(ev.payload["event"]) ?? "")"
        case "commit":            return "commit      \(stringValue(ev.payload["label"]) ?? "")"
        case "recover.engaged":   return "recover     \(stringValue(ev.payload["pattern"]) ?? "")"
        case "workflow.completed":
            let reason = stringValue(ev.payload["reason"]) ?? "ok"
            return "complete    (reason: \(reason))"
        case "workflow.failed":   return "failed      \(stringValue(ev.payload["error"]) ?? "")"
        case "workflow.cancelled": return "cancelled"
        case "workflow.suspended": return "suspended"
        case "workflow.resumed":  return "resumed"
        case "bind":              return "bind        \(stringValue(ev.payload["name"]) ?? "")"
        default:                  return ev.kind
        }
    }

    private func headerLine(events: [RawEvent]) -> String {
        guard let first = events.first else { return "▶ (empty)" }
        let runID = first.runID
        let workflowName: String = {
            if let started = events.first(where: { $0.kind == "workflow.started" }),
               let n = stringValue(started.payload["workflowName"]) {
                return n
            }
            if let semanticName = events.first(where: { $0.semanticTag != nil }).flatMap({ event in
                stringValue(event.payload["workflowName"])
                    ?? stringValue(event.payload["skillName"])
                    ?? stringValue(event.payload["subject"])
            }) {
                return semanticName
            }
            return "?"
        }()
        let total = events.count
        let durationMS = events.reversed()
            .first(where: { $0.kind == "workflow.completed" || $0.semanticTag == "completed" })
            .flatMap { stringValue($0.payload["duration_ms"]) } ?? "—"
        let glyph = options.unicodeGlyphs ? "▶" : "*"
        return "\(glyph) \(workflowName)  (run_id=\(runID) \(total) events \(durationMS)ms)"
    }

    private func timingSuffix(_ ev: RawEvent) -> String {
        guard ev.kind == "invoke.end" || ev.kind == "wait.resume",
              let dms = stringValue(ev.payload["duration_ms"])
        else { return "" }
        return "  → \(dms)ms"
    }

    private func sourceSuffix(_ ev: RawEvent) -> String {
        guard let file = ev.sourceFile, let line = ev.sourceLine else { return "" }
        return "  @\(file):\(line)"
    }

    // MARK: - Glyphs

    private var midGlyph: String { options.unicodeGlyphs ? "├─" : "|-" }
    private var endGlyph: String { options.unicodeGlyphs ? "└─" : "\\-" }

    // MARK: - Parsing helpers

    private func parseJSONL(_ jsonl: String) -> [RawEvent] {
        jsonl
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { line -> RawEvent? in
                guard let data = String(line).data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return nil }
                if let semantic = parseSemanticEnvelope(obj) {
                    return semantic
                }
                let runID  = obj["run_id"]      as? String ?? "?"
                let parent = obj["parent_run_id"] as? String
                let seq    = obj["seq"]         as? Int    ?? 0
                let kind   = obj["kind"]        as? String ?? "?"
                let payload = obj["payload"] as? [String: Any] ?? [:]
                // The JSONLObserver promotes some fields (e.g. "tool") to the
                // top level; merge them back into payload for the renderer.
                var merged = payload
                for promoted in ["tool"] {
                    if let v = obj[promoted], merged[promoted] == nil {
                        merged[promoted] = v
                    }
                }
                let source = obj["source"] as? [String: Any]
                return RawEvent(
                    runID:        runID,
                    parentRunID:  parent,
                    sequence:     seq,
                    kind:         kind,
                    payload:      merged,
                    sourceFile:   source?["file"] as? String,
                    sourceLine:   source?["line"] as? Int,
                    semanticTag:  nil
                )
            }
    }

    private func parseSemanticEnvelope(_ obj: [String: Any]) -> RawEvent? {
        guard let record = obj["record"] as? [String: Any],
              let runID = record["run"] as? String,
              let sequence = intValue(record["ingestOrder"]),
              let tag = record["tag"] as? String
        else { return nil }

        var payload = record["payload"] as? [String: Any] ?? [:]
        for key in ["subject", "skillName", "skillVersionHash", "outcome", "operationalDetail"] {
            if let value = record[key], payload[key] == nil {
                payload[key] = value
            }
        }
        if payload["kind"] == nil, let kind = record["kind"] ?? record["legacyKind"] {
            payload["kind"] = kind
        }
        if payload["workflowName"] == nil, let skillName = record["skillName"] {
            payload["workflowName"] = skillName
        }

        return RawEvent(
            runID: runID,
            parentRunID: nil,
            sequence: sequence,
            kind: tag,
            payload: payload,
            sourceFile: nil,
            sourceLine: nil,
            semanticTag: tag
        )
    }

    private func groupByRun(_ events: [RawEvent]) -> [[RawEvent]] {
        // Stable order: groups appear in the order their first event was seen.
        var order: [String] = []
        var bucket: [String: [RawEvent]] = [:]
        for ev in events {
            if bucket[ev.runID] == nil {
                order.append(ev.runID)
                bucket[ev.runID] = []
            }
            bucket[ev.runID]?.append(ev)
        }
        return order.compactMap { bucket[$0] }
    }

    private func stringValue(_ raw: Any?) -> String? {
        switch raw {
        case let s as String:        return s
        case let n as NSNumber:      return n.stringValue
        case let i as Int:           return String(i)
        case let d as Double:        return String(d)
        case let b as Bool:          return b ? "true" : "false"
        case is NSNull, .none:       return nil
        default:                     return String(describing: raw!)
        }
    }

    private func intValue(_ raw: Any?) -> Int? {
        switch raw {
        case let i as Int:
            return i
        case let n as NSNumber:
            return n.intValue
        case let s as String:
            return Int(s)
        default:
            return nil
        }
    }
}
