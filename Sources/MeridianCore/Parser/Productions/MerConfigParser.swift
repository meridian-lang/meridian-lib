import Foundation
import MeridianRuntime

// MARK: - MerConfigParser
//
// Parses .merconfig files into MerConfigFile AST nodes.
// Uses line-oriented recursive descent — no PegexBuilder for the outer structure
// since the language is indent-sensitive and natural-language-flavored.

public struct MerConfigParser {

    public let lexicon: EnglishLexicon
    /// Shared by section parsers in extension files (`+Language`, `+Trace`).
    let diagnostics: DiagnosticEngine?

    public init(lexicon: EnglishLexicon = .default,
                diagnostics: DiagnosticEngine? = nil) {
        self.lexicon = lexicon
        self.diagnostics = diagnostics
    }

    public func parse(_ source: String, file: String = "") throws -> MerConfigFile {
        let trace = ParserTrace.current
        let token = trace.push(.merconfig, "MerConfigParser.parse(\(file))")
        defer { trace.pop(token) }
        let lines = IndentTokenizer().tokenize(source, file: file)
        var vocabulary:  [VocabularyStatement] = []
        var constants:   [ConstantDeclaration] = []
        var instances:   [InstanceDeclaration] = []
        var tools:       [ToolDeclaration]     = []
        var languageSynonyms = LanguageSynonyms()
        var traceConfiguration = TraceConfigurationAST()
        var importLines: [ModuleImportLine] = []

        // Split the file into sections by === ... === headers.
        // Section content is everything between one header and the next.
        var sectionRanges: [(name: String, lines: [SourceLine])] = []
        var currentSection: String? = nil
        var currentLines: [SourceLine] = []

        for line in lines {
            if let section = sectionName(line.text) {
                if let name = currentSection {
                    sectionRanges.append((name, currentLines))
                }
                currentSection = section
                currentLines = []
            } else {
                if currentSection != nil {
                    currentLines.append(line)
                }
            }
        }
        if let name = currentSection {
            sectionRanges.append((name, currentLines))
        }

        // Pre-parse `=== tools ===` regardless of its position in the file:
        // a `To …:` phrase body in `=== vocabulary ===` lowers its `invoke
        // <tool display words>` calls to a tool-name resolution *at parse
        // time* (`parseVocabularyLines` → `StatementParser.buildInvokeExpr`),
        // so if tools were only known after vocabulary was parsed (the file's
        // natural top-to-bottom order — vocabulary conventionally precedes
        // tools), every such phrase would silently fall back to methodizing
        // the raw invocation words (`"get health"` → `getHealth`) instead of
        // matching the declared `health.get` tool, baking a wrong tool ID
        // into the AST that no later pass re-resolves. Building tools first
        // and handing a tools-only bootstrap SymbolTable into vocabulary
        // parsing fixes resolution without perturbing file order or any
        // other symbol category (kinds/relations/etc. are irrelevant to
        // `invoke` resolution and stay absent from this bootstrap table).
        for toolsRange in sectionRanges where toolsRange.name == "tools" {
            tools += try parseToolsSection(toolsRange.lines, file: file)
        }
        let toolsBootstrap = SymbolTable.build(
            from: MerConfigFile(tools: tools), sourceFile: file, lexicon: lexicon)

        for (section, body) in sectionRanges {
            trace.log(.merconfig, "section === \(section) === (\(body.filter(\.isContent).count) lines)")
            switch section {
            case "vocabulary":
                vocabulary += try parseVocabularyLines(body, file: file, toolsBootstrap: toolsBootstrap)
            case "constants":
                constants += parseConstantsSection(body)
            case "instances":
                instances += parseInstancesSection(body)
            case "tools":
                break  // pre-parsed above (`toolsBootstrap`), before vocabulary
            case "language":
                languageSynonyms = parseLanguageSection(body)
            case "trace":
                traceConfiguration = try traceConfiguration.merging(parseTraceSection(body, file: file))
            case "imports":
                importLines += parseImportsSection(body)
            default:
                let range = SourceRange(file: file, line: body.first?.number ?? 1, column: 1)
                let diag = Diagnostic.structural(
                    .unknownMerconfigSection,
                    message: "unknown merconfig section `=== \(section) ===`",
                    range: range,
                    help: "Use one of: `=== vocabulary ===`, `=== constants ===`, `=== instances ===`, `=== tools ===`, `=== language ===`, `=== trace ===`, `=== imports ===`.")
                if let diagnostics {
                    diagnostics.report(diag)
                } else {
                    throw CompilerError.diagnostics([diag])
                }
            }
        }
        trace.log(.merconfig, "parsed \(vocabulary.count) vocab, \(constants.count) constants, \(instances.count) instances, \(tools.count) tools")

        return MerConfigFile(
            vocabulary: vocabulary,
            constants: constants,
            instances: instances,
            tools: tools,
            languageSynonyms: languageSynonyms,
            traceConfiguration: traceConfiguration,
            imports: importLines
        )
    }

    private func parseImportsSection(_ lines: [SourceLine]) -> [ModuleImportLine] {
        lines.filter(\.isContent).map {
            ModuleImportLine(text: $0.statement, sourceLine: $0.number)
        }
    }

