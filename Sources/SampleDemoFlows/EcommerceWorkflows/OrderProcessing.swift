import Foundation
import MeridianRuntime

// THIS IS THE HAND-WRITTEN REFERENCE MATCHING examples/golden/OrderProcessing.expected.swift
// It proves the runtime works before the compiler exists (Phase 1 forcing function).
// The compiler will regenerate equivalent code in Phase 3.

// MARK: - Constants (from === constants === in ecommerce.merconfig)

struct Constants {
    let defaultCurrency: String = "USD"
    let highValueThreshold: Money = Money(amount: 5000, currency: "USD")
    let maximumRetryCount: Int = 3
    let newCustomerThreshold: Duration = .seconds(30 * 24 * 60 * 60) // 30 days
    let fraudRiskThreshold: Double = 0.5
}

// MARK: - Workflow: process an order placed by a customer

public struct ProcessOrder: MeridianWorkflow {

    public let runtime: Runtime
    public let order: Order
    public let customer: Customer

    public init(runtime: Runtime, order: Order, customer: Customer) {
        self.runtime = runtime
        self.order = order
        self.customer = customer
    }

    public func run() async throws -> WorkflowResult {
        let startTime = Date()
        var state = State()
        state.bind("order", Value.opaque(AnyHashableSendable(order)))
        state.bind("customer", Value.opaque(AnyHashableSendable(customer)))

        let constants = Constants()

        await runtime.workflowStarted(
            workflowName: "ProcessOrder",
            parameters: [
                "order_id": .string(order.id),
                "customer_id": .string(customer.id)
            ]
        )

        // L19: validate the order.
        // (inlined from "To validate an order:")
        let validationResultValue = try await runtime.invoke(
            tool: "validateOrder",
            args: ["id": .string(order.id)],
            sourceRange: SourceRange(file: "order_processing.meridian", line: 19, column: 3)
        )
        state.bind("validation_result", validationResultValue)

        let validationResult = validationResultValue.unwrapOpaque(as: ValidationResult.self)!
        if validationResult.verdict == .invalid {
            // L19 (inlined): reject the order with reason "validation_failed".
            _ = try await runtime.invoke(
                tool: "updateOrder",
                args: ["id": .string(order.id), "status": .string("rejected")]
            )
            try await runtime.emit(
                event: "order.rejected",
                payload: ["order": .opaque(AnyHashableSendable(order)), "reason": .string("validation_failed")]
            )
        }

        await runtime.recordEvent(.branchTaken, payload: [
            "label": .string(validationResult.verdict == .invalid ? "then" : "else"),
            "reason": .string("verdict != invalid")
        ], sourceRange: SourceRange(file: "order_processing.meridian", line: 19, column: 3))

        // L20: check the credit of the customer for the order's total amount.
        // (inlined from "To check the credit of a customer for an amount:")
        let availableCreditValue = try await runtime.invoke(
            tool: "getAvailableCredit",
            args: ["customer": .string(customer.id)],
            sourceRange: SourceRange(file: "order_processing.meridian", line: 20, column: 3)
        )
        state.bind("available_credit", availableCreditValue)

        let availableCredit = availableCreditValue.unwrapOpaque(as: Money.self)!
        if availableCredit < order.totalAmount {
            // L20 (inlined): reject the order with reason "insufficient_credit".
            _ = try await runtime.invoke(
                tool: "updateOrder",
                args: ["id": .string(order.id), "status": .string("rejected")]
            )
            try await runtime.emit(
                event: "order.rejected",
                payload: ["order": .opaque(AnyHashableSendable(order)), "reason": .string("insufficient_credit")]
            )
        }

        await runtime.recordEvent(.branchTaken, payload: [
            "label": .string(availableCredit >= order.totalAmount ? "else" : "then"),
            "reason": .string("credit >= amount")
        ], sourceRange: SourceRange(file: "order_processing.meridian", line: 20, column: 3))

        // L23: if the customer's signup date is within the new customer threshold, ...
        let daysSinceSignup = Date().timeIntervalSince(customer.signupDate)
        let newCustomerThresholdSeconds = Double(constants.newCustomerThreshold.components.seconds)
        let isNewCustomer = daysSinceSignup <= newCustomerThresholdSeconds

        await runtime.recordEvent(.branchTaken, payload: [
            "label": .string(isNewCustomer ? "then" : "else"),
            "reason": .string("customer not new")
        ], sourceRange: SourceRange(file: "order_processing.meridian", line: 23, column: 3))

        if isNewCustomer {
            // L24: bind risk = invoke run fraud check with order = the order's id.
            let riskValue = try await runtime.invoke(
                tool: "runFraudCheck",
                args: ["order": .string(order.id)],
                sourceRange: SourceRange(file: "order_processing.meridian", line: 24, column: 5)
            )
            state.bind("risk", riskValue)

            let risk = try riskValue.coerce(to: Double.self)

            // L25: if risk is more than the fraud risk threshold, ...
            if risk > constants.fraudRiskThreshold {
                // L26: put the order on hold with reason "fraud_review_required".
                _ = try await runtime.invoke(
                    tool: "updateOrder",
                    args: ["id": .string(order.id), "status": .string("on hold")]
                )
                try await runtime.emit(
                    event: "order.held",
                    payload: ["order": .opaque(AnyHashableSendable(order)), "reason": .string("fraud_review_required")]
                )

                // L27: notify the customer that their order is on hold.
                let primaryMailer = try await runtime.instance("primary_mailer")
                _ = try await runtime.invoke(
                    tool: "sendEmail",
                    args: [
                        "via": .opaque(AnyHashableSendable(primaryMailer)),
                        "to": .string(customer.email),
                        "subject": .string("Your order is on hold"),
                        "body": .string("We are reviewing your order for security purposes. This typically takes 1 to 2 business days.")
                    ]
                )

                // L28: complete with reason "fraud_review_required".
                await runtime.complete(reason: "fraud_review_required",
                    sourceRange: SourceRange(file: "order_processing.meridian", line: 28, column: 7))
                return WorkflowResult(
                    reason: "fraud_review_required",
                    durationMS: Date().timeIntervalSince(startTime) * 1000,
                    eventCount: await runtime.eventCount(),
                    bindings: state.snapshot().asValues
                )
            }
        }

        // L31: if the order's total amount is more than the high value threshold, ...
        let isHighValue = order.totalAmount > constants.highValueThreshold

        await runtime.recordEvent(.branchTaken, payload: [
            "label": .string(isHighValue ? "then" : "else"),
            "reason": .string(isHighValue ? "order amount > high value threshold" : "order amount <= high value threshold")
        ], sourceRange: SourceRange(file: "order_processing.meridian", line: 31, column: 3))

        if isHighValue {
            // L32: bind approval = invoke request approval with ...
            let approvalValue = try await runtime.invoke(
                tool: "requestApproval",
                args: [
                    "approver": .string(customer.accountManager.id),
                    "order": .string(order.id)
                ],
                sourceRange: SourceRange(file: "order_processing.meridian", line: 32, column: 5)
            )
            state.bind("approval", approvalValue)

            let approval = approvalValue.unwrapOpaque(as: Approval.self)!

            await runtime.recordEvent(.branchTaken, payload: [
                "label": .string(approval.verdict == .denied ? "then" : "else"),
                "reason": .string("approval.verdict == denied")
            ], sourceRange: SourceRange(file: "order_processing.meridian", line: 36, column: 5))

            // L36: if the approval's verdict is denied, ...
            if approval.verdict == .denied {
                // L37: reject the order with reason "approval_denied".
                _ = try await runtime.invoke(
                    tool: "updateOrder",
                    args: ["id": .string(order.id), "status": .string("rejected")]
                )
                try await runtime.emit(
                    event: "order.rejected",
                    payload: ["order": .opaque(AnyHashableSendable(order)), "reason": .string("approval_denied")]
                )

                // L38: notify the customer that their order was rejected.
                let primaryMailer = try await runtime.instance("primary_mailer")
                _ = try await runtime.invoke(
                    tool: "sendEmail",
                    args: [
                        "via": .opaque(AnyHashableSendable(primaryMailer)),
                        "to": .string(customer.email),
                        "subject": .string("We could not process your order"),
                        "body": .string(approval.note)
                    ]
                )

                // L39: complete with reason "approval_denied".
                await runtime.complete(reason: "approval_denied",
                    sourceRange: SourceRange(file: "order_processing.meridian", line: 39, column: 7))
                return WorkflowResult(
                    reason: "approval_denied",
                    durationMS: Date().timeIntervalSince(startTime) * 1000,
                    eventCount: await runtime.eventCount(),
                    bindings: state.snapshot().asValues
                )
            }
        }

        // L42: bind payment = invoke charge payment with ...
        let stripe = try await runtime.instance("stripe")
        let paymentValue = try await runtime.invoke(
            tool: "chargePayment",
            args: [
                "via": .opaque(AnyHashableSendable(stripe)),
                "customer": .string(customer.id),
                "amount": .money(order.totalAmount),
                "order_id": .string(order.id)
            ],
            sourceRange: SourceRange(file: "order_processing.meridian", line: 42, column: 3)
        )
        state.bind("payment", paymentValue)

        let payment = paymentValue.unwrapOpaque(as: PaymentResult.self)!

        await runtime.recordEvent(.branchTaken, payload: [
            "label": .string(payment.status == PaymentStatus.succeeded ? "then" : "else"),
            "reason": .string("payment.status == succeeded")
        ], sourceRange: SourceRange(file: "order_processing.meridian", line: 48, column: 3))

        // L48: if the payment's status is succeeded, ...
        if payment.status == PaymentStatus.succeeded {
            // L49: approve the order.
            _ = try await runtime.invoke(
                tool: "updateOrder",
                args: ["id": .string(order.id), "status": .string("approved")]
            )
            try await runtime.emit(
                event: "order.approved",
                payload: ["order": .opaque(AnyHashableSendable(order))]
            )

            // L50: notify the customer that their order was approved.
            let primaryMailer = try await runtime.instance("primary_mailer")
            _ = try await runtime.invoke(
                tool: "sendEmail",
                args: [
                    "via": .opaque(AnyHashableSendable(primaryMailer)),
                    "to": .string(customer.email),
                    "subject": .string("Your order is approved"),
                    "body": .string("Your order has been approved and is being prepared for fulfillment.")
                ]
            )

            // L51: complete.
            await runtime.complete(reason: nil,
                sourceRange: SourceRange(file: "order_processing.meridian", line: 51, column: 5))
            return WorkflowResult(
                reason: nil,
                durationMS: Date().timeIntervalSince(startTime) * 1000,
                eventCount: await runtime.eventCount(),
                bindings: state.snapshot().asValues
            )
        }

        // L54: put the order on hold with reason "payment_failed".
        _ = try await runtime.invoke(
            tool: "updateOrder",
            args: ["id": .string(order.id), "status": .string("on hold")]
        )
        try await runtime.emit(
            event: "order.held",
            payload: ["order": .opaque(AnyHashableSendable(order)), "reason": .string("payment_failed")]
        )

        // L56: bind retry count = invoke get retry count with order = the order's id.
        let retryCountValue = try await runtime.invoke(
            tool: "getRetryCount",
            args: ["order": .string(order.id)],
            sourceRange: SourceRange(file: "order_processing.meridian", line: 56, column: 3)
        )
        state.bind("retry_count", retryCountValue)

        let retryCount = try retryCountValue.coerce(to: Int.self)

        // L58: if retry count is less than the maximum retry count, ...
        if retryCount < constants.maximumRetryCount {
            // L59: wait 1 hour.
            try await runtime.wait(.duration(.seconds(3600)))

            // L60: process the order placed by the customer. (recursive)
            let recursiveWorkflow = ProcessOrder(runtime: runtime, order: order, customer: customer)
            _ = try await recursiveWorkflow.run()

            // L61: complete.
            await runtime.complete(reason: nil,
                sourceRange: SourceRange(file: "order_processing.meridian", line: 61, column: 5))
            return WorkflowResult(
                reason: nil,
                durationMS: Date().timeIntervalSince(startTime) * 1000,
                eventCount: await runtime.eventCount(),
                bindings: state.snapshot().asValues
            )
        }

        // L63: reject the order with reason "max_retries_exceeded".
        _ = try await runtime.invoke(
            tool: "updateOrder",
            args: ["id": .string(order.id), "status": .string("rejected")]
        )
        try await runtime.emit(
            event: "order.rejected",
            payload: ["order": .opaque(AnyHashableSendable(order)), "reason": .string("max_retries_exceeded")]
        )

        // L64: notify the customer that their order was rejected.
        let primaryMailer = try await runtime.instance("primary_mailer")
        _ = try await runtime.invoke(
            tool: "sendEmail",
            args: [
                "via": .opaque(AnyHashableSendable(primaryMailer)),
                "to": .string(customer.email),
                "subject": .string("We could not process your order"),
                "body": .string("We could not process your payment after several attempts. Please contact support.")
            ]
        )

        // L65: complete with reason "max_retries_exceeded".
        await runtime.complete(reason: "max_retries_exceeded",
            sourceRange: SourceRange(file: "order_processing.meridian", line: 65, column: 3))
        return WorkflowResult(
            reason: "max_retries_exceeded",
            durationMS: Date().timeIntervalSince(startTime) * 1000,
            eventCount: await runtime.eventCount(),
            bindings: state.snapshot().asValues
        )
    }
}

// MARK: - Value convenience

extension Value {
    func unwrapOpaque<T>(as type: T.Type) -> T? {
        if case .opaque(let box) = self {
            return box.unwrap(as: T.self)
        }
        return nil
    }
}

