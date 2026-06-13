import Foundation

// MARK: - TableParser
//
// Decodes a table sentinel (produced by `IndentTokenizer.collapseTable`) into a
// header + rows, then turns it into deterministic Meridian statements according
// to its `TableMode`:
//
//   • decision (default) → one `if <conjunction>, <action>.` per row, reusing
//     the existing inline-conditional grammar. No new IR.
//   • data               → a single `bind <name> = <recordList>` (B2).
//   • inert              → no statements (recorded, never executed).
//   • iteration          → reserved (B4); produces no statements yet.
//
// The cell-to-predicate mapping (symbolic operators, comparison-marker
// shorthands, bare-value equality) lives here so authors get plain-English
// comparisons without writing the copula in every cell.

struct TableParser {
    let lexicon: EnglishLexicon

    /// A decoded table: the header cells and the data rows (the Markdown
    /// delimiter row is dropped).
    struct ParsedTable {
        let header: [String]
        let rows: [[String]]
    }

    /// Decode a table sentinel into its mode and parsed contents. Returns nil
    /// when `text` is not a table sentinel or is structurally empty.
    static func decode(_ text: String) -> (mode: TableMode, table: ParsedTable)? {
        guard let (mode, body) = decodeTableSentinel(text) else { return nil }
        let bodyLines = body.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard bodyLines.count >= 2 else { return nil }   // header + delimiter at minimum
        let header = splitRow(bodyLines[0])
        let rows = bodyLines.dropFirst(2).map { splitRow($0) }
        return (mode, ParsedTable(header: header, rows: Array(rows)))
    }

