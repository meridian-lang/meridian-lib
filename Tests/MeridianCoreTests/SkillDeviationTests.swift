import Testing
import Foundation
@testable import MeridianCore

// Unit tests for the SkillDeviation helper: frontmatter delta, normalized
// "changed" detection, LCS unified diff, similarity/tier classification, and the
// slug/meriStem pairing helpers shared with the migrate-skill command.

@Suite("SkillDeviation")
struct SkillDeviationTests {

    @Test("frontmatter Added captures injected keys; Removed captures dropped keys")
    func frontmatterAddedRemoved() {
        let original = """
        ---
        name: demo
        legacy: true
        ---
        Body line.
        """
        let ported = """
        ---
        vocabulary: brain.merconfig
        skill: true
        rulebook: brain.merrules
        name: demo
        ---
        Body line.
        """
        let r = SkillDeviation.analyze(
            originalMarkdown: original, portedMeri: ported,
            originalName: "demo/SKILL.md", portedName: "demo.meri"
        )
        #expect(r.frontmatterAdded == ["rulebook", "skill", "vocabulary"])
        #expect(r.frontmatterRemoved == ["legacy"])
    }

    @Test("Changed ignores YAML-vs-inline list reformatting but flags real scalar changes")
    func frontmatterChangedNormalization() {
        let original = """
        ---
        tools:
          - read
          - write
        priority: high
        ---
        Body.
        """
        let ported = """
        ---
        tools: write, read
        priority: low
        ---
        Body.
        """
        let r = SkillDeviation.analyze(
            originalMarkdown: original, portedMeri: ported,
            originalName: "a", portedName: "b"
        )
        // `tools` only reordered/reformatted -> not changed; `priority` value differs.
        #expect(!r.frontmatterChanged.contains("tools"))
        #expect(r.frontmatterChanged.contains("priority"))
    }

    @Test("identical sources -> empty diff, similarity 1.0, tier 1")
    func identicalSources() {
        let src = """
        ---
        name: x
        ---
        line one
        line two
        """
        let r = SkillDeviation.analyze(
            originalMarkdown: src, portedMeri: src,
            originalName: "x", portedName: "x"
        )
        #expect(r.unifiedDiff.isEmpty)
        #expect(r.similarity == 1.0)
        #expect(r.tier == 1)
        #expect(r.added == 0 && r.removed == 0)
    }

    @Test("differing bodies produce a non-empty diff with +/- markers")
    func differingBodies() {
        let a = "alpha\nbeta\ngamma"
        let b = "alpha\ndelta\ngamma"
        let r = SkillDeviation.analyze(
            originalMarkdown: a, portedMeri: b,
            originalName: "a", portedName: "b"
        )
        #expect(!r.unifiedDiff.isEmpty)
        #expect(r.unifiedDiff.contains("-beta"))
        #expect(r.unifiedDiff.contains("+delta"))
        #expect(r.added == 1 && r.removed == 1)
    }

    @Test("tier thresholds: near-verbatim -> 1, moderate -> 2, rewrite -> 3")
    func tierThresholds() {
        #expect(SkillDeviation.tier(for: 0.95) == 1)
        #expect(SkillDeviation.tier(for: 0.85) == 1)
        #expect(SkillDeviation.tier(for: 0.70) == 2)
        #expect(SkillDeviation.tier(for: 0.50) == 2)
        #expect(SkillDeviation.tier(for: 0.30) == 3)
    }

    @Test("rewritten body classifies as tier 3")
    func rewriteTier() {
        let a = (1...20).map { "original line \($0)" }.joined(separator: "\n")
        let b = (1...20).map { "completely different content \($0)" }.joined(separator: "\n")
        let r = SkillDeviation.analyze(
            originalMarkdown: a, portedMeri: b,
            originalName: "a", portedName: "b"
        )
        #expect(r.tier == 3)
    }

    @Test("section-marker-added and shell-block-routed detected from the port's markers")
    func markerCategories() {
        let original = """
        ## Contract

        guarantees.

        ## How to use

        ```bash
        gbrain sync
        ```
        """
        let ported = """
        ## Contract (( inert, role: invariants ))

        guarantees.

        ## How to use (( role: procedure ))

        ```bash
        gbrain sync
        ```
        """
        let r = SkillDeviation.analyze(
            originalMarkdown: original, portedMeri: ported,
            originalName: "a", portedName: "b"
        )
        #expect(r.categories.contains("section-marker-added"))
        #expect(r.categories.contains("shell-block-routed"))
        #expect(!r.categories.contains("preamble-blockquoted"))
    }

    @Test("preamble-blockquoted detected when the port blockquotes pre-heading prose")
    func preambleBlockquoteCategory() {
        let original = """
        Intro paragraph that is plain prose.

        ## Phases

        do the thing. (( role: procedure ))
        """
        let ported = """
        > Intro paragraph that is plain prose.

        ## Phases

        do the thing. (( role: procedure ))
        """
        let r = SkillDeviation.analyze(
            originalMarkdown: original, portedMeri: ported,
            originalName: "a", portedName: "b"
        )
        #expect(r.categories.contains("preamble-blockquoted"))
    }

