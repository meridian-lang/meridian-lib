import Foundation
import MeridianRuntime

// MARK: - StatementParser
//
// Parses a flat list of SourceLines (already indent-filtered) into an ASTBlock.
// Called by both MerConfigParser (phrase bodies) and MeridianParser (workflow bodies).

public struct StatementParser {

    public let symbols: SymbolTable?
    public let trace: ParserTrace
    private let lexicon: EnglishLexicon
    /// Optional rulebook-driven desugar engine. When present, surface idioms are
    /// rewritten to canonical statements before the parser's own fallback runs.
    /// Nil for plain `.meridian`/`.merconfig` parsing (engine is a no-op anyway
    /// when the rulebook is empty).
    private let rewriteEngine: RewriteEngine?
    /// Optional batch collector. When present, `parseBlock` recovers from a
    /// thrown `CompilerError` per statement (collect + skip the line) so a file
    /// with several malformed statements reports them all at once.
    private let diagnostics: DiagnosticEngine?

    private var exprParser: ExpressionParser { ExpressionParser(symbols: symbols, trace: trace, lexicon: lexicon) }

    public init(symbols: SymbolTable?, trace: ParserTrace = .shared,
                lexicon: EnglishLexicon = .default,
                rewriteEngine: RewriteEngine? = nil,
                diagnostics: DiagnosticEngine? = nil) {
        self.symbols = symbols
        self.trace = trace
        self.lexicon = lexicon
        self.rewriteEngine = rewriteEngine
        self.diagnostics = diagnostics
    }

    public func parseBlock(_ lines: [SourceLine], file: String = "") throws -> ASTBlock {
        var stmts: [StatementAST] = []
        var content = lines.filter(\.isContent)
        var referents: [String] = []
        let anaphora = AnaphoraResolver(lexicon: lexicon)
        var i = 0
        while i < content.count {
            if content[i].headingLevel != nil {
                i += 1
                continue
            }
            // Per-statement recovery boundary: with a batch engine, a malformed
            // statement is collected and skipped so the rest of the block still
            // parses. Without one, the error propagates (first-error behaviour).
            do {
            if shouldResolveAnaphora(content[i]) {
                let resolved = try anaphora.resolve(content[i].statement, referents: referents, file: file, line: content[i].number)
                if resolved != content[i].statement {
                    content[i] = SourceLine(
                        indent: content[i].indent,
                        text: resolved,
                        raw: content[i].raw,
                        number: content[i].number,
                        listMarker: content[i].listMarker,
                        headingLevel: content[i].headingLevel
                    )
                }
            }
            // Rulebook desugar hoist: rewrite a surface idiom into its canonical
            // form *before* the command/chain detectors run, so a desugar rule
            // can normalize a surface variant into a backticked command and have
            // `parseInlineChain`/`inlineBacktickedCommand` route it to the shell
            // path. The engine is fixpoint-stable, so the per-statement desugar
            // hook downstream is a no-op second pass. No-op without a rulebook.
            if let engine = rewriteEngine, !engine.isEmpty {
                let result = engine.rewrite(content[i].statement)
                if result.changed, result.text != content[i].statement {
                    content[i] = SourceLine(
                        indent: content[i].indent,
                        text: result.text,
                        raw: content[i].raw,
                        number: content[i].number,
                        listMarker: content[i].listMarker,
                        headingLevel: content[i].headingLevel
                    )
                }
            }
            // A `!!! checklist (( … ))`-marked task list collapses to a single
            // sentinel: expand it per its mode (asserts / prose step / nothing).
            if let expanded = try checklistStatements(content[i], file: file) {
                for s in expanded {
                    appendStatement(s, to: &stmts)
                    recordReferents(from: s, into: &referents)
                }
                i += 1
                continue
            }
            // An unmarked Markdown task-list item (`- [ ] …`) is an invariant: it
            // desugars to a checkable `assert` (or a hard error when not checkable).
            if content[i].isChecklist {
                let stmt = try checklistInvariant(content[i], file: file)
                appendStatement(stmt, to: &stmts)
                recordReferents(from: stmt, into: &referents)
                i += 1
                continue
            }
            if let expanded = try parseInlineChain(content[i], file: file), !expanded.isEmpty {
                for s in expanded {
                    appendStatement(s, to: &stmts)
                    recordReferents(from: s, into: &referents)
                }
                i += 1
                continue
            }
            let (stmt, consumed) = try parseStatement(content, at: i, file: file)
            if let s = stmt {
                appendStatement(s, to: &stmts)
                recordReferents(from: s, into: &referents)
            }
            i += max(consumed, 1)
            } catch let e as CompilerError where diagnostics != nil {
                diagnostics!.collect(e)
                i += 1
            }
        }
        return ASTBlock(statements: stmts, sourceLine: content.first?.number ?? 0)
    }

    /// Desugar a task-list checklist item to an invariant assert. A checkable
    /// item becomes `make sure <cond>`; a non-checkable one is a hard error
    /// (rephrase to a comparison or move under an `(( inert ))` section).
    private func checklistInvariant(_ line: SourceLine, file: String) throws -> StatementAST {
        let classifier = ConditionClassifier(symbols: symbols, lexicon: lexicon, trace: trace)
        // Shared with Contract invariants: `every emitted <noun> <predicate>`
        // is an assert on the bound result `<noun>`.
        let text = classifier.normalizeFormatInvariant(line.statement)
        switch classifier.classify(text) {
        case .checkable:
            return .assertStmt(AssertStatementAST(
                condition: exprParser.parse(text),
                message: "Expected \(text)",
                sourceLine: line.number
            ))
        case .dispatchPhrase, .fuzzy:
            throw CompilerError.semanticError(
                message: "checklist item \"\(text)\" is not a structurally checkable predicate. Rephrase it as a comparison (e.g. `- [ ] the link count is at least 1`), route the whole list to the planner with a `!!! checklist (( ai-autonomy ))` marker above it, or move it under an `(( inert ))` section to keep it as documentation.",
                range: SourceRange(file: file, line: line.number, column: 1)
            )
        }
    }

    /// Expand a `!!! checklist (( … ))` sentinel into statements per its mode:
    ///   • invariant   → one `assert` per item (each must be checkable).
    ///   • inert       → nothing (documentation).
    ///   • aiAutonomy  → one autonomy prose step: loop until every criterion holds.
    ///   • aiDiscretion → one discretion prose step: verify/resolve the criteria.
    /// Returns nil when `line` is not a checklist sentinel.
    private func checklistStatements(_ line: SourceLine, file: String) throws -> [StatementAST]? {
        guard let (mode, body) = decodeChecklistSentinel(line.text) else { return nil }
        let items = body.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        switch mode {
        case .inert:
            return []
        case .invariant:
            return try items.map { item in
                let itemLine = SourceLine(indent: line.indent, text: item, raw: line.raw, number: line.number)
                return try checklistInvariant(itemLine, file: file)
            }
        case .aiAutonomy:
            return [proseStep(checklistProse(items, autonomy: true), dispatch: .autonomy, line: line)]
        case .aiDiscretion:
            return [proseStep(checklistProse(items, autonomy: false), dispatch: .discretion, line: line)]
        }
    }

    /// Render a fuzzy acceptance checklist as planner instructions. The criteria
    /// are embedded verbatim so the planner has them as the goal context.
    private func checklistProse(_ items: [String], autonomy: Bool) -> String {
        let header = autonomy
            ? "Ensure every acceptance criterion below holds, taking corrective action until all of them are satisfied:"
            : "Verify the following acceptance criteria and resolve any that are not met:"
        return header + "\n" + items.map { "- \($0)" }.joined(separator: "\n")
    }

    /// Wrap synthesized planner prose in a `.proseStep` statement with an
    /// explicit dispatch — the same path `use judgment to …:` takes, so it is
    /// valid in any workflow and runs through the planner/scope/checkpoint code.
    private func proseStep(_ text: String, dispatch: ProseDispatchAST, line: SourceLine) -> StatementAST {
        .proseStep(ProseStepAST(text: text, sourceLine: line.number, dispatch: dispatch))
    }

