import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - IRWorkflow naming tests

@Suite("IRWorkflow struct naming")
struct IRWorkflowNamingTests {

    @Test("process an order → ProcessOrder")
    func processOrder() {
        #expect(IRWorkflow.structName(from: "process an order placed by a customer") == "ProcessOrder")
    }

    @Test("leniently sync analytics → LenientlySyncAnalytics")
    func leniently() {
        #expect(IRWorkflow.structName(from: "leniently sync analytics for an order placed by a customer") == "LenientlySyncAnalytics")
    }

    @Test("validate the order → ValidateOrder")
    func validateOrder() {
        #expect(IRWorkflow.structName(from: "validate the order") == "ValidateOrder")
    }

    @Test("handle payment failure → HandlePaymentFailure")
    func handlePaymentFailure() {
        #expect(IRWorkflow.structName(from: "handle the payment failure for an order") == "HandlePaymentFailure")
    }
}

// MARK: - IRExpression emission

@Suite("IRExpression emission")
struct IRExpressionEmissionTests {

    private let emitter = SwiftEmitter()

    @Test("literal string")
    func literalString() {
        let expr = IRExpression.literal(.string("USD"))
        #expect(emitter.emitExpr(expr) == "\"USD\"")
    }

    @Test("literal number")
    func literalNumber() {
        let expr = IRExpression.literal(.number(42))
        #expect(emitter.emitExpr(expr) == "Decimal(42)")
    }

    @Test("literal bool")
    func literalBool() {
        #expect(emitter.emitExpr(.literal(.boolean(true))) == "true")
        #expect(emitter.emitExpr(.literal(.boolean(false))) == "false")
    }

    @Test("literal money")
    func literalMoney() {
        let expr = IRExpression.literal(.money(5000, currency: "USD"))
        #expect(emitter.emitExpr(expr) == "Money(amount: Decimal(5000), currency: \"USD\")")
    }

    @Test("literal enum value")
    func literalEnum() {
        let expr = IRExpression.literal(.enumValue("approved", kind: "ApprovalVerdict"))
        #expect(emitter.emitExpr(expr) == "ApprovalVerdict.approved")
    }

    @Test("identifierRef")
    func identifierRef() {
        let expr = IRExpression.identifierRef(name: "customer")
        #expect(emitter.emitExpr(expr) == "state.get(\"customer\")")
    }

    @Test("propertyAccess one level")
    func propertyAccessOneLevel() {
        let expr = IRExpression.propertyAccess(.identifierRef(name: "order"), propertyName: "id")
        #expect(emitter.emitExpr(expr) == "state.get(\"order.id\")")
    }

    @Test("propertyAccess nested path")
    func propertyAccessNested() {
        let expr = IRExpression.propertyAccess(
            .propertyAccess(.identifierRef(name: "customer"), propertyName: "account manager"),
            propertyName: "email"
        )
        // Property paths are camelCase end-to-end (matches Codable's default
        // key encoding for opaque domain values traversed by State.get).
        #expect(emitter.emitExpr(expr) == "state.get(\"customer.accountManager.email\")")
    }

    @Test("constantRef camelCase")
    func constantRef() {
        let expr = IRExpression.constantRef(name: "high value threshold")
        #expect(emitter.emitExpr(expr) == "constants.highValueThreshold")
    }

    @Test("comparison greaterThan emits Value-aware helper when LHS reads state")
    func comparison() {
        let expr = IRExpression.comparison(
            .identifierRef(name: "score"),
            .greaterThan,
            .literal(.number(0.5))
        )
        let emitted = emitter.emitExpr(expr)
        // state.get(...) returns Value? — Swift can't compare it directly, so
        // codegen routes through the runtime helper.
        #expect(emitted.contains("MeridianComparison.gt"))
        #expect(emitted.contains("state.get(\"score\")"))
    }

    @Test("logical and")
    func logicalAnd() {
        let expr = IRExpression.logical(.and, [
            .literal(.boolean(true)),
            .literal(.boolean(false))
        ])
        #expect(emitter.emitExpr(expr).contains("&&"))
    }
}

// MARK: - SwiftEmitter primitive tests

@Suite("SwiftEmitter primitives")
struct SwiftEmitterPrimitiveTests {

    private let emitter = SwiftEmitter(options: .init(emitSourceLineComments: false))
    private let ctx = Ctx(depth: 2, options: SwiftEmitter.Options(emitSourceLineComments: false))

