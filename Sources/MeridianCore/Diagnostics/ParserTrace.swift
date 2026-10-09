import Foundation
import MeridianRuntime

// MARK: - ParserTrace
//
// Lightweight, opt-in diagnostic logger for the Meridian compiler frontend.
//
// All hot-path call sites are guarded by `ParserTrace.shared.isEnabled(.x)` so
// the cost when tracing is off is a single atomic load.
//
// Categories let callers turn on just the part of the pipeline they care about
// (e.g. `phrase.match` when debugging argument extraction). Categories are
// hierarchical: enabling `phrase` enables `phrase.parse`, `phrase.match`, etc.
//
// Activation:
//
//   • Programmatic:   `ParserTrace.shared.enable([.phraseMatch, .lowering])`
//   • Environment:    `MERIDIAN_TRACE=phrase,lowering` (commas / spaces)
//                     `MERIDIAN_TRACE=all` (everything)
//   • CLI:            `meridian compile --trace phrase,lowering ...`
//
// Output destination defaults to stderr. Override with
// `ParserTrace.shared.sink = .file(URL(fileURLWithPath: "trace.log"))` or
// `.custom { line in ... }` for programmatic capture (tests, golden files).
//
// Threading: the active trace is a task-local (`ParserTrace.current`). Hosts
// inject one via `Compiler.Options.trace` (the compile entry points install it
// for the duration of the compile) or `trace.run { ... }` around a direct API
// call; no component takes a `trace:` parameter.

public enum SpanOutcome: String, Sendable {
    case success
    case failure
    case cancellation
    case rejection
}

public struct SpanID: Hashable, Sendable {
    public let value: UInt64
}

public final class ParserTrace: @unchecked Sendable {

    public static let shared = ParserTrace()

    /// The trace every compiler component reads. Defaults to the process-wide
    /// `shared` instance; hosts inject a different one by setting
    /// `Compiler.Options.trace` (the compile entry points install it for the
    /// duration of the compile) or by wrapping a direct API call in `run(_:)`.
    /// `TaskLocal` values are inherited by child tasks, so `await`ed work
    /// inside a compile sees the same trace.
    @TaskLocal public static var current: ParserTrace = .shared

    /// Run `body` with this trace installed as the task-local current trace.
    /// The direct-API injection point for hosts and tests (compile scopes get
    /// it for free through `Compiler.Options.trace`).
    public func run<T>(_ body: () throws -> T) rethrows -> T {
        try Self.$current.withValue(self, operation: body)
    }

    /// Async variant of `run(_:)`, for async command bodies and tests.
    public func run<T>(_ body: () async throws -> T) async rethrows -> T {
        try await Self.$current.withValue(self, operation: body)
    }

    public enum OutputFormat: Sendable {
        case text
        case jsonl
    }

    public enum Category: String, CaseIterable, Sendable {
        case tokenize           = "tokenize"
        case phraseParse        = "phrase.parse"
        case phraseMatch        = "phrase.match"
        case phraseExtractArgs  = "phrase.args"
        case phraseInline       = "phrase.inline"
        case statement          = "statement"
        case expression         = "expression"
        case lowering           = "lowering"
        case symbols            = "symbols"
        case merconfig          = "merconfig"
        case parse              = "parse"
        case rulebook           = "rulebook"
        case skill              = "skill"
        case codegen            = "codegen"
        case verbalizer         = "verbalizer"
        case validation         = "validation"
        case drift              = "drift"
        case diagnostics        = "diagnostics"
        case timing             = "timing"

        /// Human-readable description for `meridian trace categories`.
        public var summary: String {
            switch self {
            case .tokenize:          return "Lexing: fence collapse, comment/indent/heading decisions."
            case .phraseParse:       return "Phrase-pattern parsing."
            case .phraseMatch:       return "Phrase matching + scoring against the symbol table."
            case .phraseExtractArgs: return "Argument extraction for a matched phrase."
            case .phraseInline:      return "Phrase inlining (recursive expansion)."
            case .statement:         return "Per-statement parser dispatch."
            case .expression:        return "Expression parsing."
            case .lowering:          return "AST → IR lowering."
            case .symbols:           return "Symbol-table construction (kinds/properties/phrases/tools/…)."
            case .merconfig:         return "Vocabulary (.merconfig) parsing."
            case .parse:             return "Meridian (.meridian/.meri) file parsing."
            case .rulebook:          return "Rulebook (.merrules) parsing + rewrite."
            case .skill:             return "Skill/section role classification + scoped tools."
            case .codegen:           return "Swift/manifest/domain emission."
            case .verbalizer:        return "Canonical English verbalization (IR → source)."
            case .validation:        return "IR structural validation before emission."
            case .drift:             return "Authored-vs-canonical drift hunk classification."
            case .diagnostics:       return "Every emitted diagnostic (errors/warnings/notes)."
            case .timing:            return "Per-phase wall-clock timing + end-of-compile profile (off by default)."
            }
        }

