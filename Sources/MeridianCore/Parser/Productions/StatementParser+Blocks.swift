import Foundation
import MeridianRuntime

// MARK: - Shell fences, data tables, backtick commands
//
// Code-block sentinel dispatch (shell fences, tool fences, data tables),
// backtick command embedding, and Markdown list-marker stripping —
// extracted from StatementParser for Phase 3 readability.

extension StatementParser {

    func parseInlineChain(_ line: SourceLine, sourceFile: String) throws -> [StatementAST]? {
        let statement = line.statement

        // Command surface: a fenced ```bash/```sh/```shell block (collapsed by
        // the tokenizer into a code-block sentinel) lowers each command line to
        // a deterministic `shell.run` invoke. One invoke per command line;
        // backslash line-continuations are joined. Never calls an LLM.
        if let shellStatements = shellBlockStatements(line) {
            return shellStatements
        }

        // Non-shell fence with a configured `=== language ===` `Fence tool
        // mapping:` entry (e.g. ```python → interpreter.run) lowers to a
        // single plain `invoke` of that tool — the general-abilities
        // extension for non-shell skill repos.
        if let toolStatements = toolFenceStatements(line) {
            return toolStatements
        }

        // Inline backticked literal command on its own line, e.g. `gbrain publish`.
        if let inlineShell = inlineBacktickedCommand(line) {
            return [inlineShell]
        }

        // Operational Markdown often writes a labelled step around a single
        // command span: `Verify: `gbrain doctor --json`` or
        // `**Sync** - `gbrain sync``. Treat that as the same deterministic
        // shell command, carrying the surrounding prose as the source annotation.
        if let embeddedShell = embeddedBacktickedCommand(line) {
            return [embeddedShell]
        }

        // A collapsed Markdown table sentinel expands to per-row statements
        // (decision branches, a data-table binding, or nothing for inert).
        if let tableStatements = try tableStatements(line, sourceFile: sourceFile) {
            return tableStatements
        }

        guard statement.lowercased().hasPrefix(lexicon.grammar.statement.doPrefix) else { return nil }
        let rest = String(statement.dropFirst(lexicon.grammar.statement.doPrefix.count)).trimmingCharacters(in: .whitespaces)
        let chunks = splitStatementChain(rest)
        guard chunks.count > 1 else { return nil }
        var result: [StatementAST] = []
        for chunk in chunks {
            let synthetic = SourceLine(indent: line.indent, text: chunk, raw: line.raw, number: line.number)
            guard let stmt = try parseStatement([synthetic], at: 0, sourceFile: sourceFile).0 else {
                try raiseStructural(
                    .unparseableStatement,
                    message: "`do … and …` chain includes an unparseable chunk: \"\(chunk)\"",
                    range: SourceRange(file: sourceFile, line: line.number, column: 1),
                    help: "Every chunk of a `do A and B [and C …]` chain must be a valid statement on its own.")
            }
            result.append(stmt)
        }
        return result
    }


    /// Expand a fenced shell code block into one `shell.run` invoke per command
    /// line. Returns `nil` when the line is not a shell-tagged code-block
    /// sentinel (so other code-block languages flow through unchanged).
    func shellBlockStatements(_ line: SourceLine) -> [StatementAST]? {
        guard let (lang, body) = decodeCodeBlockSentinel(line.text) else { return nil }
        guard lexicon.isShellFence(lang) else { return nil }

        let commands = splitShellCommands(body)
        return commands.map { cmd in
            .phraseInvocation(PhraseInvocationAST(
                words: encodeShellCommand(cmd),
                sourceLine: line.number
            ))
        }
    }

