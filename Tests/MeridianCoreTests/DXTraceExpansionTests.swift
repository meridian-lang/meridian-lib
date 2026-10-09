import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("DX trace expansion — post-lower phases and structured output")
struct DXTraceExpansionTests {

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

    @Test("compile(_:) emits post-lower timing phases when .timing is enabled")
    func postLowerTimingPhases() throws {
        let mer = try load("order_processing.meridian")
        let cfg = try load("ecommerce.merconfig")
        let cap = ParserTrace.capturing(categories: [.timing])

        _ = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "order_processing.meridian")], vocabularies: [.init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)]))["order_processing.meridian"]!

        let joined = cap.lines().joined(separator: "\n")
        #expect(joined.contains("domainDecl:"))
        #expect(joined.contains("traceIdentity.annotate:"))
        #expect(joined.contains("normIdStamp:"))
        #expect(joined.contains("manifestRules:"))
    }

    @Test("compile(_:) emits codegen summaries for post-lower passes")
    func postLowerCodegenSummaries() throws {
        let mer = try load("order_processing.meridian")
        let cfg = try load("ecommerce.merconfig")
        let cap = ParserTrace.capturing(categories: [.codegen])

        _ = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "order_processing.meridian")], vocabularies: [.init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)]))["order_processing.meridian"]!

        let lines = cap.lines()
        #expect(lines.contains { $0.contains("domain decl:") })
        #expect(lines.contains { $0.contains("trace identity: annotated") })
        #expect(lines.contains { $0.contains("manifest rules:") })
    }

    @Test("multi-source compile mirrors single-file timing spans")
    func skillpackTimingSpans() throws {
        let cfg = """
        === vocabulary ===

        An order is a kind of thing.
        """
        let skillA = """
        To audit an order:
          complete.
        """
        let skillB = """
        To review an order:
          complete.
        """
        let cap = ParserTrace.capturing(categories: [.timing])
        let compiler = Compiler(options: .init(trace: cap.trace))
        _ = try compiler.compile(Compiler.CompilationUnit(sources: [ .init(source: skillA, file: "audit.meri"), .init(source: skillB, file: "review.meri"), ], vocabularies: [.init(name: "t", file: "t.merconfig", source: cfg)]))

        let joined = cap.lines().joined(separator: "\n")
        #expect(joined.contains("compile (2 file(s))"))
        #expect(joined.contains("parse audit.meri:"))
        #expect(joined.contains("parse review.meri:"))
        #expect(joined.contains("lower:"))
        #expect(joined.contains("── compile profile ──"))
    }

    @Test("multi-file split is traced under the codegen phase and summary")
    func multiFileCodegenTrace() throws {
        let mer = try load("order_processing.meridian")
        let cfg = try load("ecommerce.merconfig")
        let cap = ParserTrace.capturing(categories: [.timing, .codegen])
        let opts = Compiler.Options(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: cap.trace
        )
        _ = try Compiler(options: opts).compile(Compiler.CompilationUnit(
            sources: [Compiler.SourceInput(source: mer, file: "order_processing.meridian")],
            vocabularies: [.init(name: "ecommerce", file: "ecommerce.merconfig", source: cfg)]
        ))

        let lines = cap.lines()
        #expect(lines.contains { $0.contains("codegen:") })
        #expect(lines.contains { $0.contains("multi-file emit:") })
    }

    @Test("IR sidecar emission is traced under .codegen")
    func irSidecarTrace() throws {
        let mer = """
        To audit an order:
          emit "done".
          complete.
        """
        let cfg = "=== vocabulary ===\nAn order is a kind of thing.\n"
        let cap = ParserTrace.capturing(categories: [.codegen, .timing])
        let compiler = Compiler(options: .init(trace: cap.trace))
        let model = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "audit.meridian")], vocabularies: [.init(name: "t", file: "t.merconfig", source: cfg)]))["audit.meridian"]!.model
        _ = try cap.trace.run {
            try IRSidecarEmitter().emit(
                workflows: model.workflows,
                verbalizer: Verbalizer(model: model),
                sourceFile: "audit.meridian",
                swiftFile: "audit.swift",
                sourceMap: []
            )
        }

        let lines = cap.lines()
        #expect(lines.contains { $0.contains("emit IR sidecar") })
        #expect(lines.contains { $0.contains("IR sidecar:") })
        #expect(lines.contains { $0.contains("irSidecar:") })
    }

    @Test("verbalizer emits per-workflow and per-primitive spans")
    func verbalizerTraceSpans() throws {
        let mer = """
        To audit an order:
          emit "done".
          complete.
        """
        let cfg = "=== vocabulary ===\nAn order is a kind of thing.\n"
        let cap = ParserTrace.capturing(categories: [.verbalizer])
        let compiler = Compiler(options: .init(trace: cap.trace))
        let model = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "audit.meridian")], vocabularies: [.init(name: "t", file: "t.merconfig", source: cfg)]))["audit.meridian"]!.model
        _ = try cap.trace.run { try Verbalizer(model: model).verbalize() }

        let lines = cap.lines()
        #expect(lines.contains { $0.contains("workflow ") && $0.contains("▶") })
        #expect(lines.contains { $0.contains("primitive emit") })
        #expect(lines.contains { $0.contains("primitive complete") })
    }

    @Test("MeridianLinter threads trace through tokenizer and lint span")
    func linterTrace() {
        let cap = ParserTrace.capturing(categories: [.diagnostics, .tokenize])
        _ = cap.trace.run {
            MeridianLinter().lint(
                source: "please maybe resolve the comment.",
                file: "demo.meri"
            )
        }
        let lines = cap.lines()
        #expect(lines.contains { $0.hasPrefix("[diagnostics]") && $0.contains("lint demo.meri") })
        #expect(lines.contains { $0.contains("diagnostic(s)") })
    }

    @Test("jsonl compile records carry seq, corr, span, parent, cat, op, kind, msg")
    func jsonlCompileShape() throws {
        let mer = """
        To audit an order:
          complete.
        """
        let cfg = "=== vocabulary ===\nAn order is a kind of thing.\n"
        let cap = ParserTrace.capturing(categories: [.validation, .codegen])
        cap.trace.outputFormat = .jsonl

        _ = try Compiler(options: .init(trace: cap.trace)).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "audit.meridian")], vocabularies: [.init(name: "t", file: "t.merconfig", source: cfg)]))["audit.meridian"]!

        var records: [[String: Any]] = []
        for line in cap.lines() {
            let data = Data(line.utf8)
            if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                records.append(object)
            }
        }
        #expect(!records.isEmpty)
        for record in records {
            #expect(record["seq"] != nil)
            #expect(record["corr"] as? String == cap.trace.correlationID)
            #expect(record["cat"] != nil)
            #expect(record["kind"] != nil)
            #expect(record["msg"] != nil)
        }
        let open = records.first { ($0["kind"] as? String) == "open" && ($0["op"] as? String) != nil }
        #expect(open != nil)
        #expect(open?["span"] != nil)
    }

    @Test("trace redacts secrets in log messages")
    func secretRedaction() {
        let cap = ParserTrace.capturing(categories: [.lowering])
        cap.trace.log(.lowering, "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9")
        cap.trace.log(.lowering, "api_key=supersecretvalue")
        cap.trace.log(.lowering, "password: hunter2")

        let joined = cap.lines().joined(separator: "\n")
        #expect(!joined.contains("eyJhbGciOiJIUzI1NiJ9"))
        #expect(!joined.contains("supersecretvalue"))
        #expect(!joined.contains("hunter2"))
        #expect(joined.contains("<redacted>"))
    }

    @Test("jsonl trace redacts secrets in msg and op fields")
    func jsonlSecretRedaction() {
        let cap = ParserTrace.capturing(categories: [.lowering])
        cap.trace.outputFormat = .jsonl
        let token = cap.trace.openSpan(.lowering, "Bearer tok_secret_12345")
        cap.trace.log(.lowering, "secret=not-leaked")
        cap.trace.closeSpan(token)

        for line in cap.lines() {
            let data = Data(line.utf8)
            let object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
            let msg = object["msg"] as? String ?? ""
            let op = object["op"] as? String ?? ""
            #expect(!msg.contains("tok_secret_12345"))
            #expect(!msg.contains("not-leaked"))
            #expect(!op.contains("tok_secret_12345"))
            if msg.contains("secret") || op.contains("secret") {
                #expect(msg.contains("<redacted>") || op.contains("<redacted>"))
            }
        }
    }
}
