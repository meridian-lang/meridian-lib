import Foundation
import MeridianRuntime

// MARK: - Control-flow statements
//
// Conditional / unless / iteration / simultaneously / wait / recover /
// fallback chain — extracted from StatementParser for Phase 3 readability.
// Call sites in parseStatement remain on the orchestrator.

extension StatementParser {

    // MARK: - Conditional

    func parseConditional(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (ConditionalStatementAST, Int) {
        let line = lines[i]
        let t = line.statement

        var condText = t
        if condText.lowercased().hasPrefix(lexicon.grammar.statement.ifPrefix) {
            condText = String(condText.dropFirst(lexicon.grammar.statement.ifPrefix.count))
        }
        if condText.hasSuffix(",") { condText = String(condText.dropLast()) }
        var unknownPolicy: UnknownHandlingPolicyAST = .explicit
        let treatingMarker = lexicon.grammar.statement.treatingUnknownAsMarker
        if let treatingRange = condText.range(of: treatingMarker, options: [.caseInsensitive, .backwards]) {
            let suffix = String(condText[treatingRange.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()
            condText = String(condText[..<treatingRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if suffix == lexicon.grammar.statement.unknownAsTrueKeyword {
                unknownPolicy = .asTrue
            } else if suffix == lexicon.grammar.statement.unknownAsFalseKeyword {
                unknownPolicy = .asFalse
            }
        }
        let (authoredForm, condition) = parseAuthoredBranchCondition(condText, negatedForm: .ifNot)

        let parentIndent = line.indent

        // Collect then-block
        var thenLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { thenLines.append(l); j += 1 }
            else { break }
        }

        // Check for the grammar's `unknown whether` and `otherwise` branch markers.
        var unknownBlock: ASTBlock? = nil
        var elseBlock: ASTBlock? = nil
        var elseConsumed = j
        if j < lines.count && lines[j].isContent {
            let nextText = lines[j].statement.lowercased()
            let keywords = lexicon.grammar.statement
            if nextText == keywords.unknownWhetherPrefix.trimmingCharacters(in: .whitespaces)
                || nextText == keywords.unknownWhetherPrefix.trimmingCharacters(in: .whitespaces) + ","
                || nextText == keywords.unknownWhetherPrefix.trimmingCharacters(in: .whitespaces) + ":" {
                let unknownIndent = lines[j].indent
                var unknownLines: [SourceLine] = []
                var k = j + 1
                while k < lines.count {
                    let l = lines[k]
                    if l.isEmpty || l.isComment { k += 1; continue }
                    if l.indent > unknownIndent { unknownLines.append(l); k += 1 }
                    else { break }
                }
                unknownBlock = try parseBlock(unknownLines, sourceFile: sourceFile)
                elseConsumed = k
            }
        }
        if elseConsumed < lines.count && lines[elseConsumed].isContent {
            let nextText = lines[elseConsumed].statement.lowercased()
            let keywords = lexicon.grammar.statement
            if nextText == keywords.otherwiseKeyword || nextText == keywords.otherwiseCommaKeyword {
                let otherwiseIndent = lines[elseConsumed].indent
                var elseLines: [SourceLine] = []
                var k = elseConsumed + 1
                while k < lines.count {
                    let l = lines[k]
                    if l.isEmpty || l.isComment { k += 1; continue }
                    if l.indent > otherwiseIndent { elseLines.append(l); k += 1 }
                    else { break }
                }
                elseBlock = try parseBlock(elseLines, sourceFile: sourceFile)
                elseConsumed = k
            }
        }

        let thenBlock = try parseBlock(thenLines, sourceFile: sourceFile)
        let consumed = elseConsumed - i

        return (ConditionalStatementAST(
            condition: condition,
            thenBlock: thenBlock,
            unknownBlock: unknownBlock,
            elseBlock: elseBlock,
            unknownPolicy: unknownPolicy,
            authoredForm: authoredForm,
            sourceLine: line.number
        ), consumed)
    }

    func parseUnlessConditional(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (ConditionalStatementAST, Int) {
        let line = lines[i]
        let t = line.statement

        var condText = t
        if condText.lowercased().hasPrefix(lexicon.grammar.statement.unlessPrefix) {
            condText = String(condText.dropFirst(lexicon.grammar.statement.unlessPrefix.count))
        }
        if condText.hasSuffix(",") { condText = String(condText.dropLast()) }
        var unknownPolicy: UnknownHandlingPolicyAST = .explicit
        let treatingMarker = lexicon.grammar.statement.treatingUnknownAsMarker
        if let treatingRange = condText.range(of: treatingMarker, options: [.caseInsensitive, .backwards]) {
            let suffix = String(condText[treatingRange.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()
            condText = String(condText[..<treatingRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if suffix == lexicon.grammar.statement.unknownAsTrueKeyword {
                unknownPolicy = .asTrue
            } else if suffix == lexicon.grammar.statement.unknownAsFalseKeyword {
                unknownPolicy = .asFalse
            }
        }
        let (_, condition) = parseAuthoredBranchCondition(condText, negatedForm: .unlessHeader)

        let parentIndent = line.indent

        var thenLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { thenLines.append(l); j += 1 }
            else { break }
        }

        var unknownBlock: ASTBlock? = nil
        var elseBlock: ASTBlock? = nil
        var elseConsumed = j
        if j < lines.count && lines[j].isContent {
            let nextText = lines[j].statement.lowercased()
            let keywords = lexicon.grammar.statement
            if nextText == keywords.unknownWhetherPrefix.trimmingCharacters(in: .whitespaces)
                || nextText == keywords.unknownWhetherPrefix.trimmingCharacters(in: .whitespaces) + ","
                || nextText == keywords.unknownWhetherPrefix.trimmingCharacters(in: .whitespaces) + ":" {
                let unknownIndent = lines[j].indent
                var unknownLines: [SourceLine] = []
                var k = j + 1
                while k < lines.count {
                    let l = lines[k]
                    if l.isEmpty || l.isComment { k += 1; continue }
                    if l.indent > unknownIndent { unknownLines.append(l); k += 1 }
                    else { break }
                }
                unknownBlock = try parseBlock(unknownLines, sourceFile: sourceFile)
                elseConsumed = k
            }
        }
        if elseConsumed < lines.count && lines[elseConsumed].isContent {
            let nextText = lines[elseConsumed].statement.lowercased()
            let keywords = lexicon.grammar.statement
            if nextText == keywords.otherwiseKeyword || nextText == keywords.otherwiseCommaKeyword {
                let otherwiseIndent = lines[elseConsumed].indent
                var elseLines: [SourceLine] = []
                var k = elseConsumed + 1
                while k < lines.count {
                    let l = lines[k]
                    if l.isEmpty || l.isComment { k += 1; continue }
                    if l.indent > otherwiseIndent { elseLines.append(l); k += 1 }
                    else { break }
                }
                elseBlock = try parseBlock(elseLines, sourceFile: sourceFile)
                elseConsumed = k
            }
        }

        let thenBlock = try parseBlock(thenLines, sourceFile: sourceFile)
        let consumed = elseConsumed - i

        return (ConditionalStatementAST(
            condition: condition,
            thenBlock: thenBlock,
            unknownBlock: unknownBlock,
            elseBlock: elseBlock,
            unknownPolicy: unknownPolicy,
            authoredForm: .unlessHeader,
            sourceLine: line.number
        ), consumed)
    }

    /// Parse branch condition text, optionally peeling a leading `not ` for D11
    /// `if not` and always negating for `.unlessHeader` callers.
    func parseAuthoredBranchCondition(
        _ condText: String,
        negatedForm: BranchAuthoredForm
    ) -> (BranchAuthoredForm, ExpressionAST) {
        var text = condText.trimmingCharacters(in: .whitespaces)
        var authoredForm: BranchAuthoredForm = .ifPositive
        let notPrefix = lexicon.grammar.booleanConnectors.notPrefix
        if negatedForm == .ifNot,
           text.lowercased().hasPrefix(notPrefix) {
            authoredForm = .ifNot
            text = String(text.dropFirst(notPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        let positive = parseDecisionPredicate(text)
        switch negatedForm {
        case .unlessHeader:
            return (.unlessHeader, .logical(.not, [positive]))
        case .ifNot where authoredForm == .ifNot:
            return (.ifNot, .logical(.not, [positive]))
        default:
            return (authoredForm, positive)
        }
    }

    /// Guarded fence: `If <cond>, run:` (or a `guardedFenceIntroducers`
    /// synonym) followed — skipping blank/comment lines — by a fenced shell
    /// code-block. Returns nil when the header doesn't end in a guarded-fence
    /// marker, or the next content line isn't a shell fence, so the caller's
    /// existing comma-terminated `if …,` / inline-conditional checks still
    /// apply to every other `if` shape.
    func parseGuardedFence(_ lines: [SourceLine], at i: Int) throws
        -> (statement: ConditionalStatementAST, consumed: Int)? {
        let line = lines[i]
        let t = line.statement
        let lower = t.lowercased()
        guard let suffix = lexicon.guardedFenceIntroducers.first(where: { lower.hasSuffix($0) }) else { return nil }

        let condText = String(t.dropFirst(lexicon.grammar.statement.ifPrefix.count).dropLast(suffix.count))
            .trimmingCharacters(in: .whitespaces)
        guard !condText.isEmpty else { return nil }

        var j = i + 1
        while j < lines.count, lines[j].isEmpty || lines[j].isComment { j += 1 }
        guard j < lines.count, let shellStmts = shellBlockStatements(lines[j]), !shellStmts.isEmpty else { return nil }

        let condition = parseDecisionPredicate(condText)
        let thenBlock = ASTBlock(statements: shellStmts, sourceLine: lines[j].number)
        return (ConditionalStatementAST(condition: condition, thenBlock: thenBlock, sourceLine: line.number), j - i + 1)
    }

    /// Single-line branch `if <cond>, <then> [, otherwise <else>].`. The
    /// condition/then split is the first top-level comma (outside quotes) that
    /// does not introduce an Oxford `and`/`or` continuation; an optional top-level
    /// `, otherwise <else>` tail supplies the else-block. Returns nil when there is
    /// no inline body (the comma-terminated multi-line header is handled upstream).
    func parseInlineConditional(_ line: SourceLine, sourceFile: String) throws -> ConditionalStatementAST? {
        let t = line.statement
        let afterIf = String(t.dropFirst(lexicon.grammar.statement.ifPrefix.count)).trimmingCharacters(in: .whitespaces)
        guard let sep = inlineConditionSeparator(in: afterIf) else { return nil }
        let condText = String(afterIf[..<sep.lowerBound]).trimmingCharacters(in: .whitespaces)
        var bodyText = String(afterIf[sep.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !condText.isEmpty, !bodyText.isEmpty else { return nil }

        var elseBlock: ASTBlock? = nil
        if let elseRange = rangeOfMarkerOutsideQuotes(lexicon.grammar.statement.inlineOtherwiseMarker, in: bodyText) {
            let elseText = String(bodyText[elseRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            bodyText = String(bodyText[..<elseRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !elseText.isEmpty {
                let elseLine = SourceLine(indent: line.indent + 2, text: elseText, raw: line.raw, number: line.number)
                elseBlock = try parseBlock([elseLine], sourceFile: sourceFile)
            }
        }
        guard !bodyText.isEmpty else { return nil }

        let thenLine = SourceLine(indent: line.indent + 2, text: bodyText, raw: line.raw, number: line.number)
        let thenBlock = try parseBlock([thenLine], sourceFile: sourceFile)
        let (authoredForm, condition) = parseAuthoredBranchCondition(condText, negatedForm: .ifNot)
        return ConditionalStatementAST(
            condition: condition,
            thenBlock: thenBlock,
            elseBlock: elseBlock,
            authoredForm: authoredForm,
            sourceLine: line.number
        )
    }

    func parseInlineUnlessConditional(_ line: SourceLine, sourceFile: String) throws -> ConditionalStatementAST? {
        let t = line.statement
        let afterUnless = String(t.dropFirst(lexicon.grammar.statement.unlessPrefix.count)).trimmingCharacters(in: .whitespaces)
        guard let sep = inlineConditionSeparator(in: afterUnless) else { return nil }
        let condText = String(afterUnless[..<sep.lowerBound]).trimmingCharacters(in: .whitespaces)
        var bodyText = String(afterUnless[sep.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !condText.isEmpty, !bodyText.isEmpty else { return nil }

        var elseBlock: ASTBlock? = nil
        if let elseRange = rangeOfMarkerOutsideQuotes(lexicon.grammar.statement.inlineOtherwiseMarker, in: bodyText) {
            let elseText = String(bodyText[elseRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            bodyText = String(bodyText[..<elseRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !elseText.isEmpty {
                let elseLine = SourceLine(indent: line.indent + 2, text: elseText, raw: line.raw, number: line.number)
                elseBlock = try parseBlock([elseLine], sourceFile: sourceFile)
            }
        }
        guard !bodyText.isEmpty else { return nil }

        let thenLine = SourceLine(indent: line.indent + 2, text: bodyText, raw: line.raw, number: line.number)
        let thenBlock = try parseBlock([thenLine], sourceFile: sourceFile)
        let (_, condition) = parseAuthoredBranchCondition(condText, negatedForm: .unlessHeader)
        return ConditionalStatementAST(
            condition: condition,
            thenBlock: thenBlock,
            elseBlock: elseBlock,
            authoredForm: .unlessHeader,
            sourceLine: line.number
        )
    }

    /// The comma that separates an inline condition from its action: the first
    /// top-level comma outside double quotes that is not an Oxford `, and`/`, or`
    /// joiner inside the condition.
    func inlineConditionSeparator(in s: String) -> Range<String.Index>? {
        var inQuotes = false
        var idx = s.startIndex
        while idx < s.endIndex {
            let c = s[idx]
            if c == "\"" {
                inQuotes.toggle()
            } else if c == ",", !inQuotes {
                let after = String(s[s.index(after: idx)...]).drop(while: { $0 == " " }).lowercased()
                if after.hasPrefix(lexicon.grammar.iterationMarkers.cleanupAndPrefix)
                    || after.hasPrefix(lexicon.grammar.booleanConnectors.orMarker.trimmingCharacters(in: .whitespaces) + " ") {
                    idx = s.index(after: idx); continue
                }
                return idx..<s.index(after: idx)
            }
            idx = s.index(after: idx)
        }
        return nil
    }

    // MARK: - Iteration

    func parseIteration(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (IterationStatementAST, Int) {
        let line = lines[i]
        let t = line.statement
        // "for each {var} in {collection},"
        let statement = lexicon.grammar.statement
        var rest = t.lowercased().hasPrefix(statement.forEachPrefix)
            ? String(t.dropFirst(statement.forEachPrefix.count))
            : String(t.dropFirst(statement.forEveryPrefix.count))
        if rest.hasSuffix(",") { rest = String(rest.dropLast()) }
        if rest.hasSuffix(":") { rest = String(rest.dropLast()) }
        rest = rest.trimmingCharacters(in: .whitespaces)

        let variable: String
        let collection: ExpressionAST
        // Strip any 1C refinement clause (`sorted by` / `whose` / `within the
        // last` / `in the next` / `the first N`) BEFORE deciding bare-kind vs
        // explicit `in {collection}`. Otherwise a temporal `in the next N
        // <unit>` clause is swallowed by the naive ` in ` collection split and
        // the future window is silently lost.
        let (headPhrase, refinement) = try extractIterationRefinement(rest, sourceFile: sourceFile, line: line.number)
        if let inRange = headPhrase.range(of: lexicon.grammar.iterationMarkers.collectionInMarker, options: [.caseInsensitive]) {
            // Explicit collection: `for each {var} in {collection}`.
            variable   = String(headPhrase[headPhrase.startIndex ..< inRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            collection = exprParser.parse(String(headPhrase[inRange.upperBound...]))
        } else if let desc = descriptionGrammar.parse(headPhrase, allowSingularHead: true) {
            // Bare restricted block header: `for each <adjectives> <singular
            // kind> <verb clause>:` (`for each flaky service owned by the
            // user:`). Decompose it through the same `description` production
            // quantifiers/explicit collections use — a bare noun phrase like
            // this must not be swallowed whole into one opaque state-key
            // identifier, which would silently drop the adjective/verb-clause
            // restriction and iterate the *unfiltered* collection instead.
            variable   = camelize(lexicon.singularize(desc.noun.lowercased()))
            collection = .description(desc)
        } else {
            // Bare block header: `for each {kind}:` binds the singular kind and
            // iterates over its plural collection (`for each page:` → iterate
            // `pages` binding `page`).
            var noun = headPhrase
            for article in lexicon.articles where noun.lowercased().hasPrefix(article + " ") {
                noun = String(noun.dropFirst(article.count + 1)); break
            }
            let singular = lexicon.singularize(noun.trimmingCharacters(in: .whitespaces))
            variable   = camelize(singular)
            collection = .identifierRef(camelize(lexicon.pluralize(singular)))
        }

        let parentIndent = line.indent
        var bodyLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { bodyLines.append(l); j += 1 }
            else { break }
        }
        let body = try parseBlock(bodyLines, sourceFile: sourceFile)
        return (IterationStatementAST(
            mode: .forEach(variable: variable, collection: collection),
            body: body,
            sourceLine: line.number,
            refinement: refinement), j - i)
    }

    // MARK: - Simultaneously

    func parseSimultaneously(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (SimultaneouslyStatementAST, Int) {
        let line = lines[i]
        let parentIndent = line.indent
        var bodyLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { bodyLines.append(l); j += 1 }
            else { break }
        }

        let body = try parseBlock(bodyLines, sourceFile: sourceFile)
        let branches = body.statements.map { stmt in
            ASTBlock(statements: [stmt], sourceLine: stmt.sourceLine)
        }
        return (SimultaneouslyStatementAST(branches: branches, sourceLine: line.number), j - i)
    }

    // MARK: - Wait condition

    func parseWaitCondition(_ s: String) -> WaitConditionAST? {
        // "1 hour", "30 seconds", "2 days"
        if let (amount, unit) = lexicon.parseDuration(s) {
            return .duration(amount, unit)
        }
        // "for signal "name""
        if s.lowercased().hasPrefix(lexicon.grammar.waitSignalIntroducer) {
            let sig = unquote(String(s.dropFirst(lexicon.grammar.waitSignalIntroducer.count)))
            return .signal(sig)
        }
        // "for approval of {subject} from {role}" — subject clause is optional
        // sugar over the bare `for approval from {role}` form below; must be
        // checked first since it's the longer, more specific prefix.
        if s.lowercased().hasPrefix(lexicon.grammar.waitApprovalOfIntroducer) {
            let rest = String(s.dropFirst(lexicon.grammar.waitApprovalOfIntroducer.count))
            if let fromRange = rest.range(of: lexicon.grammar.waitApprovalFromMarker, options: .caseInsensitive) {
                let subjectText = String(rest[rest.startIndex..<fromRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let roleWords = String(rest[fromRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                return .approval(subject: exprParser.parse(subjectText), byRole: roleWords)
            }
        }
        // "for approval from {role}"
        if s.lowercased().hasPrefix(lexicon.grammar.waitApprovalIntroducer) {
            let roleWords = String(s.dropFirst(lexicon.grammar.waitApprovalIntroducer.count))
                .trimmingCharacters(in: .whitespaces)
            // subject is implicit (null at runtime); role is the stated words
            return .approval(subject: .literal(.string("")), byRole: roleWords)
        }
        // "for event {eventID}" or "for event {eventID} matching {predicate}"
        if s.lowercased().hasPrefix(lexicon.grammar.waitEventIntroducer) {
            var rest = String(s.dropFirst(lexicon.grammar.waitEventIntroducer.count)).trimmingCharacters(in: .whitespaces)
            var matching: ExpressionAST? = nil
            if let matchingRange = rest.range(of: lexicon.grammar.waitMatchingMarker, options: .caseInsensitive) {
                let predText = String(rest[matchingRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                matching = exprParser.parse(predText)
                rest = String(rest[rest.startIndex ..< matchingRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            return .event(rest, matching: matching)
        }
        return nil
    }

    // MARK: - Recover

    /// Parse `recover from {pattern}:` or `recover where {predicate}:`.
    ///
    /// The header must end with `:` (after stripping trailing whitespace). The
    /// handler body is all lines at a deeper indent than the `recover` line.
    ///
    /// Returns a `RecoverStatementAST` whose `attached` field is a placeholder;
    /// `parseBlock` replaces it with the actual preceding statement after this
    /// function returns.
    func parseRecover(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (RecoverStatementAST, Int) {
        let line = lines[i]
        // The header is just this single line; recover headers are always one line.
        let t = line.statement

        guard t.hasSuffix(":") else {
            let statement = lexicon.grammar.statement
            let rewrite = t.trimmingCharacters(in: .whitespaces).isEmpty
                ? "\(statement.recoverFromPrefix)any:"
                : "\(t.trimmingCharacters(in: .whitespaces)):"
            try raiseStructural(
                .unparseableStatement,
                message: "malformed `recover` header",
                range: SourceRange(file: sourceFile, line: line.number, column: 1),
                help: "Use `\(statement.recoverFromPrefix)<code>:` or `\(statement.recoverWherePrefix)<predicate>:` with a trailing colon and indented handler body. Did you mean `\(rewrite)`?")
        }
        let headerText = String(t.dropLast()).trimmingCharacters(in: .whitespaces)

        // Parse pattern
        let pattern: RecoverPatternAST
        let tl = headerText.lowercased()
        let statement = lexicon.grammar.statement
        if tl.hasPrefix(statement.recoverFromPrefix) {
            var rest = String(headerText.dropFirst(statement.recoverFromPrefix.count)).trimmingCharacters(in: .whitespaces)
            // Authors can write the name as either a bare identifier
            // (`recover from approval_denied`) or a string literal
            // (`recover from "planning.host_policy_denied"`). The quoted form
            // is the canonical shape for dotted/namespace-style names; strip
            // the surrounding quotes so the IR holds the raw name and codegen
            // re-quotes once at the call site.
            if (rest.hasPrefix("\"") && rest.hasSuffix("\"") && rest.count >= 2) ||
               (rest.hasPrefix("'") && rest.hasSuffix("'") && rest.count >= 2) {
                rest = String(rest.dropFirst().dropLast())
            }
            if rest.lowercased() == "any" {
                pattern = .any
            } else if rest.first?.isUppercase == true {
                // Capitalised → typed Swift error (e.g. TimeoutError)
                pattern = .typed(rest)
            } else {
                pattern = .named(rest)
            }
        } else {
            // "recover where {predicate}"
            let predText = String(headerText.dropFirst(statement.recoverWherePrefix.count)).trimmingCharacters(in: .whitespaces)
            pattern = .predicate(exprParser.parse(predText))
        }

        // Collect handler body lines (deeper indent than the recover header).
        let parentIndent = line.indent
        var bodyLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { bodyLines.append(l); j += 1 }
            else { break }
        }
        let handlerBlock = try parseBlock(bodyLines, sourceFile: sourceFile)
        let consumed = j - i

        let placeholder = recoverPlaceholder(sourceLine: line.number)
        return (RecoverStatementAST(pattern: pattern, handler: handlerBlock, attached: placeholder, sourceLine: line.number), consumed)
    }

    /// Fallback chain: a `fallbackChainIntroducers` lead-in (`try the
    /// following in order until one succeeds:`) followed by an
    /// ordered/bulleted list of steps. SKILL.md list items are conventionally
    /// flush with (not indented under) their lead-in line, so — matching the
    /// existing frontmatter block-sequence convention
    /// (`MeridianParser`'s `next.listMarker != nil, next.indent >= l.indent`)
    /// — a step is collected while it carries a list marker at an indent no
    /// shallower than the lead-in; the tokenizer has already stripped the
    /// marker itself from `.text`/`.statement`. Each item is parsed as a
    /// single statement, then chained via `chainRecover` so step N's
    /// `recover from any:` handler is step N+1 — nesting the existing 1-deep
    /// `recover` shape N-deep rather than inventing a new IR node. Requires
    /// at least two steps and every step to parse as a real statement;
    /// otherwise returns nil so the caller's generic phrase-invocation
    /// handling still applies.
    func parseFallbackChain(_ lines: [SourceLine], at i: Int, sourceFile: String) throws
        -> (statement: StatementAST, consumed: Int)? {
        let line = lines[i]
        let t = line.statement.trimmingCharacters(in: .whitespaces)
        guard lexicon.fallbackChainIntroducers.contains(where: { t.lowercased() == $0 }) else { return nil }

        let parentIndent = line.indent
        var stepLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            guard l.listMarker != nil, l.indent >= parentIndent else { break }
            stepLines.append(l)
            j += 1
        }
        guard stepLines.count > 1 else { return nil }

        // Route each step through the full single-line production pipeline
        // (`parseBlock`, not the lower-level `parseStatement`) so backticked
        // commands go through `parseInlineChain`'s
        // `inlineBacktickedCommand`/`embeddedBacktickedCommand` detectors —
        // the same path an equivalent top-level line would take.
        var steps: [StatementAST] = []
        for stepLine in stepLines {
            let stepBlock = try parseBlock([stepLine], sourceFile: sourceFile)
            guard stepBlock.statements.count == 1 else { return nil }
            steps.append(stepBlock.statements[0])
        }

        return (chainRecover(steps, sourceLine: line.number), j - i)
    }

    /// Builds `steps[0]` guarded by a `recover from any:` whose handler is the
    /// same chain over the remaining steps, recursively — the last step is
    /// returned bare (no handler: it is the final fallback, nothing left to
    /// try after it fails).
    func chainRecover(_ steps: [StatementAST], sourceLine: Int) -> StatementAST {
        guard steps.count > 1 else { return steps[0] }
        let handlerStatement = chainRecover(Array(steps.dropFirst()), sourceLine: sourceLine)
        return .recover(RecoverStatementAST(
            pattern: .any,
            handler: ASTBlock(statements: [handlerStatement], sourceLine: sourceLine),
            attached: steps[0],
            sourceLine: sourceLine
        ))
    }

}
