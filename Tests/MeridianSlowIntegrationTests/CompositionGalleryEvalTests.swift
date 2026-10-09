import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - PART VII Composition Gallery — runtime evaluation over fixture traces
//
// Companion to `Tests/MeridianCoreTests/Inform7/CompositionGalleryTests.swift`
// (parse + verbalize round trip for every gallery line). Per the cookbook's own
// acceptance-suite note, lines 1, 2, 3, 7, 8, and the north-star flagship also
// get a runtime evaluation test over a fixture trace — these drive a real
// `swift build`/`swift run` through `RuntimeExecutor`/`SwiftPMPackageRunner`,
// so they live in this slow-integration target (see Tests/README.md).
//
// This suite's vocabulary intentionally splits an alert's `status` (used by
// `Definition: an alert is critical if …`) from its `freshness` (used by
// `Definition: an alert is fresh if …`) — unlike the round-trip suite's shared
// minimal vocabulary, which keys both definitions off the same `status` field.
// Under a single shared field, "at least 1 critical alert … is fresh" can
// never be satisfied (no alert can simultaneously equal two different string
// literals), so the "troubled" definition's true branch would be permanently
// unreachable here. Splitting the field is the semantically-equivalent model
// needed to actually exercise both branches at runtime.
private func meridianRepoRoot() -> URL {
    var current = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let fm = FileManager.default
    for _ in 0..<12 {
        let manifest = current.appendingPathComponent("Package.swift")
        if fm.fileExists(atPath: manifest.path),
           let text = try? String(contentsOf: manifest, encoding: .utf8),
           text.contains("name: \"meridian\"") {
            return current
        }
        current = current.deletingLastPathComponent()
    }
    Issue.record("repo root not found")
    return current
}

@Suite("PART VII — Composition Gallery runtime evaluation", .serialized)
struct CompositionGalleryEvalTests {

