import Foundation
import MeridianRuntime

// MARK: - StatementParser
//
// Parses a flat list of SourceLines (already indent-filtered) into an ASTBlock.
// Called by both MerConfigParser (phrase bodies) and MeridianParser (workflow bodies).

public struct StatementParser {

    public let symbols: SymbolTable?
    let lexicon: EnglishLexicon
    /// Optional rulebook-driven desugar engine. When present, surface idioms are
    /// rewritten to canonical statements before the parser's own fallback runs.
    /// Nil for plain `.meridian`/`.merconfig` parsing (engine is a no-op anyway
    /// when the rulebook is empty).
    private let rewriteEngine: RewriteEngine?
    /// Optional batch collector. When present, `parseBlock` recovers from a
    /// thrown `CompilerError` per statement (collect + skip the line) so a file
    /// with several malformed statements reports them all at once.
    private let diagnostics: DiagnosticEngine?

    var exprParser: ExpressionParser {
        ExpressionParser(symbols: symbols, lexicon: lexicon)
    }

    /// Shared with the `for each <adjectives> <singular kind> <verb clause>:`
    /// bare iteration header (`parseIteration`), which must decompose a
    /// restricted head the same way quantifiers/explicit collections do
    /// rather than swallowing it into one opaque state-key identifier.
    var descriptionGrammar: DescriptionGrammar {
        let parser = exprParser
        return DescriptionGrammar(lexicon: lexicon, symbols: symbols, atom: parser.parseAtom, recurse: parser.parse)
    }

    public init(symbols: SymbolTable?,
                lexicon: EnglishLexicon = .default,
                rewriteEngine: RewriteEngine? = nil,
                diagnostics: DiagnosticEngine? = nil) {
        self.symbols = symbols
        self.lexicon = lexicon
        self.rewriteEngine = rewriteEngine
        self.diagnostics = diagnostics
    }

