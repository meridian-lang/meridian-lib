import Foundation

// MARK: - Code-block sentinel

/// Private-use-area prefix that marks a synthetic SourceLine produced by
/// collapsing a triple-backtick fenced block.  The full sentinel format is:
///   \u{E000}codeblock:<lang>:<base64-body>
/// This character cannot appear in normal Meridian source text, so the
/// sentinel is unambiguous.  The body travels inside `text` — no SourceLine
/// struct changes are needed.
let codeBlockSentinelPrefix = "\u{E000}codeblock:"

// MARK: - Shell command sentinel

/// Private-use-area prefix that marks a `PhraseInvocationAST.words` value as a
/// verbatim shell command (lowered to `invoke shell.run with command = "…"`).
/// The command body is base64-encoded after the prefix so arbitrary shell text
/// — including double quotes and backslashes — survives without any escaping
/// round-trip through the expression parser. Decoded in
/// `ASTToIR.lowerPhraseInvocation`.
let shellCommandSentinelPrefix = "\u{E000}shell:"

/// Language tags (lower-cased fence info strings) treated as literal shell
/// command blocks. A fenced block with one of these tags lowers each command
/// line to a deterministic `shell.run` invoke.
let shellFenceLanguages: Set<String> = ["bash", "sh", "shell", "console", "zsh"]

func encodeShellCommand(_ command: String) -> String {
    shellCommandSentinelPrefix + Data(command.utf8).base64EncodedString()
}

func decodeShellCommand(_ words: String) -> String? {
    guard words.hasPrefix(shellCommandSentinelPrefix) else { return nil }
    let b64 = String(words.dropFirst(shellCommandSentinelPrefix.count))
    guard let data = Data(base64Encoded: b64),
          let str  = String(data: data, encoding: .utf8) else { return nil }
    return str
}

// MARK: - Table sentinel

/// Private-use-area prefix that marks a synthetic SourceLine produced by
/// collapsing a Markdown table block. The full sentinel format is:
///   \u{E000}table:<modeToken>:<base64-body>
/// `<modeToken>` is `TableMode.sentinelToken`; the body is the raw pipe rows
/// (header + delimiter + data rows) joined by newlines. Decoded by `TableParser`.
let tableSentinelPrefix = "\u{E000}table:"

/// Private-use-area prefix that carries a deferred marker error from the
/// (non-throwing) tokenizer to the parser, which raises it as a located
/// `semanticError`. Format: `\u{E000}markererror:<base64-message>`.
let markerErrorSentinelPrefix = "\u{E000}markererror:"

func decodeTableSentinel(_ text: String) -> (mode: TableMode, body: String)? {
    guard text.hasPrefix(tableSentinelPrefix) else { return nil }
    let rest = String(text.dropFirst(tableSentinelPrefix.count))
    guard let colon = rest.firstIndex(of: ":") else { return nil }
    let token = String(rest[rest.startIndex ..< colon])
    let b64 = String(rest[rest.index(after: colon)...])
    guard let data = Data(base64Encoded: b64),
          let body = String(data: data, encoding: .utf8) else { return nil }
    return (TableMode.fromSentinel(token), body)
}

/// Private-use-area prefix that marks a synthetic SourceLine produced by
/// collapsing a `!!! checklist (( … ))`-marked Markdown task list. Format:
///   \u{E000}checklist:<modeToken>:<base64-body>
/// `<modeToken>` is `ChecklistMode.sentinelToken`; the body is the bullet
/// conditions (checkboxes stripped) joined by newlines. Decoded in
/// `StatementParser.checklistStatements`. An *unmarked* task list keeps its
/// per-item `SourceLine.isChecklist` tagging (default = invariant asserts) and
/// is NOT collapsed — only a preceding `!!! checklist` marker triggers a
/// collapse, because the AI-routed modes treat the whole run as one prose step.
let checklistSentinelPrefix = "\u{E000}checklist:"

func decodeChecklistSentinel(_ text: String) -> (mode: ChecklistMode, body: String)? {
    guard text.hasPrefix(checklistSentinelPrefix) else { return nil }
    let rest = String(text.dropFirst(checklistSentinelPrefix.count))
    guard let colon = rest.firstIndex(of: ":") else { return nil }
    let token = String(rest[rest.startIndex ..< colon])
    let b64 = String(rest[rest.index(after: colon)...])
    guard let data = Data(base64Encoded: b64),
          let body = String(data: data, encoding: .utf8) else { return nil }
    return (ChecklistMode.fromSentinel(token), body)
}

