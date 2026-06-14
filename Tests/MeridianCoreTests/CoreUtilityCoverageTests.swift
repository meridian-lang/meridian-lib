import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("SourceSpan — token-precise and whole-line ranges")
struct SourceSpanTests {
    @Test("SourceRange.span brackets a found substring; falls back to whole line")
    func rangeSpan() {
        let line = "the total amount is high"
        let found = SourceRange.span(file: "f", line: 3, in: line, of: "amount")
        #expect(found.startColumn == 11)        // 1-based position of "amount"
        #expect(found.endColumn == 17)
        let missing = SourceRange.span(file: "f", line: 3, in: line, of: "zzz")
        #expect(missing.startColumn == 1)
        #expect(missing.endColumn >= line.count)
        let empty = SourceRange.span(file: "f", line: 3, in: line, of: "")
        #expect(empty.startColumn == 1)
    }

    @Test("SourceLine.statementRange starts at the indent and range finds tokens in raw")
    func lineRanges() {
        let l = SourceLine(indent: 2, text: "do the thing", raw: "  do the thing", number: 5)
        let stmt = l.statementRange(file: "f")
        #expect(stmt.startColumn == 3)          // indent + 1
        #expect(stmt.startLine == 5)
        let tok = l.range(file: "f", of: "thing")
        #expect(tok.startColumn == 10)          // position of "thing" in raw
        let fallback = l.range(file: "f", of: "absent")
        #expect(fallback.startColumn == stmt.startColumn)
    }
}

@Suite("SkillFrontmatter — typed projection over the raw bag")
struct SkillFrontmatterTests {
    private func fm(_ pairs: [(String, String)]) -> SkillFrontmatter {
        SkillFrontmatter(FileMetadataAST(entries: pairs))
    }

    @Test("scalars surface and trim, missing/empty become nil")
    func scalars() {
        let f = fm([("name", " orders "), ("description", "x"), ("goal", "g"),
                    ("version", "1"), ("prompt-version", "2"), ("priority", "high"),
                    ("empty", "   ")])
        #expect(f.name == "orders")
        #expect(f.promptVersion == "2")
        #expect(f.priority == "high")
        #expect(fm([]).name == nil)
        #expect(fm([("name", "  ")]).name == nil)
    }

    @Test("lists unpack newline and comma delimiters and strip quotes")
    func lists() {
        let f = fm([("parameters", "order\ncustomer"),
                    ("vocabulary", "a.merconfig, b.merconfig"),
                    ("tools", "\"http.get\", 'file.read'")])
        #expect(f.parameters == ["order", "customer"])
        #expect(f.vocabulary == ["a.merconfig", "b.merconfig"])
        #expect(f.tools == ["http.get", "file.read"])
        #expect(fm([]).triggers.isEmpty)
    }

    @Test("alias keys merge (rulebook/rulebooks, tools/tools_required, when_to_use)")
    func aliases() {
        let f = fm([("rulebook", "a.merrules"), ("rulebooks", "b.merrules"),
                    ("tools_required", "shell.run"), ("when-to-use", "always")])
        #expect(f.rulebooks == ["a.merrules", "b.merrules"])
        #expect(f.tools == ["shell.run"])
        #expect(f.whenToUse == ["always"])
    }

    @Test("manifestEntries normalizes keys, dedupes, preserves order")
    func manifest() {
        let f = fm([("name", "n"), ("Name", "dup"), ("when-to-use", "x"), ("ignored", "y")])
        let entries = f.manifestEntries
        #expect(entries.contains { $0.key == "name" })
        #expect(entries.contains { $0.key == "when_to_use" })
        #expect(!entries.contains { $0.key == "ignored" })
        // "Name" duplicate is deduped against "name".
        #expect(entries.filter { $0.key == "name" }.count == 1)
    }
}

@Suite("EnglishLexicon — morphology and struct-name derivation")
struct EnglishLexiconTests {
    private let lex = EnglishLexicon.default

    @Test("stripLeadingArticle removes the/a/an, leaves others")
    func articles() {
        #expect(lex.stripLeadingArticle("the order") == "order")
        #expect(lex.stripLeadingArticle("an apple") == "apple")
        #expect(lex.stripLeadingArticle("orders") == "orders")
    }

    @Test("singularize handles ies, sibilant-es, plain-s, and leaves singulars")
    func singularize() {
        #expect(lex.singularize("categories") == "category")
        #expect(lex.singularize("statuses") == "status")
        #expect(lex.singularize("boxes") == "box")
        #expect(lex.singularize("pages") == "page")
        #expect(lex.singularize("order") == "order")   // no trailing s → unchanged
    }

    @Test("pluralize is the inverse and leaves already-plural unchanged")
    func pluralize() {
        #expect(lex.pluralize("category") == "categories")
        #expect(lex.pluralize("box") == "boxes")
        #expect(lex.pluralize("page") == "pages")
        #expect(lex.pluralize("pages") == "pages")
    }

    @Test("verb morphology: third person and past participle")
    func verbMorphology() {
        #expect(lex.thirdPersonSingular("watch") == "watches")
        #expect(lex.thirdPersonSingular("carry") == "carries")
        #expect(lex.thirdPersonSingular("own") == "owns")
        #expect(lex.regularPastParticiple("close") == "closed")
        #expect(lex.regularPastParticiple("carry") == "carried")
        #expect(lex.regularPastParticiple("own") == "owned")
    }

    @Test("structName strips articles/prepositions and sanitizes")
    func structName() {
        #expect(lex.structName(from: "process an order placed by a customer") == "ProcessOrder")
        #expect(lex.structName(from: "webhook-transforms") == "WebhookTransforms")
        #expect(lex.structName(from: "123 go") == "_123Go")
        #expect(lex.structName(from: "") == "Workflow")
    }

    @Test("parseDuration is plural-tolerant")
    func parseDuration() {
        #expect(lex.parseDuration("1 hour")?.1 == .hour)
        #expect(lex.parseDuration("3 days")?.1 == .day)
        #expect(lex.parseDuration("not a duration") == nil)
    }
}
