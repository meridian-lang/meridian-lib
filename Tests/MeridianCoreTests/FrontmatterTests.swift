import Testing
import Foundation
@testable import MeridianCore

/// Pins the shared frontmatter parser's three shapes: the raw-line fence
/// locator (`locate`), the simple lowercase-key reader (`simpleEntries`), and
/// the full tokenized parse (`parse`) — including the block-scalar, inline
/// flow-sequence, YAML block-sequence, and folded-continuation value forms,
/// which previously had no direct unit test.
@Suite("Frontmatter — single leading block parser")
struct FrontmatterTests {

    private static func lines(_ source: String) -> [SourceLine] {
        IndentTokenizer().tokenize(source, file: "fm.meri")
    }

    @Test("locate: fence-at-line-0 mode vs blank-line-tolerant mode")
    func locateBlankModes() {
        #expect(Frontmatter.locate(["---", "name: x", "---", "body"], skipLeadingBlanks: false)?.open == 0)
        #expect(Frontmatter.locate(["---", "name: x", "---", "body"], skipLeadingBlanks: false)?.close == 2)
        let withBlanks = ["", "  ", "---", "name: x", "---", "body"]
        #expect(Frontmatter.locate(withBlanks, skipLeadingBlanks: false) == nil)
        #expect(Frontmatter.locate(withBlanks, skipLeadingBlanks: true)?.open == 2)
        #expect(Frontmatter.locate(withBlanks, skipLeadingBlanks: true)?.close == 4)
        #expect(Frontmatter.locate([], skipLeadingBlanks: true) == nil)
        #expect(Frontmatter.locate(["nope"], skipLeadingBlanks: false) == nil)
        #expect(Frontmatter.locate(["---", "name: x"], skipLeadingBlanks: false) == nil)  // no close fence
    }

    @Test("simpleEntries: lowercase keys, de-quoted values, nil without a block or entries")
    func simpleEntries() {
        let entries = Frontmatter.simpleEntries("""
        ---
        Name: demo
        IMPORTS: "a.meridian, b.meridian"
        # comment
        ---
        body
        """)
        #expect(entries?["name"] == "demo")
        #expect(entries?["imports"] == "a.meridian, b.meridian")
        #expect(Frontmatter.simpleEntries("no frontmatter") == nil)
        #expect(Frontmatter.simpleEntries("---\n---\nbody") == nil)             // empty block
        #expect(Frontmatter.simpleEntries("---\nname: x")?["name"] == "x")      // unterminated block still reads
    }

    @Test("parse: nil without a leading fence; blank lines before the fence are tolerated")
    func parseFencePlacement() throws {
        #expect(Frontmatter.parse(Self.lines("body only")) == nil)
        #expect(Frontmatter.parse(Self.lines("\n\nbody")) == nil)
        let parsed = try #require(Frontmatter.parse(Self.lines("\n\n---\nname: x\n---\nbody")))
        #expect(parsed.entries.map(\.key) == ["name"])
        #expect(parsed.consumed == 5)
        #expect(Self.lines("\n\n---\nname: x\n---\nbody")[parsed.consumed].text == "body")
    }

    @Test("parse: every block-scalar introducer, with interior and trailing blanks")
    func parseBlockScalars() throws {
        let source = """
        ---
        a: |
          x

          y

        b: |-
          z
        c: |+
          u
        d: >
          w
        e: >-
          v
        f: >+
          t
        ---
        body
        """
        let parsed = try #require(Frontmatter.parse(Self.lines(source)))
        let entries = Dictionary(uniqueKeysWithValues: parsed.entries.map { ($0.key, $0.value) })
        #expect(entries["a"] == "x\n\ny")
        #expect(entries["b"] == "z")
        #expect(entries["c"] == "u")
        #expect(entries["d"] == "w")
        #expect(entries["e"] == "v")
        #expect(entries["f"] == "t")
        #expect(parsed.consumed == 17)
        #expect(Self.lines(source)[parsed.consumed].text == "body")
    }

    @Test("parse: inline flow sequences, block sequences, and folded continuations")
    func parseCollectionsAndContinuations() throws {
        let parsed = try #require(Frontmatter.parse(Self.lines("""
        ---
        tools: [alpha, "beta",  , gamma]
        half: [a, b
        triggers:

          - one
          # comment
          - two
          - three

          not a list item
        summary: a plain value
          continued here
        orphan:
        : dropped
        # comment line
        just text
        trailing:
        ---
        body
        """)))
        let entries = Dictionary(uniqueKeysWithValues: parsed.entries.map { ($0.key, $0.value) })
        #expect(entries["tools"] == "alpha\nbeta\ngamma")
        #expect(entries["half"] == "[a, b")
        #expect(entries["triggers"] == "one\ntwo\nthree")
        #expect(entries["summary"] == "a plain value continued here")
        #expect(entries["orphan"] == "")
        #expect(entries["trailing"] == "")
        #expect(!entries.keys.contains(""))
    }

    @Test("parse: indented empty key before a shallower list item is not a block sequence")
    func parseIndentedKeyBeforeShallowerList() throws {
        let parsed = try #require(Frontmatter.parse(Self.lines("""
        ---
          nested:
        - item
        ---
        """)))
        #expect(parsed.entries.map(\.key) == ["nested"])
        #expect(parsed.entries.first?.value == "")
    }

    @Test("parse: unterminated block reads to end of file")
    func parseUnterminated() throws {
        let parsed = try #require(Frontmatter.parse(Self.lines("---\nname: x\ntrailing:")))
        #expect(parsed.entries.map(\.key) == ["name", "trailing"])
        #expect(parsed.consumed == 3)
    }

    @Test("an empty frontmatter name falls back to the entry workflow name")
    func emptyNameFallsBackToEntry() throws {
        let file = try MeridianParser(symbols: SymbolTable())
            .parse("---\nname:\n---\n\ncomplete.\n", file: "empty-name.meri")
        #expect(file.metadata?["name"] == "")
        #expect(file.workflows.first?.pattern.displayText == "entry")
    }
}
