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

    @Test("COOK-boolean canonical form round trips")
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

    @Test("COOK-branch canonical form round trips")
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

    @Test("COOK-let-bind canonical form round trips")
    func cookLetBind() throws {
        try assertCookbook("""
        To bind values:
          let the posture be "halt".
          rebind posture = "watch".
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
