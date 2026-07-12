import Testing
@testable import MeridianCore
import MeridianRuntime

// MARK: - D8: `.auto` store-failure policy resolution
//
// `Runtime` treats unresolved `.auto` as fail-open, so `.auto` must resolve at
// compile time. Phase runtime-fail-closed resolves `.auto` to `.failClosed`
// unconditionally; explicit `.failOpen` / `.failClosed` are preserved.
@Suite("D8 — .auto store-failure policy resolution")
struct TraceIdentityPlannerD8Tests {

    private func configWithAutoPolicy() -> MerConfigFile {
        MerConfigFile(traceConfiguration: TraceConfigurationAST(
            storeFailurePolicy: .init(.auto, file: "t.merconfig", line: 1)
        ))
    }

    private func workflow(body: [IRPrimitive]) -> IRWorkflow {
        IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: body))
    }

    private func annotatedWorkflow(
        body: [IRPrimitive],
        sections: [SkillSectionRecord]
    ) throws -> IRWorkflow {
        let config = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: MerConfigFile(),
            skillName: "sectioned-skill",
            skillVersionHash: "version",
            workflows: [workflow(body: body)]
        )
        let annotated = try TraceIdentityPlanner.annotate(
            workflows: [workflow(body: body)],
            skillSections: sections,
            runtimeTraceConfiguration: config
        )
        return try #require(annotated.first)
    }

    @Test(".auto resolves to failClosed when no workflow has any assert at all")
    func autoResolvesToFailClosedWithNoAsserts() {
        let workflows = [workflow(body: [.complete(CompleteIR(reason: nil))])]
        let resolved = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: configWithAutoPolicy(), skillName: "s", skillVersionHash: "v", workflows: workflows
        )
        #expect(resolved.trace.storeFailurePolicy == .failClosed)
    }

    @Test(".auto resolves to failClosed when a workflow has an ordinary assert")
    func autoResolvesToFailClosedWithOrdinaryAssert() {
        let workflows = [workflow(body: [
            .assert(AssertIR(condition: .literal(.boolean(true)), monitored: false, blocking: false))
        ])]
        let resolved = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: configWithAutoPolicy(), skillName: "s", skillVersionHash: "v", workflows: workflows
        )
        #expect(resolved.trace.storeFailurePolicy == .failClosed)
    }

    @Test(".auto resolves to failClosed for a non-blocking monitored statistical assert")
    func autoResolvesToFailClosedWithNonBlockingMonitor() {
        let workflows = [workflow(body: [
            .assert(AssertIR(condition: .literal(.boolean(true)), monitored: true, cadence: .seconds(60), blocking: false))
        ])]
        let resolved = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: configWithAutoPolicy(), skillName: "s", skillVersionHash: "v", workflows: workflows
        )
        #expect(resolved.trace.storeFailurePolicy == .failClosed)
    }

    @Test(".auto resolves to failClosed when a monitored statistical assert carries the blocking flag")
    func autoResolvesToFailClosedWithBlockingMonitor() {
        let workflows = [workflow(body: [
            .assert(AssertIR(condition: .literal(.boolean(true)), monitored: true, cadence: .seconds(60), blocking: true))
        ])]
        let resolved = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: configWithAutoPolicy(), skillName: "s", skillVersionHash: "v", workflows: workflows
        )
        #expect(resolved.trace.storeFailurePolicy == .failClosed)
    }

    @Test("a blocking assert nested inside a branch/recover/iterate still resolves .auto to failClosed")
    func autoResolvesToFailClosedForNestedBlockingAssert() {
        let nestedAssert = IRBlock(statements: [
            .assert(AssertIR(condition: .literal(.boolean(true)), monitored: false, blocking: false))
        ])
        let workflows = [workflow(body: [
            .branch(BranchIR(condition: .predicate(.literal(.boolean(true))), thenBlock: nestedAssert))
        ])]
        let resolved = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: configWithAutoPolicy(), skillName: "s", skillVersionHash: "v", workflows: workflows
        )
        #expect(resolved.trace.storeFailurePolicy == .failClosed)
    }

    @Test("an explicitly declared failOpen/failClosed policy is never overridden")
    func explicitPolicyIsNotOverridden() {
        let blockingWorkflows = [workflow(body: [
            .assert(AssertIR(condition: .literal(.boolean(true)), monitored: false, blocking: false))
        ])]

        let explicitOpen = MerConfigFile(traceConfiguration: TraceConfigurationAST(
            storeFailurePolicy: .init(.failOpen, file: "t.merconfig", line: 1)
        ))
        let resolvedOpen = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: explicitOpen, skillName: "s", skillVersionHash: "v", workflows: blockingWorkflows
        )
        #expect(resolvedOpen.trace.storeFailurePolicy == .failOpen)

        let noAssertWorkflows = [workflow(body: [.complete(CompleteIR(reason: nil))])]
        let explicitClosed = MerConfigFile(traceConfiguration: TraceConfigurationAST(
            storeFailurePolicy: .init(.failClosed, file: "t.merconfig", line: 1)
        ))
        let resolvedClosed = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: explicitClosed, skillName: "s", skillVersionHash: "v", workflows: noAssertWorkflows
        )
        #expect(resolvedClosed.trace.storeFailurePolicy == .failClosed)
    }

    @Test("omitting the store failure policy entirely defaults to .auto and resolves to failClosed")
    func omittedPolicyDefaultsToAutoResolution() {
        let workflows = [workflow(body: [
            .assert(AssertIR(condition: .literal(.boolean(true)), monitored: false, blocking: false))
        ])]
        let resolved = TraceIdentityPlanner.runtimeTraceConfiguration(
            from: MerConfigFile(), skillName: "s", skillVersionHash: "v", workflows: workflows
        )
        #expect(resolved.trace.storeFailurePolicy == .failClosed)
    }

    @Test("TraceConfiguration.default uses failClosed for hosts that skip the planner")
    func traceConfigurationDefaultIsFailClosed() {
        #expect(TraceConfiguration.default.storeFailurePolicy == .failClosed)
    }

    // MARK: - Stable step section ranges

    @Test("body lines use the nearest preceding section heading")
    func bodyLinesUseSectionRanges() throws {
        let body: [IRPrimitive] = [
            .bind(BindIR(
                name: "preamble",
                expression: .literal(.number(0)),
                sourceRange: SourceRange(file: "skill.meri", line: 1, column: 1)
            )),
            .bind(BindIR(
                name: "firstCheck",
                expression: .literal(.number(1)),
                sourceRange: SourceRange(file: "skill.meri", line: 3, column: 1)
            )),
            .bind(BindIR(
                name: "lastCheck",
                expression: .literal(.number(2)),
                sourceRange: SourceRange(file: "skill.meri", line: 6, column: 1)
            )),
            .complete(CompleteIR(
                sourceRange: SourceRange(file: "skill.meri", line: 8, column: 1)
            )),
        ]
        let sections = [
            SkillSectionRecord(
                heading: "Execution Plan",
                role: "procedure",
                executes: true,
                lines: ["complete."],
                line: 7
            ),
            SkillSectionRecord(
                heading: "Validation & Safety!",
                role: "invariants",
                executes: true,
                lines: ["first check", "last check"],
                line: 2
            ),
        ]

        let annotated = try annotatedWorkflow(body: body, sections: sections)
        let paths = annotated.body.statements.compactMap { primitive -> String? in
            switch primitive {
            case .bind(let ir): return ir.stableStepPath
            case .complete(let ir): return ir.stableStepPath
            default: return nil
            }
        }

        #expect(paths.count == 4)
        #expect(paths[0].contains("/root/procedure/"))
        #expect(paths[1].contains("/validation-safety/invariants/"))
        #expect(paths[2].contains("/validation-safety/invariants/"))
        #expect(paths[3].contains("/execution-plan/procedure/"))
    }

    @Test("nested body lines retain their source section and structural role")
    func nestedBodyLinesUseSectionRange() throws {
        let branch = BranchIR(
            condition: .predicate(.literal(.boolean(true))),
            thenBlock: IRBlock(statements: [
                .complete(CompleteIR(
                    sourceRange: SourceRange(file: "skill.meri", line: 9, column: 1)
                ))
            ]),
            sourceRange: SourceRange(file: "skill.meri", line: 8, column: 1)
        )
        let sections = [
            SkillSectionRecord(
                heading: "Execution Plan",
                role: "procedure",
                executes: true,
                lines: ["if true:", "complete."],
                line: 7
            )
        ]

        let annotated = try annotatedWorkflow(body: [.branch(branch)], sections: sections)
        let annotatedBranch = try #require(annotated.body.statements.first)
        guard case .branch(let branchIR) = annotatedBranch else {
            Issue.record("Expected an annotated branch")
            return
        }
        let nested = try #require(branchIR.thenBlock.statements.first)
        guard case .complete(let completeIR) = nested else {
            Issue.record("Expected an annotated nested complete")
            return
        }

        #expect(branchIR.stableStepPath?.contains("/execution-plan/procedure/") == true)
        #expect(completeIR.stableStepPath?.contains("/execution-plan/procedure/branch.then/") == true)
    }

    @Test("inlined phrase steps use the call-site section instead of a coincident definition line")
    func inlinedPhraseUsesCallSiteSection() throws {
        let config = """
        === vocabulary ===
        A widget is a kind of thing.





        To process a widget:
          emit "processed".
        """
        let source = """
        ---
        name: section identity
        description: Exercise section-aware trace identity.
        parameters: widget
        ---
        # Section Identity
        ## Workflow
        Process the widget.
        ## Report shape (( role: template ))
        The receipt describes the processed widget.
        """

        let result = try Compiler(options: .init(trace: .silent())).compileWithManifest(
            meridianSource: source,
            meridianFile: "section-identity.meri",
            vocabularies: [
                .init(name: "section", file: "section.merconfig", source: config)
            ]
        )
        let emit = try #require(result.manifest.workflows
            .flatMap { IRWalker.flatPrimitives($0.body) }
            .compactMap { primitive -> EmitIR? in
                guard case .emit(let ir) = primitive else { return nil }
                return ir
            }
            .first)

        #expect(emit.sourceRange.startLine == 8)
        #expect(emit.stableStepPath?.contains("/workflow/procedure/") == true)
        #expect(emit.stableStepPath?.contains("/report-shape/template/") == false)
    }

    // MARK: - End-to-end: the resolved policy reaches the emitted Swift literal

    @Test("end-to-end: a skill with a blocking assert compiles with storeFailurePolicy: .failClosed")
    func compiledSkillWithBlockingAssertEmitsFailClosed() throws {
        let cfg = """
        === vocabulary ===
        A widget is a kind of thing.
        A widget has a text called the name.
        """
        let mer = """
        To process a widget:
          assert the widget's name is "ok".
          complete.
        """
        let out = try Compiler(options: .init()).compile(meridianSource: mer, merconfigSource: cfg)
        #expect(out.contains("storeFailurePolicy: .failClosed"), Comment(rawValue: out))
    }

    @Test("end-to-end: a skill with no assert at all compiles with storeFailurePolicy: .failClosed")
    func compiledSkillWithNoAssertEmitsFailClosed() throws {
        let cfg = """
        === vocabulary ===
        A widget is a kind of thing.
        A widget has a text called the name.
        """
        let mer = """
        To process a widget:
          complete.
        """
        let out = try Compiler(options: .init()).compile(meridianSource: mer, merconfigSource: cfg)
        #expect(out.contains("storeFailurePolicy: .failClosed"), Comment(rawValue: out))
    }
}