    /// Expand a fenced code block whose language matches a configured
    /// `=== language ===` `Fence tool mapping:` entry into a single plain
    /// `invoke <tool> with code = "…"` — the whole fence body as one literal
    /// string argument, deliberately without the shell command's `{…}`
    /// command-hole interpolation (that richness is `shell.run`-specific; see
    /// `toolFenceSentinelPrefix`'s doc comment). Checked only when the
    /// language is *not* a shell dialect — those keep the richer
    /// `shellBlockStatements` per-line-invoke treatment regardless of any
    /// mapping entry. Returns `nil` when the line isn't a code-block sentinel
    /// or the language has no configured mapping.
    func toolFenceStatements(_ line: SourceLine) -> [StatementAST]? {
        guard let (lang, body) = decodeCodeBlockSentinel(line.text) else { return nil }
        guard !lexicon.isShellFence(lang), let toolID = lexicon.fenceTool(for: lang) else { return nil }
        return [.phraseInvocation(PhraseInvocationAST(
            words: encodeToolFenceCommand(toolID: toolID, body: body),
            sourceLine: line.number
        ))]
    }

    /// Expand a collapsed Markdown table sentinel into statements per its mode.
    /// Returns nil when the line is not a table sentinel; an (possibly empty)
    /// array otherwise (empty = inert/iteration, consumed without execution).
    func tableStatements(_ line: SourceLine, sourceFile: String) throws -> [StatementAST]? {
        guard let (mode, table) = TableParser.decode(line.text) else { return nil }
        trace.log(.statement, "table \(mode) \(table.rows.count) row(s), \(table.header.count) column(s) @L\(line.number)")
        let parser = TableParser(lexicon: lexicon, trace: trace)
        switch mode {
        case .decision:
            var out: [StatementAST] = []
            for rowText in parser.decisionRowTexts(table) {
                let rowLine = SourceLine(indent: line.indent, text: rowText, raw: line.raw, number: line.number)
                if let expanded = try parseInlineChain(rowLine, sourceFile: sourceFile) {
                    out.append(contentsOf: expanded)
                } else if let stmt = try parseStatement([rowLine], at: 0, sourceFile: sourceFile).0 {
                    out.append(stmt)
                } else {
                    try raiseStructural(
                        .unparseableStatement,
                        message: "decision-table row does not parse as a statement: \"\(rowText)\"",
                        range: SourceRange(file: sourceFile, line: line.number, column: 1),
                        help: "Each decision-table row must expand to a valid action or chained actions (e.g. `emit x.` or `bind y = z.`). Fix the row's action column, or remove the row.")
                }
            }
            return out
        case .data(let name):
            return [try dataTableBinding(table, name: name, line: line, sourceFile: sourceFile)]
        case .aiDiscretion:
            return [proseStep(parser.aiDecisionProse(table), dispatch: .discretion, line: line)]
        case .aiAutonomy:
            return [proseStep(parser.aiDecisionProse(table), dispatch: .autonomy, line: line)]
        case .inert:
            return []
        case .iteration:
            return try parseIterationTable(table, line: line, sourceFile: sourceFile)
        }
    }

