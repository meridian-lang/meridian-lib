import Testing
@testable import MeridianCore

@Suite("Markdown tables + task-lists")
struct TablesAndChecklistsTests {

    private func parse(_ source: String) throws -> ASTBlock {
        try StatementParser(symbols: SymbolTable(), trace: .silent())
            .parseBlock(IndentTokenizer().tokenize(source))
    }

    // MARK: Tokenizer

    @Test("checklist items are tagged with their checkbox state")
    func checklistTagging() {
        let lines = IndentTokenizer().tokenize("""
        - [ ] ci is green
        - [x] tests pass
        - a plain bullet
        """).filter(\.isContent)
        #expect(lines.count == 3)
        #expect(lines[0].isChecklist && lines[0].checklistChecked == false)
        #expect(lines[0].text == "ci is green")
        #expect(lines[1].isChecklist && lines[1].checklistChecked == true)
        #expect(lines[2].isChecklist == false)
    }

    @Test("a markerless table collapses to a decision-mode sentinel")
    func tableCollapses() {
        let lines = IndentTokenizer().tokenize("""
        | status | action |
        | --- | --- |
        | open | escalate the issue |
        """).filter(\.isContent)
        #expect(lines.count == 1)
        guard let decoded = TableParser.decode(lines[0].text) else {
            Issue.record("expected a table sentinel")
            return
        }
        #expect(decoded.mode == .decision)
        #expect(decoded.table.header == ["status", "action"])
        #expect(decoded.table.rows.count == 1)
    }

    @Test("a !!! marker sets the table mode")
    func markerSetsMode() {
        let lines = IndentTokenizer().tokenize("""
        !!! table (( data table: configs ))
        | name | port |
        | --- | --- |
        | web | 80 |
        """).filter(\.isContent)
        #expect(lines.count == 1)
        guard let decoded = TableParser.decode(lines[0].text) else {
            Issue.record("expected a table sentinel")
            return
        }
        #expect(decoded.mode == .data(name: "configs"))
    }

    // MARK: Decision tables

    @Test("a decision table lowers to one conditional per row")
    func decisionTableToConditionals() throws {
        let block = try parse("""
        | status | action |
        | --- | --- |
        | open | complete |
        | closed | commit |
        """)
        let conditionals = block.statements.filter { if case .conditional = $0 { return true } else { return false } }
        #expect(conditionals.count == 2)
    }

    @Test("a wildcard row becomes an unconditional action")
    func wildcardRow() throws {
        let block = try parse("""
        | status | action |
        | --- | --- |
        | * | complete |
        """)
        #expect(block.statements.count == 1)
        if case .conditional = block.statements[0] {
            Issue.record("a fully-wildcard row should not be a conditional")
        }
    }

    // MARK: Data tables

    @Test("a data table binds a record list")
    func dataTableBinding() throws {
        let block = try parse("""
        !!! table (( data table: servers ))
        | name | port |
        | --- | --- |
        | web | 80 |
        | db | 5432 |
        """)
        #expect(block.statements.count == 1)
        guard case .bind(let bind) = block.statements[0] else {
            Issue.record("expected a bind")
            return
        }
        #expect(bind.name == "servers")
        guard case .recordList(let fields, let rows) = bind.value else {
            Issue.record("expected a recordList value")
            return
        }
        #expect(fields == ["name", "port"])
        #expect(rows.count == 2)
    }

    @Test("a data table without a name binds to `table`")
    func dataTableDefaultName() throws {
        let block = try parse("""
        !!! table (( data table ))
        | name | port |
        | --- | --- |
        | web | 80 |
        """)
        guard case .bind(let bind) = block.statements.first else {
            Issue.record("expected a bind")
            return
        }
        #expect(bind.name == "table")
    }

    // MARK: Inert + errors

    @Test("an inert table produces no statements")
    func inertTableSkipped() throws {
        let block = try parse("""
        !!! table (( inert ))
        | a | b |
        | --- | --- |
        | 1 | 2 |
        """)
        #expect(block.statements.isEmpty)
    }

