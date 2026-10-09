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
    /// Optional batch collector, threaded into every StatementParser this parser
    /// builds so per-statement parse errors are collected rather than aborting.
    public let diagnostics: DiagnosticEngine?

    public init(symbols: SymbolTable, trace: ParserTrace = .shared,
                lexicon: EnglishLexicon = .default,
                rewriteEngine: RewriteEngine? = nil,
                diagnostics: DiagnosticEngine? = nil) {
        self.symbols = symbols
        self.trace = trace
        self.lexicon = lexicon
        self.rewriteEngine = rewriteEngine
        self.diagnostics = diagnostics
    }

    private func makeStatementParser() -> StatementParser {
        StatementParser(symbols: symbols, trace: trace, lexicon: lexicon,
                        rewriteEngine: rewriteEngine, diagnostics: diagnostics)
    }

    public func parse(_ source: String, file: String = "") throws -> MeridianFile {
        let token = trace.push(.parse, "MeridianParser.parse(\(file))")
        defer { trace.pop(token) }
        let lines = IndentTokenizer().tokenize(source, file: file, trace: trace)
        let outline = MarkdownOutline.build(lines).map { section -> HeadingEntry in
            // Strip any trailing `(( … ))` marker so the outline carries the
            // clean heading text; the resolved role surfaces as `kind`.
            let clean = SkillSectionRole.parseMarker(from: section.heading).cleanHeading
            return HeadingEntry(level: section.level, text: clean, line: section.headingLine)
        } + lines.compactMap { line -> HeadingEntry? in
            guard line.headingLevel == nil,
                  !line.statement.lowercased().hasPrefix(lexicon.grammar.merconfig.workflowHeaderPrefix),
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
        // The block itself is parsed by the shared `Frontmatter.parse`.
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
                    throw CompilerError.diagnostics([
                        Diagnostic.structural(
                            .frontmatterPlacement,
                            message: "frontmatter must be the first entry in the file (only blank lines may precede the opening `---`)",
                            range: SourceRange(file: file, line: lines[k].number, column: 1),
                            help: "Move the `---` block to the top of the file, before any comments or workflow text.")
                    ])
                }
            }
        }

        // `Frontmatter.parse` requires the fence at the first non-blank line
        // (the same predicate `firstNonBlank` computed above), so a non-nil
        // block here is exactly the "frontmatter is first" case.
        if let frontmatter = Frontmatter.parse(lines) {
            i = frontmatter.consumed
            if !frontmatter.entries.isEmpty {
                metadata = FileMetadataAST(entries: frontmatter.entries,
                                           sourceLine: lines[firstNonBlank].number)
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
                imports.append(ImportStatementAST(path: token, kind: .vocabulary, sourceLine: line))
            }
        }
        if let raw = metadata?["imports"] {
            let line = metadata?.sourceLine ?? 1
            for spec in ModuleResolver.parseImportList(raw, file: file, line: line) {
                imports.append(ImportStatementAST(
                    path: spec.name, alias: spec.alias, kind: .module, sourceLine: spec.sourceLine))
            }
        }

        // A "sectioned document" is any file whose body carries `##`/`###`
        // headings. In such documents narrative sentences routinely begin with
        // "When …" / "A …" / "An …" ("When the user wants to save a thought,
        // …"), so the flat top-level `isRule` heuristic below (which fires on
        // any leading article) stays off here — it would false-positive on
        // ordinary prose. Instead, `SkillSectionBuilder` extracts Phase-8
        // rules from *executable* sections precisely, by trialing each
        // eligible line against `RuleAnalyzer.classify` (a real rule shape:
        // `must not`/`may`/`must be … by … before`/`When …,`) rather than a
        // "starts with a/an/when" guess — so rule sugar fires everywhere
        // except explicitly non-executable sections (`(( role: reference ))`/
        // `(( inert ))`) and `#`/`>` comments; prose is opt-in, not inferred.
        // A heading-less `.meridian`/`.meri` file is unaffected (byte-for-byte
        // flat-procedure behaviour, using the heuristic below directly).
        let hasHeadings = lines.contains { ($0.headingLevel ?? 0) > 0 }

        while i < lines.count {
            let line = lines[i]
            guard line.isContent else { i += 1; continue }
            if line.headingLevel != nil { implicitRegionLines.append(line); i += 1; continue }
            let t = line.statement
            let lower = t.lowercased()

            // 2B: top-level `Definition:` lines are pulled out of the implicit
            // body so they register as checkable adjectives, not procedure steps.
            if DefinitionParser.isDefinitionLine(t, lexicon: lexicon) {
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
            if !hasHeadings,
               lower.hasPrefix(lexicon.grammar.legacyImportVocabularyPrefix)
                || lower.hasPrefix(lexicon.grammar.legacyImportPrefix) {
                throw CompilerError.diagnostics([
                    Diagnostic.structural(
                        .removedImportForm,
                        message: "body-level `import` is no longer supported",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Move the merconfig path(s) to frontmatter `vocabulary:` (comma-separated) and rulebooks to `rulebook:`.")
                ])
            }

            // Rules: starts with "A customer …", "An order …", "When …"
            // (suppressed for skill docs, where these are narrative prose).
            let startsWithParameterArticle = lexicon.findEarliestArticle(t)?
                .intro.trimmingCharacters(in: .whitespaces).isEmpty == true
            let isRule = !hasHeadings &&
                        (startsWithParameterArticle ||
                         lower.hasPrefix(lexicon.grammar.topLevelRulePrefix))
            let isWorkflow = lower.hasPrefix(lexicon.grammar.merconfig.workflowHeaderPrefix)

            if isWorkflow {
                // Fold multi-line workflow header (continuation indented deeper, terminator ":")
                let (headerText, headerEnd) = HeaderFolder.collect(lines, at: i)
                var j = headerEnd
                guard headerText.hasSuffix(":") else {
                    // A top-level `to …` line that doesn't terminate with ':' is a
                    // malformed workflow header in a plain `.meridian` file —
                    // previously skipped silently, now surfaced. In a sectioned
                    // skill doc (hasHeadings) such a line is ordinary prose
                    // ("To keep things tidy, …"), so it stays a lenient skip.
                    // Engine-less callers also keep the lenient skip.
                    if let diagnostics, !hasHeadings {
                        diagnostics.report(Diagnostic.structural(
                            .malformedWorkflowHeader,
                            message: "workflow header must end with ':'",
                            range: SourceRange(file: file, line: line.number, column: 1),
                            help: "End the 'to …' workflow header with a colon and indent its body beneath it, e.g. `To do the thing:`."))
                    }
                    i += 1; continue
                }
                // B3 / SkillMD-D17: Detect prose-mode annotations before the colon.
                // (See `.ai/brainstorm-done/skill_md_expressiveness_d1_d28.md`.)
                var rawPatternText = String(headerText.dropFirst(lexicon.grammar.merconfig.workflowHeaderPrefix.count).dropLast(1))
                    .trimmingCharacters(in: .whitespaces)
                let discretionSuffix = ", " + lexicon.grammar.discretionMarker
                var allowsDiscretion = rawPatternText.lowercased().hasSuffix(discretionSuffix)
                if allowsDiscretion {
                    rawPatternText = String(rawPatternText.dropLast(discretionSuffix.count))
                        .trimmingCharacters(in: .whitespaces)
                }
                var autonomy: AutonomyConfigAST?
                if let autonomyRange = rawPatternText.range(of: ", " + lexicon.grammar.autonomyMarker, options: [.caseInsensitive]) {
                    let options = String(rawPatternText[autonomyRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    rawPatternText = String(rawPatternText[..<autonomyRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    allowsDiscretion = true
                    let exprParser = ExpressionParser(symbols: symbols, trace: trace, lexicon: lexicon)
                    autonomy = AutonomyConfigAST.parse(options, parseExpression: exprParser.parse)
                }
                let pattern = PhrasePatternParser(trace: trace, lexicon: lexicon).parse(rawPatternText)

                var bodyLines: [SourceLine] = []
                while j < lines.count {
                    let l = lines[j]
                    if l.isEmpty || l.isComment { j += 1; continue }
                    if l.indent > line.indent { bodyLines.append(l); j += 1 }
                    else { break }
                }
                let body = try makeStatementParser().parseBlock(bodyLines, sourceFile: file)
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
            // Sectioned rules join any flat top-level rules already collected
            // above (the two paths are mutually exclusive per file — a
            // sectioned document's `isRule` gate stays off — but both feed the
            // same `MeridianFile.rules` carrier so `ASTToIR` classifies and
            // injects them identically regardless of source shape).
            rules.append(contentsOf: built.rules)
            let implicitName = implicit.pattern.displayText.lowercased()
            if workflows.contains(where: { $0.pattern.displayText.lowercased() == implicitName }) {
                throw CompilerError.diagnostics([
                    Diagnostic.error(
                        .ambiguousEntryWorkflow,
                        message: "ambiguous entry workflow: frontmatter `name` matches an explicit workflow while top-level statements are also present",
                        range: SourceRange(file: file, line: implicit.sourceLine, column: 1),
                        help: "Remove the duplicate explicit workflow or drop the implicit top-level body.")
                ])
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
        /// Phase-8 rules mined from executable sections (empty for a
        /// heading-less file, where the flat top-level `isRule` check already
        /// extracted rules before `buildImplicitWorkflow` ever runs).
        let rules: [RuleAST]
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
        var sectionRules: [RuleAST] = []
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
            sectionRules = result.rules
        } else {
            effectiveBody = bodyLines
        }

        let body = try makeStatementParser().parseBlock(effectiveBody, sourceFile: file)
        let workflow = WorkflowAST(
            pattern: PhrasePattern(segments: segments),
            body: body,
            sourceLine: bodyLines.first?.number ?? metadata?.sourceLine ?? 1,
            sourceFile: file
        )
        return BuiltImplicit(workflow: workflow, sections: sections,
                             dispatchPhrases: dispatchPhrases,
                             negativeDispatchPhrases: negativeDispatchPhrases,
                             toolsUsed: toolsUsed,
                             rules: sectionRules)
    }

    private func frontmatterParameters(_ raw: String?, sourceLine: Int, file: String) throws -> [PhraseParameterAST] {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let tokens = raw
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return try tokens.map { kind in
            guard let resolved = symbols.resolveKindName(kind) else {
                let candidates = Array(symbols.kinds.values.map(\.name)).sorted()
                throw CompilerError.diagnostics([
                    Diagnostic.unresolved(
                        .unknownKind,
                        target: kind,
                        among: candidates,
                        range: SourceRange(file: file, line: sourceLine, column: 1),
                        noun: "kind",
                        help: "Declare the kind in a `.merconfig` `=== vocabulary ===` block and list the file in frontmatter `vocabulary:`.")
                ])
            }
            return PhraseParameterAST(name: camelize(resolved), kind: resolved)
        }
    }

    private func camelize(_ raw: String) -> String { IdentifierNaming.lowerCamel(raw) }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
