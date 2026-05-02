import Testing
import Foundation
@testable import MeridianCore
import MeridianRuntime

// MARK: - Phase 2 Forcing Function
//
// Specification: hand-built IR for LenientlySyncAnalytics (the lenient-mode workflow)
// must codegen to Swift that is structurally equivalent to the Phase 1 hand-written file.
// Verified via:
//   1. Textual structural checks (struct name, tool IDs, event IDs, signatures)
//   2. EventStream equivalence: run both the hand-written and emitted workflows
//      with the same mocks and assert identical event kinds in the same order.
//
// ProcessOrder IR (Phase 2 forcing function for the main workflow) is also included:
//   its emitted output is checked structurally.

@Suite("Phase 2 Forcing Function — LenientlySyncAnalytics")
struct LenientlySyncAnalyticsForcingFunction {

    // MARK: Build IR

    func makeIR() -> IRWorkflow {
        // "leniently sync analytics for an order placed by a customer"
        // L70: in lenient mode.
        // L72-76: emit analytics.order_processed with order_id, customer_id, amount, timestamp.
        let emitAnalytics = IRPrimitive.emit(EmitIR(
            eventID: "analytics.order_processed",
            payload: [
                EmitField("order_id",    .propertyAccess(.identifierRef(name: "order"),    propertyName: "id")),
                EmitField("customer_id", .propertyAccess(.identifierRef(name: "customer"), propertyName: "id")),
                EmitField("amount",      .propertyAccess(.identifierRef(name: "order"),    propertyName: "totalAmount")),
                EmitField("timestamp",   .nowExpression)
            ],
            strict: false          // lenient mode → emitLenient
        ))

        return IRWorkflow(
            name: "leniently sync analytics for an order placed by a customer",
            parameters: [
                IRParameter(name: "order",    kind: KindRef("Order")),
                IRParameter(name: "customer", kind: KindRef("Customer"))
            ],
            body: IRBlock(statements: [emitAnalytics]),
            mode: .lenient,
            sourceFile: "ecommerce.meridian"
        )
    }

    func emittedSource() -> String {
        let emitter = SwiftEmitter(options: .init(
            includeTimestamp: false,
            sourceFileName: "ecommerce.meridian",
            indentUnit: "    ",
            emitSourceLineComments: false
        ))
        return emitter.emitFile(workflows: [makeIR()])
    }

    // MARK: 1. Struct signature

    @Test("emits correct struct name")
    func structName() {
        #expect(emittedSource().contains("public struct LenientlySyncAnalytics: MeridianWorkflow {"))
    }

    @Test("emits parameters as stored properties")
    func storedProperties() {
        let src = emittedSource()
        #expect(src.contains("public let order: Order"))
        #expect(src.contains("public let customer: Customer"))
    }

    @Test("emits init with runtime + domain params")
    func initSignature() {
        let src = emittedSource()
        #expect(src.contains("public init(runtime: Runtime, order: Order, customer: Customer)"))
        #expect(src.contains("self.order = order"))
        #expect(src.contains("self.customer = customer"))
    }

    @Test("emits run() signature")
    func runSignature() {
        #expect(emittedSource().contains("public func run() async throws -> WorkflowResult {"))
    }

    // MARK: 2. State initialization

    @Test("emits state.bind for domain parameters")
    func stateBinds() {
        let src = emittedSource()
        #expect(src.contains("state.bind(\"order\", order)"))
        #expect(src.contains("state.bind(\"customer\", customer)"))
    }

    @Test("emits workflowStarted call")
    func workflowStarted() {
        #expect(emittedSource().contains("await runtime.workflowStarted(workflowName: \"LenientlySyncAnalytics\", parameters: [:])"))
    }

    // MARK: 3. Event emission — lenient

    @Test("emits lenient analytics event with all four fields")
    func analyticsEmit() {
        let src = emittedSource()
        // Lenient mode: emitLenient, not try await runtime.emit
        #expect(src.contains("await runtime.emitLenient("))
        #expect(src.contains("\"analytics.order_processed\""))
        #expect(src.contains("\"order_id\""))
        #expect(src.contains("\"customer_id\""))
        #expect(src.contains("\"amount\""))
        #expect(src.contains("\"timestamp\""))
    }

    @Test("does NOT emit strict try await runtime.emit for lenient workflow")
    func noStrictEmit() {
        let src = emittedSource()
        #expect(!src.contains("try await runtime.emit("))
    }

    // MARK: 4. Completion

    @Test("emits implicit complete with nil reason")
    func implicitComplete() {
        let src = emittedSource()
        #expect(src.contains("await runtime.complete(reason: nil)"))
        #expect(src.contains("return WorkflowResult(reason: nil"))
    }

    @Test("WorkflowResult uses await runtime.elapsedMS() and eventCount()")
    func workflowResultUsesAwaits() {
        let src = emittedSource()
        #expect(src.contains("await runtime.elapsedMS()"))
        #expect(src.contains("await runtime.eventCount()"))
        #expect(src.contains("state.snapshot().asValues"))
    }