    /// Split a Markdown pipe row into trimmed cells, dropping the optional
    /// leading/trailing pipe.
    static func splitRow(_ raw: String) -> [String] {
        var t = raw.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        return t.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: Decision tables

    /// Symbolic comparison operators a cell may begin with, mapped to the
    /// comparison op they denote. The English *spelling* is sourced from
    /// `lexicon.comparisonMarkers` (single source of truth); only the symbolic
    /// notation itself is fixed here. Ordered longest-first so `>=` wins over `>`.
    private static let symbolicOps: [(symbol: String, op: ComparisonOpAST)] = [
        (">=", .greaterOrEqual),
        ("<=", .lessOrEqual),
        ("!=", .notEqual),
        (">",  .greaterThan),
        ("<",  .lessThan),
        ("=",  .equal),
    ]

    /// The canonical English spelling for a comparison op — the first matching
    /// `lexicon.comparisonMarkers` entry (defaults are ordered longest-first, so
    /// this yields the most explicit phrasing, e.g. `.equal` → `is`).
    private func spelling(for op: ComparisonOpAST) -> String? {
        lexicon.comparisonMarkers.first(where: { $0.1 == op })?.0
    }

    private func actionColumnIndex(_ header: [String]) -> Int {
        for (idx, h) in header.enumerated() where lexicon.tableActionHeaders.contains(h.lowercased()) { return idx }
        return max(header.count - 1, 0)
    }

    /// Render a *fuzzy* decision table as planner instructions: one rule per row
    /// (`when <conditions>, <action>`; a fully-wildcard row → `otherwise, …`).
    /// Used for `!!! table (( ai-discretion ))` / `(( ai-autonomy ))`, where the
    /// condition cells are intent descriptions rather than checkable comparisons.
    /// The rules are embedded verbatim so the planner has the full ruleset.
    func aiDecisionProse(_ table: ParsedTable) -> String {
        guard !table.header.isEmpty else { return "" }
        let actionIdx = actionColumnIndex(table.header)
        var rules: [String] = []
        for row in table.rows {
            guard actionIdx < row.count else { continue }
            let action = row[actionIdx].trimmingCharacters(in: .whitespaces)
            guard !action.isEmpty else { continue }

            var conds: [String] = []
            for (idx, cell) in row.enumerated() where idx != actionIdx {
                guard idx < table.header.count else { continue }
                let c = cell.trimmingCharacters(in: .whitespaces)
                if isWildcardCell(c) { continue }
                let h = table.header[idx].trimmingCharacters(in: .whitespaces)
                if lexicon.tableConditionHeaders.contains(h.lowercased()) {
                    conds.append(c)
                } else {
                    conds.append("\(h) is \(c)")
                }
            }
            rules.append(conds.isEmpty ? "- otherwise, \(action)" : "- when \(conds.joined(separator: ", ")), \(action)")
        }
        return "Decide which case below applies and carry out its action:\n" + rules.joined(separator: "\n")
    }

    /// Synthesize one statement text per row: `if <conjunction>, <action>` (or
    /// just `<action>` when every condition cell is a wildcard). The returned
    /// strings are re-parsed by `StatementParser` through the normal grammar.
    func decisionRowTexts(_ table: ParsedTable) -> [String] {
        guard !table.header.isEmpty else { return [] }
        let actionIdx = actionColumnIndex(table.header)
        var out: [String] = []
        for row in table.rows {
            guard actionIdx < row.count else { continue }
            let action = row[actionIdx].trimmingCharacters(in: .whitespaces)
            guard !action.isEmpty else { continue }

            var predicates: [String] = []
            for (idx, cell) in row.enumerated() where idx != actionIdx {
                guard idx < table.header.count else { continue }
                if let p = conditionPredicate(header: table.header[idx], cell: cell) {
                    predicates.append(p)
                }
            }
            if predicates.isEmpty {
                out.append(action)
            } else {
                out.append("if \(predicates.joined(separator: " and ")), \(action)")
            }
        }
        return out
    }

    /// Build a condition predicate from a `(header, cell)` pair, or nil when the
    /// cell is a wildcard (the column does not constrain this row).
    private func conditionPredicate(header rawHeader: String, cell rawCell: String) -> String? {
        let cell = rawCell.trimmingCharacters(in: .whitespaces)
        if isWildcardCell(cell) { return nil }
        let lower = cell.lowercased()
        let h = rawHeader.trimmingCharacters(in: .whitespaces).lowercased()

        // Symbolic operator prefix → canonical lexicon spelling.
        for (symbol, op) in Self.symbolicOps where cell.hasPrefix(symbol) {
            guard let spelling = spelling(for: op) else { continue }
            let value = String(cell.dropFirst(symbol.count)).trimmingCharacters(in: .whitespaces)
            return "\(h) \(spelling) \(value)"
        }

        // Cell already phrased as a comparison (`more than 5`, `contains x`,
        // `is at least 3`, `matches pattern "…"`). Restore the canonical form.
        for (spelling, _) in lexicon.comparisonMarkers {
            if spelling.hasPrefix("is ") {
                let core = String(spelling.dropFirst(3))
                if lower == spelling || lower.hasPrefix(spelling + " ") { return "\(h) \(cell)" }
                if lower == core || lower.hasPrefix(core + " ") { return "\(h) is \(cell)" }
            } else {
                if lower == spelling || lower.hasPrefix(spelling + " ") { return "\(h) \(cell)" }
            }
        }

        // Bare value → equality. Quote a multi-word, non-numeric value so it
        // parses as a string literal rather than an identifier chain.
        return "\(h) is \(quoteIfNeeded(cell))"
    }

    /// A "wildcard" decision-table cell does not constrain its row (blank, a
    /// dash/asterisk/em/en-dash placeholder, or the word `any`).
    private func isWildcardCell(_ cell: String) -> Bool {
        let c = cell.trimmingCharacters(in: .whitespaces)
        if c.isEmpty { return true }
        return lexicon.tableWildcardTokens.contains(c) || lexicon.tableWildcardTokens.contains(c.lowercased())
    }

    private func quoteIfNeeded(_ value: String) -> String {
        if value.hasPrefix("\"") && value.hasSuffix("\"") { return value }
        let isNumeric = value.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" }
        if value.contains(" ") && !isNumeric { return "\"\(value)\"" }
        return value
    }
}
