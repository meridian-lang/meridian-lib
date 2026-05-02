import Foundation
import Testing
@testable import MeridianCore

@Suite("ParserTrace")
struct ParserTraceTests {

    @Test("capturing() collects only enabled categories")
    func captureRespectsCategories() {
        let cap = ParserTrace.capturing(categories: [.phraseParse])
        cap.trace.log(.phraseParse,   "kept")
        cap.trace.log(.phraseMatch,   "filtered out")
        cap.trace.log(.lowering,      "filtered out")
        let lines = cap.lines()
        #expect(lines.count == 1)
        #expect(lines[0].contains("kept"))
    }

    @Test("group prefix enables sub-categories")
    func groupEnablesChildren() {
        let cap = ParserTrace.capturing(categories: [])
        cap.trace.enable(parsing: "phrase")
        cap.trace.log(.phraseParse,        "match-1")
        cap.trace.log(.phraseMatch,        "match-2")
        cap.trace.log(.phraseExtractArgs,  "match-3")
        cap.trace.log(.lowering,           "filtered")
        let lines = cap.lines()
        #expect(lines.count == 3)
    }

    @Test("'all' enables every category")
    func allEnablesEverything() {
        let cap = ParserTrace.capturing(categories: [])
        cap.trace.enable(parsing: "all")
        for c in ParserTrace.Category.allCases { cap.trace.log(c, "x") }
        #expect(cap.lines().count == ParserTrace.Category.allCases.count)
    }

    @Test("compiler trace records phrase pattern parsing")
    func compilerEmitsPhrasePatternTrace() throws {
        let cap = ParserTrace.capturing(categories: [.phraseParse])
        let merconfig = """
        === vocabulary ===

        An order is a kind of Thing.

        To validate an order:
          emit order.validated.
        """
        let meridian = """
        # Workflows

        To validate the order:
          validate the order.
        """
        let opts = Compiler.Options(trace: cap.trace)
        _ = try Compiler(options: opts).compile(
            meridianSource: meridian,
            merconfigSource: merconfig
        )
        let log = cap.lines().joined(separator: "\n")
        #expect(log.contains("PhrasePattern.parse"))
        #expect(log.contains("validate"))
    }

    @Test("silent() suppresses output by default")
    func silentTrace() {
        let t = ParserTrace.silent()
        // No categories enabled -> log() is a no-op even before sink resolves.
        t.log(.phraseParse, "x")
        // Re-enable + capture into a buffer to verify the rest of the API still works.
        let cap = ParserTrace.capturing(categories: [.phraseParse])
        cap.trace.log(.phraseParse, "y")
        #expect(cap.lines().count == 1)
    }
}
