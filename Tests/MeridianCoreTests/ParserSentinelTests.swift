import Testing
import Foundation
@testable import MeridianCore

@Suite("TableMode — parse / sentinel round-trips")
struct TableModeTests {
    @Test("every payload spelling parses to the right mode")
    func parseAll() {
        #expect(TableMode.parse(payload: "decision table") == .decision)
        #expect(TableMode.parse(payload: "decision") == .decision)
        #expect(TableMode.parse(payload: "iteration table") == .iteration)
        #expect(TableMode.parse(payload: "inert") == .inert)
        #expect(TableMode.parse(payload: "data table") == .data(name: nil))
        #expect(TableMode.parse(payload: "data table: orders") == .data(name: "orders"))
        #expect(TableMode.parse(payload: "data: orders") == .data(name: "orders"))
        #expect(TableMode.parse(payload: "ai-discretion") == .aiDiscretion)
        #expect(TableMode.parse(payload: "ai autonomy") == .aiAutonomy)
        #expect(TableMode.parse(payload: "nonsense") == nil)
        #expect(TableMode.parse(payload: "data table:") == .data(name: nil))
    }

    @Test("sentinelToken round-trips through fromSentinel for every case")
    func roundTrip() {
        let modes: [TableMode] = [.decision, .iteration, .inert, .data(name: nil),
                                  .data(name: "orders"), .aiDiscretion, .aiAutonomy]
        for m in modes {
            #expect(TableMode.fromSentinel(m.sentinelToken) == m)
        }
        // Unknown token falls back to decision.
        #expect(TableMode.fromSentinel("garbage") == .decision)
    }
}

@Suite("ChecklistMode — parse / sentinel round-trips")
struct ChecklistModeTests {
    @Test("payload spellings parse")
    func parseAll() {
        #expect(ChecklistMode.parse(payload: "invariants") == .invariant)
        #expect(ChecklistMode.parse(payload: "ai-discretion") == .aiDiscretion)
        #expect(ChecklistMode.parse(payload: "autonomy") == .aiAutonomy)
        #expect(ChecklistMode.parse(payload: "inert") == .inert)
        #expect(ChecklistMode.parse(payload: "???") == nil)
    }

    @Test("sentinelToken round-trips")
    func roundTrip() {
        for m: ChecklistMode in [.invariant, .aiDiscretion, .aiAutonomy, .inert] {
            #expect(ChecklistMode.fromSentinel(m.sentinelToken) == m)
        }
        #expect(ChecklistMode.fromSentinel("garbage") == .invariant)
    }
}

@Suite("IndentTokenizer — sentinels and flags")
struct IndentTokenizerSentinelTests {
    private func tokenize(_ s: String) -> [SourceLine] {
        IndentTokenizer().tokenize(s)
    }

    @Test("a markdown table collapses to one table sentinel line")
    func tableSentinel() {
        let lines = tokenize("""
        | name | age |
        | --- | --- |
        | bob | 30 |
        """)
        let decoded = lines.compactMap { decodeTableSentinel($0.text) }
        #expect(decoded.count == 1)
        #expect(decoded.first?.mode == .decision)   // unmarked default
        #expect(decoded.first?.body.contains("bob") == true)
    }

    @Test("an explicit !!! table marker selects the mode")
    func tableMarkedMode() {
        let lines = tokenize("""
        !!! table (( data table: people ))
        | name | age |
        | --- | --- |
        | bob | 30 |
        """)
        let decoded = lines.compactMap { decodeTableSentinel($0.text) }.first
        #expect(decoded?.mode == .data(name: "people"))
    }

    @Test("a marker with no following table emits a deferred marker error")
    func markerErrorAtEOF() {
        let lines = tokenize("!!! table (( decision ))")
        let err = lines.compactMap { decodeMarkerError($0.text) }.first
        #expect(err != nil)
        #expect(err?.contains("must immediately precede") == true)
    }

