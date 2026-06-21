import Foundation
import MeridianRuntime

// MARK: - MerConfigParser
//
// Parses .merconfig files into MerConfigFile AST nodes.
// Uses line-oriented recursive descent — no PegexBuilder for the outer structure
// since the language is indent-sensitive and natural-language-flavored.

public struct MerConfigParser {

    public let trace: ParserTrace
    public let lexicon: EnglishLexicon
    private let diagnostics: DiagnosticEngine?

    public init(trace: ParserTrace = .shared, lexicon: EnglishLexicon = .default,
                diagnostics: DiagnosticEngine? = nil) {
        self.trace = trace
        self.lexicon = lexicon
        self.diagnostics = diagnostics
    }

    public func parse(_ source: String, file: String = "") throws -> MerConfigFile {
        let token = trace.push(.merconfig, "MerConfigParser.parse(\(file))")
        defer { trace.pop(token) }
        let lines = IndentTokenizer().tokenize(source, file: file, trace: trace)
        var vocabulary:  [VocabularyStatement] = []
        var constants:   [ConstantDeclaration] = []
        var instances:   [InstanceDeclaration] = []
        var tools:       [ToolDeclaration]     = []
        var languageSynonyms = LanguageSynonyms()

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

        for (section, body) in sectionRanges {
            trace.log(.merconfig, "section === \(section) === (\(body.filter(\.isContent).count) lines)")
            switch section {
            case "vocabulary":
                vocabulary += try parseVocabularyLines(body, file: file)
            case "constants":
                constants += parseConstantsSection(body)
            case "instances":
                instances += parseInstancesSection(body)
            case "tools":
                tools += try parseToolsSection(body, file: file)
            case "language":
                languageSynonyms = parseLanguageSection(body)
            default:
                let range = SourceRange(file: file, line: body.first?.number ?? 1, column: 1)
                let diag = Diagnostic.structural(
                    .unknownMerconfigSection,
                    message: "unknown merconfig section `=== \(section) ===`",
                    range: range,
                    help: "Use one of: `=== vocabulary ===`, `=== constants ===`, `=== instances ===`, `=== tools ===`, `=== language ===`.")
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
            languageSynonyms: languageSynonyms
        )
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

    // MARK: - Vocabulary section

    func parseVocabularyLines(_ lines: [SourceLine], file: String) throws -> [VocabularyStatement] {
        var results: [VocabularyStatement] = []
        var i = 0
        let content = lines.filter(\.isContent)

        while i < content.count {
            let line = content[i]
            let t = line.statement

            // "To {pattern}:" — phrase definition.
            // The header may span multiple lines, with continuations ending in
            // "," (or any non-":") and the final line ending in ":". E.g.
            //
            //     To send an email via a mailer server,
            //                   to an email address,
            //                   with a subject line,
            //                   and a message body:
            if t.lowercased().hasPrefix(lexicon.grammar.merconfig.workflowHeaderPrefix) {
                let (headerText, headerConsumed) = collectHeaderLines(content, at: i)
                if headerText.hasSuffix(":") {
                    let patternText = String(headerText.dropFirst(lexicon.grammar.merconfig.workflowHeaderPrefix.count).dropLast(1))
                        .trimmingCharacters(in: .whitespaces)
                    let pattern = PhrasePatternParser(trace: trace, lexicon: lexicon).parse(patternText)
                    // Body lines: strictly deeper indent than the header itself,
                    // starting after all header continuation lines.
                    let headerIndent = line.indent
                    var bodyLines: [SourceLine] = []
                    var k = i + headerConsumed
                    while k < content.count {
                        let l = content[k]
                        if l.indent > headerIndent { bodyLines.append(l); k += 1 }
                        else { break }
                    }
                    let body = try StatementParser(symbols: nil, trace: trace, lexicon: lexicon).parseBlock(bodyLines, file: file)
                    results.append(.phrase(PhraseDefinition(
                        pattern: pattern, body: body,
                        sourceLine: line.number, sourceFile: file
                    )))
                    i = k
                    continue
                }
            }

            // Block property syntax:
            //
            //     repository has:
            //       name which is a string.
            //       status which is one of (open, closed).
            if let block = parsePropertyBlockHeader(t, line: line.number) {
                var body: [SourceLine] = []
                var k = i + 1
                while k < content.count, content[k].indent > line.indent {
                    body.append(content[k]); k += 1
                }
                var entries: [PropertyEntry] = []
                for bodyLine in body where bodyLine.isContent {
                    let stmt = bodyLine.statement.trimmingCharacters(in: .whitespaces)
                    if stmt.isEmpty { continue }
                    if let entry = parseBlockPropertyEntry(stmt) {
                        entries.append(entry)
                    } else {
                        try reportBlockPropertyDiagnostic(
                            message: "unrecognized property line in `\(block.kind) has properties:` block: \"\(stmt)\"",
                            range: SourceRange(file: file, line: bodyLine.number, column: 1),
                            help: "Use `name which is a string.`, `name which is one of (a, b).`, or `name: type`.")
                    }
                }
                if !entries.isEmpty {
                    results.append(.property(PropertyDeclaration(
                        kind: block.kind,
                        properties: entries,
                        sourceLine: block.line
                    )))
                    i = k
                    continue
                }
            }

            // 2B: "Definition: a {kind} is {adjective} if {condition}."
            if DefinitionParser.isDefinitionLine(t, lexicon: lexicon) {
                if let def = DefinitionParser(lexicon: lexicon, symbols: nil, trace: trace)
                    .parse(t, line: line.number) {
                    results.append(.definition(def))
                }
                i += 1; continue
            }

            // 3B: "The verb to {base} (…) means the {relation} relation."
            if t.lowercased().hasPrefix(lexicon.grammar.merconfig.verbDeclPrefix) {
                if let v = parseVerb(t, line: line.number) { results.append(.verb(v)) }
                i += 1; continue
            }

            // 3A: "{Relation} is read from the {kind}'s {prop}." / "… via the {tool} tool."
            if t.lowercased().contains(lexicon.grammar.merconfig.isReadMarker) {
                if let backing = parseRelationBacking(t, line: line.number) {
                    results.append(.relationBacking(backing)); i += 1; continue
                }
            }

            // "A {name} is a kind of {parent}."
            if let kind = parseKindDecl(t, line: line.number) {
                results.append(.kind(kind)); i += 1; continue
            }

            // "A {kind} can be {case} or {case}[, called the {property}]."
            if let prop = parseCanBeDecl(t, line: line.number) {
                results.append(.property(prop)); i += 1; continue
            }

            // "A {kind} is usually {case}."
            if let prop = parseUsuallyDecl(t, line: line.number) {
                results.append(.property(prop)); i += 1; continue
            }

            // "A {kind} has {properties}."
            if let prop = parsePropertyDecl(t, line: line.number) {
                results.append(.property(prop)); i += 1; continue
            }

            // "The inverse of {x} is {y}."
            if t.lowercased().hasPrefix(lexicon.grammar.merconfig.inversePrefix) {
                if let inv = parseInverse(t, line: line.number) {
                    results.append(.inverse(inv))
                }
                i += 1; continue
            }

            // "{verb} relates one {kind} to {cardinality} {kind}."
            if let rel = parseRelation(t, line: line.number) {
                results.append(.relation(rel)); i += 1; continue
            }

            throw CompilerError.diagnostics([
                Diagnostic.structural(
                    .vocabularyDeclarationUnrecognized,
                    message: "unrecognized vocabulary declaration: \"\(t)\"",
                    range: SourceRange(file: file, line: line.number, column: 1),
                    help: "Use a known vocabulary form such as `A page is a kind of thing.`, `A page has a text called the summary.`, `A page can be archived or live.`, `Definition: ...`, a relation, a verb, or a `To ...:` phrase.")
            ])
        }
        return results
    }

    private func parsePropertyBlockHeader(_ t: String, line: Int) -> (kind: String, line: Int)? {
        let lower = t.lowercased()
        let suffix: String
        if lower.hasSuffix(lexicon.grammar.merconfig.propertiesBlockSuffix) {
            suffix = lexicon.grammar.merconfig.propertiesBlockSuffix
        } else if lower.hasSuffix(lexicon.grammar.merconfig.hasBlockSuffix) {
            suffix = lexicon.grammar.merconfig.hasBlockSuffix
        } else {
            return nil
        }
        let kind = String(t.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
        return kind.isEmpty ? nil : (kind, line)
    }

    private func parseBlockPropertyEntry(_ t: String) -> PropertyEntry? {
        let lower = t.lowercased()
        if let colon = t.firstIndex(of: ":") {
            let name = extractPropName(String(t[t.startIndex..<colon]), before: nil)
            let type = stripTypeArticle(String(t[t.index(after: colon)...]))
            return PropertyEntry(name: name, type: .explicit(type))
        }
        if lower.contains(" " + lexicon.grammar.merconfig.whichIsOneOfMarker) {
            let name = extractPropName(t, before: lexicon.grammar.merconfig.whichIsOneOfMarker)
            let enumPart = t.components(separatedBy: "(").dropFirst().first?
                .components(separatedBy: ")").first ?? ""
            let values = enumPart.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            return values.isEmpty ? nil : PropertyEntry(name: name, type: .enumeration(cases: values, defaultCase: nil))
        }
        if let range = t.range(of: lexicon.grammar.merconfig.whichIsMarker, options: [.caseInsensitive]) {
            let name = extractPropName(String(t[t.startIndex..<range.lowerBound]), before: nil)
            let type = stripTypeArticle(String(t[range.upperBound...]))
            return PropertyEntry(name: name, type: .explicit(type))
        }
        let name = extractPropName(t, before: nil)
        return name.isEmpty ? nil : PropertyEntry(name: name, type: .defaulted)
    }

    /// Fold a multi-line phrase/workflow header into a single string.
    /// Returns the joined text plus the number of lines consumed (>= 1).
    /// Continuation lines have indent strictly greater than the header.
    private func collectHeaderLines(_ content: [SourceLine], at i: Int) -> (text: String, consumed: Int) {
        let (text, next) = HeaderFolder.collect(content, at: i)
        return (text, next - i)
    }

    // Collect the body lines of a phrase/workflow definition.
    // These are the lines AFTER the header with strictly greater indent.
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

    // MARK: - Kind declaration

    private func parseKindDecl(_ t: String, line: Int) -> KindDeclaration? {
        // "A/An {name} is a kind of {parent}."
        let lower = t.lowercased()
        let merconfig = lexicon.grammar.merconfig
        if lower.hasPrefix(merconfig.kindPrefix),
           let range = t.range(of: merconfig.isMarker, options: [.caseInsensitive]) {
            let rawName = String(t[t.index(t.startIndex, offsetBy: merconfig.kindPrefix.count)..<range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let rawParent = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            let parent = lexicon.stripLeadingArticle(rawParent)
                .trimmingCharacters(in: .whitespaces)
            guard !rawName.isEmpty, !parent.isEmpty else { return nil }
            return KindDeclaration(name: rawName.lowercased(), parent: parent.lowercased(), sourceLine: line)
        }
        guard lower.contains(merconfig.kindOfMarker) else { return nil }
        // The leading indefinite article is part of the declaration skeleton;
        // the strip itself defers to the lexicon (no duplicated a/an spelling).
        let rest = lexicon.hasLeadingArticle(lower)
            ? lexicon.stripLeadingArticle(t)
            : t
        guard let range = rest.range(of: merconfig.kindOfMarker, options: [.caseInsensitive]) else { return nil }
        let name = String(rest[rest.startIndex ..< range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let parent = String(rest[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        return KindDeclaration(name: name, parent: parent, sourceLine: line)
    }

    // MARK: - Property declaration

    private func parsePropertyDecl(_ t: String, line: Int) -> PropertyDeclaration? {
        let lower = t.lowercased()
        let merconfig = lexicon.grammar.merconfig
        guard let hasRange = t.range(of: merconfig.hasMarker, options: [.caseInsensitive]) else { return nil }
        let rest = lexicon.hasLeadingArticle(lower)
            ? lexicon.stripLeadingArticle(t)
            : t
        guard let range = rest.range(of: merconfig.hasMarker, options: [.caseInsensitive]) else { return nil }
        let kindName = String(rest[rest.startIndex ..< range.lowerBound])
        let propText = String(rest[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        _ = hasRange

        let props = parsePropertyList(propText)
        guard !props.isEmpty else { return nil }
        return PropertyDeclaration(kind: kindName, properties: props, sourceLine: line)
    }

    private func parsePropertyList(_ t: String) -> [PropertyEntry] {
        // Handle "a name, an email, and a phone number" (comma list)
        // Handle "a status, which is one of (active, suspended, closed)"
        // Handle "a credit limit, which is Money"
        // Handle "a text called the summary"
        if let called = parseCalledProperty(t) {
            return [called]
        }
        if t.lowercased().contains(lexicon.grammar.merconfig.whichIsOneOfMarker) {
            let name = extractPropName(t, before: lexicon.grammar.merconfig.whichIsOneOfMarker)
            let enumPart = t.components(separatedBy: "(").dropFirst().first?
                            .components(separatedBy: ")").first ?? ""
            let values = enumPart.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            return [PropertyEntry(name: name, type: .enumeration(cases: values, defaultCase: nil))]
        }
        if t.lowercased().contains(lexicon.grammar.merconfig.commaWhichIsMarker) {
            let parts = t.components(separatedBy: lexicon.grammar.merconfig.commaWhichIsMarker)
            let name = extractPropName(parts[0], before: nil)
            let type = stripTypeArticle(parts[1])
            return [PropertyEntry(name: name, type: .explicit(type))]
        }
        // Comma-and-and separated properties:
        //   "a name, an email, and a phone number"  → ["name", "email", "phone number"]
        //   "an api endpoint and an api key"         → ["api endpoint", "api key"]
        // First split on commas, then split each fragment on " and " so the
        // English connective gives the same shape as a comma list.
        let items = t.components(separatedBy: ",")
            .flatMap { $0.components(separatedBy: lexicon.grammar.merconfig.andMarker) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return items.map { item in
            let name = extractPropName(item, before: nil)
            return PropertyEntry(name: name, type: .defaulted)
        }
    }

    private func parseCalledProperty(_ t: String) -> PropertyEntry? {
        let marker = " \(lexicon.grammar.calledIntroducer) "
        guard let range = t.range(of: marker, options: [.caseInsensitive]) else { return nil }
        let typeText = String(t[t.startIndex..<range.lowerBound])
        let nameText = String(t[range.upperBound...])
        let type = stripTypeArticle(typeText)
        let name = extractPropName(nameText, before: nil)
        guard !type.isEmpty, !name.isEmpty else { return nil }
        return PropertyEntry(name: name, type: .explicit(type))
    }

    private func parseCanBeDecl(_ t: String, line: Int) -> PropertyDeclaration? {
        let lower = t.lowercased()
        guard lexicon.hasLeadingArticle(lower) else { return nil }
        let marker = lexicon.grammar.domainCanBeMarker
        guard let fullRange = t.range(of: marker, options: [.caseInsensitive]) else { return nil }
        let rest = lexicon.stripLeadingArticle(t)
        guard let range = rest.range(of: marker, options: [.caseInsensitive]) else { return nil }
        _ = fullRange
        let kindName = String(rest[rest.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        var casesText = String(rest[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        var propertyName: String?
        let calledMarker = ", \(lexicon.grammar.calledIntroducer) "
        if let calledRange = casesText.range(of: calledMarker, options: [.caseInsensitive]) {
            let nameText = String(casesText[calledRange.upperBound...])
            propertyName = extractPropName(nameText, before: nil)
            casesText = String(casesText[casesText.startIndex..<calledRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }
        let values = enumCases(from: casesText)
        guard !kindName.isEmpty, values.count >= 2 else { return nil }
        let explicitName = propertyName?.trimmingCharacters(in: .whitespaces)
        let propName = (explicitName?.isEmpty == false)
            ? explicitName!
            : "\(lexicon.singularize(kindName.lowercased())) state"
        return PropertyDeclaration(
            kind: kindName,
            properties: [PropertyEntry(name: propName, type: .enumeration(cases: values, defaultCase: nil))],
            sourceLine: line
        )
    }

    private func parseUsuallyDecl(_ t: String, line: Int) -> PropertyDeclaration? {
        let lower = t.lowercased()
        guard lexicon.hasLeadingArticle(lower) else { return nil }
        let marker = lexicon.grammar.domainUsuallyMarker
        guard lower.contains(marker) else { return nil }
        let rest = lexicon.stripLeadingArticle(t)
        guard let range = rest.range(of: marker, options: [.caseInsensitive]) else { return nil }
        let kindName = String(rest[rest.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let defaultCase = String(rest[range.upperBound...])
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: Self.propPunctuation)
            .trimmingCharacters(in: .whitespaces)
        guard !kindName.isEmpty, !defaultCase.isEmpty else { return nil }
        return PropertyDeclaration(
            kind: kindName,
            properties: [PropertyEntry(name: "", type: .enumeration(cases: [], defaultCase: defaultCase))],
            sourceLine: line
        )
    }

    private func enumCases(from raw: String) -> [String] {
        raw.replacingOccurrences(of: lexicon.grammar.booleanConnectors.oxfordOrMarker, with: ", ")
            .replacingOccurrences(of: lexicon.grammar.booleanConnectors.orMarker, with: ", ")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static let propPunctuation = CharacterSet(charactersIn: ",.;:")

    private func extractPropName(_ t: String, before marker: String?) -> String {
        var s = t.trimmingCharacters(in: .whitespaces)
        // Strip a leading article. A fragment from an Oxford list may retain a
        // leading connective ("and a phone number"); drop it (only when an
        // article follows) before deferring to the lexicon for the article.
        let lower = s.lowercased()
        for prefix in lexicon.grammar.merconfig.relationContinuationPrefixes where lower.hasPrefix(prefix) {
            s = String(s.dropFirst(lexicon.grammar.iterationMarkers.cleanupAndPrefix.count))
            break
        }
        s = lexicon.stripLeadingArticle(s)
        if let m = marker, let r = s.range(of: m, options: [.caseInsensitive]) {
            s = String(s[s.startIndex ..< r.lowerBound])
        }
        // strip trailing ", which is ..."
        if let r = s.range(of: lexicon.grammar.merconfig.commaWhichIsMarker.trimmingCharacters(in: .whitespaces)) {
            s = String(s[s.startIndex ..< r.lowerBound])
        }
        // strip trailing punctuation (e.g. comma left over when extracting before
        // a "which is …" marker, or terminal period at statement end).
        return s.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: Self.propPunctuation)
                .trimmingCharacters(in: .whitespaces)
                .lowercased()
    }

    /// Strip a leading article and any trailing terminal punctuation from a
    /// type clause like `"a Date."` → `"Date"`. Preserves the original case
    /// (`Money`, `Decimal`) so the generated Swift uses canonical type names.
    private func stripTypeArticle(_ raw: String) -> String {
        let s = lexicon.stripLeadingArticle(raw)
        return s.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: Self.propPunctuation)
                .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Relation declaration

    private func parseRelation(_ t: String, line: Int) -> RelationDeclaration? {
        // "{verb} relates one {kind} to {cardinality} {kind}."
        let merconfig = lexicon.grammar.merconfig
        guard let relRange = t.range(of: merconfig.relatesMarker, options: [.caseInsensitive]) else { return nil }
        let verb = String(t[t.startIndex ..< relRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let rest = String(t[relRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        // rest: "one {kind} to {cardinality} {kind}"
        guard let toRange = rest.range(of: merconfig.toMarker, options: [.caseInsensitive]) else { return nil }
        let leftPart  = String(rest[rest.startIndex ..< toRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let rightPart = String(rest[toRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let (lCard, lKind) = parseCardinalityKind(leftPart)
        let (rCard, rKind) = parseCardinalityKind(rightPart)
        return RelationDeclaration(verb: verb.lowercased(),
                                   leftCardinality: lCard, leftKind: lKind,
                                   rightCardinality: rCard, rightKind: rKind,
                                   sourceLine: line)
    }

    private func parseCardinalityKind(_ s: String) -> (CardinalityAST, String) {
        let lower = s.lowercased()
        // 3A: `various` is a synonym for `many`.
        let merconfig = lexicon.grammar.merconfig
        let card: CardinalityAST = (lower.hasPrefix(merconfig.manyPrefix) || lower.hasPrefix(merconfig.variousPrefix)) ? .many : .one
        var rest = s
        for prefix in merconfig.cardinalityPrefixes where lower.hasPrefix(prefix) {
            rest = String(s.dropFirst(prefix.count)); break
        }
        // A trailing plural after `various`/`many` reads naturally ("various pages").
        var kind = rest.trimmingCharacters(in: .whitespaces).lowercased()
        if card == .many { kind = lexicon.singularize(kind) }
        return (card, kind)
    }

    // MARK: - 3A. Relation evaluation backing

    /// `<Relation> is read from the <kind>'s <property>.`
    /// `<Relation> is read via the <tool> tool.` (or `… via <tool.id>.`)
    private func parseRelationBacking(_ t: String, line: Int) -> RelationBackingDeclaration? {
        let merconfig = lexicon.grammar.merconfig
        guard let readRange = t.range(of: merconfig.isReadMarker, options: [.caseInsensitive]) else { return nil }
        let relation = String(t[t.startIndex ..< readRange.lowerBound])
            .trimmingCharacters(in: .whitespaces).lowercased()
        guard !relation.isEmpty else { return nil }
        var rest = String(t[readRange.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let restLower = rest.lowercased()
        if restLower.hasPrefix(merconfig.fromPrefix) {
            let body = lexicon.stripLeadingArticle(String(rest.dropFirst(merconfig.fromPrefix.count)))
            guard let apo = body.range(of: "'s ") else { return nil }
            let kind = String(body[body.startIndex ..< apo.lowerBound])
                .trimmingCharacters(in: .whitespaces).lowercased()
            let prop = String(body[apo.upperBound...])
                .trimmingCharacters(in: .whitespaces).lowercased()
            guard !kind.isEmpty, !prop.isEmpty else { return nil }
            return RelationBackingDeclaration(
                relation: relation, backing: .property(kind: kind, path: prop), sourceLine: line)
        }
        if restLower.hasPrefix(merconfig.viaPrefix) {
            rest = String(rest.dropFirst(merconfig.viaPrefix.count)).trimmingCharacters(in: .whitespaces)
            rest = lexicon.stripLeadingArticle(rest)
            if rest.lowercased().hasSuffix(merconfig.toolSuffix) {
                rest = String(rest.dropLast(merconfig.toolSuffix.count)).trimmingCharacters(in: .whitespaces)
            }
            guard !rest.isEmpty else { return nil }
            return RelationBackingDeclaration(
                relation: relation, backing: .tool(toolID: rest), sourceLine: line)
        }
        return nil
    }

    // MARK: - 3B. Verb declaration

    /// `The verb to own (he owns, it is owned) means the ownership relation.`
    /// The conjugation table is optional; missing forms fall back to regular
    /// morphology.
    private func parseVerb(_ t: String, line: Int) -> VerbDeclaration? {
        let lower = t.lowercased()
        let merconfig = lexicon.grammar.merconfig
        guard lower.hasPrefix(merconfig.verbDeclPrefix) else { return nil }
        let rest = String(t.dropFirst(merconfig.verbDeclPrefix.count))
        guard let meansRange = rest.range(of: merconfig.meansMarker, options: [.caseInsensitive]) else { return nil }
        let head = String(rest[rest.startIndex ..< meansRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var meaning = String(rest[meansRange.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        meaning = lexicon.stripLeadingArticle(meaning)
        if meaning.lowercased().hasSuffix(merconfig.relationSuffix) {
            meaning = String(meaning.dropLast(merconfig.relationSuffix.count))
        }
        let relation = meaning.trimmingCharacters(in: .whitespaces).lowercased()
        guard !relation.isEmpty else { return nil }

        var base = head
        var third: String?
        var participle: String?
        if let open = head.range(of: "(") {
            base = String(head[head.startIndex ..< open.lowerBound]).trimmingCharacters(in: .whitespaces)
            let inside = String(head[open.upperBound...].prefix { $0 != ")" })
            for part in inside.components(separatedBy: ",") {
                let words = part.trimmingCharacters(in: .whitespaces).lowercased()
                if let r = words.range(of: merconfig.isMarker) {
                    participle = String(words[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                } else if words.hasPrefix(merconfig.isMarker.trimmingCharacters(in: .whitespaces) + " ") {
                    participle = String(words.dropFirst((merconfig.isMarker.trimmingCharacters(in: .whitespaces) + " ").count)).trimmingCharacters(in: .whitespaces)
                } else if let last = words.split(separator: " ").last {
                    third = String(last)
                }
            }
        }
        base = base.trimmingCharacters(in: .whitespaces).lowercased()
        guard !base.isEmpty else { return nil }
        return VerbDeclaration(
            base: base,
            thirdPerson: third ?? lexicon.thirdPersonSingular(base),
            pastParticiple: participle ?? lexicon.regularPastParticiple(base),
            relation: relation,
            sourceLine: line)
    }

    // MARK: - Inverse declaration

    private func parseInverse(_ t: String, line: Int) -> InverseDeclaration? {
        // "The inverse of {x} is {y}."
        let merconfig = lexicon.grammar.merconfig
        guard let ofRange = t.range(of: merconfig.inversePrefix, options: [.caseInsensitive]) else { return nil }
        let rest = String(t[ofRange.upperBound...])
        guard let isRange = rest.range(of: merconfig.isMarker, options: [.caseInsensitive]) else { return nil }
        let forward = String(rest[rest.startIndex ..< isRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let inverse  = String(rest[isRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        return InverseDeclaration(forwardGerund: forward, inverseGerund: inverse, sourceLine: line)
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

    // MARK: - Tools section

    private func parseToolsSection(_ lines: [SourceLine], file: String) throws -> [ToolDeclaration] {
        var results: [ToolDeclaration] = []
        let content = lines.filter(\.isContent)
        var i = 0
        while i < content.count {
            let line = content[i]
            // Tool title: mixed case, no leading article, no "."
            // Followed by underline (=====)
            let nextIsUnderline = i + 1 < content.count && content[i+1].text.allSatisfy({ $0 == "=" })
            guard nextIsUnderline else { i += 1; continue }
            let displayName = line.text
            i += 2  // skip title + underline

            // Skip description lines (starting with "--")
            while i < content.count && content[i].text.hasPrefix("--") { i += 1 }

            // Method signature: "~ methodName(params) : ReturnType"
            guard i < content.count, content[i].text.hasPrefix("~") else {
                try reportToolDiagnostic(
                    message: "tool \"\(displayName)\" is missing a `~ methodName(params) : ReturnType` signature line",
                    range: SourceRange(file: file, line: line.number, column: 1),
                    help: "After the title underline and optional `--` description, declare `~ chargePayment(order: Order) : Order`.")
                i += 1
                continue
            }
            let sig = content[i].text.dropFirst().trimmingCharacters(in: .whitespaces)
            if let tool = parseToolSignature(sig, displayName: displayName, sourceLine: line.number) {
                results.append(tool)
            } else {
                try reportToolDiagnostic(
                    message: "malformed tool signature for \"\(displayName)\": \"\(sig)\"",
                    range: SourceRange(file: file, line: content[i].number, column: 1),
                    help: "Use `~ methodName(param: Type, …) : ReturnType` with balanced parentheses.")
            }
            i += 1
        }
        return results
    }

    private func reportToolDiagnostic(message: String, range: SourceRange, help: String) throws {
        let diag = Diagnostic.structural(
            .vocabularyDeclarationUnrecognized,
            message: message,
            range: range,
            help: help)
        if let diagnostics {
            diagnostics.report(diag)
        } else {
            throw CompilerError.diagnostics([diag])
        }
    }

    private func reportBlockPropertyDiagnostic(message: String, range: SourceRange, help: String) throws {
        let diag = Diagnostic.structural(
            .unrecognizedBlockProperty,
            message: message,
            range: range,
            help: help)
        if let diagnostics {
            diagnostics.report(diag)
        } else {
            throw CompilerError.diagnostics([diag])
        }
    }

    private func parseToolSignature(_ sig: String, displayName: String, sourceLine: Int) -> ToolDeclaration? {
        // "methodName(param: Type, ...) : ReturnType"
        guard let parenOpen = sig.firstIndex(of: "("),
              let parenClose = sig.lastIndex(of: ")") else { return nil }
        let methodName = String(sig[sig.startIndex ..< parenOpen]).trimmingCharacters(in: .whitespaces)
        let paramsStr  = String(sig[sig.index(after: parenOpen) ..< parenClose])
        var returnType = "Any"
        if let colonRange = sig[sig.index(after: parenClose)...].range(of: ":") {
            returnType = String(sig[sig.index(after: colonRange.lowerBound)...])
                .trimmingCharacters(in: .whitespaces)
        }
        let params = paramsStr.components(separatedBy: ",").compactMap { p -> ToolParameterAST? in
            let parts = p.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
            guard parts.count == 2 else { return nil }
            return ToolParameterAST(
                name: parts[0].trimmingCharacters(in: .whitespaces),
                type: parts[1].trimmingCharacters(in: .whitespaces)
            )
        }
        return ToolDeclaration(displayName: displayName, methodName: methodName,
                               parameters: params, returnType: returnType, sourceLine: sourceLine)
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

    // MARK: - Language section

    /// Parse a `=== language ===` section body into `LanguageSynonyms`.
    ///
    /// Format:
    /// ```
    /// Comparison synonyms:
    ///   exceeds = greater than
    ///   below = less than
    /// Duration synonyms:
    ///   hr = hour
    ///   mins = minute
    /// Assertion synonyms:
    ///   verify
    ///   guarantee
    /// ```
    private func parseLanguageSection(_ lines: [SourceLine]) -> LanguageSynonyms {
        let content = lines.filter(\.isContent)
        var comparisonSynonyms: [(String, ComparisonOpAST)] = []
        var durationSynonyms: [String: TimeUnitAST] = [:]
        var assertionSynonyms: [String] = []
        var timestampProperty: String? = nil
        var emptySynonyms: [String] = []
        var filledSynonyms: [String] = []
        var pastWindowSynonyms: [String] = []
        var futureWindowSynonyms: [String] = []
        var timestampAliasSynonyms: [String] = []
        var aggregateSynonyms: [(String, AggregateKindAST)] = []
        var superlativeSynonyms: [String: SuperlativeDirection] = [:]
        var sortBySynonyms: [String] = []
        var ascendingSynonyms: [String] = []
        var descendingSynonyms: [String] = []
        var possessiveSynonyms: [String] = []
        var anaphoraSynonyms: [String] = []
        var conditionHeaderSynonyms: [String] = []
        var actionHeaderSynonyms: [String] = []
        var wildcardSynonyms: [String] = []
        var shellFenceSynonyms: [String] = []

        enum Mode {
            case none, comparison, duration, assertion
            case empty, filled, pastWindow, futureWindow, timestampAlias
            case aggregate, superlative, sortBy, ascending, descending
            case possessive, anaphora
            case conditionHeader, actionHeader, wildcard, shellFence
        }
        var mode: Mode = .none

        // Header → mode. Checked longest/most-specific first where prefixes
        // overlap (e.g. `timestamp alias` before the `timestamp =` entry).
        let headers: [(String, Mode)] = [
            ("comparison synonym", .comparison),
            ("duration synonym", .duration),
            ("assertion synonym", .assertion),
            ("empty synonym", .empty),
            ("filled synonym", .filled),
            ("past-window synonym", .pastWindow),
            ("past window synonym", .pastWindow),
            ("future-window synonym", .futureWindow),
            ("future window synonym", .futureWindow),
            ("timestamp alias", .timestampAlias),
            ("aggregate synonym", .aggregate),
            ("superlative synonym", .superlative),
            ("sort-by synonym", .sortBy),
            ("sort by synonym", .sortBy),
            ("ascending synonym", .ascending),
            ("descending synonym", .descending),
            ("possessive synonym", .possessive),
            ("anaphora synonym", .anaphora),
            ("condition-header synonym", .conditionHeader),
            ("condition header synonym", .conditionHeader),
            ("action-header synonym", .actionHeader),
            ("action header synonym", .actionHeader),
            ("wildcard synonym", .wildcard),
            ("shell-fence synonym", .shellFence),
            ("shell fence synonym", .shellFence),
        ]

        for line in content {
            let t = line.statement.trimmingCharacters(in: .whitespaces)
            let lower = t.lowercased()

            if let header = headers.first(where: { lower.hasPrefix($0.0) }) {
                mode = header.1
                continue
            }
            // `timestamp = <propertyName>` — the property a temporal iteration
            // clause resolves against (default `updatedAt`). Standalone entry.
            // (Distinct from the `Timestamp aliases:` header above.)
            if lower.hasPrefix("timestamp"), let eq = t.range(of: " = ") {
                let value = String(t[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { timestampProperty = value }
                continue
            }

            // Bare-phrase blocks (no `key = value`); captured verbatim, lower-cased.
            let marker = lower
            switch mode {
            case .assertion:     if !marker.isEmpty { assertionSynonyms.append(marker) };     continue
            case .empty:         if !marker.isEmpty { emptySynonyms.append(marker) };         continue
            case .filled:        if !marker.isEmpty { filledSynonyms.append(marker) };        continue
            case .pastWindow:    if !marker.isEmpty { pastWindowSynonyms.append(marker) };    continue
            case .futureWindow:  if !marker.isEmpty { futureWindowSynonyms.append(marker) };  continue
            case .timestampAlias:if !marker.isEmpty { timestampAliasSynonyms.append(marker) };continue
            case .sortBy:        if !marker.isEmpty { sortBySynonyms.append(marker) };        continue
            case .ascending:     if !marker.isEmpty { ascendingSynonyms.append(marker) };     continue
            case .descending:    if !marker.isEmpty { descendingSynonyms.append(marker) };    continue
            case .possessive:    if !marker.isEmpty { possessiveSynonyms.append(marker) };    continue
            case .anaphora:      if !marker.isEmpty { anaphoraSynonyms.append(marker) };      continue
            case .conditionHeader: if !marker.isEmpty { conditionHeaderSynonyms.append(marker) }; continue
            case .actionHeader:  if !marker.isEmpty { actionHeaderSynonyms.append(marker) };   continue
            case .wildcard:      if !t.isEmpty { wildcardSynonyms.append(t) };                 continue
            case .shellFence:    if !marker.isEmpty { shellFenceSynonyms.append(marker) };     continue
            case .comparison, .duration, .aggregate, .superlative, .none:
                break  // keyed `key = value` blocks handled below
            }

            // Parse "key = value" pair
            guard let eqRange = t.range(of: " = ") else { continue }
            let key   = String(t[t.startIndex ..< eqRange.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(t[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()

            switch mode {
            case .comparison:
                if let op = resolveComparisonOp(value) {
                    comparisonSynonyms.append((key, op))
                }
            case .duration:
                if let unit = lexicon.durationUnits[value] {
                    durationSynonyms[key] = unit
                }
            case .aggregate:
                switch value {
                case "count": aggregateSynonyms.append((key, .count))
                case "list":  aggregateSynonyms.append((key, .list))
                default:      break
                }
            case .superlative:
                if let dir = SuperlativeDirection(rawValue: value) {
                    superlativeSynonyms[key] = dir
                }
            default:
                break
            }
        }

        return LanguageSynonyms(comparisonSynonyms: comparisonSynonyms,
                                durationSynonyms: durationSynonyms,
                                assertionSynonyms: assertionSynonyms,
                                timestampProperty: timestampProperty,
                                emptySynonyms: emptySynonyms,
                                filledSynonyms: filledSynonyms,
                                pastWindowSynonyms: pastWindowSynonyms,
                                futureWindowSynonyms: futureWindowSynonyms,
                                timestampAliasSynonyms: timestampAliasSynonyms,
                                aggregateSynonyms: aggregateSynonyms,
                                superlativeSynonyms: superlativeSynonyms,
                                sortBySynonyms: sortBySynonyms,
                                ascendingSynonyms: ascendingSynonyms,
                                descendingSynonyms: descendingSynonyms,
                                possessiveSynonyms: possessiveSynonyms,
                                anaphoraSynonyms: anaphoraSynonyms,
                                conditionHeaderSynonyms: conditionHeaderSynonyms,
                                actionHeaderSynonyms: actionHeaderSynonyms,
                                wildcardSynonyms: wildcardSynonyms,
                                shellFenceSynonyms: shellFenceSynonyms)
    }

    /// Resolve a human-readable operator description to a `ComparisonOpAST`.
    private func resolveComparisonOp(_ value: String) -> ComparisonOpAST? {
        // Try matching the value against existing comparison markers
        for (marker, op) in lexicon.comparisonMarkers {
            let lowerMarker = marker.lowercased()
            if lowerMarker == value || stripLeadingCopula(lowerMarker) == value {
                return op
            }
        }
        // Also handle plain English names (centralized spelling table).
        return lexicon.grammar.comparisonOpSpellings[value]
    }

    private func stripLeadingCopula(_ marker: String) -> String {
        let trimmed = marker.trimmingCharacters(in: .whitespaces)
        for copula in lexicon.copulas.sorted(by: { $0.count > $1.count }) {
            let prefix = copula + " "
            if trimmed.hasPrefix(prefix) {
                return String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return trimmed
    }
}

// MARK: - PhrasePatternParser

public struct PhrasePatternParser {

    public let trace: ParserTrace
    public let lexicon: EnglishLexicon

    public init(trace: ParserTrace = .shared, lexicon: EnglishLexicon = .default) {
        self.trace = trace
        self.lexicon = lexicon
    }

    /// Parse "validate an order" or "put an order on hold with a reason"
    /// into a PhrasePattern with literal and parameter segments.
    public func parse(_ text: String) -> PhrasePattern {
        let token = trace.push(.phraseParse, "PhrasePattern.parse: \"\(text)\"")
        defer { trace.pop(token) }

        var segments: [PatternSegment] = []
        var current = text.trimmingCharacters(in: .whitespaces)

        while !current.isEmpty {
            trace.log(.phraseParse, "loop  current=\"\(current)\"")
            // Look for parameter intro: "a {kind}", "an {kind}"
            if let (intro, rest, param) = tryParseParam(current) {
                if !intro.isEmpty {
                    trace.log(.phraseParse, "  → literal[\(intro.trimmingCharacters(in: .whitespaces))]")
                    segments.append(.literal(intro.trimmingCharacters(in: .whitespaces)))
                }
                trace.log(.phraseParse, "  → param(name=\(param.name), kind=\(param.kind))")
                segments.append(.parameter(param))
                current = rest.trimmingCharacters(in: .whitespaces)
            } else {
                trace.log(.phraseParse, "  → literal[\(current.trimmingCharacters(in: .whitespaces))] (tail)")
                segments.append(.literal(current.trimmingCharacters(in: .whitespaces)))
                current = ""
            }
        }
        let result = PhrasePattern(segments: segments.filter {
            if case .literal(let s) = $0 { return !s.isEmpty }
            return true
        })
        trace.log(.phraseParse, "= \(result.segments.map(describe).joined(separator: " · "))")
        return result
    }

    private func describe(_ s: PatternSegment) -> String {
        switch s {
        case .literal(let l):   return "L[\(l)]"
        case .parameter(let p): return "P(\(p.name):\(p.kind))"
        }
    }

    private func tryParseParam(_ s: String) -> (String, String, PhraseParameterAST)? {
        // Find the EARLIEST occurrence of an article-delimited parameter slot.
        // Picking the earliest is critical: in "of a customer for an amount" the
        // first parameter slot starts at "a customer", not "an amount".
        guard let (intro, afterArticle) = lexicon.findEarliestArticle(s) else {
            trace.log(.phraseParse, "tryParseParam(\"\(s)\") → no article")
            return nil
        }
        trace.log(.phraseParse, "tryParseParam: intro=\"\(intro)\" afterArticle=\"\(afterArticle)\"")

        // Extract kind name: chain consecutive nouns; stop at verbs/participles
        // or preposition connectors. No word-count cap — "email address",
        // "mailer server", "subject line", "account manager" are all valid kinds.
        //
        // Stop signals:
        //   • prepositions / conjunctions ("with", "to", "for", "by", "via" …)
        //   • participles — verbs in past or gerund form ("placed", "sent",
        //     "given", "that", "whose", "which", "using", "containing" …)
        //   • copula forms ("is", "are", "has", "have", "was", "were")
        //   • another bare article ("a", "an") that starts the next parameter
        let connectors = lexicon.prepositions.union(lexicon.copulas)
            .union(lexicon.grammar.phraseParamConnectors)
        let participles = lexicon.participles

        let words = afterArticle.components(separatedBy: " ").filter { !$0.isEmpty }
        var kindWords: [String] = []
        var remaining: [String] = []
        var paramName: String? = nil

        // Punctuation (commas, semicolons) ends a kind name — even mid-string.
        // Headers like "via a mailer server, to an email address, ..." otherwise
        // produce kindName="mailer server," which leaks the comma into the
        // parameter name.
        let kindStops = CharacterSet(charactersIn: ",;:.")

        for (idx, word) in words.enumerated() {
            let w = word.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            if w == lexicon.grammar.calledIntroducer {
                paramName = words.dropFirst(idx + 1).first?
                    .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                remaining = Array(words.dropFirst(idx + 2))
                break
            }
            // Stop at prepositions, conjunctions, copula, participles, or
            // a new bare article (start of the next parameter slot)
            let isVerb = participles.contains(w)
                || lexicon.participleSuffixes.contains(where: { w.hasSuffix($0) && idx > 0 && w.count > 3 })
            if connectors.contains(w) || isVerb || lexicon.articles.contains(w) {
                remaining = Array(words.dropFirst(idx))
                break
            }
            // Strip trailing punctuation; if the word ENDS in punctuation,
            // that's also a kind-name terminator.
            let stripped = word.trimmingCharacters(in: kindStops)
            kindWords.append(stripped)
            let endsInPunct = word.unicodeScalars.last.map { kindStops.contains($0) } ?? false
            if endsInPunct {
                remaining = Array(words.dropFirst(idx + 1))
                break
            }
            if idx == words.count - 1 { remaining = [] }
        }

        let kindName = kindWords.joined(separator: " ")
        guard !kindName.isEmpty else {
            trace.log(.phraseParse, "  no kind words → reject")
            return nil
        }
        // Param name fallback: derive from the kind in camelCase
        // (`mailer server` → `mailerServer`) to keep the codegen-side
        // identifier convention consistent end-to-end.
        let name = paramName ?? camelize(kindName)
        let rest = remaining.joined(separator: " ")
        trace.log(.phraseParse, "  → kindName=\"\(kindName)\" name=\"\(name)\" rest=\"\(rest)\"")
        return (intro, rest, PhraseParameterAST(name: name, kind: kindName))
    }

    /// Lower-camelCase a multi-word identifier (`"mailer server"` →
    /// `"mailerServer"`).
    private func camelize(_ raw: String) -> String { IdentifierNaming.lowerCamel(raw) }
}
