import Testing
@testable import MeridianCore

@Suite("SkillTriggers — classifier and synthesizer coverage")
struct SkillTriggersCoverageTests {

    @Test("cron-like schedules without asterisks classify as schedule")
    func cronLikeWithoutAsterisk() {
        let c = TriggerClassifier(lexicon: .default)
        #expect(c.classify("0 9 1 1 1", sourceLine: 1).kind == .schedule)
    }

    @Test("asterisk-bearing specs classify as schedule via the star probe")
    func asteriskSchedule() {
        let c = TriggerClassifier(lexicon: .default)
        #expect(c.classify("* * * * *", sourceLine: 1).kind == .schedule)
    }

    @Test("synthesizer logs lowering decisions under .lowering trace")
    func synthesizerTrace() {
        let cap = ParserTrace.capturing(categories: [.lowering])
        let synth = TriggerSynthesizer(lexicon: .default, trace: cap.trace)
        _ = synth.synthesize([
            SkillTrigger(kind: .schedule, spec: "nightly", name: "nightly", sourceLine: 4),
        ], sourceFile: "t.meridian")
        let lines = cap.lines()
        #expect(lines.contains { $0.contains("trigger @L4") && $0.contains("schedule") })
    }

    @Test("first trigger keeps the unsuffixed struct name")
    func synthesizerBaseStructName() {
        let synth = TriggerSynthesizer(lexicon: .default, trace: .silent())
        let workflows = synth.synthesize([
            SkillTrigger(kind: .keyword, spec: "hello", name: "hello", sourceLine: 1),
        ], sourceFile: "t.meridian")
        guard let wf = workflows.first else {
            Issue.record("expected workflow"); return
        }
        let base = EnglishLexicon.default.structName(from: "when hello fires")
        #expect(wf.explicitStructName == base)
    }

    @Test("duplicate trigger struct names receive numeric suffixes")
    func synthesizerDisambiguatesStructNames() {
        let synth = TriggerSynthesizer(lexicon: .default, trace: .silent())
        let triggers = [
            SkillTrigger(kind: .keyword, spec: "perplexity research", name: "perplexityResearch", sourceLine: 1),
            SkillTrigger(kind: .keyword, spec: "perplexity-research", name: "perplexityResearch", sourceLine: 2),
        ]
        let workflows = synth.synthesize(triggers, sourceFile: "t.meridian")
        guard workflows.count == 2 else {
            Issue.record("expected two trigger workflows"); return
        }
        #expect(workflows[0].explicitStructName != workflows[1].explicitStructName)
        #expect(workflows[1].explicitStructName?.hasSuffix("2") == true)
    }

    @Test("frontmatter triggers compile into synthetic wait/emit workflows")
    func compileWithTriggersFrontmatter() throws {
        let swift = try Compiler(options: .init(
            emitterOptions: .init(includeTimestamp: false, emitSourceLineComments: false)
        )).compile(
            meridianSource: """
            ---
            vocabulary: t.merconfig
            triggers: nightly, perplexity research, perplexity-research
            ---
            To run:
              complete.
            """,
            meridianFile: "t.meridian",
            merconfigSource: """
            === vocabulary ===
            thing is a kind of thing.
            """,
            merconfigFile: "t.merconfig"
        )
        #expect(swift.contains("trigger."))
        #expect(swift.contains("WhenNightlyFires") || swift.contains("whenNightlyFires"))
    }

    @Test("short cron field lists classify as keyword, not schedule")
    func shortCronFieldListIsKeyword() {
        let c = TriggerClassifier(lexicon: .default)
        #expect(c.classify("0 9 1 1", sourceLine: 1).kind == .keyword)
    }

    @Test("cron-like specs with invalid field characters fall through to keyword")
    func invalidCronFieldCharacters() {
        let c = TriggerClassifier(lexicon: .default)
        #expect(c.classify("0 9 mon tue wed", sourceLine: 1).kind == .keyword)
    }

    @Test("ambient and event word sets beat the keyword default")
    func ambientAndEventClassification() {
        let c = TriggerClassifier(lexicon: .default)
        #expect(c.classify("always on", sourceLine: 1).kind == .ambient)
        #expect(c.classify("webhook received", sourceLine: 1).kind == .event)
    }
}
