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
            try raiseStructural(
                .uncheckablePredicate,
                message: "checklist item \"\(text)\" is not a structurally checkable predicate. Rephrase it as a comparison (e.g. `- [ ] the link count is at least 1`), route the whole list to the planner with a `!!! checklist (( ai-autonomy ))` marker above it, or move it under an `(( inert ))` section to keep it as documentation.",
                range: SourceRange(file: file, line: line.number, column: 1),
                help: "Rephrase as a comparison, add `!!! checklist (( ai-autonomy ))` above the list, or mark the section `(( inert ))`.")
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
        // bind/decide statement.  If one reaches here it is orphaned.
        if t.hasPrefix(codeBlockSentinelPrefix) {
            try raiseStructural(
                .orphanedCodeBlock,
                message: "orphaned fenced code block",
                range: SourceRange(file: file, line: line.number, column: 1),
                help: "Place the fenced block under a `bind name =` or `decide using:` statement that consumes it, or remove it.")
        }

        // A deferred marker error from the (non-throwing) tokenizer — raise it
        // now as a located diagnostic.
        if let message = decodeMarkerError(t) {
            try raiseStructural(
                .unparseableStatement,
                message: message,
                range: SourceRange(file: file, line: line.number, column: 1),
                help: "Fix the block marker syntax (`!!! table (( … ))`, `!!! checklist (( … ))`, etc.) or move it under a recognized section.")
        }

        // Intentional inert consumes (see docs/14_DEVELOPER_EXPERIENCE.md §6.1):
        // table/checklist sentinels that produce no executable statements.
        if t.hasPrefix(tableSentinelPrefix) { return (nil, 1) }
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
        let lower = t.lowercased()
        let statement = lexicon.grammar.statement

        // Explicit judgment markers — the ONLY local path prose reaches the
        // planner: `use judgment to <goal>:` / `with discretion:` /
        // `with autonomy …:`. Checked before topic-label / idiom parsing so a
        // trailing-colon header isn't misread as a label.
        if let (stmt, consumed) = try parseJudgmentMarker(lines, at: i) {
            trace.log(.statement, "L\(line.number) -> judgment")
            return (stmt, consumed)
        }

        // A `for each …` / `for every …:` block header must be recognized before
        // the topic-label rule: a capitalized header like `For every attendee:`
        // otherwise matches `topicLabel` (uppercase, ≤40 chars, letters/spaces)
        // with an empty body and is dropped, orphaning the loop body bullets.
        if lower.hasPrefix(statement.forEachPrefix) || lower.hasPrefix(statement.forEveryPrefix) {
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

        if lower.hasPrefix(statement.otherwisePrefix) {
            let handlerText = String(t.dropFirst(statement.otherwisePrefix.count)).trimmingCharacters(in: .whitespaces)
            let handlerLine = SourceLine(indent: line.indent + 2, text: handlerText, raw: line.raw, number: line.number)
            let handler = try parseBlock([handlerLine], file: file)
            let placeholder = StatementAST.phraseInvocation(PhraseInvocationAST(words: "", sourceLine: line.number))
            return (.recover(RecoverStatementAST(pattern: .any, handler: handler, attached: placeholder, sourceLine: line.number)), 1)
        }

        // "in lenient mode." or "in strict mode."
        if lower == statement.lenientMode { return (.modal(.lenient), 1) }
        if lower == statement.strictMode  { return (.modal(.strict), 1) }

        // "complete." or "complete with reason "X"."
        if lower == statement.complete { return (.complete(CompleteStatementAST(sourceLine: line.number)), 1) }
        if lower.hasPrefix(statement.completeWithReasonPrefix) {
            let rest = String(t.dropFirst(statement.completeWithReasonPrefix.count))
            let reason = unquote(rest)
            return (.complete(CompleteStatementAST(reason: reason, sourceLine: line.number)), 1)
        }

        // "commit." or "commit with label "X"."
        if lower == statement.commit { return (.commit(CommitStatementAST(sourceLine: line.number)), 1) }
        if lower.hasPrefix(statement.commitWithLabelPrefix) {
            let label = unquote(String(t.dropFirst(statement.commitWithLabelPrefix.count)))
            return (.commit(CommitStatementAST(label: label, sourceLine: line.number)), 1)
        }

        // "wait {duration}."
        if lower.hasPrefix(statement.waitPrefix) {
            let rest = String(t.dropFirst(statement.waitPrefix.count))
            if let cond = parseWaitCondition(rest) {
                return (.wait(WaitStatementAST(condition: cond, sourceLine: line.number)), 1)
            }
        }

        // Choice-gate: `ask the user to choose between "A", "B", or "C":`, or
        // the SKILL.md list form with indented quoted/numbered options.
        if let choice = parseChoiceGate(lines, at: i) {
            return (.wait(choice.statement), choice.consumed)
        }

        // "emit {eventID} with ..." (possibly multi-line payload)
        if lower.hasPrefix(statement.emitPrefix) {
            let (emitStmt, extra) = try parseEmit(lines, at: i)
            return (.emit(emitStmt), 1 + extra)
        }

        // "if {condition},"  (conditional, possibly followed by "otherwise,")
        if lower.hasPrefix(statement.ifPrefix) && t.hasSuffix(",") {
            let (cond, consumed) = try parseConditional(lines, at: i, file: file)
            trace.log(.statement, "L\(line.number) -> conditional")
            return (.conditional(cond), consumed)
        }
        // Single-line branch: `if {condition}, {action} [, otherwise {action}].`
        // The comma after the condition already delimits it, so the indented
        // multi-line form is optional — both modalities are supported and read as
        // plain English (`if the entity does not link to the input, add …`).
        if lower.hasPrefix(statement.ifPrefix),
           let single = try parseInlineConditional(line, file: file) {
            return (.conditional(single), 1)
        }
        // Choice branches: `if yes:`, `if no:`, `if the user picks 1:`, etc.
        if let choiceBranch = try parseChoiceBranch(lines, at: i, file: file) {
            return (.conditional(choiceBranch.statement), choiceBranch.consumed)
        }
        if lower.hasPrefix(lexicon.grammar.unlessYouDecideIntroducer) && t.hasSuffix(",") {
            let (cond, consumed) = try parseUnlessDecisionConditional(lines, at: i, file: file)
            return (.conditional(cond), consumed)
        }

        // 3C: "let {name} be {value}." — sugar for `bind`. Used so a description
        // value reads naturally (`let candidates be the stale pages …`). The
        // RHS goes through `parseBindValue`, so a tool-backed relation fetch is
        // hoisted at lowering exactly as for `bind`.
        if lower.hasPrefix(statement.letPrefix),
           case let afterLet = String(t.dropFirst(statement.letPrefix.count)),
           let beRange = afterLet.range(of: statement.letBeMarker) {
            let name = lexicon.stripLeadingArticle(
                String(afterLet[afterLet.startIndex ..< beRange.lowerBound]))
            var valueStr = String(afterLet[beRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if valueStr.hasSuffix(".") { valueStr = String(valueStr.dropLast()) }
            if !name.isEmpty, !valueStr.isEmpty {
                let (expr, extra) = try parseBindValue(valueStr, lines: lines, at: i)
                trace.log(.statement, "L\(line.number) -> letBind")
                return (.bind(BindStatementAST(name: name, value: expr, sourceLine: line.number)), 1 + extra)
            }
            try raiseStructural(
                .unparseableStatement,
                message: "malformed `let … be …` statement",
                range: SourceRange(file: file, line: line.number, column: 1),
                help: "Use `let <name> be <value>.` with both a non-empty name and value.")
        }

        // "bind {name} = invoke {tool} with ..."
        // "rebind {name} = invoke {tool} with ..."
        if lower.hasPrefix(statement.bindPrefix) || lower.hasPrefix(statement.rebindPrefix) {
            let isRebind = lower.hasPrefix(statement.rebindPrefix)
            let rest = String(t.dropFirst(isRebind ? statement.rebindPrefix.count : statement.bindPrefix.count))
            if let eqRange = rest.range(of: "=") {
                let name = String(rest[rest.startIndex ..< eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let valueStr = String(rest[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                // Collect continuation lines (for multi-line invoke args)
                let (expr, extra) = try parseBindValue(valueStr, lines: lines, at: i)
                let stmt = isRebind
                    ? StatementAST.rebind(RebindStatementAST(name: name, value: expr, sourceLine: line.number))
                    : StatementAST.bind(BindStatementAST(name: name, value: expr, sourceLine: line.number))
                trace.log(.statement, "L\(line.number) -> \(isRebind ? "rebind" : "bind")")
                return (stmt, 1 + extra)
            }
            try raiseStructural(
                .unparseableStatement,
                message: "malformed `\(isRebind ? "rebind" : "bind")` assignment (expected `=`)",
                range: SourceRange(file: file, line: line.number, column: 1),
                help: "Use `bind <name> = <value>.` or `rebind <name> = <value>.`; an empty RHS may be followed by an indented fenced code block.")
        }

        // B2: "while {condition},"
        if lower.hasPrefix(statement.whilePrefix) && t.hasSuffix(",") {
            let condText = String(t.dropFirst(statement.whilePrefix.count).dropLast()).trimmingCharacters(in: .whitespaces)
            guard !condText.isEmpty else {
                try raiseStructural(.unparseableStatement, message: "malformed `while` block header (empty condition)",
                                    range: SourceRange(file: file, line: line.number, column: 1),
                                    help: "Use `while <condition>,` with a non-empty condition and an indented body.")
            }
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
            trace.log(.statement, "L\(line.number) -> while")
            return (.iteration(IterationStatementAST(mode: .whileCondition(cond), body: body, sourceLine: line.number)), j - i)
        }

        // B2: "until {condition},"
        if lower.hasPrefix(statement.untilPrefix) && t.hasSuffix(",") {
            let condText = String(t.dropFirst(statement.untilPrefix.count).dropLast()).trimmingCharacters(in: .whitespaces)
            guard !condText.isEmpty else {
                try raiseStructural(.unparseableStatement, message: "malformed `until` block header (empty condition)",
                                    range: SourceRange(file: file, line: line.number, column: 1),
                                    help: "Use `until <condition>,` with a non-empty condition and an indented body.")
            }
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
            trace.log(.statement, "L\(line.number) -> until")
            return (.iteration(IterationStatementAST(mode: .untilCondition(cond), body: body, sourceLine: line.number)), j - i)
        }

        // "simultaneously:" with each top-level body statement as a branch.
        if lower == statement.simultaneouslyHeader {
            let (sim, consumed) = try parseSimultaneously(lines, at: i, file: file)
            return (.simultaneously(sim), consumed)
        }

        // "recover from {pattern}:"  or  "recover where {predicate}:"
        let tl = lower
        if tl.hasPrefix(statement.recoverFromPrefix) || tl.hasPrefix(statement.recoverWherePrefix) {
            let (rec, consumed) = try parseRecover(lines, at: i, file: file)
            trace.log(.statement, "L\(line.number) -> recover")
            // The `attached` field is a placeholder — `parseBlock` will replace it
            // with the actual preceding statement after the loop iteration returns.
            return (.recover(rec), consumed)
        }

        // Malformed recover introducer without a parseable pattern.
        if tl.hasPrefix(statement.recoverPrefix) {
            try raiseStructural(
                .unparseableStatement,
                message: "malformed `recover` header",
                range: SourceRange(file: file, line: line.number, column: 1),
                help: "Use `recover from \"<code>\":` or `recover where <predicate>:` with an indented handler body.")
        }

        if let every = parseEveryEach(line) {
            return (.iteration(every), 1)
        }

        // Everything else is a phrase invocation (or multi-line phrase).
        // Continuation lines (deeper indent, no period) are folded into the
        // invocation text and reported in `consumed` so `parseBlock` skips them.
        let (folded, contConsumed) = collectMultiLineCounted(lines, at: i)
        trace.log(.statement, "L\(line.number) -> phraseInvocation")
        return (.phraseInvocation(PhraseInvocationAST(words: folded, sourceLine: line.number)),
                1 + contConsumed)
    }

    /// Report a structural diagnostic through the batch engine (if any) and throw
    /// so engine-less callers still fail fast.
    private func raiseStructural(_ code: DiagnosticCode, message: String,
                                 range: SourceRange, help: String) throws -> Never {
        let diag = Diagnostic.structural(code, message: message, range: range, help: help)
        if let diagnostics { diagnostics.report(diag) }
        throw CompilerError.diagnostics([diag])
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

        // Operational Markdown often writes a labelled step around a single
        // command span: `Verify: `gbrain doctor --json`` or
        // `**Sync** - `gbrain sync``. Treat that as the same deterministic
        // shell command, carrying the surrounding prose as the source annotation.
        if let embeddedShell = embeddedBacktickedCommand(line) {
            return [embeddedShell]
        }

        // A collapsed Markdown table sentinel expands to per-row statements
        // (decision branches, a data-table binding, or nothing for inert).
        if let tableStatements = try tableStatements(line, file: file) {
            return tableStatements
        }

        guard statement.lowercased().hasPrefix(lexicon.grammar.statement.doPrefix) else { return nil }
        let rest = String(statement.dropFirst(lexicon.grammar.statement.doPrefix.count)).trimmingCharacters(in: .whitespaces)
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
        let collectUntilNextHeading = lower.hasPrefix(lexicon.grammar.judgmentFollowCollectPrefix)

        func collectBody() -> (text: [String], consumed: Int) {
            var bodyLines: [String] = []
            var j = i + 1
            while j < lines.count {
                let l = lines[j]
                if collectUntilNextHeading {
                    if l.headingLevel != nil { break }
                    if l.isEmpty || l.isComment { j += 1; continue }
                    bodyLines.append(l.statement)
                    j += 1
                    continue
                }
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
    /// `ask the user to choose between "A", "B", or "C":` (trailing `:` optional),
    /// or the Markdown option-list form:
    ///
    ///   ask the user to choose between:
    ///       1. Supabase
    ///       2. BYO Postgres
    ///
    /// Numbered options use the number as the runtime selection value so
    /// follow-up branches like `if the user picks 1:` can route deterministically.
    private func parseChoiceGate(_ lines: [SourceLine], at i: Int) -> (statement: WaitStatementAST, consumed: Int)? {
        let line = lines[i]
        let t = line.statement
        let lower = t.lowercased()
        let markers = lexicon.grammar.choiceGateIntroducers
        let marker = markers.first(where: { lower.hasPrefix($0) })
            ?? markers.map { $0.trimmingCharacters(in: .whitespaces) }
                .first(where: { lower == $0 || lower == $0 + ":" })
        guard let marker else { return nil }
        let rest = String(t.dropFirst(marker.count))
        var options = doubleQuotedSpans(in: rest)
        var consumed = 1
        if options.isEmpty {
            let collected = collectChoiceOptions(lines, after: i)
            options = collected.options
            consumed += collected.consumed
        }
        guard !options.isEmpty else { return nil }
        return (WaitStatementAST(
            condition: .choice(prompt: t, options: options),
            sourceLine: line.number
        ), consumed)
    }

    private func collectChoiceOptions(_ lines: [SourceLine], after i: Int) -> (options: [String], consumed: Int) {
        let parentIndent = lines[i].indent
        var options: [String] = []
        var consumed = 0
        var j = i + 1
        while j < lines.count {
            let line = lines[j]
            if line.isEmpty || line.isComment { j += 1; consumed += 1; continue }
            guard line.indent > parentIndent else { break }
            if let option = choiceOptionValue(line.raw) ?? choiceOptionValue(line.statement) {
                options.append(option)
                j += 1
                consumed += 1
                continue
            }
            break
        }
        return (options, consumed)
    }

    private func choiceOptionValue(_ text: String) -> String? {
        let raw = text.trimmingCharacters(in: .whitespaces)
        if let quoted = doubleQuotedSpans(in: raw).first { return quoted }
        if let numeric = leadingChoiceNumber(in: raw) { return numeric }
        let stripped = stripMarkdownListMarker(raw)
        return stripped.isEmpty ? nil : stripped
    }

    private func leadingChoiceNumber(in s: String) -> String? {
        var digits = ""
        var idx = s.startIndex
        while idx < s.endIndex, s[idx].isNumber {
            digits.append(s[idx])
            idx = s.index(after: idx)
        }
        guard !digits.isEmpty, idx < s.endIndex, s[idx] == "." || s[idx] == ")" else { return nil }
        return digits
    }

    private func parseChoiceBranch(_ lines: [SourceLine], at i: Int, file: String) throws
        -> (statement: ConditionalStatementAST, consumed: Int)? {
        let line = lines[i]
        let t = line.statement.trimmingCharacters(in: .whitespaces)
        let statement = lexicon.grammar.statement
        guard t.lowercased().hasPrefix(statement.ifPrefix), t.hasSuffix(":") else { return nil }
        let label = String(t.dropFirst(statement.ifPrefix.count).dropLast()).trimmingCharacters(in: .whitespaces)
        guard let selected = choiceBranchSelection(label) else { return nil }

        let parentIndent = line.indent
        var bodyLines: [SourceLine] = []
        var j = i + 1
        while j < lines.count {
            let l = lines[j]
            if l.isEmpty || l.isComment { j += 1; continue }
            if l.indent > parentIndent {
                bodyLines.append(l)
                j += 1
            } else {
                break
            }
        }
        let body = try parseBlock(bodyLines, file: file)
        let condition = exprParser.parse("\(lexicon.grammar.choiceBranchLabels.choiceConditionPrefix)\"\(selected)\"")
        return (ConditionalStatementAST(condition: condition, thenBlock: body, elseBlock: nil,
                                        sourceLine: line.number), j - i)
    }

    private func choiceBranchSelection(_ label: String) -> String? {
        let lower = label.lowercased()
        let labels = lexicon.grammar.choiceBranchLabels
        if labels.yesLabels.contains(lower) { return "yes" }
        if labels.noLabels.contains(lower) { return "no" }
        for prefix in labels.pickPrefixes where lower.hasPrefix(prefix) {
            let value = String(label.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
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
        trace.log(.statement, "table \(mode) \(table.rows.count) row(s), \(table.header.count) column(s) @L\(line.number)")
        let parser = TableParser(lexicon: lexicon, trace: trace)
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
            return [try dataTableBinding(table, name: name, line: line, file: file)]
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
    private func dataTableBinding(_ table: TableParser.ParsedTable, name: String?, line: SourceLine, file: String) throws -> StatementAST {
        let columns = table.header.map(parseDataColumnHeader)
        let fields = columns.map(\.name)
        let rows = try table.rows.enumerated().map { rowIndex, row -> [ExpressionAST] in
            try (0 ..< fields.count).map { idx in
                try dataCellValue(
                    idx < row.count ? row[idx] : "",
                    type: columns[idx].type,
                    row: rowIndex + 1,
                    column: fields[idx],
                    line: line,
                    file: file
                )
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
    private func parseDataColumnHeader(_ raw: String) -> (name: String, type: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(")"), let open = trimmed.lastIndex(of: "(") else {
            return (trimmed, nil)
        }
        let name = String(trimmed[trimmed.startIndex..<open]).trimmingCharacters(in: .whitespaces)
        let type = String(trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)])
            .trimmingCharacters(in: .whitespaces)
        return (name.isEmpty ? trimmed : name, type.isEmpty ? nil : type)
    }

    private func dataCellValue(_ raw: String, type: String?, row: Int, column: String, line: SourceLine, file: String) throws -> ExpressionAST {
        let cell = raw.trimmingCharacters(in: .whitespaces)
        if cell.isEmpty { return .literal(.string("")) }
        if cell.hasPrefix("\"") && cell.hasSuffix("\"") && cell.count >= 2 {
            return .literal(.string(String(cell.dropFirst().dropLast())))
        }
        let parsed = exprParser.parse(cell)
        if let type {
            try validateDataCell(parsed, raw: cell, type: type, row: row, column: column, line: line, file: file)
        }
        if case .literal = parsed { return parsed }
        return .literal(.string(cell))
    }

    private func validateDataCell(_ parsed: ExpressionAST, raw: String, type: String, row: Int, column: String, line: SourceLine, file: String) throws {
        let lower = type.lowercased()
        let ok: Bool
        switch lower {
        case "string", "text":
            ok = true
        case "number":
            if case .literal(.integer) = parsed { ok = true }
            else if case .literal(.double) = parsed { ok = true }
            else { ok = false }
        case "money":
            if case .literal(.money) = parsed { ok = true } else { ok = false }
        case "boolean", "bool":
            if case .literal(.boolean) = parsed { ok = true } else { ok = false }
        case "duration":
            if case .literal(.duration) = parsed { ok = true } else { ok = false }
        default:
            ok = true
        }
        guard ok else {
            try raiseStructural(
                .invalidTableCell,
                message: "table cell at row \(row), column `\(column)` expected \(type), got `\(raw)`",
                range: SourceRange(file: file, line: line.number, column: 1),
                help: "Fix the cell value to match the column type or remove the `(Type)` annotation from the header.")
        }
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

    /// A line with exactly one backtick command span plus prose, e.g.
    /// `Verify: `gbrain doctor --json``. This covers common SKILL.md numbered
    /// and labelled command steps after `IndentTokenizer` strips list markers.
    private func embeddedBacktickedCommand(_ line: SourceLine) -> StatementAST? {
        let raw = line.statement.trimmingCharacters(in: .whitespaces)
        guard !startsWithPrimitiveStatement(raw) else { return nil }
        let spans = Self.backtickSpans(in: raw)
        guard spans.count == 1 else { return nil }
        let span = spans[0]
        let command = String(raw[span.lowerBound..<span.upperBound]).trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty, commandLooksShellLike(command) else { return nil }

        var annotationSource = raw
        annotationSource.replaceSubrange(span.fullRange(in: raw), with: "")
        let annotation = cleanCommandAnnotation(annotationSource)
        return .phraseInvocation(PhraseInvocationAST(
            words: encodeShellCommand(command),
            annotation: annotation.isEmpty ? nil : annotation,
            sourceLine: line.number
        ))
    }

    private func startsWithPrimitiveStatement(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        return lexicon.grammar.statement.primitivePrefixes.contains { lower.hasPrefix($0) }
    }

    private struct BacktickSpan {
        let lowerBound: String.Index
        let upperBound: String.Index

        func fullRange(in s: String) -> ClosedRange<String.Index> {
            s.index(before: lowerBound)...upperBound
        }
    }

    private static func backtickSpans(in s: String) -> [BacktickSpan] {
        var spans: [BacktickSpan] = []
        var open: String.Index? = nil
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "`" {
                if let start = open {
                    spans.append(BacktickSpan(lowerBound: s.index(after: start), upperBound: i))
                    open = nil
                } else {
                    open = i
                }
            }
            i = s.index(after: i)
        }
        return spans
    }

    private func commandLooksShellLike(_ command: String) -> Bool {
        command.contains(" ") || command.contains("/") || command.contains(".") || command.contains("-")
    }

    private func cleanCommandAnnotation(_ raw: String) -> String {
        var s = raw
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespaces)
        while let last = s.last, last == ":" || last == "-" || last == "\u{2014}" || last == "\u{2013}" {
            s.removeLast()
            s = s.trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    private func stripMarkdownListMarker(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("- ") || s.hasPrefix("* ") {
            return String(s.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        var digits = ""
        var idx = s.startIndex
        while idx < s.endIndex, s[idx].isNumber {
            digits.append(s[idx])
            idx = s.index(after: idx)
        }
        if !digits.isEmpty, idx < s.endIndex, s[idx] == "." || s[idx] == ")" {
            let after = s.index(after: idx)
            if after == s.endIndex || s[after].isWhitespace {
                s = String(s[after...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return s
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
        let markers = lexicon.grammar.passiveModalityMarkers
        for marker in markers {
            guard let range = text.range(of: marker, options: [.caseInsensitive]) else { continue }
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
        for marker in lexicon.grammar.iterationMarkers.embeddedEachMarkers {
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
        if let r = rangeOfMarkerOutsideQuotes(lexicon.grammar.iterationMarkers.whoseMarker, in: work) {
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
        if firstScan.lowercased().hasPrefix(lexicon.grammar.iterationMarkers.firstPrefix) {
            let after = String(firstScan.dropFirst(lexicon.grammar.iterationMarkers.firstPrefix.count)).trimmingCharacters(in: .whitespaces)
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
                   text[i...].lowercased().hasPrefix(lexicon.grammar.merconfig.withMarker) {
                    inInvokeArgs = true
                }

                // `, and ` is a chain terminator even when we're inside an
                // invoke argument list — `and` introduces the next element.
                if depth == 0,
                   text[i...].lowercased().hasPrefix(lexicon.grammar.iterationMarkers.chainCommaAndMarker) {
                    parts.append(cleanChainPart(current))
                    current = ""
                    inInvokeArgs = false
                    i = text.index(i, offsetBy: lexicon.grammar.iterationMarkers.chainCommaAndMarker.count)
                    continue
                }
                if depth == 0,
                   text[i...].lowercased().hasPrefix(lexicon.grammar.iterationMarkers.chainAndMarker) {
                    parts.append(cleanChainPart(current))
                    current = ""
                    inInvokeArgs = false
                    i = text.index(i, offsetBy: lexicon.grammar.iterationMarkers.chainAndMarker.count)
                    continue
                }
                if depth == 0,
                   text[i...].lowercased().hasPrefix(lexicon.grammar.iterationMarkers.chainThenMarker) {
                    parts.append(cleanChainPart(current))
                    current = ""
                    inInvokeArgs = false
                    i = text.index(i, offsetBy: lexicon.grammar.iterationMarkers.chainThenMarker.count)
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
        if s.lowercased().hasPrefix(lexicon.grammar.iterationMarkers.cleanupAndPrefix) {
            s = String(s.dropFirst(lexicon.grammar.iterationMarkers.cleanupAndPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        if s.lowercased().hasPrefix(lexicon.grammar.iterationMarkers.cleanupThenPrefix) {
            s = String(s.dropFirst(lexicon.grammar.iterationMarkers.cleanupThenPrefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return s
    }

    private func camelize(_ raw: String) -> String {
        IdentifierNaming.lowerCamelSplittingHyphen(raw)
    }

    private func rangeOfMarkerOutsideQuotes(_ marker: String, in text: String) -> Range<String.Index>? {
        QuoteAwareScanner.rangeOfMarker(marker, in: text, caseInsensitive: true)
    }

    // MARK: - Bind value (invoke expression or literal)

    private func parseBindValue(_ s: String, lines: [SourceLine], at i: Int) throws -> (ExpressionAST, Int) {
        if s.trimmingCharacters(in: .whitespaces).isEmpty {
            var j = i + 1
            while j < lines.count {
                let l = lines[j]
                if l.isEmpty || l.isComment { j += 1; continue }
                if l.statement.hasPrefix(codeBlockSentinelPrefix) {
                    return (exprParser.parseAtom(l.statement), j - i)
                }
                break
            }
        }

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

        if s.lowercased().hasPrefix(lexicon.grammar.statement.invokePrefix) {
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
        trace.log(.statement, "buildInvokeExpr start: \(ParserTrace.short(s))")
        var rest = s
        if rest.lowercased().hasPrefix(lexicon.grammar.statement.invokePrefix) {
            rest = String(rest.dropFirst(lexicon.grammar.statement.invokePrefix.count))
        }
        trace.log(.statement, "buildInvokeExpr rest: \(ParserTrace.short(rest))")

        let toolName: String
        let args: [(String, ExpressionAST)]

        if let withRange = rest.range(of: lexicon.grammar.merconfig.withMarker, options: [.caseInsensitive]) {
            toolName = String(rest[rest.startIndex ..< withRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let argStr = String(rest[withRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            trace.log(.statement, "buildInvokeExpr args: \(ParserTrace.short(argStr))")
            args = parseArgList(argStr)
        } else {
            toolName = rest.trimmingCharacters(in: .whitespaces)
            args = []
        }
        trace.log(.statement, "buildInvokeExpr tool: \(toolName) args=\(args.count)")

        // Resolve tool method name
        let methodName = symbols?.tool(fromWords: toolName)?.methodName ?? methodize(toolName)
        trace.log(.statement, "buildInvokeExpr method: \(methodName)")
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
            trace.log(.statement, "parseArgList key=\(key) val=\(ParserTrace.short(val))")
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
        var rest = String(t.dropFirst(lexicon.grammar.statement.emitPrefix.count)).trimmingCharacters(in: .whitespaces)

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

        if let withRange = rest.range(of: lexicon.grammar.merconfig.withMarker, options: [.caseInsensitive]) {
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
        if condText.lowercased().hasPrefix(lexicon.grammar.statement.ifPrefix) {
            condText = String(condText.dropFirst(lexicon.grammar.statement.ifPrefix.count))
        }
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

        // Check for the grammar's `otherwise` branch marker.
        var elseBlock: ASTBlock? = nil
        var elseConsumed = j
        if j < lines.count && lines[j].isContent {
            let nextText = lines[j].statement.lowercased()
            let keywords = lexicon.grammar.statement
            if nextText == keywords.otherwiseKeyword || nextText == keywords.otherwiseCommaKeyword {
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

    private func parseIteration(_ lines: [SourceLine], at i: Int, file: String) throws -> (IterationStatementAST, Int) {
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
        let (headPhrase, refinement) = extractIterationRefinement(rest)
        if let inRange = headPhrase.range(of: lexicon.grammar.iterationMarkers.collectionInMarker, options: [.caseInsensitive]) {
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
        let statement = lexicon.grammar.statement
        return t.hasPrefix(statement.recoverFromPrefix)
            || t.hasPrefix(statement.recoverWherePrefix)
            || t == statement.simultaneouslyHeader
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
        IdentifierNaming.methodize(name, stopwords: lexicon.articles)
    }
}
