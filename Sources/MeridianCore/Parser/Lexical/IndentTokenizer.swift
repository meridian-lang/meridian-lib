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

// MARK: - SourceLine

/// A single line from a Meridian source file, with indent metadata.
public struct SourceLine: Sendable {
    public let indent: Int       // number of leading spaces (tabs count as 2)
    public let text: String      // stripped of leading/trailing whitespace + trailing "."
    public let raw: String       // original content
    public let number: Int       // 1-based line number
    public let listMarker: String?
    public let headingLevel: Int?

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
        headingLevel: Int? = nil
    ) {
        self.indent = indent
        self.text = text
        self.raw = raw
        self.number = number
        self.listMarker = listMarker
        self.headingLevel = headingLevel
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

        var i = 0
        while i < rawLines.count {
            let raw = rawLines[i]
            let indent = leadingSpaces(raw)
            let text = raw.drop(while: { $0 == " " || $0 == "\t" })
                          .trimmingCharacters(in: .whitespaces)

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
                headingLevel: marked.headingLevel
            ))
            i += 1
        }
        return lines
    }

    private func stripMarkdownSurface(from text: String) -> (text: String, listMarker: String?, headingLevel: Int?) {
        if text.hasPrefix("## ") {
            return (String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces), nil, 2)
        }
        if text.hasPrefix("### ") {
            return (String(text.dropFirst(4)).trimmingCharacters(in: .whitespaces), nil, 3)
        }
        if text.hasPrefix("- ") || text.hasPrefix("* ") {
            let marker = String(text.prefix(1))
            let rest = String(text.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            return (rest, marker, nil)
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
                return (rest, marker, nil)
            }
        }
        return (text, nil, nil)
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
