import Foundation

extension SkillMigrator {
    /// True iff every non-blank body line is already executable by today's
    /// deterministic Markdown surface, is a Markdown list item that should be
    /// tried as a procedure line after presentation formatting is stripped, or
    /// (AGENTS.md Phase 1 item 1/3) trial-lowers as a real statement against the
    /// migrator's own `SymbolTable`/lexicon/rulebook. It deliberately rejects
    /// mixed prose paragraphs.
    func sectionIsExecutableOnly(_ body: ArraySlice<String>,
                                         knowledge: Compiler.KnowledgeContext) -> Bool {
        var sawContent = false
        var pendingTableMarker = false
        var pendingChecklistMarker = false
        let classifier = ConditionClassifier(symbols: knowledge.symbols, lexicon: knowledge.lexicon, trace: trace)
        let trial = TrialLowering(knowledge: knowledge, probeTally: probeSession.tally)

        var i = body.startIndex
        while i < body.endIndex {
            let raw = body[i]
            var t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("```") {
                let lang = String(t.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased()
                let executableFence = isShellFence(lang) || knowledge.lexicon.fenceTool(for: lang) != nil
                guard executableFence else { return false }
                var fenceLines = [raw]
                var j = body.index(after: i)
                while j < body.endIndex {
                    fenceLines.append(body[j])
                    let closed = body[j].trimmingCharacters(in: .whitespaces).hasPrefix("```")
                    j = body.index(after: j)
                    if closed { break }
                }
                // A shell/tool fence whose payload is only comments is guidance
                // for the agent, not a deterministic command to lower. Treating
                // it as executable-only produces an empty/no-op strict section
                // instead of routing the operational instruction through
                // judgment.
                guard Self.executableFenceContent(fenceLines).hasExecutableLine else { return false }
                sawContent = true
                i = j
                continue
            }
            i = body.index(after: i)
            if t.isEmpty || t.hasPrefix("#") || t.hasPrefix(">") { continue }

            let wasMarkdownList = isMarkdownListLine(t)
            t = normalizeMarkdownLineForLowering(stripMarkdownListMarker(t))
            if t.isEmpty { continue }
            sawContent = true

            if t.hasPrefix("!!! table") {
                pendingTableMarker = !t.lowercased().contains(TableMode.inert.sentinelToken)
                continue
            }
            if pendingTableMarker {
                if isMarkdownTableLine(t) { continue }
                pendingTableMarker = false
            }

            if t.hasPrefix("!!! checklist") {
                pendingChecklistMarker = !t.lowercased().contains(ChecklistMode.inert.sentinelToken)
                continue
            }
            if pendingChecklistMarker {
                if isTaskListLine(t) { continue }
                pendingChecklistMarker = false
            }

            if isWholeLineBacktickedCommand(t) { continue }
            if isChoiceGateLine(t, lexicon: knowledge.lexicon) { continue }
            if isTaskListLine(t) {
                let item = normalizeMarkdownLineForLowering(stripTaskListBox(t))
                if trial.isCheckableCondition(item) { continue }
                if trial.lowersAsStatement(item) { continue }
            }
            if wasMarkdownList {
                if case .fuzzy = classifier.classify(t) { return false }
                if lineHasMarkdownNarrativeMarkers(t) { return false }
                continue
            }
            // A plain-statement procedure line with no Markdown list marker
            // (e.g. "Validate the order.") — try the real parser+lowerer
            // before giving up, now that real vocabulary is threaded in.
            if trial.lowersAsStatement(t) { continue }
            return false
        }
        return sawContent
    }
}