    @Test("a blank line between a !!! table marker and its table is tolerated")
    func tableMarkerToleratesBlankLineBeforeTable() {
        let lines = tokenize("""
        !!! table (( data table: people ))

        | name | age |
        | --- | --- |
        | bob | 30 |
        """)
        let decoded = lines.compactMap { decodeTableSentinel($0.text) }.first
        #expect(decoded?.mode == .data(name: "people"))
    }

    @Test("an unrecognized !!! table mode payload emits a deferred marker error naming the valid options")
    func unknownTableModeIsMarkerError() {
        let lines = tokenize("""
        !!! table (( nonsense-mode ))
        | name | age |
        | --- | --- |
        | bob | 30 |
        """)
        let err = lines.compactMap { decodeMarkerError($0.text) }.first
        #expect(err?.contains("unknown table mode") == true, Comment(rawValue: err ?? "nil"))
        #expect(err?.contains("ai-discretion") == true, Comment(rawValue: err ?? "nil"))
    }

    @Test("a blank line inside a checklist run followed by more checklist items continues the same run")
    func checklistToleratesBlankLineBetweenItems() {
        let lines = tokenize("""
        !!! checklist (( ai-autonomy ))
        - [ ] do thing one

        - [ ] do thing two
        """)
        let decoded = lines.compactMap { decodeChecklistSentinel($0.text) }.first
        let items = decoded?.body.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        #expect(items.count == 2, Comment(rawValue: "\(String(describing: decoded))"))
    }

    @Test("a checklist run ends at trailing non-checklist content that follows a terminal blank line")
    func checklistRunEndsAtTrailingContent() {
        let lines = tokenize("""
        !!! checklist (( ai-autonomy ))
        - [ ] do thing one

        Some unrelated trailing paragraph.
        """)
        let decoded = lines.compactMap { decodeChecklistSentinel($0.text) }.first
        let items = decoded?.body.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        #expect(items == ["do thing one"], Comment(rawValue: "\(String(describing: decoded))"))
        #expect(lines.contains { $0.text.contains("Some unrelated trailing paragraph") })
    }

    @Test("a bare `!!! table` marker with no payload defaults to a decision table")
    func bareTableMarkerDefaultsDecision() {
        let lines = tokenize("""
        !!! table
        | name | age |
        | --- | --- |
        | bob | 30 |
        """)
        let decoded = lines.compactMap { decodeTableSentinel($0.text) }.first
        #expect(decoded?.mode == .decision)
    }

    @Test("a bare `!!! checklist` marker with no payload defaults to an invariant checklist")
    func bareChecklistMarkerDefaultsInvariant() {
        let lines = tokenize("""
        !!! checklist
        - [ ] do the thing
        """)
        let decoded = lines.compactMap { decodeChecklistSentinel($0.text) }.first
        #expect(decoded?.mode == .invariant)
    }

    @Test("a dangling `!!! checklist` marker at end of file emits a task-list-specific error")
    func danglingChecklistMarkerAtEOF() {
        let lines = tokenize("""
        Some paragraph.
        !!! checklist (( ai-autonomy ))
        """)
        let err = lines.compactMap { decodeMarkerError($0.text) }.first
        #expect(err?.contains("task list") == true, Comment(rawValue: err ?? "nil"))
    }

    @Test("a checklist run tolerates two consecutive blank lines between items")
    func checklistToleratesTwoBlankLinesBetweenItems() {
        let lines = tokenize("""
        !!! checklist (( ai-autonomy ))
        - [ ] do thing one


        - [ ] do thing two
        """)
        let decoded = lines.compactMap { decodeChecklistSentinel($0.text) }.first
        let items = decoded?.body.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
        #expect(items.count == 2, Comment(rawValue: "\(String(describing: decoded))"))
    }

    @Test("a tab character contributes two columns to computed indent")
    func tabIndentCountsAsTwoSpaces() {
        let lines = tokenize("order has properties:\n\tlegacy_id.")
        #expect(lines.last?.indent == 2)
    }

    @Test("a fenced code block dedents a tab-indented body line by its tab-indented opening fence")
    func fenceDedentStripsLeadingTab() {
        let lines = tokenize("    ```\n\tX\n    ```")
        let decoded = lines.compactMap { decodeCodeBlockSentinel($0.text) }.first
        #expect(decoded?.body == "X", Comment(rawValue: "\(String(describing: decoded))"))
    }

