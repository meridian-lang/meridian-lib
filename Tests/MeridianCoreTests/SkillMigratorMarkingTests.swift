import Testing
@testable import MeridianCore

// Unit tests for SkillMigrator's deterministic marking pass (the logic the CLI
// `migrate-skill` runs). The pass blockquotes pre-heading preamble and appends
// authoritative `(( … ))` markers to headings that would not otherwise resolve
// to an executable role. It injects no frontmatter and does NOT strip
// `skill: true`. These tests exercise the transform directly (no compile).

@Suite("SkillMigrator — marking pass")
struct SkillMigratorMarkingTests {

    static func migrator(vocabularies: [Compiler.VocabularyInput] = [], rulebooks: [RulebookInput] = [],
                         routeFuzzy: Bool = true) -> SkillMigrator {
        SkillMigrator(
            compiler: Compiler(options: .init()),
            vocabularies: vocabularies,
            rulebooks: rulebooks,
            options: .init(routeFuzzy: routeFuzzy)
        )
    }

    static func mark(_ source: String, vocabularies: [Compiler.VocabularyInput] = [], rulebooks: [RulebookInput] = [],
                     routeFuzzy: Bool = true) throws -> String {
        try migrator(vocabularies: vocabularies, rulebooks: rulebooks, routeFuzzy: routeFuzzy).markSections(source).markdown
    }

    static func aliases(_ source: String, vocabularies: [Compiler.VocabularyInput] = []) throws -> [SkillMigrator.SectionAlias] {
        try migrator(vocabularies: vocabularies).markSections(source).aliases
    }

    static func diagnosticsSummary(_ diagnostics: [Diagnostic]) -> String {
        diagnostics
            .map { "\($0.code.id) \($0.primaryRange): \($0.message)" }
            .joined(separator: "\n")
    }

    @Test("a Contract heading with zero checkable/normative/inference signal is left unmarked for the real compiler to reject (P1 category 4)")
    func contractOperationalErrorLeftUnmarked() throws {
        let source = """
        # Title

        ## Contract

        This skill guarantees a thing.
        """
        // No checkable predicate and no `inferenceCueWords` cue — but
        // "Contract" already asserts an invariants role, so the absence of
        // signal is not free documentation (P1 category 4: operational/
        // normative signal with no inference cue is a reword error, never a
        // silent judgment-wrap or reference escape). The migrator leaves the
        // heading and body exactly as authored; `SkillSectionBuilder.
        // assertLine` raises its own precise `uncheckablePredicate`
        // diagnostic when this is strict-compiled.
        #expect(try Self.mark(source) == source)
    }

    @Test("an Anti-Patterns heading with zero checkable/normative/inference signal is left unmarked for the real compiler to reject (P1 category 4)")
    func antiPatternsOperationalErrorLeftUnmarked() throws {
        let source = """
        ## Anti-Patterns

        - Don't do the bad thing.
        """
        #expect(try Self.mark(source) == source)
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

    @Test("mixed prose splits Contract into a clean parent and an executable invariants child (annotation label attaches to the checkable bullet)")
    func mixedContractSplits() throws {
        let source = """
        ## Contract

        This skill guarantees:
        - the page count is at least 1
        """
        let out = try Self.mark(source)
        let separator = SkillMigrator.splitHeadingSeparator
        // The colon-terminated label attaches to the checkable bullet it
        // introduces, so nothing is left over under the parent — it stays
        // completely clean rather than carrying a `(( role: reference ))`
        // marker for zero leftover content.
        #expect(out.contains("## Contract\n"), Comment(rawValue: out))
        #expect(!out.contains("## Contract (("), Comment(rawValue: out))
        #expect(out.contains("### Contract\(separator)"), Comment(rawValue: out))
        #expect(out.contains("> This skill guarantees:"), Comment(rawValue: out))
        #expect(out.contains("- the page count is at least 1"), Comment(rawValue: out))
        #expect(try Self.aliases(source) == [
            SkillMigrator.SectionAlias(heading: "Contract\(separator)", role: .invariants),
        ])
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

