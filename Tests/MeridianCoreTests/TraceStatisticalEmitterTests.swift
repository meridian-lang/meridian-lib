import Testing
@testable import MeridianCore
import MeridianRuntime

@Suite("TraceStatistical emitter")
struct TraceStatisticalEmitterTests {
    @Test("TraceStatistical emits runtime statistical evaluator call")
    func emitsRuntimeEvaluateTrace() throws {
        let workflow = IRWorkflow(
            name: "inspect",
            parameters: [],
            body: IRBlock(statements: [
                .branch(BranchIR(
                    condition: .predicate(.traceStatistical(TraceStatisticalIR(
                        scope: .currentRun,
                        pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
                        outcome: .succeeds,
                        bound: .atLeast(0.95),
                        denominator: .runs
                    ))),
                    thenBlock: IRBlock(statements: [.complete(CompleteIR(reason: "true"))]),
                    unknownBlock: IRBlock(statements: [.complete(CompleteIR(reason: "unknown"))]),
                    elseBlock: IRBlock(statements: [.complete(CompleteIR(reason: "false"))])
                ))
            ]),
            mode: .strict
        )

        let out = try SwiftEmitter(options: .init(includeTimestamp: false, emitSourceLineComments: false), trace: .silent())
            .emitFile(workflows: [workflow])

        #expect(out.contains("TraceStatisticalQuery("), Comment(rawValue: out))
        #expect(out.contains("runtime.evaluateTrace("), Comment(rawValue: out))
        #expect(out.contains("== .indeterminate"), Comment(rawValue: out))
    }

    @Test("TraceStatistical monitored assert emits registerMonitor")
    func emitsRegisterMonitor() throws {
        let workflow = IRWorkflow(
            name: "inspect",
            parameters: [],
            body: IRBlock(statements: [
                .assert(AssertIR(
                    condition: .traceStatistical(TraceStatisticalIR(
                        scope: .currentRun,
                        pattern: TraceStatisticalPatternIR(subject: .step("deploy")),
                        outcome: .fails,
                        bound: .atMost(0.1),
                        denominator: .occurrences,
                        monitorCadence: .seconds(300),
                        blocking: true
                    )),
                    message: "Expected deploy failures stay rare",
                    monitored: true,
                    cadence: .seconds(300),
                    blocking: true
                ))
            ]),
            mode: .strict
        )

        let out = try SwiftEmitter(options: .init(includeTimestamp: false, emitSourceLineComments: false), trace: .silent())
            .emitFile(workflows: [workflow])

        #expect(out.contains("runtime.registerMonitor("), Comment(rawValue: out))
        #expect(out.contains("blocking: true"), Comment(rawValue: out))
        #expect(out.contains("TraceStatisticalQuery("), Comment(rawValue: out))
    }
}