func decodeMarkerError(_ text: String) -> String? {
    guard text.hasPrefix(markerErrorSentinelPrefix) else { return nil }
    let b64 = String(text.dropFirst(markerErrorSentinelPrefix.count))
    guard let data = Data(base64Encoded: b64),
          let str = String(data: data, encoding: .utf8) else { return nil }
    return str
}

// MARK: - Block markers (enum-modeled, never raw strings)

/// The kind a general `!!! <kind> (( <attrs> ))` block marker can carry. A
/// `table` marker precedes a Markdown pipe table; a `checklist` marker precedes
/// a `- [ ]` task list. Other kinds are a hard error.
public enum BlockKind: String, Sendable, Equatable {
    case table
    case checklist
}

/// The execution mode of a Markdown table. Decision is the default (no marker
/// or `(( decision table ))`); other modes are opted into via a preceding
/// `!!! table (( … ))` marker. Modeled as an enum (not raw strings) so dispatch
/// is exhaustive — see AGENTS.md "No hardcoded English-surface vocabulary".
///
/// `aiDiscretion` / `aiAutonomy` route a *fuzzy* table (one whose condition
/// cells are intent descriptions rather than checkable comparisons) to the
/// planner instead of inerting it: the rows are rendered as a ruleset and handed
/// to a `ProseStepIR` (`.planThenExecute` / `.autonomousLoop`).
public enum TableMode: Sendable, Equatable {
    case decision
    case data(name: String?)
    case iteration
    case inert
    case aiDiscretion
    case aiAutonomy

    /// Parse a `!!! table (( <payload> ))` payload into a mode. The spelling →
    /// case mapping lives here and nowhere else. Returns nil for an unrecognized
    /// payload (the caller raises a located error listing the valid modes).
    public static func parse(payload raw: String) -> TableMode? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        switch lower {
        case "decision table", "decision": return .decision
        case "iteration table", "iteration": return .iteration
        case "inert": return .inert
        case "data table", "data": return .data(name: nil)
        case "ai-discretion", "ai discretion", "discretion": return .aiDiscretion
        case "ai-autonomy", "ai autonomy", "autonomy": return .aiAutonomy
        default:
            for prefix in ["data table:", "data:"] where lower.hasPrefix(prefix) {
                let name = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return .data(name: name.isEmpty ? nil : name)
            }
            return nil
        }
    }

    /// The stable token embedded in the tokenizer sentinel (round-trips through
    /// `fromSentinel`). Distinct from the human-facing payload spelling.
    public var sentinelToken: String {
        switch self {
        case .decision:        return "decision"
        case .iteration:       return "iteration"
        case .inert:           return "inert"
        case .aiDiscretion:    return "ai-discretion"
        case .aiAutonomy:      return "ai-autonomy"
        case .data(let name):  return name.map { "data=" + $0 } ?? "data"
        }
    }

    /// Reconstruct a mode from its sentinel token. Unknown tokens fall back to
    /// `.decision` (the default), which can never happen for tokenizer output.
    public static func fromSentinel(_ token: String) -> TableMode {
        switch token {
        case "decision":      return .decision
        case "iteration":     return .iteration
        case "inert":         return .inert
        case "ai-discretion": return .aiDiscretion
        case "ai-autonomy":   return .aiAutonomy
        case "data":          return .data(name: nil)
        default:
            if token.hasPrefix("data=") { return .data(name: String(token.dropFirst("data=".count))) }
            return .decision
        }
    }
}

/// The execution mode of a `!!! checklist (( … ))`-marked task list. An unmarked
/// task list defaults to `invariant` (each item is a checkable `assert`) and is
/// never collapsed. The marker exists to route a *fuzzy acceptance* checklist —
/// whose items are not structurally checkable — to the planner (`aiAutonomy`:
/// loop until every criterion holds; `aiDiscretion`: verify/resolve once) or to
/// keep it as documentation (`inert`). Enum-modeled for exhaustive dispatch.
public enum ChecklistMode: Sendable, Equatable {
    case invariant
    case aiDiscretion
    case aiAutonomy
    case inert