    static let vocabularySource = """
    === vocabulary ===
    A user is a kind of thing.
    A service is a kind of thing.
    An alert is a kind of thing.

    A service has a name, a status, and an owner.
    An alert has a name, a service name, a status, and a freshness.

    Ownership relates one user to various services.
    Ownership is read from the service's owner.
    The verb to own (it owns, it is owned) means the ownership relation.

    An escalation row is a kind of thing.
    An escalation row has a channel.

    Definition: a service is flaky if its status is "flaky".
    Definition: an alert is critical if its status is "critical".
    Definition: an alert is fresh if its freshness is "fresh".

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

    static func vocab() -> Compiler.VocabularyInput {
        Compiler.VocabularyInput(name: "gallery", file: "gallery.merconfig", source: vocabularySource)
    }

    /// Compile `body` (with the shared gallery vocabulary) to both Swift
    /// source and the lowered `IRWorkflow`s `RuntimeExecutor` needs.
    private func compile(_ body: String) throws -> (swift: String, workflows: [IRWorkflow]) {
        let source = """
        ---
        vocabulary: gallery.merconfig
        ---
        \(body)
        """
        let compiler = Compiler()
        let compiled = try compiler.compile(Compiler.CompilationUnit(
            sources: [Compiler.SourceInput(source: source, file: "gallery.meridian")],
            vocabularies: [Self.vocab()]
        ))["gallery.meridian"]!
        return (compiled.swift, compiled.model.workflows)
    }

    // MARK: - Line 1: for-each flaky-service-owned-by-user, sorted by name

    @Test("Gallery-1 eval: for-each flaky service owned by the user only visits the owned+flaky subset")
    func gallery1Eval() throws {
        let compiled = try compile("""
        To sweep a user:
          bind services = invoke service.list.
          for each flaky service owned by the user, sorted by name:
            complete with reason "found".
          complete with reason "none".
        """)

        // alice owns a healthy service and bob owns a flaky one — neither
        // qualifies (wrong status, wrong owner) — so the loop body never runs.
        let noneFailures = RuntimeExecutor(verbose: true).run(
            spec: .init(
                workflowName: compiled.workflows.first?.structName,
                inputs: [("user", "{\"id\":\"alice\"}")],
                toolStubs: [("service.list", """
                [{"id":"s1","name":"checkout","status":"healthy","owner":"alice"},
                 {"id":"s2","name":"billing","status":"flaky","owner":"bob"}]
                """)],
                expectFinalReason: "none"
            ),
            swiftSource: compiled.swift,
            workflows: compiled.workflows,
            repoRoot: meridianRepoRoot()
        )
        #expect(noneFailures.isEmpty, Comment(rawValue: noneFailures.joined(separator: "; ")))

        // alice now also owns a flaky service — the loop body runs.
        let foundFailures = RuntimeExecutor(verbose: true).run(
            spec: .init(
                workflowName: compiled.workflows.first?.structName,
                inputs: [("user", "{\"id\":\"alice\"}")],
                toolStubs: [("service.list", """
                [{"id":"s1","name":"checkout","status":"healthy","owner":"alice"},
                 {"id":"s2","name":"billing","status":"flaky","owner":"bob"},
                 {"id":"s3","name":"search","status":"flaky","owner":"alice"}]
                """)],
                expectFinalReason: "found"
            ),
            swiftSource: compiled.swift,
            workflows: compiled.workflows,
            repoRoot: meridianRepoRoot()
        )
        #expect(foundFailures.isEmpty, Comment(rawValue: foundFailures.joined(separator: "; ")))
    }

    // MARK: - Line 2: quantifier over verb clause over temporal adjective

    @Test("Gallery-2 eval: all-of-the-services-owned-by-the-user-are-flaky takes the correct three-valued branch")
    func gallery2Eval() throws {
        let compiled = try compile("""
        To sweep a user:
          bind services = invoke service.list.
          if all of the services owned by the user are flaky,
            complete with reason "all-flaky".
          otherwise,
            complete with reason "not-all-flaky".
        """)

        let allFlakyFailures = RuntimeExecutor(verbose: true).run(
            spec: .init(
                workflowName: compiled.workflows.first?.structName,
                inputs: [("user", "{\"id\":\"alice\"}")],
                toolStubs: [("service.list", """
                [{"id":"s1","name":"checkout","status":"flaky","owner":"alice"},
                 {"id":"s2","name":"billing","status":"flaky","owner":"alice"},
                 {"id":"s3","name":"search","status":"healthy","owner":"bob"}]
                """)],
                expectFinalReason: "all-flaky"
            ),
            swiftSource: compiled.swift,
            workflows: compiled.workflows,
            repoRoot: meridianRepoRoot()
        )
        #expect(allFlakyFailures.isEmpty, Comment(rawValue: allFlakyFailures.joined(separator: "; ")))

        let notAllFlakyFailures = RuntimeExecutor(verbose: true).run(
            spec: .init(
                workflowName: compiled.workflows.first?.structName,
                inputs: [("user", "{\"id\":\"alice\"}")],
                toolStubs: [("service.list", """
                [{"id":"s1","name":"checkout","status":"flaky","owner":"alice"},
                 {"id":"s2","name":"billing","status":"healthy","owner":"alice"},
                 {"id":"s3","name":"search","status":"healthy","owner":"bob"}]
                """)],
                expectFinalReason: "not-all-flaky"
            ),
            swiftSource: compiled.swift,
            workflows: compiled.workflows,
            repoRoot: meridianRepoRoot()
        )
        #expect(notAllFlakyFailures.isEmpty, Comment(rawValue: notAllFlakyFailures.joined(separator: "; ")))
    }

    // MARK: - Line 3: troubled definition (flaky + quantified fresh critical alert keyed by its name)

    @Test("Gallery-3 eval: troubled definition matches only a flaky service with a fresh critical alert of its own")
    func gallery3Eval() throws {
        let compiled = try compile("""
        Definition: a service is troubled if it is flaky and at least 1 critical alert whose service name is its name is fresh.