    /// `!!! table (( iteration table ))` — each row is a `for each …` header.
    func parseIterationTable(
        _ table: TableParser.ParsedTable,
        line: SourceLine,
        sourceFile: String
    ) throws -> [StatementAST] {
        guard let actionCol = table.header.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces).lowercased() == "action"
        }) else { return [] }
        var out: [StatementAST] = []
        for row in table.rows {
            let rowText = actionCol < row.count ? row[actionCol].trimmingCharacters(in: .whitespaces) : ""
            guard !rowText.isEmpty else { continue }
            let src = rowText.hasSuffix(".") ? rowText : rowText + "."
            let lines = IndentTokenizer().tokenize(src, file: sourceFile)
            let block = try parseBlock(lines.filter(\.isContent), sourceFile: sourceFile)
            guard case .iteration(let iter) = block.statements.first else { continue }
            out.append(.iteration(iter))
        }
        return out
    }

    /// Build a `bind <name> = <recordList>` from a data table. Field names come
    /// from the header; each cell is a literal value (numbers/money/duration
    /// parse as literals, everything else is a string literal).
    func dataTableBinding(_ table: TableParser.ParsedTable, name: String?, line: SourceLine, sourceFile: String) throws -> StatementAST {
        let columns = table.header.map(parseDataColumnHeader)
        let fields = columns.map(\.name)
        let rows = try table.rows.enumerated().map { rowIndex, row -> [ExpressionAST] in
            try (0 ..< fields.count).map { idx in
                try dataCellValue(
                    idx < row.count ? row[idx] : "",
                    type: columns[idx].type,
                    row: rowIndex + 1,
                    column: fields[idx],
                    line: line,
                    sourceFile: sourceFile
                )
            }
        }
        return .bind(BindStatementAST(
            name: name ?? "table",
            value: .recordList(fields: fields, rows: rows),
            sourceLine: line.number
        ))
    }

    /// Coerce a data-table cell to a literal expression. A cell that parses to a
    /// literal keeps its type; anything else becomes a string literal (a data
    /// value is never a state read).
    func parseDataColumnHeader(_ raw: String) -> (name: String, type: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(")"), let open = trimmed.lastIndex(of: "(") else {
            return (trimmed, nil)
        }
        let name = String(trimmed[trimmed.startIndex..<open]).trimmingCharacters(in: .whitespaces)
        let type = String(trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)])
            .trimmingCharacters(in: .whitespaces)
        return (name.isEmpty ? trimmed : name, type.isEmpty ? nil : type)
    }

    func dataCellValue(_ raw: String, type: String?, row: Int, column: String, line: SourceLine, sourceFile: String) throws -> ExpressionAST {
        let cell = raw.trimmingCharacters(in: .whitespaces)
        if cell.isEmpty { return .literal(.string("")) }
        if cell.hasPrefix("\"") && cell.hasSuffix("\"") && cell.count >= 2 {
            return .literal(.string(String(cell.dropFirst().dropLast())))
        }
        let parsed = exprParser.parse(cell)
        if let type {
            try validateDataCell(parsed, raw: cell, type: type, row: row, column: column, line: line, sourceFile: sourceFile)
        }
        if case .literal = parsed { return parsed }
        return .literal(.string(cell))
    }

    func validateDataCell(_ parsed: ExpressionAST, raw: String, type: String, row: Int, column: String, line: SourceLine, sourceFile: String) throws {
        let lower = type.lowercased()
        let ok: Bool
        switch lower {
        case "string", "text":
            ok = true
        case "number":
            if case .literal(.integer) = parsed { ok = true }
            else if case .literal(.double) = parsed { ok = true }
            else { ok = false }
        case "money":
            if case .literal(.money) = parsed { ok = true } else { ok = false }
        case "boolean", "bool":
            if case .literal(.boolean) = parsed { ok = true } else { ok = false }
        case "duration":
            if case .literal(.duration) = parsed { ok = true } else { ok = false }
        default:
            ok = true
        }
        guard ok else {
            try raiseStructural(
                .invalidTableCell,
                message: "table cell at row \(row), column `\(column)` expected \(type), got `\(raw)`",
                range: SourceRange(file: sourceFile, line: line.number, column: 1),
                help: "Fix the cell value to match the column type or remove the `(Type)` annotation from the header.")
        }
    }

    /// Split a shell-block body into individual commands, dropping blank lines
    /// and `#` comments and joining trailing-backslash line continuations.
    func splitShellCommands(_ body: String) -> [String] {
        var commands: [String] = []
        var pending = ""
        for rawLine in body.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                if pending.isEmpty { continue }
            }
            if trimmed.hasSuffix("\\") {
                pending += String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces) + " "
                continue
            }
            let full = (pending + trimmed).trimmingCharacters(in: .whitespaces)
            pending = ""
            if !full.isEmpty && !full.hasPrefix("#") { commands.append(full) }
        }
        if !pending.trimmingCharacters(in: .whitespaces).isEmpty {
            commands.append(pending.trimmingCharacters(in: .whitespaces))
        }
        return commands
    }

    /// A line whose entire statement is a single backtick-quoted command,
    /// optionally followed by a ` -- <note>` annotation (1A), e.g.
    /// `` `gbrain publish "title"` -- announce the page `` — lowers to one
    /// `shell.run` invoke carrying the note as a source comment.
    func inlineBacktickedCommand(_ line: SourceLine) -> StatementAST? {
        let raw = line.statement.trimmingCharacters(in: .whitespaces)
        let (commandSpan, annotation) = Self.splitCommandAnnotation(raw)
        let t = commandSpan.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2, t.hasPrefix("`"), t.hasSuffix("`") else { return nil }
        let inner = String(t.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        // Reject if the inner text still contains a backtick (not a single span)
        // or is empty.
        guard !inner.isEmpty, !inner.contains("`") else { return nil }
        return .phraseInvocation(PhraseInvocationAST(
            words: encodeShellCommand(inner),
            annotation: annotation,
            sourceLine: line.number
        ))
    }

    /// A line with exactly one backtick command span plus prose, e.g.
    /// `Verify: `gbrain doctor --json``. This covers common SKILL.md numbered
    /// and labelled command steps after `IndentTokenizer` strips list markers.
    func embeddedBacktickedCommand(_ line: SourceLine) -> StatementAST? {
        let raw = line.statement.trimmingCharacters(in: .whitespaces)
        guard !startsWithPrimitiveStatement(raw) else { return nil }
        let spans = Self.backtickSpans(in: raw)
        guard spans.count == 1 else { return nil }
        let span = spans[0]
        let command = String(raw[span.lowerBound..<span.upperBound]).trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty, commandLooksShellLike(command) else { return nil }

        var annotationSource = raw
        annotationSource.replaceSubrange(span.fullRange(in: raw), with: "")
        let annotation = cleanCommandAnnotation(annotationSource)
        return .phraseInvocation(PhraseInvocationAST(
            words: encodeShellCommand(command),
            annotation: annotation.isEmpty ? nil : annotation,
            sourceLine: line.number
        ))
    }

    func startsWithPrimitiveStatement(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        return lexicon.grammar.statement.primitivePrefixes.contains { lower.hasPrefix($0) }
    }

    private struct BacktickSpan {
        let lowerBound: String.Index
        let upperBound: String.Index

        func fullRange(in s: String) -> ClosedRange<String.Index> {
            s.index(before: lowerBound)...upperBound
        }
    }

    private static func backtickSpans(in s: String) -> [BacktickSpan] {
        var spans: [BacktickSpan] = []
        var open: String.Index? = nil
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "`" {
                if let start = open {
                    spans.append(BacktickSpan(lowerBound: s.index(after: start), upperBound: i))
                    open = nil
                } else {
                    open = i
                }
            }
            i = s.index(after: i)
        }
        return spans
    }

    func commandLooksShellLike(_ command: String) -> Bool {
        command.contains(" ") || command.contains("/") || command.contains(".") || command.contains("-")
    }

    func cleanCommandAnnotation(_ raw: String) -> String {
        var s = raw
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespaces)
        while let last = s.last, last == ":" || last == "-" || last == "\u{2014}" || last == "\u{2013}" {
            s.removeLast()
            s = s.trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    func stripMarkdownListMarker(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("- ") || s.hasPrefix("* ") {
            return String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        var digits = ""
        var idx = s.startIndex
        while idx < s.endIndex, s[idx].isNumber {
            digits.append(s[idx])
            idx = s.index(after: idx)
        }
        if !digits.isEmpty, idx < s.endIndex, s[idx] == "." || s[idx] == ")" {
            let after = s.index(after: idx)
            if after == s.endIndex || s[after].isWhitespace {
                s = String(s[after...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return s
    }

}
