import Testing
@testable import MeridianCore

@Suite("Wave 7 verbalizer cookbook forms")
struct VerbalizerCookbookTests {
    @Test("COOK-comparison canonical form round trips")
    func cookComparison() throws {
        try assertCookbook("""
        To check a page:
          if the page's summary equals "ready",
            complete with reason "ready".
        """)
    }

    @Test("COOK-04 boolean canonical form round trips")
    func cookBoolean() throws {
        try assertCookbook("""
        To check a score:
          bind score = 3.
          if score is at least 2 and score is at most 5,
            complete with reason "inside".
        """)
    }

    @Test("COOK-definition canonical form round trips")
    func cookDefinition() throws {
        try assertCookbook("""
        Definition: a page is stale if its summary is empty.

        To review a page:
          if the page is stale,
            complete with reason "stale".
        """)
    }

    @Test("COOK-quantifier canonical form round trips")
    func cookQuantifier() throws {
        try assertCookbook("""
        To audit pages:
          if at least 2 pages whose status is "published" have a summary,
            complete with reason "enough".
        """)
    }

    @Test("COOK-wait canonical form round trips")
    func cookWait() throws {
        try assertCookbook("""
        To pause:
          wait 2 seconds.
          complete.
        """)
    }

    @Test("COOK-recover canonical form round trips")
    func cookRecover() throws {
        try assertCookbook("""
        To recover a tool call:
          invoke demo tool with value = 1.
          recover from "demo.failure":
            complete with reason "recovered".
        """)
    }

    @Test("COOK-13 branch canonical form round trips")
    func cookBranch() throws {
        try assertCookbook("""
        To branch:
          bind score = 1.
          if score equals 1,
            complete with reason "one".
          otherwise,
            complete with reason "other".
        """)
    }

    @Test("COOK-13 unknown-arm canonical form round trips")
    func cookBranchUnknownArm() throws {
        try assertCookbook("""
        Definition: a service is stale if the deploy step has ever failed.

        To inspect a service:
          if the service is stale since the last deploy step succeeded,
            complete with reason "true".
          if it is unknown whether:
            complete with reason "unknown".
          otherwise,
            complete with reason "false".
        """)
    }

    @Test("COOK-let-bind canonical form round trips")
    func cookLetBind() throws {
        try assertCookbook("""
        To bind values:
          let the posture be "halt".
          rebind posture = "watch".
          complete.
        """)
    }

    @Test("COOK-14 compound note canonical form round trips")
    func cookCompoundNote() throws {
        try assertCookbook("""
        To reconcile a batch:
          let the receipt trailer be "".
          proceed, and note "thin history" in the receipt trailer.
          complete.
        """)
    }

    @Test("COOK-description canonical form round trips")
    func cookDescription() throws {
        try assertCookbook("""
        To describe pages:
          bind candidates = the first 2 pages whose status is "draft" sorted by status, ascending.
          complete.
        """)
    }

    @Test("COOK-template canonical form round trips")
    func cookTemplate() throws {
        try assertCookbook("""
        To render a report:
          bind score = 3.
          bind report =
            ```
            [if score is at least 2]ok[otherwise]low[end if]
            {{ score as a integer }}
            ```
          emit report.rendered with body = report.
        """)
    }

    @Test("COOK-assert-otherwise canonical form round trips")
    func cookAssertOtherwise() throws {
        try assertCookbook("""
        To guard a page:
          assert the page's status equals "open" otherwise:
            complete with reason "closed".
        """)
    }

    @Test("COOK-wait-approval canonical form round trips")
    func cookWaitApproval() throws {
        try assertCookbook("""
        To approve a page:
          wait for approval of the page from an account manager.
          complete.
        """)
    }

    @Test("COOK-wait-event-matching canonical form round trips")
    func cookWaitEventMatching() throws {
        try assertCookbook("""
        To watch a page:
          wait for event page.updated matching the page's status equals "ready".
          complete.
        """)
    }

    @Test("COOK-choice-gate canonical form round trips")
    func cookChoiceGate() throws {
        try assertCookbook("""
        To triage a page:
          ask the user to choose between "admit", "observe", "discharge".
          complete.
        """)
    }

    @Test("COOK-background-shortcut canonical form round trips")
    func cookBackgroundShortcut() throws {
        try assertCookbook("""
        To background a page:
          in the background, complete.
        """)
    }

    @Test("COOK-18 ever canonical form round trips")
    func cookTemporalEver() throws {
        try assertCookbook("""
        To inspect traces:
          if the deploy step has ever failed,
            complete with reason "ever".
        """)
    }

    @Test("COOK-18 within-window canonical form round trips")
    func cookTemporalWithin() throws {
        try assertCookbook("""
        To inspect traces:
          if the deploy step has failed within the last 7 days,
            complete with reason "window".
        """)
    }

    @Test("COOK-18 count-in-window canonical form round trips")
    func cookTemporalCount() throws {
        try assertCookbook("""
        To inspect traces:
          if the deploy step has failed at least 2 times within the last 7 days,
            complete with reason "count".
        """)
    }

    @Test("COOK-18 in-a-row canonical form round trips")
    func cookTemporalInARow() throws {
        try assertCookbook("""
        To inspect traces:
          if the deploy step has failed 2 times in a row,
            complete with reason "row".
        """)
    }