        /// Group prefixes — enabling `phrase` enables every `phrase.*` category.
        public var groups: [String] {
            let parts = self.rawValue.split(separator: ".")
            var result: [String] = [self.rawValue]
            if parts.count > 1 { result.append(String(parts[0])) }
            return result
        }
    }

    public enum Sink {
        case stderr
        case stdout
        case file(URL)
        case custom(@Sendable (String) -> Void)
    }

    public struct Token: Sendable {
        public let spanID: SpanID
        public let parentSpanID: SpanID?
        public let active: Bool
        public let cat: Category
        public let sequence: UInt64?

        static func inactive(_ cat: Category) -> Token {
            Token(spanID: SpanID(value: 0), parentSpanID: nil, active: false, cat: cat, sequence: nil)
        }
    }

    private enum RecordKind: String {
        case open
        case event
        case close
    }

    private final class ThreadSpanState {
        var indentLevel = 0
        var spanStack: [SpanID] = []
    }

    private let lock = NSLock()
    private var _enabled: Set<String> = []
    private var _sink: Sink = .stderr
    private var _outputFormat: OutputFormat = .text
    /// Per-thread span stacks and indent (keyed by `ObjectIdentifier(Thread.current)`).
    private var _threadSpanStates: [ObjectIdentifier: ThreadSpanState] = [:]
    /// Accumulated per-phase wall-clock durations (seconds), in first-seen order.
    private var _phaseOrder: [String] = []
    private var _phaseDurations: [String: Double] = [:]
    private var _diagnosticCount = 0
    private var _nextSpanID: UInt64 = 1
    private var _sequence: UInt64 = 0

    public let correlationID: String

    public var sink: Sink {
        get { lock.lock(); defer { lock.unlock() }; return _sink }
        set { lock.lock(); defer { lock.unlock() }; _sink = newValue }
    }

    public var outputFormat: OutputFormat {
        get { lock.lock(); defer { lock.unlock() }; return _outputFormat }
        set { lock.lock(); defer { lock.unlock() }; _outputFormat = newValue }
    }

    public init() {
        correlationID = UUID().uuidString
        if let env = ProcessInfo.processInfo.environment["MERIDIAN_TRACE"], !env.isEmpty {
            enable(parsing: env)
        }
    }

    // MARK: Activation

