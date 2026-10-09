import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Phase 1 (trace lever): a full-pipeline compile with EVERY ParserTrace
// category captured. This is the single highest-yield coverage lever — it
// flips the scattered `trace.log`/`trace.push` autoclosure arms that are
// otherwise dead under the default silent trace, across SymbolTable,
// MerConfigParser, the parsers, and ASTToIR's phrase-inline / lowering paths.
//
// The fixtures are the proven round-tripping showcases (`examples/relations.*`
// and `examples/order_processing.*`), so a regression here also means the rich
// relational + phrase-inlining surfaces stopped compiling.

@Suite("Trace-enabled end-to-end compile")
struct TraceEnabledCompileTests {
    private func stepPaths(in workflows: [IRWorkflow]) -> [String] {
        workflows.flatMap { workflow in
            IRWalker.flatPrimitives(workflow.body).compactMap { primitive in
                switch primitive {
                case .invoke(let ir): return ir.stableStepPath
                case .bind(let ir): return ir.stableStepPath
                case .branch(let ir): return ir.stableStepPath
                case .iterate(let ir): return ir.stableStepPath
                case .assert(let ir): return ir.stableStepPath
                case .emit(let ir): return ir.stableStepPath
                case .wait(let ir): return ir.stableStepPath
                case .commit(let ir): return ir.stableStepPath
                case .recover(let ir): return ir.stableStepPath
                case .simultaneously(let ir): return ir.stableStepPath
                case .aiJudgment(let ir): return ir.stableStepPath
                case .aiAutonomy(let ir): return ir.stableStepPath
                case .complete(let ir): return ir.stableStepPath
                }
            }
        }
    }

    private func examplesURL() -> URL {
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url.appendingPathComponent("examples")
    }

    private func load(_ name: String) throws -> String {
        try String(contentsOf: examplesURL().appendingPathComponent(name), encoding: .utf8)
    }