        To sweep a service:
          bind alerts = invoke alert.list.
          if the service is troubled,
            complete with reason "troubled".
          complete with reason "not-troubled".
        """)

        let troubledFailures = RuntimeExecutor(verbose: true).run(
            spec: .init(
                workflowName: compiled.workflows.first?.structName,
                inputs: [("service", "{\"id\":\"s1\",\"name\":\"checkout\",\"status\":\"flaky\",\"owner\":\"alice\"}")],
                toolStubs: [("alert.list", """
                [{"id":"a1","name":"a1","serviceName":"checkout","status":"critical","freshness":"fresh"},
                 {"id":"a2","name":"a2","serviceName":"billing","status":"critical","freshness":"fresh"}]
                """)],
                expectFinalReason: "troubled"
            ),
            swiftSource: compiled.swift,
            workflows: compiled.workflows,
            repoRoot: meridianRepoRoot()
        )
        #expect(troubledFailures.isEmpty, Comment(rawValue: troubledFailures.joined(separator: "; ")))

        // Same service, but its own alert is stale (not fresh) — not troubled.
        let notTroubledFailures = RuntimeExecutor(verbose: true).run(
            spec: .init(
                workflowName: compiled.workflows.first?.structName,
                inputs: [("service", "{\"id\":\"s1\",\"name\":\"checkout\",\"status\":\"flaky\",\"owner\":\"alice\"}")],
                toolStubs: [("alert.list", """
                [{"id":"a1","name":"a1","serviceName":"checkout","status":"critical","freshness":"stale"},
                 {"id":"a2","name":"a2","serviceName":"billing","status":"critical","freshness":"fresh"}]
                """)],
                expectFinalReason: "not-troubled"
            ),
            swiftSource: compiled.swift,
            workflows: compiled.workflows,
            repoRoot: meridianRepoRoot()
        )
        #expect(notTroubledFailures.isEmpty, Comment(rawValue: notTroubledFailures.joined(separator: "; ")))
    }

    // MARK: - Line 7: unknown-arm over a quantified three-valued condition
    //
    // For this vocabulary every field the quantifier keys on (`flaky`,
    // `owner`) is a deterministic string comparison, so the condition never
    // actually evaluates to `.indeterminate` and the `unknown` arm is
    // unreachable at runtime — it is still required to compile (an
    // `if …otherwise…` with an interposed unknown arm is one legal shape of
    // the three-armed branch). This eval test's job is to confirm the
    // unknown arm's presence doesn't disturb ordinary true/false dispatch.

    @Test("Gallery-7 eval: unknown-arm-over-quantified-flaky-condition still dispatches true/false correctly")
    func gallery7Eval() throws {
        let compiled = try compile("""
        To sweep a user:
          bind services = invoke service.list.
          if all of the services owned by the user are flaky,
            complete with reason "all-flaky".
          if it is unknown whether:
            complete with reason "unknown".
          otherwise,
            complete with reason "not-all-flaky".
        """)

        let allFlakyFailures = RuntimeExecutor(verbose: true).run(
            spec: .init(
                workflowName: compiled.workflows.first?.structName,
                inputs: [("user", "{\"id\":\"alice\"}")],
                toolStubs: [("service.list", """
                [{"id":"s1","name":"checkout","status":"flaky","owner":"alice"}]
                """)],
                expectFinalReason: "all-flaky"
            ),
            swiftSource: compiled.swift,
            workflows: compiled.workflows,
            repoRoot: meridianRepoRoot()
        )
        #expect(allFlakyFailures.isEmpty, Comment(rawValue: allFlakyFailures.joined(separator: "; ")))

        let notAllFlakyFailures = RuntimeExecutor(verbose: true).run(
            spec: .init(
                workflowName: compiled.workflows.first?.structName,
                inputs: [("user", "{\"id\":\"alice\"}")],
                toolStubs: [("service.list", """
                [{"id":"s1","name":"checkout","status":"healthy","owner":"alice"}]
                """)],
                expectFinalReason: "not-all-flaky"
            ),
            swiftSource: compiled.swift,
            workflows: compiled.workflows,
            repoRoot: meridianRepoRoot()
        )
        #expect(notAllFlakyFailures.isEmpty, Comment(rawValue: notAllFlakyFailures.joined(separator: "; ")))
    }

    // MARK: - Line 8: template loop + count + keyed restriction

    @Test("Gallery-8 eval: templated report over the first 3 troubled services counts each service's own fresh critical alerts")
    func gallery8Eval() throws {
        let compiled = try compile("""
        Definition: a service is troubled if it is flaky and at least 1 critical alert whose service name is its name is fresh.

