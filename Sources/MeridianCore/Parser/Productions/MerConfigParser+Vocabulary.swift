import Foundation
import MeridianRuntime

// MARK: - Vocabulary section

extension MerConfigParser {
    func parseVocabularyLines(_ lines: [SourceLine], file: String,
                              toolsBootstrap: SymbolTable? = nil) throws -> [VocabularyStatement] {
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
                    let pattern = PhrasePatternParser(lexicon: lexicon).parse(patternText)
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
                    let body = try StatementParser(symbols: toolsBootstrap, lexicon: lexicon).parseBlock(bodyLines, sourceFile: file)
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

            // "Definition: a {kind} is {adjective} if {condition}."
            if DefinitionParser.isDefinitionLine(t, lexicon: lexicon) {
                if let def = DefinitionParser(lexicon: lexicon, symbols: nil)
                    .parse(t, line: line.number) {
                    results.append(.definition(def))
                } else {
                    try reportVocabularyDiagnostic(
                        message: "malformed definition: \"\(t)\"",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use `Definition: a <kind> is <adjective> if <condition>.`.")
                }
                i += 1; continue
            }

            // "The verb to {base} (…) means the {relation} relation."
            if t.lowercased().hasPrefix(lexicon.grammar.merconfig.verbDeclPrefix) {
                if let v = parseVerb(t, line: line.number) {
                    results.append(.verb(v))
                } else {
                    try reportVocabularyDiagnostic(
                        message: "malformed verb declaration: \"\(t)\"",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use `The verb to <base> (<third-person>, <past-participle>) means the <relation> relation.`.")
                }
                i += 1; continue
            }

            // "{Relation} is read from the {kind}'s {prop}." / "… via the {tool} tool."
            if t.lowercased().contains(lexicon.grammar.merconfig.isReadMarker) {
                if let backing = parseRelationBacking(t, line: line.number) {
                    results.append(.relationBacking(backing)); i += 1; continue
                }
            }

            // "A {name} is a kind of {parent}."
            if let kind = parseKindDecl(t, line: line.number) {
                results.append(.kind(kind)); i += 1; continue
            }

            if let key = parseKeyDecl(t, line: line.number) {
                results.append(.key(key)); i += 1; continue
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
                } else {
                    try reportVocabularyDiagnostic(
                        message: "malformed inverse declaration: \"\(t)\"",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use `The inverse of <relation> is <relation>.`.")
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

    func parsePropertyBlockHeader(_ t: String, line: Int) -> (kind: String, line: Int)? {
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

    func parseBlockPropertyEntry(_ t: String) -> PropertyEntry? {
        let lower = t.lowercased()
        if let colon = t.firstIndex(of: ":") {
            let name = extractPropName(String(t[t.startIndex..<colon]), before: nil)
            let type = stripTypeArticle(String(t[t.index(after: colon)...]))
            return PropertyEntry(name: name, type: parsePropertyType(type))
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
            return PropertyEntry(name: name, type: parsePropertyType(type))
        }
        let name = extractPropName(t, before: nil)
        return name.isEmpty ? nil : PropertyEntry(name: name, type: .defaulted)
    }

    /// Fold a multi-line phrase/workflow header into a single string.
    /// Returns the joined text plus the number of lines consumed (>= 1).
    /// Continuation lines have indent strictly greater than the header.
    func collectHeaderLines(_ content: [SourceLine], at i: Int) -> (text: String, consumed: Int) {
        let (text, next) = HeaderFolder.collect(content, at: i)
        return (text, next - i)
    }

    // Collect the body lines of a phrase/workflow definition.
    // These are the lines AFTER the header with strictly greater indent.
    // MARK: - Kind declaration

    func parseKindDecl(_ t: String, line: Int) -> KindDeclaration? {
        // "A/An {name} is a kind of {parent}."
        let lower = t.lowercased()
        let merconfig = lexicon.grammar.merconfig
        if lower.hasPrefix(merconfig.kindPrefix),
           let range = t.range(of: merconfig.isMarker, options: [.caseInsensitive]) {
            let prefixEnd = t.index(t.startIndex, offsetBy: merconfig.kindPrefix.count)
            // The `isMarker`'s own leading space can overlap the prefix's
            // trailing space on a degenerate name (`"kind is a widget"`),
            // putting `prefixEnd` past `range.lowerBound`. Treat that as "no
            // name" rather than slicing an inverted range.
            guard prefixEnd <= range.lowerBound else { return nil }
            let rawName = String(t[prefixEnd..<range.lowerBound])
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

    func parseKeyDecl(_ t: String, line: Int) -> KeyDeclaration? {
        let lower = t.lowercased().trimmingCharacters(in: .whitespaces)
        let articles = lexicon.parameterArticles.sorted(by: { $0.count > $1.count })
        guard let article = articles.first(where: { lower.hasPrefix($0 + " ") }) else { return nil }
        let remainder = String(t.dropFirst(article.count + 1))
        let keyedBy = lexicon.grammar.merconfig.isKeyedByMarker
        guard let range = remainder.lowercased().range(of: keyedBy) else { return nil }
        let kind = String(remainder[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        var property = String(remainder[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        property = property.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        property = lexicon.stripLeadingArticle(property)
        guard !kind.isEmpty, !property.isEmpty else { return nil }
        return KeyDeclaration(kind: kind, property: property, sourceLine: line)
    }

    // MARK: - Property declaration

    func parsePropertyDecl(_ t: String, line: Int) -> PropertyDeclaration? {
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

    func parsePropertyList(_ t: String) -> [PropertyEntry] {
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
            return [PropertyEntry(name: name, type: parsePropertyType(type))]
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
            // `a legacy id which is a String` — the marker is declared in
            // `FixedGrammar` and promised by this parser's help text. Applied
            // per item so an Oxford list (`a name and a legacy id which is a
            // String`) types only the item it belongs to.
            if item.lowercased().contains(lexicon.grammar.merconfig.whichIsMarker) {
                let parts = item.components(separatedBy: lexicon.grammar.merconfig.whichIsMarker)
                let name = extractPropName(parts[0], before: nil)
                let type = stripTypeArticle(parts[1])
                return PropertyEntry(name: name, type: parsePropertyType(type))
            }
            let name = extractPropName(item, before: nil)
            return PropertyEntry(name: name, type: .defaulted)
        }
    }

    func parseCalledProperty(_ t: String) -> PropertyEntry? {
        let marker = " \(lexicon.grammar.calledIntroducer) "
        guard let range = t.range(of: marker, options: [.caseInsensitive]) else { return nil }
        let typeText = String(t[t.startIndex..<range.lowerBound])
        let nameText = String(t[range.upperBound...])
        let type = stripTypeArticle(typeText)
        let name = extractPropName(nameText, before: nil)
        guard !type.isEmpty, !name.isEmpty else { return nil }
        return PropertyEntry(name: name, type: parsePropertyType(type))
    }

    func parseCanBeDecl(_ t: String, line: Int) -> PropertyDeclaration? {
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

    func parseUsuallyDecl(_ t: String, line: Int) -> PropertyDeclaration? {
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

    func enumCases(from raw: String) -> [String] {
        raw.replacingOccurrences(of: lexicon.grammar.booleanConnectors.oxfordOrMarker, with: ", ")
            .replacingOccurrences(of: lexicon.grammar.booleanConnectors.orMarker, with: ", ")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static let propPunctuation = CharacterSet(charactersIn: ",.;:")

    func extractPropName(_ t: String, before marker: String?) -> String {
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
    func stripTypeArticle(_ raw: String) -> String {
        let s = lexicon.stripLeadingArticle(raw)
        return s.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: Self.propPunctuation)
                .trimmingCharacters(in: .whitespaces)
    }

    /// Parse merconfig property types: bare scalars/kinds, `list of K`,
    /// `optional K`, and nested forms like `optional list of order`.
    func parsePropertyType(_ raw: String) -> PropertyTypeAST {
        let type = stripTypeArticle(raw)
        let lower = type.lowercased()
        if lower.hasPrefix("list of ") {
            let rest = String(type.dropFirst("list of ".count)).trimmingCharacters(in: .whitespaces)
            return .listOf(parsePropertyType(rest))
        }
        if lower.hasPrefix("optional ") {
            let rest = String(type.dropFirst("optional ".count)).trimmingCharacters(in: .whitespaces)
            return .optional(parsePropertyType(rest))
        }
        return .explicit(type)
    }

    // MARK: - Relation declaration

    func parseRelation(_ t: String, line: Int) -> RelationDeclaration? {
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

    func parseCardinalityKind(_ s: String) -> (CardinalityAST, String) {
        let lower = s.lowercased()
        // `various` is a synonym for `many`.
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
    func parseRelationBacking(_ t: String, line: Int) -> RelationBackingDeclaration? {
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
            // After trim + article strip, an empty tool id is unreachable with the
            // default `via ` / ` tool` markers (a bare ` tool` collapses to `tool`).
            return RelationBackingDeclaration(
                relation: relation, backing: .tool(toolID: rest), sourceLine: line)
        }
        return nil
    }

    // MARK: - 3B. Verb declaration

    /// `The verb to own (he owns, it is owned) means the ownership relation.`
    /// The conjugation table is optional; missing forms fall back to regular
    /// morphology.
    func parseVerb(_ t: String, line: Int) -> VerbDeclaration? {
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

    func parseInverse(_ t: String, line: Int) -> InverseDeclaration? {
        // "The inverse of {x} is {y}."
        let merconfig = lexicon.grammar.merconfig
        guard let ofRange = t.range(of: merconfig.inversePrefix, options: [.caseInsensitive]) else { return nil }
        let rest = String(t[ofRange.upperBound...])
        guard let isRange = rest.range(of: merconfig.isMarker, options: [.caseInsensitive]) else { return nil }
        let forward = String(rest[rest.startIndex ..< isRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let inverse  = String(rest[isRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        return InverseDeclaration(forwardGerund: forward, inverseGerund: inverse, sourceLine: line)
    }

    func reportBlockPropertyDiagnostic(message: String, range: SourceRange, help: String) throws {
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

    /// A line matched a vocabulary shape's INTRODUCER (definition/verb/inverse
    /// prefix) but the dedicated parser for that shape returned `nil` — i.e.
    /// it is malformed, not merely "not this shape". Report it explicitly
    /// instead of silently dropping the line (the old behaviour: `i += 1;
    /// continue` regardless of whether parsing actually succeeded).
    func reportVocabularyDiagnostic(message: String, range: SourceRange, help: String) throws {
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

}