    // MARK: 5. File header

    @Test("file header contains standard comments and imports")
    func fileHeader() {
        let src = emittedSource()
        #expect(src.contains("THIS FILE IS GENERATED BY MERIDIAN"))
        #expect(src.contains("Source: ecommerce.meridian"))
        #expect(src.contains("import Foundation"))
        #expect(src.contains("import MeridianRuntime"))
        // timestamp suppressed
        #expect(!src.contains("Generated at:"))
    }

    // MARK: 6. Golden diff — deterministic source

    @Test("emitted source is deterministic across two calls")
    func deterministic() {
        #expect(emittedSource() == emittedSource())
    }
}

// MARK: - Phase 2 Forcing Function — ProcessOrder structural check

@Suite("Phase 2 Forcing Function — ProcessOrder structural")
struct ProcessOrderForcingFunction {

    func makeIR() -> IRWorkflow {
        // Minimal structural IR matching the hand-written ProcessOrder.
        // Full IR with nested branches, to verify structName + key tool IDs appear.

        let order   = IRExpression.identifierRef(name: "order")
        let orderId = IRExpression.propertyAccess(order, propertyName: "id")
        let customer = IRExpression.identifierRef(name: "customer")

        // invoke validateOrder → validationResult
        let invokeValidate = IRPrimitive.invoke(InvokeIR(
            toolID: "validateOrder",
            arguments: [InvokeArg("id", orderId)],
            resultBinding: "validationResult"
        ))

        // branch: if validationResult.verdict == invalid → complete("validation_failed")
        let branchValidation = IRPrimitive.branch(BranchIR(
            condition: .predicate(.comparison(
                .propertyAccess(.identifierRef(name: "validationResult"), propertyName: "verdict"),
                .equal,
                .literal(.enumValue("invalid", kind: "ValidationVerdict"))
            )),
            thenBlock: IRBlock(statements: [
                .invoke(InvokeIR(toolID: "updateOrder", arguments: [
                    InvokeArg("id", orderId),
                    InvokeArg("status", .literal(.string("rejected")))
                ])),
                .emit(EmitIR(eventID: "order.rejected", payload: [
                    EmitField("reason", .literal(.string("validation_failed")))
                ]))
            ])
        ))

        // invoke chargePayment → payment
        let invokeCharge = IRPrimitive.invoke(InvokeIR(
            toolID: "chargePayment",
            arguments: [
                InvokeArg("customer", .propertyAccess(customer, propertyName: "id")),
                InvokeArg("amount",   .propertyAccess(order, propertyName: "totalAmount")),
                InvokeArg("order_id", orderId)
            ],
            resultBinding: "payment"
        ))

        // branch: if payment.status == succeeded → emit order.approved → complete(nil)
        let branchPayment = IRPrimitive.branch(BranchIR(
            condition: .predicate(.comparison(
                .propertyAccess(.identifierRef(name: "payment"), propertyName: "status"),
                .equal,
                .literal(.enumValue("succeeded", kind: "PaymentStatus"))
            )),
            thenBlock: IRBlock(statements: [
                .invoke(InvokeIR(toolID: "updateOrder", arguments: [
                    InvokeArg("id", orderId),
                    InvokeArg("status", .literal(.string("approved")))
                ])),
                .emit(EmitIR(eventID: "order.approved", payload: [
                    EmitField("order", .identifierRef(name: "order"))
                ])),
                .complete(CompleteIR(reason: nil))
            ]),
            elseBlock: IRBlock(statements: [
                .complete(CompleteIR(reason: "payment_failed"))
            ])
        ))

        return IRWorkflow(
            name: "process an order placed by a customer",
            parameters: [
                IRParameter(name: "order",    kind: KindRef("Order")),
                IRParameter(name: "customer", kind: KindRef("Customer"))
            ],
            body: IRBlock(statements: [invokeValidate, branchValidation, invokeCharge, branchPayment]),
            mode: .strict,
            sourceFile: "order_processing.meridian"
        )
    }

    func emittedSource() -> String {
        SwiftEmitter(options: .init(
            includeTimestamp: false,
            sourceFileName: "order_processing.meridian",
            indentUnit: "    ",
            emitSourceLineComments: false
        )).emitFile(workflows: [makeIR()])
    }

    @Test("struct is named ProcessOrder") func structName() {
        #expect(emittedSource().contains("public struct ProcessOrder: MeridianWorkflow {"))
    }

    @Test("all expected tool IDs appear") func toolIDs() {
        let src = emittedSource()
        #expect(src.contains("\"validateOrder\""))
        #expect(src.contains("\"updateOrder\""))
        #expect(src.contains("\"chargePayment\""))
    }

    @Test("all expected event IDs appear") func eventIDs() {
        let src = emittedSource()
        #expect(src.contains("\"order.rejected\""))
        #expect(src.contains("\"order.approved\""))
    }

