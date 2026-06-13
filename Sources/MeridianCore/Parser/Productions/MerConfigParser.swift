import Foundation

// MARK: - MerConfigParser
//
// Parses .merconfig files into MerConfigFile AST nodes.
// Uses line-oriented recursive descent — no PegexBuilder for the outer structure
// since the language is indent-sensitive and natural-language-flavored.

public struct MerConfigParser {

    public let trace: ParserTrace
    public let lexicon: EnglishLexicon

    public init(trace: ParserTrace = .shared, lexicon: EnglishLexicon = .default) {
        self.trace = trace
        self.lexicon = lexicon
    }

    public func parse(_ source: String, file: String = "") throws -> MerConfigFile {
        let token = trace.push(.merconfig, "MerConfigParser.parse(\(file))")
        defer { trace.pop(token) }
        let lines = IndentTokenizer().tokenize(source, file: file)
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
            switch section {
            case "vocabulary":
                vocabulary += try parseVocabularySection(body, file: file)
            case "constants":
                constants += parseConstantsSection(body)
            case "instances":
                instances += parseInstancesSection(body)
            case "tools":
                tools += parseToolsSection(body)
            case "language":
                languageSynonyms = parseLanguageSection(body)
            default:
                break
            }
        }

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

    private func parseVocabularySection(_ lines: [SourceLine], file: String) throws -> [VocabularyStatement] {
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
            if t.lowercased().hasPrefix("to ") {
                let (headerText, headerConsumed) = collectHeaderLines(content, at: i)
                if headerText.hasSuffix(":") {
                    let patternText = String(headerText.dropFirst(3).dropLast(1))
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

            // 2B: "Definition: a {kind} is {adjective} if {condition}."
            if DefinitionParser.isDefinitionLine(t) {
                if let def = DefinitionParser(lexicon: lexicon, symbols: nil, trace: trace)
                    .parse(t, line: line.number) {
                    results.append(.definition(def))
                }
                i += 1; continue
            }

            // 3B: "The verb to {base} (…) means the {relation} relation."
            if t.lowercased().hasPrefix("the verb to ") {
                if let v = parseVerb(t, line: line.number) { results.append(.verb(v)) }
                i += 1; continue
            }

            // 3A: "{Relation} is read from the {kind}'s {prop}." / "… via the {tool} tool."
            if t.lowercased().contains(" is read ") {
                if let backing = parseRelationBacking(t, line: line.number) {
                    results.append(.relationBacking(backing)); i += 1; continue
                }
            }

            // "A {name} is a kind of {parent}."
            if let kind = parseKindDecl(t, line: line.number) {
                results.append(.kind(kind)); i += 1; continue
            }

            // "A {kind} has {properties}."
            if let prop = parsePropertyDecl(t, line: line.number) {
                results.append(.property(prop)); i += 1; continue
            }

            // "The inverse of {x} is {y}."
            if t.lowercased().hasPrefix("the inverse of ") {
                if let inv = parseInverse(t, line: line.number) {
                    results.append(.inverse(inv))
                }
                i += 1; continue
            }

            // "{verb} relates one {kind} to {cardinality} {kind}."
            if let rel = parseRelation(t, line: line.number) {
                results.append(.relation(rel)); i += 1; continue
            }

            i += 1
        }
        return results
    }

    /// Fold a multi-line phrase/workflow header into a single string.
    /// Returns the joined text plus the number of lines consumed (>= 1).
    /// Continuation lines have indent strictly greater than the header.
    private func collectHeaderLines(_ content: [SourceLine], at i: Int) -> (text: String, consumed: Int) {
        var text = content[i].statement
        // If first line already ends with ":", we're done.
        if text.hasSuffix(":") { return (text, 1) }
        let headerIndent = content[i].indent
        var j = i + 1
        var consumed = 1
        while j < content.count {
            let l = content[j]
            if l.indent > headerIndent {
                let part = l.statement
                text += " " + part
                consumed += 1
                j += 1
                if part.hasSuffix(":") { break }
            } else {
                break
            }
        }
        return (text, consumed)
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
        guard lower.contains(" is a kind of ") else { return nil }
        guard lower.hasPrefix("a ") || lower.hasPrefix("an ") else { return nil }
        let rest = lower.hasPrefix("an ") ? String(t.dropFirst(3)) : String(t.dropFirst(2))
        guard let range = rest.lowercased().range(of: " is a kind of ") else { return nil }
        let name = String(rest[rest.startIndex ..< range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let parent = String(rest[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        return KindDeclaration(name: name, parent: parent, sourceLine: line)
    }

    // MARK: - Property declaration

    private func parsePropertyDecl(_ t: String, line: Int) -> PropertyDeclaration? {
        let lower = t.lowercased()
        guard lower.hasPrefix("a ") || lower.hasPrefix("an ") else { return nil }
        guard let hasRange = lower.range(of: " has ") else { return nil }
        let rest = lower.hasPrefix("an ") ? String(t.dropFirst(3)) : String(t.dropFirst(2))
        guard let range = rest.lowercased().range(of: " has ") else { return nil }
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
        if t.lowercased().contains("which is one of") {
            let name = extractPropName(t, before: "which is one of")
            let enumPart = t.components(separatedBy: "(").dropFirst().first?
                            .components(separatedBy: ")").first ?? ""
            let values = enumPart.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            return [PropertyEntry(name: name, type: .enumeration(values))]
        }
        if t.lowercased().contains(", which is ") {
            let parts = t.components(separatedBy: ", which is ")
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
            .flatMap { $0.components(separatedBy: " and ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return items.map { item in
            let name = extractPropName(item, before: nil)
            return PropertyEntry(name: name, type: .defaulted)
        }
    }

    private static let propPunctuation = CharacterSet(charactersIn: ",.;:")

    private func extractPropName(_ t: String, before marker: String?) -> String {
        var s = t.trimmingCharacters(in: .whitespaces)
        // strip leading article
        for article in ["a ", "an ", "the ", "and a ", "and an "] {
            if s.lowercased().hasPrefix(article) { s = String(s.dropFirst(article.count)); break }
        }
        if let m = marker, let r = s.lowercased().range(of: m) {
            s = String(s[s.startIndex ..< r.lowerBound])
        }
        // strip trailing ", which is ..."
        if let r = s.range(of: ", which") { s = String(s[s.startIndex ..< r.lowerBound]) }
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
        guard let relRange = t.lowercased().range(of: " relates ") else { return nil }
        let verb = String(t[t.startIndex ..< relRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let rest = String(t[relRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        // rest: "one {kind} to {cardinality} {kind}"
        guard let toRange = rest.lowercased().range(of: " to ") else { return nil }
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
        let card: CardinalityAST = (lower.hasPrefix("many ") || lower.hasPrefix("various ")) ? .many : .one
        var rest = s
        for prefix in ["one ", "many ", "various "] where lower.hasPrefix(prefix) {
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
        let lower = t.lowercased()
        guard let readRange = lower.range(of: " is read ") else { return nil }
        let relation = String(t[t.startIndex ..< readRange.lowerBound])
            .trimmingCharacters(in: .whitespaces).lowercased()
        guard !relation.isEmpty else { return nil }
        var rest = String(t[readRange.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let restLower = rest.lowercased()
        if restLower.hasPrefix("from ") {
            let body = lexicon.stripLeadingArticle(String(rest.dropFirst("from ".count)))
            guard let apo = body.range(of: "'s ") else { return nil }
            let kind = String(body[body.startIndex ..< apo.lowerBound])
                .trimmingCharacters(in: .whitespaces).lowercased()
            let prop = String(body[apo.upperBound...])
                .trimmingCharacters(in: .whitespaces).lowercased()
            guard !kind.isEmpty, !prop.isEmpty else { return nil }
            return RelationBackingDeclaration(
                relation: relation, backing: .property(kind: kind, path: prop), sourceLine: line)
        }
        if restLower.hasPrefix("via ") {
            rest = String(rest.dropFirst("via ".count)).trimmingCharacters(in: .whitespaces)
            for art in ["the "] where rest.lowercased().hasPrefix(art) {
                rest = String(rest.dropFirst(art.count)); break
            }
            if rest.lowercased().hasSuffix(" tool") {
                rest = String(rest.dropLast(" tool".count)).trimmingCharacters(in: .whitespaces)
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
        guard lower.hasPrefix("the verb to ") else { return nil }
        let rest = String(t.dropFirst("the verb to ".count))
        guard let meansRange = rest.lowercased().range(of: " means ") else { return nil }
        let head = String(rest[rest.startIndex ..< meansRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        var meaning = String(rest[meansRange.upperBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        for art in ["the "] where meaning.lowercased().hasPrefix(art) {
            meaning = String(meaning.dropFirst(art.count)); break
        }
        if meaning.lowercased().hasSuffix(" relation") {
            meaning = String(meaning.dropLast(" relation".count))
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
                if let r = words.range(of: " is ") {
                    participle = String(words[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                } else if words.hasPrefix("is ") {
                    participle = String(words.dropFirst(3)).trimmingCharacters(in: .whitespaces)
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
        guard let ofRange = t.lowercased().range(of: "the inverse of ") else { return nil }
        let rest = String(t[ofRange.upperBound...])
        guard let isRange = rest.lowercased().range(of: " is ") else { return nil }
        let forward = String(rest[rest.startIndex ..< isRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let inverse  = String(rest[isRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        return InverseDeclaration(forwardGerund: forward, inverseGerund: inverse, sourceLine: line)
    }

    // MARK: - Constants section

    private func parseConstantsSection(_ lines: [SourceLine]) -> [ConstantDeclaration] {
        lines.filter(\.isContent).compactMap { line in
            // "The {name} is {value}."
            let t = line.statement
            guard t.lowercased().hasPrefix("the ") else { return nil }
            let rest = String(t.dropFirst(4))
            guard let isRange = rest.lowercased().range(of: " is ") else { return nil }
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
            guard t.lowercased().hasPrefix("there is ") else { i += 1; continue }
            // strip "there is a/an "
            var rest = String(t.dropFirst("there is ".count))
            for art in ["a ", "an "] {
                if rest.lowercased().hasPrefix(art) { rest = String(rest.dropFirst(art.count)); break }
            }
            guard let calledRange = rest.lowercased().range(of: " called ") else { i += 1; continue }
            let kind = String(rest[rest.startIndex ..< calledRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var nameAndRest = String(rest[calledRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // Inline form: "called {name} with prop1 = v1, prop2 = v2"
            var props: [(String, PropertyValueAST)] = []
            if nameAndRest.contains(" with ") {
                let parts = nameAndRest.components(separatedBy: " with ")
                nameAndRest = parts[0].trimmingCharacters(in: .whitespaces)
                props = parseInlineProperties(parts.dropFirst().joined(separator: " with "))
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

    private func parseToolsSection(_ lines: [SourceLine]) -> [ToolDeclaration] {
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
            guard i < content.count, content[i].text.hasPrefix("~") else { continue }
            let sig = content[i].text.dropFirst().trimmingCharacters(in: .whitespaces)
            if let tool = parseToolSignature(sig, displayName: displayName, sourceLine: line.number) {
                results.append(tool)
            }
            i += 1
        }
        return results
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
        if let dur = parseDuration(t) { return .duration(dur.0, dur.1) }
        if let n = Int(t) { return .integer(n) }
        if let d = Double(t) { return .double(d) }
        return nil
    }

    private func parseDuration(_ s: String) -> (Double, TimeUnitAST)? {
        lexicon.parseDuration(s)
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

        enum Mode { case none, comparison, duration, assertion }
        var mode: Mode = .none

        for line in content {
            let t = line.statement.trimmingCharacters(in: .whitespaces)
            let lower = t.lowercased()

            if lower.hasPrefix("comparison synonym") {
                mode = .comparison
                continue
            }
            if lower.hasPrefix("duration synonym") {
                mode = .duration
                continue
            }
            if lower.hasPrefix("assertion synonym") {
                mode = .assertion
                continue
            }
            // `timestamp = <propertyName>` — the property a temporal iteration
            // clause resolves against (default `updatedAt`). Standalone entry.
            if lower.hasPrefix("timestamp"), let eq = t.range(of: " = ") {
                let value = String(t[eq.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { timestampProperty = value }
                continue
            }

            // Assertion synonyms are bare leading keywords (no `key = value`),
            // e.g. `verify` or `guarantee that`. Captured verbatim, lower-cased.
            if mode == .assertion {
                let marker = lower.trimmingCharacters(in: .whitespaces)
                if !marker.isEmpty { assertionSynonyms.append(marker) }
                continue
            }

            // Parse "key = value" pair
            guard let eqRange = t.range(of: " = ") else { continue }
            let key   = String(t[t.startIndex ..< eqRange.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(t[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()

            switch mode {
            case .comparison:
                // Match value against known comparison operator names
                if let op = resolveComparisonOp(value) {
                    comparisonSynonyms.append((key, op))
                }
            case .duration:
                // Match value against known duration unit names
                if let unit = lexicon.durationUnits[value] {
                    durationSynonyms[key] = unit
                }
            case .assertion, .none:
                break
            }
        }

        return LanguageSynonyms(comparisonSynonyms: comparisonSynonyms,
                                durationSynonyms: durationSynonyms,
                                assertionSynonyms: assertionSynonyms,
                                timestampProperty: timestampProperty)
    }

    /// Resolve a human-readable operator description to a `ComparisonOpAST`.
    private func resolveComparisonOp(_ value: String) -> ComparisonOpAST? {
        // Try matching the value against existing comparison markers
        for (marker, op) in lexicon.comparisonMarkers {
            if marker.lowercased() == value
                || marker.lowercased().replacingOccurrences(of: "is ", with: "") == value {
                return op
            }
        }
        // Also handle plain English names
        switch value {
        case "greater than", "greater":    return .greaterThan
        case "less than", "less":          return .lessThan
        case "greater or equal", "greater than or equal", "greater or equal to": return .greaterOrEqual
        case "less or equal", "less than or equal", "less or equal to": return .lessOrEqual
        case "equal", "equals":            return .equal
        case "not equal", "not equals":    return .notEqual
        case "within":                     return .within
        default:                           return nil
        }
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
                // Take text until next "a "/"an " that starts a parameter
                if let range = findNextParam(current) {
                    let lit = String(current[current.startIndex ..< range.lowerBound]).trimmingCharacters(in: .whitespaces)
                    trace.log(.phraseParse, "  → literal[\(lit)] (advanced)")
                    segments.append(.literal(lit))
                    current = String(current[range.lowerBound...])
                } else {
                    trace.log(.phraseParse, "  → literal[\(current.trimmingCharacters(in: .whitespaces))] (tail)")
                    segments.append(.literal(current.trimmingCharacters(in: .whitespaces)))
                    current = ""
                }
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
        // Find the EARLIEST occurrence of " a " or " an " (or at start of string).
        // Picking the earliest is critical: in "of a customer for an amount" the
        // first parameter slot starts at "a customer", not "an amount".
        func findArticle(_ source: String) -> (intro: String, rest: String)? {
            let l = source.lowercased()
            for prefix in ["an ", "a "] {
                if l.hasPrefix(prefix) { return ("", String(source.dropFirst(prefix.count))) }
            }
            var best: (range: Range<String.Index>, len: Int)? = nil
            for infix in [" an ", " a "] {
                if let r = l.range(of: infix) {
                    if best == nil || r.lowerBound < best!.range.lowerBound {
                        best = (r, infix.count)
                    }
                }
            }
            guard let pick = best else { return nil }
            let intro = String(source[source.startIndex ..< pick.range.lowerBound])
            let rest  = String(source[pick.range.upperBound...])
            return (intro, rest)
        }

        guard let (intro, afterArticle) = findArticle(s) else {
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
            .union(["and", "that", "whose", "which"])
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
            if w == "called" {
                paramName = words.dropFirst(idx + 1).first?
                    .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                remaining = Array(words.dropFirst(idx + 2))
                break
            }
            // Stop at prepositions, conjunctions, copula, participles, or
            // a new bare article (start of the next parameter slot)
            let isVerb = participles.contains(w)
                || lexicon.participleSuffixes.contains(where: { w.hasSuffix($0) && idx > 0 && w.count > 3 })
            if connectors.contains(w) || isVerb || w == "a" || w == "an" {
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
    /// `"mailerServer"`). Mirrored on the codegen side via
    /// `SwiftEmitter.snakeToCamel` so phrase parameter names round-trip
    /// without conversion.
    private func camelize(_ raw: String) -> String {
        let parts = raw.lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "_" })
            .map(String.init)
        guard let head = parts.first else { return raw.lowercased() }
        let tail = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return ([head] + tail).joined()
    }

    private func findNextParam(_ s: String) -> Range<String.Index>? {
        let lower = s.lowercased()
        // Find next " a " or " an " in the middle of the text
        var best: Range<String.Index>? = nil
        for marker in [" a ", " an "] {
            if let r = lower.range(of: marker) {
                if best == nil || r.lowerBound < best!.lowerBound {
                    best = r.upperBound ..< r.upperBound
                }
            }
        }
        return nil  // no partial advance; we let tryParseParam handle it
    }
}
