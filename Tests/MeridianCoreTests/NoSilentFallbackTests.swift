import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

/// Each former silent compile-time fallback is now a coded diagnostic. These
/// tests assert the *code* (the durable contract), not the message text.
@Suite("NoSilentFallback")
struct NoSilentFallbackTests {

    /// Compile and return the set of diagnostic codes thrown (empty if it
    /// compiled clean).
    private func codes(_ mer: String, _ cfg: String,
                       fallbacks: FallbackPolicy = .strict,
                       merFile: String = "t.meridian",
                       cfgFile: String = "t.merconfig") -> Set<DiagnosticCode> {
        do {
            _ = try Compiler(options: .init(fallbackPolicy: fallbacks)).compile(
                meridianSource: mer, meridianFile: merFile,
                merconfigSource: cfg, merconfigFile: cfgFile)
            return []
        } catch let e as CompilerError {
            return Set(e.diagnostics.map(\.code))
        } catch IRValidationError.diagnostics(let diagnostics) {
            return Set(diagnostics.map(\.code))
        } catch {
            Issue.record("unexpected non-CompilerError: \(error)")
            return []
        }
    }

    private func codesMerOnly(_ mer: String, fallbacks: FallbackPolicy = .strict) -> Set<DiagnosticCode> {
        do {
            _ = try Compiler(options: .init(fallbackPolicy: fallbacks)).compile(
                meridianSource: mer, meridianFile: "t.meri", vocabularies: [])
            return []
        } catch let e as CompilerError {
            return Set(e.diagnostics.map(\.code))
        } catch IRValidationError.diagnostics(let diagnostics) {
            return Set(diagnostics.map(\.code))
        } catch {
            Issue.record("unexpected non-CompilerError: \(error)")
            return []
        }
    }

    private func diagnostics(_ mer: String, _ cfg: String,
                             fallbacks: FallbackPolicy = .strict) -> [Diagnostic] {
        do {
            _ = try Compiler(options: .init(fallbackPolicy: fallbacks)).compile(
                meridianSource: mer, meridianFile: "t.meridian",
                merconfigSource: cfg, merconfigFile: "t.merconfig")
            return []
        } catch let e as CompilerError {
            return e.diagnostics
        } catch IRValidationError.diagnostics(let diagnostics) {
            return diagnostics
        } catch {
            Issue.record("unexpected non-CompilerError: \(error)")
            return []
        }
    }

    private func diagnosticTrace(_ mer: String, _ cfg: String,
                                 fallbacks: FallbackPolicy = .strict) -> [String] {
        let cap = ParserTrace.capturing(categories: [.diagnostics, .lowering])
        do {
            _ = try Compiler(options: .init(trace: cap.trace, fallbackPolicy: fallbacks)).compile(
                meridianSource: mer, meridianFile: "t.meridian",
                merconfigSource: cfg, merconfigFile: "t.merconfig")
        } catch {
            Issue.record("unexpected compile failure while collecting diagnostic trace: \(error)")
        }
        return cap.lines()
    }

