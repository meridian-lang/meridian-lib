import Foundation

extension SkillMigrator {
    /// How the marking pass handles a heading.
    enum MarkDecision {
        /// Recognized role — leave the heading clean, no marker, no alias.
        case leaveUnmarked
        /// Append an inline `(( … ))` marker (`reference` / `template` /
        /// `tools` / `convention-ref` — non-executable documentation/metadata;
        /// never `inert` — the migrator does not emit that keyword).
        case inline(String)
        /// Route to a closed role via a rulebook `=== sections ===` alias instead
        /// of an inline `(( role: … ))` marker. Used for unrecognized *executable*
        /// headings (a pure-shell section, or a section whose only content is a
        /// cue-less operational line left for the real compiler to reject), so
        /// the heading stays clean and the role lives as reusable rulebook data.
        case alias(SkillSectionRole)
        /// Automatic mixed-section split (P1 four-way classification): narrative
        /// stays under the original heading with a `(( role: reference ))`
        /// marker (only when it carries real leftover content); each
        /// contiguous executable/AI-inference run in `plan` becomes a generated
        /// child heading routed to `procedure` (or `plan.execSegmentRole`) via a
        /// `SectionAlias`.
        case split(plan: SplitPlan)
    }

    /// One contiguous executable-or-AI-inference run pulled out of a mixed
    /// section body by `splitPlan`, in original line order.
    struct SplitSegment: Sendable, Equatable {
        /// Whether this segment's body renders as raw (already-lowerable or
        /// deliberately-left-for-the-compiler-to-reject) statements, or as a
        /// `use judgment to follow …:` wrap (an AI-inference-cue run).
        enum Kind: Sendable, Equatable { case exec, aiInference }
        let lines: [String]
        var kind: Kind = .exec
    }

    /// The narrative/executable/AI-inference bucketing of one section body —
    /// the P1 four-way classification (lower / judgment-if-inference-cue /
    /// reference / reword-error), applied per contiguous run. `unminedContracts`
    /// are operational/normative-cue lines (P1 category 4) that did not
    /// themselves trial-lower and carried no AI-inference cue: never silently
    /// dropped into documentation, they are pulled into their own executable
    /// segment (or, for a whole/leftover body, left role-open) so the REAL
    /// compiler processes them and raises its own precise reword diagnostic
    /// (`uncheckablePredicate` / `unresolvedPhrase`).
    struct SplitPlan: Sendable, Equatable {
        var narrativeLines: [String]
        var executableSegments: [SplitSegment]
        var unminedContracts: [String]
        var executableUnitCount: Int
        var contentUnitCount: Int
        /// Set when `executableSegments` is empty, there is no AI-inference
        /// cue, but the body carries operational/normative signal (a
        /// `normativeCueWords` cue, or the heading itself already asserts a
        /// checkable/procedure role) that cannot be silently filed as
        /// documentation. The caller leaves the heading role-open (or aliases
        /// it to `.procedure`) instead of marking it, so strict compile
        /// raises its own precise "reword this" diagnostic (P1 category 4) —
        /// no migrator-side judgment-wrap, no migrator-side marker.
        var operationalErrorWorthy: Bool = false
        /// The role each generated `<heading> — steps[ N]` *exec-kind*
        /// executable-segment sibling should be aliased to. Defaults to
        /// `.procedure` (correct for a `.procedure`-role split and for an
        /// unrecognized (`.none`) heading, where any executable content
        /// becomes generic procedure by definition). `checkableRoleDecision`
        /// overrides this to its own role (invariants/prohibitions/
        /// applicability/negativeApplicability). AI-inference-kind segments
        /// are always aliased to `.procedure` regardless of this value (their
        /// body is a `use judgment to …:` statement, which only the generic
        /// procedure builder — not the checkable-role builder — can parse).
        var execSegmentRole: SkillSectionRole = .procedure
    }

    /// Fixed, recognizable suffix for a generated split sibling heading
    /// (`<heading> — steps`, `<heading> — steps 2`, …). Load-bearing for
    /// idempotency: a heading containing this suffix is never re-split.
    static let splitHeadingSeparator = " — steps"

