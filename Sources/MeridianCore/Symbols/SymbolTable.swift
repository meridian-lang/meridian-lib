import Foundation

// MARK: - SymbolTable
//
// Populated from a parsed MerConfigFile. Used during Meridian parsing
// to resolve multi-word identifiers, instance refs, and constant refs.
// Also drives phrase resolution during lowering.

public final class SymbolTable: @unchecked Sendable {

    // MARK: - Registered symbols

    public private(set) var kinds:     [String: KindDeclaration]     = [:]
    public private(set) var properties:[String: [PropertyEntry]]     = [:]   // keyed by kind name
    public private(set) var relations: [String: RelationDeclaration] = [:]   // keyed by verb
    /// 3A: relation evaluation backings, keyed by relation name (lowercased). A
    /// relation declared without a backing sentence is a compile error
    /// (validated in `ASTToIR.validateRelationsAndVerbs`).
    public private(set) var relationBackings: [String: RelationBackingAST] = [:]
    /// 3B: declared verbs, keyed by base form (lowercased).
    public private(set) var verbs:     [String: VerbDeclaration]      = [:]
    public private(set) var constants: [String: ConstantDeclaration] = [:]
    public private(set) var instances: [String: InstanceDeclaration] = [:]
    public private(set) var tools:     [String: ToolDeclaration]     = [:]   // keyed by methodName
    public private(set) var phrases:   [PhraseDefinition]            = []

    // MARK: - 2B. Checkable adjective definitions

    /// A registered checkable adjective (`Definition: a page is stale if …`).
    public struct DefinitionRecord: Sendable {
        public let adjective: String       // normalised surface form (lowercased)
        public let kind: String            // singular kind the adjective applies to
        public let subjectVar: String      // body subject variable
        public let body: ExpressionAST
        public let functionName: String    // meridianDef_<Kind>_<adjCamel>
        public let sourceLine: Int
        public init(adjective: String, kind: String, subjectVar: String,
                    body: ExpressionAST, functionName: String, sourceLine: Int) {
            self.adjective = adjective; self.kind = kind; self.subjectVar = subjectVar
            self.body = body; self.functionName = functionName; self.sourceLine = sourceLine
        }
    }

    /// Checkable adjectives keyed by their normalised surface form. The surface
    /// form is globally unique (a collision is a hard error caught at
    /// registration in `ASTToIR.lower`).
    public private(set) var definitions: [String: DefinitionRecord] = [:]

    /// Raw `Definition:` declarations harvested from the merconfig vocabulary,
    /// pending full registration (functionName synthesis, collision + body
    /// type-checking) by `ASTToIR.lower`.
    public private(set) var pendingDefinitions: [DefinitionDeclaration] = []

    /// Register a checkable adjective. Returns the already-registered record on
    /// a benign exact re-registration; the caller (`ASTToIR.lower`) detects and
    /// reports genuine collisions before calling this.
    public func registerDefinition(_ record: DefinitionRecord) {
        definitions[record.adjective] = record
    }

    /// The definition record for a surface adjective, if any.
    public func definition(forAdjective adjective: String) -> DefinitionRecord? {
        definitions[adjective.lowercased().trimmingCharacters(in: .whitespaces)]
    }

    // MARK: - 3A/3B. Relations + verbs

    /// Which grammatical role a matched verb surface form plays.
    public enum VerbFormRole: Sendable, Equatable {
        case base, thirdPerson, pastParticiple
    }

    public func relation(named name: String) -> RelationDeclaration? {
        relations[name.lowercased().trimmingCharacters(in: .whitespaces)]
    }

    public func backing(forRelation name: String) -> RelationBackingAST? {
        relationBackings[name.lowercased().trimmingCharacters(in: .whitespaces)]
    }

    /// 3B: resolve a surface verb form to its declared verb and the conjugation
    /// that matched. Past participle ⇒ passive/object-gap reading; base/third
    /// person ⇒ active/subject reading. Verbs are scanned in a deterministic
    /// (base-sorted) order; genuine form collisions are reported at validation.
    public func resolveVerbForm(_ form: String) -> (verb: VerbDeclaration, role: VerbFormRole)? {
        let f = form.lowercased().trimmingCharacters(in: .whitespaces)
        for v in verbs.values.sorted(by: { $0.base < $1.base }) {
            if v.pastParticiple.lowercased() == f { return (v, .pastParticiple) }
            if v.thirdPerson.lowercased() == f { return (v, .thirdPerson) }
            if v.base.lowercased() == f { return (v, .base) }
        }
        return nil
    }

