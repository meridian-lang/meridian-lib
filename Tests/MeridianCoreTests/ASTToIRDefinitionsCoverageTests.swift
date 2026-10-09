import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

/// Exhaustive walker coverage for `ASTToIR+Definitions` IR-shape visitors
/// (`containsTraceTemporal`, `containsDirectSinceLast`, `attachSubjectKey`) —
/// arms that end-to-end definition corpora rarely exercise in isolation.
@Suite("ASTToIR+Definitions walker coverage")
struct ASTToIRDefinitionsCoverageTests {

    private let ir = ASTToIR(symbols: SymbolTable(trace: .silent()), sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())

    private var everFailed: IRExpression {
        .traceTemporal(TraceTemporalIR(
            scope: .currentRun,
            kind: .ever(EventPatternIR(subject: .step("deploy"), outcome: .failed))
        ))
    }

    private var sinceLast: IRExpression {
        .traceTemporal(TraceTemporalIR(
            scope: .currentRun,
            kind: .sinceLast(
                anchor: EventPatternIR(subject: .step("deploy"), outcome: .succeeded),
                holds: .eventPattern(EventPatternIR(subject: .step("deploy"), outcome: .failed)),
                holdsPattern: EventPatternIR(subject: .step("deploy"), outcome: .failed),
                holdsUsesStateHistory: false
            )
        ))
    }

    private func desc(_ filters: [IRExpression] = []) -> DescriptionIR {
        DescriptionIR(
            collection: .identifierRef(name: "pages"),
            elementVar: "page",
            filters: filters
        )
    }

