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

@Suite("sentinel base64 decode")
struct SentinelDecodeTests {
    @Test("invalid base64 returns nil; valid round-trips")
    func decode() {
        #expect(decodeBase64Body("!!!not base64!!!") == nil)
        let b64 = Data("hello".utf8).base64EncodedString()
        #expect(decodeBase64Body(b64) == "hello")
    }
}
