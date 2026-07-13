import Foundation
import Testing
@testable import MeridianCore

/// End-to-end Wave 7 path: compile → verbalize → recompile → IR equality,
/// plus drift/fixpoint checks on real corpus and example files.
@Suite("Wave 7 verbalizer end-to-end")
struct VerbalizerEndToEndTests {

    @Test("order_processing: explain surface, synonym drift, SEM-8-03, fixpoint, Swift emit")
    func orderProcessingPipeline() throws {
        let root = VerbalizerTestSupport.repositoryRoot()
        let merURL = root.appendingPathComponent("examples/order_processing.meridian")
        let cfgURL = root.appendingPathComponent("examples/ecommerce.merconfig")
        let source = try String(contentsOf: merURL, encoding: .utf8)
        let vocab = Compiler.VocabularyInput(
            name: "ecommerce",
            file: cfgURL.lastPathComponent,
            source: try String(contentsOf: cfgURL, encoding: .utf8)
        )

        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(
            source,
            vocabularies: [vocab],
            rulebooks: [],
            file: merURL.lastPathComponent
        )

        VerbalizerTestSupport.assertNoUnresolved(first, context: "order_processing authored")
        VerbalizerTestSupport.assertNoUnresolved(second, context: "order_processing canonical")
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows))
        let fixpoint = try Verbalizer(model: second).verbalize()
        #expect(fixpoint == canonical)

        #expect(canonical.contains("To process a order placed by a customer:"))
        #expect(canonical.contains("assert not the order's total amount is more than"))
        #expect(canonical.contains("invoke validateOrder"))
        #expect(!canonical.contains("# assertion message:"))

        let drift = DriftEngine.diff(authored: source, canonical: canonical)
        #expect((drift.counts[.synonymCanonicalized] ?? 0) > 0)
        #expect(drift.hunks.count > 0)

        let zeroDrift = DriftEngine.diff(authored: canonical, canonical: canonical)
        #expect(zeroDrift.hunks.isEmpty)

        let swift = try VerbalizerTestSupport.compiler().compile(
            meridianSource: canonical,
            meridianFile: "canonical-order_processing.meridian",
            merconfigSource: vocab.source,
            merconfigFile: vocab.file
        )
        #expect(swift.contains("struct "), Comment(rawValue: "expected emitted Swift structs"))
        #expect(!swift.contains("_unresolved"))
    }

    @Test("sample-gbrain briefing: SEM-8-03, fixpoint, and zero drift on canonical")
    func briefingPipeline() throws {
        try assertNamedFixture(
            lastPathComponent: "briefing.meri",
            from: try VerbalizerTestSupport.sampleGbrainFixtures(),
            contains: ["To briefing"],
            requireMeaningBearing: false
        )
    }

    @Test("briefing + escalatepending: suppress frontmatter synthetic trigger workflows")
    func syntheticTriggerWorkflowSuppression() throws {
        let gbrain = try VerbalizerTestSupport.sampleGbrainFixtures()
        let briefing = try #require(gbrain.first { $0.file.lastPathComponent == "briefing.meri" })
        let briefingSource = try String(contentsOf: briefing.file, encoding: .utf8)
        let briefingModel = try VerbalizerTestSupport.compiler().compileToModel(
            meridianSource: briefingSource,
            meridianFile: briefing.file.lastPathComponent,
            vocabularies: briefing.vocabularies,
            rulebooks: briefing.rulebooks
        )
        #expect(!SkillFrontmatter(briefingModel.metadata).triggers.isEmpty)
        #expect(briefingModel.workflows.contains { $0.name.hasPrefix("when ") && $0.name.hasSuffix(" fires") })
        let briefingCanonical = try Verbalizer(model: briefingModel).verbalize()
        #expect(!briefingCanonical.contains("To when "), Comment(rawValue: VerbalizerTestSupport.snippet(briefingCanonical)))
        #expect(!briefingCanonical.contains("emit trigger."), Comment(rawValue: VerbalizerTestSupport.snippet(briefingCanonical)))

        let corpora = try VerbalizerTestSupport.corpusFixtures()
        let escalate = try #require(corpora.first {
            $0.displayPath.hasSuffix("corpora/governance/skills/escalatepending.meri")
        })
        let escalateSource = try String(contentsOf: escalate.file, encoding: .utf8)
        let escalateModel = try VerbalizerTestSupport.compileFixture(escalate, source: escalateSource)
        #expect(!SkillFrontmatter(escalateModel.metadata).triggers.isEmpty)
        let escalateCanonical = try Verbalizer(model: escalateModel).verbalize()
        // Frontmatter synthesizers are `when … fires`; rule-injected triggers are not.
        #expect(!escalateCanonical.contains(" fires:"),
                Comment(rawValue: VerbalizerTestSupport.snippet(escalateCanonical)))
        #expect(!escalateCanonical.contains("emit trigger.escalate"),
                Comment(rawValue: VerbalizerTestSupport.snippet(escalateCanonical)))
        // The overdue escalation line lives in a `(( role: reference ))` section,
        // so it stays documentary and must not verbalize as an executable trigger.
        #expect(!escalateCanonical.contains("To when access request is flagged as overdue:"),
                Comment(rawValue: VerbalizerTestSupport.snippet(escalateCanonical)))
        #expect(!escalateCanonical.contains("emit trigger.accessRequestIsFlaggedAs.fired"),
                Comment(rawValue: VerbalizerTestSupport.snippet(escalateCanonical)))
    }

    @Test("erp backorderreplenish: SEM-8-03 and non-empty cosmetic drift")
    func erpBackorderPipeline() throws {
        let fixtures = try VerbalizerTestSupport.corpusFixtures()
        let fixture = try #require(fixtures.first {
            $0.displayPath.hasSuffix("corpora/erp/skills/backorderreplenish.meri")
        })
        let source = try String(contentsOf: fixture.file, encoding: .utf8)

        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)

        VerbalizerTestSupport.assertNoUnresolved(first, context: fixture.displayPath)
        VerbalizerTestSupport.assertNoUnresolved(second, context: "\(fixture.displayPath) canonical")
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows))
        #expect(canonical.contains("To backorder replenish"))
        #expect(canonical.contains("invoke product.list"))

        let drift = DriftEngine.diff(authored: source, canonical: canonical)
        #expect(drift.hunks.count > 0)
        #expect((drift.counts[.synonymCanonicalized] ?? 0) >= 1)
    }

    @Test("hand-authored synonym surface round-trips and reports synonym drift")
    func authoredSynonymCosmeticDrift() throws {
        let source = """
        ---
        vocabulary: test.merconfig
        ---
        To audit a page:
          make sure the page's status equals "open".
          complete.
        """
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(source)
        VerbalizerTestSupport.assertNoUnresolved(first, context: "synonym fixture")
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows))
        #expect(canonical.contains("assert the page's status equals \"open\"."))
        #expect(!canonical.contains("make sure"))

        let drift = DriftEngine.diff(authored: source, canonical: canonical)
        #expect((drift.counts[.synonymCanonicalized] ?? 0) >= 1
                || (drift.counts[.meaningBearing] ?? 0) >= 1)
        #expect(DriftEngine.diff(authored: canonical, canonical: canonical).hunks.isEmpty)
    }

    @Test("authored aiAutonomy workflow round-trips with with-autonomy surface")
    func authoredAutonomyPipeline() throws {
        // Minimal excerpt of examples/skill/flaky_ci_stabilizer.meri — the full
        // skill uses sectioned markdown that needs role markers; the autonomy
        // header itself is the Wave 7 surface under test.
        let root = VerbalizerTestSupport.repositoryRoot()
            .appendingPathComponent("examples/skill")
        let vocabURL = root.appendingPathComponent("comprehensive_workflows.merconfig")
        let vocab = Compiler.VocabularyInput(
            name: "comprehensive_workflows",
            file: vocabURL.lastPathComponent,
            source: try String(contentsOf: vocabURL, encoding: .utf8)
        )
        let source = """
        ---
        vocabulary: comprehensive_workflows.merconfig
        ---
        To autonomously stabilize ci for a pull request, with autonomy until the ci status is passed unless the ci status is cancelled re-plan after 2 failures max 6:
          Inspect the latest failing job, apply one safe repair using apply smallest repair, push the branch, and stop once CI passes. Never roll back deployments and never call halt release from this loop.
        """

        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(
            source,
            vocabularies: [vocab],
            rulebooks: [],
            file: "flaky_ci_autonomy.meri"
        )

        VerbalizerTestSupport.assertNoUnresolved(first, context: "authored autonomy")
        VerbalizerTestSupport.assertNoUnresolved(second, context: "authored autonomy canonical")
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows))
        #expect(canonical.contains("with autonomy"), Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(try Verbalizer(model: second).verbalize() == canonical)
        #expect(DriftEngine.diff(authored: canonical, canonical: canonical).hunks.isEmpty)
    }

    @Test("docs worked example capture: SEM-8-03, omits reference prose, meaning-bearing drift")
    func captureWorkedExample() throws {
        try assertNamedFixture(
            lastPathComponent: "capture.meri",
            from: try VerbalizerTestSupport.sampleGbrainFixtures(),
            contains: ["To capture"],
            requireMeaningBearing: true,
            mustNotContain: ["## Contract (( role: reference ))"]
        )
    }

    @Test("docs worked example placeorder: SEM-8-03, authored drift, canonical fixpoint")
    func placeorderWorkedExample() throws {
        let fixtures = try VerbalizerTestSupport.corpusFixtures()
        let fixture = try #require(fixtures.first {
            $0.displayPath.hasSuffix("corpora/erp/skills/placeorder.meri")
        })
        let source = try String(contentsOf: fixture.file, encoding: .utf8)
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)
        VerbalizerTestSupport.assertNoUnresolved(first, context: fixture.displayPath)
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows))
        #expect(canonical.contains("To place order"))
        #expect(canonical.contains("invoke order.list"))
        #expect(canonical.contains("invoke inventory.reserve"), Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(canonical.contains("invoke invoice.create"), Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(canonical.contains("invoke payment.collect"), Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(canonical.contains("`ofbiz order-check --queue open --json`"),
                Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(canonical.contains("the first 3 orders sorted by total amount descending"),
                Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(try Verbalizer(model: second).verbalize() == canonical)

        let drift = DriftEngine.diff(authored: source, canonical: canonical)
        #expect(drift.hunks.count > 0)
        // Check:/Publish: expansions land in meaningBearing (not desugarExpanded).
        #expect((drift.counts[.meaningBearing] ?? 0) > 0)
        #expect((drift.counts[.synonymCanonicalized] ?? 0) > 0)
        #expect(DriftEngine.diff(authored: canonical, canonical: canonical).hunks.isEmpty)
    }

    @Test("docs worked example triagealert: judgment + signal wait survive")
    func triagealertWorkedExample() throws {
        let fixtures = try VerbalizerTestSupport.corpusFixtures()
        let fixture = try #require(fixtures.first {
            $0.displayPath.hasSuffix("corpora/incident/skills/triagealert.meri")
        })
        let source = try String(contentsOf: fixture.file, encoding: .utf8)
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)
        VerbalizerTestSupport.assertNoUnresolved(first, context: fixture.displayPath)
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows))
        #expect(canonical.contains("use judgment to"), Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(canonical.contains("wait for signal"), Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(try Verbalizer(model: second).verbalize() == canonical)
    }

    @Test("opaque-assert stress fixtures fixpoint: query, testing, fulfillorder")
    func opaqueAssertStressFixtures() throws {
        let names = [
            "sample-gbrain/skills/query.meri",
            "sample-gbrain/skills/testing.meri",
            "corpora/erp/skills/fulfillorder.meri",
        ]
        let all = try VerbalizerTestSupport.sampleGbrainFixtures() + VerbalizerTestSupport.corpusFixtures()
        var failures: [String] = []
        for name in names {
            guard let fixture = all.first(where: { $0.displayPath.hasSuffix(name) }) else {
                failures.append("missing fixture \(name)")
                continue
            }
            do {
                let source = try String(contentsOf: fixture.file, encoding: .utf8)
                let (_, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)
                #expect(!canonical.contains("# assertion message:"))
                if try Verbalizer(model: second).verbalize() != canonical {
                    failures.append("\(fixture.displayPath): not a fixpoint")
                }
            } catch {
                failures.append("\(fixture.displayPath): \(error)")
            }
        }
        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "\n")))
    }

    @Test("etl backfillpartitions: simultaneously nesting round-trips")
    func backfillSimultaneously() throws {
        let fixtures = try VerbalizerTestSupport.corpusFixtures()
        let fixture = try #require(fixtures.first {
            $0.displayPath.hasSuffix("corpora/etl/skills/backfillpartitions.meri")
        })
        let source = try String(contentsOf: fixture.file, encoding: .utf8)
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows))
        #expect(canonical.contains("simultaneously:") || canonical.contains("in the background"),
                Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(canonical.contains("sorted by updated at"),
                Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(try Verbalizer(model: second).verbalize() == canonical)
    }

    @Test("dependency_upgrade_sweep: do…and desugarExpanded drift")
    func dependencyUpgradeSweepDesugarExpanded() throws {
        let fixtures = try VerbalizerTestSupport.skillExampleFixtures()
        let fixture = try #require(fixtures.first {
            $0.file.lastPathComponent == "dependency_upgrade_sweep.meri"
        })
        let source = try String(contentsOf: fixture.file, encoding: .utf8)
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)
        VerbalizerTestSupport.assertNoUnresolved(first, context: fixture.displayPath)
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows))
        #expect(try Verbalizer(model: second).verbalize() == canonical)
        let drift = DriftEngine.diff(authored: source, canonical: canonical)
        #expect((drift.counts[.desugarExpanded] ?? 0) >= 1, Comment(rawValue: "\(drift.counts)"))
    }

    @Test("erp orderapproval: choice-gate dedup + approval wait")
    func orderapprovalChoiceGate() throws {
        try assertNamedFixture(
            lastPathComponent: "orderapproval.meri",
            from: try VerbalizerTestSupport.corpusFixtures(),
            contains: [
                "ask the user to choose between \"ship\", \"hold\"",
                "wait for approval of order from an account manager",
            ],
            requireMeaningBearing: false,
            mustNotContain: ["emit ask.choice"],
            exactContainsCount: [("ask the user to choose between \"ship\", \"hold\"", 1)]
        )
    }

    @Test("clinical triagepatient: quantifier + judgment + choice")
    func triagepatientStress() throws {
        try assertNamedFixture(
            lastPathComponent: "triagepatient.meri",
            from: try VerbalizerTestSupport.corpusFixtures(),
            contains: [
                "any vital signs is critical",
                "use judgment to",
                "ask the user to choose between \"admit\", \"observe\", \"discharge\"",
            ],
            requireMeaningBearing: false
        )
    }

    @Test("governance accessmatrix: data table survives; reference template stays omitted")
    func accessmatrixDataTableAndTemplate() throws {
        try assertNamedFixture(
            lastPathComponent: "accessmatrix.meri",
            from: try VerbalizerTestSupport.corpusFixtures(),
            contains: [
                "!!! table (( data: accessMatrix ))",
                "emit governance.audit with body = matrix report.",
                "assert matrix report contains \"access-matrix\".",
            ],
            requireMeaningBearing: false,
            mustNotContain: [
                "[if classified count is more than 0]",
                "{{ classified count }}",
            ]
        )
    }

    @Test("governance policyaudit: named data table survives; reference template stays omitted")
    func policyauditDataTableAndTemplate() throws {
        try assertNamedFixture(
            lastPathComponent: "policyaudit.meri",
            from: try VerbalizerTestSupport.corpusFixtures(),
            contains: [
                "!!! table (( data: coverageThresholds ))",
                "emit governance.report with body = audit report.",
                "assert audit report contains \"policy-audit\".",
            ],
            requireMeaningBearing: false,
            mustNotContain: [
                "[if evaluated count is more than 0]",
                "{{ evaluated count }}",
            ]
        )
    }

    @Test("incident healthchecksweep: simultaneously + background + assert synonym")
    func healthchecksweepStress() throws {
        try assertNamedFixture(
            lastPathComponent: "healthchecksweep.meri",
            from: try VerbalizerTestSupport.corpusFixtures(),
            contains: [
                "simultaneously:",
                "in the background",
                "assert all services have a name",
            ],
            requireMeaningBearing: false,
            mustNotContain: ["make sure"]
        )
        let fixtures = try VerbalizerTestSupport.corpusFixtures()
        let fixture = try #require(fixtures.first {
            $0.displayPath.hasSuffix("corpora/incident/skills/healthchecksweep.meri")
        })
        let source = try String(contentsOf: fixture.file, encoding: .utf8)
        #expect(source.contains("make sure"))
        let (_, canonical, _) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)
        let drift = DriftEngine.diff(authored: source, canonical: canonical)
        #expect((drift.counts[.synonymCanonicalized] ?? 0) >= 1
                || (drift.counts[.meaningBearing] ?? 0) >= 1)
    }

    @Test("etl dagorchestrate: event matching + signal + simultaneously")
    func dagorchestrateStress() throws {
        try assertNamedFixture(
            lastPathComponent: "dagorchestrate.meri",
            from: try VerbalizerTestSupport.corpusFixtures(),
            contains: [
                "wait for event upstream.done matching",
                "wait for signal",
                "simultaneously:",
            ],
            requireMeaningBearing: false
        )
    }

    @Test("etl pipelinetriage: decide whether + judgment from ai-discretion")
    func pipelinetriageDecideWhether() throws {
        try assertNamedFixture(
            lastPathComponent: "pipelinetriage.meri",
            from: try VerbalizerTestSupport.corpusFixtures(),
            contains: [
                "decide whether",
                "use judgment to",
                "when the pipeline run's status is \"failed\"",
            ],
            requireMeaningBearing: false
        )
    }

    @Test("governance classifyresource: decide whether + judgment")
    func classifyresourceDecideWhether() throws {
        try assertNamedFixture(
            lastPathComponent: "classifyresource.meri",
            from: try VerbalizerTestSupport.corpusFixtures(),
            contains: [
                "decide whether",
                "use judgment to",
            ],
            requireMeaningBearing: false
        )
    }

    @Test("sample-gbrain RESOLVER: quote fixpoint + ai-discretion judgment")
    func resolverQuoteAndDiscretion() throws {
        try assertNamedFixture(
            lastPathComponent: "RESOLVER.meri",
            from: try VerbalizerTestSupport.sampleGbrainFixtures(),
            contains: [
                "Daily briefing, \\\"what's happening today\\\"",
                "use judgment to",
                "skills/cold-start/SKILL.md",
            ],
            requireMeaningBearing: false
        )
    }

    @Test("sample-gbrain ingest: tools fold stable across fixpoint")
    func ingestScopedToolsFold() throws {
        let fixtures = try VerbalizerTestSupport.sampleGbrainFixtures()
        let fixture = try #require(fixtures.first { $0.file.lastPathComponent == "ingest.meri" })
        let source = try String(contentsOf: fixture.file, encoding: .utf8)
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)
        VerbalizerTestSupport.assertNoUnresolved(first, context: fixture.displayPath)
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows))
        #expect(!first.toolsUsed.isEmpty || canonical.contains("tools:"),
                Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        #expect(canonical.contains("tools:"), Comment(rawValue: VerbalizerTestSupport.snippet(canonical)))
        let fixpoint = try Verbalizer(model: second).verbalize()
        #expect(fixpoint == canonical)
        #expect(fixpoint.contains("tools:"))
    }

    @Test("planner_schema_validation_demo: recover stack + autonomy")
    func plannerSchemaValidationDemo() throws {
        try assertNamedFixture(
            lastPathComponent: "planner_schema_validation_demo.meri",
            from: try VerbalizerTestSupport.skillExampleFixtures(),
            contains: [
                "recover from \"planning.missing_tool_argument\"",
                "recover from \"planning.max_steps_exceeded\"",
                "with autonomy",
            ],
            requireMeaningBearing: false
        )
    }

    @Test("procedures purgeexpired: recover from any attached-block layout")
    func purgeexpiredRecoverFromAny() throws {
        // settlebatch's `recover from any` lives in a reference section and is
        // dropped; purgeexpired keeps the live attached-block product surface.
        try assertNamedFixture(
            lastPathComponent: "purgeexpired.meri",
            from: try VerbalizerTestSupport.corpusFixtures(),
            contains: [
                "recover from any:",
            ],
            requireMeaningBearing: false
        )
    }

    private func assertNamedFixture(
        lastPathComponent: String,
        from fixtures: [VerbalizerTestSupport.Fixture],
        contains: [String],
        requireMeaningBearing: Bool,
        mustNotContain: [String] = [],
        exactContainsCount: [(String, Int)] = []
    ) throws {
        let fixture = try #require(fixtures.first { $0.file.lastPathComponent == lastPathComponent })
        let source = try String(contentsOf: fixture.file, encoding: .utf8)
        let (first, canonical, second) = try VerbalizerTestSupport.canonicalRoundTrip(fixture, source: source)
        VerbalizerTestSupport.assertNoUnresolved(first, context: fixture.displayPath)
        VerbalizerTestSupport.assertNoUnresolved(second, context: "\(fixture.displayPath) canonical")
        #expect(IREquality.structurallyEqual(first.workflows, second.workflows),
                Comment(rawValue: VerbalizerTestSupport.firstInequalityHint(first.workflows, second.workflows)))
        #expect(try Verbalizer(model: second).verbalize() == canonical)
        for needle in contains {
            #expect(canonical.contains(needle), Comment(rawValue: "missing \(needle)\n\(VerbalizerTestSupport.snippet(canonical))"))
        }
        for needle in mustNotContain {
            #expect(!canonical.contains(needle), Comment(rawValue: "unexpected \(needle)"))
        }
        for (needle, expected) in exactContainsCount {
            let count = canonical.components(separatedBy: needle).count - 1
            #expect(count == expected, Comment(rawValue: "\(needle) count \(count) != \(expected)"))
        }
        #expect(DriftEngine.diff(authored: canonical, canonical: canonical).hunks.isEmpty)
        if requireMeaningBearing {
            let drift = DriftEngine.diff(authored: source, canonical: canonical)
            #expect((drift.counts[.meaningBearing] ?? 0) > 0)
        }
    }
}
