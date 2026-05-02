import Foundation
import MeridianRuntime
import MeridianTestKit
import EcommerceWorkflows

// MARK: - Phase 1 forcing function driver
//
// Usage:
//   swift run order-processing-handwritten happy
//   swift run order-processing-handwritten denied
//   swift run order-processing-handwritten fraud
//   swift run order-processing-handwritten retry
//
// Outputs JSONL event stream to stdout.
// Diff against examples/expected_events/ to validate.

let variant = CommandLine.arguments.dropFirst().first ?? "happy"

// MARK: - Fixtures

let accountManager = AccountManager(id: "am-77", name: "Account Manager", email: "am@example.com")

let standardCustomer = Customer(
    id: "c-501",
    name: "Alice",
    email: "alice@example.com",
    status: .active,
    creditLimit: Money(amount: 15_000, currency: "USD"),
    tier: .standard,
    // signupDate far in the past → not a new customer
    signupDate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!,
    accountManager: accountManager
)

let newCustomer = Customer(
    id: "c-501",
    name: "Alice",
    email: "alice@example.com",
    status: .active,
    creditLimit: Money(amount: 15_000, currency: "USD"),
    tier: .standard,
    // signupDate 1 day ago → new customer (within 30-day threshold)
    signupDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
    accountManager: accountManager
)

let lowValueOrder = Order(
    id: "o-1001",
    status: .submitted,
    totalAmount: Money(amount: 250, currency: "USD")
)

let highValueOrder = Order(
    id: "o-2001",
    status: .submitted,
    totalAmount: Money(amount: 7_500, currency: "USD")
)

let fraudOrder = Order(
    id: "o-3001",
    status: .submitted,
    totalAmount: Money(amount: 300, currency: "USD")
)

let retryOrder = Order(
    id: "o-4001",
    status: .submitted,
    totalAmount: Money(amount: 400, currency: "USD")
)

// MARK: - Tool registry builders

/// Thread-safe mutable counter for use in @Sendable closures.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    func next() -> Int {
        lock.withLock { let v = _value; _value += 1; return v }
    }
}

func makeRegistry(variant: String) async -> ToolRegistry {
    let registry = ToolRegistry()

    await registry.register(tool: "validateOrder", .closure { _ in
        return .opaque(AnyHashableSendable(ValidationResult(verdict: .valid)))
    })

    await registry.register(tool: "getAvailableCredit", .closure { _ in
        switch variant {
        case "denied":
            return .opaque(AnyHashableSendable(Money(amount: 12_000, currency: "USD")))
        default:
            return .opaque(AnyHashableSendable(Money(amount: 7_500, currency: "USD")))
        }
    })

    await registry.register(tool: "runFraudCheck", .closure { _ in
        switch variant {
        case "fraud":
            return .number(0.8)
        default:
            return .number(0.1)
        }
    })

    await registry.register(tool: "requestApproval", .closure { _ in
        switch variant {
        case "denied":
            return .opaque(AnyHashableSendable(Approval(verdict: .denied, note: "Order exceeds customer risk profile.")))
        default:
            return .opaque(AnyHashableSendable(Approval(verdict: .approved, note: "")))
        }
    })

    let chargeCounter = Counter()
    await registry.register(tool: "chargePayment", .closure { _ in
        switch variant {
        case "retry":
            let attempt = chargeCounter.next()
            if attempt == 0 {
                return .opaque(AnyHashableSendable(PaymentResult(status: .failed, errorMessage: "card_declined")))
            } else {
                return .opaque(AnyHashableSendable(PaymentResult(status: .succeeded)))
            }
        default:
            return .opaque(AnyHashableSendable(PaymentResult(status: .succeeded)))
        }
    })

    await registry.register(tool: "updateOrder", .closure { args in
        let id = (args["id"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }) ?? ""
        let statusStr = (args["status"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }) ?? ""
        let order = Order(id: id, status: Order.Status(rawValue: statusStr) ?? .submitted)
        return .opaque(AnyHashableSendable(order))
    })

    await registry.register(tool: "sendEmail", .closure { _ in
        return .boolean(true)
    })

    let retryCounter = Counter()
    await registry.register(tool: "getRetryCount", .closure { _ in
        return .number(Decimal(retryCounter.next()))
    })

    await registry.register(tool: "getOverdueInvoices", .closure { _ in
        return .list([])
    })

    return registry
}

// MARK: - Instance registry

func makeInstanceRegistry() -> InstanceRegistry {
    let builder = InstanceRegistry.Builder()
    builder.register(
        kind: "mailer_server",
        name: "primary_mailer",
        properties: [
            "host": .literal(.string("smtp.example.com")),
            "port": .literal(.number(587)),
            "auth_type": .literal(.string("tls"))
        ]
    )
    builder.register(
        kind: "payment_processor",
        name: "stripe",
        properties: [
            "api_endpoint": .literal(.string("https://api.stripe.com/v1")),
            "api_key": .envVar("STRIPE_API_KEY")
        ]
    )
    return builder.build()
}

// MARK: - Run

Task {
    let registry = await makeRegistry(variant: variant)
    let instances = makeInstanceRegistry()
    let observer = JSONLObserver.stdout
    let runID: String
    let customer: Customer
    let order: Order

    switch variant {
    case "happy":
        runID = "r-test-happy"
        customer = standardCustomer
        order = lowValueOrder
    case "denied":
        runID = "r-test-denied"
        customer = standardCustomer
        order = highValueOrder
    case "fraud":
        runID = "r-test-fraud"
        customer = newCustomer
        order = fraudOrder
    case "retry":
        runID = "r-test-retry"
        customer = standardCustomer
        order = retryOrder
    default:
        fputs("Unknown variant: \(variant). Use: happy | denied | fraud | retry\n", stderr)
        exit(1)
    }

    let runtime = Runtime(
        toolRegistry: registry,
        instanceRegistry: instances,
        observer: observer,
        runID: runID
    )

    let workflow = ProcessOrder(runtime: runtime, order: order, customer: customer)

    do {
        let result = try await workflow.run()
        let reason = result.reason ?? "nil"
        fputs("Completed: \(reason)\n", stderr)
        exit(0)
    } catch {
        fputs("Failed: \(error)\n", stderr)
        exit(1)
    }
}

// Keep the process alive until the Task completes
RunLoop.main.run()
