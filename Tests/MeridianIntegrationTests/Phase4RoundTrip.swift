import Testing
import Foundation
import MeridianRuntime
import MeridianTestKit
import GeneratedOrderProcessing

// MARK: - Phase 4 Round Trip
//
// Phase 4 forcing function (docs/status.md):
//   compile examples/order_processing.meridian
//     → swift build (the generated module)
//     → swift run with canned tools
//     → resulting events match the expected sequence for each scenario.
//
// `GeneratedOrderProcessing` is the SwiftPM target that owns the *committed*
// compiler output (`Sources/SampleDemoFlows/GeneratedOrderProcessing/`). The
// `Phase4GoldenDiff` suite verifies that file is a byte-for-byte match for
// the live compiler output, so:
//   golden-diff passes → committed module == fresh compiler output
//   round-trip passes  → that module behaves correctly at runtime
// Together they form an end-to-end forcing function entirely in-process,
// without the spawn-a-subprocess complexity of `swift build && swift run`.

@Suite("Phase 4 Round Trip — generated ProcessOrder")
struct Phase4RoundTrip {

    // MARK: - Fixtures

    /// Mature customer (signup more than `newCustomerThreshold` ago) so the
    /// fraud-check branch is skipped unless we explicitly opt into it.
    private var matureCustomer: Customer {
        Customer(
            id: "c-501",
            name: "Alice",
            email: "alice@example.com",
            phoneNumber: "",
            status: .active,
            creditLimit: Money(amount: 15_000, currency: "USD"),
            tier: .standard,
            signupDate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        )
    }

    /// Order whose total stays under `highValueThreshold` ($5,000) so the
    /// approval branch is skipped.
    private var lowValueOrder: Order {
        Order(id: "o-1001", status: .submitted,
              totalAmount: Money(amount: 250, currency: "USD"),
              placementDate: Date())
    }

    private var highValueOrder: Order {
        Order(id: "o-2001", status: .submitted,
              totalAmount: Money(amount: 7_500, currency: "USD"),
              placementDate: Date())
    }

    // MARK: - Tool harness

    /// Build a fresh registry preloaded with closure tools that produce the
    /// same shape `state.get("X.field")` expects (since generated codegen
    /// stores tool results as opaque values and traverses via Codable).
    private func makeBaseRegistry(
        validation: ValidationResultVerdict = .valid,
        availableCredit: Decimal = 10_000,
        fraudRisk: Decimal = Decimal(string: "0.1") ?? Decimal(0),
        payment: PaymentResultStatus = .succeeded,
        approval: ApprovalVerdict = .approved
    ) async -> ToolRegistry {
        let registry = ToolRegistry()
        await registry.register(tool: "validateOrder", .closure { _ in
            .record(["verdict": .string(validation.rawValue), "issues": .list([])])
        })
        await registry.register(tool: "getAvailableCredit", .closure { _ in
            .number(availableCredit)
        })
        await registry.register(tool: "runFraudCheck", .closure { _ in
            .number(fraudRisk)
        })
        await registry.register(tool: "requestApproval", .closure { _ in
            .record(["verdict": .string(approval.rawValue), "note": .string("")])
        })
        await registry.register(tool: "chargePayment", .closure { _ in
            .record(["status": .string(payment.rawValue), "error_message": .string("")])
        })
        await registry.register(tool: "updateOrder", .closure { _ in .boolean(true) })
        await registry.register(tool: "sendEmail",   .closure { _ in .boolean(true) })
        return registry
    }

    private func makeRuntime(
        toolRegistry: ToolRegistry,
        observer: any Observer,
        runID: String = "r-test"
    ) -> Runtime {
        Runtime(
            toolRegistry: toolRegistry,
            instanceRegistry: .empty,
            observer: observer,
            runID: runID
        )
    }

    // MARK: - Happy path

    @Test("happy path: low-value valid order completes with reason nil")
    func happyPath() async throws {
        let registry = await makeBaseRegistry()
        let observer = InMemoryObserver()
        let runtime  = makeRuntime(toolRegistry: registry, observer: observer)

        let result = try await ProcessOrder(
            runtime: runtime, order: lowValueOrder, customer: matureCustomer
        ).run()

        #expect(result.reason == nil)

        let events = await observer.events
        let invokes = events.filter { $0.kind == .invokeStart }.compactMap { e -> String? in
            if case .string(let t) = e.payload["tool"] { return t } else { return nil }
        }
        // chargePayment must run, fraud + approval branches stay dormant.
        #expect(invokes.contains("validateOrder"))
        #expect(invokes.contains("getAvailableCredit"))
        #expect(invokes.contains("chargePayment"))
        #expect(!invokes.contains("requestApproval"))

        let emits = events.filter { $0.kind == .emit }.compactMap { e -> String? in
            if case .string(let s) = e.payload["event"] { return s } else { return nil }
        }
        #expect(emits.contains("order.approved"))
    }