    /// True when `form` is any conjugated form of a declared verb.
    public func isVerbForm(_ form: String) -> Bool { resolveVerbForm(form) != nil }

    /// 3B: the declared verb surface form (base / 3rd person / participle) closest
    /// to `form` by edit distance, when reasonably close. Powers "did you mean"
    /// hints on unknown-verb errors. Returns nil when nothing is within an
    /// edit-distance budget proportional to the form length.
    public func nearestVerbForm(to form: String) -> String? {
        let candidates = verbs.values.flatMap { [$0.base, $0.thirdPerson, $0.pastParticiple] }
        return Suggester().closest(form, among: candidates)
    }

    /// A ` (did you mean "…"?)` hint for an unknown verb form, or "" when no
    /// declared form is close enough. Single source for the suggestion suffix
    /// used by both `ExpressionParser` and `ASTToIR` on unknown-verb errors.
    public func verbFormSuggestion(for form: String) -> String {
        nearestVerbForm(to: form).map { " (did you mean \"\($0)\"?)" } ?? ""
    }

    /// Declared property names for a kind (lowercased lookup).
    public func propertyNames(of kind: String) -> Set<String> {
        Set((properties[kind.lowercased()] ?? []).map { $0.name.lowercased() })
    }

    /// Lower-cased enum cases discovered across all `which is one of (…)`
    /// property declarations. Used during lowering so that bare identifiers
    /// like `invalid`, `denied`, `succeeded` resolve to a string literal
    /// instead of a stray `state.get(…)` lookup.
    public private(set) var enumCases:  Set<String>                  = []

    /// Trace sink used by `matchPhrase` / `extractArgs`. Defaults to the
    /// process-wide `ParserTrace.shared`; tests can swap in a captured trace.
    public var trace: ParserTrace = .shared

    /// English lexicon used for stop-word filtering and article stripping.
    public var lexicon: EnglishLexicon = .default

    public init(trace: ParserTrace = .shared) { self.trace = trace }

    // MARK: - Populate from MerConfigFile

    public static func build(from config: MerConfigFile,
                             sourceFile: String = "",
                             trace: ParserTrace = .shared,
                             lexicon: EnglishLexicon = .default) -> SymbolTable {
        let table = SymbolTable(trace: trace)
        table.lexicon = lexicon
        for stmt in config.vocabulary {
            switch stmt {
            case .kind(let k):
                table.kinds[k.name.lowercased()] = k
                trace.log(.symbols, "kind \(k.name)")
            case .property(let p):
                table.properties[p.kind.lowercased(), default: []].append(contentsOf: p.properties)
                trace.log(.symbols, "properties on \(p.kind): \(p.properties.map(\.name).joined(separator: ", "))")
                for entry in p.properties {
                    if case .enumeration(let cases, _) = entry.type {
                        for c in cases {
                            table.enumCases.insert(c.lowercased().trimmingCharacters(in: .whitespaces))
                        }
                    }
                }
            case .relation(let r):
                table.relations[r.verb.lowercased()] = r
                trace.log(.symbols, "relation \(r.verb)")
            case .relationBacking(let b):
                table.relationBackings[b.relation.lowercased()] = b.backing
            case .verb(let v):
                table.verbs[v.base.lowercased()] = v
                trace.log(.symbols, "verb \(v.base)")
            case .inverse:
                break  // tracked via relation in Phase 4
            case .phrase(var p):
                // attach sourceFile if not already set
                if p.sourceFile.isEmpty {
                    p = PhraseDefinition(pattern: p.pattern, body: p.body,
                                        sourceLine: p.sourceLine, sourceFile: sourceFile)
                }
                table.phrases.append(p)
                trace.log(.symbols, "phrase \(p.pattern.displayText)")
            case .definition(let d):
                table.pendingDefinitions.append(d)
                trace.log(.symbols, "definition \(d.adjective)")
            }
        }
        for c in config.constants {
            table.constants[c.name.lowercased()] = c
            trace.log(.symbols, "constant \(c.name)")
        }
        for i in config.instances {
            table.instances[i.name.lowercased()] = i
            trace.log(.symbols, "instance \(i.name)")
        }
        for t in config.tools {
            table.tools[t.methodName] = t
            trace.log(.symbols, "tool \(t.methodName)")
        }
        trace.log(.symbols, "built: \(table.kinds.count) kinds, \(table.phrases.count) phrases, \(table.tools.count) tools, \(table.relations.count) relations, \(table.verbs.count) verbs")
        return table
    }

