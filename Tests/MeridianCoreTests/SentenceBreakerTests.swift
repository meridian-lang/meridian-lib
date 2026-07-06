import Testing
@testable import MeridianCore

@Suite("Wave 5 sentence breaker FSM")
struct SentenceBreakerTests {

    @Test("normal final period is a statement terminator")
    func finalPeriod() {
        #expect(SentenceBreaker().statementText(from: "complete.") == "complete")
    }

    @Test("period inside quotes is not a terminator")
    func quotedPeriod() {
        #expect(SentenceBreaker().statementText(from: "emit note with body = \"done.\"") == "emit note with body = \"done.\"")
    }

    @Test("period inside backticks is not a terminator")
    func backtickPeriod() {
        #expect(SentenceBreaker().statementText(from: "`gbrain get page.`") == "`gbrain get page.`")
    }

    @Test("decimal point is preserved")
    func decimal() {
        #expect(SentenceBreaker().statementText(from: "bind threshold = 0.5.") == "bind threshold = 0.5")
    }

    @Test("transition table covers quote and backtick states")
    func transitionTable() {
        let breaker = SentenceBreaker()

        #expect(breaker.transition(.normal, on: .doubleQuote) == .inDoubleQuote)
        #expect(breaker.transition(.inDoubleQuote, on: .doubleQuote) == .normal)
        #expect(breaker.transition(.normal, on: .backtick) == .inBacktick)
        #expect(breaker.transition(.inBacktick, on: .backtick) == .normal)
        #expect(breaker.transition(.normal, on: .other("x")) == .normal)
    }

    @Test("tokenizer statement text uses the sentence breaker")
    func tokenizerIntegration() {
        let lines = IndentTokenizer().tokenize("""
        complete.
        emit note with body = "done."
        """).filter(\.isContent)

        #expect(lines[0].statement == "complete")
        #expect(lines[1].statement == "emit note with body = \"done.\"")
    }

    @Test("trimming a terminating period is traced under .tokenize (B1)")
    func trimTraced() {
        let cap = ParserTrace.capturing(categories: [.tokenize])
        _ = SentenceBreaker().statementText(from: "complete.", trace: cap.trace)
        #expect(cap.lines().contains { $0.contains("sentence-break: trimmed terminating period") })
    }

    @Test("no trace emitted when there is no terminating period to trim")
    func noTrimNoTrace() {
        let cap = ParserTrace.capturing(categories: [.tokenize])
        _ = SentenceBreaker().statementText(from: "emit note with body = \"done.\"", trace: cap.trace)
        #expect(cap.lines().isEmpty)
    }

    @Test("an unterminated quote/backtick that runs through the final period never re-enters .normal, so the FSM falls through its loop without trimming")
    func unterminatedQuoteFallsThroughLoop() {
        // The line ends in "." (passes the `guard line.last == "."` at the
        // top), but the opening `"` is never closed, so `state` is still
        // `.inDoubleQuote` — not `.normal` — by the time the scan reaches the
        // last character. The early-return branch inside the loop
        // (`state == .normal`) never fires, the `while` exhausts every
        // character, and `shouldTrimTerminatingPeriod` falls through to its
        // final `return false`.
        let unterminatedQuote = "\"broken quote."
        #expect(SentenceBreaker().shouldTrimTerminatingPeriod(unterminatedQuote) == false)
        #expect(SentenceBreaker().statementText(from: unterminatedQuote) == unterminatedQuote)

        let unterminatedBacktick = "`broken code."
        #expect(SentenceBreaker().shouldTrimTerminatingPeriod(unterminatedBacktick) == false)
        #expect(SentenceBreaker().statementText(from: unterminatedBacktick) == unterminatedBacktick)
    }
}
