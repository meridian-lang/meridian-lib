import Testing
@testable import MeridianCore

// Unit tests for SkillMigrator's deterministic marking pass (the logic the CLI
// `migrate-skill` runs). The pass blockquotes pre-heading preamble and appends
// authoritative `(( … ))` markers to headings that would not otherwise resolve
// to an executable role. It injects no frontmatter and does NOT strip
// `skill: true`. These tests exercise the transform directly (no compile).

@Suite("SkillMigrator — marking pass")
struct SkillMigratorMarkingTests {

    static func migrator() -> SkillMigrator {
        SkillMigrator(
            compiler: Compiler(options: .init(trace: .silent())),
            vocabularies: [],
            rulebooks: []
        )
    }

    static func mark(_ source: String) -> String {
        migrator().markSections(source).markdown
    }

    static func aliases(_ source: String) -> [SkillMigrator.SectionAlias] {
        migrator().markSections(source).aliases
    }

    @Test("prose Contract is marked inert with the invariants role")
    func contractInert() {
        let out = Self.mark("""
        # Title

        ## Contract

        This skill guarantees a thing.
        """)
        #expect(out.contains("## Contract (( inert, role: invariants ))"),
                Comment(rawValue: out))
    }

    @Test("Anti-Patterns is marked inert with the prohibitions role")
    func antiPatternsInert() {
        let out = Self.mark("""
        ## Anti-Patterns

        - Don't do the bad thing.
        """)
        #expect(out.contains("## Anti-Patterns (( inert, role: prohibitions ))"),
                Comment(rawValue: out))
    }

    @Test("an unrecognized pure-shell heading is routed to a procedure rulebook alias, not an inline marker")
    func pureShellBecomesProcedure() {
        let source = """
        ## How to use

        ```bash
        gbrain capture "x"
        ```
        """
        let out = Self.mark(source)
        // The heading stays clean — no inline marker.
        #expect(out.contains("## How to use\n") || out.hasSuffix("## How to use"),
                Comment(rawValue: out))
        #expect(!out.contains("(( role: procedure ))"), Comment(rawValue: out))
        // …the role is emitted as a rulebook section alias instead.
        let aliases = Self.aliases(source)
        #expect(aliases == [SkillMigrator.SectionAlias(heading: "How to use", role: .procedure)],
                Comment(rawValue: "\(aliases)"))
    }

    @Test("aliasRulebook renders a === sections === input for the chosen aliases")
    func aliasRulebookRendered() {
        let books = SkillMigrator.aliasRulebook(
            [SkillMigrator.SectionAlias(heading: "How to use", role: .procedure)])
        #expect(books.count == 1)
        #expect(books.first?.source.contains("=== sections ===") == true)
        #expect(books.first?.source.contains("section \"How to use\" -> procedure") == true)
        #expect(SkillMigrator.aliasRulebook([]).isEmpty)
    }

    @Test("an unrecognized narrative heading is marked inert")
    func narrativeInert() {
        let out = Self.mark("""
        ## Background

        Some descriptive prose about the design.
        """)
        #expect(out.contains("## Background (( inert ))"), Comment(rawValue: out))
    }

    @Test("recognized procedure / applicability headings are left unmarked")
    func recognizedUnmarked() {
        let out = Self.mark("""
        ## Phases

        do the thing.

        ## When to invoke

        - "trigger phrase"
        """)
        #expect(out.contains("## Phases\n"), Comment(rawValue: out))
        #expect(!out.contains("## Phases ("), Comment(rawValue: out))
        #expect(out.contains("## When to invoke\n"), Comment(rawValue: out))
        #expect(!out.contains("## When to invoke ("), Comment(rawValue: out))
    }

    @Test("Phase N: heading is recognized as procedure and left unmarked")
    func phasePrefixUnmarked() {
        let out = Self.mark("""
        ## Phase 1: Inventory

        do the inventory.
        """)
        #expect(!out.contains("Phase 1: Inventory ("), Comment(rawValue: out))
    }

    @Test("pre-heading preamble content is blockquoted; comments/blanks are not")
    func preambleBlockquoted() {
        let out = Self.mark("""
        ---
        name: demo
        ---

        Intro paragraph that is plain prose.

        > already a convention note

        ## Phases

        do the thing.
        """)
        #expect(out.contains("> Intro paragraph that is plain prose."), Comment(rawValue: out))
        // The frontmatter delimiters must NOT be blockquoted.
        #expect(out.contains("\n---\nname: demo\n---\n") || out.hasPrefix("---\nname: demo\n---"),
                Comment(rawValue: out))
        // An existing blockquote is left as-is (not double-quoted).
        #expect(!out.contains("> > already a convention note"), Comment(rawValue: out))
    }

    @Test("the marking pass is idempotent")
    func idempotent() {
        let source = """
        ## Contract

        guarantees prose.

        ## Notes

        narrative.
        """
        let once = Self.mark(source)
        let twice = Self.mark(once)
        #expect(once == twice, Comment(rawValue: "once:\n\(once)\n\ntwice:\n\(twice)"))
    }

    @Test("a heading-less document is returned untouched")
    func headingLessUntouched() {
        let source = "do the first thing.\ndo the second thing.\n"
        #expect(Self.mark(source) == source)
    }

    @Test("skill: true is NOT stripped (one-time corpus edit, not a reusable transform)")
    func keepsSkillTrue() {
        let out = Self.mark("""
        ---
        name: demo
        skill: true
        ---

        ## Phases

        do the thing.
        """)
        #expect(out.contains("skill: true"), Comment(rawValue: out))
    }
}