    /// Register a workflow as a phrase stub so recursive invocations from
    /// within other workflow bodies resolve and lower to a workflow call
    /// rather than an `_unresolved` placeholder. The stub has an empty body —
    /// `ASTToIR.lowerPhraseInvocation` keys off `workflowStructName` instead.
    public func registerWorkflowPhrase(pattern: PhrasePattern,
                                       structName: String,
                                       sourceLine: Int,
                                       sourceFile: String) {
        let stub = PhraseDefinition(
            pattern: pattern,
            body: ASTBlock(statements: [], sourceLine: sourceLine),
            sourceLine: sourceLine,
            sourceFile: sourceFile,
            workflowStructName: structName
        )
        phrases.append(stub)
    }

    public func resolveKindName(_ raw: String) -> String? {
        let key = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return kinds[key]?.name
    }

    // MARK: - Phrase lookup

    /// Find the best-matching phrase definition for a raw invocation string.
    /// Requires the first significant word of the invocation to appear in the
    /// pattern's literal text, then scores by keyword overlap.
    public func matchPhrase(
        _ invocation: String,
        defaultParam: PhraseParameterAST? = nil
    ) -> (phrase: PhraseDefinition, args: [String: ExpressionAST])? {
        if let direct = matchPhraseDirect(invocation) { return direct }
        guard let defaultParam else { return nil }
        let filled = "\(invocation)\(lexicon.grammar.implicitParamFillConnector)\(defaultParam.kind)"
        trace.log(.phraseMatch, "phrase.match.implicit-fill: \"\(invocation)\" → \"\(filled)\"")
        return matchPhraseDirect(filled)
    }

    private func matchPhraseDirect(_ invocation: String) -> (phrase: PhraseDefinition, args: [String: ExpressionAST])? {
        let token = trace.push(.phraseMatch, "matchPhrase: \"\(invocation)\"")
        defer { trace.pop(token) }

        let invWords = WordStemmer.tokenize(invocation, stopwords: lexicon.toolStopwords)
        guard let firstWord = invWords.first else {
            trace.log(.phraseMatch, "no significant words")
            return nil
        }
        trace.log(.phraseMatch, "tokens=\(invWords)  firstWord=\"\(firstWord)\"")

        var best: (score: Int, phrase: PhraseDefinition)? = nil
        for phrase in phrases {
            // The first word of the invocation must appear in this phrase's literal keywords.
            // This prevents e.g. "reject… insufficient_credit" (contains "credit") from
            // accidentally matching "check the credit" (starts with "check", not "reject").
            let patternLiteralText = phrase.pattern.segments.compactMap { seg -> String? in
                if case .literal(let s) = seg { return s } else { return nil }
            }.joined(separator: " ")
            let patternFirstWords = Set(WordStemmer.tokenize(patternLiteralText, stopwords: lexicon.toolStopwords))
            guard patternFirstWords.contains(firstWord) else {
                trace.log(.phraseMatch, "  skip @L\(phrase.sourceLine) (no \"\(firstWord)\" in pattern)")
                continue
            }

            let score = phraseMatchScore(invWords, pattern: phrase.pattern)
            trace.log(.phraseMatch, "  candidate @L\(phrase.sourceLine) score=\(score) literals=\(patternFirstWords.sorted())")
            if score > (best?.score ?? -1) {
                best = (score, phrase)
            }
        }
        guard let winner = best, winner.score > 0 else {
            trace.log(.phraseMatch, "no match")
            return nil
        }
        trace.log(.phraseMatch, "winner @L\(winner.phrase.sourceLine) score=\(winner.score)")

        let args = extractArgs(invocation, pattern: winner.phrase.pattern)
        for (k, v) in args {
            trace.log(.phraseExtractArgs, "  arg[\(k)] = \(v.traceDescription(detail: .compact))")
        }
        return (winner.phrase, args)
    }

