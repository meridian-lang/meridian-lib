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
    /// Optional desugar engine threaded into every StatementParser this parser
    /// constructs. Nil for plain `.meridian` files (no rulebook loaded).
    public let rewriteEngine: RewriteEngine?

    public init(symbols: SymbolTable, trace: ParserTrace = .shared,
                lexicon: EnglishLexicon = .default,
                rewriteEngine: RewriteEngine? = nil) {
        self.symbols = symbols
        self.trace = trace
        self.lexicon = lexicon
        self.rewriteEngine = rewriteEngine
    }

    private func makeStatementParser() -> StatementParser {
        StatementParser(symbols: symbols, trace: trace, lexicon: lexicon, rewriteEngine: rewriteEngine)
    }

    public func parse(_ source: String, file: String = "") throws -> MeridianFile {
        let token = trace.push(.merconfig, "MeridianParser.parse(\(file))")
        defer { trace.pop(token) }
        let lines = IndentTokenizer().tokenize(source, file: file)
        let outline = lines.compactMap { line -> HeadingEntry? in
            guard let level = line.headingLevel else { return nil }
            // Strip any trailing `(( … ))` marker so the outline carries the
            // clean heading text; the resolved role surfaces as `kind`.
            let clean = SkillSectionRole.parseMarker(from: line.text).cleanHeading
            return HeadingEntry(level: level, text: clean, line: line.number)
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
        var definitions: [DefinitionDeclaration] = []
        var implicitBodyLines: [SourceLine] = []
        // Heading-aware view of the implicit region, used only when the file
        // opts into SKILL.md section semantics (`skill: true`). Captures the
        // `##`/`###` heading lines interleaved with the top-level statements so
        // `SkillSectionBuilder` can group statements by their section role.
        var implicitRegionLines: [SourceLine] = []

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
            // Multi-valued frontmatter keys (YAML block sequences and block
            // scalars) preserve their elements/lines as a single value joined
            // by `frontmatterListSeparator` ("\n"). `SkillFrontmatter` splits
            // these back into typed arrays; scalar keys never contain "\n".
            while i < lines.count {
                let l = lines[i]
                if l.text == "---" { i += 1; break }
                guard l.isContent, let colonIdx = l.text.firstIndex(of: ":") else {
                    i += 1
                    continue
                }
                let key   = String(l.text[l.text.startIndex ..< colonIdx]).trimmingCharacters(in: .whitespaces)
                let inline = String(l.text[l.text.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                var value = inline
                var j = i + 1

                if isBlockScalarMarker(inline) {
                    // `key: |` / `key: >` — collect deeper-indented lines verbatim.
                    var body: [String] = []
                    while j < lines.count {
                        let next = lines[j]
                        if next.isEmpty { body.append(""); j += 1; continue }
                        if next.indent > l.indent {
                            body.append(next.text)
                            j += 1
                        } else { break }
                    }
                    while body.last == "" { body.removeLast() }
                    value = body.joined(separator: frontmatterListSeparator)
                } else if inline.hasPrefix("[") && inline.hasSuffix("]") {
                    // Inline flow sequence: `key: [a, b, c]`.
                    let inner = String(inline.dropFirst().dropLast())
                    value = inner.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .init(charactersIn: "\"'")) }
                        .filter { !$0.isEmpty }
                        .joined(separator: frontmatterListSeparator)
                } else {
                    // Peek for a YAML block sequence (`- item` lines) when the
                    // value is empty; otherwise fold plain continuation lines.
                    let peek = skipBlanksIndex(from: j, in: lines)
                    if inline.isEmpty, peek < lines.count,
                       lines[peek].listMarker != nil, lines[peek].indent >= l.indent {
                        var items: [String] = []
                        var k = peek
                        while k < lines.count {
                            let next = lines[k]
                            if next.isEmpty || next.isComment { k += 1; continue }
                            if next.listMarker != nil, next.indent >= l.indent {
                                items.append(next.text.trimmingCharacters(in: .whitespaces))
                                k += 1
                            } else { break }
                        }
                        value = items.joined(separator: frontmatterListSeparator)
                        j = k
                    } else {
                        while j < lines.count {
                            let next = lines[j]
                            if next.isEmpty || next.isComment { j += 1; continue }
                            if next.indent > l.indent, next.listMarker == nil {
                                value += " " + next.text.trimmingCharacters(in: .whitespaces)
                                j += 1
                            } else { break }
                        }
                    }
                }

                i = j
                if !key.isEmpty { entries.append((key: key, value: value)) }
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
            for part in raw.split(whereSeparator: { $0 == "," || $0 == "\n" }) {
                let token = String(part)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: .init(charactersIn: "\"'"))
                guard !token.isEmpty else { continue }
                imports.append(ImportStatementAST(path: token, sourceLine: line))
            }
        }

        // A "sectioned document" is any file whose body carries `##`/`###`
        // headings. In such documents narrative sentences routinely begin with
        // "When …" / "A …" / "An …" ("When the user wants to save a thought,
        // …"). Those are prose, not Meridian `When X, do Y` rules — so we never
        // extract in-body rules from a sectioned doc. Triggers come from
        // frontmatter `triggers:`; cross-cutting behaviour from rulebook
        // conventions. A heading-less `.meridian`/`.meri` file is unaffected
        // (byte-for-byte flat-procedure behaviour).
        let hasHeadings = lines.contains { ($0.headingLevel ?? 0) > 0 }

        while i < lines.count {
            let line = lines[i]
            guard line.isContent else { i += 1; continue }
            if line.headingLevel != nil { implicitRegionLines.append(line); i += 1; continue }
            let t = line.statement
            let lower = t.lowercased()

            // 2B: top-level `Definition:` lines are pulled out of the implicit
            // body so they register as checkable adjectives, not procedure steps.
            if DefinitionParser.isDefinitionLine(t) {
                if let def = DefinitionParser(lexicon: lexicon, symbols: symbols, trace: trace)
                    .parse(t, line: line.number) {
                    definitions.append(def)
                }
                i += 1; continue
            }

            // Reject the old body-level `import …` forms with a structured
            // diagnostic so existing files migrate cleanly. Skill docs are exempt:
            // a SKILL.md procedure line may legitimately begin with the English
            // verb "Import" ("Import the vault directory into gbrain").
            if !hasHeadings, lower.hasPrefix("import vocabulary from ") || lower.hasPrefix("import ") {
                throw CompilerError.semanticError(
                    message: "body-level `import` is no longer supported. Move the merconfig path(s) to frontmatter `vocabulary:` (comma-separated).",
                    range: SourceRange(file: file, line: line.number, column: 1)
                )
            }

            // Rules: starts with "A customer …", "An order …", "When …"
            // (suppressed for skill docs, where these are narrative prose).
            let isRule = !hasHeadings &&
                        (t.lowercased().hasPrefix("a ") ||
                         t.lowercased().hasPrefix("an ") ||
                         t.lowercased().hasPrefix("when "))
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
                let body = try makeStatementParser().parseBlock(bodyLines, file: file)
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
                implicitRegionLines.append(line)
                while j < lines.count {
                    let l = lines[j]
                    if l.isEmpty || l.isComment { j += 1; continue }
                    if l.indent > line.indent {
                        implicitBodyLines.append(l)
                        implicitRegionLines.append(l)
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

        var skillSections: [SkillSectionRecord] = []
        var dispatchPhrases: [String] = []
        var negativeDispatchPhrases: [String] = []
        var toolsUsed: [String] = []

        if !implicitBodyLines.isEmpty {
            let built = try buildImplicitWorkflow(
                from: implicitBodyLines, regionLines: implicitRegionLines,
                metadata: metadata, hasHeadings: hasHeadings, file: file)
            let implicit = built.workflow
            skillSections = built.sections
            dispatchPhrases = built.dispatchPhrases
            negativeDispatchPhrases = built.negativeDispatchPhrases
            toolsUsed = built.toolsUsed
            let implicitName = implicit.pattern.displayText.lowercased()
            if workflows.contains(where: { $0.pattern.displayText.lowercased() == implicitName }) {
                throw CompilerError.semanticError(
                    message: "ambiguous entry workflow: frontmatter `name` matches an explicit workflow while top-level statements are also present",
                    range: SourceRange(file: file, line: implicit.sourceLine, column: 1)
                )
            }
            workflows.insert(implicit, at: 0)
        }

        return MeridianFile(imports: imports, rules: rules, workflows: workflows,
                            metadata: metadata, outline: outline,
                            skillSections: skillSections,
                            dispatchPhrases: dispatchPhrases,
                            negativeDispatchPhrases: negativeDispatchPhrases,
                            toolsUsed: toolsUsed,
                            definitions: definitions)
    }

    /// The implicit entry workflow plus the section metadata mined while
    /// building it (recorded sections + applicability dispatch phrases).
    private struct BuiltImplicit {
        let workflow: WorkflowAST
        let sections: [SkillSectionRecord]
        let dispatchPhrases: [String]
        let negativeDispatchPhrases: [String]
        let toolsUsed: [String]
    }

    private func buildImplicitWorkflow(
        from bodyLines: [SourceLine],
        regionLines: [SourceLine],
        metadata: FileMetadataAST?,
        hasHeadings: Bool,
        file: String
    ) throws -> BuiltImplicit {
        let name = metadata?["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "entry"
        var parameters = try frontmatterParameters(
            metadata?["parameters"],
            sourceLine: metadata?.sourceLine ?? bodyLines.first?.number ?? 1,
            file: file
        )
        // SKILL.md skills operate on freeform input. When no `parameters:` key
        // is declared, default to a single generic `input` parameter — but only
        // when the imported vocabulary actually declares an `input` kind, so we
        // never synthesize an unresolvable parameter type.
        if parameters.isEmpty, let resolved = symbols.resolveKindName("input") {
            parameters = [PhraseParameterAST(name: camelize(resolved), kind: resolved)]
        }
        var segments: [PatternSegment] = [.literal(name)]
        segments.append(contentsOf: parameters.map(PatternSegment.parameter))

        // Section semantics activate structurally: when the body carries
        // `##`/`###` headings, rewrite it through section-role lowering before
        // parsing (and record every section for the manifest). A heading-less
        // body is parsed verbatim so plain `.meridian`/`.meri` files are
        // byte-for-byte unaffected.
        let effectiveBody: [SourceLine]
        var sections: [SkillSectionRecord] = []
        var dispatchPhrases: [String] = []
        var negativeDispatchPhrases: [String] = []
        var toolsUsed: [String] = []
        if hasHeadings {
            let builder = SkillSectionBuilder(
                symbols: symbols, lexicon: lexicon, trace: trace,
                rulebook: rewriteEngine?.rulebook ?? .empty, file: file)
            let result = try builder.build(regionLines: regionLines)
            effectiveBody = result.bodyLines
            sections = result.sections
            dispatchPhrases = result.dispatchPhrases
            negativeDispatchPhrases = result.negativeDispatchPhrases
            toolsUsed = result.toolsUsed
        } else {
            effectiveBody = bodyLines
        }

        let body = try makeStatementParser().parseBlock(effectiveBody, file: file)
        let workflow = WorkflowAST(
            pattern: PhrasePattern(segments: segments),
            body: body,
            sourceLine: bodyLines.first?.number ?? metadata?.sourceLine ?? 1,
            sourceFile: file
        )
        return BuiltImplicit(workflow: workflow, sections: sections,
                             dispatchPhrases: dispatchPhrases,
                             negativeDispatchPhrases: negativeDispatchPhrases,
                             toolsUsed: toolsUsed)
    }

    private func frontmatterParameters(_ raw: String?, sourceLine: Int, file: String) throws -> [PhraseParameterAST] {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let tokens = raw
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return try tokens.map { kind in
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
        let exprParser = ExpressionParser(symbols: symbols, trace: trace, lexicon: lexicon)
        return AutonomyConfigAST.parse(raw, parseExpression: exprParser.parse)
    }

    /// True for YAML block-scalar introducers (`|`, `|-`, `>`, `>-`, `>+`).
    private func isBlockScalarMarker(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t == "|" || t == "|-" || t == "|+" || t == ">" || t == ">-" || t == ">+"
    }

    /// First non-blank, non-comment line index at or after `from`.
    private func skipBlanksIndex(from: Int, in lines: [SourceLine]) -> Int {
        var k = from
        while k < lines.count, lines[k].isEmpty || lines[k].isComment { k += 1 }
        return k
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

/// Separator used to pack multi-valued frontmatter (YAML sequences and block
/// scalars) into a single `FileMetadataAST` value string. `SkillFrontmatter`
/// splits on this to recover typed arrays. Newlines never appear in scalar
/// frontmatter values, so this is an unambiguous delimiter.
let frontmatterListSeparator = "\n"

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
