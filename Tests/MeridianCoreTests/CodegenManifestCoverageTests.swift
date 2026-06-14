import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

@Suite("ManifestEmitter — instance properties, rules, sections")
struct ManifestEmitterCoverageTests {

    @Test("emit covers instance properties, rule entries, and skill sections")
    func fullInput() throws {
        let wf = IRWorkflow(name: "do a thing", parameters: [], body: IRBlock(statements: [.complete(CompleteIR())]))
        let inst = ManifestEmitter.InstanceManifestEntry(
            name: "stripe",
            kind: "PaymentProcessor",
            properties: ["apiKey": ManifestEmitter.PropertyManifestValue(type: "String", value: "sk_test")]
        )
        let rule = ManifestEmitter.RuleManifestEntry(
            text: "an order must be validated by a clerk before it is shipped",
            kind: "precondition",
            executes: true,
            source: ManifestEmitter.RuleManifestEntry.SourceInfo(file: "t.meridian", line: 4)
        )
        let input = ManifestEmitter.Input(
            sourceFiles: ["t.meridian"],
            workflows: [wf],
            instancesRequired: [inst],
            rules: [rule]
        )
        let json = try ManifestEmitter().emit(input)
        #expect(json.contains("\"apiKey\""))
        #expect(json.contains("sk_test"))
        #expect(json.contains("meridian_rules"))
        #expect(json.contains("\"precondition\""))
        #expect(json.contains("\"line\""))
    }
}

@Suite("DomainEmitter — unrecognized parent falls back to MeridianThing")
struct DomainEmitterParentCoverageTests {

    @Test("a kind whose parent is neither a semantic base nor a declared kind → MeridianThing")
    func unrecognizedParent() throws {
        // `gadget` is not a semantic base and is never declared, so `Widget`
        // must fall back to the `MeridianThing` marker protocol.
        let cfg = """
        === vocabulary ===
        A widget is a kind of gadget.
        A widget has a label, which is a String.

        === tools ===
        """
        let mer = """
        ---
        name: widget probe
        vocabulary: w.merconfig
        ---
        To probe a widget:
          complete.
        """
        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(includeTimestamp: false, emitSourceLineComments: false)
        )
        let swift = try Compiler(options: opts).compile(
            meridianSource: mer, meridianFile: "w.meridian",
            merconfigSource: cfg, merconfigFile: "w.merconfig")
        #expect(swift.contains("public protocol WidgetKind: MeridianThing {"),
                Comment(rawValue: swift))
    }
}