    private func phraseMatchScore(_ invWords: [String], pattern: PhrasePattern) -> Int {
        let literalWords = literalKeywords(pattern)
        let paramWords   = paramKindKeywords(pattern)
        // Literal-keyword overlap is the primary score, in doubled units so
        // param-kind hits can act as fractional tiebreakers.
        //
        // 1. `+ 2 * lit` — every invocation token that hits a pattern literal
        //    counts twice.
        // 2. `+ par` — every invocation token that hits a parameter kind/name
        //    nudges the score by 1. This breaks the `review the comment`
        //    three-way tie in favour of `to review a comment`.
        // 3. `- missing` — pattern literals NOT present in the invocation
        //    penalise specificity, one point each. Without this the parent
        //    workflow `dependency upgrade sweep pull request` would beat the
        //    inner `to upgrade a dependency` for the invocation
        //    `upgrade the dependency` because the parent's `dependency,
        //    upgrade` both hit (score 4) versus the inner's literal `upgrade`
        //    (2) plus param kind `dependency` (1) = 3. The penalty for the
        //    parent's unmatched `sweep` flips the result.
        let invSet = Set(invWords)
        let lit = invWords.filter { literalWords.contains($0) }.count
        let par = invWords.filter { paramWords.contains($0) }.count
        // Penalise unmatched pattern literals weighted heavier than literal
        // hits so a strict-superset pattern (e.g. parent workflow header
        // `dependency upgrade sweep` against invocation `upgrade the
        // dependency`) loses to a focused inner pattern (`to upgrade a
        // dependency`) even when both share more than one literal token.
        let missing = literalWords.subtracting(invSet).count
        return lit * 2 + par - 2 * missing
    }

    private func literalKeywords(_ pattern: PhrasePattern) -> Set<String> {
        var words: [String] = []
        for seg in pattern.segments {
            if case .literal(let lit) = seg {
                words += WordStemmer.tokenize(lit, stopwords: lexicon.toolStopwords)
            }
        }
        return Set(words)
    }

    private func paramKindKeywords(_ pattern: PhrasePattern) -> Set<String> {
        var words: [String] = []
        for seg in pattern.segments {
            if case .parameter(let p) = seg {
                words += WordStemmer.tokenize(p.kind, stopwords: lexicon.toolStopwords)
                words += WordStemmer.tokenize(p.name, stopwords: lexicon.toolStopwords)
            }
        }
        return Set(words)
    }

    /// Extract argument expressions by matching parameter slots in the pattern
    /// against word positions in the invocation text.
    func extractArgs(_ invocation: String, pattern: PhrasePattern) -> [String: ExpressionAST] {
        let token = trace.push(.phraseExtractArgs, "extractArgs from \"\(invocation)\"")
        defer { trace.pop(token) }

        var args: [String: ExpressionAST] = [:]
        var remaining = invocation.trimmingCharacters(in: .whitespaces)
        let exprParser = ExpressionParser(symbols: self, trace: trace, lexicon: lexicon)

        for seg in pattern.segments {
            switch seg {
            case .literal(let lit):
                trace.log(.phraseExtractArgs, "literal[\(lit)]  remaining=\"\(remaining)\"")
                let words = lit.components(separatedBy: " ").filter { !$0.isEmpty }
                for word in words {
                    if let range = remaining.range(of: word, options: [.caseInsensitive]) {
                        let consumed = String(remaining[remaining.startIndex ..< range.upperBound])
                        remaining = String(remaining[range.upperBound...])
                            .trimmingCharacters(in: .whitespaces)
                        trace.log(.phraseExtractArgs, "  ate \"\(word)\" (consumed: \"\(consumed)\") → \"\(remaining)\"")
                    } else {
                        trace.log(.phraseExtractArgs, "  literal word \"\(word)\" NOT FOUND in remaining")
                    }
                }
            case .parameter(let param):
                trace.log(.phraseExtractArgs, "param(\(param.name):\(param.kind))  remaining=\"\(remaining)\"")
                let terminators = nextLiterals(after: seg, in: pattern.segments)
                let rawArgText: String
                if let terminator = terminators.first {
                    let firstWord = terminator.lowercased().components(separatedBy: " ").first ?? ""
                    if let range = remaining.range(of: " \(firstWord)", options: [.caseInsensitive]) {
                        rawArgText = String(remaining[remaining.startIndex ..< range.lowerBound])
                        remaining = String(remaining[range.lowerBound...])
                            .trimmingCharacters(in: .whitespaces)
                    } else {
                        rawArgText = remaining
                        remaining = ""
                    }
                } else {
                    rawArgText = remaining
                    remaining = ""
                }

                // Natural-language slop tolerance: callers may include or omit the
                // pattern's article and may even repeat the kind word. Strip:
                //   1. leading article ("a"/"an"/"the")
                //   2. then a leading kind word ("reason", "order", …) when it
                //      matches `param.kind` and is followed by a value
                let argText = stripPatternSlop(rawArgText, kind: param.kind)
                if argText != rawArgText {
                    trace.log(.phraseExtractArgs, "  slop-stripped: \"\(rawArgText)\" → \"\(argText)\"")
                }
                let expr = exprParser.parse(argText)
                // Store with the original param name (camelCase per the
                // convention used everywhere else). Lowering's `subExpr` tries
                // a handful of variants when looking the value back up so
                // bodies written with spaces/snake/camel all resolve.
                args[param.name] = expr
                trace.log(.phraseExtractArgs, "  → arg[\(param.name)] = \"\(argText)\"")
            }
        }
        return args
    }

