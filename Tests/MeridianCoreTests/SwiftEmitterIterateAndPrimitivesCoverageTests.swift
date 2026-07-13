import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

@Suite("SwiftEmitter+Iterate coverage")
struct SwiftEmitterIterateCoverageTests {
    private let e = SwiftEmitter()
    private var ctx: Ctx { Ctx(depth: 0, options: .init()) }

    @Test("iterate instrumentation helpers default step when stableStepPath is nil")
    func iterateHelpersNilStepPath() {
        #expect(e.emitIterateStartCall(ctx: ctx, over: "items", stableStepPath: nil).contains("\"iterate\""))
        #expect(e.emitIterateIterationCall(ctx: ctx, index: "i", stableStepPath: nil).contains("\"iterate\""))
        #expect(e.emitIterateEndCall(ctx: ctx, over: "items", count: "n", stableStepPath: nil).contains("\"iterate\""))
        #expect(e.emitIterateStartCall(ctx: ctx, over: "items", stableStepPath: "loop.1").contains("\"loop.1\""))
    }

    @Test("freshElementParam stays __e for empty env and numbers nested scopes")
    func freshElementParamNesting() {
        #expect(e.freshElementParam([:]) == "__e")
        #expect(e.freshElementParam(["item": "__e"]) == "__e1")
        #expect(e.freshElementParam(["a": "__e", "b": "__e1"]) == "__e2")
    }

    @Test("refined iterate with takeFromEnd emits Array suffix")
    func refinedIterateTakeFromEnd() throws {
        let workflow = IRWorkflow(name: "w", parameters: [], body: IRBlock(statements: []))
        let ir = IterateIR(
            mode: .whileCondition(.literal(.boolean(true))),
            body: IRBlock(statements: []),
            source: IRIterationRefinement(takeFromEnd: 2)
        )
        let out = e.emitRefinedIterate(
            ir,
            refinement: IRIterationRefinement(takeFromEnd: 2),
            param: "item",
            collection: .identifierRef(name: "items"),
            ctx: ctx,
            workflow: workflow,
            path: "0",
            loopIndex: "__i",
            loopLabel: "__label"
        ).toString(separator: "\n")
        #expect(out.contains(".suffix(2)"))
    }
}

@Suite("SwiftEmitter+Primitives coverage")
struct SwiftEmitterPrimitivesCoverageTests {
    private let e = SwiftEmitter()
    private var ctx: Ctx { Ctx(depth: 0, options: .init()) }

    @Test("emitBindValue routes strings through Value and other exprs through emitExpr")
    func emitBindValueRouting() {
        #expect(e.emitBindValue(.literal(.string("hi"))).contains(".string"))
        #expect(e.emitBindValue(.literal(.number(1))) == "Decimal(1)")
    }

    @Test("emitAutonomyPredicate toggles trailing comma")
    func emitAutonomyPredicateComma() {
        let withComma = e.emitAutonomyPredicate(
            name: "until",
            expr: .literal(.boolean(true)),
            ctx: ctx,
            includeComma: true
        )
        #expect(withComma.last?.hasSuffix("},") == true)
        let without = e.emitAutonomyPredicate(
            name: "unless",
            expr: .literal(.boolean(false)),
            ctx: ctx,
            includeComma: false
        )
        #expect(without.last?.hasSuffix("}") == true)
        #expect(without.last?.hasSuffix("},") == false)
    }

    @Test("emitEmit covers empty and non-empty payloads in strict and lenient modes")
    func emitEmitVariants() {
        let empty = e.emitEmit(
            EmitIR(eventID: "ping", payload: [], strict: true),
            ctx: ctx,
            mode: .strict
        ).toString(separator: "\n")
        #expect(empty.contains("try await runtime.emit"))
        #expect(empty.contains("payload: [:]"))

        let payload = e.emitEmit(
            EmitIR(
                eventID: "done",
                payload: [EmitField("ok", .literal(.boolean(true)))],
                strict: false
            ),
            ctx: ctx,
            mode: .lenient
        ).toString(separator: "\n")
        #expect(payload.contains("await runtime.emitLenient"))
        #expect(payload.contains("\"ok\""))
    }

    @Test("emitAIAutonomy includes until/unless/guidance arms")
    func emitAIAutonomyPredicates() {
        let ir = AIAutonomyIR(
            text: "repair",
            autonomy: AutonomyConfigIR(
                until: .literal(.boolean(true)),
                unless: .literal(.boolean(false))
            ),
            guidance: "be careful"
        )
        let out = e.emitAIAutonomy(ir, ctx: ctx).toString(separator: "\n")
        #expect(out.contains("until:"))
        #expect(out.contains("unless:"))
        #expect(out.contains("guidance:"))
        #expect(out.contains("executeAutonomousLoop"))
    }
}