    @Test("frontmatter-injected listed first when keys are added")
    func frontmatterInjectedCategory() {
        let original = "## Phases\n\ndo it."
        let ported = "---\nname: x\n---\n## Phases (( inert ))\n\ndo it."
        let r = SkillDeviation.analyze(
            originalMarkdown: original, portedMeri: ported,
            originalName: "a", portedName: "b"
        )
        #expect(r.categories.first == "frontmatter-injected")
        #expect(r.categories.contains("section-marker-added"))
    }

    @Test("slug + meriStem pairing maps skill dirs and top-level docs")
    func pairingHelpers() {
        #expect(SkillDeviation.slug("academic-verify") == "academic_verify")
        #expect(SkillDeviation.slug("Daily Task Manager") == "daily_task_manager")

        let skillURL = URL(fileURLWithPath: "/x/academic-verify/SKILL.md")
        #expect(SkillDeviation.meriStem(forSkillAt: skillURL) == "academic_verify")

        let resolverURL = URL(fileURLWithPath: "/x/RESOLVER.md")
        #expect(SkillDeviation.meriStem(forSkillAt: resolverURL) == "resolver")
    }

    @Test("renderMarkdown produces a report with the expected sections")
    func renderMarkdown() {
        let r = SkillDeviation.analyze(
            originalMarkdown: "---\nname: x\n---\nbody",
            portedMeri: "---\nname: x\nskill: true\n---\nbody",
            originalName: "x/SKILL.md", portedName: "x.meri"
        )
        let md = SkillDeviation.renderMarkdown(r, includeDiff: true)
        #expect(md.contains("# Deviation: x.meri"))
        #expect(md.contains("## Frontmatter"))
        #expect(md.contains("## Categories"))
        #expect(md.contains("```diff"))
        // New unified-diff style: file headers + a numbered hunk header.
        #expect(md.contains("--- x/SKILL.md"))
        #expect(md.contains("+++ x.meri"))
        #expect(md.contains("@@ -"))
        // The per-file report no longer renders a "Changed:" frontmatter line
        // and the Lines bullet no longer carries an "unchanged" suffix.
        #expect(!md.contains("- Changed:"))
        #expect(!md.contains("unchanged)"))
    }

    @Test("difflib ratio: 2*M/(n+m), and a single-line range omits the count")
    func difflibRatioAndRangeFormat() {
        // a has 4 lines, b has 5 (one inserted). M (matched) = 4.
        // ratio = 2*4 / (4+5) = 0.888… -> 89%.
        let a = "one\ntwo\nthree\nfour"
        let b = "one\ntwo\nINSERTED\nthree\nfour"
        let r = SkillDeviation.analyze(
            originalMarkdown: a, portedMeri: b, originalName: "a", portedName: "b"
        )
        #expect(Int((r.similarity * 100).rounded()) == 89, Comment(rawValue: "\(r.similarity)"))
        #expect(r.added == 1 && r.removed == 0 && r.unchanged == 4)
        // The original side spans 4 lines (no change removed) while the ported
        // side gains a line; difflib renders an inserted hunk. The insert sits
        // between context, so the body carries the inserted line with `+`.
        #expect(r.unifiedDiff.contains("+INSERTED"), Comment(rawValue: r.unifiedDiff))
    }

    @Test("difflib SequenceMatcher matches Python: matchCount, opcodes, ratio")
    func difflibMatcherParity() {
        // Mirror of Python: difflib.SequenceMatcher(None, a, b).
        let a = ["a", "b", "x", "c", "d"]
        let b = ["a", "b", "y", "c", "d"]
        let m = DiffMatcher(a, b)
        // 'a','b' (2) + 'c','d' (2) match; 'x'/'y' differ -> M = 4.
        #expect(m.matchCount() == 4)
        // ratio = 2*4 / (5+5) = 0.8
        #expect(m.ratio() == 0.8)
        // _format_range_unified: single line -> no comma; empty -> begins one earlier.
        #expect(DiffMatcher.formatRangeUnified(4, 5) == "5")
        #expect(DiffMatcher.formatRangeUnified(0, 0) == "0,0")
        #expect(DiffMatcher.formatRangeUnified(19, 26) == "20,7")
    }

    @Test("hunk headers carry 1-based start lines and per-side counts")
    func hunkHeaderLineNumbers() {
        // 5 identical context lines, then a change on line 6.
        let a = (1...5).map { "line \($0)" }.joined(separator: "\n") + "\nold tail"
        let b = (1...5).map { "line \($0)" }.joined(separator: "\n") + "\nnew tail"
        let r = SkillDeviation.analyze(
            originalMarkdown: a, portedMeri: b, originalName: "a", portedName: "b"
        )
        // Change at line 6 with 3 lines of leading context -> hunk starts at line 3.
        #expect(r.unifiedDiff.contains("@@ -3,4 +3,4 @@"), Comment(rawValue: r.unifiedDiff))
        #expect(r.unifiedDiff.contains("-old tail"))
        #expect(r.unifiedDiff.contains("+new tail"))
    }
}