    public static func parse(payload raw: String) -> ChecklistMode? {
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "invariant", "invariants": return .invariant
        case "ai-discretion", "ai discretion", "discretion": return .aiDiscretion
        case "ai-autonomy", "ai autonomy", "autonomy": return .aiAutonomy
        case "inert": return .inert
        default: return nil
        }
    }

    public var sentinelToken: String {
        switch self {
        case .invariant:    return "invariant"
        case .aiDiscretion: return "ai-discretion"
        case .aiAutonomy:   return "ai-autonomy"
        case .inert:        return "inert"
        }
    }

    public static func fromSentinel(_ token: String) -> ChecklistMode {
        switch token {
        case "ai-discretion": return .aiDiscretion
        case "ai-autonomy":   return .aiAutonomy
        case "inert":         return .inert
        default:              return .invariant
        }
    }
}

// MARK: - SourceLine

/// A single line from a Meridian source file, with indent metadata.
public struct SourceLine: Sendable {
    public let indent: Int       // number of leading spaces (tabs count as 2)
    public let text: String      // stripped of leading/trailing whitespace + trailing "."
    public let raw: String       // original content
    public let number: Int       // 1-based line number
    public let listMarker: String?
    public let headingLevel: Int?
    /// True when the line was a Markdown task-list item (`- [ ]` / `- [x]`).
    /// The checkbox is stripped from `text`; only the condition remains.
    public let isChecklist: Bool
    /// `true`/`false` when `isChecklist`; nil otherwise.
    public let checklistChecked: Bool?

    public var isEmpty: Bool   { text.isEmpty }
    /// A line is a comment when it is a markdown `#` line (that is not a parsed
    /// `##`/`###` heading) or a markdown blockquote (`>`). Blockquotes carry
    /// SKILL.md asides (`> **Convention:** …`) that are documentation, not
    /// executable statements — treating them as comments lets them sit above the
    /// first heading without tripping the "content before first heading" error.
    public var isComment: Bool { headingLevel == nil && (text.hasPrefix("#") || text.hasPrefix(">")) }
    public var isContent: Bool { !isEmpty && !isComment }

    /// Text with trailing "." stripped (most statements end with ".").
    public var statement: String {
        text.hasSuffix(".") ? String(text.dropLast()) : text
    }

    public init(
        indent: Int,
        text: String,
        raw: String,
        number: Int,
        listMarker: String? = nil,
        headingLevel: Int? = nil,
        isChecklist: Bool = false,
        checklistChecked: Bool? = nil
    ) {
        self.indent = indent
        self.text = text
        self.raw = raw
        self.number = number
        self.listMarker = listMarker
        self.headingLevel = headingLevel
        self.isChecklist = isChecklist
        self.checklistChecked = checklistChecked
    }
}

// MARK: - IndentTokenizer

/// Converts source text into `[SourceLine]` annotated with indent levels.
/// Handles both spaces (1 per indent unit) and tabs (2 per indent unit).
///
/// **B6 — Fenced code blocks**: During tokenization a second pass collapses
/// triple-backtick fences into a single synthetic `SourceLine` whose `text`
/// is a sentinel string: `\u{E000}codeblock:<lang>:<base64-body>`.
/// Downstream parsers (`ExpressionParser.parseAtom`, `StatementParser`) decode
/// the sentinel back into the original text (possibly with `{{ }}` markers for
/// B7 interpolation).  Only stand-alone fence lines (lines whose trimmed text
/// starts with ` ``` `) are collapsed; inline fences that share a line with
/// other tokens are not handled (documented limitation).
public struct IndentTokenizer {

    public init() {}

