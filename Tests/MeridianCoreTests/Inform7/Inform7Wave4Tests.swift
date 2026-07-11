import Testing
import Foundation
@testable import MeridianCore

@Suite("Wave 4A — declarative domain English")
struct Inform7Wave4DomainTests {

    @Test("called-the property syntax parses typed property declarations")
    func calledThePropertySyntax() throws {
        let cfg = try MerConfigParser(trace: .silent()).parse("""
        === vocabulary ===
        A page is a kind of thing.
        A page has a text called the summary.
        A page has a date called the deadline.
        """, file: "domain.merconfig")

        let properties = cfg.vocabulary.compactMap { stmt -> PropertyDeclaration? in
            if case .property(let p) = stmt { return p }
            return nil
        }.flatMap(\.properties)

        #expect(properties.contains { entry in
            entry.name == "summary" && {
                if case .explicit(let type) = entry.type { return type.lowercased() == "text" }
                return false
            }()
        })
        #expect(properties.contains { entry in
            entry.name == "deadline" && {
                if case .explicit(let type) = entry.type { return type.lowercased() == "date" }
                return false
            }()
        })
    }

    @Test("can-be and usually compile to enum property with author default")
    func canBeUsuallyDefault() throws {
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: """
            ---
            name: page workflow
            parameters: page
            ---

            ## Domain
            A page is a kind of thing.
            A page can be archived or live.
            A page is usually live.

            ## Phases
            complete.
            """,
            meridianFile: "domain.meri",
            vocabularies: []
        )

        #expect(out.contains("public enum PagePageState"), Comment(rawValue: out))
        #expect(out.contains("public var pageState: PagePageState"), Comment(rawValue: out))
        #expect(out.contains("pageState: PagePageState = .live"), Comment(rawValue: out))
    }

    @Test("Domain section declarations are harvested before frontmatter parameter resolution")
    func domainSectionHarvestsBeforeParameterResolution() throws {
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: """
            ---
            name: summarize
            parameters: page
            ---

            ## Domain
            A page is a kind of thing.
            A page has a text called the summary.

            ## Phases
            complete.
            """,
            meridianFile: "domain-section.meri",
            vocabularies: []
        )

        #expect(out.contains("public struct Page"), Comment(rawValue: out))
        #expect(out.contains("public var summary: String"), Comment(rawValue: out))
        #expect(out.contains("public let page: Page"), Comment(rawValue: out))
    }

    @Test("Domain-shaped sentence in a procedure is not harvested")
    func domainSentenceInProcedureErrors() {
        #expect(throws: CompilerError.self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: """
                ---
                name: bad
                ---

                ## Phases
                A deal is a kind of page.
                """,
                meridianFile: "bad-domain-position.meri",
                vocabularies: []
            )
        }
    }

    @Test("duplicate kind declarations reject multiple parents")
    func duplicateKindRejectsMultipleParents() {
        #expect(throws: CompilerError.self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: """
                ---
                name: duplicate
                parameters: deal
                ---

                ## Domain
                A page is a kind of thing.
                A task is a kind of thing.
                A deal is a kind of page.
                A deal is a kind of task.

                ## Phases
                complete.
                """,
                meridianFile: "duplicate-domain.meri",
                vocabularies: []
            )
        }
    }
}

@Suite("Wave 4B — declarative tables")
struct Inform7Wave4TableTests {

    @Test("Tables section defaults unmarked Markdown tables to data bindings")
    func tablesSectionDefaultsToData() throws {
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: """
            ---
            name: route
            ---

            ## Tables
            | trigger phrase | skill |
            | --- | --- |
            | daily briefing | briefing |

            ## Phases
            bind chosen skill = the skill corresponding to the trigger phrase "daily briefing" in the table.
            complete.
            """,
            meridianFile: "tables.meri",
            vocabularies: []
        )

        #expect(out.contains("state.bind(\"table\", Value.list"), Comment(rawValue: out))
        #expect(out.contains("table.lookup_miss"), Comment(rawValue: out))
        #expect(out.contains("__row.member(\"triggerPhrase\")"), Comment(rawValue: out))
        #expect(out.contains("__row.member(\"skill\")"), Comment(rawValue: out))
    }

    @Test("explicit named data table supports multi-word lookup table names")
    func namedDataTableLookup() throws {
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: """
            ---
            name: route
            ---

            ## Phases
            !!! table (( data table: dispatch table ))
            | trigger phrase | skill |
            | --- | --- |
            | daily briefing | briefing |
            bind chosen skill = the skill corresponding to the trigger phrase "daily briefing" in the dispatch table.
            complete.
            """,
            meridianFile: "named-table.meri",
            vocabularies: []
        )

        #expect(out.contains("state.bind(\"dispatchTable\", Value.list"), Comment(rawValue: out))
        #expect(out.contains("state.get(\"dispatchTable\")"), Comment(rawValue: out))
    }

    @Test("typed data table reports row and column for invalid cells")
    func typedTableCellDiagnostic() {
        #expect(throws: CompilerError.self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: """
                ---
                name: bad table
                ---

                ## Tables
                | score (Number) | label |
                | --- | --- |
                | high | risky |

                ## Phases
                complete.
                """,
                meridianFile: "bad-table.meri",
                vocabularies: []
            )
        }
    }
}

@Suite("Wave 4C — text substitutions")
struct Inform7Wave4TemplateTests {

    @Test("template parser recognizes conditional loop formatter and leaves plain brackets literal")
    func parserRecognizesTemplateDirectives() {
        let parser = ExpressionParser(trace: .silent())
        let segs = parser.parseInterpolationSegments("""
        [date]
        [if the score is more than 5]high[otherwise]low[end if]
        """)
        let loopSegs = parser.parseInterpolationSegments("[for each row in rows]{{ row.name as a integer }}[end for]")

        #expect(segs.contains { if case .literal(let s) = $0 { return s.contains("[date]") }; return false })
        #expect(segs.contains { if case .conditional = $0 { return true }; return false })
        #expect(loopSegs.contains { if case .forEach = $0 { return true }; return false })
    }

    @Test("template codegen emits conditional loop and formatter helpers")
    func templateCodegen() throws {
        let expr = IRExpression.interpolatedString([
            .literal("Rows:\n"),
            .forEach(
                variable: "row",
                collection: .identifierRef(name: "rows"),
                body: [
                    .literal("- "),
                    .expression(.propertyAccess(.identifierRef(name: "row"), propertyName: "name")),
                    .literal(": "),
                    .formatted(.propertyAccess(.identifierRef(name: "row"), propertyName: "score"), formatter: "integer"),
                    .literal("\n")
                ]
            ),
            .conditional(
                condition: .comparison(.identifierRef(name: "count"), .greaterThan, .literal(.number(Decimal(0)))),
                then: [.literal("non-empty")],
                otherwise: [.literal("empty")]
            )
        ])
        let wf = IRWorkflow(
            name: "template test",
            parameters: [],
            body: IRBlock(statements: [
                .bind(BindIR(name: "report", expression: expr, isRebind: false))
            ])
        )
        let out = try SwiftEmitter(options: .init(emitSourceLineComments: false)).emitFile(workflows: [wf])

        #expect(out.contains("private func meridianFormat"), Comment(rawValue: out))
        #expect(out.contains("for __item in"), Comment(rawValue: out))
        #expect(out.contains("if MeridianComparison.gt"), Comment(rawValue: out))
        #expect(out.contains("meridianFormat(__item.member(\"score\") ?? .null, as: \"integer\")"), Comment(rawValue: out))
    }

    @Test("source-level fenced template can be bound after an empty assignment")
    func sourceLevelFencedTemplateBind() throws {
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: """
            ---
            name: template source
            ---

            ## Tables
            | skill | score (Number) |
            | --- | --- |
            | briefing | 10 |

            ## Phases
            bind report body =
              ```
              [for each row in table]{{ row.skill }}: {{ row.score as a integer }}[end for]
              [if true]done[otherwise]empty[end if]
              ```
            emit template.report with body = report body.
            complete.
            """,
            meridianFile: "template-source.meri",
            vocabularies: []
        )

        #expect(out.contains("private func meridianFormat"), Comment(rawValue: out))
        #expect(out.contains("for __item in"), Comment(rawValue: out))
        #expect(out.contains("meridianFormat(__item.member(\"score\") ?? .null, as: \"integer\")"), Comment(rawValue: out))
    }

    // --- FormatterRegistry: single source of truth for the closed formatter set ---

    @Test("FormatterRegistry accepts every fixed name and any decimal(N)")
    func registryAcceptsKnownFormatters() {
        #expect(FormatterRegistry.isValid("integer"))
        #expect(FormatterRegistry.isValid("Integer"))          // case-insensitive
        #expect(FormatterRegistry.isValid("short date"))
        #expect(FormatterRegistry.isValid("long date"))
        #expect(FormatterRegistry.isValid("decimal(0)"))
        #expect(FormatterRegistry.isValid("decimal(2)"))
        #expect(FormatterRegistry.isValid("DECIMAL(3)"))
    }

    @Test("FormatterRegistry rejects unknown names and malformed decimal(...)")
    func registryRejectsUnknown() {
        #expect(!FormatterRegistry.isValid("shortdate"))
        #expect(!FormatterRegistry.isValid("percentage"))
        #expect(!FormatterRegistry.isValid("decimal()"))
        #expect(!FormatterRegistry.isValid("decimal(abc)"))
        #expect(!FormatterRegistry.isValid("decimal(2"))
        #expect(!FormatterRegistry.isValid(""))
    }

    @Test("an unknown formatter in a fenced template is a sourced MER2012 error naming the available formatters")
    func unknownFormatterIsHardError() throws {
        let caught = #expect(throws: CompilerError.self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: """
                ---
                name: template source
                ---

                ## Phases
                bind report body =
                  ```
                  {{ 5 as a percentage }}
                  ```
                emit template.report with body = report body.
                complete.
                """,
                meridianFile: "template-source.meri",
                vocabularies: [])
        }
        let err = try #require(caught)
        let diag = try #require(err.diagnostics.first)
        #expect(diag.code == .unknownTemplateFormatter, Comment(rawValue: "\(diag.code)"))
        #expect(diag.message.contains("percentage"), Comment(rawValue: diag.message))
        #expect(!diag.suggestions.isEmpty || !diag.notes.isEmpty, Comment(rawValue: "\(diag)"))
    }

    @Test("a near-miss formatter typo suggests the nearest declared name")
    func formatterTypoSuggestsNearest() throws {
        let caught = #expect(throws: CompilerError.self) {
            _ = try Compiler(options: .init(trace: .silent())).compile(
                meridianSource: """
                ---
                name: template source
                ---

                ## Phases
                bind report body =
                  ```
                  {{ 5 as a integr }}
                  ```
                emit template.report with body = report body.
                complete.
                """,
                meridianFile: "template-source.meri",
                vocabularies: [])
        }
        let err = try #require(caught)
        let rendered = (err.diagnostics.first?.suggestions ?? []).map(\.rationale).joined()
        #expect(rendered.contains("integer"), Comment(rawValue: rendered))
    }

    @Test("short date, long date, and decimal(N) formatters all compile cleanly")
    func validFormattersCompile() throws {
        let out = try Compiler(options: .init(trace: .silent())).compile(
            meridianSource: """
            ---
            name: template source
            ---

            ## Phases
            bind report body =
              ```
              {{ now as a short date }} {{ now as a long date }} {{ 5 as a decimal(2) }}
              ```
            emit template.report with body = report body.
            complete.
            """,
            meridianFile: "template-source.meri",
            vocabularies: [])
        #expect(out.contains("as: \"short date\""), Comment(rawValue: out))
        #expect(out.contains("as: \"long date\""), Comment(rawValue: out))
        #expect(out.contains("as: \"decimal(2)\""), Comment(rawValue: out))
    }
}

// MARK: - End-to-end .meridian.test specs (4A / 4B / 4C)

@Suite("Wave 4 — .meridian.test specs")
struct Wave4SpecTests {

    /// `Tests/MeridianCoreTests/Inform7/Inform7Wave4Tests.swift`
    ///  → `Tests/MeridianCoreTests/MeridianTestSpecs`.
    private func specURL(_ file: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Inform7
            .deletingLastPathComponent()   // MeridianCoreTests
            .appendingPathComponent("MeridianTestSpecs")
            .appendingPathComponent(file)
    }

    @Test("each Wave 4 spec compiles and satisfies its assertions",
          arguments: [
            "wave4_4a_domain.meridian.test",
            "wave4_4b_tables.meridian.test",
            "wave4_4c_templates.meridian.test",
            "wave4_4c_templates_unknown_formatter.meridian.test",
          ])
    func specPasses(_ file: String) throws {
        let spec = try MeridianTestRunner().loadSpec(specURL(file))
        switch MeridianTestRunner().run(spec) {
        case .success:
            break
        case .failure(let reasons):
            Issue.record(Comment(rawValue: "\(file) failed:\n\(reasons.joined(separator: "\n"))"))
        case .skipped(let reason):
            Issue.record(Comment(rawValue: "\(file) was skipped: \(reason ?? "")"))
        }
    }
}
