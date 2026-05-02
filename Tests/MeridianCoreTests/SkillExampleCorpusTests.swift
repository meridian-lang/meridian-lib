import Foundation
import Testing
@testable import MeridianCore

@Suite("SKILL example corpus")
struct SkillExampleCorpusTests {

    // MARK: - Existing github-vocabulary corpus

    @Test("all SkillMD-D22 skill examples parse and lower")
    func skillExamplesParseAndLower() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let cfgSource = try String(contentsOf: root.appendingPathComponent("examples/github.merconfig"), encoding: .utf8)
        let cfg = try MerConfigParser(trace: .silent()).parse(cfgSource, file: "github.merconfig")
        let symbols = SymbolTable.build(from: cfg, sourceFile: "github.merconfig", trace: .silent())
        let names = [
            "ci_fixer",
            "code_review",
            "incident_response",
            "customer_support",
            "release_orchestrator",
            "multi_host_demo"
        ]

        for name in names {
            let url = root.appendingPathComponent("examples/skill/\(name).meridian")
            let source = try String(contentsOf: url, encoding: .utf8)
            let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse(source, file: url.path)
            let workflows = try ASTToIR(symbols: symbols, sourceFile: url.path, trace: .silent()).lower(ast)
            #expect(!workflows.isEmpty, Comment(rawValue: "Expected workflows in \(name)"))
        }
    }

    @Test("release orchestrator has deterministic-to-autonomy cross-tier nesting")
    func releaseOrchestratorCrossTierNesting() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let cfgSource = try String(contentsOf: root.appendingPathComponent("examples/github.merconfig"), encoding: .utf8)
        let cfg = try MerConfigParser(trace: .silent()).parse(cfgSource, file: "github.merconfig")
        let symbols = SymbolTable.build(from: cfg, sourceFile: "github.merconfig", trace: .silent())
        let source = try String(
            contentsOf: root.appendingPathComponent("examples/skill/release_orchestrator.meridian"),
            encoding: .utf8
        )

        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse(
            source,
            file: "examples/skill/release_orchestrator.meridian"
        )
        let workflows = try ASTToIR(
            symbols: symbols,
            sourceFile: "examples/skill/release_orchestrator.meridian",
            trace: .silent()
        ).lower(ast)

        let entry = try #require(workflows.first)
        let nestedCall = entry.body.statements.compactMap { primitive -> InvokeIR? in
            guard case .invoke(let invoke) = primitive else { return nil }
            return invoke
        }.first { $0.toolID.hasPrefix("workflow:") }

        #expect(nestedCall?.toolID == "workflow:AutonomouslyStabilizePullRequest")
        let hasAutonomousWorkflow = workflows.contains(where: { workflow in
            workflow.body.statements.contains(where: { primitive in
                guard case .proseStep(let step) = primitive else { return false }
                return step.dispatchMode == .autonomousLoop
                    && step.autonomy?.until != nil
                    && step.autonomy?.replanAfterFailures == 2
            })
        })
        #expect(hasAutonomousWorkflow)
    }

    // MARK: - Comprehensive corpus

    /// `(file stem, extension)` for every sample in the comprehensive corpus.
    /// Mixed `.meridian` / `.meri` to prove the shorter extension also works
    /// end-to-end.
    private static let comprehensiveSamples: [(name: String, ext: String)] = [
        ("security_review_triage",          "meridian"),
        ("flaky_ci_stabilizer",             "meri"),
        ("large_release_train",             "meridian"),
        ("dependency_upgrade_sweep",        "meri"),
        ("hotfix_commander",                "meridian"),
        ("review_comment_refactor",         "meri"),
        ("merge_conflict_playbook",         "meridian"),
        ("incident_pr_response",            "meri"),
        ("policy_guarded_autonomy",         "meridian"),
        ("planner_schema_validation_demo",  "meri"),
        ("customer_support_router",         "meridian"),
        ("deployment_promotion",            "meri"),
    ]

    /// Shared loader for the comprehensive vocabulary symbol table.
    private static func comprehensiveSymbols() throws -> SymbolTable {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let cfgSource = try String(
            contentsOf: root.appendingPathComponent("examples/skill/comprehensive_workflows.merconfig"),
            encoding: .utf8
        )
        let cfg = try MerConfigParser(trace: .silent()).parse(
            cfgSource,
            file: "comprehensive_workflows.merconfig"
        )
        return SymbolTable.build(
            from: cfg,
            sourceFile: "comprehensive_workflows.merconfig",
            trace: .silent()
        )
    }

    /// Lower a single sample to `[IRWorkflow]`.
    private static func lower(name: String, ext: String, symbols: SymbolTable) throws -> [IRWorkflow] {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let url = root.appendingPathComponent("examples/skill/\(name).\(ext)")
        let source = try String(contentsOf: url, encoding: .utf8)
        let file = "examples/skill/\(name).\(ext)"
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse(source, file: file)
        return try ASTToIR(symbols: symbols, sourceFile: file, trace: .silent()).lower(ast)
    }

    @Test("comprehensive vocabulary parses every section")
    func comprehensiveVocabularyParses() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let cfgSource = try String(
            contentsOf: root.appendingPathComponent("examples/skill/comprehensive_workflows.merconfig"),
            encoding: .utf8
        )
        let cfg = try MerConfigParser(trace: .silent()).parse(
            cfgSource,
            file: "comprehensive_workflows.merconfig"
        )
        #expect(!cfg.vocabulary.isEmpty, Comment(rawValue: "Expected vocabulary statements"))
        #expect(cfg.tools.count >= 30, Comment(rawValue: "Expected ~33 tool declarations, got \(cfg.tools.count)"))
        #expect(!cfg.constants.isEmpty)
        #expect(!cfg.instances.isEmpty)
    }

    @Test("every comprehensive sample parses and lowers")
    func everyComprehensiveSampleLowers() throws {
        let symbols = try Self.comprehensiveSymbols()
        for sample in Self.comprehensiveSamples {
            let workflows = try Self.lower(name: sample.name, ext: sample.ext, symbols: symbols)
            #expect(!workflows.isEmpty,
                    Comment(rawValue: "Expected workflows in \(sample.name).\(sample.ext)"))
            for w in workflows {
                #expect(!w.body.statements.isEmpty,
                        Comment(rawValue: "Workflow `\(w.name)` in \(sample.name).\(sample.ext) is empty"))
            }
        }
    }

    @Test("both .meridian and .meri extensions are exercised")
    func mixedExtensionsAreExercised() {
        let extensions = Set(Self.comprehensiveSamples.map(\.ext))
        #expect(extensions.contains("meridian"))
        #expect(extensions.contains("meri"))
    }

    // MARK: - Structural assertions per representative sample

    @Test("flaky_ci_stabilizer has bounded autonomy with until/unless and replan")
    func flakyCiStabilizerAutonomy() throws {
        let symbols = try Self.comprehensiveSymbols()
        let workflows = try Self.lower(name: "flaky_ci_stabilizer", ext: "meri", symbols: symbols)
        let autonomyStep = autonomyStep(in: workflows)
        let step = try #require(autonomyStep, "Expected an autonomous-loop ProseStepIR")
        #expect(step.dispatchMode == .autonomousLoop)
        let cfg = try #require(step.autonomy)
        #expect(cfg.until != nil, Comment(rawValue: "Expected until predicate"))
        #expect(cfg.unless != nil, Comment(rawValue: "Expected unless predicate"))
        #expect(cfg.replanAfterFailures == 2)
        #expect(cfg.maxSteps == 6)
    }

    @Test("large_release_train nests deterministic → discretion → autonomy")
    func largeReleaseTrainCrossTierNesting() throws {
        let symbols = try Self.comprehensiveSymbols()
        let workflows = try Self.lower(name: "large_release_train", ext: "meridian", symbols: symbols)
        let entry = try #require(workflows.first)

        // Deterministic outer entry must call workflow stubs (cross-tier handoff).
        let workflowCalls = entry.body.statements.compactMap { primitive -> InvokeIR? in
            guard case .invoke(let inv) = primitive,
                  inv.toolID.hasPrefix("workflow:") else { return nil }
            return inv
        }
        #expect(workflowCalls.count >= 2,
                Comment(rawValue: "Expected at least 2 workflow handoffs from the deterministic outer gate"))

        // Some sub-workflow must be a discretion plan-then-execute step.
        let hasDiscretion = workflows.contains { w in
            w.body.statements.contains { primitive in
                guard case .proseStep(let step) = primitive else { return false }
                return step.dispatchMode == .planThenExecute
            }
        }
        #expect(hasDiscretion, Comment(rawValue: "Expected at least one discretion ProseStep"))

        // Some sub-workflow must be an autonomous loop with until/unless.
        let hasAutonomy = workflows.contains { w in
            w.body.statements.contains { primitive in
                guard case .proseStep(let step) = primitive else { return false }
                return step.dispatchMode == .autonomousLoop
                    && step.autonomy?.until != nil
                    && step.autonomy?.unless != nil
            }
        }
        #expect(hasAutonomy, Comment(rawValue: "Expected at least one autonomy ProseStep with until + unless"))
    }

    @Test("dependency_upgrade_sweep keeps inline `do … and …` chain intact")
    func dependencyUpgradeSweepInlineChain() throws {
        let symbols = try Self.comprehensiveSymbols()
        let workflows = try Self.lower(name: "dependency_upgrade_sweep", ext: "meri", symbols: symbols)
        let entry = try #require(workflows.first)

        // The sweep does an `every dependency` iteration somewhere.
        let hasIteration = workflows.contains { w in
            w.body.statements.contains { primitive in
                if case .iterate = primitive { return true } else { return false }
            }
        }
        #expect(hasIteration, Comment(rawValue: "Expected an iteration primitive (every X)"))

        // The sweep recovers from any error somewhere.
        let hasRecover = workflows.contains { w in
            anyRecover(in: w.body.statements)
        }
        #expect(hasRecover, Comment(rawValue: "Expected a recover primitive"))

        // The two-element `do … with arg = X, arg = Y, and inspect …` chain
        // must lower into at least two distinct primitives in the entry body
        // (one bind-via-invoke, plus the inspect phrase invocation chain).
        // `bind X = invoke Y …` lowers to `.invoke` with `resultBinding != nil`
        // (not to `.bind`), so we count those.
        let resultBindings = entry.body.statements.reduce(into: 0) { acc, primitive in
            if case .invoke(let inv) = primitive, inv.resultBinding != nil { acc += 1 }
        }
        #expect(resultBindings >= 2,
                Comment(rawValue: "Expected at least 2 invoke-with-result-binding (outdated + test result) in entry; got \(resultBindings)"))
    }

    @Test("hotfix_commander has wait + autonomy + recover")
    func hotfixCommanderShape() throws {
        let symbols = try Self.comprehensiveSymbols()
        let workflows = try Self.lower(name: "hotfix_commander", ext: "meridian", symbols: symbols)
        let entry = try #require(workflows.first)

        // Two waits: approval + signal.
        let waitCount = entry.body.statements.reduce(into: 0) { acc, primitive in
            if case .wait = primitive { acc += 1 }
        }
        #expect(waitCount >= 2, Comment(rawValue: "Expected ≥2 wait primitives in hotfix_commander"))

        // Recover attached somewhere in the entry body.
        #expect(anyRecover(in: entry.body.statements),
                Comment(rawValue: "Expected a recover primitive in entry"))

        // Autonomous sub-workflow has unless predicate (abort guard).
        let abortGuarded = workflows.contains { w in
            w.body.statements.contains { primitive in
                guard case .proseStep(let step) = primitive else { return false }
                return step.dispatchMode == .autonomousLoop && step.autonomy?.unless != nil
            }
        }
        #expect(abortGuarded, Comment(rawValue: "Expected autonomy step with unless abort guard"))
    }

    @Test("policy_guarded_autonomy recovers from named planning failure codes")
    func policyGuardedAutonomyRecoverCodes() throws {
        let symbols = try Self.comprehensiveSymbols()
        let workflows = try Self.lower(name: "policy_guarded_autonomy", ext: "meridian", symbols: symbols)
        let names = collectRecoverNames(in: workflows)
        #expect(names.contains("planning.host_policy_denied"),
                Comment(rawValue: "Expected recover from planning.host_policy_denied; got \(names.sorted())"))
        #expect(names.contains("planning.tool_out_of_scope"),
                Comment(rawValue: "Expected recover from planning.tool_out_of_scope; got \(names.sorted())"))
    }

    @Test("planner_schema_validation_demo recovers from each schema-validation code")
    func plannerSchemaRecoverCodes() throws {
        let symbols = try Self.comprehensiveSymbols()
        let workflows = try Self.lower(name: "planner_schema_validation_demo", ext: "meri", symbols: symbols)
        let names = collectRecoverNames(in: workflows)
        for expected in [
            "planning.missing_tool_argument",
            "planning.unexpected_tool_argument",
            "planning.invalid_tool_argument_type",
            "planning.tool_not_registered",
            "planning.too_many_actions",
            "planning.max_steps_exceeded",
        ] {
            #expect(names.contains(expected),
                    Comment(rawValue: "Expected recover from \(expected) — got \(names.sorted())"))
        }
    }

    @Test("merge_conflict_playbook combines deterministic IR with discretion plan")
    func mergeConflictPlaybookShape() throws {
        let symbols = try Self.comprehensiveSymbols()
        let workflows = try Self.lower(name: "merge_conflict_playbook", ext: "meridian", symbols: symbols)
        // Should have at least one discretion ProseStepIR somewhere.
        let hasDiscretion = workflows.contains { w in
            w.body.statements.contains { primitive in
                guard case .proseStep(let step) = primitive else { return false }
                return step.dispatchMode == .planThenExecute
            }
        }
        #expect(hasDiscretion, Comment(rawValue: "Expected discretion ProseStep"))

        // Plus a branch primitive driving the mechanical sync path.
        let hasBranch = workflows.contains { w in
            w.body.statements.contains { primitive in
                if case .branch = primitive { return true } else { return false }
            }
        }
        #expect(hasBranch, Comment(rawValue: "Expected branch primitive (if merge status is behind)"))
    }

    @Test("deployment_promotion uses simultaneously: parallel block")
    func deploymentPromotionParallel() throws {
        let symbols = try Self.comprehensiveSymbols()
        let workflows = try Self.lower(name: "deployment_promotion", ext: "meri", symbols: symbols)
        let hasSimultaneously = workflows.contains { w in
            w.body.statements.contains { primitive in
                if case .simultaneously = primitive { return true } else { return false }
            }
        }
        #expect(hasSimultaneously, Comment(rawValue: "Expected simultaneously primitive"))
    }

    @Test("incident_pr_response preserves frontmatter goal metadata")
    func incidentPrResponseGoalMetadata() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let symbols = try Self.comprehensiveSymbols()
        let url = root.appendingPathComponent("examples/skill/incident_pr_response.meri")
        let source = try String(contentsOf: url, encoding: .utf8)
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse(source, file: url.path)
        let goal = ast.metadata?["goal"]
        #expect(goal != nil, Comment(rawValue: "Expected frontmatter goal to be parsed"))
        #expect(goal?.contains("paged humans") == true,
                Comment(rawValue: "Expected the goal text to be preserved verbatim"))
    }

    @Test("security_review_triage preserves markdown outline")
    func securityReviewTriageOutline() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let symbols = try Self.comprehensiveSymbols()
        let url = root.appendingPathComponent("examples/skill/security_review_triage.meridian")
        let source = try String(contentsOf: url, encoding: .utf8)
        let ast = try MeridianParser(symbols: symbols, trace: .silent()).parse(source, file: url.path)

        let titles = ast.outline.map(\.text)
        #expect(titles.contains("Open the audit trail"))
        #expect(titles.contains("Plan risky remediation under discretion"))
    }

    @Test("integration: comprehensive sample compiles end-to-end via Compiler")
    func comprehensiveSampleCompilesEndToEnd() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let cfgSource = try String(
            contentsOf: root.appendingPathComponent("examples/skill/comprehensive_workflows.merconfig"),
            encoding: .utf8
        )
        let merSource = try String(
            contentsOf: root.appendingPathComponent("examples/skill/large_release_train.meridian"),
            encoding: .utf8
        )
        // Pass the basename so the frontmatter
        // `vocabulary: comprehensive_workflows.merconfig` resolves against
        // the vocabulary input.
        let opts = Compiler.Options(emitterOptions: .init(emitSourceLineComments: false))
        let swift = try Compiler(options: opts).compile(
            meridianSource: merSource,
            meridianFile: "large_release_train.meridian",
            merconfigSource: cfgSource,
            merconfigFile: "comprehensive_workflows.merconfig"
        )
        #expect(!swift.isEmpty)
        #expect(swift.contains("public struct"),
                Comment(rawValue: "Expected generated workflow struct"))
        #expect(swift.contains("executeProsePlan") || swift.contains("executeAutonomousLoop"),
                Comment(rawValue: "Expected prose/autonomy runtime call in generated Swift"))
    }

    // MARK: - Helpers

    private func autonomyStep(in workflows: [IRWorkflow]) -> ProseStepIR? {
        for w in workflows {
            for primitive in w.body.statements {
                if case .proseStep(let step) = primitive,
                   step.dispatchMode == .autonomousLoop {
                    return step
                }
            }
        }
        return nil
    }

    /// Recursively walks an `[IRPrimitive]` block, returning every recover
    /// pattern name it finds. Includes recovers inside if/else/iterate bodies
    /// and inside other recover blocks.
    private func collectRecoverNames(in workflows: [IRWorkflow]) -> Set<String> {
        var names: Set<String> = []
        for w in workflows {
            walkBlockForRecover(w.body.statements, into: &names)
        }
        return names
    }

    private func walkBlockForRecover(_ statements: [IRPrimitive], into out: inout Set<String>) {
        for primitive in statements {
            switch primitive {
            case .recover(let rec):
                if case .named(let name) = rec.pattern {
                    // Source uses quoted string literals: strip surrounding `"…"`.
                    var stripped = name
                    if stripped.first == "\"", stripped.last == "\"", stripped.count >= 2 {
                        stripped = String(stripped.dropFirst().dropLast())
                    }
                    out.insert(stripped)
                }
                walkBlockForRecover(rec.handler.statements, into: &out)
                walkBlockForRecover(rec.attachedTo.statements, into: &out)
            case .branch(let br):
                walkBlockForRecover(br.thenBlock.statements, into: &out)
                if let elseBlock = br.elseBlock {
                    walkBlockForRecover(elseBlock.statements, into: &out)
                }
                if case .match(_, let cases) = br.condition {
                    for c in cases {
                        walkBlockForRecover(c.block.statements, into: &out)
                    }
                }
            case .iterate(let it):
                walkBlockForRecover(it.body.statements, into: &out)
            case .simultaneously(let sim):
                for branch in sim.branches {
                    walkBlockForRecover(branch.statements, into: &out)
                }
            default:
                break
            }
        }
    }

    private func anyRecover(in statements: [IRPrimitive]) -> Bool {
        for primitive in statements {
            if case .recover = primitive { return true }
            switch primitive {
            case .branch(let br):
                if anyRecover(in: br.thenBlock.statements) { return true }
                if let elseBlock = br.elseBlock,
                   anyRecover(in: elseBlock.statements) { return true }
                if case .match(_, let cases) = br.condition {
                    for c in cases where anyRecover(in: c.block.statements) { return true }
                }
            case .iterate(let it):
                if anyRecover(in: it.body.statements) { return true }
            case .simultaneously(let sim):
                for b in sim.branches where anyRecover(in: b.statements) { return true }
            default:
                continue
            }
        }
        return false
    }
}
