import Foundation
import Testing
@testable import MeridianCore

@Suite("Multi-file Swift emit MVP")
struct MultiFileSwiftEmitTests {
    @Test("compileMultiFile splits domain and workflows")
    func compileMultiFileSplit() throws {
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
        let split = try Compiler(options: .init(trace: .silent(), emitMultiFile: true))
            .compileMultiFile(
                meridianSource: mer,
                meridianFile: "inspect.meridian",
                vocabularies: [.init(name: "t", file: "t.merconfig", source: cfg)]
            )
        #expect(split.output.domainSource.contains("struct Service"), Comment(rawValue: split.output.domainSource))
        #expect(split.output.workflowsSource.contains("struct InspectService"), Comment(rawValue: split.output.workflowsSource))
        #expect(!split.output.domainSource.contains("func run"), Comment(rawValue: "domain file has no workflow run()"))
        #expect(!split.output.workflowsSource.contains("struct Service"), Comment(rawValue: "workflows file has no domain struct"))
    }
}