    private func assertAllowedFallbackWarning(
        _ mer: String,
        _ cfg: String,
        code: DiagnosticCode,
        messageFragment: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(!codes(mer, cfg).contains(code), sourceLocation: sourceLocation)
        let lines = diagnosticTrace(mer, cfg)
        #expect(lines.contains {
            $0.contains("warning \(code.id)")
                && $0.contains(messageFragment)
                && ($0.contains("fallback") || $0.contains("allow-fallbacks"))
        }, Comment(rawValue: lines.joined(separator: "\n")), sourceLocation: sourceLocation)
    }

    private let cfg = """
    === vocabulary ===

    An order is a kind of thing.
    A widget is a kind of thing.

    === tools ===

    Charge Payment
    ==============
    ~ chargePayment(order: Order) : Order
    """

    @Test("unknown tool is a hard error (was: invoke that failed only at runtime)")
    func unknownTool() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          invoke chargePaymnt with order = the order.
        """
        #expect(codes(mer, cfg).contains(.unknownTool))
    }

    @Test("unknown tool downgraded by allow-fallbacks: unknown-tools")
    func unknownToolFallback() {
        let mer = """
        ---
        vocabulary: t.merconfig
        allow-fallbacks: unknown-tools
        ---
        To process an order:
          invoke chargePaymnt with order = the order.
        """
        assertAllowedFallbackWarning(
            mer,
            cfg,
            code: .unknownTool,
            messageFragment: "unknown tool allowed by fallback"
        )
    }

    @Test("a declared tool with the right spelling compiles clean")
    func declaredToolClean() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          invoke chargePayment with order = the order.
        """
        #expect(codes(mer, cfg).isEmpty)
    }

    @Test("unresolved phrase is a hard error (was: _unresolved placeholder)")
    func unresolvedPhrase() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          frobnicate the gizmo using the order.
        """
        let c = codes(mer, cfg)
        #expect(c.contains(.unresolvedPhrase) || c.contains(.unknownTool),
                Comment(rawValue: "expected an unresolved phrase/tool code, got \(c.map(\.id).sorted())"))
    }

    @Test("unresolved phrase downgraded by allow-fallbacks: unresolved-phrases")
    func unresolvedPhraseFallback() {
        let mer = """
        ---
        vocabulary: t.merconfig
        allow-fallbacks: unresolved-phrases, unknown-tools
        ---
        To process an order:
          frobnicate the gizmo using the order.
        """
        assertAllowedFallbackWarning(
            mer,
            cfg,
            code: .unresolvedPhrase,
            messageFragment: "unresolved phrase placeholder"
        )
    }

    @Test("unparseable rule downgraded by allow-fallbacks: unparseable-rules")
    func unparseableRuleFallbackWarning() {
        let mer = """
        ---
        vocabulary: t.merconfig
        allow-fallbacks: unparseable-rules
        ---
        When payment clears do nothing.

        To process an order:
          complete.
        """
        assertAllowedFallbackWarning(
            mer,
            cfg,
            code: .unparseableRule,
            messageFragment: "unparseable rule dropped by allow-fallbacks"
        )
    }

    @Test("unattached rule downgraded by allow-fallbacks: unattached-rules")
    func unattachedRuleFallbackWarning() {
        let mer = """
        ---
        vocabulary: t.merconfig
        allow-fallbacks: unattached-rules
        ---
        A widget must not be tampered.

        To process an order:
          complete.
        """
        assertAllowedFallbackWarning(
            mer,
            cfg,
            code: .unattachedRule,
            messageFragment: "unattached rule dropped by allow-fallbacks"
        )
    }

    @Test("trigger action downgraded by allow-fallbacks: unresolved-trigger-actions")
    func unresolvedTriggerActionFallbackWarning() {
        let mer = """
        ---
        vocabulary: t.merconfig
        allow-fallbacks: unresolved-trigger-actions
        ---
        When a refund is requested, do something completely unknown.

        To process an order:
          complete.
        """
        assertAllowedFallbackWarning(
            mer,
            cfg,
            code: .unresolvedTriggerAction,
            messageFragment: "trigger action unresolved but allowed by fallback"
        )
    }

    @Test("orphaned fenced code block is a structural error")
    func orphanedCodeBlock() {
        let mer = """
        ---
        name: orphan block
        ---
        ## Phases
        ```
        echo hi
        ```
        complete.
        """
        #expect(codesMerOnly(mer).contains(.orphanedCodeBlock))
    }

    @Test("malformed bind assignment is a malformed-statement error, not unresolved phrase")
    func malformedBind() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          bind total
          complete.
        """
        #expect(codes(mer, cfg).contains(.unparseableStatement))
    }

    @Test("ordinary unknown natural language stays an unresolved-phrase error with guidance")
    func ordinaryPhraseNotMalformedStatement() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          frobnicate the gizmo using the order.
        """
        let c = codes(mer, cfg)
        #expect(c.contains(.unresolvedPhrase))
        #expect(!c.contains(.unparseableStatement))
    }

    @Test("unknown merconfig section is a configuration error")
    func unknownMerconfigSection() {
        let badCfg = """
        === widgets ===
        A widget is a kind of thing.
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        complete.
        """
        #expect(codes(mer, badCfg).contains(.unknownMerconfigSection))
    }

    @Test("malformed tool declaration is a vocabulary error")
    func malformedToolDeclaration() {
        let badCfg = """
        === tools ===

        Broken Tool
        ==============
        -- missing signature line
        """
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        complete.
        """
        #expect(codes(mer, badCfg).contains(.vocabularyDeclarationUnrecognized))
    }

    @Test("misplaced frontmatter is a structural error")
    func misplacedFrontmatter() {
        let mer = """
        To do something:
          complete.
        ---
        name: late
        ---
        """
        #expect(codesMerOnly(mer).contains(.frontmatterPlacement))
    }

    @Test("removed body import is a structural error")
    func removedImport() {
        let mer = """
        import vocabulary from "t.merconfig".
        To do something:
          complete.
        """
        #expect(codes(mer, cfg).contains(.removedImportForm))
    }

    @Test("unlowerable rule predicate errors instead of silently returning false")
    func unlowerableRulePredicate() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        A customer must not place an order whose every item is out of stock.

        To process an order placed by a customer:
          invoke chargePayment with order = the order.
        """
        let c = codes(mer, cfg)
        #expect(c.contains(.unlowerableRulePredicate),
                Comment(rawValue: "expected unlowerableRulePredicate, got \(c.map(\.id).sorted())"))
    }

    // MARK: - Phase A1 closed gaps (one compile trigger per touch-site)

    @Test("topic label with an empty rest errors (was: silently dropped)")
    func topicLabelEmptyRest() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          The setup skill provides:
          complete.
        """
        #expect(codes(mer, cfg).contains(.unparseableStatement))
    }

    @Test("a `do … and …` chain with an unparseable chunk errors (was: compactMap drop)")
    func doChainUnparseableChunk() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          do complete and bind total.
        """
        #expect(codes(mer, cfg).contains(.unparseableStatement))
    }

    @Test("a decision-table row that does not parse errors (was: silently dropped)")
    func decisionTableUnparseableRow() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          | status | action |
          | --- | --- |
          | ready | The setup skill provides: |
          complete.
        """
        #expect(codes(mer, cfg).contains(.unparseableStatement))
    }

    @Test("malformed definition vocabulary line errors (was: silently dropped)")
    func malformedDefinitionVocabularyLine() {
        let badCfg = """
        === vocabulary ===
        Definition: this is not a valid definition shape.
        An order is a kind of thing.
        """
        #expect(codes("---\nvocabulary: t.merconfig\n---\ncomplete.", badCfg)
            .contains(.vocabularyDeclarationUnrecognized))
    }

    @Test("malformed verb vocabulary line errors (was: silently dropped)")
    func malformedVerbVocabularyLine() {
        let badCfg = """
        === vocabulary ===
        The verb to  (he owns, it is owned) means the ownership relation.
        An order is a kind of thing.
        """
        #expect(codes("---\nvocabulary: t.merconfig\n---\ncomplete.", badCfg)
            .contains(.vocabularyDeclarationUnrecognized))
    }

    @Test("malformed inverse vocabulary line errors (was: silently dropped)")
    func malformedInverseVocabularyLine() {
        let badCfg = """
        === vocabulary ===
        The inverse of owns is.
        An order is a kind of thing.
        """
        #expect(codes("---\nvocabulary: t.merconfig\n---\ncomplete.", badCfg)
            .contains(.vocabularyDeclarationUnrecognized))
    }

    @Test("empty expression atom surfaces malformed statement at lowering (was: silent empty string)")
    func emptyExpressionAtom() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          let total be .
          complete.
        """
        #expect(codes(mer, cfg).contains(.unparseableStatement))
    }

    @Test("corrupt code-block sentinel surfaces malformed condition at lowering (was: silent empty string)")
    func corruptCodeBlockSentinel() {
        let sentinel = "\u{E000}codeblock:plain:!!!not-valid-base64!!!"
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          bind payload = \(sentinel).
          complete.
        """
        #expect(codes(mer, cfg).contains(.malformedCondition))
    }

    @Test("loop `whose … contains …` emits string contains, not MeridianComparison.eq (emitLoopBoolExpr regression)")
    func loopContainsNotSilentEq() throws {
        let out = try Compiler(options: .init(fallbackPolicy: .strict)).compile(
            meridianSource: """
            ---
            vocabulary: t.merconfig
            ---
            To process an order:
              for each order whose tags contains "urgent":
                complete.
            """,
            meridianFile: "t.meridian",
            merconfigSource: cfg,
            merconfigFile: "t.merconfig")
        #expect(out.contains(".contains("))
        #expect(!out.contains("MeridianComparison.eq(__e.member(\"tags\")"))
    }

    @Test("match branch arm missing colon is MER1012")
    func matchBranchMissingColon() {
        let mer = """
        To route:
          branch on choice:
            "ready"
              complete.
        """
        #expect(codesMerOnly(mer).contains(.matchBranchSyntax))
    }

    @Test("empty match branch is a match-branch semantic error")
    func emptyMatchBranchSemantic() {
        let mer = """
        To route:
          branch on choice:
          complete.
        """
        #expect(codesMerOnly(mer).contains(.matchBranchSemantic))
    }

    @Test("SwiftEmitter rejects invalid expression IR instead of falling back")
    func swiftEmitterRejectsInvalidExpressionIR() throws {
        let emitter = SwiftEmitter()
        let emptyLogical = #expect(throws: CompilerError.self) {
            _ = try emitter.emitExpr(.logical(.and, []))
        }
        #expect(try #require(emptyLogical).diagnostics.contains { $0.code == .invalidIR })

        let inlineInvoke = #expect(throws: CompilerError.self) {
            _ = try emitter.emitValueExpr(.invocation(InvokeIR(toolID: "demo.tool")))
        }
        #expect(try #require(inlineInvoke).diagnostics.contains { $0.code == .invalidIR })
    }

    @Test("recovery summary appears when multiple workflows fail")
    func recoverySummaryForMultipleWorkflowFailures() {
        let mer = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          frobnicate the order.

        To audit an order:
          transmogrify the order.
        """
        let ds = diagnostics(mer, cfg)
        #expect(ds.filter { $0.code == .unresolvedPhrase }.count == 2,
                Comment(rawValue: ds.map { "\($0.code.id): \($0.message)" }.joined(separator: "\n")))
        #expect(ds.contains { $0.code == .diagnosticRecoverySummary })
        #expect(ds.contains { diagnostic in
            diagnostic.notes.contains { $0.message.contains("skipped workflow") }
        })
    }

    @Test("warnings-only DiagnosticEngine does not throw")
    func warningsDoNotFailCompile() {
        let engine = DiagnosticEngine(trace: .silent())
        engine.report(Diagnostic.warning(.swiftFormatFailed, message: "cosmetic",
                                         range: SourceRange(file: "x.swift", line: 1, column: 1)))
        var threw = false
        do { try engine.throwIfErrors() } catch { threw = true }
        #expect(!threw)
    }
}
