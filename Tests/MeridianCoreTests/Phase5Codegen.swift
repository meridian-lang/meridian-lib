import Testing
import Foundation
@testable import MeridianCore

// MARK: - Phase 5 codegen smoke
//
// Exercises the `iterate` and `assert` IR primitives end-to-end through the
// Swift emitter. These two are easy to break silently — `iterate` because of
// the type of `state.get`'s return (Optional<Value>) and `assert` because the
// runtime call signature differs from the IR's "condition + message"
// vocabulary. The tests below pin both shapes.

@Suite("Phase 5 codegen — iterate + assert")
struct Phase5Codegen {

    private func emitter() -> SwiftEmitter {
        SwiftEmitter(options: .init(emitSourceLineComments: false))
    }

    // MARK: - iterate

    @Test("iterate emits a checkpointed enumerated loop")
    func iterateOverList() throws {
        let body = IRBlock(statements: [
            .emit(EmitIR(eventID: "item.seen", payload: [
                EmitField("item", .identifierRef(name: "item"))
            ], strict: true))
        ])
        let it = IRPrimitive.iterate(IterateIR(
            mode: .overCollection(parameter: "item",
                                  kind: KindRef("Any"),
                                  collection: .identifierRef(name: "items")),
            body: body
        ))
        let wf = IRWorkflow(
            name: "process the items",
            parameters: [],
            body: IRBlock(statements: [it]),
            mode: .strict,
            sourceFile: "iterate_demo.meridian"
        )
        let out = try emitter().emit(workflows: [wf]).combined

        // The optional-chained accessor — no force casts, no
        // `Value.opaque(AnyHashableSendable(...))` wrapping (`Value` is already
        // Sendable so we just bind the loop variable straight).
        #expect(out.contains("let __meridianColl_0_0 = (state.get(\"items\")?.asList ?? [])"))
        #expect(out.contains("for (__meridianLoopIndex_0_0, item) in __meridianColl_0_0.enumerated() {"))
        #expect(out.contains("let __meridianLoopLabel_0_0 = \"progress:0.0:iteration:\\(__meridianLoopIndex_0_0)\""))
        #expect(out.contains("state.bind(\"item\", item)"))
        #expect(out.contains("try await runtime.checkpoint(label: __meridianLoopLabel_0_0, state: state.snapshot())"))
        // 8B/E instrumentation: iterate.start/iteration/end (branched/iterated/recovered
        // now actually emitted, not just renderable — see Wave 8 gap closure plan §E).
        #expect(out.contains("try await runtime.recordIterateStart(over: \"state.get(\\\"items\\\")\", step: \"iterate\")"))
        #expect(out.contains("try await runtime.recordIterateIteration(index: __meridianLoopIndex_0_0, step: \"iterate\")"))
        #expect(out.contains("try await runtime.recordIterateEnd(over: \"state.get(\\\"items\\\")\", count: __meridianColl_0_0.count, step: \"iterate\")"))
        #expect(!out.contains("as! [Any]"))
    }

    // MARK: - assert

    @Test("bare assert lowers to `try await runtime.assert(cond, message:)`")
    func bareAssertCallsRuntime() throws {
        let assertIR = IRPrimitive.assert(AssertIR(
            condition: .identifierRef(name: "verdictIsValid"),
            message: "verdict must be valid",
            otherwiseAction: nil
        ))
        let wf = IRWorkflow(
            name: "guard validation",
            parameters: [],
            body: IRBlock(statements: [assertIR]),
            mode: .strict,
            sourceFile: "assert_demo.meridian"
        )
        let out = try emitter().emit(workflows: [wf]).combined

        // Must funnel through runtime.assert so the `assert.passed` / `assert.failed`
        // event still fires for observers; no raw `guard … else { throw }` form.
        #expect(out.contains("try await runtime.assert(state.get(\"verdictIsValid\"), message: \"verdict must be valid\")"))
        #expect(!out.contains("MeridianRuntimeError.assertionFailed"))
    }

    @Test("assert with otherwise block emits both branches and still fires events")
    func assertWithOtherwise() throws {
        let recoveryEmit = IRBlock(statements: [
            .emit(EmitIR(eventID: "validation.failed", payload: [], strict: true))
        ])
        let assertIR = IRPrimitive.assert(AssertIR(
            condition: .identifierRef(name: "verdictIsValid"),
            message: "verdict must be valid",
            otherwiseAction: recoveryEmit
        ))
        let wf = IRWorkflow(
            name: "guard validation with recovery",
            parameters: [],
            body: IRBlock(statements: [assertIR]),
            mode: .strict,
            sourceFile: "assert_otherwise.meridian"
        )
        let out = try emitter().emit(workflows: [wf]).combined

        // Failure path — recovery block runs after the failed-event fires.
        #expect(out.contains("if !(state.get(\"verdictIsValid\")) {"))
        #expect(out.contains("try await runtime.assert(false, message: \"verdict must be valid\")"))
        #expect(out.contains("await runtime.emit("))
        // Success path — still wants the passed event so observers can see
        // both shapes side by side.
        #expect(out.contains("try await runtime.assert(true, message: \"verdict must be valid\")"))
    }
}