    // MARK: - Validation failure

    @Test("invalid validation result → emits order.rejected with validation_failed")
    func validationFailure() async throws {
        let registry = await makeBaseRegistry(validation: .invalid)
        let observer = InMemoryObserver()
        let runtime  = makeRuntime(toolRegistry: registry, observer: observer)

        _ = try await ProcessOrder(
            runtime: runtime, order: lowValueOrder, customer: matureCustomer
        ).run()

        let events = await observer.events
        let rejected = events.filter { $0.kind == .emit }.first { e in
            if case .string("order.rejected") = e.payload["event"] { return true }
            return false
        }
        #expect(rejected != nil)
        if case .string(let reason)? = rejected?.payload["reason"] {
            #expect(reason == "validation_failed")
        }
    }

    // MARK: - Insufficient credit

    @Test("insufficient credit → emits order.rejected with insufficient_credit")
    func insufficientCredit() async throws {
        // Credit 100 < 250 (lowValueOrder.totalAmount).
        let registry = await makeBaseRegistry(availableCredit: 100)
        let observer = InMemoryObserver()
        let runtime  = makeRuntime(toolRegistry: registry, observer: observer)

        _ = try await ProcessOrder(
            runtime: runtime, order: lowValueOrder, customer: matureCustomer
        ).run()

        let events = await observer.events
        let rejected = events.filter { $0.kind == .emit }.first { e in
            if case .string("order.rejected") = e.payload["event"] { return true }
            return false
        }
        #expect(rejected != nil)
        if case .string(let reason)? = rejected?.payload["reason"] {
            #expect(reason == "insufficient_credit")
        }
    }

    // MARK: - High-value approval denied

    @Test("high-value order + denied approval → completes with approval_denied reason")
    func approvalDenied() async throws {
        let registry = await makeBaseRegistry(
            availableCredit: 20_000, approval: .denied
        )
        let observer = InMemoryObserver()
        let runtime  = makeRuntime(toolRegistry: registry, observer: observer)

        let result = try await ProcessOrder(
            runtime: runtime, order: highValueOrder, customer: matureCustomer
        ).run()

        #expect(result.reason == "approval_denied")

        let events = await observer.events
        // chargePayment must NOT run after a denied approval.
        let charged = events.filter { $0.kind == .invokeStart }.contains { e in
            if case .string("chargePayment") = e.payload["tool"] { return true }
            return false
        }
        #expect(!charged)
    }

    // MARK: - JSONL stream parity (golden hash)

    @Test("invoke + emit kinds are deterministic for the happy path")
    func happyPathKindHash() async throws {
        let registry = await makeBaseRegistry()
        let observer = InMemoryObserver()
        let runtime  = makeRuntime(toolRegistry: registry, observer: observer)

        _ = try await ProcessOrder(
            runtime: runtime, order: lowValueOrder, customer: matureCustomer
        ).run()

        let events = await observer.events
        // Only bind & branch are non-deterministic w.r.t. ordering across
        // builds; the high-level event sequence below is.
        let highLevelKinds: [EventKind] = events
            .map { $0.kind }
            .filter { kind in
                kind == EventKind.workflowStarted || kind == EventKind.workflowCompleted ||
                kind == EventKind.invokeStart      || kind == EventKind.invokeEnd          ||
                kind == EventKind.emit
            }

        // Expected: workflow.started, then per-tool invokeStart/invokeEnd
        // pairs interleaved with emits, then workflow.completed.
        #expect(highLevelKinds.first == EventKind.workflowStarted)
        #expect(highLevelKinds.last  == EventKind.workflowCompleted)

        let invokeStarts = highLevelKinds.filter { $0 == EventKind.invokeStart }.count
        let invokeEnds   = highLevelKinds.filter { $0 == EventKind.invokeEnd }.count
        // Every invokeStart must pair with an invokeEnd (no half-open invokes).
        #expect(invokeStarts == invokeEnds)
        #expect(invokeStarts >= 4)   // at least validate, credit, charge, sendEmail
    }