    private func workflow() -> IRWorkflow {
        IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: []))
    }

    @Test("invoke with binding emits let + state.bind")
    func invokeWithBinding() {
        let ir = InvokeIR(toolID: "validateOrder", arguments: [
            InvokeArg("id", .propertyAccess(.identifierRef(name: "order"), propertyName: "id"))
        ], resultBinding: "validationResult")
        let out = emitter.emitInvoke(ir, ctx: ctx).toString()
        #expect(out.contains("let validationResult = try await runtime.invoke("))
        #expect(out.contains("tool: \"validateOrder\""))
        #expect(out.contains("state.bind(\"validationResult\", validationResult)"))
    }

    @Test("invoke without binding emits _")
    func invokeNoBinding() {
        let ir = InvokeIR(toolID: "updateOrder", arguments: [])
        let out = emitter.emitInvoke(ir, ctx: ctx).toString()
        #expect(out.contains("_ = try await runtime.invoke("))
        #expect(!out.contains("state.bind"))
    }

    @Test("bind emits state.bind")
    func bindEmitsBind() {
        let ir = BindIR(name: "score", expression: .literal(.number(0)))
        let out = emitter.emitBind(ir, ctx: ctx).toString()
        #expect(out.contains("state.bind(\"score\","))
    }

    @Test("rebind emits state.rebind")
    func rebindEmitsRebind() {
        let ir = BindIR(name: "score", expression: .literal(.number(1)), isRebind: true)
        let out = emitter.emitBind(ir, ctx: ctx).toString()
        #expect(out.contains("state.rebind(\"score\","))
    }

    @Test("strict emit emits try await runtime.emit")
    func strictEmit() {
        let ir = EmitIR(eventID: "order.approved", payload: [
            EmitField("order_id", .identifierRef(name: "order"))
        ], strict: true)
        let out = emitter.emitEmit(ir, ctx: ctx, mode: .strict).toString()
        #expect(out.contains("try await runtime.emit("))
        #expect(out.contains("\"order.approved\""))
    }

    @Test("lenient emit emits await runtime.emitLenient")
    func lenientEmit() {
        let ir = EmitIR(eventID: "analytics.sent", payload: [], strict: false)
        let out = emitter.emitEmit(ir, ctx: ctx, mode: .strict).toString()
        #expect(out.contains("await runtime.emitLenient("))
    }

    @Test("branch with else emits if/else")
    func branchWithElse() {
        let thenBlock = IRBlock(statements: [.complete(CompleteIR(reason: "ok"))])
        let elseBlock = IRBlock(statements: [.complete(CompleteIR(reason: "nok"))])
        let ir = BranchIR(
            condition: .predicate(.literal(.boolean(true))),
            thenBlock: thenBlock,
            elseBlock: elseBlock
        )
        let out = emitter.emitBranch(ir, ctx: ctx, workflow: workflow()).toString()
        #expect(out.contains("if true {"))
        #expect(out.contains("} else {"))
        #expect(out.contains("\"ok\""))
        #expect(out.contains("\"nok\""))
    }

    @Test("branch without else emits only if")
    func branchNoElse() {
        let thenBlock = IRBlock(statements: [])
        let ir = BranchIR(
            condition: .predicate(.literal(.boolean(true))),
            thenBlock: thenBlock
        )
        let out = emitter.emitBranch(ir, ctx: ctx, workflow: workflow()).toString()
        #expect(out.contains("if true {"))
        #expect(!out.contains("} else {"))
    }

    @Test("complete with reason emits reason string and return")
    func completeWithReason() {
        let ir = CompleteIR(reason: "fraud_review_required")
        let out = emitter.emitComplete(ir, ctx: ctx).toString()
        #expect(out.contains("await runtime.complete(reason: \"fraud_review_required\")"))
        #expect(out.contains("return WorkflowResult("))
        #expect(out.contains("\"fraud_review_required\""))
    }

    @Test("complete without reason emits nil")
    func completeNoReason() {
        let ir = CompleteIR(reason: nil)
        let out = emitter.emitComplete(ir, ctx: ctx).toString()
        #expect(out.contains("reason: nil"))
    }

    @Test("commit with label emits checkpoint call")
    func commitWithLabel() {
        let ir = CommitIR(label: "after_validation")
        let out = emitter.emitCommit(ir, ctx: ctx).toString()
        #expect(out.contains("runtime.checkpoint(label: \"after_validation\""))
    }
}

