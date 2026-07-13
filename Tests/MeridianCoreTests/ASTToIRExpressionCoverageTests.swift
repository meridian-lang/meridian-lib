import Foundation
import Testing
@testable import MeridianCore
import MeridianRuntime

/// Direct coverage for reachable `ASTToIR+Expression` helper arms that the
/// end-to-end corpus does not always hit (kind-backed payload schemas,
/// implicit cross-skill scope, `since` holds that are already event patterns,
/// statistical asserts missing a monitor cadence).
@Suite("ASTToIR+Expression helper coverage")
struct ASTToIRExpressionCoverageTests {

    @Test("knownPayloadFields unions kind properties; payloadFieldName default is nil")
    func knownPayloadFieldsAndPayloadFieldName() throws {
        let config = MerConfigFile(vocabulary: [
            .kind(KindDeclaration(name: "deploy", parent: "thing", sourceLine: 1)),
            .property(PropertyDeclaration(
                kind: "deploy",
                properties: [PropertyEntry(name: "region", type: .explicit("string"))],
                sourceLine: 2
            )),
        ])
        let symbols = SymbolTable.build(from: config, trace: .silent())
        let ir = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent())
        let fields = try #require(ir.knownPayloadFields(forSubjectNamed: "deploy"))
        #expect(fields.contains("region"))
        #expect(ir.payloadFieldName(IRExpression.literal(.boolean(true))) == nil)
        #expect(ir.payloadFieldName(IRExpression.identifierRef(name: "region")) == "region")
    }

    @Test("currentRun scope with stepOfSkill subject becomes acrossSkills after allow-list check")
    func implicitCrossSkillScopeFromStepOfSkill() throws {
        let symbols = SymbolTable.build(from: MerConfigFile(), trace: .silent())
        symbols.traceConfiguration = TraceConfigurationAST(
            crossSkillAllowList: .init(["briefing"], file: "t.merconfig", line: 1)
        )
        let ir = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent())
        let scope = try ir.resolveTraceScope(
            declared: .currentRun,
            subjects: [.stepOfSkill(step: "fetch", skill: "briefing")],
            line: 1
        )
        #expect(scope == .acrossSkills(["briefing"]))
    }

    @Test("resolveSinceHolds accepts a direct event-pattern holds expression")
    func resolveSinceHoldsDirectEventPattern() throws {
        let ir = ASTToIR(symbols: SymbolTable(trace: .silent()), sourceFile: "t.meridian", trace: .silent())
        let pattern = EventPatternIR(subject: .step("deploy"), outcome: .failed)
        let resolved = try ir.resolveSinceHolds(.eventPattern(pattern), line: 1)
        #expect(resolved.holdsPattern?.outcome == .failed)
        #expect(resolved.usesStateHistory == false)
    }

    @Test("resolveSinceHolds inlines an adjective whose body is an event pattern")
    func resolveSinceHoldsAdjectiveEventBody() throws {
        let symbols = SymbolTable(trace: .silent())
        symbols.registerDefinition(SymbolTable.DefinitionRecord(
            adjective: "stale",
            kind: "service",
            subjectVar: "service",
            body: .eventPattern(EventPatternAST(
                subject: .step("deploy"),
                outcome: .failed
            )),
            functionName: "service_is_stale",
            sourceLine: 1
        ))
        let ir = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent())
        let holds = IRExpression.definitionPredicate(
            functionName: "service_is_stale",
            subject: .identifierRef(name: "service")
        )
        let resolved = try ir.resolveSinceHolds(holds, line: 1)
        #expect(resolved.holdsPattern?.outcome == .failed)
        #expect(resolved.usesStateHistory == false)
    }

    @Test("statistical assert without cadence or default monitor cadence is malformedCondition")
    func monitoredAssertRequiresCadence() throws {
        let ir = ASTToIR(symbols: SymbolTable(trace: .silent()), sourceFile: "t.meridian", trace: .silent())
        let statistical = TraceStatisticalIR(
            pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
            outcome: .fails,
            bound: .atLeast(0.5),
            denominator: .runs
        )
        let caught = #expect(throws: CompilerError.self) {
            try ir.monitoredAssertConfig(for: .traceStatistical(statistical), line: 1)
        }
        let err = try #require(caught)
        #expect(err.diagnostics.first?.code == .malformedCondition)
    }

    @Test("statistical payload whose-clause validates declared fields on a tool subject")
    func statisticalPayloadFieldValidation() throws {
        let config = MerConfigFile(tools: [
            ToolDeclaration(
                displayName: "Deploy Rollback",
                methodName: "deploy.rollback",
                parameters: [ToolParameterAST(name: "region", type: "String")],
                returnType: "void"
            ),
        ])
        let symbols = SymbolTable.build(from: config, trace: .silent())
        let ir = ASTToIR(symbols: symbols, sourceFile: "t.meridian", trace: .silent())
        let ok = try ir.lowerTraceStatistical(
            TraceStatisticalAST(
                scope: .currentRun,
                pattern: TraceStatisticalPatternAST(
                    subject: .step("deploy"),
                    payloadPredicate: .comparison(
                        .identifierRef("region"),
                        .equal,
                        .literal(.string("us-east"))
                    )
                ),
                outcome: .fails,
                bound: .atLeast(0.1),
                denominator: .runs
            ),
            scope: nil,
            line: 1
        )
        #expect(ok.pattern.payloadPredicate != nil)

        let bad = #expect(throws: CompilerError.self) {
            try ir.lowerTraceStatistical(
                TraceStatisticalAST(
                    scope: .currentRun,
                    pattern: TraceStatisticalPatternAST(
                        subject: .step("deploy"),
                        payloadPredicate: .comparison(
                            .identifierRef("unknown_field"),
                            .equal,
                            .literal(.string("x"))
                        )
                    ),
                    outcome: .fails,
                    bound: .atLeast(0.1),
                    denominator: .runs
                ),
                scope: nil,
                line: 1
            )
        }
        let err = try #require(bad)
        #expect(err.diagnostics.first?.code == .traceUnknownPayloadField)
    }
}