    /// Compute the section's `splitPlan`, then decide the whole-section (no
    /// exec/AI-inference content at all) outcome per P1: operational/normative
    /// signal (`roleAlreadyAsserted`, or an unmined-contract line) is left for
    /// the real compiler to reject; otherwise the body is genuinely documentary
    /// (the caller marks it `(( role: reference ))`).
    ///
    /// The split threshold that used to discard small executable segments
    /// below a minimum count/ratio has been removed: every lowerable or
    /// AI-inference segment always survives as its own child section.
    ///
    /// - roleAlreadyAsserted: the heading itself is a recognized built-in role
    ///   synonym (`.procedure`, a `Phase N:` prefix, or one of the checkable
    ///   roles). A body with zero executable lines, zero AI-inference cue, and
    ///   zero unmined contracts is still not automatically "documentary" when
    ///   the heading itself already asserts an operational contract — the
    ///   absence of deterministic signal under an explicit "this is a
    ///   procedure/contract/applicability gate" heading is itself the
    ///   operational-error signal, not a free pass to documentation.
    func splitPlanApplyingThreshold(_ body: ArraySlice<String>, knowledge: Compiler.KnowledgeContext,
                                            roleAlreadyAsserted: Bool = false, checkableOnly: Bool = false,
                                            ruleAware: Bool = true,
                                            referenceHeadingContext: Bool = false) -> SplitPlan {
        var plan = splitPlan(for: body, knowledge: knowledge, checkableOnly: checkableOnly,
                             ruleAware: ruleAware, referenceHeadingContext: referenceHeadingContext)
        guard !plan.executableSegments.isEmpty else {
            if roleAlreadyAsserted || !plan.unminedContracts.isEmpty {
                plan.operationalErrorWorthy = true
            }
            return plan
        }
        return plan
    }

    /// True iff `lines` has at least one line that is not blank, a Markdown
    /// comment (`>`), or a heading (`#`) — i.e. real prose/content, not just
    /// structural filler. Used to decide whether a split's leftover parent
    /// narrative needs an explicit `(( role: reference ))` marker (non-empty)
    /// or can stay clean (empty/filler-only).
    func hasSubstantiveContent(_ lines: [String]) -> Bool {
        lines.contains { raw in
            let t = raw.trimmingCharacters(in: .whitespaces)
            return !t.isEmpty && !t.hasPrefix(">") && !t.hasPrefix("#")
        }
    }

    struct ExecutableFenceContent: Sendable, Equatable {
        var hasExecutableLine: Bool
        var commentText: String
    }

    /// Inspect the payload of a shell/tool fence. Lines beginning with `#` are
    /// comments, except shebangs (`#!`), which make the fence executable. This
    /// keeps examples like:
    ///
    /// ```bash
    /// # Weekly: pull recent news per company; flag changes for review.
    /// ```
    ///
    /// out of the deterministic shell path: they are operational guidance for
    /// an agent, not commands Meridian can execute directly.
    static func executableFenceContent(_ fenceLines: [String]) -> ExecutableFenceContent {
        var hasExecutableLine = false
        var comments: [String] = []
        guard fenceLines.count > 1 else {
            return ExecutableFenceContent(hasExecutableLine: false, commentText: "")
        }

        let payloadEnd = fenceLines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true
            ? fenceLines.index(before: fenceLines.endIndex)
            : fenceLines.endIndex
        for raw in fenceLines[fenceLines.index(after: fenceLines.startIndex)..<payloadEnd] {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { continue }
            if t.hasPrefix("#!") {
                hasExecutableLine = true
                continue
            }
            if t.hasPrefix("#") {
                let comment = t.dropFirst().trimmingCharacters(in: .whitespaces)
                if !comment.isEmpty { comments.append(comment) }
                continue
            }
            hasExecutableLine = true
        }
        return ExecutableFenceContent(hasExecutableLine: hasExecutableLine,
                                      commentText: comments.joined(separator: " "))
    }
    // MARK: - Automatic mixed-section split (P1 four-way classification)

    /// One raw-line block of a section body: a fenced code block, a contiguous
    /// Markdown table, or a contiguous task-list run is one atomic block
    /// (never split mid-block); every other line is its own block.
    struct SplitBlock {
        var rawLines: [String]
        var normalizedText: String
        var isFence: Bool
        var isShellFence: Bool
        /// A non-shell fence whose language has a configured `Fence tool
        /// mapping:` entry (general-abilities: e.g. ```python → an
        /// interpreter tool). Classified as executable, same as a shell
        /// fence, but kept as a distinct flag since it lowers to one plain
        /// `invoke` rather than per-line `shell.run` calls.
        var isToolFence: Bool = false
        /// True for a shell/tool fence whose payload contains only comments.
        /// Such a fence is operational guidance, but it is not a deterministic
        /// command block: lowering it as shell would either do nothing or
        /// preserve only comments. The migrator routes the surrounding section
        /// through judgment (if cued) or leaves it for a real reword error.
        var isGuidanceOnlyExecutableFence: Bool = false
        var isTable: Bool = false
        var isChecklist: Bool = false
        /// A contiguous run of `<question>? -> <rhs>` list items (Phase 2's
        /// question-arrow decision protocol).
        var isQuestionArrowList: Bool = false
        /// An `if <cond>,` header plus its indented body, and (if present) a
        /// same-column `otherwise[,]` sibling plus its own indented body — one
        /// atomic block, captured by relative indentation rather than by
        /// single-line trial-lowering. `TrialLowering.lowersAsStatement`
        /// probes a bare single line with `IndentTokenizer`, so an `if …,`
        /// header alone (correctly, structurally) never lowers — it has no
        /// body — and a line-by-line scan previously classified the header,
        /// `otherwise,`, and every body line as independent `.documentation`,
        /// silently dropping real branch logic (`replay the pipeline run.` /
        /// `use judgment to …`) into inert narrative prose. See
        /// `docs/09_SKILL_PORTING.md` §"Common porting fixes" and
        /// `IMPLEMENTATION_LOG.md` (2026-07-06T19:25:56Z, "Gotcha #2 fixed").
        var isIfChain: Bool = false
        /// When set, an `.exec`/`.aiInference`-classified block renders these
        /// lines instead of `rawLines` — used by the question-arrow
        /// protocol's case 1/2 desugar, whose output (`<rhs> only when
        /// <cond>.` / `let the <name> be "<rhs>" only when <cond>.`) is not
        /// the original Markdown text, and by its case-3 judgment wrap.
        var execRenderOverride: [String]? = nil
    }