    @Test("a comment-only shell fence with no inference cue is an operational-error split, not an auto-judgment-wrap")
    func commentOnlyShellFenceRoutesToOperationalError() throws {
        let source = """
        ## Deal / company monitoring (cron)

        For each active item under `deals/` or `companies/`:

        ```bash
        # Weekly: pull recent news per company; flag changes for review.
        ```
        """
        let out = try Self.mark(source)
        let separator = SkillMigrator.splitHeadingSeparator
        // Neither the colon lead-in nor the fence's comment text carries an
        // `inferenceCueWords` cue, so P1 forbids auto-wrapping it in
        // judgment. It is instead pulled into its own executable-error
        // child (aliased to `.procedure`), left for the real compiler to
        // raise its own precise reword diagnostic.
        #expect(out.contains("## Deal / company monitoring (cron)\n"), Comment(rawValue: out))
        #expect(!out.contains("## Deal / company monitoring (cron) (("), Comment(rawValue: out))
        #expect(!out.contains("use judgment"), Comment(rawValue: out))
        #expect(out.contains("### Deal / company monitoring (cron)\(separator)"), Comment(rawValue: out))
        #expect(out.contains("For each active item under `deals/` or `companies/`:"), Comment(rawValue: out))
        #expect(out.contains("# Weekly: pull recent news per company; flag changes for review."), Comment(rawValue: out))
        #expect(try Self.aliases(source) == [
            SkillMigrator.SectionAlias(heading: "Deal / company monitoring (cron)\(separator)", role: .procedure),
        ])
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

    @Test("an unrecognized mixed prose and command section splits into a reference-marked parent and an executable command child")
    func mixedCommandProseSplits() throws {
        let out = try Self.mark("""
        ## Post import

        Run the cleanup commands below.
        - `gbrain extract links --source db`
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("## Post import (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("Run the cleanup commands below."), Comment(rawValue: out))
        #expect(out.contains("### Post import\(separator)"), Comment(rawValue: out))
        #expect(out.contains("gbrain extract links --source db"), Comment(rawValue: out))
    }

    @Test("structural if/otherwise chains stay together as an executable split block")
    func structuralIfChainSplitsAsExecutableBlock() throws {
        let out = try Self.mark("""
        ## Conditional flow

        Keep the branch as authored.
        if the page count is at least 1,
          complete.

        otherwise,
          complete.
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("## Conditional flow (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("### Conditional flow\(separator)"), Comment(rawValue: out))
        #expect(out.contains("if the page count is at least 1,"), Comment(rawValue: out))
        #expect(out.contains("otherwise,"), Comment(rawValue: out))
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

    @Test("non-shell fenced prose marks unknown heading as reference documentation")
    func nonShellFenceStaysReference() throws {
        let out = try Self.mark("""
        ## Example output

        ```markdown
        # Report
        ```
        """)
        #expect(out.contains("## Example output (( role: reference ))"), Comment(rawValue: out))
    }

    @Test("general-abilities: a non-shell fence with a configured Fence tool mapping is routed to procedure")
    func toolMappedFenceBecomesProcedure() throws {
        let voc = Compiler.VocabularyInput(name: "test", file: "test.merconfig", source: """
        === language ===
        Fence tool mapping:
          python = interpreter.run
        """)
        let out = try Self.mark("""
        ## Example output

        ```python
        print("hi")
        ```
        """, vocabularies: [voc])
        #expect(out.contains("## Example output\n"), Comment(rawValue: out))
        #expect(!out.contains("## Example output (("), Comment(rawValue: out))
    }

    @Test("a fence in an unmapped language still stays reference even with a mapping configured for another language")
    func unmappedLanguageFenceStaysReferenceDespiteOtherMapping() throws {
        let voc = Compiler.VocabularyInput(name: "test", file: "test.merconfig", source: """
        === language ===
        Fence tool mapping:
          python = interpreter.run
        """)
        let out = try Self.mark("""
        ## Example output

        ```markdown
        # Report
        ```
        """, vocabularies: [voc])
        #expect(out.contains("## Example output (( role: reference ))"), Comment(rawValue: out))
    }

    @Test("an explicit in-body inert table marker does not gate the parent heading; the split still separates it from its table (known scope boundary)")
    func explicitInertTableMarkerBodyNoLongerGatesHeading() throws {
        // Unlike a heading-level `(( inert ))` marker (still respected
        // verbatim by strict compile as hand-authored input), an in-body
        // `!!! table (( inert ))` marker is not specially recognized by the
        // split scanner — it is ordinary narrative that happens to precede a
        // table block. The table has no checkable/inference signal, so it
        // becomes its own operational-error child (left for the real
        // compiler), and the marker line stays behind as leftover narrative,
        // which is why the parent gets `(( role: reference ))` rather than
        // the table itself being respected as inert. Nothing is silently
        // dropped — both halves of the content are preserved, just split.
        let out = try Self.mark("""
        ## Reference table

        !!! table (( inert ))
        | item | note |
        |---|---|
        | a | b |
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("## Reference table (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("!!! table (( inert ))"), Comment(rawValue: out))
        #expect(out.contains("### Reference table\(separator)"), Comment(rawValue: out))
        #expect(out.contains("| item | note |"), Comment(rawValue: out))
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

    @Test("a Phases section with no checkable/cue signal hard-fails to compile by default; routeFuzzy rescues it to (( role: reference ))")
    func failedMarkdownProcedureItemHardErrorsByDefault() async throws {
        let source = """
        ## Phases

        1. Load calendar. Check today's meetings.
        2. Compile prep briefing.
        """
        // Matches `SkillMigrator.Options`'s own default: no escape hatch, so
        // an operational Phases section with zero checkable/AI-inference
        // signal is left exactly as authored by the marking pass, and the
        // real compiler raises its own precise diagnostic — a hard error,
        // never a silently downgraded reference section.
        let strict = try await SkillMigrator(compiler: Compiler(options: .init()), vocabularies: [],
                                             options: .init(routeFuzzy: false)).migrate(source)
        #expect(!strict.compiledOK, Comment(rawValue: strict.meriSource))

        // With the routeFuzzy escape hatch enabled (this suite's test
        // default), the compile-retry loop rescues the section to
        // `(( role: reference ))` so exploratory batch runs still produce a
        // compiling file.
        let result = try await Self.migrator().migrate(source)
        #expect(result.compiledOK)
        #expect(result.meriSource.contains("## Phases (( role: reference ))"),
                Comment(rawValue: result.meriSource))
    }

    @Test("an unrecognized heading with no checkable/cue signal is marked reference documentation directly (no retry needed)")
    func failedUnknownMarkdownItemMarksReference() async throws {
        let result = try await Self.migrator().migrate("""
        ## Related skills

        - `skillify` — scaffolds a new skill
        - conventions/quality.md — output quality standards
        """)

        #expect(result.compiledOK)
        #expect(result.meriSource.contains("## Related skills (( role: reference ))"),
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

    @Test("a Domain heading is a recognized non-executable role and stays untouched")
    func domainHeadingLeftUnmarked() throws {
        let source = """
        ## Domain

        A Widget has a name and a price.
        """
        #expect(try Self.mark(source) == source)
    }

    @Test("a When Not To Use heading with fully checkable content remains executable")
    func negativeApplicabilityCheckableRemainsExecutable() throws {
        let out = try Self.mark("""
        ## When Not To Use

        - the request type is "internal"
        """)
        #expect(out.contains("## When Not To Use\n"), Comment(rawValue: out))
        #expect(!out.contains("## When Not To Use (("), Comment(rawValue: out))
    }

    @Test("a checkable-role heading with a question-arrow list body under checkableOnly falls to the fuzzy-table/error-operational cue gate")
    func checkableRoleQuestionArrowListRoutesThroughCueGate() throws {
        let outWithCue = try Self.mark("""
        ## Contract

        1. Is this ambiguous enough that we must decide it manually? -> escalate to a human
        2. Is the context missing enough that we must decide it manually? -> escalate to a human
        """)
        #expect(outWithCue.contains("!!! table (( ai-discretion ))") || outWithCue.contains("use judgment"),
                Comment(rawValue: outWithCue))

        let outWithoutCue = try Self.mark("""
        ## Contract

        1. Is the sky a nice color today for a picnic? -> escalate to a human
        2. Is the grass a nice color today for a picnic? -> escalate to a human
        """, routeFuzzy: false)
        #expect(outWithoutCue.contains("## Contract\n"), Comment(rawValue: outWithoutCue))
        #expect(!outWithoutCue.contains("## Contract (("), Comment(rawValue: outWithoutCue))
    }

    @Test("executableFenceContent: a degenerate single-line fence (no payload) is not executable")
    func executableFenceContentDegenerateSingleLine() {
        let content = SkillMigrator.executableFenceContent(["```bash"])
        #expect(!content.hasExecutableLine)
        #expect(content.commentText.isEmpty)
    }

    @Test("executableFenceContent: a shebang line makes the fence executable even with only comments otherwise")
    func executableFenceContentShebangIsExecutable() {
        let content = SkillMigrator.executableFenceContent([
            "```bash",
            "#!/usr/bin/env bash",
            "# just a comment",
            "```",
        ])
        #expect(content.hasExecutableLine)
    }

    @Test("heading-less body with no leading title inserts Overview right at the first body line")
    func headinglessNoLeadingTitleInsertsAtFirstLine() throws {
        let out = try Self.mark("""
        This skill has no title heading at all, just narrative.
        """)
        #expect(out.hasPrefix("## Overview (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("This skill has no title heading at all"), Comment(rawValue: out))
    }

    @Test("heading-less body with a non-fuzzy (checkable) task-list item does not trigger the overview wrap")
    func headinglessCheckableTaskListItemNotWrapped() throws {
        let source = """
        # Title

        - [ ] the request type is "internal"
        """
        let out = try Self.mark(source)
        #expect(!out.contains("## Overview (( role: reference ))"), Comment(rawValue: out))
    }

    @Test("heading-less body with a fuzzy task-list item triggers the overview wrap")
    func headinglessFuzzyTaskListItemWrapped() throws {
        let out = try Self.mark("""
        # Title

        - [ ] the output is reasonable
        """)
        #expect(out.contains("## Overview (( role: reference ))"), Comment(rawValue: out))
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

    @Test("an unrecognized narrative heading is marked reference documentation")
    func narrativeReference() throws {
        let out = try Self.mark("""
        ## Background

        Some descriptive prose about the design.
        """)
        #expect(out.contains("## Background (( role: reference ))"), Comment(rawValue: out))
    }

    @Test("heading-less fuzzy condition line triggers overview wrap")
    func headinglessFuzzyConditionWrapped() throws {
        let out = try Self.mark("""
        # Title

        the report is notable
        """)
        #expect(out.contains("## Overview (( role: reference ))"), Comment(rawValue: out))
    }

    @Test("heading-less narrative SKILL is wrapped under Overview (( role: reference ))")
    func headinglessNarrativeWrappedInOverview() throws {
        let source = """
        # Deprecated

        This skill moved elsewhere.

        - Keep this note as documentation.
        """
        let out = try Self.mark(source)
        #expect(out.contains("## Overview (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("This skill moved elsewhere."), Comment(rawValue: out))
        #expect(out.contains("- Keep this note as documentation."), Comment(rawValue: out))
    }

    @Test("install-style deprecation stub is wrapped under Overview (( role: reference ))")
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
        #expect(out.contains("## Overview (( role: reference ))"), Comment(rawValue: out))
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
            vocabularies: [])
        _ = try cap.trace.run {
            try migrator.markSections("""
            # Deprecated

            This skill moved elsewhere.

            - Keep this note as documentation.
            """)
        }
        #expect(cap.lines().contains { $0.contains("Overview (( role: reference ))") })
    }

    @Test("narrative Tools Used command bullets are marked role: tools")
    func narrativeToolsUsedMarked() throws {
        let out = try Self.mark("""
        ## Tools Used

        - `gbrain publish` -- deterministic HTML generation
        """)
        #expect(out.contains("## Tools Used (( role: tools ))"), Comment(rawValue: out))
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

    @Test("a narrative procedure/applicability heading with zero checkable/inference signal is left unmarked (P1 category 4), not auto-judgment-wrapped")
    func recognizedNarrativeHeadingsLeftUnmarked() throws {
        let source = """
        ## Phases

        do the thing.

        ## When to invoke

        - "trigger phrase"
        """
        // Neither body carries an `inferenceCueWords` cue, so P1 forbids
        // auto-wrapping either heading in judgment even though both already
        // assert an operational role (procedure / applicability). Both are
        // left exactly as authored for the real per-line builder to reject.
        #expect(try Self.mark(source) == source)
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

    @Test("Phase N: narrative heading is recognized as procedure and left unmarked (P1 category 4), not auto-judgment-wrapped")
    func phasePrefixNarrativeLeftUnmarked() throws {
        let source = """
        ## Phase 1: Inventory

        do the inventory.
        """
        #expect(try Self.mark(source) == source)
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

    // MARK: - AGENTS.md Phase 1 item 1/3: real symbols + trial lowering as the oracle

    static let orderVocab = Compiler.VocabularyInput(
        name: "order", file: "order.merconfig",
        source: """
        === vocabulary ===

        To validate the order:
          emit skill.report with message = "validated".
        """
    )

    @Test("a plain-statement procedure line with no vocabulary is left unmarked (P1 category 4), not auto-judgment-wrapped; an empty unrecognized heading is marked reference")
    func plainStatementLeftUnmarkedWithoutVocab() throws {
        let out = try Self.mark("""
        ## Setup

        ## Steps

        Validate the order.
        """)
        // With no vocabulary threaded in, "Validate the order." can't
        // trial-lower and carries no inference cue — "Steps" already
        // asserts it is a procedure, so P1 category 4 applies: left exactly
        // as authored for the real compiler to reject, never auto-wrapped.
        #expect(!out.contains("use judgment"), Comment(rawValue: out))
        #expect(!out.contains("## Steps (("), Comment(rawValue: out))
        #expect(out.contains("## Steps\n\nValidate the order."), Comment(rawValue: out))
        // "Setup" has no body at all (unrecognized heading, no signal
        // whatsoever) — genuinely documentary, marked reference directly.
        #expect(out.contains("## Setup (( role: reference ))"), Comment(rawValue: out))
    }

    @Test("a plain-statement procedure line trial-lowers and stays unmarked once real vocabulary is threaded in")
    func plainStatementLeftUnmarkedWithVocab() throws {
        let out = try Self.mark("""
        ## Setup

        ## Steps

        Validate the order.
        """, vocabularies: [Self.orderVocab])
        #expect(!out.contains("## Steps (( inert"), Comment(rawValue: out))
        #expect(out.contains("## Steps\n"), Comment(rawValue: out))
    }

    @Test("an unrecognized heading whose body only trial-lowers is routed to a procedure alias")
    func unrecognizedHeadingTrialLowersToAlias() throws {
        let out = try Self.mark("""
        ## Order handling

        Validate the order.
        """, vocabularies: [Self.orderVocab])
        #expect(out.contains("## Order handling\n"), Comment(rawValue: out))
        #expect(try Self.aliases("""
        ## Order handling

        Validate the order.
        """, vocabularies: [Self.orderVocab]) == [SkillMigrator.SectionAlias(heading: "Order handling", role: .procedure)])
    }

    @Test("a checklist item whose statement text (not just the box) trial-lowers is accepted")
    func taskListItemTrialLowersAsStatement() throws {
        let out = try Self.mark("""
        ## Steps

        [ ] Validate the order.
        """, vocabularies: [Self.orderVocab])
        #expect(!out.contains("## Steps (( inert"), Comment(rawValue: out))
    }

    @Test("a small mixed section still splits — P1 removed the old minimum-size threshold; every lowerable segment always gets its own child")
    func smallMixedSectionAlwaysSplits() throws {
        let body = """
        ## Steps

        This phase exists to keep orders tidy over the long run.

        It runs on a slow cadence and touches many different systems.

        Most of the time nothing needs to change at all.

        Occasionally a manual review catches something worth fixing.

        Validate the order.
        """
        let out = try Self.mark(body, vocabularies: [Self.orderVocab])
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(!out.contains("use judgment"), Comment(rawValue: out))
        #expect(out.contains("## Steps (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("This phase exists to keep orders tidy over the long run."), Comment(rawValue: out))
        #expect(out.contains("### Steps\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "### Steps\(separator)")!.lowerBound
        #expect(out[childIdx...].contains("Validate the order."), Comment(rawValue: out))
        #expect(!out[childIdx...].contains("This phase exists"), Comment(rawValue: out))

        // Idempotent: running again does not re-split or double-mark.
        let again = try Self.mark(out, vocabularies: [Self.orderVocab])
        #expect(again == out, Comment(rawValue: again))
    }

    @Test("routeFuzzy no longer affects the deterministic marking pass — it only gates the compile-retry rescue fallback")
    func routeFuzzyDoesNotAffectMarking() throws {
        // See `SkillMigratorCommandRewriteCoverageTests.markSectionReference`
        // for the retry-rescue behavior this flag now exclusively controls.
        let source = """
        ## Steps

        This phase exists to keep orders tidy over the long run.

        Validate the order.
        """
        let on = try Self.mark(source, vocabularies: [Self.orderVocab], routeFuzzy: true)
        let off = try Self.mark(source, vocabularies: [Self.orderVocab], routeFuzzy: false)
        #expect(on == off, Comment(rawValue: "routeFuzzy true:\n\(on)\n\nrouteFuzzy false:\n\(off)"))
    }

    // MARK: - AGENTS.md Phase 1 item 3: automatic mixed-section split

    @Test("a mixed section splits: leftover narrative under the parent is marked (( role: reference )) (not plain inert or judgment), the executable run becomes a child heading")
    func mixedSectionSplits() throws {
        let out = try Self.mark("""
        ## Steps

        This phase exists to keep orders tidy.

        Validate the order.
        """, vocabularies: [Self.orderVocab])
        // The leftover narrative carries no inference cue, so it is not
        // judgment-wrapped (P1 forbids that); it stays under the parent,
        // which needs an explicit `(( role: reference ))` marker since it
        // has real leftover content (not just blank/comment filler).
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(!out.contains("use judgment"), Comment(rawValue: out))
        #expect(out.contains("## Steps (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("This phase exists to keep orders tidy."), Comment(rawValue: out))
        #expect(out.contains("### Steps\(SkillMigrator.splitHeadingSeparator)"), Comment(rawValue: out))
        #expect(out.contains("Validate the order."), Comment(rawValue: out))
        // The narrative line must NOT end up under the generated child heading.
        let childIdx = out.range(of: "### Steps\(SkillMigrator.splitHeadingSeparator)")!.lowerBound
        #expect(!out[childIdx...].contains("This phase exists"), Comment(rawValue: out))
    }

    @Test("split generates an alias for the child heading so the candidate strict-compiles")
    func splitGeneratesChildAlias() throws {
        let aliases = try Self.aliases("""
        ## Steps

        This phase exists to keep orders tidy.

        Validate the order.
        """, vocabularies: [Self.orderVocab])
        #expect(aliases == [SkillMigrator.SectionAlias(heading: "Steps\(SkillMigrator.splitHeadingSeparator)", role: .procedure)],
                Comment(rawValue: "\(aliases)"))
    }

    @Test("a split candidate strict-compiles end to end via migrate()")
    func splitCandidateStrictCompiles() async throws {
        let result = try await Self.migrator(vocabularies: [Self.orderVocab]).migrate("""
        ## Steps

        This phase exists to keep orders tidy.

        Validate the order.
        """)
        #expect(result.compiledOK, Comment(rawValue: result.meriSource + "\n\n" + Self.diagnosticsSummary(result.report.diagnostics)))
    }

    @Test("multiple contiguous executable runs generate numbered sibling headings in order")
    func multipleRunsGetNumberedSiblings() throws {
        let out = try Self.mark("""
        ## Steps

        Validate the order.

        This explains why the next check matters before moving on.

        Validate the order.
        """, vocabularies: [Self.orderVocab])
        #expect(out.contains("### Steps\(SkillMigrator.splitHeadingSeparator)\n"), Comment(rawValue: out))
        #expect(out.contains("### Steps\(SkillMigrator.splitHeadingSeparator) 2"), Comment(rawValue: out))
    }

    @Test("a colon-terminated label attaches to its following command, not the narrative half")
    func annotationLabelAttachesToCommand() throws {
        let out = try Self.mark("""
        ## Steps

        This phase exists to keep orders tidy across every run of the pipeline.

        Run the health check:

        Validate the order.
        """, vocabularies: [Self.orderVocab])
        let childIdx = out.range(of: "### Steps\(SkillMigrator.splitHeadingSeparator)")!.lowerBound
        #expect(out[childIdx...].contains("Run the health check:"), Comment(rawValue: out))
    }

    @Test("an annotation label attached to its following command renders as a comment, not a raw statement, and strict-compiles")
    func annotationLabelAttachesAsCommentAndCompiles() async throws {
        // Regression for a real gbrain `enrich`/`publish`-shaped bug: a
        // free-standing narrative sentence ending in ":" on its OWN line,
        // immediately before a SEPARATE command/fence/AI-block on the next
        // non-blank line, is not the single-line `Run `cmd` to <purpose>`
        // idiom (whose purpose text folds into the command's own canonical
        // rewrite). Emitted verbatim as a second statement it has no
        // production to match and either raises `unresolved phrase` or —
        // before the SymbolTable malformed-argument fix — silently
        // phrase-matches garbage args from a low-confidence literal-word
        // overlap. It must render as a comment (dropped from IR, kept as
        // visible context) so the label never has to parse as a statement.
        let result = try await Self.migrator(vocabularies: [Self.orderVocab]).migrate("""
        ## Steps

        This phase exists to keep orders tidy across every run of the pipeline.

        The order desk automatically removes all private/internal data:

        Validate the order.
        """)
        #expect(result.compiledOK, Comment(rawValue: result.meriSource + "\n\n" + Self.diagnosticsSummary(result.report.diagnostics)))
        #expect(result.meriSource.contains("> The order desk automatically removes all private/internal data:"),
                Comment(rawValue: result.meriSource))
    }

    @Test("a must/never/always contract line that does not lower is reported as an unmined contract, never silently dropped")
    func normativeNarrativeIsReportedUnmined() async throws {
        let result = try await Self.migrator(vocabularies: [Self.orderVocab]).migrate("""
        ## Steps

        Authors must never delete original SKILL.md files.

        Validate the order.
        """)
        #expect(result.report.unminedContracts.contains { $0.contains("must never delete original") },
                Comment(rawValue: "\(result.report.unminedContracts)"))
    }

    @Test("reference-like notes may contain refusal rationale without becoming unmined contracts")
    func referenceNotesWithRefusalRationaleStayDocumentary() async throws {
        let result = try await Self.migrator(vocabularies: [Self.orderVocab]).migrate("""
        ## DBA notes

        The source system owns physical cascade delete; Meridian records the deterministic
        audit close and refuses to invent a hidden datastore.
        """)
        #expect(result.report.unminedContracts.isEmpty, Comment(rawValue: "\(result.report.unminedContracts)"))
        #expect(result.meriSource.contains("## DBA notes (( role: reference ))"),
                Comment(rawValue: result.meriSource))
    }

    @Test("re-running the marking pass on an already-split file is a no-op (idempotent)")
    func splitIsIdempotent() throws {
        let source = """
        ## Steps

        This phase exists to keep orders tidy.

        Validate the order.
        """
        let once = try Self.mark(source, vocabularies: [Self.orderVocab])
        let twice = try Self.mark(once, vocabularies: [Self.orderVocab])
        #expect(once == twice, Comment(rawValue: "once:\n\(once)\n\ntwice:\n\(twice)"))
    }

    // MARK: - Named hard-section acceptance fixtures (AGENTS.md Phase 1 item 3)
    //
    // Trimmed, verbatim excerpts from the real gbrain corpus sections the plan
    // calls out as split-algorithm acceptance tests.

    @Test("setup's Lookup sequence: a numbered command list + trailing narrative splits, commands intact and in order")
    func setupLookupSequenceSplits() throws {
        // sample-gbrain/original-skills/setup/SKILL.md, "### Lookup sequence".
        // This is an unrecognized (custom) heading with substantive leftover
        // narrative, so it gets `(( role: reference ))`. Step 4's shape (a
        // stray word between the backtick command and its " -- " annotation)
        // falls outside today's annotated-command grammar, so it stays
        // narrative alongside the closing note — split correctly moves ONLY
        // the three cleanly-shaped commands, and drops nothing.
        let out = try Self.mark("""
        ### Lookup sequence (MANDATORY for every entity question)

        1. `gbrain search "name"` -- keyword match, fast, works without embeddings
        2. `gbrain query "what do we know about name"` -- hybrid search, needs embeddings
        3. `gbrain get <slug>` -- direct page read when you know the slug from steps 1-2
        4. `grep` fallback -- only if gbrain returns zero results AND the file may exist outside the indexed brain

        Stop at the first step that gives you what you need. Most lookups resolve at step 1.
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("### Lookup sequence (MANDATORY for every entity question) (( role: reference ))"),
                Comment(rawValue: out))
        #expect(out.contains("Stop at the first step that gives you what you need."), Comment(rawValue: out))
        #expect(out.contains(#"4. `grep` fallback"#), Comment(rawValue: out))
        #expect(out.contains("### Lookup sequence (MANDATORY for every entity question)\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "### Lookup sequence (MANDATORY for every entity question)\(separator)")!.lowerBound
        let child = String(out[childIdx...])
        #expect(child.contains(#"1. `gbrain search "name"`"#), Comment(rawValue: out))
        #expect(child.contains(#"3. `gbrain get <slug>`"#), Comment(rawValue: out))
        // Order-preserving: step 1 precedes step 3 under the generated child.
        #expect(child.range(of: "1. `gbrain search")!.lowerBound < child.range(of: "3. `gbrain get")!.lowerBound)
        #expect(!child.contains("Stop at the first step"), Comment(rawValue: out))
        // Step 4 was never lost — it stayed under the original heading's narrative.
        #expect(!child.contains("`grep` fallback"), Comment(rawValue: out))
    }

    @Test("briefing's Phases: a numbered procedure list with a normative trailing note splits with the note folded into the executable child, not left as parent narrative")
    func briefingPhasesSplits() throws {
        // Representative of sample-gbrain/original-skills/briefing/SKILL.md's
        // "## Phases" shape: numbered steps, each a backticked/annotated
        // command, followed by a closing narrative note.
        let out = try Self.mark("""
        ## Phases

        1. `gbrain briefing collect` -- gather signals from the last 24 hours
        2. `gbrain briefing rank` -- score and order by relevance
        3. `gbrain briefing render` -- produce the final markdown

        These phases always run in order; never skip ahead to render.
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        // The closing note carries a normative cue ("never") with no
        // checkable shape and no inference cue — P1 category 4 pulls it
        // into the SAME executable run as the commands (left for the real
        // compiler), rather than leaving it as separate parent narrative.
        // Nothing is left over under the parent, so it stays completely
        // clean (no marker at all).
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(!out.contains("use judgment"), Comment(rawValue: out))
        #expect(out.contains("## Phases\n"), Comment(rawValue: out))
        #expect(!out.contains("## Phases (("), Comment(rawValue: out))
        #expect(out.contains("### Phases\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "### Phases\(separator)")!.lowerBound
        #expect(out[childIdx...].contains("These phases always run in order"), Comment(rawValue: out))
    }

    @Test("maintain's Link graph extraction: an annotation-label + shell fence splits via the ratio threshold, not the count threshold")
    func maintainLinkGraphExtractionSplits() throws {
        // sample-gbrain/original-skills/maintain/SKILL.md, "### Link graph
        // extraction": only 2 executable units (the label + its fence), below
        // the count floor of 3, but they are 2 of 3 content units (66% ratio)
        // so the ratio branch of the threshold still splits it.
        let out = try Self.mark("""
        ### Link graph extraction
        If link_count is 0 or low relative to page_count, run batch extraction:
        ```bash
        gbrain extract links --dir ~/brain
        ```
        This scans all markdown files for entity references, See Also sections, and
        frontmatter fields, then creates typed links in the database.
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("### Link graph extraction (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("This scans all markdown files"), Comment(rawValue: out))
        #expect(out.contains("### Link graph extraction\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "### Link graph extraction\(separator)")!.lowerBound
        let child = String(out[childIdx...])
        // The annotation label travels with its fence into the generated child.
        #expect(child.contains("run batch extraction:"), Comment(rawValue: out))
        #expect(child.contains("gbrain extract links --dir ~/brain"), Comment(rawValue: out))
        #expect(!child.contains("This scans all markdown files"), Comment(rawValue: out))
    }

    @Test("brain_taxonomist's Step 1: a cue-less fuzzy question-arrow decision list is an operational-error split (case 3 of the four-way lowering), not an auto-judgment-wrap")
    func brainTaxonomistStep1RoutesToOperationalError() throws {
        // sample-gbrain/original-skills/brain-taxonomist/SKILL.md, "### Step 1":
        // a question-arrow decision list whose questions are phrased in
        // question word-order ("Is X a Y?"), which the classifier does not
        // read as a checkable predicate. Under P1, with no
        // `inferenceCueWords` cue present in the text, this is NOT
        // auto-wrapped in judgment — it is left as its own executable-error
        // child, verbatim, for the real compiler to reject.
        let step1 = try Self.mark("""
        ### Step 1: Identify primary subject type

        Walk these questions in order:
        1. Is the primary subject a NAMED PERSON? → person-typed directory
        2. Is the primary subject a NAMED ORGANIZATION? → company-typed directory
        3. Is it about a TIME-BOUNDED EVENT (meeting, deal, trip)? → temporal-typed directory
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        // Everything moved into the child (no leftover narrative), so the
        // parent stays completely clean — no marker at all.
        #expect(!step1.contains("(( inert"), Comment(rawValue: step1))
        #expect(!step1.contains("use judgment"), Comment(rawValue: step1))
        #expect(step1.contains("### Step 1: Identify primary subject type\n"), Comment(rawValue: step1))
        #expect(!step1.contains("### Step 1: Identify primary subject type (("), Comment(rawValue: step1))
        #expect(step1.contains("### Step 1: Identify primary subject type\(separator)"), Comment(rawValue: step1))
        #expect(step1.contains("Is the primary subject a NAMED PERSON? → person-typed directory"), Comment(rawValue: step1))
    }

    // MARK: - idiom: question-arrow decision protocol

    @Test("question-arrow case 1: checkable questions with statement-shaped rhs desugar to the suffix-conditional idiom")
    func questionArrowCase1DesugarsToSuffixConditional() throws {
        let out = try Self.mark("""
        ### Response

        Walk these conditions in order:
        1. the health status is "down"? -> restart the service
        2. the queue depth is greater than 100? -> page the on call engineer
        """, vocabularies: [Self.decisionVocab])
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("### Response\(separator)"), Comment(rawValue: out))
        #expect(out.contains(#"restart the service only when the health status is "down"."#), Comment(rawValue: out))
        #expect(out.contains("page the on call engineer only when the queue depth is greater than 100."), Comment(rawValue: out))
        #expect(!out.contains("use judgment"), Comment(rawValue: out))
        #expect(!out.contains("->"), Comment(rawValue: out))
    }

    @Test("question-arrow case 2: checkable questions with a bare-value rhs desugar to a decision-table binding, named by the `deciding the <name>:` lead-in")
    func questionArrowCase2DesugarsToDecisionTableBinding() throws {
        let out = try Self.mark("""
        ### Response

        deciding the directory:
        1. the subject type is "person"? -> person-typed directory
        2. the subject type is "organization"? -> company-typed directory
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("### Response\(separator)"), Comment(rawValue: out))
        #expect(out.contains(#"let the directory be "person-typed directory" only when the subject type is "person"."#), Comment(rawValue: out))
        #expect(out.contains(#"let the directory be "company-typed directory" only when the subject type is "organization"."#), Comment(rawValue: out))
    }

    @Test("question-arrow case 2 falls back to a generic result name without a `deciding the <name>:` lead-in")
    func questionArrowCase2FallsBackToGenericName() throws {
        let out = try Self.mark("""
        ### Response

        1. the subject type is "person"? -> person-typed directory
        2. the subject type is "organization"? -> company-typed directory
        """)
        #expect(out.contains(#"let the category be "person-typed directory" only when the subject type is "person"."#), Comment(rawValue: out))
    }

    @Test("question-arrow case 2 uses fallback article when the lexicon has no definite article")
    func questionArrowCase2FallbackArticle() throws {
        let base = EnglishLexicon.default
        let noArticleLexicon = EnglishLexicon(
            articles: [],
            prepositions: base.prepositions,
            copulas: base.copulas,
            participles: base.participles,
            participleSuffixes: base.participleSuffixes,
            comparisonMarkers: base.comparisonMarkers,
            durationUnits: base.durationUnits,
            toolStopwords: base.toolStopwords
        )
        let compiler = Compiler(options: .init(lexicon: noArticleLexicon))
        let knowledge = try compiler.bootstrap(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: "", file: "<test>")], vocabularies: []))
        let trial = TrialLowering(knowledge: knowledge)
        let migrator = Self.migrator()
        let block = SkillMigrator.SplitBlock(
            rawLines: ["1. total is greater than 0? -> high"],
            normalizedText: "total is greater than 0? -> high",
            isFence: false,
            isShellFence: false,
            isQuestionArrowList: true
        )

        let result = migrator.classifyQuestionArrowList(block, precedingBlock: nil, trial: trial)
        #expect(result.kind == SkillMigrator.SplitKind.exec)
        #expect(result.renderOverride == [
            #"let the category be "high" only when total is greater than 0."#,
        ])
    }

    @Test("question-arrow case 3: a non-checkable question with a genuine inference cue wraps the whole list in judgment, not a decision-table binding")
    func questionArrowCase3WrapsInJudgmentWhenCueIsPresent() throws {
        let out = try Self.mark("""
        ### Response

        1. Is this case ambiguous enough that we must decide it manually? -> escalate to a human
        2. Is the context missing enough that we must decide it manually? -> escalate to a human
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("### Response\(separator)"), Comment(rawValue: out))
        #expect(out.contains("use judgment to weigh each question below:"), Comment(rawValue: out))
        #expect(out.contains("Is this case ambiguous enough that we must decide it manually? -> escalate to a human"), Comment(rawValue: out))
        #expect(!out.contains(#"let the category be"#), Comment(rawValue: out))
    }

    @Test("question-arrow case 3: a non-checkable question with no inference cue is a category-4 reword error, not a silent judgment wrap")
    func questionArrowCase3IsHardErrorWithoutCue() throws {
        let out = try Self.mark("""
        ### Response

        1. Is the sky a nice color today for a picnic? -> escalate to a human
        2. Is the grass a nice color today for a picnic? -> escalate to a human
        """, routeFuzzy: false)
        #expect(!out.contains("use judgment"), Comment(rawValue: out))
        #expect(!out.contains(#"let the category be"#), Comment(rawValue: out))
    }

    // MARK: - `sectionIsExecutableOnly` marker run-tracking

    @Test("sectionIsExecutableOnly: a `!!! table` run followed by a plain lowerable line clears the pending-table marker and keeps checking")
    func executableOnlyTableMarkerRunEndsAndContinues() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        let body: ArraySlice<String> = [
            "!!! table",
            "| a | b |",
            "| - | - |",
            "Make sure the order is valid.",
        ][...]
        #expect(m.sectionIsExecutableOnly(body, knowledge: knowledge))
    }

    @Test("sectionIsExecutableOnly: a `!!! checklist` run followed by a plain lowerable line clears the pending-checklist marker and keeps checking")
    func executableOnlyChecklistMarkerRunEndsAndContinues() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        let body: ArraySlice<String> = [
            "!!! checklist",
            "- [ ] the order is valid",
            "Make sure the order is valid.",
        ][...]
        #expect(m.sectionIsExecutableOnly(body, knowledge: knowledge))
    }

    @Test("sectionIsExecutableOnly: a `!!! checklist` run with a non-lowerable line inside the run is not executable-only")
    func executableOnlyChecklistRunWithFuzzyLineFails() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        let body: ArraySlice<String> = [
            "!!! checklist",
            "- [ ] the order is valid",
            "This paragraph is narrative prose that never lowers as anything.",
        ][...]
        #expect(!m.sectionIsExecutableOnly(body, knowledge: knowledge))
    }

    @Test("a full question-arrow candidate strict-compiles end to end via migrate() for all three cases")
    func questionArrowCandidatesStrictCompile() async throws {
        let case1 = try await Self.migrator(vocabularies: [Self.decisionVocab]).migrate("""
        ### Response

        Walk these conditions in order:
        1. the health status is "down"? -> restart the service
        2. the queue depth is greater than 100? -> page the on call engineer
        """)
        #expect(case1.compiledOK, Comment(rawValue: case1.meriSource + "\n\n" + Self.diagnosticsSummary(case1.report.diagnostics)))

        let case2 = try await Self.migrator().migrate("""
        ### Response

        deciding the directory:
        1. the subject type is "person"? -> person-typed directory
        2. the subject type is "organization"? -> company-typed directory
        """)
        #expect(case2.compiledOK, Comment(rawValue: case2.meriSource + "\n\n" + Self.diagnosticsSummary(case2.report.diagnostics)))

        let case3 = try await Self.migrator().migrate("""
        ### Step 1: Identify primary subject type

        Walk these questions in order:
        1. Is the primary subject a NAMED PERSON? → person-typed directory
        2. Is the primary subject a NAMED ORGANIZATION? → company-typed directory
        3. Is it about a TIME-BOUNDED EVENT (meeting, deal, trip)? → temporal-typed directory
        """)
        #expect(case3.compiledOK, Comment(rawValue: case3.meriSource + "\n\n" + Self.diagnosticsSummary(case3.report.diagnostics)))
    }

    static let decisionVocab = Compiler.VocabularyInput(
        name: "decision", file: "decision.merconfig",
        source: """
        === vocabulary ===

        To restart the service:
          emit skill.report with message = "restarted".

        To page the on call engineer:
          emit skill.report with message = "paged".
        """
    )

    @Test("brain_taxonomist's Step 5: a checklist with unlowerable items is AI-routed via ai-autonomy, not left inert")
    func brainTaxonomistStep5RoutesToAiAutonomyChecklist() throws {
        // sample-gbrain/original-skills/brain-taxonomist/SKILL.md, "### Step 5":
        // the checklist items don't trial-lower as checkable predicates, so
        // route-fuzzy (AGENTS.md Phase 1 item 4 / docs/13 fix 12) wraps the
        // whole run in `!!! checklist (( ai-autonomy ))` under a generated
        // child heading rather than dropping it as inert prose.
        let out = try Self.mark("""
        ### Step 5: Validate before writing

        - [ ] Path follows the active pack's path_prefixes
        - [ ] Slug is kebab-case, descriptive
        - [ ] Cross-links to related pages are included

        Prefer flagging schema gaps over guessing the closest-fitting type.
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        // Neither the checklist items nor the closing note ("Prefer
        // flagging...") carry an `inferenceCueWords` cue, so P1 forbids the
        // old auto-`!!! checklist (( ai-autonomy ))` wrap — the checklist
        // becomes a plain operational-error child (left for the real
        // compiler), and the closing narrative stays behind as leftover
        // parent narrative (so the parent needs `(( role: reference ))`).
        #expect(!out.contains("!!! checklist"), Comment(rawValue: out))
        #expect(out.contains("### Step 5: Validate before writing (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("Prefer flagging schema gaps"), Comment(rawValue: out))
        #expect(out.contains("### Step 5: Validate before writing\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "### Step 5: Validate before writing\(separator)")!.lowerBound
        let child = String(out[childIdx...])
        #expect(child.contains("- [ ] Path follows the active pack's path_prefixes"), Comment(rawValue: out))
        #expect(child.contains("- [ ] Cross-links to related pages are included"), Comment(rawValue: out))
        #expect(!child.contains("Prefer flagging schema gaps"), Comment(rawValue: out))
    }

    @Test("testing's Test tiers: a fuzzy Markdown table containing an inference cue (\"judge\") is AI-routed via ai-discretion")
    func testingTierTableRoutesToAiDiscretionTable() throws {
        // sample-gbrain/original-skills/testing/SKILL.md, "### Test tiers": a
        // Markdown table whose cells are descriptive, not checkable — doesn't
        // trial-lower as a decision/data table. Its "LLM-judge" cell carries
        // the `inferenceCueWords` cue "judge", so it is AI-routed via
        // `!!! table (( ai-discretion ))` rather than left as a plain
        // operational-error child. Without that cue this would be
        // `.errorOperational` instead (see `brainTaxonomistStep5…` above) —
        // never auto-wraps cue-less content in judgment.
        let out = try Self.mark("""
        ### Test tiers

        | Tier | What it runs | Wall time | Gates |
        |------|--------------|-----------|-------|
        | **Unit** | `bun test` (deterministic, zero external calls) | <2s | Every commit |
        | **Evals** | LLM-judge or quality evals | ~60s | Daily |
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("### Test tiers\n"), Comment(rawValue: out))
        #expect(!out.contains("### Test tiers (("), Comment(rawValue: out))
        #expect(out.contains("### Test tiers\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "### Test tiers\(separator)")!.lowerBound
        let child = String(out[childIdx...])
        #expect(child.contains("!!! table (( ai-discretion ))"), Comment(rawValue: out))
        #expect(child.contains("| Tier | What it runs | Wall time | Gates |"), Comment(rawValue: out))
        #expect(child.contains("| Evals | LLM-judge or quality evals | ~60s | Daily |"), Comment(rawValue: out))
    }

    // MARK: - `decision(forHeading:)` idempotency / unmined-contract branches

    @Test("a recognized-procedure heading whose body is already judgment-wrapped is idempotently left unmarked")
    func procedureHeadingAlreadyJudgmentWrappedIsIdempotent() throws {
        let source = """
        ## Phases

        use judgment to follow the Phases guidance:
          weigh the tradeoffs before choosing a path.
        """
        #expect(try Self.mark(source) == source)
    }

    @Test("a rulebook-aliased-procedure heading that already carries the generated split suffix is left unmarked, not re-split")
    func procedureHeadingWithSplitSuffixIsLeftUnmarked() throws {
        let heading = "My Heading\(SkillMigrator.splitHeadingSeparator)"
        let rulebook = RulebookInput(name: "r", file: "r.merrules", source: """
        === sections ===
        section "\(heading)" -> procedure
        """)
        let source = """
        ## \(heading)

        do the thing.
        """
        #expect(try Self.mark(source, rulebooks: [rulebook]) == source)
    }

    @Test("an unrecognized heading whose body is already judgment-wrapped is idempotently aliased to procedure")
    func unrecognizedHeadingAlreadyJudgmentWrappedIsIdempotent() throws {
        let source = """
        ## Odd Corner

        use judgment to follow the Odd Corner guidance:
          weigh the tradeoffs before choosing a path.
        """
        #expect(try Self.mark(source) == source)
        #expect(try Self.aliases(source) == [SkillMigrator.SectionAlias(heading: "Odd Corner", role: .procedure)])
    }

    @Test("a checkable-role heading whose body is already judgment-wrapped is idempotently left unmarked")
    func checkableRoleHeadingAlreadyJudgmentWrappedIsIdempotent() throws {
        let source = """
        ## Contract

        use judgment to follow the Contract guidance:
          weigh the tradeoffs before choosing a path.
        """
        #expect(try Self.mark(source) == source)
    }

    @Test("a rulebook-aliased checkable-role heading that already carries the generated split suffix is left unmarked, not re-split")
    func checkableRoleHeadingWithSplitSuffixIsLeftUnmarked() throws {
        let heading = "Contract\(SkillMigrator.splitHeadingSeparator)"
        let rulebook = RulebookInput(name: "r", file: "r.merrules", source: """
        === sections ===
        section "\(heading)" -> invariants
        """)
        let source = """
        ## \(heading)

        guarantees prose.
        """
        #expect(try Self.mark(source, rulebooks: [rulebook]) == source)
    }

    @Test("an unrecognized heading whose only content is an unmined normative contract (no checkable/cue signal) is aliased to procedure, not marked as documentation")
    func unrecognizedHeadingWithUnminedContractAliasedToProcedure() async throws {
        let result = try await Self.migrator().migrate("""
        ## Random Section

        Authors must never delete original SKILL.md files.
        """)
        #expect(!result.meriSource.contains("## Random Section (("), Comment(rawValue: result.meriSource))
        #expect(result.report.unminedContracts.contains { $0.contains("must never delete original") },
                Comment(rawValue: "\(result.report.unminedContracts)"))
    }

    // MARK: - AGENTS.md Phase 1 item 5: sectionIsTemplateBody leading-label tolerance

    @Test("Output Format with a leading label line before a table is recognized as a template, not inert")
    func templateBodyToleratesLeadingLabelBeforeTable() throws {
        let out = try Self.mark("""
        ## Output Format

        Report as a table:

        | Field | Value |
        |---|---|
        | Status | {{status}} |
        """)
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
    }

    @Test("Output Format with a leading label line before a bullet list is recognized as a template, not inert")
    func templateBodyToleratesLeadingLabelBeforeList() throws {
        let out = try Self.mark("""
        ## Output Format

        An enriched page contains:
        - Frontmatter with type and tags
        - Executive summary
        """)
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
    }

    @Test("Output Format with no label at all is still recognized as a template (regression, unchanged)")
    func templateBodyWithoutLabelStillWorks() throws {
        let out = try Self.mark("""
        ## Output Format

        | Field | Value |
        |---|---|
        | Status | {{status}} |
        """)
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
    }

    @Test("Output Format with a repeated mid-body label (not just leading) still stays inert (known scope boundary)")
    func templateBodyWithRepeatedMidBodyLabelStaysInert() throws {
        // sample-gbrain/original-skills/enrich/SKILL.md's real "## Output
        // Format": each of several page kinds gets its own "<X> contains:"
        // label before its own bullet list. The tolerance is deliberately
        // scoped to exactly one *leading* label (AGENTS.md Phase 1 item 5),
        // not every colon-terminated line, so this still needs a future fix
        // (Phase 3 pilot review) rather than a broadened heuristic today.
        let out = try Self.mark("""
        ## Output Format

        An enriched person page contains:
        - Frontmatter with type and tags
        - Executive summary

        An enriched company page contains:
        - Frontmatter with type and tags
        """)
        #expect(out.contains("## Output Format (( role: template ))"), Comment(rawValue: out))
    }

    @Test("a heading whose text already carries the generated split suffix is never re-split or marked")
    func headingWithSplitSuffixIsNeverReSplit() throws {
        // Simulates re-scanning a generated child heading whose body no longer
        // proves fully executable (e.g. the vocabulary that made it lower is
        // unavailable) — the recognizable-suffix guard must prevent minting a
        // nested "… — steps — steps" grandchild. Both `.procedure` and `.none`
        // decision branches return `.leaveUnmarked` outright for any heading
        // already containing the split suffix, so the whole document is left
        // byte-for-byte untouched.
        let source = """
        ## Steps\(SkillMigrator.splitHeadingSeparator)

        This phase exists to keep orders tidy.

        Validate the order.
        """
        #expect(try Self.mark(source) == source)
    }

    // MARK: - idiom: bold-label step tolerance

    @Test("a bold label before a plain-prose statement is dropped so the statement lowers on its own")
    func boldLabelBeforePlainStatementIsDropped() throws {
        let source = """
        ## Steps

        1. **Run health check.** Check the brain health.
        """
        let out = try Self.mark(source)
        // The section is now executable (routed via the `procedure` alias, no
        // inline marker) instead of inert-with-an-unresolved-label-sentence.
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(!out.contains("**"), Comment(rawValue: out))
        #expect(out.contains("1. Check the brain health."), Comment(rawValue: out))
    }

    @Test("a bulleted bold label before a plain statement is dropped, keeping the bullet marker")
    func boldLabelOnBulletIsDropped() throws {
        let out = try Self.mark("""
        ## Steps

        - **Sync.** Refresh the local index.
        - **Verify.** Confirm the index checksum matches.
        """)
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(out.contains("- Refresh the local index."), Comment(rawValue: out))
        #expect(out.contains("- Confirm the index checksum matches."), Comment(rawValue: out))
    }

    @Test("a bold label before a backticked command is left alone (embeddedBacktickedCommand keeps it as the annotation)")
    func boldLabelBeforeCommandIsUntouched() throws {
        // Regression guard: the bold-label drop must not preempt the richer
        // existing path where the label becomes the command's `-- annotation`
        // comment (`embeddedBacktickedCommand` + `cleanCommandAnnotation`).
        let out = try Self.mark("""
        ## Steps

        1. **Sync brain.** `gbrain sync`
        """)
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(out.contains("`gbrain sync`"), Comment(rawValue: out))
    }

    @Test("mid-sentence emphasis (not a leading label) is unaffected by the bold-label drop")
    func midSentenceEmphasisUnaffected() throws {
        let out = try Self.mark("""
        ## Steps

        1. Run the health check **before** every deploy.
        """)
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(out.contains("1. Run the health check before every deploy."), Comment(rawValue: out))
    }

    // MARK: - `headinglessOverviewInsertIndex` / `headinglessBodyNeedsInertOverview`

    @Test("a heading-less body with a leading blank line before its title still inserts Overview right after the title")
    func headinglessLeadingBlankLineBeforeTitle() throws {
        let source = "\n# Title\n\nthe report is notable\n"
        let out = try Self.mark(source)
        #expect(out.contains("## Overview (( role: reference ))"), Comment(rawValue: out))
        #expect(out.contains("the report is notable"), Comment(rawValue: out))
    }

    @Test("a heading-less body with a bare list-marker line (nothing after it) is skipped, not misread as content")
    func headinglessBareListMarkerLineIsSkipped() throws {
        let out = try Self.mark("""
        # Title

        -
        the report is notable
        """)
        #expect(out.contains("## Overview (( role: reference ))"), Comment(rawValue: out))
    }

    @Test("a heading-less body whose only checkable task-list item is preceded by a fuzzy line does not early-return before evaluating it")
    func headinglessMixedFuzzyThenCheckableTaskList() throws {
        // The leading fuzzy sentence alone already proves the body needs the
        // inert overview wrap (`sectionIsExecutableOnly` fails first because
        // that sentence never lowers), so `headinglessBodyNeedsInertOverview`
        // is reached and must walk past a later checkable (non-fuzzy)
        // task-list item without misclassifying it as the reason to wrap.
        let out = try Self.mark("""
        # Title

        The report is notable and worth reviewing closely.

        - [ ] the request type is "internal"
        """)
        #expect(out.contains("## Overview (( role: reference ))"), Comment(rawValue: out))
    }

    // MARK: - `lineHasMarkdownNarrativeMarkers` (via `sectionIsExecutableOnly`)

    @Test("sectionIsExecutableOnly: a marker-only numbered line (nothing after it) normalizes to empty and is skipped, not misread as content")
    func executableOnlyMarkerOnlyLineIsSkipped() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        let body: ArraySlice<String> = [
            "1.",
            "- [ ] the page count is at least 1",
        ][...]
        #expect(m.sectionIsExecutableOnly(body, knowledge: knowledge))
    }

    @Test("sectionIsExecutableOnly: a non-fuzzy Markdown list item ending in a colon is rejected as a narrative marker, not silently accepted")
    func executableOnlyListItemEndingInColonIsRejected() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        let body: ArraySlice<String> = [
            "- the page count is at least 1:",
        ][...]
        #expect(!m.sectionIsExecutableOnly(body, knowledge: knowledge))
    }

    // MARK: - `headinglessBodyNeedsInertOverview` direct branch coverage

    @Test("headinglessBodyNeedsInertOverview: a comment line, a marker-only list item, and a checkable task-list item are all skipped without triggering the wrap")
    func headinglessBodyNeedsInertOverviewSkipsCommentMarkerAndCheckableItem() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        let body: ArraySlice<String> = [
            "> a blockquote aside",
            "1.",
            "- [ ] the request type is \"internal\"",
        ][...]
        #expect(!m.headinglessBodyNeedsInertOverview(body, knowledge: knowledge))
    }

    // MARK: - `bodyRestatesConvention`

    @Test("bodyRestatesConvention: a fenced code block inside the body does not break convention-restatement detection")
    func bodyRestatesConventionSkipsFencedContent() throws {
        let rulebook = RulebookInput(name: "conv", file: "conv.merrules", source: """
        === conventions ===
        after filing a page:
          always include a citation.
        """)
        let m = Self.migrator(rulebooks: [rulebook])
        let body: ArraySlice<String> = [
            "```text",
            "irrelevant fenced example",
            "```",
            "> a blockquote aside",
            "Always include a citation.",
        ][...]
        #expect(try m.bodyRestatesConvention(body))
    }

    // MARK: - `parseQuestionArrowLine` / `classifyQuestionArrowList`

    @Test("parseQuestionArrowLine: a question with no arrow marker after it is not a question-arrow line")
    func parseQuestionArrowLineNoArrowReturnsNil() {
        let m = Self.migrator()
        #expect(m.parseQuestionArrowLine("Is this ready? just a follow-up sentence") == nil)
    }

    @Test("parseQuestionArrowLine: an arrow with an empty rhs is not a question-arrow line")
    func parseQuestionArrowLineEmptyRhsReturnsNil() {
        let m = Self.migrator()
        #expect(m.parseQuestionArrowLine("Is this ready? ->") == nil)
    }

    @Test("classifyQuestionArrowList: a block whose lines don't all parse as question-arrow items is documentation (defensive; real callers pre-filter)")
    func classifyQuestionArrowListMixedBlockIsDocumentation() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        let block = SkillMigrator.SplitBlock(
            rawLines: ["Is this ready? -> yes", "not a question-arrow line at all"],
            normalizedText: "", isFence: false, isShellFence: false, isQuestionArrowList: true)
        let (kind, override) = m.classifyQuestionArrowList(block, precedingBlock: nil, trial: TrialLowering(knowledge: knowledge))
        #expect(kind == .documentation)
        #expect(override == nil)
    }

    // MARK: - `splitPlan` single-line table/question-arrow fallthrough

    @Test("splitPlan: a comment-only shell fence whose comment carries an inference cue is AI-routed, not left as an operational error")
    func splitPlanGuidanceOnlyFenceWithInferenceCueIsAiInference() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        let body: ArraySlice<String> = [
            "```bash",
            "# assess the situation before proceeding",
            "```",
        ][...]
        let plan = m.splitPlan(for: body, knowledge: knowledge)
        #expect(plan.executableSegments.contains { $0.kind == .aiInference })
        let rendered = m.renderSplitPlan(plan, headingHashes: "##", headingText: "Guidance",
                                         lexicon: knowledge.lexicon)
        #expect(rendered.contains("use judgment to follow the Guidance — steps guidance:"))
    }

    @Test("splitPlan: a lone pipe-delimited line whose next line is a bare single `|` still fails the >= 2-row table check")
    func splitPlanLoneTableRowFallsThrough() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        // The second line ("|") also has matching prefix/suffix `|`, but at
        // length 1 fails the table-continuation guard's `count > 1` half —
        // the lookahead scan stops after zero continuation rows, so the
        // block never reaches the >= 2-row threshold either.
        let body: ArraySlice<String> = ["| just one row |", "|"][...]
        let plan = m.splitPlan(for: body, knowledge: knowledge)
        #expect(plan.narrativeLines.contains("| just one row |"), Comment(rawValue: "\(plan)"))
    }

    @Test("splitPlan: a lone question-arrow line followed by a non-question-arrow line is not treated as a question-arrow block")
    func splitPlanLoneQuestionArrowFallsThrough() throws {
        let m = Self.migrator()
        let knowledge = try m.knowledgeContext()
        // The scan looks one line ahead, finds it doesn't parse as a
        // question-arrow item, and stops — leaving only one item, below the
        // >= 2-item threshold for a dedicated question-arrow block.
        let body: ArraySlice<String> = ["Is this ready? -> yes", "Plain narrative filler content that never lowers as anything."][...]
        let plan = m.splitPlan(for: body, knowledge: knowledge)
        // Falling below the >= 2-item threshold merges the line into the
        // ordinary hard-wrap paragraph scan instead, where it joins the
        // next line as one cue-less operational-error unit (never a
        // dedicated question-arrow block).
        #expect(plan.executableSegments.contains { $0.lines.contains("Is this ready? -> yes") }, Comment(rawValue: "\(plan)"))
        #expect(plan.unminedContracts.contains { $0.contains("Is this ready? -> yes") }, Comment(rawValue: "\(plan)"))
    }

    @Test("executableFenceContent: an unclosed fence (no closing backtick line) still scans its full payload")
    func executableFenceContentUnclosedFenceScansFullPayload() {
        let content = SkillMigrator.executableFenceContent(["```bash", "gbrain stats"])
        #expect(content.hasExecutableLine)
    }

    @Test("executableFenceContent: a blank line inside the fence payload is skipped")
    func executableFenceContentSkipsBlankPayloadLine() {
        let content = SkillMigrator.executableFenceContent(["```bash", "", "# just a comment", "```"])
        #expect(!content.hasExecutableLine)
        #expect(content.commentText == "just a comment")
    }
}