    private func shouldResolveAnaphora(_ line: SourceLine) -> Bool {
        let lower = line.statement.lowercased()
        if lower.contains(lexicon.grammar.tryIdiomFailureSeparator) { return false }
        return true
    }

    private func recordReferents(from statement: StatementAST, into referents: inout [String]) {
        switch statement {
        case .bind(let s):
            referents.append(camelize(s.name))
        case .rebind(let s):
            referents.append(camelize(s.name))
        case .iteration(let s):
            if case .forEach(let variable, _) = s.mode { referents.append(variable) }
        case .labelled(let s):
            recordReferents(from: s.statement, into: &referents)
        default:
            break
        }
        if referents.count > 4 {
            referents = Array(referents.suffix(4))
        }
    }

    private func appendStatement(_ statement: StatementAST, to stmts: inout [StatementAST]) {
        // `recover from …:` attaches to the immediately preceding statement.
        // When we see one, pop the predecessor from `stmts` and embed it.
        if case .recover(var rec) = statement,
           case .phraseInvocation(let placeholder) = rec.attached,
           (placeholder.words.isEmpty || placeholder.words == "__recover_placeholder__"),
           let preceding = stmts.last {
            stmts.removeLast()
            rec = RecoverStatementAST(
                pattern: rec.pattern,
                handler: rec.handler,
                attached: preceding,
                sourceLine: rec.sourceLine
            )
            stmts.append(.recover(rec))
        } else {
            stmts.append(statement)
        }
    }

    func parseStatement(_ lines: [SourceLine], at i: Int, file: String) throws -> (StatementAST?, Int) {
        let line = lines[i]
        let t = line.statement
        trace.log(.statement, "L\(line.number): \(ParserTrace.short(t))")

        // B6: Bare code-block sentinel lines are always consumed by the preceding
        // bind/decide statement.  If one reaches here it is orphaned — skip it.
        if t.hasPrefix(codeBlockSentinelPrefix) { return (nil, 1) }

        // A deferred marker error from the (non-throwing) tokenizer — raise it
        // now as a located diagnostic.
        if let message = decodeMarkerError(t) {
            throw CompilerError.semanticError(
                message: message,
                range: SourceRange(file: file, line: line.number, column: 1)
            )
        }

        // A table sentinel that reached here (e.g. an inert table producing no
        // statements) is consumed; executable tables are expanded in
        // `parseInlineChain` before this point.
        if t.hasPrefix(tableSentinelPrefix) { return (nil, 1) }

        // A checklist sentinel is expanded in `parseBlock`; one reaching here
        // (e.g. an inert list producing no statements) is consumed.
        if t.hasPrefix(checklistSentinelPrefix) { return (nil, 1) }

        // Rulebook desugar hook: rewrite a surface idiom (e.g. `If X -> Y`)
        // into a canonical statement, then re-parse. The engine reaches a
        // fixpoint, so the re-parse never re-triggers a rewrite (no recursion
        // loop). No-op when no rulebook is loaded.
        if let engine = rewriteEngine, !engine.isEmpty {
            let result = engine.rewrite(t)
            if result.changed, result.text != t {
                let rewritten = SourceLine(indent: line.indent, text: result.text,
                                           raw: line.raw, number: line.number)
                var newLines = lines
                newLines[i] = rewritten
                return try parseStatementWithoutRewrite(newLines, at: i, file: file)
            }
        }

        return try parseStatementWithoutRewrite(lines, at: i, file: file)
    }

