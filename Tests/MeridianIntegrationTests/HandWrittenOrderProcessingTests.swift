import Testing
import Foundation
import MeridianRuntime
import MeridianTestKit
import EcommerceWorkflows

// MARK: - Phase 1 forcing-function integration tests
//
// Runs ProcessOrder hand-written workflow against canned closure tools.
// Captures event stream and normalizes for structural comparison.
// Validates happy_path, approval_denied, fraud_review scenarios.

@Suite("HandWrittenOrderProcessing")
struct HandWrittenOrderProcessingTests {

    // MARK: - Fixtures

    private let accountManager = AccountManager(
        id: "am-77", name: "Account Manager", email: "am@example.com"
    )

    private var standardCustomer: Customer {
        Customer(
            id: "c-501",
            name: "Alice",
            email: "alice@example.com",
            status: .active,
            creditLimit: Money(amount: 15_000, currency: "USD"),
            tier: .standard,
            signupDate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!,
            accountManager: accountManager
        )
    }

    private var lowValueOrder: Order {
        Order(id: "o-1001", status: .submitted, totalAmount: Money(amount: 250, currency: "USD"))
    }

    private var highValueOrder: Order {
        Order(id: "o-2001", status: .submitted, totalAmount: Money(amount: 7_500, currency: "USD"))
    }

    // MARK: - Registry builders

