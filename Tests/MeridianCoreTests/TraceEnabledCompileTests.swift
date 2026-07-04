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
}