// MARK: - Full workflow emission

@Suite("SwiftEmitter full workflow")
struct SwiftEmitterWorkflowTests {

    private var options: SwiftEmitter.Options {
        SwiftEmitter.Options(indentUnit: "    ", emitSourceLineComments: false)
    }

    @Test("emitted file contains required header")
    func fileHeader() {
        let emitter = SwiftEmitter(options: options)
        let wf = IRWorkflow(
            name: "test workflow",
            parameters: [],
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))])
        )
        let out = emitter.emitFile(workflows: [wf])
        #expect(out.contains("THIS FILE IS GENERATED BY MERIDIAN"))
        #expect(out.contains("import Foundation"))
        #expect(out.contains("import MeridianRuntime"))
    }

    @Test("workflow with parameters emits typed properties and init")
    func workflowWithParameters() {
        let emitter = SwiftEmitter(options: options)
        let wf = IRWorkflow(
            name: "process an order placed by a customer",
            parameters: [
                IRParameter(name: "order", kind: KindRef("Order")),
                IRParameter(name: "customer", kind: KindRef("Customer"))
            ],
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))])
        )
        let out = emitter.emitWorkflow(wf).toString()
        #expect(out.contains("public struct ProcessOrder: MeridianWorkflow {"))
        #expect(out.contains("public let order: Order"))
        #expect(out.contains("public let customer: Customer"))
        #expect(out.contains("public init(runtime: Runtime, order: Order, customer: Customer)"))
        #expect(out.contains("state.bind(\"order\", order)"))
        #expect(out.contains("state.bind(\"customer\", customer)"))
    }

    @Test("invoke + branch + complete emits correct structure")
    func invokeBranchComplete() {
        let emitter = SwiftEmitter(options: options)

        // IR: invoke validateOrder → validationResult
        //     if validationResult.verdict == invalid → complete("validation_failed")
        //     complete(nil)
        let invoke = IRPrimitive.invoke(InvokeIR(
            toolID: "validateOrder",
            arguments: [InvokeArg("id", .propertyAccess(.identifierRef(name: "order"), propertyName: "id"))],
            resultBinding: "validationResult"
        ))
        let branchThen = IRBlock(statements: [
            .complete(CompleteIR(reason: "validation_failed"))
        ])
        let branch = IRPrimitive.branch(BranchIR(
            condition: .predicate(.comparison(
                .propertyAccess(.identifierRef(name: "validationResult"), propertyName: "verdict"),
                .equal,
                .literal(.enumValue("invalid", kind: "ValidationVerdict"))
            )),
            thenBlock: branchThen
        ))
        let complete = IRPrimitive.complete(CompleteIR(reason: nil))

        let wf = IRWorkflow(
            name: "process an order placed by a customer",
            parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
            body: IRBlock(statements: [invoke, branch, complete])
        )

        let out = emitter.emitWorkflow(wf).toString()

        // Verify structural correctness
        #expect(out.contains("let validationResult = try await runtime.invoke("))
        #expect(out.contains("tool: \"validateOrder\""))
        #expect(out.contains("state.bind(\"validationResult\", validationResult)"))
        // state.get returns Value?; codegen routes equality through the helper
        // and wraps the enum literal as a Value so the helper signature matches.
        // (The runtime stores enum-typed properties as `.string(rawValue)`.)
        #expect(out.contains("MeridianComparison.eq(state.get(\"validationResult.verdict\"), .string(\"invalid\"))"))
        #expect(out.contains("await runtime.complete(reason: \"validation_failed\")"))
        #expect(out.contains("return WorkflowResult(reason: \"validation_failed\""))
        #expect(out.contains("await runtime.complete(reason: nil)"))
    }

    @Test("constants decl emits Constants struct")
    func constantsDecl() {
        let emitter = SwiftEmitter(options: options)
        let decl = SwiftEmitter.ConstantsDecl(entries: [
            .init("high value threshold", .money(5000, currency: "USD")),
            .init("fraud risk threshold", .number(0.5)),
            .init("maximum retry count", .number(3))
        ])
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: []))
        let out = emitter.emitFile(workflows: [wf], constantsDecl: decl)
        #expect(out.contains("public struct Constants: Sendable {"))
        #expect(out.contains("public let highValueThreshold: Money"))
        #expect(out.contains("public let fraudRiskThreshold: Decimal"))
        #expect(out.contains("public let maximumRetryCount: Decimal"))
        #expect(out.contains("private let constants = Constants()"))
    }
}

