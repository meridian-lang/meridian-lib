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
            compiler: Compiler(options: .init(trace: .silent())),
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

    @Test("a Contract heading with zero checkable/normative signal is judgment-wrapped, not silently inert")
    func contractInert() throws {
        let out = try Self.mark("""
        # Title

        ## Contract

        This skill guarantees a thing.
        """)
        // "Contract" already asserts an invariants role — with no checkable
        // predicate and no unmined normative cue words, that absence of
        // signal is itself the judgment signal (AGENTS.md §15), not evidence
        // the guarantee is genuinely inert. The heading carries an explicit
        // `(( role: procedure ))` marker (not a clean heading + rulebook
        // alias): the checkable-role body builder (invariants here) has no
        // case for a `use judgment to follow …:` prose step, and a marker is
        // authoritative over any rulebook alias for the same heading text
        // (unlike an alias, which can lose to a same-heading corpus-wide
        // alias — see `SkillMigrator.SplitPlan.forcedRoleMarker`).
        #expect(out.contains("use judgment to follow the Contract guidance:"), Comment(rawValue: out))
        #expect(out.contains("## Contract (( role: procedure ))"), Comment(rawValue: out))
    }

    @Test("an Anti-Patterns heading with zero checkable/normative signal is judgment-wrapped, not silently inert")
    func antiPatternsInert() throws {
        let out = try Self.mark("""
        ## Anti-Patterns

        - Don't do the bad thing.
        """)
        #expect(out.contains("use judgment to follow the Anti-Patterns guidance:"), Comment(rawValue: out))
        #expect(out.contains("## Anti-Patterns (( role: procedure ))"), Comment(rawValue: out))
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

    @Test("a comment-only shell fence is judgment-routed guidance, not deterministic shell or plain inert")
    func commentOnlyShellFenceRoutesToJudgment() throws {
        let source = """
        ## Deal / company monitoring (cron)

        For each active item under `deals/` or `companies/`:

        ```bash
        # Weekly: pull recent news per company; flag changes for review.
        ```
        """
        let out = try Self.mark(source)
        #expect(out.contains("## Deal / company monitoring (cron)\n"), Comment(rawValue: out))
        #expect(!out.contains("## Deal / company monitoring (cron) (( inert"),
                Comment(rawValue: out))
        #expect(out.contains("use judgment to follow the Deal / company monitoring (cron) guidance:"),
                Comment(rawValue: out))
        #expect(!out.contains("Deal / company monitoring (cron)\(SkillMigrator.splitHeadingSeparator)"),
                Comment(rawValue: out))
        #expect(try Self.aliases(source) == [
            SkillMigrator.SectionAlias(heading: "Deal / company monitoring (cron)", role: .procedure),
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

    @Test("a fence in an unmapped language still stays inert even with a mapping configured for another language")
    func unmappedLanguageFenceStaysInertDespiteOtherMapping() throws {
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

    @Test("a narrative procedure heading with zero executable signal is judgment-wrapped, not silently inert")
    func recognizedNarrativeHeadingsBecomeInert() throws {
        let out = try Self.mark("""
        ## Phases

        do the thing.

        ## When to invoke

        - "trigger phrase"
        """)
        // "Phases" already asserts it is a procedure — zero exec signal there
        // is the judgment signal itself (AGENTS.md §16 / Phase 1 item 4), not
        // evidence the section is genuinely inert.
        #expect(out.contains("use judgment to follow the Phases guidance:"), Comment(rawValue: out))
        #expect(!out.contains("## Phases (( inert"), Comment(rawValue: out))
        // "When to invoke" is a recognized applicability heading; a bare
        // trigger-phrase bullet is neither checkable nor normative, so the
        // same zero-signal-is-the-signal rule applies (AGENTS.md §15) — it is
        // judgment-wrapped rather than left plainly inert. Like Contract/
        // Anti-Patterns above, the checkable-role (applicability) body
        // builder has no prose-step case, so the heading carries an explicit
        // `(( role: procedure ))` marker rather than a clean heading + alias.
        #expect(out.contains("use judgment to follow the When to invoke guidance:"), Comment(rawValue: out))
        #expect(out.contains("## When to invoke (( role: procedure ))"), Comment(rawValue: out))
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

    @Test("Phase N: narrative heading is recognized as procedure and judgment-wrapped, not silently inert")
    func phasePrefixNarrativeInert() throws {
        let out = try Self.mark("""
        ## Phase 1: Inventory

        do the inventory.
        """)
        #expect(out.contains("use judgment to follow the Phase 1: Inventory guidance:"), Comment(rawValue: out))
        #expect(!out.contains("## Phase 1: Inventory (( inert"), Comment(rawValue: out))
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

    @Test("a plain-statement procedure line with no vocabulary is judgment-wrapped, not silently inert (baseline, symbols: nil today)")
    func plainStatementInertWithoutVocab() throws {
        let out = try Self.mark("""
        ## Setup

        ## Steps

        Validate the order.
        """)
        // With no vocabulary threaded in, "Validate the order." can't
        // trial-lower — but "Steps" already asserts it is a procedure, so
        // the zero-exec-signal body still routes to judgment rather than a
        // plain inert marker (AGENTS.md §16 / Phase 1 item 4).
        #expect(out.contains("use judgment to follow the Steps guidance:"), Comment(rawValue: out))
        #expect(!out.contains("## Steps (( inert"), Comment(rawValue: out))
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

    @Test("below the split threshold, a mixed section routes to a judgment-wrap instead of splitting (fuzzy routing on)")
    func belowThresholdRoutesToJudgmentWrap() throws {
        let body = """
        ## Steps

        This phase exists to keep orders tidy over the long run.

        It runs on a slow cadence and touches many different systems.

        Most of the time nothing needs to change at all.

        Occasionally a manual review catches something worth fixing.

        Validate the order.
        """
        let out = try Self.mark(body, vocabularies: [Self.orderVocab])
        // No inert marker — the section is executable via the judgment wrap.
        #expect(out.contains("## Steps\n"), Comment(rawValue: out))
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(out.contains("use judgment to follow the Steps guidance:"), Comment(rawValue: out))
        #expect(out.contains("This phase exists to keep orders tidy over the long run."), Comment(rawValue: out))
        #expect(out.contains("Validate the order."), Comment(rawValue: out))
        #expect(!out.contains(SkillMigrator.splitHeadingSeparator), Comment(rawValue: out))

        // Idempotent: running again does not nest a second judgment wrap.
        let again = try Self.mark(out, vocabularies: [Self.orderVocab])
        #expect(again == out, Comment(rawValue: again))
    }

    @Test("below the split threshold with fuzzy routing disabled, a mixed section stays whole and plainly inert (opt-out)")
    func belowThresholdStaysWholeInertWithRouteFuzzyOff() throws {
        let out = try Self.mark("""
        ## Steps

        This phase exists to keep orders tidy over the long run.

        It runs on a slow cadence and touches many different systems.

        Most of the time nothing needs to change at all.

        Occasionally a manual review catches something worth fixing.

        Validate the order.
        """, vocabularies: [Self.orderVocab], routeFuzzy: false)
        #expect(out.contains("## Steps (( inert, role: procedure ))"), Comment(rawValue: out))
        #expect(!out.contains("use judgment to follow"), Comment(rawValue: out))
        #expect(!out.contains(SkillMigrator.splitHeadingSeparator), Comment(rawValue: out))
    }

    // MARK: - AGENTS.md Phase 1 item 3: automatic mixed-section split

    @Test("above the split threshold, a mixed section splits: leftover narrative under the parent is judgment-wrapped (not plain inert), the executable run becomes a child heading")
    func aboveThresholdSplits() throws {
        let out = try Self.mark("""
        ## Steps

        This phase exists to keep orders tidy.

        Validate the order.
        """, vocabularies: [Self.orderVocab])
        // "Steps" is already a recognized `.procedure` heading (roleAlreadyAsserted),
        // so the leftover narrative left behind by the split gets the same
        // zero-deterministic-signal-is-the-judgment-signal treatment as a
        // whole-section judgment-wrap (AGENTS.md §15/§16), rather than sitting
        // under the parent as silent `(( inert ))` prose — no forced marker is
        // needed since `.procedure` already accepts a `use judgment …:` prose step.
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(out.contains("## Steps\n"), Comment(rawValue: out))
        #expect(out.contains("use judgment to follow the Steps guidance:"), Comment(rawValue: out))
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
        #expect(result.compiledOK, Comment(rawValue: result.meriSource + "\n\n" + result.report.diagnostics.joined(separator: "\n")))
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
        #expect(result.compiledOK, Comment(rawValue: result.meriSource + "\n\n" + result.report.diagnostics.joined(separator: "\n")))
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
        // This is an unrecognized (custom) heading, so its leftover narrative
        // gets the generic "(( inert ))" marker, not a role-specific one. Step
        // 4's shape (a stray word between the backtick command and its " -- "
        // annotation) falls outside today's annotated-command grammar, so it
        // stays narrative alongside the closing note — split correctly moves
        // ONLY the three cleanly-shaped commands, and drops nothing.
        let out = try Self.mark("""
        ### Lookup sequence (MANDATORY for every entity question)

        1. `gbrain search "name"` -- keyword match, fast, works without embeddings
        2. `gbrain query "what do we know about name"` -- hybrid search, needs embeddings
        3. `gbrain get <slug>` -- direct page read when you know the slug from steps 1-2
        4. `grep` fallback -- only if gbrain returns zero results AND the file may exist outside the indexed brain

        Stop at the first step that gives you what you need. Most lookups resolve at step 1.
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("### Lookup sequence (MANDATORY for every entity question) (( inert ))"),
                Comment(rawValue: out))
        #expect(out.contains("Stop at the first step that gives you what you need."), Comment(rawValue: out))
        #expect(out.contains(#"4. `grep` fallback"#), Comment(rawValue: out))
        #expect(out.contains("#### Lookup sequence (MANDATORY for every entity question)\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "#### Lookup sequence (MANDATORY for every entity question)\(separator)")!.lowerBound
        let child = String(out[childIdx...])
        #expect(child.contains(#"1. `gbrain search "name"`"#), Comment(rawValue: out))
        #expect(child.contains(#"3. `gbrain get <slug>`"#), Comment(rawValue: out))
        // Order-preserving: step 1 precedes step 3 under the generated child.
        #expect(child.range(of: "1. `gbrain search")!.lowerBound < child.range(of: "3. `gbrain get")!.lowerBound)
        #expect(!child.contains("Stop at the first step"), Comment(rawValue: out))
        // Step 4 was never lost — it stayed under the original heading's narrative.
        #expect(!child.contains("`grep` fallback"), Comment(rawValue: out))
    }

    @Test("briefing's Phases: a numbered procedure list with a trailing note splits cleanly")
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
        // The closing note ("never skip ahead to render") is a real ordering
        // constraint, not filler — the leftover narrative under the parent
        // heading is judgment-wrapped rather than left as plain inert prose
        // (AGENTS.md §15/§16), same as any other `.procedure` heading whose
        // split leaves substantive leftover narrative behind.
        #expect(!out.contains("(( inert"), Comment(rawValue: out))
        #expect(out.contains("use judgment to follow the Phases guidance:"), Comment(rawValue: out))
        #expect(out.contains("### Phases\(separator)"), Comment(rawValue: out))
        #expect(out.contains("These phases always run in order"), Comment(rawValue: out))
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
        #expect(out.contains("### Link graph extraction (( inert ))"), Comment(rawValue: out))
        #expect(out.contains("This scans all markdown files"), Comment(rawValue: out))
        #expect(out.contains("#### Link graph extraction\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "#### Link graph extraction\(separator)")!.lowerBound
        let child = String(out[childIdx...])
        // The annotation label travels with its fence into the generated child.
        #expect(child.contains("run batch extraction:"), Comment(rawValue: out))
        #expect(child.contains("gbrain extract links --dir ~/brain"), Comment(rawValue: out))
        #expect(!child.contains("This scans all markdown files"), Comment(rawValue: out))
    }

    @Test("brain_taxonomist's Step 1: a fuzzy question-arrow decision list routes to a judgment wrap (case 3 of the three-way lowering)")
    func brainTaxonomistStep1RoutesToJudgmentWrap() throws {
        // sample-gbrain/original-skills/brain-taxonomist/SKILL.md, "### Step 1":
        // a question-arrow decision list whose questions are phrased in
        // question word-order ("Is X a Y?"), which the classifier does not
        // read as a checkable predicate (needs entity/semantic judgment) —
        // the honest outcome per the Phase 2 design is case 3: route to an
        // explicit AI decision step, not fake determinism.
        let step1 = try Self.mark("""
        ### Step 1: Identify primary subject type

        Walk these questions in order:
        1. Is the primary subject a NAMED PERSON? → person-typed directory
        2. Is the primary subject a NAMED ORGANIZATION? → company-typed directory
        3. Is it about a TIME-BOUNDED EVENT (meeting, deal, trip)? → temporal-typed directory
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(step1.contains("### Step 1: Identify primary subject type (( inert ))"), Comment(rawValue: step1))
        #expect(step1.contains("#### Step 1: Identify primary subject type\(separator)"), Comment(rawValue: step1))
        #expect(step1.contains("use judgment to weigh each question below:"), Comment(rawValue: step1))
        #expect(step1.contains("Is the primary subject a NAMED PERSON? → person-typed directory"), Comment(rawValue: step1))
    }

    // MARK: - Phase 2 idiom: question-arrow decision protocol

    @Test("question-arrow case 1: checkable questions with statement-shaped rhs desugar to the suffix-conditional idiom")
    func questionArrowCase1DesugarsToSuffixConditional() throws {
        let out = try Self.mark("""
        ### Response

        Walk these conditions in order:
        1. the health status is "down"? -> restart the service
        2. the queue depth is greater than 100? -> page the on call engineer
        """, vocabularies: [Self.decisionVocab])
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("#### Response\(separator)"), Comment(rawValue: out))
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
        #expect(out.contains("#### Response\(separator)"), Comment(rawValue: out))
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

    @Test("a full question-arrow candidate strict-compiles end to end via migrate() for all three cases")
    func questionArrowCandidatesStrictCompile() async throws {
        let case1 = try await Self.migrator(vocabularies: [Self.decisionVocab]).migrate("""
        ### Response

        Walk these conditions in order:
        1. the health status is "down"? -> restart the service
        2. the queue depth is greater than 100? -> page the on call engineer
        """)
        #expect(case1.compiledOK, Comment(rawValue: case1.meriSource + "\n\n" + case1.report.diagnostics.joined(separator: "\n")))

        let case2 = try await Self.migrator().migrate("""
        ### Response

        deciding the directory:
        1. the subject type is "person"? -> person-typed directory
        2. the subject type is "organization"? -> company-typed directory
        """)
        #expect(case2.compiledOK, Comment(rawValue: case2.meriSource + "\n\n" + case2.report.diagnostics.joined(separator: "\n")))

        let case3 = try await Self.migrator().migrate("""
        ### Step 1: Identify primary subject type

        Walk these questions in order:
        1. Is the primary subject a NAMED PERSON? → person-typed directory
        2. Is the primary subject a NAMED ORGANIZATION? → company-typed directory
        3. Is it about a TIME-BOUNDED EVENT (meeting, deal, trip)? → temporal-typed directory
        """)
        #expect(case3.compiledOK, Comment(rawValue: case3.meriSource + "\n\n" + case3.report.diagnostics.joined(separator: "\n")))
    }

    @Test("question-arrow protocol with fuzzy routing disabled leaves case 3 lists plainly inert (opt-out parity)")
    func questionArrowCase3RespectsRouteFuzzyOff() throws {
        let out = try Self.mark("""
        ### Step 1: Identify primary subject type

        Walk these questions in order:
        1. Is the primary subject a NAMED PERSON? → person-typed directory
        2. Is the primary subject a NAMED ORGANIZATION? → company-typed directory
        3. Is it about a TIME-BOUNDED EVENT (meeting, deal, trip)? → temporal-typed directory
        """, routeFuzzy: false)
        #expect(out.contains("### Step 1: Identify primary subject type (( inert ))"), Comment(rawValue: out))
        #expect(!out.contains("use judgment"), Comment(rawValue: out))
        #expect(!out.contains(SkillMigrator.splitHeadingSeparator), Comment(rawValue: out))
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
        #expect(out.contains("### Step 5: Validate before writing (( inert ))"), Comment(rawValue: out))
        #expect(out.contains("#### Step 5: Validate before writing\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "#### Step 5: Validate before writing\(separator)")!.lowerBound
        let child = String(out[childIdx...])
        #expect(child.contains("!!! checklist (( ai-autonomy ))"), Comment(rawValue: out))
        #expect(child.contains("- [ ] Path follows the active pack's path_prefixes"), Comment(rawValue: out))
        #expect(child.contains("- [ ] Cross-links to related pages are included"), Comment(rawValue: out))
        // The marker directly precedes the checklist — no blank line between.
        let markerRange = child.range(of: "!!! checklist (( ai-autonomy ))")!
        let afterMarker = child[markerRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(afterMarker.hasPrefix("- [ ] Path follows"), Comment(rawValue: out))
        #expect(!child.contains("Prefer flagging schema gaps"), Comment(rawValue: out))

        // With fuzzy routing disabled, the checklist stays inert (opt-out parity).
        let optOut = try Self.mark("""
        ### Step 5: Validate before writing

        - [ ] Path follows the active pack's path_prefixes
        - [ ] Slug is kebab-case, descriptive
        - [ ] Cross-links to related pages are included

        Prefer flagging schema gaps over guessing the closest-fitting type.
        """, routeFuzzy: false)
        #expect(optOut.contains("### Step 5: Validate before writing (( inert ))"), Comment(rawValue: optOut))
        #expect(!optOut.contains("!!! checklist"), Comment(rawValue: optOut))
        #expect(!optOut.contains(SkillMigrator.splitHeadingSeparator), Comment(rawValue: optOut))
    }

    @Test("testing's Test tiers: a fuzzy Markdown table is AI-routed via ai-discretion instead of staying inert")
    func testingTierTableRoutesToAiDiscretionTable() throws {
        // sample-gbrain/original-skills/testing/SKILL.md, "### Test tiers": a
        // Markdown table whose cells are descriptive, not checkable — doesn't
        // trial-lower as a decision/data table, so route-fuzzy wraps it in
        // `!!! table (( ai-discretion ))` rather than dropping it inert. (This
        // is deliberately conservative: a table that's genuine reference
        // material the workflow never acts on is a Phase 3 pilot-review call,
        // not a marking-pass heuristic — over-routing is reversible, silently
        // staying inert was the bug.)
        let out = try Self.mark("""
        ### Test tiers

        | Tier | What it runs | Wall time | Gates |
        |------|--------------|-----------|-------|
        | **Unit** | `bun test` (deterministic, zero external calls) | <2s | Every commit |
        | **Evals** | LLM-judge or quality evals | ~60s | Daily |
        """)
        let separator = SkillMigrator.splitHeadingSeparator
        #expect(out.contains("### Test tiers (( inert ))"), Comment(rawValue: out))
        #expect(out.contains("#### Test tiers\(separator)"), Comment(rawValue: out))
        let childIdx = out.range(of: "#### Test tiers\(separator)")!.lowerBound
        let child = String(out[childIdx...])
        #expect(child.contains("!!! table (( ai-discretion ))"), Comment(rawValue: out))
        #expect(child.contains("| Tier | What it runs | Wall time | Gates |"), Comment(rawValue: out))
        #expect(child.contains("| Evals | LLM-judge or quality evals | ~60s | Daily |"), Comment(rawValue: out))

        // Opt-out parity: with fuzzy routing disabled, the table stays inert.
        let optOut = try Self.mark("""
        ### Test tiers

        | Tier | What it runs | Wall time | Gates |
        |------|--------------|-----------|-------|
        | **Unit** | `bun test` (deterministic, zero external calls) | <2s | Every commit |
        | **Evals** | LLM-judge or quality evals | ~60s | Daily |
        """, routeFuzzy: false)
        #expect(optOut.contains("### Test tiers (( inert ))"), Comment(rawValue: optOut))
        #expect(!optOut.contains("!!! table"), Comment(rawValue: optOut))
        #expect(!optOut.contains(SkillMigrator.splitHeadingSeparator), Comment(rawValue: optOut))
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
        #expect(out.contains("## Output Format (( inert, role: template ))"), Comment(rawValue: out))
    }

    @Test("a heading whose text already carries the generated split suffix is never split again")
    func headingWithSplitSuffixIsNeverReSplit() throws {
        // Simulates re-scanning a generated child heading whose body no longer
        // proves fully executable (e.g. the vocabulary that made it lower is
        // unavailable) — the recognizable-suffix guard must prevent minting a
        // nested "… — steps — steps" grandchild; it falls back to plain inert.
        let out = try Self.mark("""
        ## Steps\(SkillMigrator.splitHeadingSeparator)

        This phase exists to keep orders tidy.

        Validate the order.
        """)
        #expect(!out.contains("\(SkillMigrator.splitHeadingSeparator)\(SkillMigrator.splitHeadingSeparator)"),
                Comment(rawValue: out))
        #expect(out.contains("## Steps\(SkillMigrator.splitHeadingSeparator) (( inert ))"), Comment(rawValue: out))
    }

    // MARK: - Phase 2 idiom: bold-label step tolerance

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
}