    public func tokenize(_ source: String, file: String = "") -> [SourceLine] {
        var lines: [SourceLine] = []
        let rawLines = source.components(separatedBy: "\n")

        // A `!!! <kind> (( … ))` marker line sets a pending block that folds into
        // the next collapsible block (a table or a task list). `.line` is the
        // marker's 1-based source line for error reporting.
        var pendingMarker: (block: PendingBlock, line: Int)? = nil

        var i = 0
        while i < rawLines.count {
            let raw = rawLines[i]
            let indent = leadingSpaces(raw)
            let text = raw.drop(while: { $0 == " " || $0 == "\t" })
                          .trimmingCharacters(in: .whitespaces)

            // Resolve a pending `!!!` marker: it must immediately precede a block
            // of the matching kind (blank lines are tolerated in between).
            if let pending = pendingMarker {
                if text.isEmpty {
                    lines.append(SourceLine(indent: indent, text: "", raw: raw, number: i + 1))
                    i += 1
                    continue
                }
                switch pending.block {
                case .table(let mode):
                    if isTableStart(at: i, in: rawLines) {
                        let (sentinel, next) = collapseTable(at: i, in: rawLines, indent: indent, mode: mode)
                        lines.append(sentinel)
                        i = next
                        pendingMarker = nil
                        continue
                    }
                    lines.append(markerErrorLine(
                        "a `!!! table` marker must immediately precede a Markdown table (a header row followed by a `|---|` delimiter row)",
                        line: pending.line))
                case .checklist(let mode):
                    if isChecklistItemLine(raw) {
                        let (sentinel, next) = collapseChecklist(at: i, in: rawLines, indent: indent, mode: mode)
                        lines.append(sentinel)
                        i = next
                        pendingMarker = nil
                        continue
                    }
                    lines.append(markerErrorLine(
                        "a `!!! checklist` marker must immediately precede a task list (one or more `- [ ]` / `- [x]` items)",
                        line: pending.line))
                }
                pendingMarker = nil
                // fall through to process the current line normally
            }

            // A general block marker `!!! <kind> (( <attrs> ))` — consumed (not
            // emitted); it sets the mode for the next block of its kind.
            if text.hasPrefix("!!!") {
                switch parseBangMarker(text) {
                case .table(let mode):
                    pendingMarker = (.table(mode), i + 1)
                case .checklist(let mode):
                    pendingMarker = (.checklist(mode), i + 1)
                case .invalid(let message):
                    lines.append(markerErrorLine(message, line: i + 1))
                }
                i += 1
                continue
            }

            // A markerless Markdown table defaults to a decision table.
            if isTableStart(at: i, in: rawLines) {
                let (sentinel, next) = collapseTable(at: i, in: rawLines, indent: indent, mode: .decision)
                lines.append(sentinel)
                i = next
                continue
            }

            // Detect a stand-alone opening fence: "```" or "```<language>"
            if text.hasPrefix("```") {
                let langTag = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let openingLineNumber = i + 1   // 1-based
                let baseIndent = indent
                var bodyParts: [String] = []
                i += 1
                while i < rawLines.count {
                    let bodyRaw = rawLines[i]
                    let bodyTrimmed = bodyRaw.drop(while: { $0 == " " || $0 == "\t" })
                                             .trimmingCharacters(in: .whitespaces)
                    // Closing fence: bare "```" or "```." (statement terminator).
                    if bodyTrimmed == "```" || bodyTrimmed == "```." { i += 1; break }
                    bodyParts.append(dedent(bodyRaw, by: baseIndent))
                    i += 1
                }
                // Remove a single trailing blank line that originates from a
                // newline before the closing fence (the join would add it anyway).
                if bodyParts.last == "" { bodyParts.removeLast() }
                let body = bodyParts.joined(separator: "\n")
                let b64  = Data(body.utf8).base64EncodedString()
                let lang = langTag.isEmpty ? "plain" : langTag
                let sentinelText = codeBlockSentinelPrefix + lang + ":" + b64
                lines.append(SourceLine(indent: indent, text: sentinelText,
                                        raw: raw, number: openingLineNumber))
                continue
            }

            let marked = stripMarkdownSurface(from: text)
            lines.append(SourceLine(
                indent: indent,
                text: marked.text,
                raw: raw,
                number: i + 1,
                listMarker: marked.listMarker,
                headingLevel: marked.headingLevel,
                isChecklist: marked.isChecklist,
                checklistChecked: marked.checklistChecked
            ))
            i += 1
        }
        if let pending = pendingMarker {
            let kind: String
            switch pending.block {
            case .table:     kind = "table"
            case .checklist: kind = "task list"
            }
            lines.append(markerErrorLine(
                "a `!!! …` marker must immediately precede a \(kind) (none found before end of file)",
                line: pending.line))
        }
        return lines
    }