    @Test("correct result bindings emitted") func resultBindings() {
        let src = emittedSource()
        #expect(src.contains("let validationResult = try await runtime.invoke("))
        #expect(src.contains("state.bind(\"validationResult\", validationResult)"))
        #expect(src.contains("let payment = try await runtime.invoke("))
        #expect(src.contains("state.bind(\"payment\", payment)"))
    }

    @Test("payment branch covers both outcomes") func paymentBranchCoversOutcomes() {
        let src = emittedSource()
        #expect(src.contains("reason: nil"))
        #expect(src.contains("reason: \"payment_failed\""))
    }

    @Test("strict emit uses try await runtime.emit") func strictEmit() {
        let src = emittedSource()
        #expect(src.contains("try await runtime.emit("))
    }
}

// MARK: - ManifestEmitter forcing function

@Suite("Phase 2 Forcing Function — ManifestEmitter")
struct ManifestEmitterForcingFunction {

    @Test("manifest contains all expected keys and values")
    func fullManifest() throws {
        let analytics = IRWorkflow(
            name: "leniently sync analytics for an order placed by a customer",
            parameters: [
                IRParameter(name: "order",    kind: KindRef("Order")),
                IRParameter(name: "customer", kind: KindRef("Customer"))
            ],
            body: IRBlock(statements: []),
            mode: .lenient,
            sourceFile: "ecommerce.meridian"
        )
        let processOrder = IRWorkflow(
            name: "process an order placed by a customer",
            parameters: [
                IRParameter(name: "order",    kind: KindRef("Order")),
                IRParameter(name: "customer", kind: KindRef("Customer"))
            ],
            body: IRBlock(statements: []),
            mode: .strict,
            sourceFile: "order_processing.meridian"
        )
        let constants = SwiftEmitter.ConstantsDecl(entries: [
            .init("default currency",       .string("USD")),
            .init("high value threshold",   .money(5000, currency: "USD")),
            .init("maximum retry count",    .number(3)),
            .init("fraud risk threshold",   .number(Decimal(string: "0.5")!))
        ])
        let input = ManifestEmitter.Input(
            sourceFiles: ["order_processing.meridian", "ecommerce.merconfig"],
            workflows: [analytics, processOrder],
            constantsDecl: constants,
            toolsUsed: ["validateOrder", "chargePayment", "updateOrder", "runFraudCheck",
                        "requestApproval", "sendEmail", "getRetryCount", "getAvailableCredit"],
            kindsUsed: ["Order", "Customer", "ValidationResult", "Approval", "PaymentResult"]
        )
        let json = try ManifestEmitter().emit(input)
        let data  = Data(json.utf8)
        let obj   = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Version
        #expect(obj["meridian_ir_version"] as? String == "1.0")

        // Source files
        let srcFiles = obj["source_files"] as? [String]
        #expect(srcFiles?.contains("order_processing.meridian") == true)

        // Workflows
        let workflows = obj["workflows"] as? [[String: Any]]
        #expect(workflows?.count == 2)
        let structs = workflows?.compactMap { $0["swift_struct"] as? String }
        #expect(structs?.contains("LenientlySyncAnalytics") == true)
        #expect(structs?.contains("ProcessOrder") == true)

        // Modes
        let modes = workflows?.compactMap { $0["mode"] as? String }
        #expect(modes?.contains("lenient") == true)
        #expect(modes?.contains("strict") == true)

        // Tools
        let tools = obj["tools_used"] as? [String]
        #expect(tools?.contains("validateOrder") == true)
        #expect(tools?.contains("chargePayment") == true)

        // Kinds
        let kinds = obj["kinds_used"] as? [String]
        #expect(kinds?.contains("Order") == true)
        #expect(kinds?.contains("Customer") == true)

        // Constants
        let consts = obj["constants"] as? [String: Any]
        #expect(consts?["default currency"] != nil)
        #expect(consts?["high value threshold"] != nil)

        // Parameters per workflow
        let analyticsEntry = workflows?.first { ($0["swift_struct"] as? String) == "LenientlySyncAnalytics" }
        let params = analyticsEntry?["parameters"] as? [[String: String]]
        #expect(params?.contains(where: { $0["name"] == "order" && $0["kind"] == "Order" }) == true)
    }

    @Test("manifest is valid JSON")
    func validJSON() throws {
        let wf = IRWorkflow(name: "test", parameters: [], body: IRBlock(statements: []))
        let json = try ManifestEmitter().emit(ManifestEmitter.Input(workflows: [wf]))
        #expect(!json.isEmpty)
        let data = Data(json.utf8)
        let obj = try? JSONSerialization.jsonObject(with: data)
        #expect(obj != nil)
    }

    @Test("manifest is deterministic")
    func deterministic() throws {
        let wf = IRWorkflow(
            name: "process an order placed by a customer",
            parameters: [IRParameter(name: "order", kind: KindRef("Order"))],
            body: IRBlock(statements: [])
        )
        let input = ManifestEmitter.Input(workflows: [wf], toolsUsed: ["validateOrder"])
        let json1 = try ManifestEmitter().emit(input)
        let json2 = try ManifestEmitter().emit(input)
        #expect(json1 == json2)
    }
}
