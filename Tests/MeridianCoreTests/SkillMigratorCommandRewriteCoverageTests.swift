import Testing
@testable import MeridianCore

@Suite("SkillMigrator command rewrite — coverage")
struct SkillMigratorCommandRewriteCoverageTests {

    private func migrator() -> SkillMigrator {
        SkillMigrator(compiler: Compiler(options: .init(fallbackPolicy: .lenient)), vocabularies: [])
    }

    @Test("diagnosticLine parses L<n> and file:line:column prefixes")
    func diagnosticLineFormats() {
        let m = migrator()
        #expect(m.diagnosticLine("L42: unparseable statement") == 42)
        #expect(m.diagnosticLine("t.meridian:12:3: error message") == 12)
        #expect(m.diagnosticLine("no line here") == nil)
        #expect(m.diagnosticLine("foo::bar") == nil)
        #expect(m.diagnosticLine("x:12:") == nil)
    }

    @Test("markEnclosingSectionReference always stamps (( role: reference )), regardless of heading")
    func referenceRescueMarkerIsUniform() {
        let m = SkillMigrator(compiler: Compiler(options: .init(fallbackPolicy: .lenient)),
                              vocabularies: [], options: .init(routeFuzzy: true))
        for heading in ["Invariants", "Protocol", "Anti-Patterns", "When to use",
                        "When not to use", "Output Format", "Tools", "Random Notes"] {
            let src = "## \(heading)\ndo something that does not lower."
            let out = m.markEnclosingSectionReference(forDiagnostic: "L2: unparseable", in: src)
            guard let marked = out else {
                Issue.record("expected reference marking for \(heading)"); continue
            }
            #expect(marked.contains("(( role: reference ))"))
            #expect(!marked.contains("(( inert"))
        }
    }

    @Test("frontmatter parameters in YAML list form build the rewrite scope")
    func frontmatterListParams() {
        let lines = """
        ---
        parameters:
          - slug
          - attendee name
        ---
        """.components(separatedBy: "\n")
        let scope = migrator().frontmatterParamScope(lines)
        #expect(scope.contains("slug"))
        #expect(scope.contains(SkillMigrator.scopeKey("attendee name")))
        #expect(scope.contains("input"))
    }

    @Test("shell-fence placeholders rewrite inside fenced blocks")
    func shellFenceRewrite() {
        let src = """
        ---
        parameters: slug
        ---
        ## Procedure
        ```bash
        gbrain open <slug>
        ```
        """
        let out = migrator().rewriteCommandPlaceholders(src)
        #expect(out.contains("gbrain open {slug}"))
        #expect(!out.contains("<slug>"))
    }

    @Test("markEnclosingSectionReference stamps the nearest heading, only when routeFuzzy is on")
    func markSectionReference() {
        let src = """
        ## Protocol
        do something that does not lower.
        """
        // Default migrator() has routeFuzzy off (P1 policy: category-4 is a
        // hard error unless the caller opts into the escape hatch).
        #expect(migrator().markEnclosingSectionReference(forDiagnostic: "L2: unparseable", in: src) == nil)

        let routed = SkillMigrator(compiler: Compiler(options: .init(fallbackPolicy: .lenient)),
                                   vocabularies: [], options: .init(routeFuzzy: true))
        let out = routed.markEnclosingSectionReference(forDiagnostic: "L2: unparseable", in: src)
        guard let marked = out else {
            Issue.record("expected reference marking"); return
        }
        #expect(marked.contains("(( role: reference ))"))
    }

    @Test("markEnclosingSectionReference returns nil when the diagnostic carries no parseable line number, even with routeFuzzy on")
    func markSectionReferenceNilWithoutParseableLine() {
        let routed = SkillMigrator(compiler: Compiler(options: .init(fallbackPolicy: .lenient)),
                                   vocabularies: [], options: .init(routeFuzzy: true))
        let src = """
        ## Protocol
        do something that does not lower.
        """
        #expect(routed.markEnclosingSectionReference(forDiagnostic: "no line number here", in: src) == nil)
    }

    @Test("diagnosticLine falls through to the colon scan when an L-prefix has no digits")
    func diagnosticLineFallsThroughWhenLPrefixHasNoDigits() {
        let m = migrator()
        #expect(m.diagnosticLine("Lxyz") == nil)
        #expect(m.diagnosticLine("Lxyz t.meridian:7:2: error") == 7)
    }

    @Test("rewriteAnglePlaceholders leaves a string with no `<` untouched")
    func rewriteAnglePlaceholdersNoAngleBracket() {
        let m = migrator()
        #expect(m.rewriteAnglePlaceholders("gbrain stats", scope: ["slug"]) == "gbrain stats")
    }

    @Test("rewriteAnglePlaceholders treats a nested `<` before the closing `>` as unresolved, not a placeholder")
    func rewriteAnglePlaceholdersNestedAngleBracket() {
        let m = migrator()
        let out = m.rewriteAnglePlaceholders("<slug <nested>>", scope: ["slug", "nested"])
        // The outer `<slug ` never sees its own `>` before hitting a fresh
        // `<`, so it is left verbatim; only the inner `<nested>` resolves.
        #expect(out.contains("{nested}"), Comment(rawValue: out))
        #expect(out.contains("<slug"), Comment(rawValue: out))
    }

    @Test("isWordShaped rejects punctuation-only placeholder names")
    func isWordShapedRejects() {
        #expect(SkillMigrator.isWordShaped("valid-name"))
        #expect(!SkillMigrator.isWordShaped("bad@name"))
        #expect(!SkillMigrator.isWordShaped(""))
    }

    @Test("unterminated inline backtick spans are left verbatim")
    func unterminatedBacktickSpan() {
        let src = """
        ---
        parameters: slug
        ---
        - `open <slug>
        """
        let out = migrator().rewriteCommandPlaceholders(src)
        #expect(out.contains("`open <slug>"))
    }
}