    @Test("a !!! marker not followed by a table is a hard error")
    func danglingMarkerErrors() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            !!! table (( inert ))
            this is not a table
            """)
        }
    }

    // MARK: Checklists → invariants

    @Test("a checkable checklist item becomes an assert")
    func checkableChecklistAsserts() throws {
        let block = try parse("- [ ] the link count is at least 1")
        guard case .assertStmt = block.statements.first else {
            Issue.record("expected an assert from a checkable checklist item")
            return
        }
    }

    @Test("a non-checkable checklist item is a hard error")
    func nonCheckableChecklistErrors() {
        #expect(throws: CompilerError.self) {
            _ = try parse("- [ ] file everything properly")
        }
    }

    @Test("an unknown block kind is a hard error")
    func unknownKindErrors() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            !!! frobnicate (( inert ))
            | a | b |
            | --- | --- |
            | 1 | 2 |
            """)
        }
    }

    // MARK: End-to-end (sectioned skill via Compiler)

    private func compileSkill(_ body: String) throws -> String {
        try Compiler(options: .init(fallbackPolicy: .lenient)).compile(
            meridianSource: body, meridianFile: "test.meridian",
            merconfigSource: "", merconfigFile: "test.merconfig")
    }

    @Test("a decision table inside a ## Protocol section emits branches")
    func decisionTableInSection() throws {
        let out = try compileSkill("""
        ## Protocol

        | status | action          |
        |--------|-----------------|
        | open   | complete        |
        | closed | commit          |
        """)
        #expect(out.contains("if "))
    }

    @Test("a data table inside a ## Protocol section emits a record list")
    func dataTableInSection() throws {
        let out = try compileSkill("""
        ## Protocol

        !!! table (( data table: tiers ))
        | name | floor |
        |------|-------|
        | gold | 100   |
        """)
        #expect(out.contains("Value.list("))
        #expect(out.contains(".record("))
    }

    @Test("a checklist inside an executable section emits an assert")
    func checklistInSection() throws {
        let out = try compileSkill("""
        ## Protocol

        - [ ] the page count is at least 1
        """)
        #expect(out.contains("MeridianComparison."))
    }

    // MARK: AI-routed fuzzy tables + checklists

    @Test("ai-discretion / ai-autonomy table markers parse to their modes")
    func aiTableModesParse() {
        #expect(TableMode.parse(payload: "ai-discretion") == .aiDiscretion)
        #expect(TableMode.parse(payload: "ai autonomy") == .aiAutonomy)
        #expect(TableMode.fromSentinel(TableMode.aiDiscretion.sentinelToken) == .aiDiscretion)
        #expect(TableMode.fromSentinel(TableMode.aiAutonomy.sentinelToken) == .aiAutonomy)
    }

    @Test("a fuzzy decision table routed to ai-discretion lowers to a prose step")
    func aiDiscretionTable() throws {
        let block = try parse("""
        !!! table (( ai-discretion ))
        | Condition | Action |
        |---|---|
        | user asks for research | spawn a research subagent |
        | user asks for a script run | submit a shell job |
        """)
        #expect(block.statements.count == 1)
        guard case .proseStep(let step) = block.statements.first else {
            Issue.record("expected a prose step")
            return
        }
        #expect(step.dispatch == .discretion)
        #expect(step.text.contains("Decide which case"))
        #expect(step.text.contains("when user asks for research, spawn a research subagent"))
    }

    @Test("a !!! checklist (( ai-autonomy )) marker collapses items to one autonomy prose step")
    func aiAutonomyChecklist() throws {
        let block = try parse("""
        !!! checklist (( ai-autonomy ))
        - [ ] all entity pages are cross-linked
        - [ ] no DRY violations across skills
        - [x] schema pack is consistent
        """)
        #expect(block.statements.count == 1)
        guard case .proseStep(let step) = block.statements.first else {
            Issue.record("expected a prose step")
            return
        }
        #expect(step.dispatch == .autonomy)
        #expect(step.text.contains("Ensure every acceptance criterion"))
        #expect(step.text.contains("- all entity pages are cross-linked"))
        #expect(step.text.contains("- no DRY violations across skills"))
    }

    @Test("a checklist marker collapses the run (the sentinel hides per-item tagging)")
    func checklistMarkerCollapses() {
        let lines = IndentTokenizer().tokenize("""
        !!! checklist (( ai-autonomy ))
        - [ ] a
        - [ ] b
        """).filter(\.isContent)
        #expect(lines.count == 1)
        guard let decoded = decodeChecklistSentinel(lines[0].text) else {
            Issue.record("expected a checklist sentinel")
            return
        }
        #expect(decoded.mode == .aiAutonomy)
        #expect(decoded.body == "a\nb")
    }

    @Test("a !!! checklist marker not followed by a task list is a hard error")
    func danglingChecklistMarkerErrors() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            !!! checklist (( ai-autonomy ))
            this is not a task list
            """)
        }
    }

    @Test("an unknown checklist mode is a hard error")
    func unknownChecklistModeErrors() {
        #expect(throws: CompilerError.self) {
            _ = try parse("""
            !!! checklist (( frobnicate ))
            - [ ] a
            """)
        }
    }

    @Test("an inert checklist marker produces no statements")
    func inertChecklistSkipped() throws {
        let block = try parse("""
        !!! checklist (( inert ))
        - [ ] fuzzy criterion one
        - [ ] fuzzy criterion two
        """)
        #expect(block.statements.isEmpty)
    }

    @Test("an unmarked task list is still per-item invariants (regression)")
    func unmarkedChecklistStillAsserts() throws {
        let block = try parse("""
        - [ ] the page count is at least 1
        - [ ] the link count is at least 1
        """)
        let asserts = block.statements.filter { if case .assertStmt = $0 { return true } else { return false } }
        #expect(asserts.count == 2)
    }

    @Test("a fuzzy decision table in a section emits a planner call (executeProsePlan)")
    func aiDiscretionTableInSection() throws {
        let out = try compileSkill("""
        ## Protocol

        !!! table (( ai-discretion ))
        | Condition | Action |
        |---|---|
        | user asks for research | spawn a research subagent |
        | user asks for a script run | submit a shell job |
        """)
        #expect(out.contains("executeProsePlan"))
    }

    @Test("a fuzzy acceptance checklist in a section emits an autonomous loop")
    func aiAutonomyChecklistInSection() throws {
        let out = try compileSkill("""
        ## Protocol

        !!! checklist (( ai-autonomy ))
        - [ ] all entity pages are cross-linked
        - [ ] no DRY violations across skills
        """)
        #expect(out.contains("executeAutonomousLoop"))
    }

    // MARK: `## Tools Used` accepts both bullet forms

    @Test("Tools Used mines both `(<id>)` and leading-backtick `` `id` — desc`` forms")
    func toolsUsedBothForms() throws {
        let manifest = try Compiler(options: .init(fallbackPolicy: .lenient)).compileWithManifest(
            meridianSource: """
            ## Tools Used

            - read a brain page (get_page)
            - `query` — hybrid vector+keyword search
            - `search` - keyword search for variants.
            """,
            meridianFile: "test.meridian",
            vocabularies: []).manifest
        #expect(manifest.toolsUsed == ["get_page", "query", "search"],
                Comment(rawValue: "got \(manifest.toolsUsed)"))
    }

    @Test("a backticked CLI command in Tools Used is rejected (not a bare tool id)")
    func toolsUsedRejectsBacktickedCommand() {
        #expect(throws: CompilerError.self) {
            _ = try compileSkill("""
            ## Tools Used

            - `gbrain init --non-interactive --url ...` -- create brain
            """)
        }
    }
}