    public func enable(parsing spec: String) {
        let parts = spec.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ", "))
            .filter { !$0.isEmpty }
        if parts.contains("all") {
            enable(Category.allCases)
            return
        }
        var names: Set<String> = []
        for p in parts { names.insert(p) }
        lock.lock()
        _enabled.formUnion(names)
        lock.unlock()
    }

    /// Tokens accepted by `enable(parsing:)` / `--trace` (leaf categories + group
    /// prefixes + `all`). Used for MER2010 validation in the CLI.
    public static func knownTraceTokens() -> Set<String> {
        var tokens: Set<String> = ["all"]
        for cat in Category.allCases {
            for g in cat.groups { tokens.insert(g) }
        }
        return tokens
    }

    /// Return MER2010 diagnostics for unknown tokens in a trace spec (empty when valid).
    public static func validateTraceSpec(_ spec: String) -> [Diagnostic] {
        let parts = spec.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ", "))
            .filter { !$0.isEmpty }
        if parts.contains("all") { return [] }
        let known = knownTraceTokens()
        return parts.compactMap { token -> Diagnostic? in
            guard !known.contains(token) else { return nil }
            return Diagnostic.unresolved(
                .unknownTraceCategory,
                target: token,
                among: known.sorted(),
                range: SourceRange(file: "<trace>", line: 1, column: 1),
                noun: "trace category",
                help: "Run `meridian trace categories` to list valid tokens.")
        }
    }

    public func enable(_ cats: [Category]) {
        lock.lock()
        // Only insert the leaf category. `isEnabled` walks group prefixes when
        // reading, so adding parent groups here would over-enable siblings
        // (e.g. enabling .phraseParse would also enable .phraseMatch via the
        // shared "phrase" prefix).
        for c in cats { _enabled.insert(c.rawValue) }
        lock.unlock()
    }

    public func disableAll() {
        lock.lock(); _enabled.removeAll(); lock.unlock()
    }

    public func isEnabled(_ cat: Category) -> Bool {
        lock.lock(); defer { lock.unlock() }
        for g in cat.groups where _enabled.contains(g) { return true }
        return false
    }

    // MARK: Spans

    /// Open a correlated span. Zero-cost when the category is disabled.
    @discardableResult
    public func openSpan(
        _ cat: Category,
        _ operation: @autoclosure () -> String,
        range: SourceRange? = nil
    ) -> Token {
        guard isEnabled(cat) else { return .inactive(cat) }
        let op = operation()
        let spanID = allocateSpanID()
        let (parentSpanID, seq) = beginThreadSpan(spanID)
        let msg = "▶ \(op)"
        emitRecord(
            cat: cat,
            kind: .open,
            span: spanID,
            parent: parentSpanID,
            op: op,
            outcome: nil,
            msg: msg,
            range: range,
            sequence: seq)
        return Token(spanID: spanID, parentSpanID: parentSpanID, active: true, cat: cat, sequence: seq)
    }

    public func closeSpan(
        _ token: Token,
        outcome: SpanOutcome = .success,
        result: @autoclosure () -> String = ""
    ) {
        guard token.active else { return }
        let r = result()
        endThreadSpan(expected: token.spanID)
        let msg = r.isEmpty ? "" : "◀ \(r)"
        let seq = nextSequence()
        if !msg.isEmpty || outputFormat == .jsonl {
            emitRecord(
                cat: token.cat,
                kind: .close,
                span: token.spanID,
                parent: token.parentSpanID,
                op: nil,
                outcome: outcome,
                msg: msg,
                range: nil,
                sequence: seq)
        }
    }

    // MARK: Logging

    /// Log a single trace line. Cheap when category is disabled.
    public func log(_ cat: Category, _ message: @autoclosure () -> String) {
        guard isEnabled(cat) else { return }
        let msg = message()
        let (span, parent) = currentThreadSpanContext()
        emitRecord(
            cat: cat,
            kind: .event,
            span: span,
            parent: parent,
            op: nil,
            outcome: nil,
            msg: msg,
            range: nil,
            sequence: nextSequence())
    }

    /// Log a labelled key/value pair, indented under the current scope.
    public func detail(_ cat: Category, _ key: String, _ value: @autoclosure () -> String) {
        guard isEnabled(cat) else { return }
        let msg = "  \(key): \(value())"
        let (span, parent) = currentThreadSpanContext()
        emitRecord(
            cat: cat,
            kind: .event,
            span: span,
            parent: parent,
            op: nil,
            outcome: nil,
            msg: msg,
            range: nil,
            sequence: nextSequence())
    }

    /// Open a logical scope; returned token must be passed to `pop`.
    @discardableResult
    public func push(_ cat: Category, _ label: @autoclosure () -> String) -> Token {
        openSpan(cat, label())
    }

    public func pop(_ token: Token, _ result: @autoclosure () -> String = "") {
        closeSpan(token, outcome: .success, result: result())
    }

    // MARK: Timing

    /// Run `body` as a named compile phase, recording its wall-clock duration
    /// into the profile. The timing line is emitted under `.timing` (off by
    /// default, so deterministic trace tests are unaffected); the duration is
    /// always accumulated so `profileSummary()` can report even when `.timing`
    /// output is disabled.
    @discardableResult
    public func phase<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
        let start = DispatchTime.now()
        defer { accumulate(name, since: start) }
        return try body()
    }

    /// Async variant of `phase(_:_:)`.
    @discardableResult
    public func phase<T>(_ name: String, _ body: () async throws -> T) async rethrows -> T {
        let start = DispatchTime.now()
        defer { accumulate(name, since: start) }
        return try await body()
    }

    private func accumulate(_ name: String, since start: DispatchTime) {
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds) / 1_000_000_000
        lock.lock()
        if _phaseDurations[name] == nil { _phaseOrder.append(name) }
        _phaseDurations[name, default: 0] += elapsed
        lock.unlock()
        log(.timing, "\(name): \(String(format: "%.2f", elapsed * 1000)) ms")
    }

    /// Emit the accumulated per-phase timing profile under `.timing`. Call once
    /// at the end of a compile. No-op when `.timing` is disabled or no phases ran.
    public func profileSummary() {
        guard isEnabled(.timing) else { return }
        lock.lock()
        let order = _phaseOrder
        let durations = _phaseDurations
        let diags = _diagnosticCount
        lock.unlock()
        guard !order.isEmpty else { return }
        let total = durations.values.reduce(0, +)
        emitPlainText(.timing, "── compile profile ──")
        for name in order {
            let ms = (durations[name] ?? 0) * 1000
            let pct = total > 0 ? (durations[name] ?? 0) / total * 100 : 0
            emitPlainText(.timing, String(format: "  %-22@ %8.2f ms  (%4.1f%%)", name as NSString, ms, pct))
        }
        emitPlainText(.timing, String(format: "  %-22@ %8.2f ms", "total" as NSString, total * 1000))
        emitPlainText(.timing, "  diagnostics emitted: \(diags)")
    }

    /// Reset accumulated timing state. Used between independent compiles that
    /// share a trace instance (rare; mostly a test convenience).
    public func resetProfile() {
        lock.lock(); _phaseOrder.removeAll(); _phaseDurations.removeAll(); _diagnosticCount = 0; lock.unlock()
    }

    /// Mirror an emitted diagnostic into the `.diagnostics` stream and bump the
    /// profile counter. Called by `DiagnosticEngine` whenever it records one.
    public func recordDiagnostic(_ summary: @autoclosure () -> String) {
        lock.lock(); _diagnosticCount += 1; lock.unlock()
        log(.diagnostics, summary())
    }

    // MARK: Thread-local span state

    private func withThreadSpanState<R>(_ body: (ThreadSpanState) -> R) -> R {
        let key = ObjectIdentifier(Thread.current)
        lock.lock()
        defer { lock.unlock() }
        if _threadSpanStates[key] == nil {
            _threadSpanStates[key] = ThreadSpanState()
        }
        return body(_threadSpanStates[key]!)
    }

    private func allocateSpanID() -> SpanID {
        lock.lock()
        defer { lock.unlock() }
        let id = _nextSpanID
        _nextSpanID += 1
        return SpanID(value: id)
    }

    private func nextSequence() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        _sequence += 1
        return _sequence
    }

    @discardableResult
    private func beginThreadSpan(_ spanID: SpanID) -> (parent: SpanID?, sequence: UInt64) {
        let seq = nextSequence()
        return withThreadSpanState { state in
            let parent = state.spanStack.last
            state.spanStack.append(spanID)
            state.indentLevel += 1
            return (parent, seq)
        }
    }

    private func endThreadSpan(expected: SpanID) {
        withThreadSpanState { state in
            state.indentLevel = max(0, state.indentLevel - 1)
            if let top = state.spanStack.last {
                state.spanStack.removeLast()
                if top.value != expected.value {
                    // Mismatched close — still unwind indent to avoid corrupting output.
                }
            }
        }
    }

    private func currentThreadSpanContext() -> (span: SpanID?, parent: SpanID?) {
        withThreadSpanState { state in
            let stack = state.spanStack
            guard let span = stack.last else { return (nil, nil) }
            let parent = stack.count > 1 ? stack[stack.count - 2] : nil
            return (span, parent)
        }
    }

    private func currentIndent() -> Int {
        withThreadSpanState { max(0, $0.indentLevel) }
    }

    // MARK: Emit

    private func emitRecord(
        cat: Category,
        kind: RecordKind,
        span: SpanID?,
        parent: SpanID?,
        op: String?,
        outcome: SpanOutcome?,
        msg: String,
        range: SourceRange?,
        sequence: UInt64
    ) {
        let format: OutputFormat
        let sink: Sink
        let corr: String
        lock.lock()
        format = _outputFormat
        sink = _sink
        corr = correlationID
        lock.unlock()

        let line: String
        switch format {
        case .text:
            let indent = kind == .open ? max(0, currentIndent() - 1) : currentIndent()
            let pad = String(repeating: "  ", count: indent)
            let body = msg.isEmpty && kind == .close ? "" : msg
            guard !body.isEmpty else { return }
            line = "[\(cat.rawValue)] \(pad)\(Self.redactSecrets(body))\n"
        case .jsonl:
            line = Self.encodeJSONL(
                seq: sequence,
                corr: corr,
                span: span,
                parent: parent,
                cat: cat,
                op: op,
                kind: kind,
                outcome: outcome,
                msg: msg,
                range: range)
        }

        writeLine(line, sink: sink)
    }

    private func emitPlainText(_ cat: Category, _ raw: String) {
        let sink: Sink
        lock.lock()
        sink = _sink
        lock.unlock()
        let pad = String(repeating: "  ", count: currentIndent())
        let line = "[\(cat.rawValue)] \(pad)\(Self.redactSecrets(raw))\n"
        writeLine(line, sink: sink)
    }

    private func writeLine(_ line: String, sink: Sink) {
        switch sink {
        case .stderr:
            FileHandle.standardError.write(Data(line.utf8))
        case .stdout:
            FileHandle.standardOutput.write(Data(line.utf8))
        case .file(let url):
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    let h = try FileHandle(forWritingTo: url)
                    try h.seekToEnd()
                    try h.write(contentsOf: Data(line.utf8))
                    try h.close()
                } else if let data = line.data(using: .utf8) {
                    try data.write(to: url, options: .atomic)
                } else {
                    throw CocoaError(.fileWriteUnknown)
                }
            } catch {
                // Mid-stream sink failure: fall back to stderr once visibly.
                let notice = "[diagnostics] warning MER5011 @trace-file: cannot write trace file \(url.path); falling back to stderr\n"
                FileHandle.standardError.write(Data(notice.utf8))
                FileHandle.standardError.write(Data(line.utf8))
                lock.lock(); _sink = .stderr; lock.unlock()
            }
        case .custom(let fn):
            fn(line)
        }
    }

    private static func encodeJSONL(
        seq: UInt64,
        corr: String,
        span: SpanID?,
        parent: SpanID?,
        cat: Category,
        op: String?,
        kind: RecordKind,
        outcome: SpanOutcome?,
        msg: String,
        range: SourceRange?
    ) -> String {
        var object: [String: Any] = [
            "seq": seq,
            "corr": corr,
            "cat": cat.rawValue,
            "kind": kind.rawValue,
            "msg": redactSecrets(msg),
        ]
        if let span { object["span"] = span.value }
        if let parent { object["parent"] = parent.value }
        if let op { object["op"] = redactSecrets(op) }
        if let outcome { object["outcome"] = outcome.rawValue }
        if let range {
            object["range"] = [
                "file": range.file,
                "startLine": range.startLine,
                "startColumn": range.startColumn,
                "endLine": range.endLine,
                "endColumn": range.endColumn,
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let json = String(data: data, encoding: .utf8)
        else {
            return "{\"seq\":\(seq),\"corr\":\"\(corr)\",\"kind\":\"\(kind.rawValue)\",\"msg\":\"\"}\n"
        }
        return json + "\n"
    }

    private static let redactionRegexes: [(NSRegularExpression, String)] = {
        let specs: [(String, String)] = [
            (#"(?i)\b(Authorization\s*:\s*Bearer\s+)[^\s,;]+"#, "$1<redacted>"),
            (#"(?i)\b(Authorization\s*:\s*)(?!Bearer\s)[^\s,;]+"#, "$1<redacted>"),
            (#"(?i)\b(Bearer\s+)[A-Za-z0-9._~+/=-]+"#, "$1<redacted>"),
            (#"(?i)\b((?:password|api[_-]?key|apiKey|secret|[A-Za-z0-9_-]*secret)\s*[=:]\s*)[^\s,;]+"#, "$1<redacted>"),
        ]
        return specs.map { (try! NSRegularExpression(pattern: $0.0), $0.1) }
    }()

    private static func redactSecrets(_ raw: String) -> String {
        var text = raw
        for (regex, template) in redactionRegexes {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
        }
        return text
    }
}

// MARK: - Convenience

extension ParserTrace {
    /// Render a value for a trace line, eliding long strings.
    public static func short(_ s: String, max: Int = 80) -> String {
        if s.count <= max { return s }
        let head = s.prefix(max - 3)
        return "\(head)..."
    }

    /// Build a fresh, isolated trace whose output is captured into an array.
    /// Useful for tests and for callers that want to inspect parser steps
    /// without polluting stderr.
    ///
    ///     let cap = ParserTrace.capturing(categories: [.phraseMatch])
    ///     _ = try Compiler(options: .init(trace: cap.trace)).compile(...)
    ///     for line in cap.lines() { print(line) }
    public static func capturing(categories: [Category] = Category.allCases.filter { $0 != .timing })
        -> (trace: ParserTrace, lines: @Sendable () -> [String])
    {
        let trace = ParserTrace()
        let buffer = LineBuffer()
        trace.sink = .custom { line in buffer.append(line) }
        trace.enable(categories)
        return (trace, { buffer.snapshot() })
    }

    /// Disable every category; useful in tests that want a quiet baseline.
    public static func silent() -> ParserTrace {
        let t = ParserTrace()
        t.disableAll()
        t.sink = .custom { _ in }
        return t
    }

    private final class LineBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var lines: [String] = []
        func append(_ s: String) {
            lock.lock(); defer { lock.unlock() }
            lines.append(s.hasSuffix("\n") ? String(s.dropLast()) : s)
        }
        func snapshot() -> [String] {
            lock.lock(); defer { lock.unlock() }
            return lines
        }
    }
}
