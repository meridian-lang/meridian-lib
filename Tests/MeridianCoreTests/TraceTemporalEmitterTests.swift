import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("TraceTemporal emitter")
struct TraceTemporalEmitterTests {
    @Test("TraceTemporal emits runtime evaluator call for direct condition")
    func emitsRuntimeEvaluateTrace() throws {
        let workflow = IRWorkflow(
            name: "inspect",
            parameters: [],
            body: IRBlock(statements: [
                .branch(BranchIR(
                    condition: .predicate(.traceTemporal(TraceTemporalIR(
                        scope: .currentRun,
                        kind: .ever(EventPatternIR(subject: .step("deploy"), outcome: .failed))
                    ))),
                    thenBlock: IRBlock(statements: [.complete(CompleteIR(reason: "true"))]),
                    elseBlock: IRBlock(statements: [.complete(CompleteIR(reason: "false"))])
                ))
            ]),
            mode: .strict
        )

        let out = try SwiftEmitter(options: .init(includeTimestamp: false, emitSourceLineComments: false), trace: .silent())
            .emit(workflows: [workflow]).combined

        #expect(out.contains("runtime.evaluateTrace("), Comment(rawValue: out))
        #expect(out.contains("evaluationInstant: await runtime.currentDate()"), Comment(rawValue: out))
    }

    @Test("TraceTemporal emits K3 branch routing for since-the-last")
    func emitsUnknownRouting() throws {
        let temporal = TraceTemporalIR(
            scope: .currentRun,
            kind: .sinceLast(
                anchor: EventPatternIR(subject: .step("deploy"), outcome: .succeeded),
                holds: .eventPattern(EventPatternIR(subject: .step("deploy"), outcome: .succeeded)),
                holdsPattern: EventPatternIR(subject: .step("deploy"), outcome: .succeeded),
                holdsUsesStateHistory: false
            )
        )
        let workflow = IRWorkflow(
            name: "inspect",
            parameters: [],
            body: IRBlock(statements: [
                .branch(BranchIR(
                    condition: .predicate(.traceTemporal(temporal)),
                    thenBlock: IRBlock(statements: [.complete(CompleteIR(reason: "true"))]),
                    unknownBlock: IRBlock(statements: [.complete(CompleteIR(reason: "unknown"))]),
                    elseBlock: IRBlock(statements: [.complete(CompleteIR(reason: "false"))])
                ))
            ]),
            mode: .strict
        )

        let out = try SwiftEmitter(options: .init(includeTimestamp: false, emitSourceLineComments: false), trace: .silent())
            .emit(workflows: [workflow]).combined

        #expect(out.contains("== .indeterminate"), Comment(rawValue: out))
        #expect(out.contains("let __meridianTruth_"), Comment(rawValue: out))
    }
}
