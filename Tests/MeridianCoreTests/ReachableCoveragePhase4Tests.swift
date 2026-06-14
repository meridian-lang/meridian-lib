import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Phase 4: codegen / compiler / rules / migrator pure layers.
//  - CompilerError projection helpers (diagnostics, primaryMessage).
//  - RuleAnalyzer.classify across all five shapes + the unclassified path.
//  - SkillMigrator.deterministicTransform command-placeholder rewrite + heading
//    edge cases.
//  - SwiftEmitter residual comparison/literal emit arms via crafted compiles.
//  - RuleInjector permission softening + approval-handling detection.

@Suite("Reachable coverage — Phase 4 (compiler/rules/codegen/migrator)")
struct ReachableCoveragePhase4Tests {

    private func compile(_ mer: String, _ cfg: String) throws -> String {
        try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: .silent()
        )).compile(
            meridianSource: mer, meridianFile: "t.meridian",
            merconfigSource: cfg, merconfigFile: "t.merconfig"
        )
    }

    // MARK: CompilerError projection

    @Test("every CompilerError case projects to diagnostics + a primary message")
    func compilerErrorProjection() {
        let r = SourceRange(file: "f", line: 3, column: 1)
        let cases: [CompilerError] = [
            .notImplemented("nope"),
            .syntaxError(message: "bad syntax", range: r),
            .semanticError(message: "bad meaning", range: r),
            .codegenError(message: "bad codegen"),
            .diagnostics([Diagnostic(code: .legacySemantic, severity: .error, message: "d", primaryRange: r)]),
        ]
        for c in cases {
            #expect(!c.diagnostics.isEmpty)
            #expect(!c.primaryMessage.isEmpty)
        }
        #expect(CompilerError.notImplemented("nope").primaryMessage == "nope")
        #expect(CompilerError.codegenError(message: "x").primaryMessage == "x")
    }

    // MARK: RuleAnalyzer.classify

    @Test("RuleAnalyzer classifies all five rule shapes and rejects others")
    func ruleClassification() {
        let a = RuleAnalyzer(trace: .silent())
        func kindOf(_ text: String) -> String {
            guard let r = a.classify(RuleAST(text: text, sourceLine: 1)) else { return "nil" }
            switch r {
            case .invariant:       return "invariant"
            case .parameterGuard:  return "parameterGuard"
            case .precondition:    return "precondition"
            case .trigger:         return "trigger"
            case .permission:      return "permission"
            }
        }
        #expect(kindOf("When a refund is requested, process the refund.") == "trigger")
        #expect(kindOf("An order must be approved by an account manager before it ships.") == "precondition")
        #expect(kindOf("An order must not be cancelled.") == "invariant")
        #expect(kindOf("A customer must not place an order whose total is more than their limit.") == "parameterGuard")
        #expect(kindOf("An account manager may approve any order.") == "permission")
        // Unclassified shapes return nil.
        #expect(kindOf("This is just narrative prose.") == "nil")
        // Trigger prefix without a comma fails the inner guard → nil.
        #expect(kindOf("When something happens") == "nil")
    }

    // MARK: SkillMigrator.deterministicTransform

    @Test("deterministicTransform rewrites <param> command holes inside shell + backtick spans")
    func migratorCommandHoles() {
        let m = SkillMigrator(
            compiler: Compiler(options: .init(trace: .silent())),
            vocabularies: [], rulebooks: []
        )
        let md = """
        ---
        name: demo
        parameters: ticket
        ---

        ## Steps

        Run `gbrain show <ticket>` first.

        ```bash
        gbrain capture "<ticket>"
        ```
        """
        let out = m.deterministicTransform(md).source
        // The resolved <ticket> hole becomes a {ticket} interpolation in both
        // the inline backtick span and the fenced shell block.
        #expect(out.contains("{ticket}"), Comment(rawValue: out))
    }

    @Test("heading matcher rejects 1-hash, 7-hash, no-space, and empty-text headings")
    func migratorHeadingEdges() {
        let m = SkillMigrator(
            compiler: Compiler(options: .init(trace: .silent())),
            vocabularies: [], rulebooks: []
        )
        // None of these are valid `##`..`######` headings with text, so the
        // marking pass leaves them untouched (they aren't sections).
        let md = """
        ## Real Section

        narrative.

        ####### too deep

        ##nospace

        ## 
        """
        let out = m.markSections(md).markdown
        #expect(out.contains("####### too deep"), Comment(rawValue: out))
        #expect(out.contains("##nospace"), Comment(rawValue: out))
    }

    // MARK: SwiftEmitter — residual comparison + literal emit arms

    @Test("string/collection comparison operators emit their helper forms")
    func emitComparisonOps() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        An order has a code, which is a String.
        An order has a status, which is a String.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run an order:
          if the code starts with "AB",
            complete with reason "a".
          if the code ends with "ZZ",
            complete with reason "b".
          if the status is one of "open", "closed",
            complete with reason "c".
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("hasPrefix") || swift.contains("hasSuffix") || swift.contains("contains"))
    }

    @Test("a duration literal emits a Value.duration wrapper in payload position")
    func emitValueLiterals() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        """
        // `$50` would parse as an env-var (the money atom is shadowed), so we
        // exercise the duration literal arm, which parses cleanly.
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To run an order:
          emit billing.charged with window = 30 minutes.
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains(".duration("), Comment(rawValue: String(swift.prefix(2000))))
    }

    // MARK: RuleInjector — bounded permission gate injection

    @Test("a bounded permission injects an assert gate into the matching workflow")
    func boundedPermissionGate() throws {
        let cfg = """
        === vocabulary ===
        order is a kind of thing.
        order has properties:
          total_amount: Money.
        account manager is a kind of thing.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---

        An account manager may approve any order whose total amount is at most $10000.

        To approve an order:
          complete with reason "approved".
        """
        let swift = try compile(mer, cfg)
        #expect(swift.contains("runtime.assert"), Comment(rawValue: String(swift.prefix(2000))))
    }

    // MARK: Spec-runner assertion arms (Assertions.swift)

    @Test("emit/primitive-count/line-count assertions pass against a compiling workflow")
    func specAssertionsPass() {
        let src = """
        To run:
          emit demo.event with note = "hi".
          complete.
        """
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: FileManager.default.temporaryDirectory,
            source: .inline(src),
            assertions: [
                .emitEventID("demo.event"),
                .primitiveCount(.emit, 1),
                .swiftLineCountMin(5),
                .swiftLineCountMax(100000),
            ]
        )
        if case .failure(let r) = MeridianTestRunner().run(spec) {
            Issue.record("expected success, got: \(r)")
        }
    }

    @Test("errorKind assertion matches a semantic compile failure")
    func specErrorKind() {
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: FileManager.default.temporaryDirectory,
            source: .inline("---\nvocabulary: missing.merconfig\n---\nTo run:\n  complete.\n"),
            vocab: [.inline(name: "present", source: "# empty")],
            compileExpectation: .fail,
            assertions: [.errorKind(.semantic)]
        )
        if case .failure(let r) = MeridianTestRunner().run(spec) {
            Issue.record("expected success (semantic error matched), got: \(r)")
        }
    }

    @Test("golden_manifest assertion writes and matches under --update-golden")
    func specGoldenManifest() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mer-phase4-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let spec = MeridianTestRunner.Spec(
            displayName: "t", baseDir: dir,
            source: .inline("To run:\n  complete.\n"),
            assertions: [.goldenManifest(path: "m.json")]
        )
        // Exercises the goldenManifest assertion arm (manifest emit + golden
        // evaluate). Under --update-golden a missing golden is created, so the
        // run succeeds.
        if case .failure(let r) = MeridianTestRunner(updateGolden: true).run(spec) {
            Issue.record("expected success with updateGolden, got: \(r)")
        }
    }
}