    @Test("COOK-18 since-the-last canonical form round trips")
    func cookTemporalSince() throws {
        try assertCookbook("""
        Definition: a service is stale if the deploy step has ever failed.

        To inspect a service:
          if the service is stale since the last deploy step succeeded,
            complete with reason "stable".
          otherwise,
            complete with reason "fallback".
        """)
    }

    @Test("COOK-19 keyed temporal adjective canonical form round trips")
    func cookTemporalKeyedAdjective() throws {
        try assertCookbook("""
        Definition: a service is flaky if the deploy step has failed at least 2 times within the last 7 days.

        To inspect a service:
          if the service is flaky,
            complete with reason "watch".
          if it is unknown whether:
            complete with reason "unknown".
          otherwise,
            complete with reason "ok".
        """)
    }

    @Test("COOK-STAT statistical canonical form round trips")
    func cookStatistical() throws {
        let source = """
        ---
        vocabulary: trace.merconfig
        ---
        To inspect traces:
          if the deploy step succeeds in at least 90% of runs within the last 7 days,
            complete with reason "stable".
          otherwise,
            complete with reason "fallback".
        """
        let vocab = Compiler.VocabularyInput(
            name: "trace",
            file: "trace.merconfig",
            source: """
            === trace ===
            usually at least: 90%
            """
        )
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(source, vocabularies: [vocab])
        VerbalizerTestSupport.assertNoUnresolved(first, context: "cookbook source")
        VerbalizerTestSupport.assertNoUnresolved(second, context: "cookbook canonical")
        #expect(canonical.contains("at least 90% of runs within the last 604800 seconds"),
                Comment(rawValue: canonical))
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows),
                Comment(rawValue: "Cookbook round trip failed:\n\(VerbalizerTestSupport.snippet(canonical))"))
    }

    @Test("SEM_6_01 usually and rarely verbalize numerically")
    func sem601UsuallyRarelyVerbalizeNumerically() throws {
        let vocab = Compiler.VocabularyInput(
            name: "trace",
            file: "trace.merconfig",
            source: """
            === trace ===
            usually at least: 85%
            rarely at most: 15%
            """
        )
        let source = """
        ---
        vocabulary: trace.merconfig
        ---
        To inspect traces:
          if the deploy step usually succeeds,
            complete with reason "steady".
          otherwise,
            complete with reason "not-steady".
          if the deploy step rarely fails,
            complete with reason "rare".
          otherwise,
            complete with reason "not-rare".
        """
        let (_, canonical, _) = try VerbalizerTestSupport.canonicalRoundTrip(source, vocabularies: [vocab])
        #expect(canonical.contains("at least 85% of runs"), Comment(rawValue: canonical))
        #expect(canonical.contains("at most 15% of runs"), Comment(rawValue: canonical))
    }

    @Test("COOK-northstar-definition-and-judgment gallery lines round trip")
    func cookNorthstarGallery() throws {
        // Gallery lines adapted from MERIDIAN_NORTHSTAR_EXAMPLE.md (design doc
        // is read-only; these COOK fixtures keep the evidence matrix honest).
        try assertCookbook("""
        Definition: a page is stale if its summary is empty.

        To decide posture for a page:
          if the page is stale,
            let the posture be "halt".
          otherwise,
            let the posture be "proceed".
          use judgment to compose the status narrative:
            Weigh stability against urgency.
          complete.
        """)
    }

    private func assertCookbook(_ body: String) throws {
        let source = """
        ---
        vocabulary: test.merconfig
        ---
        \(body)
        """
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(source)
        VerbalizerTestSupport.assertNoUnresolved(first, context: "cookbook source")
        VerbalizerTestSupport.assertNoUnresolved(second, context: "cookbook canonical")
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows),
                Comment(rawValue: "Cookbook round trip failed:\n\(VerbalizerTestSupport.snippet(canonical))"))
        #expect(VerbalizerTestSupport.definitionInfosEqual(first.loweredDefinitions, second.loweredDefinitions),
                Comment(rawValue: "Cookbook definitions changed:\n\(VerbalizerTestSupport.snippet(canonical))"))
    }
}

@Suite("COOK statistical")
struct StatisticalCookbookTests {
    @Test("COOK-STAT statistical canonical form round trips")
    func cookStatistical() throws {
        let source = """
        ---
        vocabulary: trace.merconfig
        ---
        To inspect traces:
          if the deploy step succeeds in at least 90% of runs within the last 7 days,
            complete with reason "stable".
          otherwise,
            complete with reason "fallback".
        """
        let vocab = Compiler.VocabularyInput(
            name: "trace",
            file: "trace.merconfig",
            source: """
            === trace ===
            usually at least: 90%
            """
        )
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(source, vocabularies: [vocab])
        VerbalizerTestSupport.assertNoUnresolved(first, context: "cookbook source")
        VerbalizerTestSupport.assertNoUnresolved(second, context: "cookbook canonical")
        #expect(canonical.contains("at least 90% of runs within the last 604800 seconds"),
                Comment(rawValue: canonical))
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows),
                Comment(rawValue: "Cookbook round trip failed:\n\(VerbalizerTestSupport.snippet(canonical))"))
    }
}