    @Test("a marked checklist collapses to a checklist sentinel")
    func checklistSentinel() {
        let lines = tokenize("""
        !!! checklist (( ai-autonomy ))
        - [ ] do thing one
        - [x] do thing two
        """)
        let decoded = lines.compactMap { decodeChecklistSentinel($0.text) }.first
        #expect(decoded?.mode == .aiAutonomy)
    }

    @Test("an unmarked task-list item is tagged isChecklist with its checked state")
    func unmarkedChecklist() {
        let lines = tokenize("""
        - [ ] unchecked item
        - [x] checked item
        """).filter(\.isContent)
        #expect(lines.count == 2)
        #expect(lines[0].isChecklist)
        #expect(lines[0].checklistChecked == false)
        #expect(lines[1].checklistChecked == true)
    }

    @Test("a fenced code block collapses to a code-block sentinel")
    func codeBlockSentinel() {
        let fence = "```"
        let lines = tokenize("\(fence)swift\nlet x = 1\n\(fence)")
        let decoded = lines.compactMap { decodeCodeBlockSentinel($0.text) }.first
        #expect(decoded?.lang == "swift")
        #expect(decoded?.body.contains("let x = 1") == true)
    }

    @Test("# and > lines are comments; ## is a heading")
    func commentAndHeadingFlags() {
        let lines = tokenize("""
        # a markdown comment
        > a blockquote aside
        ## A Heading
        """)
        #expect(lines[0].isComment)
        #expect(lines[1].isComment)
        #expect(lines[2].headingLevel == 2)
        #expect(!lines[2].isComment)
    }
}

@Suite("IndentTokenizer — tokenize-category trace messages")
struct IndentTokenizerTraceTests {
    @Test("every tokenize decision point that logs a message actually fires it")
    func tokenizeTraceMessagesFire() {
        let cap = ParserTrace.capturing(categories: [.tokenize])
        let source = """
        !!! table (( data table: people ))
        | name | age |
        | --- | --- |
        | bob | 30 |

        !!! checklist (( ai-autonomy ))
        - [ ] do the thing

        !!! not-a-real-marker

        | x | y |
        | --- | --- |
        | 1 | 2 |

        ```swift
        let x = 1
        ```
        """
        _ = IndentTokenizer().tokenize(source, trace: cap.trace)
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("block marker → table") })
        #expect(lines.contains { $0.contains("block marker → checklist") })
        #expect(lines.contains { $0.contains("invalid block marker") })
        #expect(lines.contains { $0.contains("collapsed decision table") })
        #expect(lines.contains { $0.contains("collapsed `swift` fence") })
    }
}

@Suite("sentinel base64 decode")
struct SentinelDecodeTests {
    @Test("invalid base64 returns nil; valid round-trips")
    func decode() {
        #expect(decodeBase64Body("!!!not base64!!!") == nil)
        let b64 = Data("hello".utf8).base64EncodedString()
        #expect(decodeBase64Body(b64) == "hello")
    }

    @Test("each sentinel decoder rejects a payload with no colon separator")
    func decodersRejectMissingColon() {
        #expect(decodeToolFenceCommand("\u{E000}toolfence:noColonHere") == nil)
        #expect(decodeTableSentinel("\u{E000}table:noColonHere") == nil)
        #expect(decodeChecklistSentinel("\u{E000}checklist:noColonHere") == nil)
        #expect(decodeCodeBlockSentinel("\u{E000}codeblock:noColonHere") == nil)
    }

    @Test("each sentinel decoder rejects a payload with invalid base64 after the colon")
    func decodersRejectInvalidBase64() {
        #expect(decodeToolFenceCommand("\u{E000}toolfence:python:not base64!!!") == nil)
        #expect(decodeTableSentinel("\u{E000}table:decision:not base64!!!") == nil)
        #expect(decodeChecklistSentinel("\u{E000}checklist:invariant:not base64!!!") == nil)
    }
}
