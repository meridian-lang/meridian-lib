import Testing
import Foundation
@testable import MeridianCore

@Suite("MeridianFormatter")
struct MeridianFormatterTests {

    @Test("format is idempotent on canonical input")
    func idempotent() {
        let canonical = """
        rule:
          do thing
          do another thing
        """
        let formatter = MeridianFormatter()
        let once  = formatter.format(canonical + "\n")
        let twice = formatter.format(once)
        #expect(once == twice)
    }

    @Test("CRLF line endings are normalised to LF")
    func crlfNormalised() {
        let crlf = "line one\r\nline two\r\n"
        let out = MeridianFormatter().format(crlf)
        #expect(!out.contains("\r"))
        #expect(out == "line one\nline two\n")
    }

    @Test("trailing whitespace on every line is stripped")
    func trailingWhitespaceStripped() {
        let dirty = "first  \nsecond\t\nthird\n"
        let out = MeridianFormatter().format(dirty)
        #expect(out == "first\nsecond\nthird\n")
    }

    @Test("leading tabs become 2-space indents (1 tab = 1 level)")
    func tabsBecomeSpaces() {
        let dirty = "\thello\n\t\tnested\n"
        let out = MeridianFormatter().format(dirty)
        #expect(out == "  hello\n    nested\n")
    }

    @Test("runs of 3+ blank lines collapse to a single blank line")
    func blankRunsCollapse() {
        let dirty = "a\n\n\n\nb\n"
        let out = MeridianFormatter().format(dirty)
        #expect(out == "a\n\nb\n")
    }

    @Test("single trailing newline is guaranteed")
    func trailingNewlineNormalised() {
        let none = "a\nb"
        let many = "a\nb\n\n\n"
        #expect(MeridianFormatter().format(none) == "a\nb\n")
        #expect(MeridianFormatter().format(many) == "a\nb\n")
    }

    @Test("isFormatted matches the round-trip semantics")
    func isFormattedMatchesRoundTrip() {
        let formatter = MeridianFormatter()
        let dirty = "x\t \n"
        let canon = formatter.format(dirty)
        #expect(!formatter.isFormatted(dirty))
        #expect(formatter.isFormatted(canon))
    }
}
