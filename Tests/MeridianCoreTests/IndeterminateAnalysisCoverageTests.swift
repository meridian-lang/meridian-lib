import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

/// Direct coverage for `IndeterminateAnalysis` syntactic walker arms that
/// Broken Twin integration tests only hit indirectly.
@Suite("IndeterminateAnalysis coverage")
struct IndeterminateAnalysisCoverageTests {

    private var failedDeploy: EventPatternIR {
        EventPatternIR(subject: .step("deploy"), outcome: .failed)
    }

    private var statistical: IRExpression {
        .traceStatistical(TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
            outcome: .succeeds,
            bound: .atLeast(0.9),
            denominator: .runs
        ))
    }

    private var sinceLast: IRExpression {
        .traceTemporal(TraceTemporalIR(
            kind: .sinceLast(
                anchor: failedDeploy,
                holds: .eventPattern(failedDeploy),
                holdsPattern: failedDeploy,
                holdsUsesStateHistory: false
            )
        ))
    }

    private var ever: IRExpression {
        .traceTemporal(TraceTemporalIR(kind: .ever(failedDeploy)))
    }

    private func analysis(_ symbols: SymbolTable = SymbolTable()) -> IndeterminateAnalysis {
        IndeterminateAnalysis(symbols: symbols)
    }

    private func register(
        adjective: String,
        body: ExpressionAST,
        functionName: String,
        on symbols: SymbolTable
    ) {
        symbols.registerDefinition(SymbolTable.DefinitionRecord(
            adjective: adjective,
            kind: "service",
            subjectVar: "service",
            body: body,
            functionName: functionName,
            sourceLine: 1
        ))
    }

    @Test("leaf statistical and sinceLast are possibly indeterminate")
    func leafPositives() {
        let a = analysis()
        #expect(a.possiblyIndeterminate(statistical))
        #expect(a.possiblyIndeterminate(sinceLast))
    }

    @Test("non-sinceLast temporal kinds are not indeterminate")
    func temporalNegatives() {
        let a = analysis()
        #expect(!a.possiblyIndeterminate(ever))
        #expect(!a.possiblyIndeterminate(.traceTemporal(TraceTemporalIR(
            kind: .withinWindow(failedDeploy, duration: .seconds(5))
        ))))
        #expect(!a.possiblyIndeterminate(.traceTemporal(TraceTemporalIR(
            kind: .countInWindow(failedDeploy, comparator: .atLeast(1), duration: .seconds(60))
        ))))
        #expect(!a.possiblyIndeterminate(.traceTemporal(TraceTemporalIR(
            kind: .inARow(failedDeploy, count: 2)
        ))))
        #expect(!a.possiblyIndeterminate(.traceTemporal(TraceTemporalIR(
            kind: .boundedFutureMonitor(
                condition: .literal(.boolean(true)),
                horizon: .seconds(10),
                mode: .eventuallyWithin
            )
        ))))
    }

    @Test("structural IR recursion finds nested statistical leaves")
    func structuralIRMatrix() {
        let a = analysis()
        let lit = IRExpression.literal(.boolean(true))
        #expect(a.possiblyIndeterminate(.comparison(statistical, .equal, lit)))
        #expect(a.possiblyIndeterminate(.comparison(lit, .equal, statistical)))
        #expect(a.possiblyIndeterminate(.logical(.and, [lit, statistical])))
        #expect(a.possiblyIndeterminate(.propertyAccess(statistical, propertyName: "x")))
        #expect(a.possiblyIndeterminate(.invocation(InvokeIR(
            toolID: "t",
            arguments: [InvokeArg("p", statistical)]
        ))))
        #expect(a.possiblyIndeterminate(.eventPattern(EventPatternIR(
            subject: .step("deploy"),
            outcome: .failed,
            payloadPredicate: statistical
        ))))
        #expect(!a.possiblyIndeterminate(.eventPattern(failedDeploy)))
        #expect(!a.possiblyIndeterminate(.logical(.and, [lit, ever])))
        #expect(!a.possiblyIndeterminate(lit))
        #expect(!a.possiblyIndeterminate(.identifierRef(name: "x")))
    }

    @Test("definitionPredicate recurses into adjective bodies and cycle-guards")
    func definitionPredicateRecursion() {
        let symbols = SymbolTable()
        register(
            adjective: "reliable",
            body: .traceStatistical(TraceStatisticalAST(
                pattern: TraceStatisticalPatternAST(subject: .step("deploy")),
                outcome: .succeeds,
                bound: .atLeast(0.9),
                denominator: .runs
            )),
            functionName: "service_is_reliable",
            on: symbols
        )
        register(
            adjective: "stable",
            body: .logical(.and, [
                .identifierRef("reliable"),
                .literal(.boolean(true)),
            ]),
            functionName: "service_is_stable",
            on: symbols
        )
        register(
            adjective: "looped",
            body: .identifierRef("looped"),
            functionName: "service_is_looped",
            on: symbols
        )
        register(
            adjective: "ghosted",
            body: .identifierRef("ghost"),
            functionName: "service_is_ghosted",
            on: symbols
        )
        register(
            adjective: "nested",
            body: {
                let sinceAST = ExpressionAST.traceTemporal(TraceTemporalAST(
                    kind: .sinceLast(
                        anchor: EventPatternAST(subject: .step("deploy"), outcome: .failed),
                        holds: .literal(.boolean(true))
                    )
                ))
                let invokeBase = ExpressionAST.invoke("tool", [("p", sinceAST)])
                let lhs = ExpressionAST.propertyAccess(invokeBase, "ok")
                let comparison = ExpressionAST.comparison(
                    lhs,
                    .equal,
                    .literal(.boolean(true))
                )
                let payload = ExpressionAST.traceStatistical(TraceStatisticalAST(
                    pattern: TraceStatisticalPatternAST(subject: .step("deploy")),
                    outcome: .fails,
                    bound: .atMost(0.1),
                    denominator: .occurrences
                ))
                let event = ExpressionAST.eventPattern(EventPatternAST(
                    subject: .step("deploy"),
                    outcome: .failed,
                    payloadPredicate: payload
                ))
                return ExpressionAST.logical(.or, [comparison, event])
            }(),
            functionName: "service_is_nested",
            on: symbols
        )
        register(
            adjective: "ever_only",
            body: .traceTemporal(TraceTemporalAST(kind: .ever(
                EventPatternAST(subject: .step("deploy"), outcome: .failed)
            ))),
            functionName: "service_is_ever_only",
            on: symbols
        )
        register(
            adjective: "nil_payload",
            body: .eventPattern(EventPatternAST(subject: .step("deploy"), outcome: .failed)),
            functionName: "service_is_nil_payload",
            on: symbols
        )

        let a = analysis(symbols)
        #expect(a.possiblyIndeterminate(.definitionPredicate(
            functionName: "service_is_reliable",
            subject: .identifierRef(name: "service")
        )))
        #expect(a.possiblyIndeterminate(.definitionPredicate(
            functionName: "service_is_stable",
            subject: .identifierRef(name: "service")
        )))
        #expect(a.possiblyIndeterminate(.definitionPredicate(
            functionName: "service_is_nested",
            subject: .identifierRef(name: "service")
        )))
        #expect(!a.possiblyIndeterminate(.definitionPredicate(
            functionName: "service_is_looped",
            subject: .identifierRef(name: "service")
        )))
        #expect(!a.possiblyIndeterminate(.definitionPredicate(
            functionName: "service_is_ghosted",
            subject: .identifierRef(name: "service")
        )))
        #expect(!a.possiblyIndeterminate(.definitionPredicate(
            functionName: "missing_fn",
            subject: .identifierRef(name: "service")
        )))
        #expect(!a.possiblyIndeterminate(.definitionPredicate(
            functionName: "service_is_ever_only",
            subject: .identifierRef(name: "service")
        )))
        #expect(!a.possiblyIndeterminate(.definitionPredicate(
            functionName: "service_is_nil_payload",
            subject: .identifierRef(name: "service")
        )))
    }

    @Test("IR default arms stay determinate (no structural recursion)")
    func irDefaultArms() {
        let a = analysis()
        #expect(!a.possiblyIndeterminate(.literal(.boolean(true))))
        #expect(!a.possiblyIndeterminate(.quantified(QuantifierIR(
            kind: .any,
            description: DescriptionIR(
                collection: .identifierRef(name: "pages"),
                elementVar: "page",
                filters: []
            ),
            body: nil
        ))))
        // interpolatedString / recordList / tableLookup are not walked — SEM-6
        // only recurses through logical/comparison/property/invocation/event/definition.
        #expect(!a.possiblyIndeterminate(.interpolatedString([.expression(statistical)])))
        #expect(!a.possiblyIndeterminate(.recordList(fields: ["n"], rows: [[statistical]])))
        #expect(!a.possiblyIndeterminate(.tableLookup(
            table: "t", keyColumn: "k", key: statistical, valueColumn: "v"
        )))
    }
}