    public func parseBlock(_ lines: [SourceLine], sourceFile: String = "") throws -> ASTBlock {
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
                let resolved = try anaphora.resolve(content[i].statement, referents: referents, file: sourceFile, line: content[i].number)
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
            if let expanded = try checklistStatements(content[i], sourceFile: sourceFile) {
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
                let stmt = try checklistInvariant(content[i], sourceFile: sourceFile)
                appendStatement(stmt, to: &stmts)
                recordReferents(from: stmt, into: &referents)
                i += 1
                continue
            }
            if let expanded = try parseInlineChain(content[i], sourceFile: sourceFile), !expanded.isEmpty {
                for s in expanded {
                    appendStatement(s, to: &stmts)
                    recordReferents(from: s, into: &referents)
                }
                i += 1
                continue
            }
            let (stmt, consumed) = try parseStatement(content, at: i, sourceFile: sourceFile)
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


    func parseStatement(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (StatementAST?, Int) {
        let trace = ParserTrace.current
        let line = lines[i]
        let t = line.statement
        trace.log(.statement, "L\(line.number): \(ParserTrace.short(t))")

        // B6: Bare code-block sentinel lines are always consumed by the preceding
        // bind/decide statement.  If one reaches here it is orphaned.
        if t.hasPrefix(codeBlockSentinelPrefix) {
            try raiseStructural(
                .orphanedCodeBlock,
                message: "orphaned fenced code block",
                range: SourceRange(file: sourceFile, line: line.number, column: 1),
                help: "Place the fenced block under a `bind name =` or `decide using:` statement that consumes it, or remove it.")
        }

        // A deferred marker error from the (non-throwing) tokenizer — raise it
        // now as a located diagnostic.
        if let message = decodeMarkerError(t) {
            try raiseStructural(
                .unparseableStatement,
                message: message,
                range: SourceRange(file: sourceFile, line: line.number, column: 1),
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
                return try parseStatementWithoutRewrite(newLines, at: i, sourceFile: sourceFile)
            }
        }

        return try parseStatementWithoutRewrite(lines, at: i, sourceFile: sourceFile)
    }

    /// The body of statement parsing, run after the rulebook desugar hook.
    /// Separated so the hook can re-enter parsing exactly once on the rewritten
    /// line without risking an infinite loop.
    func parseStatementWithoutRewrite(_ lines: [SourceLine], at i: Int, sourceFile: String) throws -> (StatementAST?, Int) {
        let trace = ParserTrace.current
        let line = lines[i]
        let t = line.statement
        let lower = t.lowercased()
        let statement = lexicon.grammar.statement

        // Explicit judgment markers — the ONLY local path prose reaches the
        // planner: `use judgment to <goal>:` / `with discretion:` /
        // `with autonomy …:`. Checked before topic-label / idiom parsing so a
        // trailing-colon header isn't misread as a label.
        if let (stmt, consumed) = try parseJudgmentMarker(lines, at: i, sourceFile: sourceFile) {
            trace.log(.statement, "L\(line.number) -> judgment")
            return (stmt, consumed)
        }

        // A `for each …` / `for every …:` block header must be recognized before
        // the topic-label rule: a capitalized header like `For every attendee:`
        // otherwise matches `topicLabel` (uppercase, ≤40 chars, letters/spaces)
        // with an empty body and is dropped, orphaning the loop body bullets.
        // `parseIteration` only throws when its body contains a genuinely
        // malformed statement — that diagnostic must surface, not be silently
        // swallowed and re-routed to a misleading `topicLabel`/other match.
        if lower.hasPrefix(statement.forEachPrefix) || lower.hasPrefix(statement.forEveryPrefix) {
            let (iter, consumed) = try parseIteration(lines, at: i, sourceFile: sourceFile)
            trace.log(.statement, "L\(line.number) -> iteration (for each/for every)")
            return (.iteration(iter), consumed)
        }

        if let (label, rest) = StatementParser.topicLabel(in: t) {
            guard !rest.isEmpty else {
                try raiseStructural(
                    .unparseableStatement,
                    message: "topic label \"\(label):\" has no statement after the colon",
                    range: SourceRange(file: sourceFile, line: line.number, column: 1),
                    help: "Add a statement after the label's colon (e.g. `\(label): complete.`), or remove the empty label.")
            }
            let labelledLine = SourceLine(indent: line.indent, text: rest, raw: line.raw, number: line.number)
            let (stmt, consumed) = try parseStatement([labelledLine] + Array(lines.dropFirst(i + 1)), at: 0, sourceFile: sourceFile)
            guard let stmt else {
                try raiseStructural(
                    .unparseableStatement,
                    message: "topic label \"\(label):\" wraps content that produces no statement",
                    range: SourceRange(file: sourceFile, line: line.number, column: 1),
                    help: "A topic label must wrap a real statement (e.g. `\(label): complete.`); it cannot wrap a table/checklist sentinel or other inert content.")
            }
            trace.log(.statement, "L\(line.number) -> labelled")
            return (.labelled(LabelledStatementAST(label: label, statement: stmt, sourceLine: line.number)), consumed)
        }

        // `assert <condition> otherwise:` — a colon-terminated block header
        // (like `if it is unknown whether:` / guarded-fence headers), not the
        // sibling-line `otherwise,`/`otherwise:` a `conditional` attaches.
        // Checked before the generic idiom fallback so the whole header,
        // otherwise-colon included, isn't swallowed as the assert's condition
        // text (see AssertStatementAST.otherwise / D-DX pitfall: this field
        // was declared and threaded through IR/codegen/verbalizer but never
        // actually populated by any parser production).
        if let (assertion, consumed) = try parseAssertWithOtherwise(lines, at: i, sourceFile: sourceFile) {
            trace.log(.statement, "L\(line.number) -> assert otherwise:")
            return (.assertStmt(assertion), consumed)
        }

        if let idiom = try parseEnglishIdiom(line, sourceFile: sourceFile) {
            trace.log(.statement, "L\(line.number) -> englishIdiom")
            return (idiom, 1)
        }

        if let conditional = try parseSuffixConditional(line, sourceFile: sourceFile) {
            trace.log(.statement, "L\(line.number) -> suffixConditional")
            return (.conditional(conditional), 1)
        }

        if lower.hasPrefix(statement.otherwisePrefix) {
            let handlerText = String(t.dropFirst(statement.otherwisePrefix.count)).trimmingCharacters(in: .whitespaces)
            let handlerLine = SourceLine(indent: line.indent + 2, text: handlerText, raw: line.raw, number: line.number)
            let handler = try parseBlock([handlerLine], sourceFile: sourceFile)
            let placeholder = StatementAST.phraseInvocation(PhraseInvocationAST(words: "", sourceLine: line.number))
            trace.log(.statement, "L\(line.number) -> otherwise (bare recover handler)")
            return (.recover(RecoverStatementAST(pattern: .any, handler: handler, attached: placeholder, sourceLine: line.number)), 1)
        }

        // "in lenient mode." or "in strict mode."
        if lower == statement.lenientMode {
            trace.log(.statement, "L\(line.number) -> modal(lenient)")
            return (.modal(.lenient), 1)
        }
        if lower == statement.strictMode {
            trace.log(.statement, "L\(line.number) -> modal(strict)")
            return (.modal(.strict), 1)
        }

        // "complete." or "complete with reason "X"."
        if lower == statement.complete {
            trace.log(.statement, "L\(line.number) -> complete")
            return (.complete(CompleteStatementAST(sourceLine: line.number)), 1)
        }
        if lower.hasPrefix(statement.completeWithReasonPrefix) {
            let rest = String(t.dropFirst(statement.completeWithReasonPrefix.count))
            let reason = unquote(rest)
            trace.log(.statement, "L\(line.number) -> complete(reason:)")
            return (.complete(CompleteStatementAST(reason: reason, sourceLine: line.number)), 1)
        }

        // "commit." or "commit with label "X"."
        if lower == statement.commit {
            trace.log(.statement, "L\(line.number) -> commit")
            return (.commit(CommitStatementAST(sourceLine: line.number)), 1)
        }
        if lower.hasPrefix(statement.commitWithLabelPrefix) {
            let label = unquote(String(t.dropFirst(statement.commitWithLabelPrefix.count)))
            trace.log(.statement, "L\(line.number) -> commit(label:)")
            return (.commit(CommitStatementAST(label: label, sourceLine: line.number)), 1)
        }

        // "wait {duration}." — also accepts the comma-continuation form
        // (`wait for signal "x",` as one step of a still-open if/otherwise
        // branch) the way `if`/`while`/`until` already do; a trailing comma
        // left in front of `parseWaitCondition`'s own quote-stripping made
        // `unquote` see `"x",` (last char is `,`, not `"`) and give up,
        // leaving the raw quotes in the signal id to reach the emitter
        // unescaped (`.signal(""x",")`, invalid Swift).
        if lower.hasPrefix(statement.waitPrefix) {
            var rest = String(t.dropFirst(statement.waitPrefix.count))
            if rest.hasSuffix(",") { rest = String(rest.dropLast()) }
            var timeoutRecover: ASTBlock?
            if let recoverRange = rest.range(of: statement.waitRecoverOnTimeoutMarker, options: .caseInsensitive) {
                let head = String(rest[..<recoverRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                rest = head
                if t.hasSuffix(":") {
                    let parentIndent = line.indent
                    var bodyLines: [SourceLine] = []
                    var j = i + 1
                    while j < lines.count {
                        let l = lines[j]
                        if l.isEmpty || l.isComment { j += 1; continue }
                        if l.indent > parentIndent { bodyLines.append(l); j += 1 } else { break }
                    }
                    timeoutRecover = try parseBlock(bodyLines, sourceFile: sourceFile)
                }
            }
            var timeout: (Double, TimeUnitAST)?
            if let timeoutRange = rest.range(of: statement.waitTimeoutMarker, options: .caseInsensitive) {
                let head = String(rest[..<timeoutRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let durationText = String(rest[timeoutRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if let (value, unit) = lexicon.parseDuration(durationText) {
                    timeout = (value, unit)
                }
                rest = head
            }
            if let cond = parseWaitCondition(rest) {
                trace.log(.statement, "L\(line.number) -> wait")
                return (.wait(WaitStatementAST(
                    condition: cond, timeout: timeout, timeoutRecover: timeoutRecover,
                    sourceLine: line.number)), 1)
            }
        }

        // Choice-gate: `ask the user to choose between "A", "B", or "C":`, or
        // the SKILL.md list form with indented quoted/numbered options.
        if let choice = parseChoiceGate(lines, at: i) {
            trace.log(.statement, "L\(line.number) -> choiceGate")
            return (.wait(choice.statement), choice.consumed)
        }

        // Fallback chain (Phase 2 idiom): `try the following in order until
        // one succeeds:` + an ordered list of steps → an N-deep `recover`
        // nesting (each step's handler is "try the next step").
        if let chain = try parseFallbackChain(lines, at: i, sourceFile: sourceFile) {
            trace.log(.statement, "L\(line.number) -> fallbackChain")
            return (chain.statement, chain.consumed)
        }

        // "emit {eventID} with ..." (possibly multi-line payload)
        if lower.hasPrefix(statement.emitPrefix) {
            let (emitStmt, extra) = try parseEmit(lines, at: i)
            trace.log(.statement, "L\(line.number) -> emit")
            return (.emit(emitStmt), 1 + extra)
        }

        // "branch on {subject}:" — match-form IR surface (Wave 7 verbalizer).
        if lower.hasPrefix(statement.branchOnPrefix) && t.hasSuffix(":") {
            let (match, consumed) = try parseMatchBranch(lines, at: i, sourceFile: sourceFile)
            trace.log(.statement, "L\(line.number) -> matchBranch")
            return (.matchBranch(match), consumed)
        }

        // "if {condition},"  (conditional, possibly followed by "otherwise,")
        if lower.hasPrefix(statement.ifPrefix) && t.hasSuffix(",") {
            let (cond, consumed) = try parseConditional(lines, at: i, sourceFile: sourceFile)
            trace.log(.statement, "L\(line.number) -> conditional")
            return (.conditional(cond), consumed)
        }
        // `unless you decide that <question>,` — discretion negation (more specific
        // than the generic `unless {condition},` block form below).
        if lower.hasPrefix(lexicon.grammar.unlessYouDecideIntroducer) && t.hasSuffix(",") {
            let (cond, consumed) = try parseUnlessDecisionConditional(lines, at: i, sourceFile: sourceFile)
            trace.log(.statement, "L\(line.number) -> unlessDecisionConditional")
            return (.conditional(cond), consumed)
        }
        // `unless {condition},` — D11 block conditional (negated predicate).
        if lower.hasPrefix(statement.unlessPrefix) && t.hasSuffix(",") {
            let (cond, consumed) = try parseUnlessConditional(lines, at: i, sourceFile: sourceFile)
            trace.log(.statement, "L\(line.number) -> unlessConditional")
            return (.conditional(cond), consumed)
        }
        // Guarded fence (Phase 2 idiom): "If {condition}, run:" immediately
        // followed by a fenced shell code-block wraps the block's `shell.run`
        // invokes in a `branch`. SKILL.md bodies are flat (the fence is never
        // indented under the header), so this is a 2-line structural
        // production rather than `parseConditional`'s indented-body form.
        if lower.hasPrefix(statement.ifPrefix),
           let guardedFence = try parseGuardedFence(lines, at: i) {
            trace.log(.statement, "L\(line.number) -> guardedFence")
            return (.conditional(guardedFence.statement), guardedFence.consumed)
        }
        // Single-line branch: `if {condition}, {action} [, otherwise {action}].`
        // The comma after the condition already delimits it, so the indented
        // multi-line form is optional — both modalities are supported and read as
        // plain English (`if the entity does not link to the input, add …`).
        if lower.hasPrefix(statement.ifPrefix),
           let single = try parseInlineConditional(line, sourceFile: sourceFile) {
            trace.log(.statement, "L\(line.number) -> inlineConditional")
            return (.conditional(single), 1)
        }
        if lower.hasPrefix(statement.unlessPrefix),
           let single = try parseInlineUnlessConditional(line, sourceFile: sourceFile) {
            trace.log(.statement, "L\(line.number) -> inlineUnlessConditional")
            return (.conditional(single), 1)
        }
        // Choice branches: `if yes:`, `if no:`, `if the user picks 1:`, etc.
        if let choiceBranch = try parseChoiceBranch(lines, at: i, sourceFile: sourceFile) {
            trace.log(.statement, "L\(line.number) -> choiceBranch")
            return (.conditional(choiceBranch.statement), choiceBranch.consumed)
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
                range: SourceRange(file: sourceFile, line: line.number, column: 1),
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
                range: SourceRange(file: sourceFile, line: line.number, column: 1),
                help: "Use `bind <name> = <value>.` or `rebind <name> = <value>.`; an empty RHS may be followed by an indented fenced code block.")
        }

        // Compound note form: `proceed, and note "<text>" in the <binding>`
        // (INFORM7 §2.9). A single-line statement that lowers to a `rebind`
        // appending the note text to an already-declared text binding.
        if lower.hasPrefix(lexicon.grammar.compoundNoteIntroducer.lowercased()) {
            if let note = parseCompoundNote(t, line: line) {
                trace.log(.statement, "L\(line.number) -> note")
                return (.note(note), 1)
            }
            try raiseStructural(
                .unparseableStatement,
                message: "malformed compound note statement",
                range: SourceRange(file: sourceFile, line: line.number, column: 1),
                help: "Use `proceed, and note \"<text>\" in the <binding>.` with a quoted note and a target binding.")
        }

        // B2: "while {condition},"
        if lower.hasPrefix(statement.whilePrefix) && t.hasSuffix(",") {
            let condText = String(t.dropFirst(statement.whilePrefix.count).dropLast()).trimmingCharacters(in: .whitespaces)
            guard !condText.isEmpty else {
                try raiseStructural(.unparseableStatement, message: "malformed `while` block header (empty condition)",
                                    range: SourceRange(file: sourceFile, line: line.number, column: 1),
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
            let body = try parseBlock(bodyLines, sourceFile: sourceFile)
            trace.log(.statement, "L\(line.number) -> while")
            return (.iteration(IterationStatementAST(mode: .whileCondition(cond), body: body, sourceLine: line.number)), j - i)
        }

        // B2: "until {condition},"
        if lower.hasPrefix(statement.untilPrefix) && t.hasSuffix(",") {
            let condText = String(t.dropFirst(statement.untilPrefix.count).dropLast()).trimmingCharacters(in: .whitespaces)
            guard !condText.isEmpty else {
                try raiseStructural(.unparseableStatement, message: "malformed `until` block header (empty condition)",
                                    range: SourceRange(file: sourceFile, line: line.number, column: 1),
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
            let body = try parseBlock(bodyLines, sourceFile: sourceFile)
            trace.log(.statement, "L\(line.number) -> until")
            return (.iteration(IterationStatementAST(mode: .untilCondition(cond), body: body, sourceLine: line.number)), j - i)
        }

        // "simultaneously:" with each top-level body statement as a branch.
        if lower == statement.simultaneouslyHeader {
            let (sim, consumed) = try parseSimultaneously(lines, at: i, sourceFile: sourceFile)
            trace.log(.statement, "L\(line.number) -> simultaneously")
            return (.simultaneously(sim), consumed)
        }

        // "recover from {pattern}:"  or  "recover where {predicate}:"
        let tl = lower
        if tl.hasPrefix(statement.recoverFromPrefix) || tl.hasPrefix(statement.recoverWherePrefix) {
            let (rec, consumed) = try parseRecover(lines, at: i, sourceFile: sourceFile)
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
                range: SourceRange(file: sourceFile, line: line.number, column: 1),
                help: "Use `recover from \"<code>\":` or `recover where <predicate>:` with an indented handler body.")
        }

        if let every = try parseEveryEach(line, sourceFile: sourceFile) {
            trace.log(.statement, "L\(line.number) -> iteration (every/each shorthand)")
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
    func raiseStructural(_ code: DiagnosticCode, message: String,
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


    // MARK: - Utilities

    func unquote(_ s: String) -> String {
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
