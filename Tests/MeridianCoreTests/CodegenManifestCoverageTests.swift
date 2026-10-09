import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

@Suite("ManifestEmitter — instance properties, rules, sections")
struct ManifestEmitterCoverageTests {

    @Test("emit covers instance properties, rule entries, and skill sections")
    func fullInput() throws {
        let wf = IRWorkflow(
            name: "do a thing", parameters: [],
            body: IRBlock(statements: [
                .aiJudgment(AIJudgmentIR(text: "decide what to do")),
                .complete(CompleteIR()),
            ]))
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
        let cap = ParserTrace.capturing(categories: [.codegen])
        let json = try ManifestEmitter(trace: cap.trace).emit(input)
        #expect(cap.lines().contains { $0.contains("emit manifest:") })
        #expect(json.contains("\"apiKey\""))
        #expect(json.contains("sk_test"))
        #expect(json.contains("meridian_rules"))
        #expect(json.contains("\"precondition\""))
        #expect(json.contains("\"line\""))
        #expect(json.contains("judgment_steps"))
    }

    @Test("compile(_:) carries metadata, sections, tools, and deterministic JSON")
    func compileCompleteSkillSchema() throws {
        let compiler = Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false),
            trace: .silent()
        ))
        let result = try compiler.compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: """
            ---
            name: manifest probe
            description: Checks the manifest carrier.
            ---
            ## Tools Used
            - Shell command runner (shell.run)

            ## Steps
            complete.

            ## Notes (( role: reference ))
            Documentation that must stay visible.
            """, file: "manifest.meri")], vocabularies: [], rulebooks: []))["manifest.meri"]!

        #expect(result.manifest.toolsUsed == ["shell.run"])
        #expect(result.manifest.skillSections.map(\.heading).contains("Steps"))
        #expect(result.manifest.skillSections.map(\.heading).contains("Notes"))
        #expect(result.manifest.skillSections.contains { $0.heading == "Notes" && !$0.executes })

        let first = try compiler.emitManifest(result.manifest)
        let second = try compiler.emitManifest(result.manifest)
        #expect(first == second)

        let data = try #require(first.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let skill = try #require(json["meridian_skill"] as? [String: Any])
        let sections = try #require(skill["sections"] as? [[String: Any]])
        #expect(skill["name"] as? String == "manifest probe")
        #expect(skill["description"] as? String == "Checks the manifest carrier.")
        #expect(sections.contains { $0["heading"] as? String == "Notes" && $0["executes"] as? Bool == false })
    }

    @Test("compile(_:) populates kinds_used with genuine domain kinds, not synthetic parameter placeholders")
    func compileKindsUsed() throws {
        let cfg = """
        === vocabulary ===
        A widget is a kind of gadget.
        A widget has a label, which is a String.
        A crate is a kind of gadget.

        === tools ===
        """
        let mer = """
        ---
        name: widget probe
        vocabulary: w.merconfig
        ---
        To probe a widget:
          for each crate:
            complete.

        A widget with label "broken" must not be probed.
        """
        let opts = Compiler.Options(
            emitterOptions: SwiftEmitter.Options(includeTimestamp: false, emitSourceLineComments: false),
            trace: .silent()
        )
        let result = try Compiler(options: opts).compile(Compiler.CompilationUnit(sources: [Compiler.SourceInput(source: mer, file: "w.meridian")], vocabularies: [.init(name: "w.merconfig", file: "w.merconfig", source: cfg)]))["w.meridian"]!

        #expect(result.manifest.kindsUsed.contains("Widget"))

        let json = try Compiler(options: opts).emitManifest(result.manifest)
        let data = try #require(json.data(using: String.Encoding.utf8))
        let obj = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let kinds = try #require(obj["kinds_used"] as? [String])
        #expect(kinds.contains("Widget"))
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
