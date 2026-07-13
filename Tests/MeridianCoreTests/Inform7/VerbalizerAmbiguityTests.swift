import Testing
@testable import MeridianCore

@Suite("Wave 7 verbalizer ambiguity")
struct VerbalizerAmbiguityTests {
    @Test("smoke canonical forms compile without malformed or unresolved IR")
    func smokeCanonicalFormsAreUnambiguous() throws {
        let source = """
        ---
        vocabulary: test.merconfig
        ---
        Definition: a page is stale if its summary is empty.

        To validate an order:
          bind score = 1.
          assert score equals 1.
          if score equals 1,
            invoke demo tool with value = score.
          complete.
        """

        try assertCanonicalIsUnambiguous(source, context: "smoke")
    }

    @Test("cookbook canonical forms compile without malformed or unresolved IR")
    func cookbookCanonicalFormsAreUnambiguous() throws {
        for (index, body) in cookbookSources().enumerated() {
            try assertCanonicalIsUnambiguous("""
            ---
            vocabulary: test.merconfig
            ---
            \(body)
            """, context: "cookbook-\(index)")
        }
    }

    @Test("all sample-gbrain and corpora canonical forms compile without unresolved IR")
    func corpusCanonicalFormsAreUnambiguous() throws {
        let fixtures = try VerbalizerTestSupport.sampleGbrainFixtures() + VerbalizerTestSupport.corpusFixtures()
        #expect(fixtures.count >= 100)
        var failures: [String] = []

        for fixture in fixtures {
            do {
                let source = try String(contentsOf: fixture.file, encoding: .utf8)
                let (_, canonical, reparsed) = try VerbalizerTestSupport.canonicalRoundTrip(
                    source,
                    vocabularies: fixture.vocabularies,
                    rulebooks: fixture.rulebooks,
                    file: fixture.file.lastPathComponent,
                    moduleSearchPaths: fixture.moduleSearchPaths
                )
                VerbalizerTestSupport.assertNoUnresolved(reparsed, context: fixture.displayPath)
                // Only flag IR placeholder tokens — prose may legitimately
                // contain the English word "malformed" (e.g. frontmatter_guard).
                if canonical.contains("_unresolved") || canonical.contains("malformed(") {
                    failures.append("\(fixture.displayPath): suspicious canonical text\n\(VerbalizerTestSupport.snippet(canonical))")
                }
            } catch {
                failures.append("\(fixture.displayPath): \(error)")
            }
        }

        #expect(failures.isEmpty, Comment(rawValue: "Ambiguous corpus canonical forms:\n" + failures.joined(separator: "\n\n")))
    }

    private func assertCanonicalIsUnambiguous(_ source: String, context: String) throws {
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(source)
        VerbalizerTestSupport.assertNoUnresolved(first, context: "\(context) source")
        VerbalizerTestSupport.assertNoUnresolved(second, context: "\(context) canonical")
        #expect(!canonical.localizedCaseInsensitiveContains("malformed"), Comment(rawValue: canonical))
        #expect(!canonical.contains("_unresolved"), Comment(rawValue: canonical))
        #expect(!second.workflows.isEmpty, Comment(rawValue: canonical))
    }

    private func cookbookSources() -> [String] {
        [
            """
            To check a page:
              if the page's summary equals "ready",
                complete with reason "ready".
            """,
            """
            Definition: a page is stale if its summary is empty.

            To review a page:
              if the page is stale,
                complete with reason "stale".
            """,
            """
            To audit pages:
              if no pages whose status is "draft",
                complete with reason "clean".
            """,
            """
            To pause:
              wait 2 seconds.
              complete.
            """,
            """
            To branch:
              bind score = 1.
              if score equals 1,
                complete with reason "one".
              otherwise,
                complete with reason "other".
            """,
            """
            To render a report:
              bind score = 3.
              bind report =
                ```
                [if score is at least 2]ok[otherwise]low[end if]
                {{ score as a integer }}
                ```
              emit report.rendered with body = report.
            """,
        ]
    }
}
