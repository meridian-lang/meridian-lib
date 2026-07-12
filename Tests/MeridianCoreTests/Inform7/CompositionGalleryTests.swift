import Testing
@testable import MeridianCore
import MeridianRuntime

// MARK: - PART VII Composition Gallery (cookbook, MERIDIAN_SYNTAX_COOKBOOK.md)
//
// "Every gallery line gets: a parse test, a verbalization round-trip test,
// and (1, 2, 3, 7, 8) an evaluation test over a fixture trace." Line 6 is a
// permission (deferred to Wave 9). This suite covers parse + verbalize round
// trip for all 7 non-deontic lines (1, 2, 3, 4, 5, 7, 8); the runtime
// evaluation tests for 1/2/3/7/8 (plus the north-star flagship) live in
// `Tests/MeridianSlowIntegrationTests/CompositionGalleryEvalTests.swift`
// since they drive a real `swift build`/`swift run` (see Tests/README.md).
//
// The cookbook's exact prose is sometimes indentation/colon shorthand rather
// than literal executable syntax — the same phenomenon already documented for
// the `if it is unknown whether ALL ...:` single-liner (MER3014 ambiguous
// anaphora forces a two-statement split). Where a literal cookbook line
// doesn't parse as written, the semantically-equivalent working idiom is used
// and the deviation is called out in a comment on that test.
@Suite("PART VII — Composition Gallery acceptance suite")
struct CompositionGalleryTests {

    static let galleryVocabularySource = """
    === vocabulary ===
    A user is a kind of thing.
    A service is a kind of thing.
    An alert is a kind of thing.

    A service has a name, a status, and an owner.
    An alert has a name, a service name, and a status.

    Ownership relates one user to various services.
    Ownership is read from the service's owner.
    The verb to own (it owns, it is owned) means the ownership relation.

    An escalation row is a kind of thing.
    An escalation row has a channel.

    Definition: a service is flaky if its status is "flaky".
    Definition: an alert is critical if its status is "critical".
    Definition: an alert is fresh if its status is "fresh".

    === tools ===
    List Services
    =============
    -- List all services.
    ~ service.list() : List

    List Alerts
    ===========
    -- List all alerts.
    ~ alert.list() : List
    """

    static func galleryVocab() -> Compiler.VocabularyInput {
        Compiler.VocabularyInput(name: "gallery", file: "gallery.merconfig", source: galleryVocabularySource)
    }

    // MARK: - Line 1: `for each flaky service owned by the user, sorted by name:`
    // (temporal adjective + verb clause + sort)

    @Test("Gallery-1 for-each flaky-service-owned-by-user sorted-by-name parses and round trips")
    func gallery1() throws {
        try assertGallery("""
        To sweep a user:
          for each flaky service owned by the user, sorted by name:
            complete.
          complete.
        """)
    }

    // MARK: - Line 2: `if all of the services that the user owns are flaky:`
    // (quantifier over verb clause over temporal adjective; three-valued)

    @Test("Gallery-2 quantifier-over-owned-services-are-flaky parses and round trips")
    func gallery2() throws {
        try assertGallery("""
        To sweep a user:
          if all of the services owned by the user are flaky,
            complete with reason "all-flaky".
          otherwise,
            complete with reason "not-all-flaky".
        """)
    }

    // MARK: - Line 3: definition composing temporal adjective, quantifier,
    // payload-style restriction, and `its` keying.

    @Test("Gallery-3 troubled definition (flaky + quantified fresh critical alert keyed by its name) parses and round trips")
    func gallery3() throws {
        try assertGallery("""
        Definition: a service is troubled if it is flaky and at least 1 critical alert whose service name is its name is fresh.

        To sweep a service:
          if the service is troubled,
            complete with reason "troubled".
          complete.
        """)
    }

    // MARK: - Line 4: superlative event-pattern subject + anchor-first
    // `since` + event negation + payload predicate.
    //
    // The superlative subject (`the most recent troubled service`) is the
    // parse-only + lint part per the cookbook: it legally parses but nests a
    // collection-ranking computation inside the anchor position, so
    // `MeridianLinter` flags it (MER6006) as a two-step candidate rather than
    // silently accepting it as idiomatic.

