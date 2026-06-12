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
    public static func capturing(categories: [Category] = Category.allCases)
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