    // MARK: - Section header detection

    private func sectionName(_ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("===") && t.hasSuffix("===") else { return nil }
        // A line consisting entirely of `=` characters is a tool-title underline
        // (e.g. `=========================`) — NOT a section header. Without this
        // check the section splitter would treat the underline as opening a new
        // (unrecognised) section, dropping every tool that follows.
        if t.allSatisfy({ $0 == "=" }) { return nil }
        let inner = t.dropFirst(3).dropLast(3)
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        return inner.isEmpty ? nil : inner
    }


    private func collectPhraseBody(_ content: [SourceLine], headerIndex: Int) -> ([SourceLine], Int) {
        guard headerIndex < content.count else { return ([], headerIndex + 1) }
        let headerIndent = content[headerIndex].indent
        var body: [SourceLine] = []
        var i = headerIndex + 1
        while i < content.count {
            let line = content[i]
            if line.indent > headerIndent {
                body.append(line)
                i += 1
            } else {
                break
            }
        }
        return (body, i)
    }


    // MARK: - Constants section

    private func parseConstantsSection(_ lines: [SourceLine]) -> [ConstantDeclaration] {
        lines.filter(\.isContent).compactMap { line in
            // "The {name} is {value}."
            let t = line.statement
            guard lexicon.hasLeadingArticle(t) else { return nil }
            let rest = lexicon.stripLeadingArticle(t)
            guard let isRange = rest.range(of: lexicon.grammar.merconfig.isMarker, options: [.caseInsensitive]) else { return nil }
            let name  = String(rest[rest.startIndex ..< isRange.lowerBound])
            let value = String(rest[isRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard let lit = parseLiteral(value) else { return nil }
            return ConstantDeclaration(name: name.lowercased(), value: lit, sourceLine: line.number)
        }
    }

    // MARK: - Instances section

    private func parseInstancesSection(_ lines: [SourceLine]) -> [InstanceDeclaration] {
        var results: [InstanceDeclaration] = []
        let content = lines.filter(\.isContent)
        var i = 0
        while i < content.count {
            let line = content[i]
            let t = line.statement
            // "There is a {kind} called {name}"
            let merconfig = lexicon.grammar.merconfig
            guard t.lowercased().hasPrefix(merconfig.thereIsPrefix) else { i += 1; continue }
            // strip "there is " then the leading article (lexicon-owned)
            let rest = lexicon.stripLeadingArticle(String(t.dropFirst(merconfig.thereIsPrefix.count)))
            guard let calledRange = rest.range(of: merconfig.calledMarker, options: [.caseInsensitive]) else { i += 1; continue }
            let kind = String(rest[rest.startIndex ..< calledRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var nameAndRest = String(rest[calledRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // Inline form: "called {name} with prop1 = v1, prop2 = v2"
            var props: [(String, PropertyValueAST)] = []
            if nameAndRest.contains(merconfig.withMarker) {
                let parts = nameAndRest.components(separatedBy: merconfig.withMarker)
                nameAndRest = parts[0].trimmingCharacters(in: .whitespaces)
                props = parseInlineProperties(parts.dropFirst().joined(separator: merconfig.withMarker))
            } else if line.text.hasSuffix(":") {
                // Block form: properties on subsequent lines
                nameAndRest = String(nameAndRest.dropLast())  // remove ":"
                let (propLines, _) = collectPhraseBody(content, headerIndex: i)
                props = propLines.compactMap(parsePropertyAssignment)
                i += propLines.count
            }
            results.append(InstanceDeclaration(
                kind: kind.lowercased(), name: nameAndRest.lowercased(),
                properties: props, sourceLine: line.number
            ))
            i += 1
        }
        return results
    }

    private func parseInlineProperties(_ s: String) -> [(String, PropertyValueAST)] {
        s.components(separatedBy: ",").compactMap { part in
            parsePropertyAssignment(SourceLine(indent: 0, text: part.trimmingCharacters(in: .whitespaces), raw: part, number: 0))
        }
    }

    private func parsePropertyAssignment(_ line: SourceLine) -> (String, PropertyValueAST)? {
        let t = line.statement
        guard let eqRange = t.range(of: " = ") ?? t.range(of: "=") else { return nil }
        let key = String(t[t.startIndex ..< eqRange.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
        let val = String(t[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        if val.hasPrefix("$") {
            return (key, .envVar(String(val.dropFirst())))
        }
        if let lit = parseLiteral(val) { return (key, .literal(lit)) }
        return (key, .literal(.string(val)))
    }

    // MARK: - Literal parsing

    func parseLiteral(_ s: String) -> LiteralAST? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if (t.hasPrefix("\"") && t.hasSuffix("\"")) || (t.hasPrefix("'") && t.hasSuffix("'")) {
            return .string(String(t.dropFirst().dropLast()))
        }
        if t.hasPrefix("$"), let v = Double(t.dropFirst()) { return .money(v, currency: "USD") }
        if t == "true"  { return .boolean(true) }
        if t == "false" { return .boolean(false) }
        if let dur = lexicon.parseDuration(t) { return .duration(dur.0, dur.1) }
        if let n = Int(t) { return .integer(n) }
        if let d = Double(t) { return .double(d) }
        return nil
    }
}