// MARK: - ManifestEmitter tests

@Suite("ManifestEmitter")
struct ManifestEmitterTests {

    @Test("emits valid JSON with required top-level keys")
    func emitsValidJSON() throws {
        let wf = IRWorkflow(
            name: "process an order placed by a customer",
            parameters: [
                IRParameter(name: "order", kind: KindRef("Order")),
                IRParameter(name: "customer", kind: KindRef("Customer"))
            ],
            body: IRBlock(statements: []),
            sourceFile: "order_processing.meridian"
        )
        let input = ManifestEmitter.Input(
            sourceFiles: ["order_processing.meridian", "ecommerce.merconfig"],
            workflows: [wf],
            toolsUsed: ["validateOrder", "chargePayment"],
            kindsUsed: ["Order", "Customer"]
        )
        let json = try ManifestEmitter().emit(input)
        let data = Data(json.utf8)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)
        #expect(parsed?["meridian_ir_version"] as? String == "1.0")
        let workflows = parsed?["workflows"] as? [[String: Any]]
        #expect(workflows?.first?["swift_struct"] as? String == "ProcessOrder")
        #expect(workflows?.first?["source_name"] as? String == "process an order placed by a customer")
        #expect((parsed?["tools_used"] as? [String])?.contains("validateOrder") == true)
    }

    @Test("emits constants block when provided")
    func emitsConstants() throws {
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: []))
        let decl = SwiftEmitter.ConstantsDecl(entries: [
            .init("high value threshold", .money(5000, currency: "USD"))
        ])
        let input = ManifestEmitter.Input(workflows: [wf], constantsDecl: decl)
        let json = try ManifestEmitter().emit(input)
        #expect(json.contains("high value threshold") || json.contains("constants"))
    }
}

// MARK: - Newline / formatting tests

@Suite("SwiftEmitter output formatting")
struct SwiftEmitterFormattingTests {

    private func emitter(comments: Bool = false) -> SwiftEmitter {
        SwiftEmitter(options: .init(
            sourceFileName: "test.meridian",
            emitSourceLineComments: comments
        ))
    }

    // MARK: Line structure

