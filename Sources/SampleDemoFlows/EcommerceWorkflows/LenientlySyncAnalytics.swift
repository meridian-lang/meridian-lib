import Foundation
import MeridianRuntime

// MARK: - Workflow: leniently sync analytics for an order placed by a customer

public struct LenientlySyncAnalytics: MeridianWorkflow {

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

        await runtime.workflowStarted(
            workflowName: "LenientlySyncAnalytics",
            parameters: [
                "order_id": .string(order.id),
                "customer_id": .string(customer.id)
            ]
        )

        // L70: in lenient mode.
        // (modal directive — affects emit codegen below)

        // L72-76: emit analytics.order_processed with ...
        await runtime.emitLenient(
            event: "analytics.order_processed",
            payload: [
                "order_id": .string(order.id),
                "customer_id": .string(customer.id),
                "amount": .money(order.totalAmount),
                "timestamp": .dateTime(Date())
            ]
        )

        // (natural end of workflow — implicit complete)
        await runtime.complete(reason: nil)
        return WorkflowResult(
            reason: nil,
            durationMS: Date().timeIntervalSince(startTime) * 1000,
            eventCount: await runtime.eventCount(),
            bindings: state.snapshot().asValues
        )
    }
}
