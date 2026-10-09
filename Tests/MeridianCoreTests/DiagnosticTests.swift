import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("Diagnostic")
struct DiagnosticTests {

    private func range(_ file: String = "t.meridian", line: Int = 6, col: Int = 10, endCol: Int = 22) -> SourceRange {
        SourceRange(file: file, startLine: line, startColumn: col, endLine: line, endColumn: endCol)
    }

    private func validationDiagnostics(_ expression: IRExpression) -> [Diagnostic] {
        do {
            try IRValidator.validate(expression, sourceFile: "invalid.ir")
            return []
        } catch IRValidationError.diagnostics(let diagnostics) {
            return diagnostics
        } catch {
            Issue.record("unexpected validation error: \(error)")
            return []
        }
    }

    private func validationDiagnostics(_ workflows: [IRWorkflow]) -> [Diagnostic] {
        do {
            try IRValidator.validate(workflows, sourceFile: "invalid.ir")
            return []
        } catch IRValidationError.diagnostics(let diagnostics) {
            return diagnostics
        } catch {
            Issue.record("unexpected validation error: \(error)")
            return []
        }
    }

    // MARK: Always-on guarantee

    @Test("unresolved within budget attaches a did-you-mean suggestion")
    func unresolvedSuggests() {
        let d = Diagnostic.unresolved(.unknownTool, target: "chargePaymnt",
                                      among: ["chargePayment", "refundPayment"],
                                      range: range(), noun: "tool")
        #expect(d.suggestions.count == 1)
        #expect(d.suggestions.first?.replacement == "chargePayment")
        #expect(d.suggestions.first?.range != nil)
        #expect(d.suggestions.first?.rationale.contains("did you mean") == true)
    }

    @Test("unresolved with nothing close attaches a candidate-list note, never bare")
    func unresolvedFallsBackToNote() {
        let d = Diagnostic.unresolved(.unknownTool, target: "zzzzzz",
                                      among: ["chargePayment", "refundPayment"],
                                      range: range(), noun: "tool")
        #expect(d.suggestions.isEmpty)
        #expect(d.notes.count == 1)
        #expect(d.notes.first?.message.contains("chargePayment") == true)
    }

    @Test("unresolved with empty candidate set still gives an actionable note")
    func unresolvedEmptyCandidates() {
        let d = Diagnostic.unresolved(.unknownVocabulary, target: "missing",
                                      among: [], range: range(), noun: "vocabulary")
        #expect(d.suggestions.isEmpty)
        #expect(d.notes.count == 1)
    }

    @Test("unresolved with many candidates lists a ranked top subset")
    func unresolvedManyCandidates() {
        let many = (1...20).map { "candidate\($0)" }
        let d = Diagnostic.unresolved(.unknownTool, target: "zzzzzzzzzz",
                                      among: many, range: range(), noun: "tool")
        #expect(d.suggestions.isEmpty)
        guard let note = d.notes.first?.message else {
            Issue.record("expected candidate-list note"); return
        }
        #expect(note.contains("total"))
        #expect(note.contains("candidate"))
    }

    // MARK: The guard test that makes "always-on" load-bearing

