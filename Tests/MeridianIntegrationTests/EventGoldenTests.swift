import Testing
import Foundation
import MeridianRuntime
import MeridianTestKit
import EcommerceWorkflows

@Suite("Expected event goldens")
struct EventGoldenTests {
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func next() -> Int {
            lock.withLock {
                let current = value
                value += 1
                return current
            }
        }
    }

    @Test("happy_path expected JSONL matches")
    func happyPath() async throws {
        try await assertGolden(variant: "happy", expected: "happy_path.expected.jsonl")
    }

    @Test("approval_denied expected JSONL matches")
    func approvalDenied() async throws {
        try await assertGolden(variant: "denied", expected: "approval_denied.expected.jsonl")
    }

    @Test("fraud_review expected JSONL matches")
    func fraudReview() async throws {
        try await assertGolden(variant: "fraud", expected: "fraud_review.expected.jsonl")
    }

    @Test("retry_success expected JSONL matches")
    func retrySuccess() async throws {
        try await assertGolden(variant: "retry", expected: "retry_success.expected.jsonl")
    }

    private func assertGolden(variant: String, expected: String) async throws {
        let actual = try await runVariant(variant)
        let expectedURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("examples/expected_events/\(expected)")
        if ProcessInfo.processInfo.environment["MERIDIAN_REGEN_EVENTS"] == "1" {
            try actual.write(to: expectedURL, atomically: true, encoding: .utf8)
        }
        let expectedText = try EventAssertions.loadJSONL(at: expectedURL)
        let actualLines = normalizeStable(EventAssertions.normalize(actual))
        let expectedLines = normalizeStable(EventAssertions.normalize(expectedText))
        #expect(
            EventAssertions.diff(actual: actualLines, expected: expectedLines) == nil,
            Comment(rawValue: EventAssertions.diff(actual: actualLines, expected: expectedLines) ?? "")
        )
    }

    private func normalizeStable(_ lines: [String]) -> [String] {
        lines.map { line in
            var out = line.replacingOccurrences(
                of: #"placementDate: [^\\)]* \+0000"#,
                with: "placementDate: <date>",
                options: .regularExpression
            )
            out = out.replacingOccurrences(
                of: #"properties: \[[^\]]*\]"#,
                with: "properties: <properties>",
                options: .regularExpression
            )
            return out
        }
    }

    private func runVariant(_ variant: String) async throws -> String {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("meridian-events-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        let runtime = Runtime(
            toolRegistry: await makeRegistry(variant: variant),
            instanceRegistry: makeInstanceRegistry(),
            observer: JSONLObserver(destination: .file(outputURL)),
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_745_913_600)),
            runID: runID(for: variant)
        )
        _ = try await ProcessOrder(
            runtime: runtime,
            order: order(for: variant),
            customer: customer(for: variant)
        ).run()
        return try String(contentsOf: outputURL, encoding: .utf8)
    }

    private func makeRegistry(variant: String) async -> ToolRegistry {
        let registry = ToolRegistry()
        await registry.register(tool: "validateOrder", .closure { _ in
            .opaque(AnyHashableSendable(ValidationResult(verdict: .valid)))
        })
        await registry.register(tool: "getAvailableCredit", .closure { _ in
            variant == "denied"
                ? .opaque(AnyHashableSendable(Money(amount: 12_000, currency: "USD")))
                : .opaque(AnyHashableSendable(Money(amount: 7_500, currency: "USD")))
        })
        await registry.register(tool: "runFraudCheck", .closure { _ in
            variant == "fraud" ? .number(0.8) : .number(0.1)
        })
        await registry.register(tool: "requestApproval", .closure { _ in
            variant == "denied"
                ? .opaque(AnyHashableSendable(Approval(verdict: .denied, note: "Order exceeds customer risk profile.")))
                : .opaque(AnyHashableSendable(Approval(verdict: .approved, note: "")))
        })

        let chargeCounter = Counter()
        await registry.register(tool: "chargePayment", .closure { _ in
            if variant == "retry", chargeCounter.next() == 0 {
                return .opaque(AnyHashableSendable(PaymentResult(status: .failed, errorMessage: "card_declined")))
            }
            return .opaque(AnyHashableSendable(PaymentResult(status: .succeeded)))
        })
        await registry.register(tool: "updateOrder", .closure { args in
            let id = (args["id"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }) ?? ""
            let status = (args["status"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }) ?? ""
            return .opaque(AnyHashableSendable(Order(id: id, status: Order.Status(rawValue: status) ?? .submitted)))
        })
        await registry.register(tool: "sendEmail", .closure { _ in .boolean(true) })
        let retryCounter = Counter()
        await registry.register(tool: "getRetryCount", .closure { _ in .number(Decimal(retryCounter.next())) })
        await registry.register(tool: "getOverdueInvoices", .closure { _ in .list([]) })
        return registry
    }

    private func makeInstanceRegistry() -> InstanceRegistry {
        let builder = InstanceRegistry.Builder()
        builder.register(kind: "mailer_server", name: "primary_mailer", properties: [
            "host": .literal(.string("smtp.example.com")),
            "port": .literal(.number(587)),
            "auth_type": .literal(.string("tls"))
        ])
        builder.register(kind: "payment_processor", name: "stripe", properties: [
            "api_endpoint": .literal(.string("https://api.stripe.com/v1")),
            "api_key": .envVar("STRIPE_API_KEY")
        ])
        return builder.build()
    }

    private func runID(for variant: String) -> String {
        switch variant {
        case "denied": return "r-test-denied"
        case "fraud": return "r-test-fraud"
        case "retry": return "r-test-retry"
        default: return "r-test-happy"
        }
    }

    private func customer(for variant: String) -> Customer {
        Customer(
            id: "c-501",
            name: "Alice",
            email: "alice@example.com",
            status: .active,
            creditLimit: Money(amount: 15_000, currency: "USD"),
            tier: .standard,
            signupDate: Calendar.current.date(byAdding: variant == "fraud" ? .day : .year, value: variant == "fraud" ? -1 : -2, to: Date())!,
            accountManager: AccountManager(id: "am-77", name: "Account Manager", email: "am@example.com")
        )
    }

    private func order(for variant: String) -> Order {
        switch variant {
        case "denied":
            return Order(id: "o-2001", status: .submitted, totalAmount: Money(amount: 7_500, currency: "USD"))
        case "fraud":
            return Order(id: "o-3001", status: .submitted, totalAmount: Money(amount: 300, currency: "USD"))
        case "retry":
            return Order(id: "o-4001", status: .submitted, totalAmount: Money(amount: 400, currency: "USD"))
        default:
            return Order(id: "o-1001", status: .submitted, totalAmount: Money(amount: 250, currency: "USD"))
        }
    }
}