    // MARK: - Phase C: rule-injected runtime asserts

    @Test("Phase C invariant: suspended customer triggers MeridianRuntimeError.assertion")
    func suspendedCustomerAssertFires() async throws {
        // The order_processing.meridian rule
        //   "A customer with status suspended must not place orders."
        // injects a runtime.assert at the start of every workflow that takes
        // a customer parameter. A suspended customer must therefore throw
        // MeridianRuntimeError.assertion when ProcessOrder.run() is called.
        let suspendedCustomer = Customer(
            id: "c-901",
            name: "SuspendedAlice",
            email: "alice@example.com",
            phoneNumber: "",
            status: .suspended,
            creditLimit: Money(amount: 10_000, currency: "USD"),
            tier: .standard,
            signupDate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        )

        let registry = await makeBaseRegistry()
        let observer = InMemoryObserver()
        let runtime  = makeRuntime(toolRegistry: registry, observer: observer, runID: "r-suspended")

        var thrown: (any Error)? = nil
        do {
            _ = try await ProcessOrder(
                runtime: runtime, order: lowValueOrder, customer: suspendedCustomer
            ).run()
        } catch {
            thrown = error
        }

        // The injected assert must fire. Use case-pattern match because
        // MeridianRuntimeError doesn't conform to Equatable.
        guard case let .assertion(message, _)? = thrown as? MeridianRuntimeError else {
            Issue.record("Expected MeridianRuntimeError.assertion, got \(String(describing: thrown))")
            return
        }
        #expect(message.lowercased().contains("must not"))
        #expect(message.lowercased().contains("suspended"))

        // The runtime must have emitted an `assert.failed` event before
        // the throw, so the JSONL trail records the violation.
        let events = await observer.events
        let assertFailed = events.first { $0.kind == .assertFailed }
        #expect(assertFailed != nil, "Expected an assert.failed event in the run's JSONL trail")
    }

    @Test("Phase C parameterGuard: amount > credit limit triggers assertion")
    func overCreditLimitAssertFires() async throws {
        // The rule
        //   "A customer must not place an order whose total amount is
        //    more than their credit limit."
        // injects an assert that totalAmount > credit limit must NOT hold.
        // Build a customer with low credit and an order that exceeds it.
        let lowCreditCustomer = Customer(
            id: "c-902",
            name: "Bob",
            email: "bob@example.com",
            phoneNumber: "",
            status: .active,
            creditLimit: Money(amount: 100, currency: "USD"),  // very low
            tier: .standard,
            signupDate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        )
        let bigOrder = Order(
            id: "o-big",
            status: .submitted,
            totalAmount: Money(amount: 50_000, currency: "USD"),  // way over
            placementDate: Date()
        )

        let registry = await makeBaseRegistry()
        let observer = InMemoryObserver()
        let runtime  = makeRuntime(toolRegistry: registry, observer: observer, runID: "r-overlimit")

        var thrown: (any Error)? = nil
        do {
            _ = try await ProcessOrder(
                runtime: runtime, order: bigOrder, customer: lowCreditCustomer
            ).run()
        } catch {
            thrown = error
        }
        guard case let .assertion(message, _)? = thrown as? MeridianRuntimeError else {
            Issue.record("Expected MeridianRuntimeError.assertion, got \(String(describing: thrown))")
            return
        }
        #expect(message.lowercased().contains("credit limit"))
    }

    @Test("Phase C: invariants do NOT fire for compliant orders")
    func compliantOrderPassesAsserts() async throws {
        // Sanity check: an active customer, low-value order, ample credit
        // — none of the rule asserts should fire.
        let registry = await makeBaseRegistry()
        let observer = InMemoryObserver()
        let runtime  = makeRuntime(toolRegistry: registry, observer: observer, runID: "r-compliant")

        let result = try await ProcessOrder(
            runtime: runtime, order: lowValueOrder, customer: matureCustomer
        ).run()

        #expect(result.reason == nil)
        let events = await observer.events
        // assert.passed events must be present (proving the asserts ran)
        // and no assert.failed events.
        let assertPassed = events.filter { $0.kind == .assertPassed }
        let assertFailed = events.filter { $0.kind == .assertFailed }
        #expect(!assertPassed.isEmpty,
                Comment(rawValue: "Expected at least one assert.passed event; got: \(events.map { $0.kind })"))
        #expect(assertFailed.isEmpty,
                Comment(rawValue: "Expected no assert.failed events; got: \(assertFailed.map { $0.payload })"))
    }
}