    @Test("containsTraceTemporal walks nested IRExpression shapes")
    func containsTraceTemporalShapes() {
        #expect(ir.containsTraceTemporal(everFailed))
        #expect(!ir.containsTraceTemporal(.literal(.boolean(true))))
        #expect(ir.containsTraceTemporal(.comparison(everFailed, .equal, .literal(.boolean(true)))))
        #expect(ir.containsTraceTemporal(.logical(.and, [everFailed, .literal(.boolean(true))])))
        #expect(ir.containsTraceTemporal(.propertyAccess(everFailed, propertyName: "x")))
        #expect(ir.containsTraceTemporal(.relationTraversal(everFailed, relationName: "mentions", target: nil)))
        #expect(ir.containsTraceTemporal(.relationTraversal(
            .identifierRef(name: "a"), relationName: "mentions", target: everFailed)))
        #expect(ir.containsTraceTemporal(.invocation(InvokeIR(
            toolID: "t",
            arguments: [InvokeArg("x", everFailed)]
        ))))
        #expect(ir.containsTraceTemporal(.definitionPredicate(
            functionName: "f", subject: everFailed)))
        #expect(ir.containsTraceTemporal(.quantified(QuantifierIR(
            kind: .all, description: desc([everFailed]), body: nil))))
        #expect(ir.containsTraceTemporal(.quantified(QuantifierIR(
            kind: .all, description: desc(), body: everFailed))))
        #expect(ir.containsTraceTemporal(.description(desc([everFailed]))))
        #expect(ir.containsTraceTemporal(.aggregate(.count, desc([everFailed]))))
        #expect(ir.containsTraceTemporal(.superlative(SuperlativeIR(
            description: desc([everFailed]), sortPath: "age", ascending: true))))
        #expect(ir.containsTraceTemporal(.interpolatedString([
            .literal("a"),
            .expression(everFailed),
            .shellEscapedExpression(everFailed),
            .formatted(everFailed, formatter: "iso8601"),
            .conditional(condition: everFailed, then: [.literal("t")], otherwise: [.literal("e")]),
            .forEach(variable: "x", collection: everFailed, body: [.literal("b")]),
        ])))
        #expect(ir.containsTraceTemporal(.recordList(fields: ["a"], rows: [[everFailed]])))
        #expect(ir.containsTraceTemporal(.tableLookup(
            table: "t", keyColumn: "k", key: everFailed, valueColumn: "v")))
        #expect(ir.containsTraceTemporal(.eventPattern(EventPatternIR(
            subject: .step("deploy"),
            outcome: .failed,
            payloadPredicate: everFailed
        ))))
    }

    @Test("containsDirectSinceLast walks nested IRExpression shapes")
    func containsDirectSinceLastShapes() {
        #expect(ir.containsDirectSinceLast(sinceLast))
        #expect(!ir.containsDirectSinceLast(everFailed))
        #expect(ir.containsDirectSinceLast(.comparison(sinceLast, .equal, .literal(.boolean(true)))))
        #expect(ir.containsDirectSinceLast(.logical(.or, [sinceLast])))
        #expect(ir.containsDirectSinceLast(.propertyAccess(sinceLast, propertyName: "x")))
        #expect(ir.containsDirectSinceLast(.relationTraversal(sinceLast, relationName: "r", target: nil)))
        #expect(ir.containsDirectSinceLast(.relationTraversal(
            .identifierRef(name: "a"), relationName: "r", target: sinceLast)))
        #expect(ir.containsDirectSinceLast(.invocation(InvokeIR(
            toolID: "t", arguments: [InvokeArg("x", sinceLast)]))))
        #expect(ir.containsDirectSinceLast(.definitionPredicate(
            functionName: "f", subject: sinceLast)))
        #expect(ir.containsDirectSinceLast(.quantified(QuantifierIR(
            kind: .any, description: desc([sinceLast]), body: nil))))
        #expect(ir.containsDirectSinceLast(.quantified(QuantifierIR(
            kind: .any, description: desc(), body: sinceLast))))
        #expect(ir.containsDirectSinceLast(.description(desc([sinceLast]))))
        #expect(ir.containsDirectSinceLast(.aggregate(.list, desc([sinceLast]))))
        #expect(ir.containsDirectSinceLast(.superlative(SuperlativeIR(
            description: desc([sinceLast]), sortPath: "age", ascending: false))))
        #expect(ir.containsDirectSinceLast(.interpolatedString([
            .literal("a"),
            .expression(sinceLast),
            .shellEscapedExpression(sinceLast),
            .formatted(sinceLast, formatter: "iso8601"),
            .conditional(condition: sinceLast, then: [.literal("t")], otherwise: [.literal("e")]),
            .forEach(variable: "x", collection: sinceLast, body: [.literal("b")]),
        ])))
        #expect(ir.containsDirectSinceLast(.recordList(fields: ["a"], rows: [[sinceLast]])))
        #expect(ir.containsDirectSinceLast(.tableLookup(
            table: "t", keyColumn: "k", key: sinceLast, valueColumn: "v")))
        #expect(ir.containsDirectSinceLast(.eventPattern(EventPatternIR(
            subject: .step("deploy"),
            outcome: .failed,
            payloadPredicate: sinceLast
        ))))
        #expect(ir.assertNeedsExplicitDefaultPolicy(
            condition: sinceLast,
            otherwise: nil,
            monitored: false,
            blocking: true
        ))
        #expect(!ir.assertNeedsExplicitDefaultPolicy(
            condition: everFailed,
            otherwise: IRBlock(statements: [.complete(CompleteIR())]),
            monitored: false,
            blocking: true
        ))
        #expect(!ir.assertNeedsExplicitDefaultPolicy(
            condition: sinceLast,
            otherwise: nil,
            monitored: true,
            blocking: false
        ))
    }

    @Test("attachSubjectKey rewrites nested shapes and stamps subjectKeyExpr")
    func attachSubjectKeyShapes() {
        let stamped = ir.attachSubjectKey(everFailed, subjectVar: "service", keyProperty: "id")
        guard case .traceTemporal(let temporal) = stamped else {
            Issue.record("expected traceTemporal")
            return
        }
        #expect(temporal.subjectKeyExpr != nil)

        let statistical = ir.attachSubjectKey(
            .traceStatistical(TraceStatisticalIR(
                pattern: TraceStatisticalPatternIR(
                    subject: .step("deploy"),
                    payloadPredicate: .identifierRef(name: "region")
                ),
                outcome: .fails,
                bound: .atLeast(0.5),
                denominator: .runs
            )),
            subjectVar: "service",
            keyProperty: "id"
        )
        guard case .traceStatistical(let s) = statistical else {
            Issue.record("expected traceStatistical")
            return
        }
        #expect(s.subjectKeyExpr != nil)

        _ = ir.attachSubjectKey(
            .comparison(.identifierRef(name: "a"), .equal, .literal(.string("b"))),
            subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(
            .logical(.not, [.identifierRef(name: "a")]),
            subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(
            .propertyAccess(.identifierRef(name: "a"), propertyName: "b"),
            subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(
            .relationTraversal(.identifierRef(name: "a"), relationName: "r", target: .identifierRef(name: "b")),
            subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(
            .invocation(InvokeIR(toolID: "t", arguments: [InvokeArg("x", .identifierRef(name: "a"))])),
            subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(
            .definitionPredicate(functionName: "f", subject: .identifierRef(name: "a")),
            subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(
            .quantified(QuantifierIR(kind: .all, description: desc(), body: .literal(.boolean(true)))),
            subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(.description(desc()), subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(.aggregate(.count, desc()), subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(
            .superlative(SuperlativeIR(description: desc(), sortPath: "age", ascending: true)),
            subjectVar: "service", keyProperty: "id")
        _ = ir.attachSubjectKey(.literal(.boolean(true)), subjectVar: "service", keyProperty: "id")
    }

    @Test("registerDefinitions skips benign re-register and rejects collisions")
    func registerDefinitionsCollisionAndSkip() throws {
        let config = MerConfigFile(vocabulary: [
            .kind(KindDeclaration(name: "page", parent: "thing", sourceLine: 1)),
            .property(PropertyDeclaration(
                kind: "page",
                properties: [PropertyEntry(name: "owner", type: .explicit("string"))],
                sourceLine: 2
            )),
        ])
        let symbols = SymbolTable.build(from: config, trace: .silent())
        let ir = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
        let body = ExpressionAST.comparison(
            .propertyAccess(.identifierRef("page"), "owner"),
            .equal,
            .literal(.string("none"))
        )
        let first = DefinitionDeclaration(
            adjective: "orphaned",
            kind: "page",
            subjectVar: "page",
            body: body,
            sourceLine: 10
        )
        try ir.registerDefinitions([first])
        try ir.registerDefinitions([first]) // benign skip

        let clash = DefinitionDeclaration(
            adjective: "orphaned",
            kind: "service",
            subjectVar: "service",
            body: .literal(.boolean(true)),
            sourceLine: 11
        )
        do {
            try ir.registerDefinitions([clash])
            Issue.record("expected duplicateDeclaration")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .duplicateDeclaration })
        }
    }

    @Test("typeCheckDefinitionBody rejects unknown subject properties")
    func typeCheckUnknownProperty() throws {
        let config = MerConfigFile(vocabulary: [
            .kind(KindDeclaration(name: "page", parent: "thing", sourceLine: 1)),
            .property(PropertyDeclaration(
                kind: "page",
                properties: [PropertyEntry(name: "owner", type: .explicit("string"))],
                sourceLine: 2
            )),
        ])
        let symbols = SymbolTable.build(from: config, trace: .silent())
        let ir = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
        do {
            try ir.registerDefinitions([
                DefinitionDeclaration(
                    adjective: "broken",
                    kind: "page",
                    subjectVar: "page",
                    body: .comparison(
                        .propertyAccess(.identifierRef("page"), "missing"),
                        .equal,
                        .literal(.string("x"))
                    ),
                    sourceLine: 3
                )
            ])
            Issue.record("expected unknownProperty")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .unknownProperty })
        }
    }

    @Test("detectDefinitionRecursion catches transitive adjective cycles")
    func definitionRecursionCycle() throws {
        let symbols = SymbolTable(trace: .silent())
        let ir = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
        symbols.registerDefinition(.init(
            adjective: "alpha",
            kind: "page",
            subjectVar: "page",
            body: .comparison(.identifierRef("page"), .equal, .identifierRef("beta")),
            functionName: "meridianDef_Page_alpha",
            sourceLine: 1
        ))
        symbols.registerDefinition(.init(
            adjective: "beta",
            kind: "page",
            subjectVar: "page",
            body: .comparison(.identifierRef("page"), .equal, .identifierRef("alpha")),
            functionName: "meridianDef_Page_beta",
            sourceLine: 2
        ))
        do {
            try ir.detectDefinitionRecursion(start: "alpha")
            Issue.record("expected definitionRecursion")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .definitionRecursion })
        }
    }

    @Test("lowerRegisteredDefinitions requires key for trace-backed adjectives")
    func lowerUnkeyedTraceDefinition() throws {
        let config = MerConfigFile(vocabulary: [
            .kind(KindDeclaration(name: "service", parent: "thing", sourceLine: 1)),
        ])
        let symbols = SymbolTable.build(from: config, trace: .silent())
        let ir = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
        try ir.registerDefinitions([
            DefinitionDeclaration(
                adjective: "flaky",
                kind: "service",
                subjectVar: "service",
                body: .traceTemporal(TraceTemporalAST(kind: .ever(
                    EventPatternAST(subject: .step("deploy"), outcome: .failed)
                ))),
                sourceLine: 2
            )
        ])
        do {
            _ = try ir.lowerRegisteredDefinitions()
            Issue.record("expected traceUnkeyedDefinition")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .traceUnkeyedDefinition })
        }
    }

    @Test("resolveAdjectiveFilter throws unknownAdjective")
    func resolveUnknownAdjective() throws {
        let ir = ASTToIR(symbols: SymbolTable(trace: .silent()), sourceFile: "t.meridian", trace: .silent(), engine: DiagnosticEngine())
        do {
            _ = try ir.resolveAdjectiveFilter(
                adjective: "missing",
                subject: .identifierRef(name: "page"),
                sourceLine: 1
            )
            Issue.record("expected unknownAdjective")
        } catch let CompilerError.diagnostics(diags) {
            #expect(diags.contains { $0.code == .unknownAdjective })
        }
    }
}