    /// Leading-whitespace width matching `IndentTokenizer.leadingSpaces`
    /// (tabs count as 2) — the same measure `StatementParser.parseConditional`
    /// uses to delimit an `if`/`otherwise` body, so the migrator's block scan
    /// groups exactly the lines the real parser would.
    private func leadingWhitespaceWidth(_ s: String) -> Int {
        var n = 0
        for c in s {
            if c == " " { n += 1 } else if c == "\t" { n += 2 } else { break }
        }
        return n
    }

    /// Scan a structural `if <cond>,` header starting at `start`, if present:
    /// the header itself, every subsequent line strictly more indented than
    /// it (the "then" body — blank lines mid-body are absorbed only when a
    /// qualifying line follows), and, if a same-or-lesser-indented bare
    /// `otherwise`/`otherwise,` line immediately follows the body, that line
    /// plus its own indented body. Returns `nil` when `start` isn't an `if
    /// …,` header, or the header has no body at all (a malformed single
    /// dangling header — left to fall through to the old per-line path,
    /// which already surfaces this as a documentation/error line exactly as
    /// before; this function's only job is to stop a well-formed multi-line
    /// conditional from being shredded into independent lines).
    private func scanIfChain(_ body: ArraySlice<String>, from start: ArraySlice<String>.Index,
                              lexicon: EnglishLexicon) -> (lines: [String], next: ArraySlice<String>.Index)? {
        let statement = lexicon.grammar.statement
        let headerRaw = body[start]
        let headerTrimmed = headerRaw.trimmingCharacters(in: .whitespaces)
        guard headerTrimmed.lowercased().hasPrefix(statement.ifPrefix), headerTrimmed.hasSuffix(",") else { return nil }

        let headerIndent = leadingWhitespaceWidth(headerRaw)
        var lines = [headerRaw]
        var j = body.index(after: start)

        func consumeBody(minIndentExclusive: Int) {
            while j < body.endIndex {
                let raw = body[j]
                let trimmed = raw.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    var k = body.index(after: j)
                    while k < body.endIndex, body[k].trimmingCharacters(in: .whitespaces).isEmpty {
                        k = body.index(after: k)
                    }
                    guard k < body.endIndex, leadingWhitespaceWidth(body[k]) > minIndentExclusive else { return }
                    while j < k { lines.append(body[j]); j = body.index(after: j) }
                    continue
                }
                guard leadingWhitespaceWidth(raw) > minIndentExclusive else { return }
                lines.append(raw)
                j = body.index(after: j)
            }
        }

        consumeBody(minIndentExclusive: headerIndent)

        if j < body.endIndex {
            let otherwiseRaw = body[j]
            let otherwiseTrimmed = otherwiseRaw.trimmingCharacters(in: .whitespaces).lowercased()
            if otherwiseTrimmed == statement.otherwiseKeyword || otherwiseTrimmed == statement.otherwiseCommaKeyword {
                let otherwiseIndent = leadingWhitespaceWidth(otherwiseRaw)
                lines.append(otherwiseRaw)
                j = body.index(after: j)
                consumeBody(minIndentExclusive: otherwiseIndent)
            }
        }