    /// The body of statement parsing, run after the rulebook desugar hook.
    /// Separated so the hook can re-enter parsing exactly once on the rewritten
    /// line without risking an infinite loop.
    func parseStatementWithoutRewrite(_ lines: [SourceLine], at i: Int, file: String) throws -> (StatementAST?, Int) {
        let line = lines[i]
        let t = line.statement

        // Explicit judgment markers — the ONLY local path prose reaches the
        // planner: `use judgment to <goal>:` / `with discretion:` /
        // `with autonomy …:`. Checked before topic-label / idiom parsing so a
        // trailing-colon header isn't misread as a label.
        if let (stmt, consumed) = try parseJudgmentMarker(lines, at: i) {
            return (stmt, consumed)
        }

        // A `for each …` / `for every …:` block header must be recognized before
        // the topic-label rule: a capitalized header like `For every attendee:`
        // otherwise matches `topicLabel` (uppercase, ≤40 chars, letters/spaces)
        // with an empty body and is dropped, orphaning the loop body bullets.
        if t.lowercased().hasPrefix("for each ") || t.lowercased().hasPrefix("for every ") {
            if let (iter, consumed) = try? parseIteration(lines, at: i, file: file) {
                return (.iteration(iter), consumed)
            }
        }

        if let (label, rest) = StatementParser.topicLabel(in: t) {
            guard !rest.isEmpty else { return (nil, 1) }
            let labelledLine = SourceLine(indent: line.indent, text: rest, raw: line.raw, number: line.number)
            let (stmt, consumed) = try parseStatement([labelledLine] + Array(lines.dropFirst(i + 1)), at: 0, file: file)
            guard let stmt else { return (nil, consumed) }
            return (.labelled(LabelledStatementAST(label: label, statement: stmt, sourceLine: line.number)), consumed)
        }

        if let idiom = try parseEnglishIdiom(line, file: file) {
            return (idiom, 1)
        }

        if let conditional = try parseSuffixConditional(line, file: file) {
            return (.conditional(conditional), 1)
        }

        if t.lowercased().hasPrefix("otherwise ") {
            let handlerText = String(t.dropFirst("otherwise ".count)).trimmingCharacters(in: .whitespaces)
            let handlerLine = SourceLine(indent: line.indent + 2, text: handlerText, raw: line.raw, number: line.number)
            let handler = try parseBlock([handlerLine], file: file)
            let placeholder = StatementAST.phraseInvocation(PhraseInvocationAST(words: "", sourceLine: line.number))
            return (.recover(RecoverStatementAST(pattern: .any, handler: handler, attached: placeholder, sourceLine: line.number)), 1)
        }

        // "in lenient mode." or "in strict mode."
        if t.lowercased() == "in lenient mode" { return (.modal(.lenient), 1) }
        if t.lowercased() == "in strict mode"  { return (.modal(.strict), 1) }

        // "complete." or "complete with reason "X"."
        if t.lowercased() == "complete" { return (.complete(CompleteStatementAST(sourceLine: line.number)), 1) }
        if t.lowercased().hasPrefix("complete with reason ") {
            let rest = String(t.dropFirst("complete with reason ".count))
            let reason = unquote(rest)
            return (.complete(CompleteStatementAST(reason: reason, sourceLine: line.number)), 1)
        }

        // "commit." or "commit with label "X"."
        if t.lowercased() == "commit" { return (.commit(CommitStatementAST(sourceLine: line.number)), 1) }
        if t.lowercased().hasPrefix("commit with label ") {
            let label = unquote(String(t.dropFirst("commit with label ".count)))
            return (.commit(CommitStatementAST(label: label, sourceLine: line.number)), 1)
        }

        // "wait {duration}."
        if t.lowercased().hasPrefix("wait ") {
            let rest = String(t.dropFirst(5))
            if let cond = parseWaitCondition(rest) {
                return (.wait(WaitStatementAST(condition: cond, sourceLine: line.number)), 1)
            }
        }

        // Choice-gate: `ask the user to choose between "A", "B", or "C":`
        if let choice = parseChoiceGate(line) {
            return (.wait(choice), 1)
        }

        // "emit {eventID} with ..." (possibly multi-line payload)
        if t.lowercased().hasPrefix("emit ") {
            let (emitStmt, extra) = try parseEmit(lines, at: i)
            return (.emit(emitStmt), 1 + extra)
        }

        // "if {condition},"  (conditional, possibly followed by "otherwise,")
        if t.lowercased().hasPrefix("if ") && t.hasSuffix(",") {
            let (cond, consumed) = try parseConditional(lines, at: i, file: file)
            return (.conditional(cond), consumed)
        }
        // Single-line branch: `if {condition}, {action} [, otherwise {action}].`
        // The comma after the condition already delimits it, so the indented
        // multi-line form is optional — both modalities are supported and read as
        // plain English (`if the entity does not link to the input, add …`).
        if t.lowercased().hasPrefix("if "),
           let single = try parseInlineConditional(line, file: file) {
            return (.conditional(single), 1)
        }
        if t.lowercased().hasPrefix(lexicon.grammar.unlessYouDecideIntroducer) && t.hasSuffix(",") {
            let (cond, consumed) = try parseUnlessDecisionConditional(lines, at: i, file: file)
            return (.conditional(cond), consumed)
        }

        // 3C: "let {name} be {value}." — sugar for `bind`. Used so a description
        // value reads naturally (`let candidates be the stale pages …`). The
        // RHS goes through `parseBindValue`, so a tool-backed relation fetch is
        // hoisted at lowering exactly as for `bind`.
        if t.lowercased().hasPrefix("let "),
           case let afterLet = String(t.dropFirst(4)),
           let beRange = afterLet.range(of: " be ") {
            let name = lexicon.stripLeadingArticle(
                String(afterLet[afterLet.startIndex ..< beRange.lowerBound]))
            var valueStr = String(afterLet[beRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if valueStr.hasSuffix(".") { valueStr = String(valueStr.dropLast()) }
            if !name.isEmpty, !valueStr.isEmpty {
                let (expr, extra) = try parseBindValue(valueStr, lines: lines, at: i)
                return (.bind(BindStatementAST(name: name, value: expr, sourceLine: line.number)), 1 + extra)
            }
        }

        // "bind {name} = invoke {tool} with ..."
        // "rebind {name} = invoke {tool} with ..."
        if t.lowercased().hasPrefix("bind ") || t.lowercased().hasPrefix("rebind ") {
            let isRebind = t.lowercased().hasPrefix("rebind ")
            let rest = String(t.dropFirst(isRebind ? 7 : 5))
            if let eqRange = rest.range(of: " = ") {
                let name = String(rest[rest.startIndex ..< eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let valueStr = String(rest[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                // Collect continuation lines (for multi-line invoke args)
                let (expr, extra) = try parseBindValue(valueStr, lines: lines, at: i)
                let stmt = isRebind
                    ? StatementAST.rebind(RebindStatementAST(name: name, value: expr, sourceLine: line.number))
                    : StatementAST.bind(BindStatementAST(name: name, value: expr, sourceLine: line.number))
                return (stmt, 1 + extra)
            }
        }

        // B2: "while {condition},"
        if t.lowercased().hasPrefix("while ") && t.hasSuffix(",") {
            let condText = String(t.dropFirst("while ".count).dropLast()).trimmingCharacters(in: .whitespaces)
            let cond = exprParser.parse(condText)
            let parentIndent = line.indent
            var bodyLines: [SourceLine] = []
            var j = i + 1
            while j < lines.count {
                let l = lines[j]
                if l.isEmpty || l.isComment { j += 1; continue }
                if l.indent > parentIndent { bodyLines.append(l); j += 1 }
                else { break }
            }
            let body = try parseBlock(bodyLines, file: file)
            return (.iteration(IterationStatementAST(mode: .whileCondition(cond), body: body, sourceLine: line.number)), j - i)
        }

        // B2: "until {condition},"
        if t.lowercased().hasPrefix("until ") && t.hasSuffix(",") {
            let condText = String(t.dropFirst("until ".count).dropLast()).trimmingCharacters(in: .whitespaces)
            let cond = exprParser.parse(condText)
            let parentIndent = line.indent
            var bodyLines: [SourceLine] = []
            var j = i + 1
            while j < lines.count {
                let l = lines[j]
                if l.isEmpty || l.isComment { j += 1; continue }
                if l.indent > parentIndent { bodyLines.append(l); j += 1 }
                else { break }
            }
            let body = try parseBlock(bodyLines, file: file)
            return (.iteration(IterationStatementAST(mode: .untilCondition(cond), body: body, sourceLine: line.number)), j - i)
        }

        // "simultaneously:" with each top-level body statement as a branch.
        if t.lowercased() == "simultaneously:" {
            let (sim, consumed) = try parseSimultaneously(lines, at: i, file: file)
            return (.simultaneously(sim), consumed)
        }

        // "recover from {pattern}:"  or  "recover where {predicate}:"
        let tl = t.lowercased()
        if tl.hasPrefix("recover from ") || tl.hasPrefix("recover where ") {
            let (rec, consumed) = try parseRecover(lines, at: i, file: file)
            // The `attached` field is a placeholder — `parseBlock` will replace it
            // with the actual preceding statement after the loop iteration returns.
            return (.recover(rec), consumed)
        }

        if let every = parseEveryEach(line) {
            return (.iteration(every), 1)
        }

        // Everything else is a phrase invocation (or multi-line phrase).
        // Continuation lines (deeper indent, no period) are folded into the
        // invocation text and reported in `consumed` so `parseBlock` skips them.
        let (folded, contConsumed) = collectMultiLineCounted(lines, at: i)
        return (.phraseInvocation(PhraseInvocationAST(words: folded, sourceLine: line.number)),
                1 + contConsumed)
    }

    public static func topicLabel(in text: String) -> (label: String, rest: String)? {
        guard let colon = text.firstIndex(of: ":") else { return nil }
        let label = String(text[..<colon]).trimmingCharacters(in: .whitespaces)
        let after = text.index(after: colon)
        let rest = String(text[after...]).trimmingCharacters(in: .whitespaces)
        guard let first = label.first, first.isUppercase,
              !label.isEmpty, label.count <= 40,
              label.allSatisfy({ $0.isLetter || $0.isNumber || $0 == " " || $0 == "_" || $0 == "-" }),
              (rest.isEmpty || text[after].isWhitespace) else {
            return nil
        }
        return (label, rest)
    }

    private func parseInlineChain(_ line: SourceLine, file: String) throws -> [StatementAST]? {
        let statement = line.statement

        // Command surface: a fenced ```bash/```sh/```shell block (collapsed by
        // the tokenizer into a code-block sentinel) lowers each command line to
        // a deterministic `shell.run` invoke. One invoke per command line;
        // backslash line-continuations are joined. Never calls an LLM.
        if let shellStatements = shellBlockStatements(line) {
            return shellStatements
        }

        // Inline backticked literal command on its own line, e.g. `gbrain publish`.
        if let inlineShell = inlineBacktickedCommand(line) {
            return [inlineShell]
        }

        // A collapsed Markdown table sentinel expands to per-row statements
        // (decision branches, a data-table binding, or nothing for inert).
        if let tableStatements = try tableStatements(line, file: file) {
            return tableStatements
        }

        guard statement.lowercased().hasPrefix("do ") else { return nil }
        let rest = String(statement.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let chunks = splitStatementChain(rest)
        guard chunks.count > 1 else { return nil }
        return try chunks.compactMap { chunk in
            let synthetic = SourceLine(indent: line.indent, text: chunk, raw: line.raw, number: line.number)
            return try parseStatement([synthetic], at: 0, file: file).0
        }
    }

    /// Parse an explicit judgment marker into a `.proseStep` carrying its own
    /// dispatch mode (so it is valid in any workflow, deterministic-by-default):
    ///
    ///   • `use judgment to <goal>:`  + indented instructions → discretion
    ///   • `use judgment to <goal>.`  (single line)            → discretion
    ///   • `with discretion:`         + indented instructions  → discretion
    ///   • `with autonomy <opts>:`    + indented instructions  → autonomy
    ///
    /// Returns `nil` when the line is not a judgment marker.
    private func parseJudgmentMarker(_ lines: [SourceLine], at i: Int) throws -> (StatementAST, Int)? {
        let line = lines[i]
        let t = line.statement
        let lower = t.lowercased()

        func collectBody() -> (text: [String], consumed: Int) {
            var bodyLines: [String] = []
            var j = i + 1
            while j < lines.count {
                let l = lines[j]
                if l.isEmpty || l.isComment { j += 1; continue }
                if l.indent > line.indent { bodyLines.append(l.statement); j += 1 } else { break }
            }
            return (bodyLines, j - i)
        }

        // `use judgment to <goal>` — block (ends with ":") or single line.
        for prefix in lexicon.grammar.judgmentIntroducers {
            guard lower.hasPrefix(prefix) else { continue }
            var goal = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            let isBlock = goal.hasSuffix(":")
            if isBlock { goal = String(goal.dropLast()).trimmingCharacters(in: .whitespaces) }
            var consumed = 1
            var proseText = goal
            if isBlock {
                let body = collectBody()
                consumed += body.consumed - 1
                if !body.text.isEmpty {
                    proseText = ([goal] + body.text).filter { !$0.isEmpty }.joined(separator: "\n")
                }
            }
            return (.proseStep(ProseStepAST(text: proseText, sourceLine: line.number, dispatch: .discretion)), consumed)
        }

        // `with discretion:` block.
        if lower == lexicon.grammar.discretionMarker + ":" || lower == lexicon.grammar.discretionMarker {
            let body = collectBody()
            let proseText = body.text.joined(separator: "\n")
            return (.proseStep(ProseStepAST(text: proseText, sourceLine: line.number, dispatch: .discretion)), body.consumed)
        }

        // `with autonomy <options>:` block.
        if lower.hasPrefix(lexicon.grammar.autonomyMarker) {
            let afterMarker = String(t.dropFirst(lexicon.grammar.autonomyMarker.count))
            let opts = afterMarker.hasSuffix(":")
                ? String(afterMarker.dropLast()).trimmingCharacters(in: .whitespaces)
                : afterMarker.trimmingCharacters(in: .whitespaces)
            let body = collectBody()
            let proseText = body.text.joined(separator: "\n")
            return (.proseStep(ProseStepAST(
                text: proseText,
                sourceLine: line.number,
                dispatch: .autonomy,
                autonomy: AutonomyConfigAST.parse(opts, parseExpression: exprParser.parse)
            )), body.consumed)
        }

        return nil
    }

    /// Parse a choice-gate statement:
    /// `ask the user to choose between "A", "B", or "C":` (trailing `:` optional).
    /// Options are the double-quoted spans. Returns nil when the line is not a
    /// choice gate or declares no options.
    private func parseChoiceGate(_ line: SourceLine) -> WaitStatementAST? {
        let t = line.statement
        let lower = t.lowercased()
        let markers = lexicon.grammar.choiceGateIntroducers
        guard let marker = markers.first(where: { lower.hasPrefix($0) }) else { return nil }
        let rest = String(t.dropFirst(marker.count))
        let options = doubleQuotedSpans(in: rest)
        guard !options.isEmpty else { return nil }
        return WaitStatementAST(
            condition: .choice(prompt: t, options: options),
            sourceLine: line.number
        )
    }

    /// Extract the contents of each double-quoted span in `s`, in order.
    private func doubleQuotedSpans(in s: String) -> [String] {
        var spans: [String] = []
        var current = ""
        var inQuote = false
        for c in s {
            if c == "\"" {
                if inQuote { spans.append(current); current = "" }
                inQuote.toggle()
                continue
            }
            if inQuote { current.append(c) }
        }
        return spans
    }

    /// Expand a fenced shell code block into one `shell.run` invoke per command
    /// line. Returns `nil` when the line is not a shell-tagged code-block
    /// sentinel (so other code-block languages flow through unchanged).
    private func shellBlockStatements(_ line: SourceLine) -> [StatementAST]? {
        guard let (lang, body) = decodeCodeBlockSentinel(line.text) else { return nil }
        guard lexicon.isShellFence(lang) else { return nil }

        let commands = splitShellCommands(body)
        return commands.map { cmd in
            .phraseInvocation(PhraseInvocationAST(
                words: encodeShellCommand(cmd),
                sourceLine: line.number
            ))
        }
    }

    /// Expand a collapsed Markdown table sentinel into statements per its mode.
    /// Returns nil when the line is not a table sentinel; an (possibly empty)
    /// array otherwise (empty = inert/iteration, consumed without execution).
    private func tableStatements(_ line: SourceLine, file: String) throws -> [StatementAST]? {
        guard let (mode, table) = TableParser.decode(line.text) else { return nil }
        let parser = TableParser(lexicon: lexicon)
        switch mode {
        case .decision:
            var out: [StatementAST] = []
            for rowText in parser.decisionRowTexts(table) {
                let rowLine = SourceLine(indent: line.indent, text: rowText, raw: line.raw, number: line.number)
                if let expanded = try parseInlineChain(rowLine, file: file) {
                    out.append(contentsOf: expanded)
                } else if let stmt = try parseStatement([rowLine], at: 0, file: file).0 {
                    out.append(stmt)
                }
            }
            return out
        case .data(let name):
            return [dataTableBinding(table, name: name, line: line)]
        case .aiDiscretion:
            return [proseStep(parser.aiDecisionProse(table), dispatch: .discretion, line: line)]
        case .aiAutonomy:
            return [proseStep(parser.aiDecisionProse(table), dispatch: .autonomy, line: line)]
        case .inert, .iteration:
            return []
        }
    }

    /// Build a `bind <name> = <recordList>` from a data table. Field names come
    /// from the header; each cell is a literal value (numbers/money/duration
    /// parse as literals, everything else is a string literal).
    private func dataTableBinding(_ table: TableParser.ParsedTable, name: String?, line: SourceLine) -> StatementAST {
        let fields = table.header
        let rows = table.rows.map { row -> [ExpressionAST] in
            (0 ..< fields.count).map { idx in
                dataCellValue(idx < row.count ? row[idx] : "")
            }
        }
        return .bind(BindStatementAST(
            name: name ?? "table",
            value: .recordList(fields: fields, rows: rows),
            sourceLine: line.number
        ))
    }

    /// Coerce a data-table cell to a literal expression. A cell that parses to a
    /// literal keeps its type; anything else becomes a string literal (a data
    /// value is never a state read).
    private func dataCellValue(_ raw: String) -> ExpressionAST {
        let cell = raw.trimmingCharacters(in: .whitespaces)
        if cell.isEmpty { return .literal(.string("")) }
        if cell.hasPrefix("\"") && cell.hasSuffix("\"") && cell.count >= 2 {
            return .literal(.string(String(cell.dropFirst().dropLast())))
        }
        let parsed = exprParser.parse(cell)
        if case .literal = parsed { return parsed }
        return .literal(.string(cell))
    }

    /// Split a shell-block body into individual commands, dropping blank lines
    /// and `#` comments and joining trailing-backslash line continuations.
    private func splitShellCommands(_ body: String) -> [String] {
        var commands: [String] = []
        var pending = ""
        for rawLine in body.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                if pending.isEmpty { continue }
            }
            if trimmed.hasSuffix("\\") {
                pending += String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces) + " "
                continue
            }
            let full = (pending + trimmed).trimmingCharacters(in: .whitespaces)
            pending = ""
            if !full.isEmpty && !full.hasPrefix("#") { commands.append(full) }
        }
        if !pending.trimmingCharacters(in: .whitespaces).isEmpty {
            commands.append(pending.trimmingCharacters(in: .whitespaces))
        }
        return commands
    }

    /// A line whose entire statement is a single backtick-quoted command,
    /// optionally followed by a ` -- <note>` annotation (1A), e.g.
    /// `` `gbrain publish "title"` -- announce the page `` — lowers to one
    /// `shell.run` invoke carrying the note as a source comment.
    private func inlineBacktickedCommand(_ line: SourceLine) -> StatementAST? {
        let raw = line.statement.trimmingCharacters(in: .whitespaces)
        let (commandSpan, annotation) = Self.splitCommandAnnotation(raw)
        let t = commandSpan.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2, t.hasPrefix("`"), t.hasSuffix("`") else { return nil }
        let inner = String(t.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        // Reject if the inner text still contains a backtick (not a single span)
        // or is empty.
        guard !inner.isEmpty, !inner.contains("`") else { return nil }
        return .phraseInvocation(PhraseInvocationAST(
            words: encodeShellCommand(inner),
            annotation: annotation,
            sourceLine: line.number
        ))
    }

    /// Split a command bullet into the command span and an optional trailing
    /// ` -- <note>` explanation. The separator (space `--` space) is recognized
    /// only at backtick-depth 0, so a command containing `--flag` or an
    /// in-backtick ` -- ` is never split. A bare trailing ` --` (no note) is
    /// left attached.
    static func splitCommandAnnotation(_ s: String) -> (command: String, annotation: String?) {
        let chars = Array(s)
        var depth = 0
        var i = 0
        while i < chars.count {
            if chars[i] == "`" { depth ^= 1 }
            if depth == 0, chars[i] == "-", i > 0, chars[i - 1] == " ",
               i + 1 < chars.count, chars[i + 1] == "-",
               i + 2 < chars.count, chars[i + 2] == " " {
                let command = String(chars[0..<i]).trimmingCharacters(in: .whitespaces)
                let note = String(chars[(i + 2)...]).trimmingCharacters(in: .whitespaces)
                return (command, note.isEmpty ? nil : note)
            }
            i += 1
        }
        return (s, nil)
    }

    private func parseEnglishIdiom(_ line: SourceLine, file: String) throws -> StatementAST? {
        let t = line.statement
        let lower = t.lowercased()

        // Background spawn: `in the background, <stmt>.` → detached simultaneously.
        for prefix in lexicon.grammar.backgroundSpawnIntroducers {
            guard lower.hasPrefix(prefix) else { continue }
            let actionText = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            guard !actionText.isEmpty else { return nil }
            let actionLine = SourceLine(indent: line.indent, text: actionText, raw: line.raw, number: line.number)
            guard let stmt = try parseStatement([actionLine], at: 0, file: file).0 else { return nil }
            return .simultaneously(SimultaneouslyStatementAST(
                branches: [ASTBlock(statements: [stmt], sourceLine: line.number)],
                detached: true,
                sourceLine: line.number
            ))
        }

        if let marker = lexicon.assertionMarkers.first(where: { lower.hasPrefix($0 + " ") }) {
            let condition = String(t.dropFirst(marker.count + 1)).trimmingCharacters(in: .whitespaces)
            guard !condition.isEmpty else { return nil }
            return .assertStmt(AssertStatementAST(
                condition: exprParser.parse(condition),
                message: "Expected \(condition)",
                sourceLine: line.number
            ))
        }

        if lower.hasPrefix(lexicon.grammar.afterIdiomIntroducer),
           let comma = rangeOfMarkerOutsideQuotes(", ", in: t) {
            let conditionText = String(t[t.index(t.startIndex, offsetBy: lexicon.grammar.afterIdiomIntroducer.count)..<comma.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let actionText = String(t[comma.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !conditionText.isEmpty, !actionText.isEmpty else { return nil }
            let actionLine = SourceLine(indent: line.indent + 2, text: actionText, raw: line.raw, number: line.number)
            let (stmt, _) = try parseStatement([actionLine], at: 0, file: file)
            guard let stmt else { return nil }
            return .conditional(ConditionalStatementAST(
                condition: exprParser.parse(conditionText),
                thenBlock: ASTBlock(statements: [stmt], sourceLine: line.number),
                sourceLine: line.number
            ))
        }

        if let range = rangeOfMarkerOutsideQuotes(lexicon.grammar.exceptWhenMarker, in: t) {
            let actionText = String(t[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let predicateText = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !actionText.isEmpty, !predicateText.isEmpty else { return nil }
            let rewritten = "\(actionText)\(lexicon.grammar.suffixConditionalNegated)\(predicateText)"
            let rewrittenLine = SourceLine(indent: line.indent, text: rewritten, raw: line.raw, number: line.number)
            return try parseStatement([rewrittenLine], at: 0, file: file).0
        }

        if lower.hasPrefix(lexicon.grammar.tryIdiomIntroducer),
           let range = rangeOfMarkerOutsideQuotes(lexicon.grammar.tryIdiomFailureSeparator, in: t) {
            let actionText = String(t[t.index(t.startIndex, offsetBy: lexicon.grammar.tryIdiomIntroducer.count)..<range.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let handlerText = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !actionText.isEmpty, !handlerText.isEmpty else { return nil }
            let actionLine = SourceLine(indent: line.indent, text: actionText, raw: line.raw, number: line.number)
            let handlerLine = SourceLine(indent: line.indent + 2, text: handlerText, raw: line.raw, number: line.number)
            guard let action = try parseStatement([actionLine], at: 0, file: file).0,
                  let handler = try parseStatement([handlerLine], at: 0, file: file).0 else { return nil }
            return .recover(RecoverStatementAST(
                pattern: .any,
                handler: ASTBlock(statements: [handler], sourceLine: line.number),
                attached: action,
                sourceLine: line.number
            ))
        }

        if let passive = passiveVoiceRewrite(t) {
            let rewrittenLine = SourceLine(indent: line.indent, text: passive, raw: line.raw, number: line.number)
            return try parseStatement([rewrittenLine], at: 0, file: file).0
        }

        return nil
    }

    private func passiveVoiceRewrite(_ text: String) -> String? {
        let lower = text.lowercased()
        let markers = lexicon.grammar.passiveModalityMarkers
        for marker in markers {
            guard let range = lower.range(of: marker) else { continue }
            let subject = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            var verb = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !subject.isEmpty, verb.hasSuffix("ed") else { continue }
            verb.removeLast(2)
            if verb.hasSuffix("v") { verb += "e" }
            return "\(verb) \(subject)"
        }
        return nil
    }

    private func parseSuffixConditional(_ line: SourceLine, file: String) throws -> ConditionalStatementAST? {
        let t = line.statement
        let markers = lexicon.grammar.suffixConditionalMarkers
        for marker in markers {
            guard let range = rangeOfMarkerOutsideQuotes(marker, in: t) else { continue }
            let actionText = String(t[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let predicateText = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !actionText.isEmpty, !predicateText.isEmpty else { return nil }

            let actionLine = SourceLine(indent: line.indent + 2, text: actionText, raw: line.raw, number: line.number)
            let (stmt, _) = try parseStatement([actionLine], at: 0, file: file)
            guard let stmt else { return nil }

            let parsedPredicate = parseDecisionPredicate(predicateText)
            let condition: ExpressionAST = marker == lexicon.grammar.suffixConditionalNegated
                ? .logical(.not, [parsedPredicate])
                : parsedPredicate
            return ConditionalStatementAST(
                condition: condition,
                thenBlock: ASTBlock(statements: [stmt], sourceLine: line.number),
                sourceLine: line.number
            )
        }
        return nil
    }

    private func parseUnlessDecisionConditional(
        _ lines: [SourceLine],
        at i: Int,
        file: String
    ) throws -> (ConditionalStatementAST, Int) {
        let line = lines[i]
        var question = String(line.statement.dropFirst(lexicon.grammar.unlessYouDecideIntroducer.count))
        if question.hasSuffix(",") { question = String(question.dropLast()) }
        let parentIndent = line.indent
        var bodyLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { bodyLines.append(l); j += 1 }
            else { break }
        }
        let body = try parseBlock(bodyLines, file: file)
        return (ConditionalStatementAST(
            condition: .logical(.not, [.decideWhether(question: question.trimmingCharacters(in: .whitespaces))]),
            thenBlock: body,
            sourceLine: line.number
        ), j - i)
    }

    private func parseDecisionPredicate(_ text: String) -> ExpressionAST {
        let t = text.trimmingCharacters(in: .whitespaces)
        let lower = t.lowercased()
        if lower.hasPrefix(lexicon.grammar.youDecideIntroducer) {
            let question = String(t.dropFirst(lexicon.grammar.youDecideIntroducer.count)).trimmingCharacters(in: .whitespaces)
            return .decideWhether(question: question)
        }
        return exprParser.parse(t)
    }

    private func parseEveryEach(_ line: SourceLine) -> IterationStatementAST? {
        let t = line.statement
        for marker in [" every ", " each "] {
            guard let range = rangeOfMarkerOutsideQuotes(marker, in: t) else { continue }
            let action = String(t[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rawNounPhrase = String(t[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !action.isEmpty, !rawNounPhrase.isEmpty else { return nil }

            let (rawNoun, refinement) = extractIterationRefinement(rawNounPhrase)
            guard !rawNoun.isEmpty else { return nil }

            let singular = lexicon.singularize(rawNoun)
            let variable = camelize(singular)
            let collection = ExpressionAST.identifierRef(camelize(lexicon.pluralize(singular)))
            let bodyText = "\(action) the \(singular)"
            let body = ASTBlock(
                statements: [.phraseInvocation(PhraseInvocationAST(words: bodyText, sourceLine: line.number))],
                sourceLine: line.number
            )
            return IterationStatementAST(
                mode: .forEach(variable: variable, collection: collection),
                body: body,
                sourceLine: line.number,
                refinement: refinement
            )
        }
        return nil
    }

    /// Strip a single-clause iteration refinement (1C) off a noun phrase,
    /// returning the bare kind noun plus the parsed refinement (or nil). Grammar,
    /// in order: `[the first N] <kind plural> [whose <pred> | within the last N
    /// <unit> | in the next N <unit>] [sorted by <prop>[, <dir>]]`. Sorting is
    /// recognized as a trailing clause; the filter clause is single (the first
    /// of `whose`/temporal that appears); `the first N` is a leading prefix.
    private func extractIterationRefinement(_ phrase: String) -> (noun: String, refinement: IterationRefinementAST?) {
        var work = phrase.trimmingCharacters(in: .whitespaces)
        var ref = IterationRefinementAST()

        // 1. Trailing `sorted by <prop>[, <dir>]`.
        if let r = lexicon.sortByMarkers.lazy.compactMap({ rangeOfMarkerOutsideQuotes($0, in: work) }).first {
            let head = String(work[..<r.lowerBound])
            var tail = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            var ascending = true
            if let comma = tail.range(of: ",") {
                let dir = String(tail[comma.upperBound...]).trimmingCharacters(in: .whitespaces).lowercased()
                tail = String(tail[..<comma.lowerBound]).trimmingCharacters(in: .whitespaces)
                if lexicon.descendingMarkers.contains(where: { dir.contains($0) }) { ascending = false }
                else if lexicon.ascendingMarkers.contains(where: { dir.contains($0) }) { ascending = true }
            }
            if !tail.isEmpty { ref.sort = (camelize(tail), ascending) }
            work = head.trimmingCharacters(in: .whitespaces)
        }

        // 2. Single filter clause: whose / within the last / in the next.
        if let r = rangeOfMarkerOutsideQuotes(" whose ", in: work) {
            let head = String(work[..<r.lowerBound])
            let clause = String(work[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !clause.isEmpty { ref.predicate = exprParser.parse(clause) }
            work = head.trimmingCharacters(in: .whitespaces)
        } else if let hit = lexicon.temporalWindowMarkers.lazy.compactMap({ (marker, op) -> (Range<String.Index>, ComparisonOpAST)? in
            rangeOfMarkerOutsideQuotes(marker, in: work).map { ($0, op) }
        }).first {
            let head = String(work[..<hit.0.lowerBound])
            let clause = String(work[hit.0.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let secs = durationSeconds(clause) {
                ref.temporal = (lexicon.timestampProperty, hit.1 == .withinPast ? .past : .future, secs)
            }
            work = head.trimmingCharacters(in: .whitespaces)
        }

        // 3. Leading `[the ]first N`.
        var firstScan = work
        for article in lexicon.articles where firstScan.lowercased().hasPrefix(article + " ") {
            firstScan = String(firstScan.dropFirst(article.count + 1)); break
        }
        if firstScan.lowercased().hasPrefix("first ") {
            let after = String(firstScan.dropFirst("first ".count)).trimmingCharacters(in: .whitespaces)
            let comps = after.split(separator: " ", maxSplits: 1).map(String.init)
            if let n = Int(comps.first ?? "") {
                ref.take = n
                work = comps.count > 1 ? comps[1].trimmingCharacters(in: .whitespaces) : ""
            }
        }

        return (work.trimmingCharacters(in: .whitespaces), ref.isEmpty ? nil : ref)
    }

    /// Parse "N <unit>" into total seconds using the lexicon's duration table.
    private func durationSeconds(_ s: String) -> Double? {
        guard let (amount, unit) = lexicon.parseDuration(s) else { return nil }
        return amount * Double(unit.inSeconds)
    }

    private func splitStatementChain(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var inString = false
        // True once a chain element has entered an invoke argument list via
        // ` with `. While true, plain commas separate invoke arguments rather
        // than chain elements; only `, and `, ` and `, or ` then ` terminate
        // the element.
        var inInvokeArgs = false
        var i = text.startIndex
        while i < text.endIndex {
            let c = text[i]
            if c == "\"" {
                inString.toggle()
                current.append(c)
                i = text.index(after: i)
                continue
            }
            if !inString {
                if c == "(" { depth += 1 }
                else if c == ")" { depth = max(0, depth - 1) }

                // Enter "invoke args" mode when we see ` with ` at depth 0.
                if depth == 0, !inInvokeArgs,
                   text[i...].lowercased().hasPrefix(" with ") {
                    inInvokeArgs = true
                }

                // `, and ` is a chain terminator even when we're inside an
                // invoke argument list — `and` introduces the next element.
                if depth == 0,
                   text[i...].lowercased().hasPrefix(", and ") {
                    parts.append(cleanChainPart(current))
                    current = ""
                    inInvokeArgs = false
                    i = text.index(i, offsetBy: ", and ".count)
                    continue
                }
                if depth == 0,
                   text[i...].lowercased().hasPrefix(" and ") {
                    parts.append(cleanChainPart(current))
                    current = ""
                    inInvokeArgs = false
                    i = text.index(i, offsetBy: " and ".count)
                    continue
                }
                if depth == 0,
                   text[i...].lowercased().hasPrefix(" then ") {
                    parts.append(cleanChainPart(current))
                    current = ""
                    inInvokeArgs = false
                    i = text.index(i, offsetBy: " then ".count)
                    continue
                }
                // Plain comma only splits when not collecting invoke arguments.
                if depth == 0, !inInvokeArgs, c == "," {
                    parts.append(cleanChainPart(current))
                    current = ""
                    i = text.index(after: i)
                    continue
                }
            }
            current.append(c)
            i = text.index(after: i)
        }
        parts.append(cleanChainPart(current))
        return parts.filter { !$0.isEmpty }
    }

    private func cleanChainPart(_ part: String) -> String {
        var s = part.trimmingCharacters(in: .whitespaces)
        if s.lowercased().hasPrefix("and ") { s = String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces) }
        if s.lowercased().hasPrefix("then ") { s = String(s.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        return s
    }

    private func camelize(_ raw: String) -> String {
        let parts = raw.lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "_" || $0 == "-" })
            .map(String.init)
        guard let head = parts.first else { return raw.lowercased() }
        let tail = parts.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return ([head] + tail).joined()
    }

    private func rangeOfMarkerOutsideQuotes(_ marker: String, in text: String) -> Range<String.Index>? {
        QuoteAwareScanner.rangeOfMarker(marker, in: text, caseInsensitive: true)
    }

    // MARK: - Bind value (invoke expression or literal)

    private func parseBindValue(_ s: String, lines: [SourceLine], at i: Int) throws -> (ExpressionAST, Int) {
        // B3: "decide whether <question>" — routes to llm.decide at runtime.
        if s.lowercased().hasPrefix(lexicon.grammar.decideWhetherIntroducer) {
            let question = String(s.dropFirst(lexicon.grammar.decideWhetherIntroducer.count)).trimmingCharacters(in: .whitespaces)
            return (.decideWhether(question: question), 0)
        }

        // B6/B7: "decide using:" followed by an indented code-block sentinel.
        // Use parseAtom to decode the sentinel — this handles plain bodies
        // (.literal(.string)) and {{ expr }} interpolated bodies
        // (.interpolatedString) uniformly. Wrap both forms as .invoke so the
        // question argument can be any IRExpression (including interpolated).
        if s.lowercased() == lexicon.grammar.decideUsingMarker {
            var j = i + 1
            while j < lines.count {
                let l = lines[j]
                if l.isEmpty || l.isComment { j += 1; continue }
                if l.statement.hasPrefix(codeBlockSentinelPrefix) {
                    let questionExpr = exprParser.parseAtom(l.statement)
                    return (.invoke("llm.decide", [("question", questionExpr)]), j - i)
                }
                break
            }
            return (.invoke("llm.decide", [("question", .literal(.string("")))]), 0)
        }

        // B6: Sentinel used directly as a value expression (safety net for
        // future inline-fence handling; currently unreachable with normal source).
        if s.hasPrefix(codeBlockSentinelPrefix) {
            return (exprParser.parseAtom(s), 0)
        }

        if s.lowercased().hasPrefix("invoke ") {
            let (expr, extra) = parseInvokeExpr(s, lines: lines, at: i)
            return (expr, extra)
        }
        return (exprParser.parse(s), 0)
    }

    // MARK: - Invoke expression

    func parseInvokeExpr(_ s: String, lines: [SourceLine], at i: Int) -> (ExpressionAST, Int) {
        // "invoke {tool words} with {args}"  or multi-line
        var invText = s
        var extra = 0

        // Collect continuation lines for multi-line args
        let parentIndent = lines[i].indent
        var contLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent {
                contLines.append(l)
                j += 1
                extra += 1
            } else {
                break
            }
        }
        // Append continuation args to invText
        if !contLines.isEmpty {
            let contStr = contLines.map { $0.statement }.joined(separator: ", ")
            invText = invText.hasSuffix(",") ? invText + " " + contStr
                                             : invText + " " + contStr
        }

        return (buildInvokeExpr(invText), extra)
    }

    func buildInvokeExpr(_ s: String) -> ExpressionAST {
        // "invoke {tool name} with {k = v, k = v}"
        // Strip "invoke "
        var rest = s
        if rest.lowercased().hasPrefix("invoke ") { rest = String(rest.dropFirst(7)) }

        let toolName: String
        let args: [(String, ExpressionAST)]

        if let withRange = rest.lowercased().range(of: " with ") {
            toolName = String(rest[rest.startIndex ..< withRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let argStr = String(rest[withRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            args = parseArgList(argStr)
        } else {
            toolName = rest.trimmingCharacters(in: .whitespaces)
            args = []
        }

        // Resolve tool method name
        let methodName = symbols?.tool(fromWords: toolName)?.methodName ?? methodize(toolName)
        return .invoke(methodName, args)
    }

    private func parseArgList(_ s: String) -> [(String, ExpressionAST)] {
        // "key = value, key = value, ..."
        // Split on commas not inside quotes
        let parts = splitArgs(s)
        return parts.compactMap { part -> (String, ExpressionAST)? in
            let p = part.trimmingCharacters(in: .whitespaces)
            guard let range = p.range(of: " = ") ?? p.range(of: "=") else { return nil }
            let key = String(p[p.startIndex ..< range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let val = String(p[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (key, exprParser.parse(val))
        }
    }

    private func splitArgs(_ s: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var inString = false
        // Only double quotes delimit string literals here — single-quote
        // (apostrophe) is too common in possessives ("customer's email") to
        // treat as a string boundary.
        for c in s {
            if c == "\"" {
                inString.toggle()
                current.append(c)
                continue
            }
            if !inString {
                if c == "(" { depth += 1 }
                else if c == ")" { depth -= 1 }
                else if c == "," && depth == 0 {
                    parts.append(current.trimmingCharacters(in: .whitespaces))
                    current = ""
                    continue
                }
            }
            current.append(c)
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(current.trimmingCharacters(in: .whitespaces))
        }
        return parts
    }

    // MARK: - Emit

    private func parseEmit(_ lines: [SourceLine], at i: Int) throws -> (EmitStatementAST, Int) {
        let line = lines[i]
        let t = line.statement
        var rest = String(t.dropFirst(5)).trimmingCharacters(in: .whitespaces)  // drop "emit "

        let eventID: String
        var extra = 0
        let parentIndent = line.indent

        // Collect any continuation lines (deeper indent) before deciding on eventID.
        // This handles both "emit X with arg = v" and "emit X with\n  arg = v,\n  ..."
        var contLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent { contLines.append(l); j += 1; extra += 1 }
            else { break }
        }

        // Normalise: append continuation into rest so we can find " with " cleanly
        if !contLines.isEmpty {
            let contStr = contLines.map(\.statement).joined(separator: ", ")
            if rest.hasSuffix(" with") {
                rest = rest + " " + contStr
            } else if rest.hasSuffix(",") {
                rest = rest + " " + contStr
            } else {
                rest = rest + contStr
            }
        }

        if let withRange = rest.lowercased().range(of: " with ") {
            eventID = String(rest[rest.startIndex ..< withRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let argStr = String(rest[withRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let payload = parseArgList(argStr)
            return (EmitStatementAST(eventID: eventID, payload: payload, sourceLine: line.number), extra)
        } else {
            eventID = rest
            return (EmitStatementAST(eventID: eventID, payload: [], sourceLine: line.number), extra)
        }
    }

    // MARK: - Conditional

    private func parseConditional(_ lines: [SourceLine], at i: Int, file: String) throws -> (ConditionalStatementAST, Int) {
        let line = lines[i]
        let t = line.statement

        // condition text: strip leading "if " and trailing ","
        var condText = t
        if condText.lowercased().hasPrefix("if ") { condText = String(condText.dropFirst(3)) }
        if condText.hasSuffix(",") { condText = String(condText.dropLast()) }
        let condition = parseDecisionPredicate(condText)

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

        // Check for "otherwise,"
        var elseBlock: ASTBlock? = nil
        var elseConsumed = j
        if j < lines.count && lines[j].isContent {
            let nextText = lines[j].statement.lowercased()
            if nextText == "otherwise" || nextText == "otherwise," {
                let otherwiseIndent = lines[j].indent
                var elseLines: [SourceLine] = []
                var k = j + 1
                while k < lines.count {
                    let l = lines[k]
                    if l.isEmpty || l.isComment { k += 1; continue }
                    if l.indent > otherwiseIndent { elseLines.append(l); k += 1 }
                    else { break }
                }
                elseBlock = try parseBlock(elseLines, file: file)
                elseConsumed = k
            }
        }

        let thenBlock = try parseBlock(thenLines, file: file)
        let consumed = elseConsumed - i

        return (ConditionalStatementAST(
            condition: condition,
            thenBlock: thenBlock,
            elseBlock: elseBlock,
            sourceLine: line.number
        ), consumed)
    }

    /// Single-line branch `if <cond>, <then> [, otherwise <else>].`. The
    /// condition/then split is the first top-level comma (outside quotes) that
    /// does not introduce an Oxford `and`/`or` continuation; an optional top-level
    /// `, otherwise <else>` tail supplies the else-block. Returns nil when there is
    /// no inline body (the comma-terminated multi-line header is handled upstream).
    private func parseInlineConditional(_ line: SourceLine, file: String) throws -> ConditionalStatementAST? {
        let t = line.statement
        let afterIf = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        guard let sep = inlineConditionSeparator(in: afterIf) else { return nil }
        let condText = String(afterIf[..<sep.lowerBound]).trimmingCharacters(in: .whitespaces)
        var bodyText = String(afterIf[sep.upperBound...]).trimmingCharacters(in: .whitespaces)
        guard !condText.isEmpty, !bodyText.isEmpty else { return nil }

        var elseBlock: ASTBlock? = nil
        if let elseRange = rangeOfMarkerOutsideQuotes(", otherwise ", in: bodyText) {
            let elseText = String(bodyText[elseRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            bodyText = String(bodyText[..<elseRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if !elseText.isEmpty {
                let elseLine = SourceLine(indent: line.indent + 2, text: elseText, raw: line.raw, number: line.number)
                elseBlock = try parseBlock([elseLine], file: file)
            }
        }
        guard !bodyText.isEmpty else { return nil }

        let thenLine = SourceLine(indent: line.indent + 2, text: bodyText, raw: line.raw, number: line.number)
        let thenBlock = try parseBlock([thenLine], file: file)
        return ConditionalStatementAST(
            condition: parseDecisionPredicate(condText),
            thenBlock: thenBlock,
            elseBlock: elseBlock,
            sourceLine: line.number
        )
    }

    /// The comma that separates an inline condition from its action: the first
    /// top-level comma outside double quotes that is not an Oxford `, and`/`, or`
    /// joiner inside the condition.
    private func inlineConditionSeparator(in s: String) -> Range<String.Index>? {
        var inQuotes = false
        var idx = s.startIndex
        while idx < s.endIndex {
            let c = s[idx]
            if c == "\"" {
                inQuotes.toggle()
            } else if c == ",", !inQuotes {
                let after = String(s[s.index(after: idx)...]).drop(while: { $0 == " " }).lowercased()
                if after.hasPrefix("and ") || after.hasPrefix("or ") {
                    idx = s.index(after: idx); continue
                }
                return idx..<s.index(after: idx)
            }
            idx = s.index(after: idx)
        }
        return nil
    }

    // MARK: - Iteration

    private func parseIteration(_ lines: [SourceLine], at i: Int, file: String) throws -> (IterationStatementAST, Int) {
        let line = lines[i]
        let t = line.statement
        // "for each {var} in {collection},"
        var rest = t.lowercased().hasPrefix("for each ") ? String(t.dropFirst(9))
                 : String(t.dropFirst("for every ".count))
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
        let (headPhrase, refinement) = extractIterationRefinement(rest)
        if let inRange = headPhrase.lowercased().range(of: " in ") {
            // Explicit collection: `for each {var} in {collection}`.
            variable   = String(headPhrase[headPhrase.startIndex ..< inRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            collection = exprParser.parse(String(headPhrase[inRange.upperBound...]))
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
        let body = try parseBlock(bodyLines, file: file)
        return (IterationStatementAST(
            mode: .forEach(variable: variable, collection: collection),
            body: body,
            sourceLine: line.number,
            refinement: refinement), j - i)
    }

    // MARK: - Simultaneously

    private func parseSimultaneously(_ lines: [SourceLine], at i: Int, file: String) throws -> (SimultaneouslyStatementAST, Int) {
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

        let body = try parseBlock(bodyLines, file: file)
        let branches = body.statements.map { stmt in
            ASTBlock(statements: [stmt], sourceLine: stmt.sourceLine)
        }
        return (SimultaneouslyStatementAST(branches: branches, sourceLine: line.number), j - i)
    }

    // MARK: - Wait condition

    private func parseWaitCondition(_ s: String) -> WaitConditionAST? {
        // "1 hour", "30 seconds", "2 days"
        if let (amount, unit) = lexicon.parseDuration(s) {
            return .duration(amount, unit)
        }
        // "for signal "name""
        if s.lowercased().hasPrefix(lexicon.grammar.waitSignalIntroducer) {
            let sig = unquote(String(s.dropFirst(lexicon.grammar.waitSignalIntroducer.count)))
            return .signal(sig)
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
    /// Returns a `RecoverStatementAST` whose `attached` field is a placeholder
    /// `phraseInvocation("__recover_placeholder__")`; `parseBlock` replaces it
    /// with the actual preceding statement after this function returns.
    private func parseRecover(_ lines: [SourceLine], at i: Int, file: String) throws -> (RecoverStatementAST, Int) {
        let line = lines[i]
        // The header is just this single line; recover headers are always one line.
        let t = line.statement

        guard t.hasSuffix(":") else {
            let placeholder = StatementAST.phraseInvocation(
                PhraseInvocationAST(words: "__recover_placeholder__", sourceLine: line.number))
            return (RecoverStatementAST(pattern: .any, handler: ASTBlock(statements: []), attached: placeholder, sourceLine: line.number), 1)
        }
        let headerText = String(t.dropLast()).trimmingCharacters(in: .whitespaces)

        // Parse pattern
        let pattern: RecoverPatternAST
        let tl = headerText.lowercased()
        if tl.hasPrefix("recover from ") {
            var rest = String(headerText.dropFirst("recover from ".count)).trimmingCharacters(in: .whitespaces)
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
            let predText = String(headerText.dropFirst("recover where ".count)).trimmingCharacters(in: .whitespaces)
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
        let handlerBlock = try parseBlock(bodyLines, file: file)
        let consumed = j - i

        let placeholder = StatementAST.phraseInvocation(
            PhraseInvocationAST(words: "__recover_placeholder__", sourceLine: line.number))
        return (RecoverStatementAST(pattern: pattern, handler: handlerBlock, attached: placeholder, sourceLine: line.number), consumed)
    }

    // MARK: - Multi-line phrase invocation collector

    /// Fold continuation lines (deeper indent than the header) into a single text
    /// fragment, returning both the joined string and the number of continuation
    /// lines consumed. The header line is *not* counted in `consumed`.
    ///
    /// Two early-exit conditions:
    ///   - If the header line is `.`-terminated (a complete statement), no
    ///     continuation lines are folded — even if subsequent indented lines
    ///     exist. They belong to a structurally separate statement (e.g. an
    ///     attached `recover from …:` block).
    ///   - A subsequent line that begins with a known structural keyword
    ///     (`recover from`, `recover where`, `simultaneously:`) is also a
    ///     boundary — it cannot be a phrase continuation.
    private func collectMultiLineCounted(_ lines: [SourceLine], at i: Int) -> (text: String, consumed: Int) {
        let header = lines[i]
        var result = header.statement
        // `.statement` strips a trailing `.`; consult `text` to detect it.
        if header.text.hasSuffix(".") {
            return (result, 0)
        }
        let parentIndent = header.indent
        var j = i + 1
        var consumed = 0
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent, !isStructuralBoundary(l) {
                result += " " + l.statement
                j += 1
                consumed += 1
            } else {
                break
            }
        }
        return (result, consumed)
    }

    /// Lines that are themselves complete statements rather than phrase
    /// continuations. Folding them into a phrase invocation hides the
    /// statement from the parser entirely.
    private func isStructuralBoundary(_ line: SourceLine) -> Bool {
        let t = line.statement.lowercased()
        return t.hasPrefix("recover from ")
            || t.hasPrefix("recover where ")
            || t == "simultaneously:"
    }

    // MARK: - Utilities

    private func unquote(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        if (t.hasPrefix("\"") && t.hasSuffix("\"")) ||
           (t.hasPrefix("'")  && t.hasSuffix("'")) {
            return String(t.dropFirst().dropLast())
        }
        return t
    }

    /// Convert a multi-word tool name to lowerCamelCase method name.
    func methodize(_ name: String) -> String {
        let words = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !lexicon.articles.contains($0) }
        guard let first = words.first else { return name }
        return first + words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }
}