    @Test("Gallery-4 superlative since-the-last anchor + negated payload-predicate event pattern parses and round trips")
    func gallery4() throws {
        try assertGallery("""
        Definition: a service is troubled if it is flaky and at least 1 critical alert whose service name is its name is fresh.

        To sweep:
          if since the last deploy of the most recent troubled service, no slack.send whose channel is "#incidents" was invoked,
            complete with reason "clean".
          otherwise,
            complete with reason "leaked".
        """)
    }

    @Test("Gallery-4 superlative event anchor triggers the MER6006 lint hint")
    func gallery4Lint() throws {
        let source = """
        ---
        vocabulary: test.merconfig
        ---
        Definition: a service is troubled if it is flaky and at least 1 critical alert whose service name is its name is fresh.

        To sweep:
          if since the last deploy of the most recent troubled service, no slack.send whose channel is "#incidents" was invoked,
            complete with reason "clean".
          otherwise,
            complete with reason "leaked".
        """
        let diagnostics = MeridianLinter().lint(source: source, file: "gallery4.meridian")
        #expect(diagnostics.contains { $0.code == .lintSuperlativeEventAnchor },
                Comment(rawValue: "expected MER6006 for the superlative anchor; got \(diagnostics)"))
    }

    // MARK: - Line 5: counting over table rows with restriction.

    @Test("Gallery-5 number-of-rows-in-the-escalation-table-whose-channel parses and round trips")
    func gallery5() throws {
        try assertGallery("""
        To handle:
          let n be the number of rows in the escalation table whose channel is "#alerts".
          complete.
        """)
    }

    // MARK: - Line 7: unknown-arm over a quantified three-valued condition.
    //
    // Deviation: same as the existing `if it is unknown whether:` idiom
    // elsewhere in the suite (COOK-13 unknown-arm) — the unknown-arm attaches
    // to the *preceding* `if`, it does not itself carry the restated
    // condition (MER3014 ambiguous anaphora otherwise).

    @Test("Gallery-7 unknown-arm-over-quantified-flaky-condition parses and round trips")
    func gallery7() throws {
        try assertGallery("""
        To sweep a user:
          if all of the services owned by the user are flaky,
            complete with reason "all-flaky".
          if it is unknown whether:
            complete with reason "unknown".
          otherwise,
            complete with reason "not-all-flaky".
        """)
    }

    // MARK: - Line 8: template loop + count + keyed restriction.
    //
    // Deviation: the cookbook's `[for each of the first 3 troubled services]`
    // elides an explicit loop variable; `TemplateInterpolationParser`
    // requires the `x in collection` form (`splitForEachHeader`) to avoid
    // treating a leading `of` as the collection expression's first token.

    @Test("Gallery-8 template for-each-first-3-troubled-services with keyed count parses and round trips")
    func gallery8() throws {
        let backtick3 = String(repeating: "`", count: 3)
        try assertGallery("""
        Definition: a service is troubled if it is flaky and at least 1 critical alert whose service name is its name is fresh.

        To report:
          bind report =
            \(backtick3)
            [for each service in the first 3 troubled services]{{ its name }}: {{ the number of fresh critical alerts whose service name is its name }} open[end for]
            \(backtick3)
          complete.
        """)
    }

    // MARK: - North-star flagship (temporal core; depends on B: anchor-first
    // `since` + `occurred` + kind-noun anchor).

    @Test("North-star anchor-first since-the-last-production-deploy no-critical-alert-has-occurred parses and round trips")
    func northstarFlagship() throws {
        try assertGallery("""
        To sweep:
          if since the last production deploy, no critical alert has occurred,
            complete with reason "healthy".
          otherwise,
            complete with reason "unhealthy".
        """)
    }

    // MARK: - Helpers

    private func assertGallery(_ body: String) throws {
        let source = """
        ---
        vocabulary: gallery.merconfig
        ---
        \(body)
        """
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(
            source, vocabularies: [Self.galleryVocab()]
        )
        VerbalizerTestSupport.assertNoUnresolved(first, context: "gallery source")
        VerbalizerTestSupport.assertNoUnresolved(second, context: "gallery canonical")
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows),
                Comment(rawValue: "Gallery round trip failed:\n\(VerbalizerTestSupport.snippet(canonical))\n\(VerbalizerTestSupport.firstInequalityHint(first.workflows, second.workflows))"))
        #expect(VerbalizerTestSupport.definitionInfosEqual(first.loweredDefinitions, second.loweredDefinitions),
                Comment(rawValue: "Gallery definitions changed:\n\(VerbalizerTestSupport.snippet(canonical))"))
    }
}