    /// Strip a leading article and optional leading kind word from a parameter's
    /// raw arg text. Lets `with reason "X"`, `with a reason "X"`, and
    /// `with the reason "X"` all extract just `"X"` for a slot whose kind is `reason`.
    private func stripPatternSlop(_ text: String, kind: String) -> String {
        var s = text.trimmingCharacters(in: .whitespaces)
        // Trailing list/sentence punctuation is never part of an argument value.
        let trailers: Set<Character> = [",", ";", "."]
        while let last = s.last, trailers.contains(last) {
            s = String(s.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        for article in lexicon.articles.sorted(by: { $0.count > $1.count }) {
            if s.lowercased().hasPrefix(article + " ") {
                s = String(s.dropFirst(article.count + 1))
                break
            }
        }
        let kindLower = kind.lowercased()
        let prefix = kindLower + " "
        if s.lowercased().hasPrefix(prefix) {
            let after = String(s.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            if !after.isEmpty { s = after }
        }
        // Strip any trailers exposed by removing the kind word (e.g. "subject line "X"," -> ""X"").
        while let last = s.last, trailers.contains(last) {
            s = String(s.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    private func nextLiterals(after seg: PatternSegment, in segments: [PatternSegment]) -> [String] {
        var found = false
        var result: [String] = []
        for s in segments {
            if found, case .literal(let lit) = s {
                result.append(lit)
            }
            if case .literal(let a) = seg, case .literal(let b) = s, a == b { found = true }
            if case .parameter(let a) = seg, case .parameter(let b) = s, a.name == b.name { found = true }
        }
        return result
    }

    // MARK: - Tool lookup

    /// Find a tool declaration by display name (case-insensitive, ignoring spacing).
    public func tool(named displayName: String) -> ToolDeclaration? {
        let key = displayName.lowercased().replacingOccurrences(of: " ", with: "")
        return tools.values.first {
            $0.displayName.lowercased().replacingOccurrences(of: " ", with: "") == key ||
            $0.methodName.lowercased() == key
        }
    }

    /// Find a tool by words in an invocation like "invoke validate order with ..."
    /// Uses token-overlap scoring: candidates are ranked by how many tokenized
    /// words they share with the invocation, penalised by extra candidate words.
    public func tool(fromWords words: String) -> ToolDeclaration? {
        let invocationTokens = Set(WordStemmer.tokenize(words, stopwords: lexicon.toolStopwords))
        guard !invocationTokens.isEmpty else { return nil }
        var best: (score: Int, penalty: Int, decl: ToolDeclaration)? = nil
        for decl in tools.values {
            let candidateTokens = Set(WordStemmer.tokenize(decl.displayName + " " + decl.methodName, stopwords: lexicon.toolStopwords))
            let overlap = invocationTokens.intersection(candidateTokens).count
            guard overlap > 0 else { continue }
            let extra = candidateTokens.subtracting(invocationTokens).count
            let score = overlap * 2 - extra
            if let b = best {
                if score > b.score || (score == b.score && decl.methodName.count < b.penalty) {
                    best = (score, decl.methodName.count, decl)
                }
            } else {
                best = (score, decl.methodName.count, decl)
            }
        }
        return best?.decl
    }
}
