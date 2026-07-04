import Foundation

extension SkillMigrator {
    /// How the marking pass handles a heading.
    enum MarkDecision {
        /// Recognized role — leave the heading clean, no marker, no alias.
        case leaveUnmarked
        /// Append an inline `(( … ))` marker (inert / invariants / prohibitions /
        /// convention-ref — non-executable or role-restating prose).
        case inline(String)
        /// Route to a closed role via a rulebook `=== sections ===` alias instead
        /// of an inline `(( role: … ))` marker. Used for unrecognized *executable*
        /// headings (a pure-shell section), so the heading stays clean and the
        /// role lives as reusable rulebook data.
        case alias(SkillSectionRole)
        /// Automatic mixed-section split (AGENTS.md Phase 1 item 3): narrative
        /// stays under the original heading with `marker`; each contiguous
        /// executable run in `plan` becomes a generated child heading routed to
        /// `procedure` via a `SectionAlias`.
        case split(marker: String, plan: SplitPlan)
    }

    /// One contiguous executable run pulled out of a mixed section body by
    /// `splitPlan`, in original line order.
    struct SplitSegment: Sendable, Equatable {
        let lines: [String]
    }

    /// The narrative/executable bucketing of one section body. `unminedContracts`
    /// are normative-narrative lines (AGENTS.md §15 cue shapes) that did not
    /// themselves trial-lower and were not split out — per Phase 1 item 3 these
    /// are reported, never silently dropped into generic inert prose.
    struct SplitPlan: Sendable, Equatable {
        var narrativeLines: [String]
        var executableSegments: [SplitSegment]
        var unminedContracts: [String]
        var executableUnitCount: Int
        var contentUnitCount: Int
        /// Set by `splitPlanApplyingThreshold` when `executableSegments` was
        /// cleared (no split) but real exec/normative signal existed — worth
        /// routing the whole leftover body through `use judgment to follow the
        /// <heading> guidance:` (AGENTS.md Phase 1 items 3 & 4) rather than a
        /// plain `(( inert ))` marker. False when the body is genuinely inert
        /// (zero exec signal, zero unmined contracts).
        var judgmentWorthy: Bool = false
        /// True when a judgment-wrap path (either `judgmentWorthy` whole-
        /// section, or `narrativeJudgmentWorthy` leftover-narrative-beside-
        /// split-children) additionally needs a `procedure` `SectionAlias`
        /// for the original heading (it was not already a recognized role)
        /// — the judgment statement makes the section's body executable, so
        /// an unrecognized heading with content must resolve.
        var needsProcedureAlias: Bool = false
        /// The role each generated `<heading> — steps[ N]` executable-segment
        /// sibling should be aliased to. Defaults to `.procedure` (correct for
        /// a `.procedure`-role split and for an unrecognized (`.none`) heading,
        /// where any executable content becomes generic procedure by
        /// definition). `checkableRoleDecision` overrides this to its own role
        /// (invariants/prohibitions/applicability/negativeApplicability): a
        /// bullet split *out* of e.g. `## Contract` because it trial-lowered
        /// as a checkable predicate is a predicate, not a procedure step —
        /// aliasing it to `.procedure` hands it to the generic statement
        /// builder, which parses a bare (non-`make sure`-prefixed) predicate
        /// bullet as an implicit action/phrase invocation instead of an
        /// assertion, and can misresolve it into a bogus tool call (e.g.
        /// "Brain is checked BEFORE any external API call" → invoke
        /// `searchBrain`) that only surfaces as an opaque `MER2002 unknown
        /// tool`, far from its real cause.
        var execSegmentRole: SkillSectionRole = .procedure
        /// When set, the judgment-wrap path (no exec segments, `judgmentWorthy`)
        /// renders this literal inline marker on the heading instead of leaving
        /// it clean + routing via a rulebook `SectionAlias`. Needed for a
        /// heading whose text is a *recognized checkable role* (Contract →
        /// invariants, Anti-Patterns → prohibitions, …): `SkillSectionBuilder`'s
        /// invariants/prohibitions/applicability/negativeApplicability body
        /// builder only accepts per-line checkable predicates (MER1010 on a
        /// `use judgment to follow …:` line), so escaping to the generic
        /// procedure builder is required — but a `SectionAlias` cannot do that
        /// reliably here, because a corpus rulebook commonly already declares
        /// its OWN `section "<Heading>" -> <role>` synonym line for this exact
        /// heading text (to add author-facing synonyms like "Avoid"/"Pitfalls"
        /// alongside the builtin "Anti-Patterns"), and `Rulebook.role(forHeading:)`
        /// resolves by first match, so a later per-file alias can never win
        /// against an earlier corpus-wide one for the same heading text. An
        /// explicit `(( … ))` marker on the heading itself is authoritative
        /// over ANY rulebook alias (`SectionRoleResolver.decide` checks the
        /// marker first, unconditionally) and needs no rulebook cooperation.
        var forcedRoleMarker: String? = nil
        /// True when `executableSegments` is non-empty (the split proceeds)
        /// *and* the leftover `narrativeLines` left under the parent heading
        /// itself has real signal worth routing through `use judgment to
        /// follow the <heading> guidance:` rather than sitting under the
        /// parent's plain inert marker as silent documentation. A `## Phase N:
        /// …` parent whose real steps got extracted into a `— steps` child
        /// commonly still carries its own normative/conditional narrative
        /// (e.g. "If the `pack_upgrade_available` finding is `ok`, there's no
        /// successor — done.") that deserves the same "zero-deterministic-
        /// signal-is-the-judgment-signal" treatment as a heading with no
        /// executable segments at all (AGENTS.md §15/§16) — the two cases
        /// (whole-section judgment-wrap vs. leftover-narrative judgment-wrap)
        /// share this criterion, just applied to a different slice of the
        /// body. Same-role-widths as `judgmentWorthy`'s
        /// `roleAlreadyAsserted || !unminedContracts.isEmpty` test.
        var narrativeJudgmentWorthy: Bool = false
    }

