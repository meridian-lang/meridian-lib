import Testing
@testable import MeridianCore

// Unit tests for SkillMigrator's deterministic marking pass (the logic the CLI
// `migrate-skill` runs). The pass blockquotes pre-heading preamble and appends
// authoritative `(( … ))` markers to headings that would not otherwise resolve
// to an executable role. It injects no frontmatter and does NOT strip
// `skill: true`. These tests exercise the transform directly (no compile).

@Suite("SkillMigrator — marking pass")
struct SkillMigratorMarkingTests {

    static func migrator(rulebooks: [RulebookInput] = []) -> SkillMigrator {
        SkillMigrator(
            compiler: Compiler(options: .init(trace: .silent())),
            vocabularies: [],
            rulebooks: rulebooks
        )
    }

    static func mark(_ source: String, rulebooks: [RulebookInput] = []) throws -> String {
        try migrator(rulebooks: rulebooks).markSections(source).markdown
    }

    static func aliases(_ source: String) throws -> [SkillMigrator.SectionAlias] {
        try migrator().markSections(source).aliases
    }

    @Test("prose Contract is marked inert with the invariants role")
    func contractInert() throws {
        let out = try Self.mark("""
        # Title

        ## Contract

        This skill guarantees a thing.
        """)
        #expect(out.contains("## Contract (( inert, role: invariants ))"),
                Comment(rawValue: out))
    }

    @Test("Anti-Patterns is marked inert with the prohibitions role")
    func antiPatternsInert() throws {
        let out = try Self.mark("""
        ## Anti-Patterns

        - Don't do the bad thing.
        """)
        #expect(out.contains("## Anti-Patterns (( inert, role: prohibitions ))"),
                Comment(rawValue: out))
    }

    @Test("checkable Contract and Anti-Patterns remain executable")
    func checkableRoleSectionsExecutable() throws {
        let out = try Self.mark("""
        ## Contract

        - the page count is at least 1

        ## Anti-Patterns

        - the error count is greater than 0
        """)
        #expect(out.contains("## Contract\n"), Comment(rawValue: out))
        #expect(!out.contains("## Contract (("), Comment(rawValue: out))
        #expect(out.contains("## Anti-Patterns\n"), Comment(rawValue: out))
        #expect(!out.contains("## Anti-Patterns (("), Comment(rawValue: out))
    }

    @Test("mixed prose keeps Contract inert even with checkable bullets")
    func mixedContractStillInert() throws {
        let out = try Self.mark("""
        ## Contract

        This skill guarantees:
        - the page count is at least 1
        """)
        #expect(out.contains("## Contract (( inert, role: invariants ))"),
                Comment(rawValue: out))
    }

    @Test("an unrecognized pure-shell heading is routed to a procedure rulebook alias, not an inline marker")
    func pureShellBecomesProcedure() throws {
        let source = """
        ## How to use

        ```bash
        gbrain capture "x"
        ```
        """
        let out = try Self.mark(source)
        // The heading stays clean — no inline marker.
        #expect(out.contains("## How to use\n") || out.hasSuffix("## How to use"),
                Comment(rawValue: out))
        #expect(!out.contains("(( role: procedure ))"), Comment(rawValue: out))
        // …the role is emitted as a rulebook section alias instead.
        let aliases = try Self.aliases(source)
        #expect(aliases == [SkillMigrator.SectionAlias(heading: "How to use", role: .procedure)],
                Comment(rawValue: "\(aliases)"))
    }

    @Test("an unrecognized whole-line command section is routed to a procedure alias")
    func commandOnlyBecomesProcedure() throws {
        let source = """
        ## Post import

        - `gbrain extract links --source db` -- extract links
        - `gbrain stats`
        """
        let out = try Self.mark(source)
        #expect(out.contains("## Post import\n"), Comment(rawValue: out))
        #expect(!out.contains("## Post import (("), Comment(rawValue: out))
        #expect(try Self.aliases(source) == [SkillMigrator.SectionAlias(heading: "Post import", role: .procedure)])
    }

    @Test("an unrecognized mixed prose and command section stays inert")
    func mixedCommandProseStaysInert() throws {
        let out = try Self.mark("""
        ## Post import

        Run the cleanup commands below.
        - `gbrain extract links --source db`
        """)
        #expect(out.contains("## Post import (( inert ))"), Comment(rawValue: out))
    }

    @Test("choice-only unknown heading is routed to procedure")
    func choiceOnlyBecomesProcedure() throws {
        let source = """
        ## Choose topology

        ask the user to choose between "single", "remote".
        """
        #expect(try Self.aliases(source) == [SkillMigrator.SectionAlias(heading: "Choose topology", role: .procedure)])
    }

    @Test("checkable task-list unknown heading is routed to procedure")
    func checkableTaskListBecomesProcedure() throws {
        let source = """
        ## Verification pass

        - [ ] the page count is at least 1
        - [x] the error count is less than 1
        """
        #expect(try Self.aliases(source) == [SkillMigrator.SectionAlias(heading: "Verification pass", role: .procedure)])
    }

    @Test("explicit table marker unknown heading is routed to procedure")
    func tableMarkerBecomesProcedure() throws {
        let source = """
        ## Decision table

        !!! table
        | status | action |
        |---|---|
        | ready | complete |
        """
        #expect(try Self.aliases(source) == [SkillMigrator.SectionAlias(heading: "Decision table", role: .procedure)])
    }

    @Test("non-shell fenced prose keeps unknown heading inert")
    func nonShellFenceStaysInert() throws {
        let out = try Self.mark("""
        ## Example output

        ```markdown
        # Report
        ```
        """)
        #expect(out.contains("## Example output (( inert ))"), Comment(rawValue: out))
    }

    @Test("explicit inert block marker keeps unknown heading inert")
    func inertBlockMarkerStaysInert() throws {
        let out = try Self.mark("""
        ## Reference table

        !!! table (( inert ))
        | item | note |
        |---|---|
        | a | b |
        """)
        #expect(out.contains("## Reference table (( inert ))"), Comment(rawValue: out))
    }

    @Test("numbered command item with parenthesis marker is routed to procedure")
    func numberedParenCommandBecomesProcedure() throws {
        let source = """
        ## Setup command

        1) `gbrain stats`
        """
        #expect(try Self.aliases(source) == [SkillMigrator.SectionAlias(heading: "Setup command", role: .procedure)])
    }

    @Test("markdown list items are cleaned and tried as procedure steps")
    func markdownListItemsBecomeProcedureCandidates() throws {
        let source = """
        ## Setup steps

        - **Complete** the [setup](https://example.com/setup)
        - Review __output__
        """
        let out = try Self.mark(source)
        #expect(out.contains("## Setup steps\n"), Comment(rawValue: out))
        #expect(out.contains("- Complete the setup"), Comment(rawValue: out))
        #expect(out.contains("- Review output"), Comment(rawValue: out))
        #expect(!out.contains("**"), Comment(rawValue: out))
        #expect(!out.contains("]("), Comment(rawValue: out))
        #expect(try Self.aliases(source) == [SkillMigrator.SectionAlias(heading: "Setup steps", role: .procedure)])
    }

    @Test("failed Markdown procedure item marks the whole recognized section inert")
    func failedMarkdownProcedureItemInertsSection() async throws {
        let result = try await Self.migrator().migrate("""
        ## Phases

        1. Load calendar. Check today's meetings.
        2. Compile prep briefing.
        """)

        #expect(result.compiledOK)
        #expect(result.meriSource.contains("## Phases (( inert, role: procedure ))"),
                Comment(rawValue: result.meriSource))
    }

    @Test("failed Markdown item under unknown heading marks that section inert")
    func failedUnknownMarkdownItemInertsSection() async throws {
        let result = try await Self.migrator().migrate("""
        ## Related skills

        - `skillify` — scaffolds a new skill
        - conventions/quality.md — output quality standards
        """)

        #expect(result.compiledOK)
        #expect(result.meriSource.contains("## Related skills (( inert ))"),
                Comment(rawValue: result.meriSource))
    }

    @Test("heading-less markdown list is not auto-wrapped as inert")
    func headinglessMarkdownListTriedAsProcedure() throws {
        let out = try Self.mark("""
        # Setup

        - **Complete** the [setup](https://example.com/setup)
        - Review __output__
        """)
        #expect(!out.contains("## Overview (( inert ))"), Comment(rawValue: out))
        #expect(out.contains("- Complete the setup"), Comment(rawValue: out))
        #expect(out.contains("- Review output"), Comment(rawValue: out))
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
    func narrativeInert() throws {
        let out = try Self.mark("""
        ## Background

        Some descriptive prose about the design.
        """)
        #expect(out.contains("## Background (( inert ))"), Comment(rawValue: out))
    }

    @Test("heading-less fuzzy condition line triggers overview wrap")
    func headinglessFuzzyConditionWrapped() throws {
        let out = try Self.mark("""
        # Title

        the report is notable
        """)
        #expect(out.contains("## Overview (( inert ))"), Comment(rawValue: out))
    }

    @Test("heading-less narrative SKILL is wrapped under Overview (( inert ))")
    func headinglessNarrativeWrappedInOverview() throws {
        let source = """
        # Deprecated

        This skill moved elsewhere.

        - Keep this note as documentation.
        """
        let out = try Self.mark(source)
        #expect(out.contains("## Overview (( inert ))"), Comment(rawValue: out))
        #expect(out.contains("This skill moved elsewhere."), Comment(rawValue: out))
        #expect(out.contains("- Keep this note as documentation."), Comment(rawValue: out))
    }

    @Test("install-style deprecation stub is wrapped under Overview (( inert ))")
    func installDeprecationStubWrapped() throws {
        let source = """
        # Install GBrain (Deprecated)

        This skill has been replaced by the **setup** skill. See `skills/setup/SKILL.md`.

        The setup skill provides:
        - Auto-provision Supabase via CLI (< 2 min TTHW)
        - Manual fallback with non-interactive init
        """
        let out = try Self.mark(source)
        #expect(out.contains("# Install GBrain (Deprecated)"), Comment(rawValue: out))
        #expect(out.contains("## Overview (( inert ))"), Comment(rawValue: out))
        #expect(out.contains("Auto-provision Supabase"), Comment(rawValue: out))
    }

    @Test("heading-less shell-only body stays untouched for flat procedure compile")
    func headinglessShellOnlyUntouched() throws {
        let source = """
        # Setup

        ```bash
        gbrain init
        ```
        """
        #expect(try Self.mark(source) == source)
    }

    @Test("heading-less narrative wrap is traced under .skill")
    func headinglessNarrativeTraced() throws {
        let cap = ParserTrace.capturing(categories: [.skill])
        let migrator = SkillMigrator(
            compiler: Compiler(options: .init(trace: cap.trace)),
            vocabularies: [],
            trace: cap.trace)
        _ = try migrator.markSections("""
        # Deprecated

        This skill moved elsewhere.

        - Keep this note as documentation.
        """)
        #expect(cap.lines().contains { $0.contains("Overview (( inert ))") })
    }

    @Test("narrative Tools Used command bullets are marked inert")
    func narrativeToolsUsedInert() throws {
        let out = try Self.mark("""
        ## Tools Used

        - `gbrain publish` -- deterministic HTML generation
        """)
        #expect(out.contains("## Tools Used (( inert, role: tools ))"), Comment(rawValue: out))
    }

    @Test("valid Tools Used bullets remain live")
    func validToolsUsedLive() throws {
        let out = try Self.mark("""
        ## Tools Used

        - `gbrain.publish` -- deterministic HTML generation
        - Search the brain (search)
        """)
        #expect(out.contains("## Tools Used\n"), Comment(rawValue: out))
        #expect(!out.contains("## Tools Used ("), Comment(rawValue: out))
    }

    @Test("recognized narrative procedure / applicability headings are marked inert")
    func recognizedNarrativeHeadingsBecomeInert() throws {
        let out = try Self.mark("""
        ## Phases

        do the thing.

        ## When to invoke

        - "trigger phrase"
        """)
        #expect(out.contains("## Phases (( inert, role: procedure ))"), Comment(rawValue: out))
        #expect(out.contains("## When to invoke (( inert, role: applicability ))"), Comment(rawValue: out))
    }

    @Test("recognized lowerable procedure / applicability headings are left unmarked")
    func recognizedLowerableHeadingsStayExecutable() throws {
        let out = try Self.mark("""
        ## Phases

        ```bash
        gbrain stats
        ```

        ## When to invoke

        - the page count is at least 1
        """)
        #expect(out.contains("## Phases\n"), Comment(rawValue: out))
        #expect(!out.contains("## Phases ("), Comment(rawValue: out))
        #expect(out.contains("## When to invoke\n"), Comment(rawValue: out))
        #expect(!out.contains("## When to invoke ("), Comment(rawValue: out))
    }

    @Test("Phase N: narrative heading is recognized as procedure but marked inert")
    func phasePrefixNarrativeInert() throws {
        let out = try Self.mark("""
        ## Phase 1: Inventory

        do the inventory.
        """)
        #expect(out.contains("## Phase 1: Inventory (( inert, role: procedure ))"), Comment(rawValue: out))
    }

    @Test("pre-heading preamble content is blockquoted; comments/blanks are not")
    func preambleBlockquoted() throws {
        let out = try Self.mark("""
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
    func idempotent() throws {
        let source = """
        ## Contract

        guarantees prose.

        ## Notes

        narrative.
        """
        let once = try Self.mark(source)
        let twice = try Self.mark(once)
        #expect(once == twice, Comment(rawValue: "once:\n\(once)\n\ntwice:\n\(twice)"))
    }

    @Test("a heading-less document is returned untouched")
    func headingLessUntouched() throws {
        let source = "do the first thing.\ndo the second thing.\n"
        #expect(try Self.mark(source) == source)
    }

    @Test("skill: true is NOT stripped (one-time corpus edit, not a reusable transform)")
    func keepsSkillTrue() throws {
        let out = try Self.mark("""
        ---
        name: demo
        skill: true
        ---

        ## Phases

        do the thing.
        """)
        #expect(out.contains("skill: true"), Comment(rawValue: out))
    }

    @Test("a malformed rulebook input surfaces its parse failure instead of silently disabling convention detection")
    func malformedRulebookSurfacesError() {
        let badRulebook = RulebookInput(name: "bad", file: "bad.merrules", source: """
        === conventions ===
        this is not a valid Inform-style convention rule at all
        """)
        #expect(throws: CompilerError.self) {
            _ = try Self.mark("""
            ## Background

            Some descriptive prose about the design.
            """, rulebooks: [badRulebook])
        }
    }
}