    @Test("relations showcase compiles with all trace categories and logs symbols/lowering/merconfig")
    func relationsTraced() throws {
        let mer = try load("relations.meridian")
        let cfg = try load("relations.merconfig")
        let cap = ParserTrace.capturing()  // all categories except .timing

        let swift = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )).compile(
            meridianSource: mer, meridianFile: "relations.meridian",
            merconfigSource: cfg, merconfigFile: "relations.merconfig"
        )

        #expect(swift.contains("MeridianWorkflow"))
        let lines = cap.lines()
        #expect(!lines.isEmpty)
        // Each of these streams is fed by a distinct cluster of trace arms.
        #expect(lines.contains { $0.hasPrefix("[symbols]") })
        #expect(lines.contains { $0.hasPrefix("[merconfig]") })
        #expect(lines.contains { $0.hasPrefix("[lowering]") })
        #expect(lines.contains { $0.hasPrefix("[parse]") || $0.hasPrefix("[statement]") })
        // The relational fixture inlines/dispatches phrases and lowers a
        // definition, so the phrase-inline + lowering arms must have fired.
        #expect(lines.contains { $0.contains("lower definition") || $0.contains("lowerWorkflow") })
    }

    @Test("order processing compiles with all trace categories and exercises phrase inlining")
    func orderProcessingTraced() throws {
        let mer = try load("order_processing.meridian")
        let cfg = try load("ecommerce.merconfig")
        let cap = ParserTrace.capturing()

        let swift = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )).compile(
            meridianSource: mer, meridianFile: "order_processing.meridian",
            merconfigSource: cfg, merconfigFile: "ecommerce.merconfig"
        )

        #expect(swift.contains("struct"))
        let lines = cap.lines()
        // order_processing bodies are phrase invocations → the phrase.inline
        // push/log arms in ASTToIR.lowerPhraseInvocation fire.
        #expect(lines.contains { $0.hasPrefix("[phrase.inline]") })
        #expect(lines.contains { $0.hasPrefix("[lowering]") })
    }

    @Test("expression production dispatch is traced under .expression (B1)")
    func expressionDispatchTraced() throws {
        let mer = try load("relations.meridian")
        let cfg = try load("relations.merconfig")
        let cap = ParserTrace.capturing(categories: [.expression])

        _ = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )).compile(
            meridianSource: mer, meridianFile: "relations.meridian",
            merconfigSource: cfg, merconfigFile: "relations.merconfig"
        )

        let lines = cap.lines()
        #expect(!lines.isEmpty)
        // At least one clause/atom production decision must have been logged
        // (the exact production that fires depends on the fixture's grammar).
        #expect(lines.contains { $0.contains("clause(") || $0.contains("atom(") })
    }

    @Test("codegen emission (domain/constants/instances/workflow) is traced under .codegen (B2)")
    func codegenTraced() throws {
        let mer = try load("order_processing.meridian")
        let cfg = try load("ecommerce.merconfig")
        let cap = ParserTrace.capturing(categories: [.codegen])

        _ = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )).compile(
            meridianSource: mer, meridianFile: "order_processing.meridian",
            merconfigSource: cfg, merconfigFile: "ecommerce.merconfig"
        )

        let lines = cap.lines()
        #expect(lines.contains { $0.contains("emit file:") })
        #expect(lines.contains { $0.contains("emit workflow") })
    }

    @Test("bootstrap sub-phases (rulebook/merconfig/lexicon merge) are timed (B2)")
    func bootstrapTimingTraced() throws {
        let mer = try load("relations.meridian")
        let cfg = try load("relations.merconfig")
        let cap = ParserTrace.capturing(categories: [.timing])

        _ = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )).compile(
            meridianSource: mer, meridianFile: "relations.meridian",
            merconfigSource: cfg, merconfigFile: "relations.merconfig"
        )

        let lines = cap.lines()
        #expect(lines.contains { $0.contains("bootstrap.merconfig") })
        #expect(lines.contains { $0.contains("bootstrap.lexiconMerge") })
        #expect(lines.contains { $0.contains("symbols:") })
        #expect(lines.contains { $0.contains("codegen:") })
    }

    @Test("skill migration is traced under .skill (B3)")
    func skillMigrationTraced() async throws {
        let cfg = """
        === vocabulary ===

        A page is a kind of thing.
        """
        let markdown = """
        ---
        name: demo skill
        ---
        ## Phases
        Say hello.
        """
        let cap = ParserTrace.capturing(categories: [.skill])
        let compiler = Compiler(options: .init(trace: cap.trace))
        let migrator = SkillMigrator(
            compiler: compiler,
            vocabularies: [.init(name: "t", file: "t.merconfig", source: cfg)]
        )
        _ = try await migrator.migrate(markdown, file: "demo.meri")

        let lines = cap.lines()
        #expect(lines.contains { $0.contains("migrate \"demo.meri\"") })
    }

    @Test("stable step paths survive unrelated edits")
    func stableStepPathsIgnoreUnrelatedInsertions() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        """
        let original = """
        To audit an order:
          let score be 1.
          emit "done".
          complete.
        """
        let edited = """
        To audit an order:
          let scratch be 0.
          let score be 1.
          emit "done".
          complete.
        """
        let compiler = Compiler(options: .init(trace: .silent()))
        let lhs = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: original, file: "audit.meridian")], vocabularies: [.init(name: "audit", file: "audit.merconfig", source: cfg)]))["audit.meridian"]!.manifest.workflows
        let rhs = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: edited, file: "audit.meridian")], vocabularies: [.init(name: "audit", file: "audit.merconfig", source: cfg)]))["audit.meridian"]!.manifest.workflows
        let lhsPaths = Set(stepPaths(in: lhs))
        let rhsPaths = Set(stepPaths(in: rhs))
        #expect(lhsPaths.isSubset(of: rhsPaths))
    }

    @Test("post-lower trace identity phases appear under .timing")
    func postLowerPhasesTraced() throws {
        let mer = try load("order_processing.meridian")
        let cfg = try load("ecommerce.merconfig")
        let cap = ParserTrace.capturing(categories: [.timing, .codegen])

        _ = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "order_processing.meridian")], vocabularies: [.init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)]))["order_processing.meridian"]!

        let joined = cap.lines().joined(separator: "\n")
        #expect(joined.contains("traceIdentity.annotate:"))
        #expect(joined.contains("trace identity: annotated"))
        #expect(joined.contains("normIdStamp:"))
        #expect(joined.contains("norm id stamp: contract asserts stamped"))
    }

    @Test("skill fingerprint ignores whitespace-only edits but changes on meaning edits")
    func skillFingerprintStability() throws {
        let cfg = "=== vocabulary ===\nAn order is a kind of thing.\n"
        let compiler = Compiler(options: .init(trace: .silent()))
        let base = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: "To audit an order:\n  complete.\n", file: "audit.meridian")], vocabularies: [.init(name: "audit", file: "audit.merconfig", source: cfg)]))["audit.meridian"]!.manifest.skillVersionHash
        let whitespace = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: "To   audit   an order:\n\n  complete.\n", file: "audit.meridian")], vocabularies: [.init(name: "audit", file: "audit.merconfig", source: cfg)]))["audit.meridian"]!.manifest.skillVersionHash
        let meaning = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: "To audit an order:\n  emit \"changed\".\n  complete.\n", file: "audit.meridian")], vocabularies: [.init(name: "audit", file: "audit.merconfig", source: cfg)]))["audit.meridian"]!.manifest.skillVersionHash
        #expect(base == whitespace)
        #expect(base != meaning)
    }
}