    /// Fixed, recognizable suffix for a generated split sibling heading
    /// (`<heading> — steps`, `<heading> — steps 2`, …). Load-bearing for
    /// idempotency: a heading containing this suffix is never re-split.
    static let splitHeadingSeparator = " — steps"
    /// Compute the section's `splitPlan`, then apply the split threshold
    /// (AGENTS.md Phase 1 item 3: at least 3 executable units, or at least 25%
    /// of content units — otherwise splitting two commands out of twenty prose
    /// lines would produce worse output than keeping the section whole). Below
    /// threshold, `executableSegments` is cleared and, when real exec/normative
    /// signal existed, `judgmentWorthy` is set so the renderer wraps the
    /// leftover body in `use judgment to follow the <heading> guidance:`
    /// (AGENTS.md Phase 1 item 4) instead of a plain `(( inert ))` marker —
    /// `--no-route-fuzzy` opts back into the plain marker. `unminedContracts`
    /// is always preserved either way, so a normative-narrative line that
    /// fails to lower is reported even when nothing else routes it.
    ///
    /// - roleAlreadyAsserted: the heading itself is a recognized built-in role
    ///   synonym (`.procedure`, a `Phase N:` prefix, or one of the checkable
    ///   roles — `.invariants`/`.prohibitions`/`.applicability`/
    ///   `.negativeApplicability`). A body with zero executable lines and
    ///   zero unmined contracts (e.g. "Ask: ... Generate: ...", an interview
    ///   script with no `must`/`never` cue words; or "This skill guarantees a
    ///   thing." with no checkable predicate) is still fuzzy actionable
    ///   content, not genuinely inert documentation — the heading is already
    ///   asserting "this is a procedure/contract/applicability gate", so the
    ///   absence of deterministic signal is itself the judgment signal.
    ///   Without this, such a section fell through to a plain
    ///   `(( inert, role: … ))` with no judgment wrapper, silently
    ///   suppressing its guidance.
    func splitPlanApplyingThreshold(_ body: ArraySlice<String>, knowledge: Compiler.KnowledgeContext,
                                            roleAlreadyAsserted: Bool = false, checkableOnly: Bool = false) -> SplitPlan {
        var plan = splitPlan(for: body, knowledge: knowledge, checkableOnly: checkableOnly)
        guard !plan.executableSegments.isEmpty else {
            plan.judgmentWorthy = roleAlreadyAsserted || !plan.unminedContracts.isEmpty
            return plan
        }
        let ratio = plan.contentUnitCount > 0
            ? Double(plan.executableUnitCount) / Double(plan.contentUnitCount) : 0
        guard plan.executableUnitCount < 3 && ratio < 0.25 else {
            // The split is kept (real exec content justified it). Any
            // leftover narrative left under the *parent* heading gets the
            // same judgment-worthiness test `judgmentWorthy` applies to a
            // whole-section judgment-wrap — it just wasn't split out because
            // it isn't itself checkable/statement-shaped, not because it
            // lacks signal.
            if hasSubstantiveContent(plan.narrativeLines) {
                plan.narrativeJudgmentWorthy = roleAlreadyAsserted || !plan.unminedContracts.isEmpty
            }
            return plan
        }
        plan.judgmentWorthy = true
        plan.executableSegments = []
        return plan
    }

