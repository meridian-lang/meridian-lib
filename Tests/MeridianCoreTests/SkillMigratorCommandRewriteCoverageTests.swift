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

    @Test("inertMarker picks role-specific markers for recognized headings")
    func inertMarkerRoles() {
        let m = migrator()
        #expect(m.inertMarker(forHeading: "Invariants").contains("role: invariants"))
        #expect(m.inertMarker(forHeading: "Protocol").contains("role: procedure"))
        #expect(m.inertMarker(forHeading: "Anti-Patterns").contains("role: prohibitions"))
        #expect(m.inertMarker(forHeading: "When to use").contains("role: applicability"))
        #expect(m.inertMarker(forHeading: "When not to use").contains("role: negative-applicability"))
        #expect(m.inertMarker(forHeading: "Output Format").contains("role: template"))
        #expect(m.inertMarker(forHeading: "Tools").contains("role: tools"))
        #expect(m.inertMarker(forHeading: "Random Notes") == "(( inert ))")
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

    @Test("markEnclosingSectionInert stamps the nearest heading")
    func markSectionInert() {
        let src = """
        ## Protocol
        do something that does not lower.
        """
        let out = migrator().markEnclosingSectionInert(forDiagnostic: "L2: unparseable", in: src)
        guard let marked = out else {
            Issue.record("expected inert marking"); return
        }
        #expect(marked.contains("(( inert"))
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