        To report:
          bind services = invoke service.list.
          bind alerts = invoke alert.list.
          bind report =
            ```
            [for each service in the first 3 troubled services]{{ its name }}: {{ the number of fresh critical alerts whose service name is its name }} open[end for]
            ```
          complete.
        """)

        let failures = RuntimeExecutor(verbose: true).run(
            spec: .init(
                workflowName: compiled.workflows.first?.structName,
                toolStubs: [
                    ("service.list", """
                    [{"id":"s1","name":"checkout","status":"flaky","owner":"alice"},
                     {"id":"s2","name":"billing","status":"flaky","owner":"bob"},
                     {"id":"s3","name":"search","status":"healthy","owner":"carol"}]
                    """),
                    ("alert.list", """
                    [{"id":"a1","name":"a1","serviceName":"checkout","status":"critical","freshness":"fresh"},
                     {"id":"a2","name":"a2","serviceName":"checkout","status":"critical","freshness":"fresh"},
                     {"id":"a3","name":"a3","serviceName":"checkout","status":"critical","freshness":"stale"},
                     {"id":"a4","name":"a4","serviceName":"billing","status":"warning","freshness":"fresh"}]
                    """)
                ],
                expectFinalBindingContains: (key: "report", substring: "checkout: 2 open")
            ),
            swiftSource: compiled.swift,
            workflows: compiled.workflows,
            repoRoot: meridianRepoRoot()
        )
        #expect(failures.isEmpty, Comment(rawValue: failures.joined(separator: "; ")))
    }

    // MARK: - North-star flagship: anchor-first since-the-last-production-deploy,
    // no-critical-alert-has-occurred.
    //
    // `runtime.evaluateTrace` short-circuits to `.indeterminate` unless a real
    // trace store is attached (`Runtime.evaluateTrace` — `guard let traceStore
    // else { return .indeterminate }`), and `RuntimeExecutor`'s driver builds
    // a plain `Runtime(...)` with no trace store, so this needs a custom
    // driver — mirrors `RuntimeExecutorExtendedCoverageTests.replayForcingFunction`
    // (same repo), but wires an `InMemoryTraceStore` + `InMemoryObserver`
    // through `Runtime.Builder` instead of a `JSONLTraceStore`, so the
    // workflow's own `emit production deploy.` / `emit critical alert.`
    // statements become queryable within the same run.

    @Test("North-star eval: since-the-last-production-deploy no-critical-alert-has-occurred flips on a trailing critical alert")
    func northstarFlagshipEval() throws {
        let healthyReason = try runNorthstar(emitCriticalAlertAfterDeploy: false)
        #expect(healthyReason == "healthy", Comment(rawValue: "expected 'healthy', got '\(healthyReason ?? "(none)")'"))

        let unhealthyReason = try runNorthstar(emitCriticalAlertAfterDeploy: true)
        #expect(unhealthyReason == "unhealthy", Comment(rawValue: "expected 'unhealthy', got '\(unhealthyReason ?? "(none)")'"))
    }

    private func runNorthstar(emitCriticalAlertAfterDeploy: Bool) throws -> String? {
        let compiled = try compile("""
        To sweep:
          emit production deploy.
        \(emitCriticalAlertAfterDeploy ? "  emit critical alert.\n" : "")\
          if since the last production deploy, no critical alert has occurred,
            complete with reason "healthy".
          otherwise,
            complete with reason "unhealthy".
        """)
        guard let workflow = compiled.workflows.first else {
            Issue.record("no workflow compiled")
            return nil
        }

        let runner = try SwiftPMPackageRunner.temporary(prefix: "meridian-northstar")
        defer { try? runner.remove() }
        try runner.writeMeridianRunDriverPackage(
            repoRoot: meridianRepoRoot(),
            generatedSource: compiled.swift,
            workflow: workflow
        )
        try runner.writeFile(
            "Sources/Driver/Driver.swift",
            contents: """
            import Foundation
            import MeridianRuntime
            import GeneratedWorkflow

            @main
            struct Driver {
                static func main() async throws {
                    let runtime = try Runtime.Builder()
                        .setToolRegistry(ToolRegistry())
                        .setObserver(InMemoryObserver())
                        .setTraceStore(InMemoryTraceStore())
                        .setTraceSkillIdentity(TraceSkillIdentity(name: "Northstar", versionHash: "v1"))
                        .setRunID("northstar-run")
                        .build()
                    let result = try await \(workflow.structName)(runtime: runtime).run()
                    print("__MERIDIAN_NORTHSTAR_REASON__:\\(result.reason ?? "")")
                }
            }
            """
        )

        _ = try runner.build()
        let output = try runner.run(executable: "Driver").stdout
        let sentinel = "__MERIDIAN_NORTHSTAR_REASON__:"
        guard let line = output.components(separatedBy: "\n").first(where: { $0.hasPrefix(sentinel) }) else {
            Issue.record("driver did not print the northstar reason sentinel; output:\n\(output)")
            return nil
        }
        return String(line.dropFirst(sentinel.count))
    }
}