    /// True iff `lines` has at least one line that is not blank, a Markdown
    /// comment (`>`), or a heading (`#`) — i.e. real prose/content, not just
    /// structural filler. Used to gate `narrativeJudgmentWorthy`: an empty or
    /// filler-only leftover shouldn't get a `use judgment to follow …:` line
    /// with nothing meaningful under it.
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
    // MARK: - Automatic mixed-section split (AGENTS.md Phase 1 item 3)

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
        /// through judgment instead of leaving it inert or pretending it is
        /// strict executable code.
        var isGuidanceOnlyExecutableFence: Bool = false
        var isTable: Bool = false
        var isChecklist: Bool = false
        /// A contiguous run of `<question>? -> <rhs>` list items (Phase 2's
        /// question-arrow decision protocol).
        var isQuestionArrowList: Bool = false
        /// When set, an `.exec`-classified block renders these lines instead
        /// of `rawLines` — used by the question-arrow protocol's case 1/2
        /// desugar, whose output (`<rhs> only when <cond>.` /
        /// `let the <name> be "<rhs>" only when <cond>.`) is not the original
        /// Markdown text.
        var execRenderOverride: [String]? = nil
    }

    enum SplitKind: Equatable {
        case blank, comment, exec, unminedNormative, documentation
        /// A Markdown table whose condition cells are fuzzy (didn't trial-lower
        /// as a decision/data table) — AI-routed via `!!! table (( ai-discretion ))`
        /// instead of staying inert (AGENTS.md Phase 1 item 4, docs/13 fix 12).
        case fuzzyTable
        /// A task-list run with at least one non-structurally-checkable item —
        /// AI-routed via `!!! checklist (( ai-autonomy ))` (same rationale).
        case fuzzyChecklist
    }

    /// Scan a section body into atomic blocks, classify each with the same
    /// trial-lowering oracle used by `sectionIsExecutableOnly`, then bucket
    /// contiguous runs into narrative (stays under the original heading) vs.
    /// executable (becomes a generated child heading). An annotation label
    /// (a line ending `:` immediately before an executable block) attaches to
    /// the run it introduces, per the deterministic split precedence.
    func splitPlan(for body: ArraySlice<String>, knowledge: Compiler.KnowledgeContext,
                           checkableOnly: Bool = false) -> SplitPlan {
        let trial = TrialLowering(knowledge: knowledge)

        // Step 1: atomic-block scan (fences are one block).
        var blocks: [SplitBlock] = []
        var i = body.startIndex
        while i < body.endIndex {
            let raw = body[i]
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                var fenceLines = [raw]
                let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                let shell = isShellFence(lang)
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
            // Hard-wrapped paragraph continuation: `SKILL.md` bodies wrap a
            // single sentence or numbered-list item across multiple raw
            // lines. If the current line doesn't end its sentence (no
            // `.`/`:`/`?`/`!`) and isn't already a complete whole-line
            // command/choice-gate, absorb subsequent lines as one atomic
            // block until a line that does end its sentence, a blank line,
            // or a line that starts a new structural element (heading,
            // fence, table, checklist, question-arrow, or a fresh list
            // item). Without this, per-line classification chops one
            // logical sentence into alternating narrative/exec fragments
            // whenever an intermediate wrapped line happens to contain a
            // backtick-flanked command name (e.g. setup's "If the user
            // picks 2" numbered items — see IMPLEMENTATION_LOG.md Phase 3).
            // A blank starting line is never grown (it has no "sentence" to
            // continue, and must stay its own neutral block — otherwise it
            // would swallow the next real line, e.g. a `deciding the
            // <name>:` lead-in immediately preceding a question-arrow list).
            if t.isEmpty {
                blocks.append(SplitBlock(rawLines: [raw], normalizedText: t, isFence: false, isShellFence: false))
                i = body.index(after: i)
                continue
            }
            var paragraphLines = [raw]
            var lastTrimmed = t
            var j = body.index(after: i)
            while j < body.endIndex, !endsSentenceForSplitting(lastTrimmed) {
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
        // question-arrow protocol's case 1/2 output must be stashed on the
        // block itself (`execRenderOverride`) for Step 4 to render.
        var kinds: [SplitKind] = Array(repeating: .documentation, count: blocks.count)
        for idx in blocks.indices {
            let block = blocks[idx]
            if block.isFence {
                if block.isShellFence || block.isToolFence {
                    kinds[idx] = block.isGuidanceOnlyExecutableFence ? .unminedNormative : .exec
                } else {
                    kinds[idx] = .documentation
                }
                continue
            }
            if block.isTable {
                // A data table can't be represented as one `make sure {cond}.`
                // predicate, so under `checkableOnly` it never qualifies as
                // `.exec` — same rationale as the plain-line restriction above.
                let joined = block.rawLines.joined(separator: "\n")
                kinds[idx] = (!checkableOnly && trial.lowersAsStatement(joined)) ? .exec : (options.routeFuzzy ? .fuzzyTable : .documentation)
                continue
            }
            if block.isChecklist {
                let joined = block.rawLines.joined(separator: "\n")
                kinds[idx] = (!checkableOnly && trial.lowersAsStatement(joined)) ? .exec : (options.routeFuzzy ? .fuzzyChecklist : .documentation)
                continue
            }
            if block.isQuestionArrowList {
                // None of `classifyQuestionArrowList`'s three outcomes (a
                // desugared `<action> only when <question>.`, a decision-table
                // row, or a judgment-wrap) is a bare checkable predicate, so
                // under `checkableOnly` this block is never `.exec` either —
                // it goes through the same fuzzy/documentation fallback as an
                // unrecognized table.
                guard !checkableOnly else {
                    kinds[idx] = options.routeFuzzy ? .fuzzyTable : .documentation
                    continue
                }
                let precedingBlock = idx > 0 ? blocks[idx - 1] : nil
                let (kind, override) = classifyQuestionArrowList(
                    block, precedingBlock: precedingBlock, trial: trial)
                kinds[idx] = kind
                blocks[idx].execRenderOverride = override
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
            // only `isCheckableCondition` may produce `.exec`, so every
            // segment this plan hands to `execSegmentRole` is guaranteed
            // checkable (see AGENTS.md pitfall on `searchBrain`-style
            // misrouting of a bare predicate bullet through the generic
            // procedure builder).
            if !checkableOnly, isWholeLineBacktickedCommand(stripped) || isChoiceGateLine(stripped) { kinds[idx] = .exec; continue }
            if trial.isCheckableCondition(stripped) { kinds[idx] = .exec; continue }
            if !checkableOnly, trial.lowersAsStatement(stripped) { kinds[idx] = .exec; continue }
            if trial.isNormativeNarrative(stripped) { kinds[idx] = .unminedNormative; continue }
            kinds[idx] = .documentation
        }

        // A colon lead-in immediately before a guidance-only executable fence
        // (possibly separated by blank lines) is part of that guidance, even if
        // the broad trial-lowering probe can parse it as a skeletal loop header.
        // Splitting only the lead-in into a `— steps` child would leave the
        // comment-only fence under the parent judgment block and create a fake
        // deterministic child with no real action.
        for idx in blocks.indices where idx > blocks.startIndex && blocks[idx].isGuidanceOnlyExecutableFence {
            guard let prevIdx = stride(from: idx - 1, through: 0, by: -1).first(where: {
                kinds[$0] != .blank && kinds[$0] != .comment
            }) else { continue }
            let normalized = normalizeMarkdownLineForLowering(stripMarkdownListMarker(blocks[prevIdx].normalizedText))
            if normalized.hasSuffix(":") {
                kinds[prevIdx] = .unminedNormative
            }
        }

        // Step 3: annotation-label look-ahead — a trailing-colon documentation
        // line immediately before an executable (or AI-routed) block joins
        // that block's run.
        func isExecLike(_ kind: SplitKind) -> Bool {
            kind == .exec || kind == .fuzzyTable || kind == .fuzzyChecklist
        }
        for idx in blocks.indices {
            guard kinds[idx] == .documentation else { continue }
            // Check the markdown-normalized form (bold/emphasis/list-marker
            // stripped), not the raw text: a label like "**Run init on this
            // machine:**" ends its *raw* line in `**`, not `:` — the colon
            // is inside the bold span. Using the same normalization Step 2
            // already computed for classification keeps this lookahead
            // consistent with what actually got trial-lowered.
            let normalized = normalizeMarkdownLineForLowering(stripMarkdownListMarker(blocks[idx].normalizedText))
            guard normalized.hasSuffix(":") else { continue }
            guard let nextIdx = ((idx + 1)..<blocks.count).first(where: { kinds[$0] != .blank && kinds[$0] != .comment }) else { continue }
            guard isExecLike(kinds[nextIdx]) else { continue }
            kinds[idx] = .exec
            // Render as a comment, not a raw statement line. The label is
            // free-standing narrative on its OWN line (unlike the single-line
            // `Run `cmd` to <purpose>` idiom, where the purpose is folded into
            // the command's own canonical rewrite) — StatementParser has no
            // production that takes an arbitrary "<sentence>:" line followed
            // by a SEPARATE command/fence/AI-block and treats the sentence as
            // that block's annotation; fed through verbatim it is just an
            // unparseable (or, worse, accidentally phrase-matching-with-
            // garbage-args) statement of its own. Comment-prefixing keeps the
            // label visible as context immediately above the block it
            // introduces while dropping it from the IR — safe here because,
            // unlike AGENTS.md #14's normative-contract case, a label is
            // descriptive lead-in prose, never the sole carrier of an
            // enforceable requirement (an AI-routed block's own criteria rows
            // and a real command's own semantics carry that either way).
            blocks[idx].execRenderOverride = blocks[idx].rawLines.map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty ? line : "> \(trimmed)"
            }
        }

        // Step 4: bucket contiguous runs. Blank/comment blocks are neutral —
        // they attach to whichever bucket is open when they're encountered.
        enum Bucket { case narrative, exec }
        func bucket(for kind: SplitKind) -> Bucket {
            isExecLike(kind) ? .exec : .narrative
        }

        var narrativeLines: [String] = []
        var executableSegments: [SplitSegment] = []
        var unminedContracts: [String] = []
        var executableUnitCount = 0
        var contentUnitCount = 0

        var pendingNeutral: [String] = []
        var pendingExec: [String] = []
        var currentBucket: Bucket?

        func flushExec() {
            guard !pendingExec.isEmpty else { return }
            executableSegments.append(SplitSegment(lines: pendingExec))
            pendingExec = []
        }

        for (idx, block) in blocks.enumerated() {
            let kind = kinds[idx]
            if kind == .blank || kind == .comment {
                pendingNeutral.append(contentsOf: block.rawLines)
                continue
            }
            contentUnitCount += 1
            if kind == .unminedNormative { unminedContracts.append(block.normalizedText) }

            let target = bucket(for: kind)
            if target == .exec { executableUnitCount += 1 }

            if target != currentBucket {
                // Bucket switch: the neutral lines seen since the last real
                // content stay with the bucket that is ENDING (trailing
                // whitespace of the previous run), not the one starting.
                if currentBucket == .exec { pendingExec.append(contentsOf: pendingNeutral) }
                else { narrativeLines.append(contentsOf: pendingNeutral) }
                pendingNeutral = []
                if currentBucket == .exec { flushExec() }
                currentBucket = target
            } else {
                if target == .exec { pendingExec.append(contentsOf: pendingNeutral) }
                else { narrativeLines.append(contentsOf: pendingNeutral) }
                pendingNeutral = []
            }

            if target == .exec {
                // The explicit AI-routing marker travels immediately above the
                // block it's routing (no blank line between), per docs/13
                // fix 12's syntax — never silently dropped into a plain exec run.
                if kind == .fuzzyTable { pendingExec.append("!!! table (( ai-discretion ))") }
                else if kind == .fuzzyChecklist { pendingExec.append("!!! checklist (( ai-autonomy ))") }
                pendingExec.append(contentsOf: block.execRenderOverride ?? block.rawLines)
            } else {
                narrativeLines.append(contentsOf: block.rawLines)
            }
        }
        // Trailing neutral lines (blank/comment at the very end of the body)
        // attach to whichever bucket was last open.
        if currentBucket == .exec { pendingExec.append(contentsOf: pendingNeutral) }
        else { narrativeLines.append(contentsOf: pendingNeutral) }
        flushExec()

        return SplitPlan(narrativeLines: narrativeLines, executableSegments: executableSegments,
                         unminedContracts: unminedContracts, executableUnitCount: executableUnitCount,
                         contentUnitCount: contentUnitCount)
    }

    /// Render a `SplitPlan` as replacement lines for the original heading's
    /// `idx..<end` range: the original heading (now marked inert with
    /// `marker`) followed by its leftover narrative, then one generated child
    /// heading per executable segment (`<heading> — steps`, `— steps 2`, …).
    /// When the plan has no executable segments, either:
    ///   - `judgmentWorthy` (real signal, just below the split threshold) and
    ///     fuzzy-routing is enabled: the heading is left role-bearing (no inert
    ///     marker) and its body opens with `use judgment to follow the
    ///     <heading> guidance:`, which collects `originalBody` verbatim into
    ///     `ProseStepAST.guidance` (Phase 2's separate planner-context field,
    ///     not the dispatch goal in `text`) rather than the prose text
    ///     (AGENTS.md Phase 1 items 3 & 4); or
    ///   - otherwise: falls back to `originalBody` verbatim under the plain
    ///     inert `marker` — byte-identical to the pre-split-era marking.
    func renderSplitPlan(_ plan: SplitPlan, headingHashes: String, headingText: String,
                                 marker: String, originalBody: [String], routeFuzzy: Bool) -> [String] {
        guard !plan.executableSegments.isEmpty else {
            if routeFuzzy && plan.judgmentWorthy {
                let headingLine = plan.forcedRoleMarker.map { "\(headingHashes) \(headingText) \($0)" }
                    ?? "\(headingHashes) \(headingText)"
                var out: [String] = [headingLine]
                out.append("use judgment to follow the \(headingText) guidance:")
                out.append(contentsOf: originalBody)
                return out
            }
            var out: [String] = ["\(headingHashes) \(headingText) \(marker)"]
            out.append(contentsOf: originalBody)
            return out
        }
        var out: [String] = []
        if routeFuzzy && plan.narrativeJudgmentWorthy {
            let headingLine = plan.forcedRoleMarker.map { "\(headingHashes) \(headingText) \($0)" }
                ?? "\(headingHashes) \(headingText)"
            out.append(headingLine)
            out.append("use judgment to follow the \(headingText) guidance:")
        } else {
            out.append("\(headingHashes) \(headingText) \(marker)")
        }
        out.append(contentsOf: plan.narrativeLines)
        let childHashes = headingHashes + "#"
        for (i, segment) in plan.executableSegments.enumerated() {
            let suffix = i == 0 ? "" : " \(i + 1)"
            var segLines = segment.lines
            normalizeMarkdownFormattingForLowering(&segLines, segLines.indices)
            out.append("")
            out.append("\(childHashes) \(headingText)\(Self.splitHeadingSeparator)\(suffix)")
            out.append("")
            out.append(contentsOf: segLines)
        }
        return out
    }
}