    @Test("emitFile produces multi-line output")
    func multiLine() {
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: []))
        let out = emitter().emitFile(workflows: [wf])
        let lines = out.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count > 5)
        #expect(out.contains("let __meridianResumeContext = await runtime.consumeResumeContext()"))
    }

    @Test("replay guards checkpoint side-effect primitives")
    func replayGuardsCheckpointSideEffects() {
        let workflow = IRWorkflow(
            name: "test replay guards",
            parameters: [],
            body: IRBlock(statements: [
                .invoke(InvokeIR(toolID: "tool.one", resultBinding: "first", sourceRange: .init(file: "t.meridian", line: 2, column: 1))),
                .emit(EmitIR(eventID: "event.one", payload: [], sourceRange: .init(file: "t.meridian", line: 3, column: 1))),
                .wait(WaitIR(condition: .duration(.seconds(1)), sourceRange: .init(file: "t.meridian", line: 4, column: 1))),
                .commit(CommitIR(label: "user_label", sourceRange: .init(file: "t.meridian", line: 5, column: 1)))
            ])
        )
        let out = emitter().emitWorkflow(workflow).toString()

        #expect(out.contains("if __meridianShouldRun(\"progress:0.0:L2:C1\")"))
        #expect(out.contains("try await runtime.checkpoint(label: \"progress:0.0:L2:C1\", state: state.snapshot())"))
        #expect(out.contains("if __meridianShouldRun(\"progress:0.1:L3:C1\")"))
        #expect(out.contains("if __meridianShouldRun(\"progress:0.2:L4:C1\")"))
        #expect(out.contains("if __meridianShouldRun(\"user_label\")"))
        #expect(out.contains("try await runtime.checkpoint(label: \"user_label\", state: state.snapshot())"))
    }

    @Test("every emitFile line is a separate line (no embedded newlines in items)")
    func noEmbeddedNewlines() {
        let wf = IRWorkflow(
            name: "process an order placed by a customer",
            parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))])
        )
        let out = emitter().emitFile(workflows: [wf])
        // Each line from split should itself be a single line
        let lines = out.components(separatedBy: "\n")
        for line in lines {
            #expect(!line.contains("\n"), "Line contains embedded newline: \(line)")
        }
    }

    @Test("header lines appear on separate lines")
    func headerLinesAreSeparate() {
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: []))
        let out = emitter().emitFile(workflows: [wf])
        let lines = out.components(separatedBy: "\n")
        #expect(lines.contains("// THIS FILE IS GENERATED BY MERIDIAN. DO NOT EDIT."))
        #expect(lines.contains("// Source: test.meridian"))
        #expect(lines.contains("// Meridian IR version: 1.0"))
        #expect(lines.contains("import Foundation"))
        #expect(lines.contains("import MeridianRuntime"))
    }

    @Test("workflow struct lines appear on separate lines")
    func workflowLinesAreSeparate() {
        let wf = IRWorkflow(
            name: "process an order placed by a customer",
            parameters: [
                IRParameter(name: "order", kind: KindRef("Order")),
                IRParameter(name: "customer", kind: KindRef("Customer"))
            ],
            body: IRBlock(statements: [.complete(CompleteIR(reason: nil))])
        )
        let lines = emitter().emitFile(workflows: [wf]).components(separatedBy: "\n")
        #expect(lines.contains("public struct ProcessOrder: MeridianWorkflow {"))
        #expect(lines.contains("    public let runtime: Runtime"))
        #expect(lines.contains("    public let order: Order"))
        #expect(lines.contains("    public let customer: Customer"))
        #expect(lines.contains("    public func run() async throws -> WorkflowResult {"))
        #expect(lines.contains("        var state = State()"))
        #expect(lines.contains("        state.bind(\"order\", order)"))
        #expect(lines.contains("        state.bind(\"customer\", customer)"))
        #expect(lines.contains("}"))
    }

    @Test("blank lines separate major sections")
    func blankLinesBetweenSections() {
        let wf = IRWorkflow(
            name: "test",
            parameters: [IRParameter(name: "x", kind: KindRef("X"))],
            body: IRBlock(statements: [])
        )
        let lines = emitter().emitFile(workflows: [wf]).components(separatedBy: "\n")
        // There should be at least one blank line in the output
        #expect(lines.contains(""))
    }

    // MARK: Constants guard

    @Test("let constants = Constants() NOT emitted without constantsDecl")
    func noConstantsWithoutDecl() {
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: []))
        let out = emitter().emitFile(workflows: [wf])
        #expect(!out.contains("let constants = Constants()"))
    }

    @Test("let constants = Constants() IS emitted with constantsDecl")
    func constantsWithDecl() {
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: []))
        let decl = SwiftEmitter.ConstantsDecl(entries: [
            .init("max retries", .number(3))
        ])
        let out = emitter().emitFile(workflows: [wf], constantsDecl: decl)
        let lines = out.components(separatedBy: "\n")
        #expect(lines.contains("        let constants = Constants()"))
        #expect(lines.contains("public struct Constants: Sendable {"))
        #expect(lines.contains("private let constants = Constants()"))
    }

    // MARK: Source line comments

    @Test("source line comments appear on own line when enabled")
    func sourceLineCommentOnOwnLine() {
        let ir = IRWorkflow(
            name: "test",
            parameters: [],
            body: IRBlock(statements: [
                .complete(CompleteIR(reason: nil,
                    sourceRange: SourceRange(file: "t.meridian", line: 7, column: 1)))
            ])
        )
        let e = SwiftEmitter(options: .init(emitSourceLineComments: true))
        let lines = e.emitFile(workflows: [ir]).components(separatedBy: "\n")
        #expect(lines.contains("        // L7"))
    }

    @Test("no source line comments when disabled")
    func noSourceLineComments() {
        let ir = IRWorkflow(
            name: "test",
            parameters: [],
            body: IRBlock(statements: [
                .complete(CompleteIR(reason: nil,
                    sourceRange: SourceRange(file: "t.meridian", line: 7, column: 1)))
            ])
        )
        let e = SwiftEmitter(options: .init(emitSourceLineComments: false))
        let out = e.emitFile(workflows: [ir])
        #expect(!out.contains("// L7"))
    }

    // MARK: Golden snapshot — LenientlySyncAnalytics

    /// Verifies the complete line-by-line structure of the simplest workflow.
    /// This is the Phase 2 forcing function golden check.
    @Test("LenientlySyncAnalytics golden line structure")
    func lenientlySyncAnalyticsGolden() {
        // Property names use spaces (as the real parser produces from "the
        // order's total amount"). Codegen camelCases them so paths line up
        // with Swift property names and Codable's default keying:
        // "total amount" → "totalAmount".
        let emit = IRPrimitive.emit(EmitIR(
            eventID: "analytics.order_processed",
            payload: [
                EmitField("order_id",    .propertyAccess(.identifierRef(name: "order"),    propertyName: "id")),
                EmitField("customer_id", .propertyAccess(.identifierRef(name: "customer"), propertyName: "id")),
                EmitField("amount",      .propertyAccess(.identifierRef(name: "order"),    propertyName: "total amount")),
                EmitField("timestamp",   .nowExpression)
            ],
            strict: false
        ))
        let wf = IRWorkflow(
            name: "leniently sync analytics for an order placed by a customer",
            parameters: [
                IRParameter(name: "order",    kind: KindRef("Order")),
                IRParameter(name: "customer", kind: KindRef("Customer"))
            ],
            body: IRBlock(statements: [emit]),
            mode: .lenient,
            sourceFile: "ecommerce.meridian"
        )
        let e = SwiftEmitter(options: .init(
            sourceFileName: "ecommerce.meridian",
            emitSourceLineComments: false
        ))
        let lines = e.emitFile(workflows: [wf]).components(separatedBy: "\n")

        // File header
        #expect(lines.contains("// THIS FILE IS GENERATED BY MERIDIAN. DO NOT EDIT."))
        #expect(lines.contains("// Source: ecommerce.meridian"))
        #expect(lines.contains("import MeridianRuntime"))

        // Struct skeleton
        #expect(lines.contains("public struct LenientlySyncAnalytics: MeridianWorkflow {"))
        #expect(lines.contains("    public let runtime: Runtime"))
        #expect(lines.contains("    public let order: Order"))
        #expect(lines.contains("    public let customer: Customer"))
        #expect(lines.contains("    public init(runtime: Runtime, order: Order, customer: Customer) {"))
        #expect(lines.contains("        self.runtime = runtime"))
        #expect(lines.contains("        self.order = order"))
        #expect(lines.contains("        self.customer = customer"))
        #expect(lines.contains("    }"))

        // run() body
        #expect(lines.contains("    public func run() async throws -> WorkflowResult {"))
        #expect(lines.contains("        var state = State()"))
        #expect(lines.contains("        state.bind(\"order\", order)"))
        #expect(lines.contains("        state.bind(\"customer\", customer)"))
        // No constants (no constantsDecl)
        #expect(!lines.contains("        let constants = Constants()"))
        #expect(lines.contains("        await runtime.workflowStarted(workflowName: \"LenientlySyncAnalytics\", parameters: [:])"))

        // Lenient emit
        #expect(lines.contains("        if __meridianShouldRun(\"progress:0.0:L0:C0\") {"))
        #expect(lines.contains("            await runtime.emitLenient("))
        #expect(lines.contains("                event: \"analytics.order_processed\","))
        #expect(lines.contains("                payload: ["))
        // Payload values flow into [String: Value], so codegen wraps optionals
        // (?? .null) and dates (.date(Date())) explicitly.
        #expect(lines.contains("                    \"order_id\": state.get(\"order.id\") ?? .null,"))
        #expect(lines.contains("                    \"customer_id\": state.get(\"customer.id\") ?? .null,"))
        #expect(lines.contains("                    \"amount\": state.get(\"order.totalAmount\") ?? .null,"))
        #expect(lines.contains("                    \"timestamp\": .date(Date()),"))
        #expect(lines.contains("                ]"))
        #expect(lines.contains("            )"))
        #expect(lines.contains("            try await runtime.checkpoint(label: \"progress:0.0:L0:C0\", state: state.snapshot())"))

        // Implicit complete
        #expect(lines.contains("        await runtime.complete(reason: nil)"))
        #expect(lines.contains("        return WorkflowResult(reason: nil, durationMS: await runtime.elapsedMS(), eventCount: await runtime.eventCount(), bindings: state.snapshot().asValues)"))
        #expect(lines.contains("    }"))
        #expect(lines.contains("}"))
    }
}