    private func stripMarkdownSurface(from text: String)
        -> (text: String, listMarker: String?, headingLevel: Int?, isChecklist: Bool, checklistChecked: Bool?) {
        if text.hasPrefix("## ") {
            return (String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces), nil, 2, false, nil)
        }
        if text.hasPrefix("### ") {
            return (String(text.dropFirst(4)).trimmingCharacters(in: .whitespaces), nil, 3, false, nil)
        }
        if text.hasPrefix("- ") || text.hasPrefix("* ") {
            let marker = String(text.prefix(1))
            var rest = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            // Task-list checkbox: `- [ ] …` / `- [x] …` / `- [X] …`.
            if let (checked, condition) = stripChecklistBox(rest) {
                rest = condition
                return (rest, marker, nil, true, checked)
            }
            return (rest, marker, nil, false, nil)
        }
        if let dot = text.firstIndex(of: ".") {
            let number = text[..<dot]
            let afterDot = text.index(after: dot)
            if !number.isEmpty,
               number.allSatisfy(\.isNumber),
               afterDot < text.endIndex,
               text[afterDot].isWhitespace {
                let marker = String(text[...dot])
                let rest = String(text[text.index(after: afterDot)...]).trimmingCharacters(in: .whitespaces)
                return (rest, marker, nil, false, nil)
            }
        }
        return (text, nil, nil, false, nil)
    }

    /// Strip a leading task-list checkbox (`[ ]` / `[x]` / `[X]`) from a bullet
    /// body. Returns `(checked, remainingCondition)` or nil when there is none.
    private func stripChecklistBox(_ s: String) -> (checked: Bool, condition: String)? {
        let lower = s.lowercased()
        guard lower.hasPrefix("[ ]") || lower.hasPrefix("[x]") else { return nil }
        let checked = lower.hasPrefix("[x]")
        let condition = String(s.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return (checked, condition)
    }

    private func leadingSpaces(_ s: String) -> Int {
        var n = 0
        for c in s {
            if c == " "  { n += 1 }
            else if c == "\t" { n += 2 }
            else { break }
        }
        return n
    }

    /// Strip up to `n` leading spaces/tabs from `s` (tabs count as 2 spaces).
    private func dedent(_ s: String, by n: Int) -> String {
        var stripped = 0
        var idx = s.startIndex
        while idx < s.endIndex && stripped < n {
            let c = s[idx]
            if c == " "  { stripped += 1; idx = s.index(after: idx) }
            else if c == "\t" { stripped += 2; idx = s.index(after: idx) }
            else { break }
        }
        return String(s[idx...])
    }

    // MARK: - Table + marker recognition

    private func trimmed(_ raw: String) -> String {
        raw.drop(while: { $0 == " " || $0 == "\t" }).trimmingCharacters(in: .whitespaces)
    }

    /// A table starts when the current line is a pipe row and the next line is a
    /// delimiter row (`|---|:--:|`). Requiring the delimiter avoids mistaking a
    /// prose line that happens to contain a `|` for a table.
    private func isTableStart(at i: Int, in rawLines: [String]) -> Bool {
        let cur = trimmed(rawLines[i])
        guard cur.contains("|"), i + 1 < rawLines.count else { return false }
        return isDelimiterRow(trimmed(rawLines[i + 1]))
    }

    private func isDelimiterRow(_ s: String) -> Bool {
        guard s.contains("-"), s.contains("|") else { return false }
        return s.allSatisfy { $0 == "|" || $0 == "-" || $0 == ":" || $0 == " " }
    }

    /// Collapse a contiguous run of pipe rows (header + delimiter + data) into a
    /// single table sentinel SourceLine. Returns the sentinel and the index of
    /// the first line after the table.
    private func collapseTable(at start: Int, in rawLines: [String], indent: Int, mode: TableMode)
        -> (SourceLine, Int) {
        var bodyParts: [String] = []
        var j = start
        while j < rawLines.count {
            let row = trimmed(rawLines[j])
            if row.isEmpty || !row.contains("|") { break }
            bodyParts.append(row)
            j += 1
        }
        let body = bodyParts.joined(separator: "\n")
        let b64 = Data(body.utf8).base64EncodedString()
        let sentinel = tableSentinelPrefix + mode.sentinelToken + ":" + b64
        return (SourceLine(indent: indent, text: sentinel, raw: rawLines[start], number: start + 1), j)
    }

    /// A pending block marker awaiting its block on a following line.
    private enum PendingBlock {
        case table(TableMode)
        case checklist(ChecklistMode)
    }

    /// The outcome of parsing a `!!!` marker: a resolved table/checklist mode or
    /// a deferred error message (raised later by the parser as a located
    /// diagnostic).
    private enum BangMarker {
        case table(TableMode)
        case checklist(ChecklistMode)
        case invalid(String)
    }

    /// Parse a `!!! <kind> (( <attrs> ))` marker line. Recognizes `table` and
    /// `checklist`. The `(( … ))` payload is optional: bare `!!! table` is a
    /// decision table; bare `!!! checklist` is an invariant task list.
    private func parseBangMarker(_ text: String) -> BangMarker {
        var s = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var payload = ""
        if s.hasSuffix("))"), let open = s.range(of: "((", options: .backwards) {
            payload = String(s[open.upperBound...].dropLast(2)).trimmingCharacters(in: .whitespaces)
            s = String(s[..<open.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        guard let kind = BlockKind(rawValue: s.lowercased()) else {
            return .invalid("`!!! \(s)` is not a recognized block marker; use `!!! table (( … ))` or `!!! checklist (( … ))`.")
        }
        switch kind {
        case .table:
            if payload.isEmpty { return .table(.decision) }
            guard let mode = TableMode.parse(payload: payload) else {
                return .invalid("unknown table mode `\(payload)` in `!!! table (( \(payload) ))`. Use one of: decision table, data table[: name], iteration table, ai-discretion, ai-autonomy, inert.")
            }
            return .table(mode)
        case .checklist:
            if payload.isEmpty { return .checklist(.invariant) }
            guard let mode = ChecklistMode.parse(payload: payload) else {
                return .invalid("unknown checklist mode `\(payload)` in `!!! checklist (( \(payload) ))`. Use one of: invariant, ai-discretion, ai-autonomy, inert.")
            }
            return .checklist(mode)
        }
    }

    /// True when `raw` is a Markdown task-list item (`- [ ]` / `- [x]` / `* [x]`).
    private func isChecklistItemLine(_ raw: String) -> Bool {
        let t = trimmed(raw)
        guard t.hasPrefix("- ") || t.hasPrefix("* ") else { return false }
        let body = String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces).lowercased()
        return body.hasPrefix("[ ]") || body.hasPrefix("[x]")
    }

    /// Collapse a contiguous run of task-list items into one checklist sentinel
    /// SourceLine carrying the mode and the bullet conditions (checkboxes
    /// stripped). Stops at the first non-checklist (or blank) line. Returns the
    /// sentinel and the index of the first line after the run.
    private func collapseChecklist(at start: Int, in rawLines: [String], indent: Int, mode: ChecklistMode)
        -> (SourceLine, Int) {
        var conditions: [String] = []
        var j = start
        while j < rawLines.count, isChecklistItemLine(rawLines[j]) {
            let t = trimmed(rawLines[j])
            var body = String(t.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            // Strip the `[ ]` / `[x]` box (3 chars) plus following space.
            body = String(body.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if body.hasSuffix(".") { body.removeLast() }
            conditions.append(body)
            j += 1
        }
        let body = conditions.joined(separator: "\n")
        let b64 = Data(body.utf8).base64EncodedString()
        let sentinel = checklistSentinelPrefix + mode.sentinelToken + ":" + b64
        return (SourceLine(indent: indent, text: sentinel, raw: rawLines[start], number: start + 1), j)
    }

    private func markerErrorLine(_ message: String, line: Int) -> SourceLine {
        let b64 = Data(message.utf8).base64EncodedString()
        return SourceLine(indent: 0, text: markerErrorSentinelPrefix + b64, raw: "", number: line)
    }
}

// MARK: - Block extraction helpers

extension Array where Element == SourceLine {

    /// Content (non-empty, non-comment) lines only.
    var contentLines: [SourceLine] { filter(\.isContent) }

    /// Extract the indented body following `headerLine` — all lines with
    /// strictly greater indent than `headerLine.indent`.
    /// Stops at the first line whose indent is ≤ `headerLine.indent` (exclusive).
    func indentedBlock(after headerIndex: Int) -> (lines: [SourceLine], nextIndex: Int) {
        guard headerIndex < count else { return ([], headerIndex) }
        let parentIndent = self[headerIndex].indent
        var i = headerIndex + 1
        var block: [SourceLine] = []
        while i < count {
            let line = self[i]
            if line.isEmpty || line.isComment {
                i += 1
                continue
            }
            if line.indent <= parentIndent { break }
            block.append(line)
            i += 1
        }
        return (block, i)
    }

    /// Parse a continuation block: lines immediately after `startIndex` that
    /// have strictly greater indent. Used for multi-line invoke args / emit payload.
    func continuationLines(from startIndex: Int, parentIndent: Int) -> [SourceLine] {
        var result: [SourceLine] = []
        var i = startIndex
        while i < count {
            let line = self[i]
            if line.isEmpty || line.isComment { i += 1; continue }
            if line.indent <= parentIndent { break }
            result.append(line)
            i += 1
        }
        return result
    }
}