    private func makeBaseRegistry() async -> ToolRegistry {
        let registry = ToolRegistry()
        await registry.register(tool: "validateOrder", .closure { _ in
            .opaque(AnyHashableSendable(ValidationResult(verdict: .valid)))
        })
        await registry.register(tool: "getAvailableCredit", .closure { _ in
            .opaque(AnyHashableSendable(Money(amount: 10_000, currency: "USD")))
        })
        await registry.register(tool: "runFraudCheck", .closure { _ in
            .number(0.1)
        })
        await registry.register(tool: "updateOrder", .closure { args in
            let id = args["id"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
            return .opaque(AnyHashableSendable(Order(id: id)))
        })
        await registry.register(tool: "sendEmail", .closure { _ in .boolean(true) })
        await registry.register(tool: "getRetryCount", .closure { _ in .number(0) })
        return registry
    }

    private func makeInstanceRegistry() -> InstanceRegistry {
        InstanceRegistry.Builder()
            .register(kind: "mailer_server", name: "primary_mailer", properties: [
                "host": .literal(.string("smtp.example.com"))
            ])
            .register(kind: "payment_processor", name: "stripe", properties: [
                "api_endpoint": .literal(.string("https://api.stripe.com/v1")),
                "api_key": .literal(.string("sk_test"))
            ])
            .build()
    }

    // MARK: - Happy path

    @Test("happy path: completes with reason nil")
    func happyPathCompletes() async throws {
        let registry = await makeBaseRegistry()
        await registry.register(tool: "chargePayment", .closure { _ in
            .opaque(AnyHashableSendable(PaymentResult(status: .succeeded)))
        })

        let observer = InMemoryObserver()
        let runtime = Runtime(
            toolRegistry: registry,
            instanceRegistry: makeInstanceRegistry(),
            observer: observer,
            runID: "r-test-happy"
        )

        let workflow = ProcessOrder(runtime: runtime, order: lowValueOrder, customer: standardCustomer)
        let result = try await workflow.run()

        #expect(result.reason == nil)

        let events = await observer.events
        let kinds = events.map(\.kind)
        #expect(kinds.first == .workflowStarted)
        #expect(kinds.last == .workflowCompleted)
        let invokeStarts = events.filter { $0.kind == .invokeStart }
        #expect(invokeStarts.contains { $0.payload["tool"] == .string("validateOrder") })
        #expect(invokeStarts.contains { $0.payload["tool"] == .string("chargePayment") })
        let emits = events.filter { $0.kind == .emit }
        #expect(emits.contains { $0.payload["event"] == .string("order.approved") })
    }

    @Test("happy path: event sequence numbers are strictly increasing")
    func happyPathEventOrder() async throws {
        let registry = await makeBaseRegistry()
        await registry.register(tool: "chargePayment", .closure { _ in
            .opaque(AnyHashableSendable(PaymentResult(status: .succeeded)))
        })

        let observer = InMemoryObserver()
        let runtime = Runtime(
            toolRegistry: registry,
            instanceRegistry: makeInstanceRegistry(),
            observer: observer,
            runID: "r-test-happy"
        )

        _ = try await ProcessOrder(runtime: runtime, order: lowValueOrder, customer: standardCustomer).run()

        let events = await observer.events
        for (i, event) in events.enumerated() {
            #expect(event.sequence == i + 1)
        }
    }

    // MARK: - Approval denied

    @Test("approval denied: completes with reason approval_denied")
    func approvalDenied() async throws {
        let registry = await makeBaseRegistry()
        await registry.register(tool: "getAvailableCredit", .closure { _ in
            .opaque(AnyHashableSendable(Money(amount: 20_000, currency: "USD")))
        })
        await registry.register(tool: "requestApproval", .closure { _ in
            .opaque(AnyHashableSendable(Approval(verdict: .denied, note: "Risk too high.")))
        })
        await registry.register(tool: "chargePayment", .closure { _ in
            .opaque(AnyHashableSendable(PaymentResult(status: .succeeded)))
        })

        let observer = InMemoryObserver()
        let runtime = Runtime(
            toolRegistry: registry,
            instanceRegistry: makeInstanceRegistry(),
            observer: observer,
            runID: "r-test-denied"
        )

        let result = try await ProcessOrder(runtime: runtime, order: highValueOrder, customer: standardCustomer).run()

        #expect(result.reason == "approval_denied")

        let events = await observer.events
        let invokeStarts = events.filter { $0.kind == .invokeStart }
        #expect(invokeStarts.contains { $0.payload["tool"] == .string("requestApproval") })
        let emits = events.filter { $0.kind == .emit }
        #expect(emits.contains { $0.payload["event"] == .string("order.rejected") })
        #expect(events.last?.kind == .workflowCompleted)
        if case .string(let reason) = events.last?.payload["reason"] {
            #expect(reason == "approval_denied")
        }
    }

    @Test("approval denied: chargePayment is never invoked")
    func approvalDeniedNoCharge() async throws {
        let registry = await makeBaseRegistry()
        await registry.register(tool: "getAvailableCredit", .closure { _ in
            .opaque(AnyHashableSendable(Money(amount: 20_000, currency: "USD")))
        })
        await registry.register(tool: "requestApproval", .closure { _ in
            .opaque(AnyHashableSendable(Approval(verdict: .denied, note: "No.")))
        })

        let observer = InMemoryObserver()
        let runtime = Runtime(
            toolRegistry: registry,
            instanceRegistry: makeInstanceRegistry(),
            observer: observer
        )

        _ = try await ProcessOrder(runtime: runtime, order: highValueOrder, customer: standardCustomer).run()

        let events = await observer.events
        let invokeStarts = events.filter { $0.kind == .invokeStart }
        #expect(!invokeStarts.contains { $0.payload["tool"] == .string("chargePayment") })
    }

    // MARK: - Fraud review

    @Test("fraud review: completes with reason fraud_review_required")
    func fraudReview() async throws {
        let registry = await makeBaseRegistry()
        await registry.register(tool: "runFraudCheck", .closure { _ in .number(0.9) })

        let newCustomer = Customer(
            id: "c-502",
            name: "Bob",
            email: "bob@example.com",
            status: .active,
            creditLimit: Money(amount: 15_000, currency: "USD"),
            tier: .standard,
            signupDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            accountManager: accountManager
        )

        let observer = InMemoryObserver()
        let runtime = Runtime(
            toolRegistry: registry,
            instanceRegistry: makeInstanceRegistry(),
            observer: observer
        )

        let result = try await ProcessOrder(
            runtime: runtime,
            order: Order(id: "o-3001", totalAmount: Money(amount: 300, currency: "USD")),
            customer: newCustomer
        ).run()

        #expect(result.reason == "fraud_review_required")

        let events = await observer.events
        let emits = events.filter { $0.kind == .emit }
        #expect(emits.contains { $0.payload["event"] == .string("order.held") })
    }

    // MARK: - EventAssertions normalization

    @Test("EventAssertions normalization strips ts and run_id")
    func normalizationStripsFields() throws {
        let jsonl = """
        {"ts":"2026-04-29T10:00:00.000Z","run_id":"r-real","seq":1,"kind":"workflow.started","payload":{"workflow":"ProcessOrder"}}
        {"ts":"2026-04-29T10:00:00.100Z","run_id":"r-real","seq":2,"kind":"invoke.end","payload":{"duration_ms":100}}
        """
        let lines = EventAssertions.normalize(jsonl)
        #expect(lines.count == 2)
        #expect(!lines[0].contains("2026-04-29"))
        #expect(!lines[0].contains("r-real"))
        #expect(lines[1].contains("\"duration_ms\":0"))
    }

    @Test("EventAssertions diff returns nil for identical sequences")
    func diffNil() throws {
        let lines = ["{\"seq\":1,\"kind\":\"bind\"}", "{\"seq\":2,\"kind\":\"emit\"}"]
        let result = EventAssertions.diff(actual: lines, expected: lines)
        #expect(result == nil)
    }

    @Test("EventAssertions diff returns description for mismatch")
    func diffMismatch() throws {
        let actual = ["{\"kind\":\"bind\"}"]
        let expected = ["{\"kind\":\"emit\"}"]
        let result = EventAssertions.diff(actual: actual, expected: expected)
        #expect(result != nil)
    }
}
