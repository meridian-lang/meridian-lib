import Foundation

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

public final class ParserTrace: @unchecked Sendable {

    public static let shared = ParserTrace()

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
        case rulebook           = "rulebook"
        case skill              = "skill"
        case codegen            = "codegen"
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
            case .rulebook:          return "Rulebook (.merrules) parsing + rewrite."
            case .skill:             return "Skill/section role classification + scoped tools."
            case .codegen:           return "Swift/manifest/domain emission."
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

    private let lock = NSLock()
    private var _enabled: Set<String> = []
    private var _sink: Sink = .stderr
    private var indentLevel = 0
    /// Accumulated per-phase wall-clock durations (seconds), in first-seen order.
    private var _phaseOrder: [String] = []
    private var _phaseDurations: [String: Double] = [:]
    private var _diagnosticCount = 0

    public var sink: Sink {
        get { lock.lock(); defer { lock.unlock() }; return _sink }
        set { lock.lock(); defer { lock.unlock() }; _sink = newValue }
    }

    public init() {
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

    // MARK: Logging

    /// Log a single trace line. Cheap when category is disabled.
    public func log(_ cat: Category, _ message: @autoclosure () -> String) {
        guard isEnabled(cat) else { return }
        emit(cat, message())
    }

    /// Log a labelled key/value pair, indented under the current scope.
    public func detail(_ cat: Category, _ key: String, _ value: @autoclosure () -> String) {
        guard isEnabled(cat) else { return }
        emit(cat, "  \(key): \(value())")
    }

    /// Open a logical scope; returned token must be passed to `pop`.
    @discardableResult
    public func push(_ cat: Category, _ label: @autoclosure () -> String) -> Token {
        guard isEnabled(cat) else { return Token(active: false, cat: cat) }
        emit(cat, "▶ \(label())")
        lock.lock(); indentLevel += 1; lock.unlock()
        return Token(active: true, cat: cat)
    }

    public func pop(_ token: Token, _ result: @autoclosure () -> String = "") {
        guard token.active else { return }
        lock.lock(); indentLevel = max(0, indentLevel - 1); lock.unlock()
        let r = result()
        if !r.isEmpty { emit(token.cat, "◀ \(r)") }
    }

    public struct Token {
        let active: Bool
        let cat: Category
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
        emit(.timing, "── compile profile ──")
        for name in order {
            let ms = (durations[name] ?? 0) * 1000
            let pct = total > 0 ? (durations[name] ?? 0) / total * 100 : 0
            emit(.timing, String(format: "  %-22@ %8.2f ms  (%4.1f%%)", name as NSString, ms, pct))
        }
        emit(.timing, String(format: "  %-22@ %8.2f ms", "total" as NSString, total * 1000))
        emit(.timing, "  diagnostics emitted: \(diags)")
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

    // MARK: Emit

    private func emit(_ cat: Category, _ raw: String) {
        lock.lock()
        let pad = String(repeating: "  ", count: indentLevel)
        let line = "[\(cat.rawValue)] \(pad)\(raw)\n"
        let s = _sink
        lock.unlock()

        switch s {
        case .stderr:
            FileHandle.standardError.write(Data(line.utf8))
        case .stdout:
            FileHandle.standardOutput.write(Data(line.utf8))
        case .file(let url):
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile()
                h.write(Data(line.utf8))
                try? h.close()
            } else {
                try? line.data(using: .utf8)?.write(to: url, options: .atomic)
            }
        case .custom(let fn):
            fn(line)
        }
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