    @Test("every nameResolution code yields a suggestion or candidate-list note")
    func everyNameResolutionCodeIsGuided() {
        let r = range()
        for code in DiagnosticCode.all where code.kind == .nameResolution {
            // With a near candidate → suggestion.
            let near = Diagnostic.unresolved(code, target: "chargePaymnt",
                                             among: ["chargePayment"], range: r)
            #expect(!near.suggestions.isEmpty,
                    Comment(rawValue: "\(code.id) produced no suggestion for a near candidate"))
            // With only far candidates → candidate-list note (never bare).
            let far = Diagnostic.unresolved(code, target: "zzzzzzzzzz",
                                            among: ["alpha", "beta"], range: r)
            #expect(!far.suggestions.isEmpty || !far.notes.isEmpty,
                    Comment(rawValue: "\(code.id) produced neither suggestion nor note"))
        }
    }

    @Test("every structural code can carry non-empty help")
    func structuralCodesCarryHelp() {
        let r = range()
        for code in DiagnosticCode.all where code.kind == .structural {
            let d = Diagnostic.structural(code, message: "x", range: r, help: "do the fix")
            #expect(d.help?.isEmpty == false,
                    Comment(rawValue: "\(code.id) lost its help"))
        }
    }

    // MARK: Catalog integrity

    @Test("catalog ids are unique and explanations non-empty")
    func catalogIntegrity() {
        let ids = DiagnosticCode.all.map(\.id)
        #expect(Set(ids).count == ids.count, Comment(rawValue: "duplicate diagnostic code ids"))
        for code in DiagnosticCode.all {
            #expect(!code.explanation.isEmpty, Comment(rawValue: "\(code.id) has no explanation"))
            #expect(DiagnosticCode.lookup(code.id) != nil)
        }
    }

    // MARK: Human rendering (UI snapshot of the marquee shape)

    @Test("human renderer draws a caret and the did-you-mean hint")
    func humanRender() {
        let source = """
        ---
        vocabulary: t.merconfig
        ---
        To process an order:
          invoke chargePaymnt with order = the order.
        """
        let d = Diagnostic.unresolved(.unknownTool, target: "chargePaymnt",
                                      among: ["chargePayment"],
                                      range: SourceRange(file: "t.meridian", startLine: 5, startColumn: 10, endLine: 5, endColumn: 22),
                                      noun: "tool")
        let out = DiagnosticRenderer(sources: ["t.meridian": source]).render(d)
        #expect(out.contains("[\(DiagnosticCode.unknownTool.id)]"))
        #expect(out.contains("^"))
        #expect(out.contains("did you mean \"chargePayment\"?"))
        #expect(out.contains("meridian explain-diag \(DiagnosticCode.unknownTool.id)"))
        // rationale surfaced inline.
        #expect(out.contains("D-DX-5"))
    }

    @Test("JSON renderer emits a stable schema incl. decision id")
    func jsonRender() throws {
        let related = SourceRange(file: "t.merconfig", line: 2, column: 1)
        let d = Diagnostic.unresolved(.unknownTool, target: "chargePaymnt",
                                      among: ["chargePayment"], range: range(), noun: "tool")
        let enriched = Diagnostic(
            code: d.code, severity: d.severity, message: d.message,
            primaryRange: d.primaryRange, suggestions: d.suggestions, notes: d.notes,
            help: d.help, phase: "parse", relatedRanges: [related])
        let json = try DiagnosticRenderer().renderJSON([enriched])
        let data = json.data(using: .utf8)!
        let arr = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        #expect(arr.count == 1)
        #expect(arr[0]["code"] as? String == DiagnosticCode.unknownTool.id)
        #expect(arr[0]["severity"] as? String == "error")
        #expect(arr[0]["decision"] as? String == "D-DX-5")
        #expect(arr[0]["phase"] as? String == "parse")
        let relatedArr = arr[0]["related"] as! [[String: Any]]
        #expect(relatedArr.first?["file"] as? String == "t.merconfig")
        let suggestions = arr[0]["suggestions"] as! [[String: Any]]
        #expect(suggestions.first?["replacement"] as? String == "chargePayment")
    }

    @Test("human renderer shows phase and related ranges when present")
    func humanRenderPhaseAndRelated() {
        let related = SourceRange(file: "cfg.merconfig", line: 4, column: 1)
        let d = Diagnostic.error(
            .duplicateDeclaration,
            message: "duplicate kind `order`",
            range: range(),
            help: "rename one declaration",
            phase: "bootstrap",
            relatedRanges: [related])
        let out = DiagnosticRenderer(sources: ["t.meridian": "x"]).render(d)
        #expect(out.contains("phase"))
        #expect(out.contains("bootstrap"))
        #expect(out.contains("related"))
        #expect(out.contains("cfg.merconfig:4:1"))
    }

    @Test("Diagnostic.error auto-fills help from catalog explanation")
    func errorAutoFillsHelp() {
        let d = Diagnostic.error(.invalidIR, message: "bad ir", range: range())
        #expect(d.help == DiagnosticCode.invalidIR.explanation)
    }

    @Test("unresolved ambiguous near-misses list alternates instead of auto-suggesting")
    func unresolvedAmbiguousNearMisses() {
        let d = Diagnostic.unresolved(.unknownTool, target: "paymnt",
                                      among: ["payment", "paymet"],
                                      range: range(), noun: "tool")
        #expect(d.suggestions.isEmpty)
        #expect(d.notes.first?.message.contains("payment") == true)
        #expect(d.notes.first?.message.contains("paymet") == true)
    }

    @Test("recovering collects thrown lowering errors once without duplicate pre-report")
    func recoveringDoesNotDuplicateLoweringDiagnostics() throws {
        let engine = DiagnosticEngine()
        let r = range()
        let diag = Diagnostic.error(.unresolvedPhrase, message: "unknown phrase", range: r, help: "fix it")
        _ = try engine.recovering(context: "workflow test") {
            throw CompilerError.diagnostics([diag])
        }
        let matches = engine.diagnostics.filter { $0.code == .unresolvedPhrase && $0.message == "unknown phrase" }
        #expect(matches.count == 1)
    }

    // MARK: CompilerError projection

    @Test("CompilerError.diagnostics projects the structured case")
    func compilerErrorProjection() {
        let d = Diagnostic.unresolved(.unknownTool, target: "x", among: ["y"], range: range(), noun: "tool")
        let err = CompilerError.diagnostics([d])
        #expect(err.diagnostics.count == 1)
        #expect(err.diagnostics.first?.code == .unknownTool)
    }

    @Test("catalog metadata covers every DiagnosticCode.all entry")
    func catalogMetadataComplete() {
        #expect(DiagnosticCode.catalog.count == DiagnosticCode.all.count)
        for code in DiagnosticCode.all {
            guard let entry = DiagnosticCode.catalogByID[code.id] else {
                Issue.record("missing catalog metadata for \(code.id)")
                continue
            }
            switch entry.status {
            case .active:
                #expect(!entry.emitters.isEmpty, Comment(rawValue: "\(code.id) has no production emitter listed"))
            case .reserved, .deprecated:
                #expect(entry.emitters.isEmpty, Comment(rawValue: "\(code.id) \(entry.status.rawValue) but has emitters"))
            }
        }
    }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Maps every `public static let <name> = DiagnosticCode(id: "MER-...")`
    /// declaration in `DiagnosticCode.swift` to its Swift case name, so the
    /// catalog's `emitters` list can be checked against the *actual* source
    /// rather than trusted at face value.
    private func diagnosticCaseNames() throws -> [String: String] {
        let url = repoRoot.appendingPathComponent("Sources/MeridianCore/Diagnostics/DiagnosticCode.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let regex = try NSRegularExpression(
            pattern: #"public static let (\w+) = DiagnosticCode\(\s*id: "([^"]+)""#
        )
        let range = NSRange(source.startIndex..., in: source)
        var result: [String: String] = [:]
        regex.enumerateMatches(in: source, range: range) { match, _, _ in
            guard let match, match.numberOfRanges == 3,
                  let nameRange = Range(match.range(at: 1), in: source),
                  let idRange = Range(match.range(at: 2), in: source) else { return }
            result[String(source[idRange])] = String(source[nameRange])
        }
        return result
    }

    /// Every `.swift` file under `Sources/`, keyed by filename (unique in this
    /// repo), so an `emitters` entry like `"ASTToIR.swift:lowerEventSubject"`
    /// can be resolved back to a real file on disk.
    private func sourceFilesByName() -> [String: URL] {
        let sourcesRoot = repoRoot.appendingPathComponent("Sources")
        guard let enumerator = FileManager.default.enumerator(at: sourcesRoot, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var byName: [String: URL] = [:]
        for entry in enumerator {
            guard let url = entry as? URL, url.pathExtension == "swift" else { continue }
            byName[url.lastPathComponent] = url
        }
        return byName
    }

    /// D-DX-4/AGENTS.md pitfall #11: a catalog entry listing
    /// a file as an emitter is a *claim*, not proof — this test loads each
    /// listed file's real source and requires the diagnostic's own case name
    /// (`.traceUnknownStep`, etc.) to actually appear in it, so a phantom
    /// emitter (declared in the catalog, never wired in `Sources/`) fails the
    /// build instead of silently shipping as documented-but-unimplemented.
    @Test("every active code's listed emitter file actually references it")
    func activeEmittersAreReal() throws {
        let caseNames = try diagnosticCaseNames()
        let filesByName = sourceFilesByName()
        var fileCache: [URL: String] = [:]
        for code in DiagnosticCode.all {
            guard let entry = DiagnosticCode.catalogByID[code.id], entry.status == .active else { continue }
            guard let caseName = caseNames[code.id] else {
                Issue.record("no DiagnosticCode.swift case found for \(code.id)")
                continue
            }
            let needle = ".\(caseName)"
            var found = false
            for emitter in entry.emitters {
                let filename = String(emitter.split(separator: ":", maxSplits: 1).first ?? Substring(emitter))
                guard let fileURL = filesByName[filename] else { continue }
                let source: String
                if let cached = fileCache[fileURL] {
                    source = cached
                } else {
                    source = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
                    fileCache[fileURL] = source
                }
                if source.contains(needle) {
                    found = true
                    break
                }
            }
            #expect(found, Comment(rawValue: "\(code.id) (.\(caseName)) lists emitter(s) \(entry.emitters) but none reference `\(needle)`"))
        }
    }

    @Test("unknown trace category validates to unknownTraceCategory")
    func unknownTraceCategory() {
        let ds = ParserTrace.validateTraceSpec("not-a-real-category")
        #expect(ds.count == 1)
        #expect(ds.first?.code == .unknownTraceCategory)
    }

    // MARK: New codes (Diagnostics Tracing Overhaul)

    /// `MER2011` guards `ASTToIR.lowerPhraseInvocation`'s workflow-call
    /// argument mapping (`Sources/MeridianCore/Lowering/ASTToIR.swift`,
    /// `ordered.map`): every declared workflow parameter must find a matching
    /// key in the extracted `args` dict, under one of a few name/kind/spacing
    /// variants. `SymbolTable.extractArgs` currently populates an entry for
    /// EVERY parameter segment of the winning pattern unconditionally (even an
    /// under-supplied invocation just gets an empty/malformed value for the
    /// unfilled slot) — so this `throw` is a hardening guard against a FUTURE
    /// regression reintroducing the original silent `compactMap`-drop, not a
    /// live-fire path under the current architecture. It is still registered,
    /// catalogued, and rendered exactly like every other diagnostic.
    @Test("missing phrase argument renders with a did-you-mean-shaped candidate list")
    func missingPhraseArgumentRenders() {
        let d = Diagnostic.unresolved(.missingPhraseArgument, target: "accountManager",
                                      among: ["order", "customer"], range: range(), noun: "phrase argument")
        #expect(d.code == .missingPhraseArgument)
        #expect(d.code.kind == .nameResolution)
        #expect(!d.suggestions.isEmpty || !d.notes.isEmpty)
    }

    /// `MER3016` fires when a rule's predicate parses to an expression shape a
    /// rule body cannot express (quantifiers, descriptions, aggregates,
    /// superlatives, relation traversals, verb predicates, data tables, or a
    /// parse-error carrier) — see `NoSilentFallbackTests.unlowerableRulePredicate`
    /// for the end-to-end compile trigger.
    @Test("unlowerable rule predicate carries actionable rewrite help")
    func unlowerableRulePredicateStructural() {
        let d = Diagnostic.error(.unlowerableRulePredicate, message: "x",
                                 range: range(), help: "rewrite the predicate")
        #expect(d.code == .unlowerableRulePredicate)
        #expect(d.help == "rewrite the predicate")
    }

    @Test("unknown test-spec key validates to invalidTestSpecKey")
    func unknownTestSpecKey() {
        let spec = """
        source_inline: ```
        to x:
          emit y.
        ```
        bad_key: oops
        """
        do {
            _ = try SpecParser().parse(spec, fileURL: URL(fileURLWithPath: "/tmp/t.meridian.test"))
            Issue.record("expected invalidTestSpecKey")
        } catch let e as CompilerError {
            #expect(e.diagnostics.first?.code == .invalidTestSpecKey)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("IRValidator reports invalidIR for malformed expressions")
    func invalidIRValidation() {
        do {
            try IRValidator.validate(IRExpression.logical(.and, []), sourceFile: "invalid.ir")
            Issue.record("expected invalidIR")
        } catch IRValidationError.diagnostics(let diagnostics) {
            let invalid = diagnostics.first { $0.code == .invalidIR }
            #expect(invalid != nil)
            #expect(invalid?.help?.isEmpty == false)
            #expect(invalid?.phase == "validation")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("IRValidator reports matchBranchSemantic for malformed matches")
    func matchSemanticValidation() {
        let done = IRBlock(statements: [.complete(CompleteIR())])
        let branch = IRPrimitive.branch(BranchIR(
            condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .wildcard, block: done),
                BranchCase(pattern: .wildcard, block: done),
            ]),
            thenBlock: done
        ))
        let workflow = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: [branch]))

        do {
            try IRValidator.validate(workflow, sourceFile: "invalid.ir")
            Issue.record("expected matchBranchSemantic")
        } catch IRValidationError.diagnostics(let diagnostics) {
            #expect(diagnostics.contains { $0.code == .matchBranchSemantic })
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("IRValidator rejects malformed expression shapes")
    func irValidatorExpressionRejections() {
        let malformed: [(IRExpression, String)] = [
            (.propertyAccess(.identifierRef(name: "order"), propertyName: " "), "empty property name"),
            (.relationTraversal(.identifierRef(name: "order"), relationName: " ", target: .identifierRef(name: "customer")), "empty relation name"),
            (.logical(.and, []), "logical and expression has no operands"),
            (.logical(.or, []), "logical or expression has no operands"),
            (.logical(.not, []), "logical not expression has no operands"),
            (.logical(.not, [.literal(.boolean(true)), .literal(.boolean(false))]), "logical not expression has more than one operand"),
            (.invocation(InvokeIR(toolID: "demo.tool")), "inline invocation demo.tool cannot be emitted in expression position"),
            (.recordList(fields: [], rows: []), "record list has no fields"),
            (.recordList(fields: ["name", " "], rows: []), "record list contains an empty field name"),
            (.recordList(fields: ["name"], rows: [[.literal(.string("Ada")), .literal(.string("Lovelace"))]]), "record list row has 2 cells for 1 fields"),
            (.tableLookup(table: "", keyColumn: "id", key: .literal(.string("o-1")), valueColumn: "status"), "table lookup contains an empty table or column name"),
            (.definitionPredicate(functionName: " ", subject: .identifierRef(name: "order")), "definition predicate has an empty function name"),
            (.description(DescriptionIR(collection: .identifierRef(name: "orders"), elementVar: " ")), "description has an empty element variable"),
            (.description(DescriptionIR(collection: .identifierRef(name: "orders"), elementVar: "order", sort: IRSortSpec(path: "", ascending: true))), "description has an empty sort path"),
            (.superlative(SuperlativeIR(description: DescriptionIR(collection: .identifierRef(name: "orders"), elementVar: "order"), sortPath: " ", ascending: true)), "superlative has an empty sort path"),
            (.interpolatedString([.forEach(variable: " ", collection: .identifierRef(name: "items"), body: [.literal("x")])]), "interpolated string loop has an empty variable"),
            (.interpolatedString([.formatted(.identifierRef(name: "score"), formatter: " ")]), "interpolated string formatter is empty"),
        ]

        for (expression, expected) in malformed {
            let diagnostics = validationDiagnostics(expression)
            #expect(diagnostics.contains { $0.code == .invalidIR && $0.message.contains(expected) },
                    Comment(rawValue: "missing \(expected) in \(diagnostics.map(\.message))"))
        }

        let discretion = validationDiagnostics(.invocation(InvokeIR(
            toolID: "runtime.discretion.decide",
            arguments: [InvokeArg("question", .literal(.string("continue?")))]
        )))
        #expect(discretion.isEmpty)

        do {
            try IRValidator.validate(IRWorkflow(
                name: "valid",
                parameters: [],
                body: IRBlock(statements: [.complete(CompleteIR())]),
                sourceFile: "workflow-source.meri"
            ))
        } catch {
            Issue.record("expected valid workflow to pass validation: \(error)")
        }
    }

    @Test("IRValidator rejects malformed statement IR")
    func irValidatorStatementRejections() {
        let done = IRBlock(statements: [.complete(CompleteIR())])
        let target = IRWorkflow(
            name: "target",
            parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
            body: done,
            explicitStructName: "Target"
        )
        let multiParamTarget = IRWorkflow(
            name: "multi target",
            parameters: [
                IRParameter(name: "order", kind: KindRef("Order")),
                IRParameter(name: "customer", kind: KindRef("Customer")),
            ],
            body: done,
            explicitStructName: "MultiTarget"
        )
        let invalids: [IRPrimitive] = [
            .invoke(InvokeIR(toolID: " ", arguments: [
                InvokeArg(" ", .literal(.string("x"))),
                InvokeArg("dup", .literal(.string("one"))),
                InvokeArg("dup", .literal(.string("two"))),
            ])),
            .invoke(InvokeIR(toolID: "demo.tool", arguments: [
                InvokeArg(" ", .literal(.string("x"))),
            ])),
            .invoke(InvokeIR(toolID: "workflow:Target", arguments: [])),
            .invoke(InvokeIR(toolID: "workflow:MultiTarget", arguments: [])),
            .emit(EmitIR(eventID: "audit", payload: [EmitField(" ", .literal(.string("x")))])),
            .iterate(IterateIR(
                mode: .overCollection(parameter: " ", kind: KindRef("Order"), collection: .identifierRef(name: "orders")),
                body: done,
                source: IRIterationRefinement(sort: IRSortSpec(path: " ", ascending: true))
            )),
            .wait(WaitIR(condition: .signal(" "))),
            .wait(WaitIR(condition: .approval(of: .identifierRef(name: "order"), by: " "))),
            .wait(WaitIR(condition: .event(" ", matching: nil))),
            .wait(WaitIR(condition: .choice(prompt: " ", options: ["approve"]))),
            .wait(WaitIR(condition: .choice(prompt: "choose", options: []))),
            .wait(WaitIR(condition: .choice(prompt: "choose", options: ["approve", " "]))),
            .recover(RecoverIR(pattern: .named(" "), handler: done, attachedTo: done)),
            .recover(RecoverIR(pattern: .typed(KindRef(" ")), handler: done, attachedTo: done)),
            .recover(RecoverIR(pattern: .predicate(.logical(.and, [])), handler: done, attachedTo: done)),
            .assert(AssertIR(condition: .literal(.boolean(false)), otherwiseAction: IRBlock(statements: [
                .bind(BindIR(name: "bad", expression: .logical(.and, [])))
            ]))),
        ]
        let workflow = IRWorkflow(name: "caller", parameters: [], body: IRBlock(statements: invalids))
        let diagnostics = validationDiagnostics([target, multiParamTarget, workflow])
        let expected = [
            "invoke has an empty tool id",
            "invoke <empty> has an empty argument key",
            "invoke demo.tool has an empty argument key",
            "invoke  repeats argument dup",
            "workflow invoke workflow:Target is missing argument order",
            "workflow invoke workflow:MultiTarget is missing arguments order, customer",
            "emit payload contains an empty field key",
            "iteration has an empty parameter name",
            "iteration refinement has an empty sort path",
            "wait signal is empty",
            "wait approval approver is empty",
            "wait event is empty",
            "choice prompt is empty",
            "choice options must be non-empty strings",
            "recover pattern name is empty",
            "recover pattern kind is empty",
            "logical and expression has no operands",
        ]
        for message in expected {
            #expect(diagnostics.contains { $0.code == .invalidIR && $0.message.contains(message) },
                    Comment(rawValue: "missing \(message) in \(diagnostics.map(\.message).joined(separator: "\n"))"))
        }
    }

    @Test("IRValidator rejects malformed match-branch semantics")
    func irValidatorMatchBranchSemanticRejections() {
        let done = IRBlock(statements: [.complete(CompleteIR())])
        let empty = IRBlock(statements: [])
        let date = Date(timeIntervalSince1970: 42)
        let branches: [IRPrimitive] = [
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), []), thenBlock: empty)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), []), thenBlock: done)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .literal(.string("ready")), block: done),
                BranchCase(pattern: .literal(.string("ready")), block: done),
            ]), thenBlock: empty)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .wildcard, block: done),
                BranchCase(pattern: .wildcard, block: done),
            ]), thenBlock: done)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .enumValue("approved", kind: "Status"), block: empty),
            ]), thenBlock: empty)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .literal(.number(Decimal(7))), block: done),
                BranchCase(pattern: .literal(.number(Decimal(7))), block: done),
            ]), thenBlock: empty)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .literal(.boolean(true)), block: done),
                BranchCase(pattern: .literal(.boolean(true)), block: done),
            ]), thenBlock: empty)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .literal(.money(Decimal(10), currency: "USD")), block: done),
                BranchCase(pattern: .literal(.money(Decimal(10), currency: "USD")), block: done),
            ]), thenBlock: empty)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .literal(.duration(.seconds(5))), block: done),
                BranchCase(pattern: .literal(.duration(.seconds(5))), block: done),
            ]), thenBlock: empty)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .literal(.date(date)), block: done),
                BranchCase(pattern: .literal(.dateTime(date)), block: done),
            ]), thenBlock: empty)),
            .branch(BranchIR(condition: .match(.identifierRef(name: "choice"), [
                BranchCase(pattern: .literal(.enumValue("approved", kind: "Status")), block: done),
                BranchCase(pattern: .literal(.enumValue("approved", kind: "Status")), block: done),
            ]), thenBlock: empty)),
        ]

        let diagnostics = validationDiagnostics([
            IRWorkflow(name: "match coverage", parameters: [], body: IRBlock(statements: branches), sourceFile: "source.meri")
        ])
        let expected = [
            "match branch has no case arms",
            "match branch has an otherwise arm but no case arms",
            "match branch repeats pattern ready",
            "match branch declares multiple wildcard/default arms",
            "match branch approved has no statements",
        ]
        for message in expected {
            #expect(diagnostics.contains { $0.code == .matchBranchSemantic && $0.message.contains(message) },
                    Comment(rawValue: "missing \(message) in \(diagnostics.map(\.message).joined(separator: "\n"))"))
        }
    }

    @Test("DiagnosticEngine recovery attaches skip notes and one MER6004 summary")
    func diagnosticEngineRecoverySummaryAndNotes() throws {
        let cap = ParserTrace.capturing(categories: [.diagnostics])
        let engine = DiagnosticEngine()
        let r = range("broken.meridian", line: 2, col: 3, endCol: 14)

        let recovered: Int? = try cap.trace.run {
            try engine.recovering(context: "workflow process order") {
                throw CompilerError.diagnostics([
                    Diagnostic.error(.unresolvedPhrase, message: "unknown phrase", range: r)
                ])
            }
        }
        #expect(recovered == nil)
        #expect(engine.diagnostics.last?.notes.contains {
            $0.message.contains("skipped workflow process order")
        } == true)

        let recoveredEmpty: Int? = try engine.recovering(context: "empty diagnostic probe") {
            throw CompilerError.diagnostics([])
        }
        #expect(recoveredEmpty == nil)
        let recoveredDefault: Int? = try engine.recovering {
            throw CompilerError.diagnostics([])
        }
        #expect(recoveredDefault == nil)
        #expect(engine.skippedConstructs == ["workflow process order", "empty diagnostic probe", "construct"])

        do {
            try engine.throwIfErrors()
            Issue.record("expected aggregated diagnostics")
        } catch let error as CompilerError {
            let diagnostics = error.diagnostics
            #expect(diagnostics.contains { $0.code == .diagnosticRecoverySummary && $0.message.contains("3 constructs skipped") })
            #expect(diagnostics.contains { diagnostic in
                diagnostic.code == .diagnosticRecoverySummary
                    && diagnostic.notes.contains { $0.message.contains("empty diagnostic probe") && $0.message.contains("workflow process order") }
            })
        }
        do {
            try engine.throwIfErrors()
            Issue.record("expected aggregated diagnostics on second throw")
        } catch let error as CompilerError {
            #expect(error.diagnostics.filter { $0.code == .diagnosticRecoverySummary }.count == 1)
        }
        #expect(cap.lines().contains { $0.contains("skipped workflow process order") })
    }

    @Test("explain-diag worked examples cover the DX closeout codes")
    func explainDiagExamplesForDXCodes() throws {
        let required = [
            "MER1012", "MER3016", "MER3017", "MER3018", "MER4002",
            "MER5011", "MER6001", "MER6002", "MER6003", "MER6004",
        ]
        for id in required {
            let code = try #require(DiagnosticCode.lookup(id))
            let examples = ExplainDiagExamples.examples(for: code)
            #expect(!examples.isEmpty, Comment(rawValue: "\(id) missing worked examples"))
            #expect(examples.allSatisfy { !$0.before.isEmpty && !$0.after.isEmpty })
        }
    }
}
