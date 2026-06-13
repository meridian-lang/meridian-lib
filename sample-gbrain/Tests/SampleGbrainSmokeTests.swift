import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// Smoke tests for the shared gbrain vocabulary + rulebook under sample-gbrain/.
// These validate that brain.merconfig and brain.merrules parse and that a
// minimal skill body compiles deterministically against them.

@Suite("sample-gbrain smoke")
struct SampleGbrainSmokeTests {

    static func sampleRoot() -> URL {
        var url = URL(fileURLWithPath: #file)
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return url.appendingPathComponent("sample-gbrain")
    }

    static func vocab() throws -> Compiler.VocabularyInput {
        let src = try String(contentsOf: sampleRoot().appendingPathComponent("brain.merconfig"), encoding: .utf8)
        return Compiler.VocabularyInput(name: "brain", file: "brain.merconfig", source: src)
    }

    static func rulebook() throws -> RulebookInput {
        let src = try String(contentsOf: sampleRoot().appendingPathComponent("brain.merrules"), encoding: .utf8)
        return RulebookInput(name: "brain", file: "brain.merrules", source: src)
    }

    @Test("brain.merconfig parses with kinds, enums, tools, and phrases")
    func vocabParses() throws {
        let v = try Self.vocab()
        let cfg = try MerConfigParser(trace: .silent()).parse(v.source, file: v.file)
        #expect(cfg.tools.count >= 15)
        let kindNames = cfg.vocabulary.compactMap { stmt -> String? in
            if case .kind(let k) = stmt { return k.name } else { return nil }
        }
        #expect(kindNames.contains("page"))
        #expect(kindNames.contains("signal"))
        let phraseCount = cfg.vocabulary.filter { if case .phrase = $0 { return true } else { return false } }.count
        #expect(phraseCount >= 10)
    }

    @Test("brain.merrules parses desugar, section-role, and convention rules")
    func rulebookParses() throws {
        let r = try Self.rulebook()
        let book = try RulebookParser(trace: .silent()).parse(r.source, file: r.file)
        #expect(book.desugars.count >= 6)
        #expect(book.sectionRoles.count >= 6)
        #expect(book.conventions.count >= 3)
        #expect(book.role(forHeading: "Contract") == .invariants)
        #expect(book.role(forHeading: "When NOT To Use") == .negativeApplicability)
        #expect(book.role(forHeading: "Phases") == .procedure)
    }

    @Test("a minimal skill body compiles against brain vocabulary + rulebook")
    func minimalSkillCompiles() throws {
        let meri = """
        ---
        name: capture demo
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        allow-fallbacks: unknown-tools
        ---
        capture the note.
        search the brain for the note.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "capture_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        #expect(out.contains("struct CaptureDemo"))
        #expect(!out.contains("_unresolved"))
    }

    @Test("skill: true lowers Contract->assert, When-To-Use->precondition, Phases->procedure")
    func sectionSemanticsLower() throws {
        let meri = """
        ---
        name: section demo
        skill: true
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        allow-fallbacks: unknown-tools
        ---
        ## Contract
        The page priority is "p0".

        ## When To Use
        The notability threshold is at least 20.

        ## Phases
        capture the input.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "section_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        #expect(out.contains("struct SectionDemo"))
        #expect(out.contains("runtime.assert"))
        #expect(out.contains("if "))
        #expect(!out.contains("_unresolved"))
    }

    @Test("fuzzy applicability condition is a hard compile error")
    func fuzzyApplicabilityErrors() throws {
        let meri = """
        ---
        name: fuzzy demo
        skill: true
        vocabulary: brain.merconfig
        ---
        ## When To Use
        The request is ambiguous.
        """
        #expect(throws: CompilerError.self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: meri,
                meridianFile: "fuzzy_demo.meri",
                vocabularies: [Self.vocab()]
            )
        }
    }

    @Test("procedure idioms: bare for-each header + Report: emit lower deterministically")
    func procedureIdiomsLower() throws {
        let meri = """
        ---
        name: procedure demo
        skill: true
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        ---
        ## Phases
        for each page:
          publish the page at the slug.
        Report: "done".
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "procedure_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        #expect(out.contains("struct ProcedureDemo"))
        #expect(out.contains("skill.report"))
        #expect(out.contains("for "))
        #expect(!out.contains("_unresolved"))
    }

    @Test("command surface: fenced bash block + inline backticked command lower to shell.run invokes")
    func commandSurfaceLowers() throws {
        let meri = """
        ---
        name: command demo
        skill: true
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        ---
        ## Phases
        ```bash
        gbrain search "acme corp"
        gbrain publish
        ```
        `gbrain doctor`
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "command_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        #expect(out.contains("struct CommandDemo"))
        #expect(out.contains("shell.run"))
        #expect(out.contains("gbrain search"))
        #expect(out.contains("gbrain publish"))
        #expect(out.contains("gbrain doctor"))
        #expect(!out.contains("_unresolved"))
    }

    @Test("explicit 'use judgment to …:' marker lowers to a prose step in a deterministic workflow")
    func explicitJudgmentLowers() throws {
        let meri = """
        ---
        name: judgment demo
        skill: true
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        ---
        ## Phases
        publish the page at the slug.
        use judgment to decide if the entity is notable:
          Weigh prominence, recency, and reliability of sources.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "judgment_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        #expect(out.contains("struct JudgmentDemo"))
        #expect(out.contains("executeProsePlan"))
        #expect(out.contains("decide if the entity is notable"))
        #expect(!out.contains("_unresolved"))
    }

    @Test("unmarked freeform prose in a deterministic workflow is a hard error")
    func unmarkedProseErrors() throws {
        let meri = """
        ---
        name: unmarked demo
        skill: true
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        ---
        ## Phases
        Ponder the deeper meaning of the request and act accordingly.
        """
        #expect(throws: (any Error).self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: meri,
                meridianFile: "unmarked_demo.meri",
                vocabularies: [Self.vocab()],
                rulebooks: [Self.rulebook()]
            )
        }
    }

    @Test("rulebook conventions inject a before-guard into matching workflows")
    func conventionsInject() throws {
        let conventionsRulebook = RulebookInput(
            name: "conv",
            file: "conv.merrules",
            source: """
            === conventions ===
            before publishing a page:
              make sure the page is ready.
            """
        )
        let meri = """
        ---
        name: publish a page
        skill: true
        vocabulary: brain.merconfig
        rulebook: conv.merrules
        ---
        ## Phases
        publish the page at the slug.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "publish_page.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [conventionsRulebook]
        )
        #expect(out.contains("struct PublishPage"))
        #expect(out.contains("ready"))
        #expect(!out.contains("_unresolved"))
    }

    @Test("frontmatter triggers synthesize typed trigger workflows that fan out events")
    func triggersSynthesize() throws {
        let meri = """
        ---
        name: trigger demo
        skill: true
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        triggers:
          - nightly
          - meeting transcript received
          - every inbound message
        ---
        ## Phases
        publish the page at the slug.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "trigger_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        #expect(out.contains("trigger.nightly.fired"))
        #expect(out.contains("\"kind\""))
        #expect(out.contains("\"schedule\""))
        #expect(out.contains("\"event\""))
        #expect(out.contains("\"ambient\""))
        #expect(!out.contains("_unresolved"))
    }

    @Test("trigger classifier maps specs to keyword/ambient/event/schedule")
    func triggerClassification() throws {
        let c = TriggerClassifier(lexicon: .default)
        #expect(c.classify("nightly", sourceLine: 1).kind == .schedule)
        #expect(c.classify("0 9 * * *", sourceLine: 1).kind == .schedule)
        #expect(c.classify("every inbound message", sourceLine: 1).kind == .ambient)
        #expect(c.classify("meeting transcript received", sourceLine: 1).kind == .event)
        #expect(c.classify("summarize my day", sourceLine: 1).kind == .keyword)
    }

    @Test("choice-gate lowers to ask.choice emit + choice wait + branch on selection")
    func choiceGateLowers() throws {
        let meri = """
        ---
        name: choice demo
        skill: true
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        ---
        ## Phases
        ask the user to choose between "proceed", "cancel".
        if the choice is "proceed",
          publish the page at the slug.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "choice_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        #expect(out.contains("ask.choice"))
        #expect(out.contains(".choice(prompt:"))
        #expect(out.contains("consumeChoiceSelection"))
        #expect(out.contains("\"proceed\""))
        #expect(!out.contains("_unresolved"))
    }

    @Test("background spawn lowers to a detached Task with no join")
    func backgroundSpawnLowers() throws {
        let meri = """
        ---
        name: background demo
        skill: true
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        ---
        ## Phases
        in the background, publish the page at the slug.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "background_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        #expect(out.contains("Task {"))
        #expect(!out.contains("waitForAll"))
        #expect(!out.contains("_unresolved"))
    }

    @Test("skillpack compile resolves a cross-file workflow invocation")
    func skillpackCrossFileResolves() throws {
        let enrichment = Compiler.SkillpackInput(
            source: """
            ---
            vocabulary: brain.merconfig
            ---
            To run enrichment:
              publish the page at the slug.
            """,
            file: "run_enrichment.meri"
        )
        let orchestrator = Compiler.SkillpackInput(
            source: """
            ---
            vocabulary: brain.merconfig
            ---
            To orchestrate work:
              run enrichment.
            """,
            file: "orchestrate_work.meri"
        )
        let outputs = try Compiler(options: .init(trace: .silent())).compileSkillpack(
            [enrichment, orchestrator],
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        let orchestratorOut = try #require(outputs["orchestrate_work.meri"])
        #expect(orchestratorOut.contains("RunEnrichment(runtime: runtime"))
        #expect(!orchestratorOut.contains("_unresolved"))

        // The cross-file call only resolves because the skillpack pre-registers
        // every file's workflows: compiling the orchestrator alone must fail.
        #expect(throws: (any Error).self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: orchestrator.source,
                meridianFile: orchestrator.file,
                vocabularies: [Self.vocab()],
                rulebooks: [Self.rulebook()]
            )
        }
    }

    @Test("arrow-conditional desugar rewrites to a deterministic branch")
    func arrowConditionalDesugars() throws {
        let meri = """
        ---
        name: arrow demo
        vocabulary: brain.merconfig
        rulebook: brain.merrules
        allow-fallbacks: unknown-tools
        ---
        If the note is "urgent" -> capture the note.
        """
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: meri,
            meridianFile: "arrow_demo.meri",
            vocabularies: [Self.vocab()],
            rulebooks: [Self.rulebook()]
        )
        #expect(out.contains("if "))
        #expect(!out.contains("_unresolved"))
    }
}
