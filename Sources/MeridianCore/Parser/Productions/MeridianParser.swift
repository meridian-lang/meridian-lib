import Foundation
import MeridianRuntime

// MARK: - MeridianParser
//
// Parses .meridian files into MeridianFile AST nodes.
// Expects a SymbolTable (populated from the imported .merconfig) for name resolution.

public struct MeridianParser {

    public let symbols: SymbolTable
    public let trace: ParserTrace
    public let lexicon: EnglishLexicon

    public init(symbols: SymbolTable, trace: ParserTrace = .shared, lexicon: EnglishLexicon = .default) {
        self.symbols = symbols
        self.trace = trace
        self.lexicon = lexicon
    }

    public func parse(_ source: String, file: String = "") throws -> MeridianFile {
        let token = trace.push(.merconfig, "MeridianParser.parse(\(file))")
        defer { trace.pop(token) }
        let lines = IndentTokenizer().tokenize(source, file: file)
        let outline = lines.compactMap { line -> HeadingEntry? in
            guard let level = line.headingLevel else { return nil }
            return HeadingEntry(level: level, text: line.text, line: line.number)
        } + lines.compactMap { line -> HeadingEntry? in
            guard line.headingLevel == nil,
                  !line.statement.lowercased().hasPrefix("to "),
                  let (label, rest) = StatementParser.topicLabel(in: line.statement),
                  !rest.isEmpty || line.indent == 0 else { return nil }
            return HeadingEntry(level: 3, text: label, line: line.number, kind: "topic")
        }
        var imports:   [ImportStatementAST] = []
        var rules:     [RuleAST]            = []
        var workflows: [WorkflowAST]        = []
        var implicitBodyLines: [SourceLine] = []

        // B1: Detect optional `---`-delimited frontmatter at the top of the file.
        //
        // Frontmatter MUST be the first entry in the file — only blank lines
        // are allowed before the opening `---`. Any non-blank content
        // (including `#` comments) before a frontmatter block is a hard error.
        var metadata: FileMetadataAST? = nil
        var i = 0
        while i < lines.count, lines[i].isEmpty { i += 1 }
        let firstNonBlank = i

        // If the file has any `---/---` block but it isn't the first entry,
        // diagnose precisely so authors don't silently lose their frontmatter.
        if i < lines.count && lines[i].text != "---" {
            for k in i..<lines.count where lines[k].text == "---" {
                var hasCloser = false
                for n in (k + 1)..<lines.count where lines[n].text == "---" { hasCloser = true; break }
                if hasCloser {
                    throw CompilerError.semanticError(
                        message: "frontmatter must be the first entry in the file (only blank lines may precede the opening `---`)",
                        range: SourceRange(file: file, line: lines[k].number, column: 1)
                    )
                }
            }
        }

        if firstNonBlank < lines.count && lines[firstNonBlank].text == "---" {
            let fmStartLine = lines[i].number
            i += 1
            var entries: [(key: String, value: String)] = []
            while i < lines.count {
                let l = lines[i]
                if l.text == "---" { i += 1; break }
                if l.isContent, let colonIdx = l.text.firstIndex(of: ":") {
                    let key   = String(l.text[l.text.startIndex ..< colonIdx]).trimmingCharacters(in: .whitespaces)
                    var value = String(l.text[l.text.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    // Collect continuation lines indented deeper than this entry.
                    var j = i + 1
                    while j < lines.count {
                        let next = lines[j]
                        if next.isEmpty || next.isComment { j += 1; continue }
                        if next.indent > l.indent {
                            value += " " + next.text.trimmingCharacters(in: .whitespaces)
                            j += 1
                        } else { break }
                    }
                    i = j
                    if !key.isEmpty { entries.append((key: key, value: value)) }
                } else {
                    i += 1
                }
            }
            if !entries.isEmpty {
                metadata = FileMetadataAST(entries: entries, sourceLine: fmStartLine)
            }
        }

        // Vocabulary imports are declared exclusively in frontmatter under the
        // `vocabulary:` key as a comma-separated list of merconfig paths.
        // Example:
        //   ---
        //   name: …
        //   vocabulary: comprehensive_workflows.merconfig, github.merconfig
        //   ---
        // There is intentionally no body-level `import …` syntax — frontmatter
        // is the single source of truth so the dependency set is visible above
        // the fold.
        if let raw = metadata?["vocabulary"] {
            let line = metadata?.sourceLine ?? 1
            for part in raw.split(separator: ",") {
                let token = String(part)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: .init(charactersIn: "\"'"))
                guard !token.isEmpty else { continue }
                imports.append(ImportStatementAST(path: token, sourceLine: line))
            }
        }

        while i < lines.count {
            let line = lines[i]
            guard line.isContent else { i += 1; continue }
            if line.headingLevel != nil { i += 1; continue }
            let t = line.statement
            let lower = t.lowercased()

            // Reject the old body-level `import …` forms with a structured
            // diagnostic so existing files migrate cleanly.
            if lower.hasPrefix("import vocabulary from ") || lower.hasPrefix("import ") {
                throw CompilerError.semanticError(
                    message: "body-level `import` is no longer supported. Move the merconfig path(s) to frontmatter `vocabulary:` (comma-separated).",
                    range: SourceRange(file: file, line: line.number, column: 1)
                )
            }

            // Rules: starts with "A customer …", "An order …", "When …"
            let isRule = t.lowercased().hasPrefix("a ") ||
                         t.lowercased().hasPrefix("an ") ||
                         t.lowercased().hasPrefix("when ")
            let isWorkflow = t.lowercased().hasPrefix("to ")

            if isWorkflow {
                // Fold multi-line workflow header (continuation indented deeper, terminator ":")
                var headerText = t
                var j = i + 1
                if !headerText.hasSuffix(":") {
                    while j < lines.count {
                        let l = lines[j]
                        if l.isEmpty || l.isComment { j += 1; continue }
                        if l.indent > line.indent {
                            let part = l.statement
                            headerText += " " + part
                            j += 1
                            if part.hasSuffix(":") { break }
                        } else {
                            break
                        }
                    }
                }
                guard headerText.hasSuffix(":") else { i += 1; continue }
                // B3 / SkillMD-D17: Detect prose-mode annotations before the colon.
                // (See `.ai/brainstorm-done/skill_md_expressiveness_d1_d28.md`.)
                var rawPatternText = String(headerText.dropFirst(3).dropLast(1))
                    .trimmingCharacters(in: .whitespaces)
                let discretionSuffix = ", with discretion"
                var allowsDiscretion = rawPatternText.lowercased().hasSuffix(discretionSuffix)
                if allowsDiscretion {
                    rawPatternText = String(rawPatternText.dropLast(discretionSuffix.count))
                        .trimmingCharacters(in: .whitespaces)
                }
                var autonomy: AutonomyConfigAST?
                if let autonomyRange = rawPatternText.lowercased().range(of: ", with autonomy") {
                    let options = String(rawPatternText[autonomyRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    rawPatternText = String(rawPatternText[..<autonomyRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    allowsDiscretion = true
                    autonomy = parseAutonomyOptions(options)
                }
                let pattern = PhrasePatternParser(trace: trace, lexicon: lexicon).parse(rawPatternText)

                var bodyLines: [SourceLine] = []
                while j < lines.count {
                    let l = lines[j]
                    if l.isEmpty || l.isComment { j += 1; continue }
                    if l.indent > line.indent { bodyLines.append(l); j += 1 }
                    else { break }
                }
                let body = try StatementParser(symbols: symbols, trace: trace, lexicon: lexicon).parseBlock(bodyLines, file: file)
                trace.log(.merconfig, "workflow @L\(line.number): \(pattern.segments.count) segs, \(body.statements.count) stmts")
                workflows.append(WorkflowAST(
                    pattern: pattern, body: body,
                    sourceLine: line.number, sourceFile: file,
                    allowsDiscretion: allowsDiscretion,
                    autonomy: autonomy
                ))
                i = j
                continue
            }

            if isRule {
                rules.append(RuleAST(text: t, sourceLine: line.number))
                i += 1
                continue
            }

            if line.indent == 0 {
                var j = i + 1
                implicitBodyLines.append(line)
                while j < lines.count {
                    let l = lines[j]
                    if l.isEmpty || l.isComment { j += 1; continue }
                    if l.indent > line.indent {
                        implicitBodyLines.append(l)
                        j += 1
                    } else {
                        break
                    }
                }
                i = j
                continue
            }

            i += 1
        }

        if !implicitBodyLines.isEmpty {
            let implicit = try buildImplicitWorkflow(from: implicitBodyLines, metadata: metadata, file: file)
            let implicitName = implicit.pattern.displayText.lowercased()
            if workflows.contains(where: { $0.pattern.displayText.lowercased() == implicitName }) {
                throw CompilerError.semanticError(
                    message: "ambiguous entry workflow: frontmatter `name` matches an explicit workflow while top-level statements are also present",
                    range: SourceRange(file: file, line: implicit.sourceLine, column: 1)
                )
            }
            workflows.insert(implicit, at: 0)
        }

        return MeridianFile(imports: imports, rules: rules, workflows: workflows, metadata: metadata, outline: outline)
    }

    private func buildImplicitWorkflow(
        from bodyLines: [SourceLine],
        metadata: FileMetadataAST?,
        file: String
    ) throws -> WorkflowAST {
        let name = metadata?["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "entry"
        let parameters = try frontmatterParameters(
            metadata?["parameters"],
            sourceLine: metadata?.sourceLine ?? bodyLines.first?.number ?? 1,
            file: file
        )
        var segments: [PatternSegment] = [.literal(name)]
        segments.append(contentsOf: parameters.map(PatternSegment.parameter))
        let body = try StatementParser(symbols: symbols, trace: trace, lexicon: lexicon)
            .parseBlock(bodyLines, file: file)
        return WorkflowAST(
            pattern: PhrasePattern(segments: segments),
            body: body,
            sourceLine: bodyLines.first?.number ?? metadata?.sourceLine ?? 1,
            sourceFile: file
        )
    }

    private func frontmatterParameters(_ raw: String?, sourceLine: Int, file: String) throws -> [PhraseParameterAST] {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return try raw.split(separator: ",").map { chunk in
            let kind = String(chunk).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let resolved = symbols.resolveKindName(kind) else {
                throw CompilerError.semanticError(
                    message: "frontmatter parameter `\(kind)` does not resolve to an imported vocabulary kind",
                    range: SourceRange(file: file, line: sourceLine, column: 1)
                )
            }
            return PhraseParameterAST(name: camelize(resolved), kind: resolved)
        }
    }

    private func parseAutonomyOptions(_ raw: String) -> AutonomyConfigAST {
        let lower = raw.lowercased()
        let exprParser = ExpressionParser(symbols: symbols, trace: trace, lexicon: lexicon)
        let until = extractClause(named: "until", from: raw, lower: lower).map(exprParser.parse)
        let unless = extractClause(named: "unless", from: raw, lower: lower).map(exprParser.parse)
        let replan = extractIntAfter("re-plan after", from: lower)
            ?? extractIntAfter("replan after", from: lower)
            ?? 3
        let maxSteps = extractIntAfter("max", from: lower)
            ?? extractIntAfter("up to", from: lower)
            ?? 32
        return AutonomyConfigAST(
            until: until,
            unless: unless,
            replanAfterFailures: replan,
            maxSteps: maxSteps
        )
    }

    private func extractClause(named marker: String, from raw: String, lower: String) -> String? {
        guard let range = lower.range(of: "\(marker) ") else { return nil }
        let start = range.upperBound
        var end = raw.endIndex
        for next in [" until ", " unless ", " re-plan after ", " replan after ", " max ", " up to "] {
            guard let nextRange = lower[start...].range(of: next) else { continue }
            if nextRange.lowerBound < end { end = nextRange.lowerBound }
        }
        let text = String(raw[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func extractIntAfter(_ marker: String, from lower: String) -> Int? {
        guard let range = lower.range(of: marker) else { return nil }
        let suffix = lower[range.upperBound...]
        let digits = suffix.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
        return Int(String(digits))
    }

    private func camelize(_ raw: String) -> String {
        let parts = raw.lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "_" })
            .map(String.init)
        guard let head = parts.first else { return raw.lowercased() }
        let tail = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return ([head] + tail).joined()
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
