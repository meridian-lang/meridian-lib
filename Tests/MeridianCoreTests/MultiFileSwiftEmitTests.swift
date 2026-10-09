import Foundation
import Testing
@testable import MeridianCore

@Suite("Multi-file Swift emit MVP")
struct MultiFileSwiftEmitTests {
    @Test("compile(_:) splits domain and workflows")
    func compileSplit() throws {
        let cfg = """
        === vocabulary ===
        A service is a kind of thing.
        A service has a text called the name.

        === tools ===
        Demo Tool
        =========
        ~ demoTool(value: Number) : String
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To inspect a service:
          complete.
        """
        let split = try Compiler(options: .init())
            .compile(Compiler.CompilationUnit(
                sources: [Compiler.SourceInput(source: mer, file: "inspect.meridian")],
                vocabularies: [.init(name: "t", file: "t.merconfig", source: cfg)]
            ))["inspect.meridian"]!
        #expect(split.domainSwift.contains("struct Service"), Comment(rawValue: split.domainSwift))
        #expect(split.workflowsSwift.contains("struct InspectService"), Comment(rawValue: split.workflowsSwift))
        #expect(!split.domainSwift.contains("func run"), Comment(rawValue: "domain file has no workflow run()"))
        #expect(!split.workflowsSwift.contains("struct Service"), Comment(rawValue: "workflows file has no domain struct"))
    }
}