        guard lines.count > 1 else { return nil }
        return (lines, j)
    }

    enum SplitKind: Equatable {
        case blank, comment, exec, documentation
        /// Non-lowerable content that carries an `inferenceCueWords` cue — the
        /// ONLY P1 category-2 signal. Rendered as its own `use judgment to
        /// follow …:` sibling segment.
        case aiInference
        /// Non-lowerable content with no inference cue but real operational/
        /// normative signal (P1 category 4) — pulled into its own executable
        /// segment (or left role-open at the whole-section level) so the real
        /// compiler raises a precise reword diagnostic. Never silently
        /// dropped into documentation and never auto-wrapped in judgment.
        case errorOperational
        /// A Markdown table whose condition cells are fuzzy (didn't trial-lower
        /// as a decision/data table) AND whose text carries an inference cue —
        /// AI-routed via `!!! table (( ai-discretion ))`. A cue-less
        /// non-checkable table is `.errorOperational` instead (P1: tables and
        /// checklists are gated identically — no auto-emitted AI marker).
        case fuzzyTable
        /// A task-list run with at least one non-structurally-checkable item
        /// AND an inference cue — AI-routed via `!!! checklist (( ai-autonomy
        /// ))`. Cue-less → `.errorOperational` (see `.fuzzyTable`).
        case fuzzyChecklist
    }

    /// Scan a section body into atomic blocks, classify each with the same
    /// trial-lowering oracle used by `sectionIsExecutableOnly`, then bucket
    /// contiguous runs into narrative (stays under the original heading),
    /// AI-inference (becomes its own judgment-wrapped child), or executable
    /// (becomes a generated child heading, verbatim — either because it
    /// lowers, or because it is deliberately left for the real compiler to
    /// reject). An annotation label (a line ending `:` immediately before an
    /// executable/AI-inference block) attaches to the run it introduces, per
    /// the deterministic split precedence.
    func splitPlan(for body: ArraySlice<String>, knowledge: Compiler.KnowledgeContext,
                   checkableOnly: Bool = false, ruleAware: Bool = true,
                   referenceHeadingContext: Bool = false) -> SplitPlan {
        let trace = ParserTrace.current
        let trial = TrialLowering(knowledge: knowledge, probeTally: probeSession.tally)
        // rule-aware classifier hook: a line the compiler's own
        // `RuleAnalyzer` recognizes as a Phase-8 rule shape (`must not …` /
        // `may …` [+ bounded `up to N`] / `must be … by … before …` /
        // `When …, …`) is lowerable (P1 category 1), never routed to
        // `reference` documentation or left for a hard-error fallback just
        // because it lacks a `normativeCueWords` hit (e.g. bare `may …`) or
        // carries no other executable shape `TrialLowering` recognizes.
        // Scoped out for applicability/negativeApplicability callers
        // (`ruleAware: false`) — those bodies are dispatch-phrase fragments
        // ("When the user says X, Y, Z" has no action clause), and trialing
        // them against `RuleAnalyzer` produces the same false-positive
        // trigger match the compiler-side fix (`SkillSectionBuilder`) guards
        // against; see IMPLEMENTATION_LOG.md for the gbrain measurement that
        // surfaced this.
        let ruleAnalyzer = ruleAware ? RuleAnalyzer(lexicon: knowledge.lexicon, symbols: knowledge.symbols) : nil
        func isRuleShaped(_ text: String) -> Bool {
            guard let ruleAnalyzer else { return false }
            // Shape-gate first: `classify`'s marker matching is unanchored
            // substring matching (safe only because the flat top-level path
            // and `SkillSectionBuilder` both gate on this same shape first —
            // see `RuleAnalyzer.looksLikeRuleShapedSentence`'s doc comment).
            // Without this gate, ordinary narrative merely mentioning "may"
            // ("the file may exist outside the indexed brain") spuriously
            // satisfies `classifyPermission`.
            guard ruleAnalyzer.looksLikeRuleShapedSentence(text) else { return false }
            do {
                return try ruleAnalyzer.classify(RuleAST(text: text, sourceLine: 0)) != nil
            } catch {
                return true
            }
        }

        // Step 1: atomic-block scan (fences are one block).
        var blocks: [SplitBlock] = []
        var i = body.startIndex
        while i < body.endIndex {
            let raw = body[i]
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                var fenceLines = [raw]
                let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                let shell = knowledge.lexicon.isShellFence(lang)
                let toolFence = !shell && knowledge.lexicon.fenceTool(for: lang) != nil
                var j = body.index(after: i)
                while j < body.endIndex {
                    fenceLines.append(body[j])
                    let closed = body[j].trimmingCharacters(in: .whitespaces).hasPrefix("```")
                    j = body.index(after: j)
                    if closed { break }
                }
                let content = Self.executableFenceContent(fenceLines)
                let guidanceOnly = (shell || toolFence) && !content.hasExecutableLine && !content.commentText.isEmpty
                blocks.append(SplitBlock(rawLines: fenceLines, normalizedText: content.commentText,
                                         isFence: true, isShellFence: shell, isToolFence: toolFence,
                                         isGuidanceOnlyExecutableFence: guidanceOnly))
                i = j
                continue
            }
            // A Markdown table (contiguous `|…|` rows, header + separator +
            // data) is one atomic block — never interleave its rows with
            // narrative/exec buckets.
            if t.hasPrefix("|"), t.hasSuffix("|"), t.count > 1 {
                var tableLines = [raw]
                var j = body.index(after: i)
                while j < body.endIndex {
                    let tt = body[j].trimmingCharacters(in: .whitespaces)
                    guard tt.hasPrefix("|"), tt.hasSuffix("|"), tt.count > 1 else { break }
                    tableLines.append(body[j])
                    j = body.index(after: j)
                }
                if tableLines.count >= 2 {
                    blocks.append(SplitBlock(rawLines: tableLines, normalizedText: "", isFence: false, isShellFence: false, isTable: true))
                    i = j
                    continue
                }
            }
            // A contiguous task-list run is one atomic block, so a fuzzy item
            // anywhere in the run routes the whole checklist to the planner
            // rather than fragmenting it line by line.
            if isTaskListLine(normalizeMarkdownLineForLowering(stripMarkdownListMarker(t))) {
                var checklistLines = [raw]
                var j = body.index(after: i)
                while j < body.endIndex {
                    let tt = body[j].trimmingCharacters(in: .whitespaces)
                    guard isTaskListLine(normalizeMarkdownLineForLowering(stripMarkdownListMarker(tt))) else { break }
                    checklistLines.append(body[j])
                    j = body.index(after: j)
                }
                blocks.append(SplitBlock(rawLines: checklistLines, normalizedText: "", isFence: false, isShellFence: false, isChecklist: true))
                i = j
                continue
            }
            // A contiguous `<question>? -> <rhs>` run (Phase 2's question-arrow
            // decision protocol) is one atomic block — the three-way lowering
            // decides uniformly over the whole list, not line by line.
            if parseQuestionArrowLine(t) != nil {
                var qaLines = [raw]
                var j = body.index(after: i)
                while j < body.endIndex {
                    guard parseQuestionArrowLine(body[j]) != nil else { break }
                    qaLines.append(body[j])
                    j = body.index(after: j)
                }
                if qaLines.count >= 2 {
                    blocks.append(SplitBlock(rawLines: qaLines, normalizedText: "", isFence: false, isShellFence: false, isQuestionArrowList: true))
                    i = j
                    continue
                }
            }
            // Structural `if <cond>,` header: captured by relative
            // indentation (matching `IndentTokenizer.leadingSpaces` and
            // `StatementParser.parseConditional`'s own then/otherwise
            // grouping), not by paragraph-joining or single-line trial-
            // lowering. An `if …,` header alone never trial-lowers — it
            // structurally has no body when probed in isolation — so
            // without this the header, an `otherwise,` sibling, and every
            // body line were each independently misclassified as
            // `.documentation`, silently dropping the whole branch (see
            // `SplitBlock.isIfChain`'s doc comment and `IMPLEMENTATION_LOG.md`
            // 2026-07-06T19:25:56Z, "Gotcha #2 fixed").
            if let chain = scanIfChain(body, from: i, lexicon: knowledge.lexicon) {
                let joined = chain.lines.joined(separator: "\n")
                blocks.append(SplitBlock(rawLines: chain.lines, normalizedText: joined,
                                         isFence: false, isShellFence: false, isIfChain: true))
                i = chain.next
                continue
            }
            // Hard-wrapped paragraph continuation: `SKILL.md` bodies wrap a
            // single sentence or numbered-list item across multiple raw
            // lines. If the current line doesn't end its sentence (no
            // `.`/`:`/`?`/`!`) and isn't already a complete whole-line
            // command/choice-gate, absorb subsequent lines as one atomic
            // block until a line that does end its sentence, a blank line,
            // or a line that starts a new structural element (heading,
            // fence, table, checklist, question-arrow, or a fresh list
            // item). A blank starting line is never grown.
            if t.isEmpty {
                blocks.append(SplitBlock(rawLines: [raw], normalizedText: t, isFence: false, isShellFence: false))
                i = body.index(after: i)
                continue
            }
            var paragraphLines = [raw]
            var lastTrimmed = t
            var j = body.index(after: i)
            while j < body.endIndex, !endsSentenceForSplitting(lastTrimmed, lexicon: knowledge.lexicon) {
                let nextRaw = body[j]
                let nextTrimmed = nextRaw.trimmingCharacters(in: .whitespaces)
                guard !nextTrimmed.isEmpty,
                      !nextTrimmed.hasPrefix("#"), !nextTrimmed.hasPrefix(">"),
                      !nextTrimmed.hasPrefix("```"),
                      !(nextTrimmed.hasPrefix("|") && nextTrimmed.hasSuffix("|") && nextTrimmed.count > 1),
                      !isTaskListLine(normalizeMarkdownLineForLowering(stripMarkdownListMarker(nextTrimmed))),
                      parseQuestionArrowLine(nextTrimmed) == nil,
                      !isMarkdownListLine(nextTrimmed)
                else { break }
                paragraphLines.append(nextRaw)
                lastTrimmed = nextTrimmed
                j = body.index(after: j)
            }
            if paragraphLines.count > 1 {
                let joined = paragraphLines.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
                blocks.append(SplitBlock(rawLines: paragraphLines, normalizedText: joined, isFence: false, isShellFence: false))
                i = j
                continue
            }
            blocks.append(SplitBlock(rawLines: [raw], normalizedText: t, isFence: false, isShellFence: false))
            i = body.index(after: i)
        }

        // Step 2: classify each block. An indexed loop (not `.map`) because the
        // question-arrow protocol's output must be stashed on the block itself
        // (`execRenderOverride`) for Step 4 to render.
        var kinds: [SplitKind] = Array(repeating: .documentation, count: blocks.count)
        func traceSplitKind(_ kind: SplitKind) -> String {
            switch kind {
            case .blank: return "blank"
            case .comment: return "comment"
            case .exec: return "lowerable"
            case .documentation: return "reference"
            case .aiInference: return "judgment"
            case .errorOperational: return "reword-error"
            case .fuzzyTable: return "fuzzy-table-judgment"
            case .fuzzyChecklist: return "fuzzy-checklist-judgment"
            }
        }
        for idx in blocks.indices {
            let block = blocks[idx]
            if block.isFence {
                if block.isShellFence || block.isToolFence {
                    if block.isGuidanceOnlyExecutableFence {
                        kinds[idx] = trial.hasInferenceCue(block.normalizedText) ? .aiInference : .errorOperational
                    } else {
                        kinds[idx] = .exec
                    }
                } else {
                    kinds[idx] = .documentation
                }
                continue
            }
            if block.isTable {
                // A data table can't be represented as one `make sure {cond}.`
                // predicate, so under `checkableOnly` it never qualifies as
                // `.exec` — same rationale as the plain-line restriction below.
                let joined = block.rawLines.joined(separator: "\n")
                if !checkableOnly && trial.lowersAsStatement(joined) {
                    kinds[idx] = .exec
                } else {
                    kinds[idx] = trial.hasInferenceCue(joined) ? .fuzzyTable : .errorOperational
                }
                continue
            }
            if block.isChecklist {
                let joined = block.rawLines.joined(separator: "\n")
                if !checkableOnly && trial.lowersAsStatement(joined) {
                    kinds[idx] = .exec
                } else {
                    kinds[idx] = trial.hasInferenceCue(joined) ? .fuzzyChecklist : .errorOperational
                }
                continue
            }
            if block.isQuestionArrowList {
                // None of `classifyQuestionArrowList`'s outcomes is a bare
                // checkable predicate, so under `checkableOnly` this block
                // falls to the same cue-gated fallback as an unrecognized
                // table.
                guard !checkableOnly else {
                    let joined = block.rawLines.joined(separator: "\n")
                    kinds[idx] = trial.hasInferenceCue(joined) ? .fuzzyTable : .errorOperational
                    continue
                }
                let precedingBlock = idx > 0 ? blocks[idx - 1] : nil
                let (kind, override) = classifyQuestionArrowList(
                    block, precedingBlock: precedingBlock, trial: trial)
                kinds[idx] = kind
                blocks[idx].execRenderOverride = override
                continue
            }
            if block.isIfChain {
                // An `if …,` header requires an indented body to lower at
                // all — under `checkableOnly` (invariants/prohibitions/…),
                // like a backticked command, it is action-shaped, so it must
                // not auto-qualify as `.exec` there either.
                let joined = block.normalizedText
                if !checkableOnly, trial.lowersAsStatement(joined) {
                    kinds[idx] = .exec
                } else if isRuleShaped(joined) {
                    kinds[idx] = .exec
                } else if trial.hasInferenceCue(joined) {
                    kinds[idx] = .aiInference
                } else if trial.isNormativeNarrative(joined) {
                    kinds[idx] = .errorOperational
                } else {
                    kinds[idx] = .documentation
                }
                continue
            }

            let t = block.normalizedText
            if t.isEmpty { kinds[idx] = .blank; continue }
            if t.hasPrefix("#") || t.hasPrefix(">") { kinds[idx] = .comment; continue }

            let stripped = normalizeMarkdownLineForLowering(stripMarkdownListMarker(t))
            if stripped.isEmpty { kinds[idx] = .blank; continue }

            // Under `checkableOnly` (invariants/prohibitions/applicability/
            // negativeApplicability callers), a backticked command or choice
            // gate is action-shaped, not predicate-shaped — it cannot be a
            // checkable role's `make sure {cond}.` item — so it must not
            // auto-qualify as `.exec` here. Likewise `lowersAsStatement`'s
            // broader "any statement" fallback (actions included) is skipped:
            // only `isCheckableCondition` may produce `.exec`.
            if !checkableOnly, isWholeLineBacktickedCommand(stripped) || isChoiceGateLine(stripped, lexicon: knowledge.lexicon) { kinds[idx] = .exec; continue }
            if trial.isCheckableCondition(stripped) { kinds[idx] = .exec; continue }
            if !checkableOnly, trial.lowersAsStatement(stripped) { kinds[idx] = .exec; continue }
            // a real Phase-8 rule shape is lowerable regardless of
            // `TrialLowering`'s narrower statement/condition trial — it lowers
            // through `RuleAnalyzer`/`RuleInjector`, not `StatementParser`.
            // Gated by `ruleAware` (not `checkableOnly`): invariants/
            // prohibitions bodies (checkableOnly: true) are exactly where
            // `must not …`/`may …` rule prose is most likely to appear.
            if isRuleShaped(stripped) { kinds[idx] = .exec; continue }
            // the ONLY gate that may route non-lowerable content to an AI
            // marker is an inference cue. A normative cue with no inference
            // cue is an operational reword error, never silent documentation.
            if trial.hasInferenceCue(stripped) { kinds[idx] = .aiInference; continue }
            if trial.isNormativeNarrative(stripped) {
                kinds[idx] = referenceHeadingContext ? .documentation : .errorOperational
                continue
            }
            kinds[idx] = .documentation
        }
        if trace.isEnabled(.skill) {
            for idx in blocks.indices {
                let raw = blocks[idx].normalizedText.isEmpty
                    ? blocks[idx].rawLines.joined(separator: " ")
                    : blocks[idx].normalizedText
                trace.log(.skill, "split-plan block \(idx): \(traceSplitKind(kinds[idx])) — \(ParserTrace.short(raw, max: 100))")
            }
        }

        // A colon lead-in immediately before a guidance-only executable fence
        // (possibly separated by blank lines) is part of that guidance, even if
        // the broad trial-lowering probe can parse it as a skeletal loop header.
        // It inherits the fence's own cue-gated classification, so both travel
        // together into the same child.
        for idx in blocks.indices where idx > blocks.startIndex && blocks[idx].isGuidanceOnlyExecutableFence {
            guard let prevIdx = stride(from: idx - 1, through: 0, by: -1).first(where: {
                kinds[$0] != .blank && kinds[$0] != .comment
            }) else { continue }
            let normalized = normalizeMarkdownLineForLowering(stripMarkdownListMarker(blocks[prevIdx].normalizedText))
            if normalized.hasSuffix(":") {
                kinds[prevIdx] = kinds[idx]
            }
        }

        // Step 3: annotation-label look-ahead — a trailing-colon documentation
        // line immediately before an executable/AI-inference (or AI-routed)
        // block joins that block's run.
        func isExecLike(_ kind: SplitKind) -> Bool {
            kind == .exec || kind == .fuzzyTable || kind == .fuzzyChecklist || kind == .errorOperational
        }
        func joinsRun(_ kind: SplitKind) -> Bool {
            isExecLike(kind) || kind == .aiInference
        }
        // A trailing-colon line that is ITSELF a recognized multi-line
        // statement introducer (`recover from …:`, `for each …:`, `while
        // …:`, `until …:`, …) is not a free-standing narrative label — it is
        // real syntax that structurally cannot trial-lower alone (e.g.
        // `recover from X:` has no preceding statement to attach to when
        // probed in isolation) but MUST reach the parser verbatim so it can
        // join the block it introduces. Blockquoting it (the label
        // treatment below) would silently drop the construct — the exact
        // "no silent drops via `>`" failure mode AGENTS.md §6 pitfall #14
        // warns about, except migrator-authored instead of hand-authored.
        func isStatementIntroducer(_ text: String) -> Bool {
            let lower = text.lowercased()
            return knowledge.lexicon.grammar.statement.primitivePrefixes.contains { lower.hasPrefix($0) }
        }
        for idx in blocks.indices {
            guard kinds[idx] == .documentation else { continue }
            // Check the markdown-normalized form (bold/emphasis/list-marker
            // stripped), not the raw text: a label like "**Run init on this
            // machine:**" ends its *raw* line in `**`, not `:` — the colon
            // is inside the bold span.
            let normalized = normalizeMarkdownLineForLowering(stripMarkdownListMarker(blocks[idx].normalizedText))
            guard normalized.hasSuffix(":") else { continue }
            guard let nextIdx = ((idx + 1)..<blocks.count).first(where: { kinds[$0] != .blank && kinds[$0] != .comment }) else { continue }
            guard joinsRun(kinds[nextIdx]) else { continue }
            kinds[idx] = kinds[nextIdx] == .aiInference ? .aiInference : .exec
            if isStatementIntroducer(normalized) {
                // Real syntax — join the run verbatim, unmarked.
                continue
            }
            // Render as a comment, not a raw statement line — the label is
            // free-standing narrative on its OWN line, not itself an
            // enforceable requirement.
            blocks[idx].execRenderOverride = blocks[idx].rawLines.map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? line : "> \(trimmed)"
            }
        }

        // Step 4: bucket contiguous runs. Blank/comment blocks are neutral —
        // they attach to whichever bucket is open when they're encountered.
        // Three buckets: narrative (stays under the parent), exec (raw —
        // lowerable or deliberately left for the real compiler to reject),
        // aiInference (its own `use judgment to follow …:` sibling).
        enum Bucket: Equatable { case narrative, exec, aiInference }
        func bucket(for kind: SplitKind) -> Bucket {
            if kind == .aiInference { return .aiInference }
            return isExecLike(kind) ? .exec : .narrative
        }

        var narrativeLines: [String] = []
        var executableSegments: [SplitSegment] = []
        var unminedContracts: [String] = []
        var executableUnitCount = 0
        var contentUnitCount = 0

        var pendingNeutral: [String] = []
        var pendingSegment: [String] = []
        var currentBucket: Bucket?

        func flushSegment() {
            guard currentBucket == .exec || currentBucket == .aiInference, !pendingSegment.isEmpty else {
                pendingSegment = []
                return
            }
            executableSegments.append(SplitSegment(lines: pendingSegment,
                                                    kind: currentBucket == .aiInference ? .aiInference : .exec))
            pendingSegment = []
        }

        for (idx, block) in blocks.enumerated() {
            let kind = kinds[idx]
            if kind == .blank || kind == .comment {
                pendingNeutral.append(contentsOf: block.rawLines)
                continue
            }
            contentUnitCount += 1
            if kind == .errorOperational { unminedContracts.append(block.normalizedText) }

            let target = bucket(for: kind)
            if target != .narrative { executableUnitCount += 1 }

            if target != currentBucket {
                // Bucket switch: the neutral lines seen since the last real
                // content stay with the bucket that is ENDING (trailing
                // whitespace of the previous run), not the one starting.
                if currentBucket == .exec || currentBucket == .aiInference {
                    pendingSegment.append(contentsOf: pendingNeutral)
                } else {
                    narrativeLines.append(contentsOf: pendingNeutral)
                }
                pendingNeutral = []
                flushSegment()
                currentBucket = target
            } else {
                if target == .exec || target == .aiInference {
                    pendingSegment.append(contentsOf: pendingNeutral)
                } else {
                    narrativeLines.append(contentsOf: pendingNeutral)
                }
                pendingNeutral = []
            }

            if target == .exec {
                // The explicit AI-routing marker travels immediately above the
                // block it's routing (no blank line between), per docs/09_SKILL_PORTING.md's
                // syntax — never silently dropped into a plain exec run.
                if kind == .fuzzyTable { pendingSegment.append("!!! table (( ai-discretion ))") }
                else if kind == .fuzzyChecklist { pendingSegment.append("!!! checklist (( ai-autonomy ))") }
                if checkableOnly, block.execRenderOverride == nil, block.rawLines.count > 1 {
                    // A checkable-role body (invariants/prohibitions/…) requires
                    // one physical line per predicate — the real compiler
                    // rejects a hard-wrapped bullet split across raw source
                    // lines as "not a single predicate". This block was a
                    // multi-line paragraph joined only for classification
                    // (`normalizedText`); collapse it to that single joined
                    // line so the checkable-section parser sees one item, not
                    // a wrapped fragment plus an orphaned continuation line.
                    pendingSegment.append(block.normalizedText)
                } else {
                    pendingSegment.append(contentsOf: block.execRenderOverride ?? block.rawLines)
                }
            } else if target == .aiInference {
                pendingSegment.append(contentsOf: block.execRenderOverride ?? block.rawLines)
            } else {
                narrativeLines.append(contentsOf: block.rawLines)
            }
        }
        // Trailing neutral lines (blank/comment at the very end of the body)
        // attach to whichever bucket was last open.
        if currentBucket == .exec || currentBucket == .aiInference {
            pendingSegment.append(contentsOf: pendingNeutral)
        } else {
            narrativeLines.append(contentsOf: pendingNeutral)
        }
        flushSegment()

        return SplitPlan(narrativeLines: narrativeLines, executableSegments: executableSegments,
                         unminedContracts: unminedContracts, executableUnitCount: executableUnitCount,
                         contentUnitCount: contentUnitCount)
    }

    /// Render a `SplitPlan` as replacement lines for the original heading's
    /// `idx..<end` range: the original heading followed by its leftover
    /// narrative, then one generated child heading per executable/AI-inference
    /// segment (`<heading> — steps`, `— steps 2`, …).
    func renderSplitPlan(_ plan: SplitPlan, headingHashes: String, headingText: String,
                         lexicon: EnglishLexicon) -> [String] {
        var out: [String] = []
        if hasSubstantiveContent(plan.narrativeLines) {
            out.append("\(headingHashes) \(headingText) (( role: reference ))")
        } else {
            out.append("\(headingHashes) \(headingText)")
        }
        out.append(contentsOf: plan.narrativeLines)
        // Cap the child heading depth at `###` — `IndentTokenizer` only
        // recognizes `##`/`###` as heading levels (`markHeadingOrList`), so a
        // `####` line from a deeper parent silently reads back as a markdown
        // comment, not a heading: the "child" body would merge right back
        // into the parent's own content and never resolve independently. The
        // universal-sections model is flat regardless of nesting depth (every
        // heading is its own independent section — `SkillSectionBuilder.
        // splitSections`), so a same-level sibling is exactly as valid as a
        // deeper child; capping loses no structure.
        let childHashes = headingHashes.count >= 3 ? headingHashes : headingHashes + "#"
        for (i, segment) in plan.executableSegments.enumerated() {
            let suffix = i == 0 ? "" : " \(i + 1)"
            let childHeadingText = "\(headingText)\(Self.splitHeadingSeparator)\(suffix)"
            out.append("")
            out.append("\(childHashes) \(childHeadingText)")
            out.append("")
            if segment.kind == .aiInference {
                out.append(lexicon.grammar.judgmentFollowCollectLine(heading: childHeadingText))
                out.append(contentsOf: segment.lines)
            } else {
                var segLines = segment.lines
                normalizeMarkdownFormattingForLowering(&segLines, segLines.indices)
                out.append(contentsOf: segLines)
            }
        }
        return out
    }
}
