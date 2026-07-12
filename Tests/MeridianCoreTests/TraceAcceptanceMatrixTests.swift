import Foundation
import Testing
@testable import MeridianCore

// Phase 1 observability matrix — expected compile-time trace stages for a
// successful full pipeline compile:
//   1. symbols   — vocabulary/symbol table construction
//   2. merconfig   — `.merconfig` bootstrap + lexicon merge
//   3. parse       — meridian surface parse (statement/expression arms)
//   4. lowering    — AST → IR
//   5. codegen     — IR → Swift emission
// On failure, the diagnostics stream must carry compiler error evidence.

@Suite("Trace acceptance matrix")
struct TraceAcceptanceMatrixTests {
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

    @Test("successful compile captures symbols, merconfig, parse, lowering, and codegen evidence")
    func successfulCompileStages() throws {
        let mer = try load("order_processing.meridian")
        let cfg = try load("ecommerce.merconfig")
        let cap = ParserTrace.capturing()

        let swift = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )).compile(
            meridianSource: mer,
            meridianFile: "order_processing.meridian",
            merconfigSource: cfg,
            merconfigFile: "ecommerce.merconfig"
        )

        #expect(swift.contains("struct"))
        let lines = cap.lines()
        #expect(!lines.isEmpty)
        #expect(lines.contains { $0.hasPrefix("[symbols]") }, Comment(rawValue: "missing symbols stage"))
        #expect(lines.contains { $0.hasPrefix("[merconfig]") }, Comment(rawValue: "missing merconfig stage"))
        #expect(
            lines.contains { $0.hasPrefix("[parse]") || $0.hasPrefix("[statement]") },
            Comment(rawValue: "missing parse stage")
        )
        #expect(lines.contains { $0.hasPrefix("[lowering]") }, Comment(rawValue: "missing lowering stage"))
        #expect(lines.contains { $0.hasPrefix("[codegen]") }, Comment(rawValue: "missing codegen stage"))
    }

    @Test("failed compile captures diagnostics trace evidence")
    func failedCompileDiagnostics() throws {
        let cfg = "=== vocabulary ===\nAn order is a kind of thing.\n"
        let badMer = """
        To audit an order:
          invoke totallyUnknownTool with order = the order.
        """
        let cap = ParserTrace.capturing(categories: [.diagnostics])
        let compiler = Compiler(options: .init(trace: cap.trace))

        do {
            _ = try compiler.compile(
                meridianSource: badMer,
                meridianFile: "audit.meridian",
                merconfigSource: cfg,
                merconfigFile: "audit.merconfig"
            )
            Issue.record("expected compile to fail")
        } catch {
            // expected
        }

        let lines = cap.lines()
        #expect(!lines.isEmpty, Comment(rawValue: "diagnostics stream empty on failed compile"))
        #expect(
            lines.contains { $0.hasPrefix("[diagnostics]") },
            Comment(rawValue: "missing diagnostics category evidence:\n\(lines.joined(separator: "\n"))")
        )
    }
}
