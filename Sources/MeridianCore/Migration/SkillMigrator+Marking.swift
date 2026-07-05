import Foundation

extension SkillMigrator {
    func markSections(_ markdown: String) throws
        -> (markdown: String, aliases: [SectionAlias], unminedContracts: [String]) {
        let knowledge = try knowledgeContext()
        var lines = markdown.components(separatedBy: "\n")
        let bodyStart = frontmatterEnd(lines)

        let headingIdxs = Self.topLevelHeadingIndices(lines, from: bodyStart, headingMatch: headingMatch)
        guard let firstHeading = headingIdxs.first else {
            let (markdown, aliases) = try wrapHeadinglessNarrativeIfNeeded(lines, bodyStart: bodyStart, knowledge: knowledge)
            return (markdown, aliases, [])
        }

        // 1. Blockquote preamble (body lines before the first heading).
        if firstHeading > bodyStart {
            lines = blockquoteBody(lines, from: bodyStart, to: firstHeading)
        }

        // 2. Mark headings (or route to a rulebook alias, or split).
        let rulebook = try mergedRulebook()
        var aliases: [SectionAlias] = []
        var unminedContracts: [String] = []
        // Split edits change line counts, so they can't be applied in place
        // during this scan (they would invalidate every later heading's
        // precomputed index). Defer them and apply back-to-front afterward —
        // earlier-in-file insertions never affect the offsets of not-yet-
        // applied later ranges when walked in descending order.
        struct SplitEdit { let range: Range<Int>; let replacement: [String] }
        var splitEdits: [SplitEdit] = []

        for (k, idx) in headingIdxs.enumerated() {
            guard let m = headingMatch(lines[idx]) else { continue }
            if m.text.hasSuffix("))") { continue }   // already marked — idempotent
            let end = (k + 1 < headingIdxs.count) ? headingIdxs[k + 1] : lines.count
            let body = lines[(idx + 1)..<end]
            switch try decision(forHeading: m.text, body: body, knowledge: knowledge, rulebook: rulebook) {
            case .leaveUnmarked:
                if shouldNormalizeExecutableBody(forHeading: m.text) {
                    normalizeMarkdownFormattingForLowering(&lines, (idx + 1)..<end)
                }
                break
            case .inline(let marker):
                lines[idx] = "\(m.hashes) \(m.text) \(marker)"
            case .alias(let role):
                // Leave the heading clean; the role is supplied via a rulebook
                // `=== sections ===` alias the CLI persists.
                if role == .procedure {
                    normalizeMarkdownFormattingForLowering(&lines, (idx + 1)..<end)
                }
                aliases.append(SectionAlias(heading: m.text, role: role))
            case .split(let plan):
                let replacement = renderSplitPlan(plan, headingHashes: m.hashes, headingText: m.text)
                splitEdits.append(SplitEdit(range: idx..<end, replacement: replacement))
                for (i, segment) in plan.executableSegments.enumerated() {
                    let suffix = i == 0 ? "" : " \(i + 1)"
                    let role = segment.kind == .aiInference ? SkillSectionRole.procedure : plan.execSegmentRole
                    aliases.append(SectionAlias(heading: "\(m.text)\(Self.splitHeadingSeparator)\(suffix)", role: role))
                }
                unminedContracts.append(contentsOf: plan.unminedContracts)
            }
        }

        for edit in splitEdits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            lines.replaceSubrange(edit.range, with: edit.replacement)
        }
        return (lines.joined(separator: "\n"), aliases, unminedContracts)
    }

    func shouldNormalizeExecutableBody(forHeading heading: String) -> Bool {
        switch SkillSectionRole.builtinRole(forHeading: heading) {
        case .procedure, .invariants, .prohibitions, .applicability, .negativeApplicability:
            return true
        default:
            return false
        }
    }

    /// When a document has no `##`/`###` headings, wrap prose paragraphs under
    /// `## Overview (( inert ))`. Markdown list items are treated as procedure
    /// candidates after presentation formatting is stripped, so strict compile
    /// gets the first chance to lower them.
    func wrapHeadinglessNarrativeIfNeeded(_ lines: [String], bodyStart: Int,
                                                  knowledge: Compiler.KnowledgeContext)
        throws -> (markdown: String, aliases: [SectionAlias]) {
        var lines = lines
        let body = lines[bodyStart..<lines.count]
        if sectionIsExecutableOnly(body, knowledge: knowledge) {
            normalizeMarkdownFormattingForLowering(&lines, bodyStart..<lines.count)
            return (lines.joined(separator: "\n"), [])
        }
        guard headinglessBodyNeedsInertOverview(body, knowledge: knowledge) else {
            normalizeMarkdownFormattingForLowering(&lines, bodyStart..<lines.count)
            return (lines.joined(separator: "\n"), [])
        }

        let insertAt = headinglessOverviewInsertIndex(lines, bodyStart: bodyStart)
        trace.log(.skill, "heading-less narrative: insert ## Overview (( role: reference )) at L\(insertAt + 1)")
        lines.insert("## Overview (( role: reference ))", at: insertAt)
        if insertAt + 1 < lines.count,
           !lines[insertAt + 1].trimmingCharacters(in: .whitespaces).isEmpty {
            lines.insert("", at: insertAt + 1)
        }
        return (lines.joined(separator: "\n"), [])
    }

    /// Index at which to insert `## Overview (( inert ))`: immediately after a
    /// leading `#` title and any following blank lines, or at the first body line.
    func headinglessOverviewInsertIndex(_ lines: [String], bodyStart: Int) -> Int {
        var i = bodyStart
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.isEmpty { i += 1; continue }
            if t.hasPrefix("#") && !t.hasPrefix("##") {
                var j = i + 1
                while j < lines.count, lines[j].trimmingCharacters(in: .whitespaces).isEmpty {
                    j += 1
                }
                return j
            }
            break
        }
        return i
    }

    /// True when a heading-less body reads as prose narrative rather than a flat
    /// procedure candidate. Markdown list markers and inline presentation do not
    /// decide inertness by themselves.
    func headinglessBodyNeedsInertOverview(_ body: ArraySlice<String>,
                                                   knowledge: Compiler.KnowledgeContext) -> Bool {
        let classifier = ConditionClassifier(symbols: knowledge.symbols, lexicon: knowledge.lexicon, trace: trace)
        for raw in body {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("##") { continue }
            if trimmed.hasPrefix(">") { continue }

            let stripped = stripMarkdownListMarker(trimmed)
            let text = normalizeMarkdownLineForLowering(stripped)
            if text.isEmpty { continue }

            if isTaskListLine(stripped) {
                let item = normalizeMarkdownLineForLowering(stripTaskListBox(stripped))
                if case .fuzzy = classifier.classify(item) { return true }
                continue
            }

            if case .fuzzy = classifier.classify(text) { return true }
            if !isMarkdownListLine(trimmed), !isProcedureCandidateLine(text) { return true }
        }
        return false
    }

    /// Markdown surface signals that still indicate documentation rather than a
    /// flat procedure step after formatting is stripped.
    func lineHasMarkdownNarrativeMarkers(_ line: String) -> Bool {
        if isTaskListLine(line) { return false }
        if line.hasSuffix(":") { return true }
        return false
    }
    // MARK: - Marking helpers

    /// Index of the first body line (after a leading `--- … ---` frontmatter
    /// block), or 0 when there is no frontmatter.
    func frontmatterEnd(_ lines: [String]) -> Int {
        FrontmatterScanner.locate(lines, skipLeadingBlanks: false).map { $0.close + 1 } ?? 0
    }

    func headingMatch(_ line: String) -> (hashes: String, text: String)? {
        SkillMarkdownShape.headingMatch(line)
    }

    /// Indices of real (top-level) headings from `from` onward, skipping any
    /// `#`-prefixed line inside a fenced code block. A ` ```markdown ` output
    /// template commonly embeds `##`/`### ` lines as literal page-template
    /// content (e.g. media-ingest's brain-page template); without fence
    /// tracking those get treated as genuine section boundaries, and the
    /// marking/split pass then injects inert markers and generated sibling
    /// headings INSIDE the fence — corrupting it into multiple broken pieces
    /// with stray content between the original opening and closing backticks
    /// (mirrors `SkillMetrics`'s `inFence` tracking for the same reason).
    static func topLevelHeadingIndices(
        _ lines: [String], from start: Int, headingMatch: (String) -> (hashes: String, text: String)?
    ) -> [Int] {
        var result: [Int] = []
        var inFence = false
        for idx in lines.indices where idx >= start {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inFence.toggle()
                continue
            }
            if inFence { continue }
            if headingMatch(lines[idx]) != nil { result.append(idx) }
        }
        return result
    }

    /// Merge corpus rulebooks supplied to the migrator so heading-role
    /// decisions match what strict compile will see (`erp.merrules`'s
    /// `section "Controls" -> invariants`, etc.).
    func mergedRulebook() throws -> Rulebook {
        var book = Rulebook.empty
        for input in rulebookInputs {
            book = book.merging(try RulebookParser().parse(input.source, file: input.file))
        }
        return book
    }

    /// Built-in heading synonym first, then author rulebook `=== sections ===`
    /// alias — same precedence as `SkillSectionBuilder` / `SkillMetrics`.
    func derivedRole(forHeading heading: String, rulebook: Rulebook) -> SkillSectionRole? {
        rulebook.role(forHeading: heading) ?? SkillSectionRole.builtinRole(forHeading: heading)
    }

    /// Decide how to handle `heading`, by the rulebook/built-in role alias and, for
    /// unrecognized headings, whether the body restates a rulebook convention,
    /// then whether the body is provably executable-only.
    func decision(forHeading heading: String, body: ArraySlice<String>,
                          knowledge: Compiler.KnowledgeContext, rulebook: Rulebook) throws -> MarkDecision {
        switch derivedRole(forHeading: heading, rulebook: rulebook) {
        case .invariants:
            return checkableRoleDecision(heading: heading, body: body, knowledge: knowledge, role: .invariants)
        case .prohibitions:
            return checkableRoleDecision(heading: heading, body: body, knowledge: knowledge, role: .prohibitions)
        case .applicability:
            return checkableRoleDecision(heading: heading, body: body, knowledge: knowledge, role: .applicability)
        case .negativeApplicability:
            return checkableRoleDecision(heading: heading, body: body, knowledge: knowledge, role: .negativeApplicability)
        case .procedure:
            if sectionIsExecutableOnly(body, knowledge: knowledge) { return .leaveUnmarked }
            if bodyIsJudgmentWrapped(heading: heading, body: body) { return .leaveUnmarked }
            if heading.contains(Self.splitHeadingSeparator) { return .leaveUnmarked }
            let plan = splitPlanApplyingThreshold(body, knowledge: knowledge, roleAlreadyAsserted: true)
            if plan.executableSegments.isEmpty {
                // No exec/AI-inference content at all: an operational-error
                // body is simply left unmarked so the real compiler processes
                // it and raises its own reword diagnostic; a genuinely
                // cue-less/signal-less body becomes `reference` documentation.
                if plan.operationalErrorWorthy { return .leaveUnmarked }
                return .inline("(( role: reference ))")
            }
            return .split(plan: plan)
        case .template:
            return sectionIsTemplateBody(body) ? .leaveUnmarked : .inline("(( role: template ))")
        case .tools:
            return sectionIsToolListBody(body) ? .leaveUnmarked : .inline("(( role: tools ))")
        case .some:
            // Domain / tables sections are already declarative metadata with
            // closed parsers; leave them to their role-specific handlers.
            return .leaveUnmarked
        case .none:
            // 1D: a section whose body verbatim restates an external rulebook
            // convention is recorded as `convention-ref` (non-executable
            // metadata) rather than generic documentation.
            if try bodyRestatesConvention(body) { return .inline("(( role: convention-ref ))") }
            // An unrecognized *executable* heading is routed to
            // `procedure` via a rulebook alias — preferred over an inline marker
            // (see docs/13). Other unknowns are classified per P1.
            if sectionIsExecutableOnly(body, knowledge: knowledge) { return .alias(.procedure) }
            if bodyIsJudgmentWrapped(heading: heading, body: body) { return .alias(.procedure) }
            if heading.contains(Self.splitHeadingSeparator) { return .leaveUnmarked }
            let plan = splitPlanApplyingThreshold(body, knowledge: knowledge)
            if plan.executableSegments.isEmpty {
                if plan.operationalErrorWorthy {
                    // No cue at all, but real operational/normative signal:
                    // alias to `.procedure` and leave the body untouched so
                    // the real compiler raises its own precise reword
                    // diagnostic (P1 category 4) — no migrator-side marker.
                    return .alias(.procedure)
                }
                // Genuinely documentary, no signal at all.
                return .inline("(( role: reference ))")
            }
            return .split(plan: plan)
        }
    }

    /// `invariants`/`prohibitions`/`applicability`/`negativeApplicability`
    /// share one shape: a fully checkable body stays clean. Otherwise, apply
    /// the P1 four-way split: checkable lines lower as their own child;
    /// AI-inference-cue lines become their own judgment-wrapped child;
    /// anything else is left for the real per-line checkable-role builder to
    /// reject with its own precise `uncheckablePredicate` diagnostic — a
    /// `## Contract` heading explicitly asserting guarantees, or
    /// `## Anti-Patterns` explicitly asserting prohibitions, with content that
    /// is neither checkable nor AI-cued is not free documentation; it is a
    /// reword error (P1 category 4), never a silent inert/reference escape.
    func checkableRoleDecision(heading: String, body: ArraySlice<String>,
                                       knowledge: Compiler.KnowledgeContext, role: SkillSectionRole) -> MarkDecision {
        if sectionIsCheckableRoleBody(body, knowledge: knowledge) { return .leaveUnmarked }
        if bodyIsJudgmentWrapped(heading: heading, body: body) { return .leaveUnmarked }
        if heading.contains(Self.splitHeadingSeparator) { return .leaveUnmarked }
        // `checkableOnly: true` restricts the split's own `.exec` classification
        // to `isCheckableCondition` — no `lowersAsStatement`/backtick-command/
        // choice-gate fallback — so every segment this produces is guaranteed
        // checkable-predicate-shaped, matching what `execSegmentRole` (set
        // below) routes it to.
        var plan = splitPlanApplyingThreshold(body, knowledge: knowledge, roleAlreadyAsserted: true, checkableOnly: true)
        plan.execSegmentRole = role
        if plan.executableSegments.isEmpty {
            if plan.operationalErrorWorthy {
                // No inference cue: leave the heading exactly as its natural
                // checkable role. `SkillSectionBuilder.assertLine` already
                // throws a precise `uncheckablePredicate` naming the exact
                // reword needed for the first non-checkable line — no
                // migrator-side marker, no silent judgment-wrap.
                return .leaveUnmarked
            }
            // No signal at all despite the role heading: genuinely documentary.
            return .inline("(( role: reference ))")
        }
        return .split(plan: plan)
    }

    /// True when `body`'s first content line is already the exact judgment
    /// wrap this migrator generates for an AI-inference section. Re-running
    /// the marking pass on an already-wrapped section must be a no-op, not a
    /// second, nested `use judgment to …:` line.
    func bodyIsJudgmentWrapped(heading: String, body: ArraySlice<String>) -> Bool {
        guard let first = body.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return false }
        return first.trimmingCharacters(in: .whitespaces) == "use judgment to follow the \(heading) guidance:"
    }
    /// Parsed, normalized rulebook convention strings (each rule's `action`
    /// and `body`) used for convention-restatement detection. A rulebook
    /// input that fails to parse is a real authoring error in the supplied
    /// `.merrules` — surfaced here rather than silently treated as "no
    /// conventions" (which would have made every restated-convention section
    /// fall through to generic `(( inert ))`, losing the more specific
    /// `convention-ref` marker with no indication why).
    func conventionStrings() throws -> Set<String> {
        var out: Set<String> = []
        for input in rulebookInputs {
            let book = try RulebookParser().parse(input.source, file: input.file)
            for rule in book.conventions {
                let action = SkillMigrator.normalizeConvention(rule.action)
                let body = SkillMigrator.normalizeConvention(rule.body)
                if !action.isEmpty { out.insert(action) }
                if !body.isEmpty { out.insert(body) }
            }
        }
        return out
    }

    /// True iff every non-blank, non-fence body line restates a known rulebook
    /// convention (exact, case-insensitive, punctuation/whitespace-normalized).
    func bodyRestatesConvention(_ body: ArraySlice<String>) throws -> Bool {
        let conventions = try conventionStrings()
        guard !conventions.isEmpty else { return false }
        var sawContent = false
        var inFence = false
        for raw in body {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") { inFence.toggle(); continue }
            if inFence || t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
            sawContent = true
            let normalized = SkillMigrator.normalizeConvention(t)
            if !conventions.contains(normalized) { return false }
        }
        return sawContent
    }

    /// Normalize a convention/section line for exact comparison: lowercased,
    /// list-marker stripped, internal whitespace collapsed, trailing punctuation
    /// removed.
    static func normalizeConvention(_ s: String) -> String {
        Rulebook.normalizeLine(s, stripListMarkers: true)
    }

    /// True iff every non-blank body line is a structurally checkable predicate
    /// once Markdown bullet/number markers are stripped. This is intentionally
    /// all-or-nothing: one narrative intro line keeps the section inert so the
    /// author can split prose from executable assertions.
    func sectionIsCheckableRoleBody(_ body: ArraySlice<String>,
                                            knowledge: Compiler.KnowledgeContext) -> Bool {
        let trial = TrialLowering(knowledge: knowledge)
        var sawContent = false
        for raw in body {
            let t = normalizeMarkdownLineForLowering(stripMarkdownListMarker(raw.trimmingCharacters(in: .whitespaces)))
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }
            sawContent = true
            if trial.isCheckableCondition(t) { continue }
            return false
        }
        return sawContent
    }
}
