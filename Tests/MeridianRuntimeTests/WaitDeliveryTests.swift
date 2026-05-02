import Testing
import Foundation
@testable import MeridianRuntime

// MARK: - Shared test helpers

private func makeRuntime(observer: any Observer = InMemoryObserver()) -> Runtime {
    Runtime(toolRegistry: ToolRegistry(), observer: observer, runID: "r-wait-\(UUID().uuidString)")
}

// MARK: - Wait delivery tests

@Suite("wait(.signal) — delivery")
struct SignalWaitTests {

    @Test("deliverSignal wakes a waiting workflow and emits wait.start + wait.resume")
    func signalDeliverWakes() async throws {
        let observer = InMemoryObserver()
        let runtime = makeRuntime(observer: observer)
        let result = try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await runtime.wait(.signal("order.ready")) }
            group.addTask {
                try await Task.sleep(for: .milliseconds(10))
                await runtime.deliverSignal("order.ready")
            }
            try await group.waitForAll()
        }
        _ = result
        let kinds = await observer.events.map(\.kind)
        #expect(kinds.contains(.waitStart))
        #expect(kinds.contains(.waitResume))
    }

    @Test("deliverSignal with no waiter is a no-op (not a crash)")
    func signalDropped() async {
        let runtime = makeRuntime()
        await runtime.deliverSignal("nobody-listening")
    }

    @Test("wait(.signal) emits wait.start payload with kind=signal and name")
    func signalWaitStartPayload() async throws {
        let observer = InMemoryObserver()
        let runtime = makeRuntime(observer: observer)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await runtime.wait(.signal("review")) }
            group.addTask {
                try await Task.sleep(for: .milliseconds(10))
                await runtime.deliverSignal("review")
            }
            try await group.waitForAll()
        }
        let startEvent = await observer.events.first { $0.kind == .waitStart }
        #expect(startEvent != nil)
        #expect(startEvent?.payload["kind"] == .string("signal"))
        #expect(startEvent?.payload["name"] == .string("review"))
    }

    @Test("two sequential deliveries each wake exactly one waiter")
    func signalTwoDeliveries() async throws {
        let runtime = makeRuntime()
        // Start two concurrent waits, then deliver two signals.
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await runtime.wait(.signal("ping")) }
            group.addTask { try await runtime.wait(.signal("ping")) }
            group.addTask {
                try await Task.sleep(for: .milliseconds(20))
                await runtime.deliverSignal("ping")
                await runtime.deliverSignal("ping")
            }
            try await group.waitForAll()
        }
        // If we reach here, both waiters were successfully woken.
    }
}

// MARK: - Approval wait tests

@Suite("wait(.approval) — delivery")
struct ApprovalWaitTests {

    @Test("deliverApproval(.approved) resumes normally")
    func approvalApproved() async throws {
        let runtime = makeRuntime()
        let subject = Value.string("order-101")
        let role = RoleRef.accountManager

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await runtime.wait(.approval(of: subject, by: role)) }
            group.addTask {
                try await Task.sleep(for: .milliseconds(10))
                await runtime.deliverApproval(of: subject, by: role, verdict: .approved)
            }
            try await group.waitForAll()
        }
    }

    @Test("deliverApproval(.denied) throws MeridianRuntimeError.approvalDenied")
    func approvalDenied() async throws {
        let runtime = makeRuntime()
        let subject = Value.string("order-202")
        let role = RoleRef.accountManager

        var threwApprovalDenied = false
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await runtime.wait(.approval(of: subject, by: role)) }
                group.addTask {
                    try await Task.sleep(for: .milliseconds(10))
                    await runtime.deliverApproval(of: subject, by: role, verdict: .denied)
                }
                try await group.waitForAll()
            }
        } catch let err as MeridianRuntimeError {
            if case .approvalDenied = err { threwApprovalDenied = true }
        }
        #expect(threwApprovalDenied, "Expected approvalDenied error from denied approval")
    }

    @Test("deliverApproval with no waiter is a no-op")
    func approvalDropped() async {
        let runtime = makeRuntime()
        await runtime.deliverApproval(of: .null, by: RoleRef("nobody"), verdict: .approved)
    }

    @Test("approval keyed by subject — delivering for wrong subject does not wake waiter")
    func approvalSubjectIdentity() async throws {
        let runtime = makeRuntime()
        let subjectA = Value.string("order-A")
        let subjectB = Value.string("order-B")
        let role = RoleRef.accountManager

        let waitTask = Task {
            try await runtime.wait(.approval(of: subjectA, by: role))
        }
        try await Task.sleep(for: .milliseconds(10))
        // Deliver for B — should NOT wake the A waiter.
        await runtime.deliverApproval(of: subjectB, by: role, verdict: .approved)
        try await Task.sleep(for: .milliseconds(10))
        #expect(!waitTask.isCancelled)
        // Now deliver for A — should wake it.
        await runtime.deliverApproval(of: subjectA, by: role, verdict: .approved)
        try await waitTask.value
    }
}

// MARK: - Event wait tests

@Suite("wait(.event) — delivery")
struct EventWaitTests {

    @Test("deliverEvent wakes a matching event waiter")
    func eventDelivered() async throws {
        let observer = InMemoryObserver()
        let runtime = makeRuntime(observer: observer)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await runtime.wait(.event("payment.confirmed", matching: nil)) }
            group.addTask {
                try await Task.sleep(for: .milliseconds(10))
                let evt = Event(timestamp: Date(), runID: "ext", sequence: 1, kind: .emit,
                                payload: ["event": .string("payment.confirmed")])
                await runtime.deliverEvent(evt)
            }
            try await group.waitForAll()
        }

        let kinds = await observer.events.map(\.kind)
        #expect(kinds.contains(.waitStart))
        #expect(kinds.contains(.waitResume))
    }

    @Test("deliverEvent with non-matching id does not wake waiter")
    func eventNonMatchingID() async throws {
        let runtime = makeRuntime()
        let waitTask = Task { try await runtime.wait(.event("payment.confirmed", matching: nil)) }
        try await Task.sleep(for: .milliseconds(10))

        let wrongEvt = Event(timestamp: Date(), runID: "ext", sequence: 1, kind: .emit,
                             payload: ["event": .string("payment.failed")])
        await runtime.deliverEvent(wrongEvt)
        try await Task.sleep(for: .milliseconds(10))
        #expect(!waitTask.isCancelled, "waiter should still be parked")
        waitTask.cancel()
    }

    @Test("wait(.event) is woken when the runtime itself emits a matching domain event")
    func eventWokenByInternalEmit() async throws {
        let runtime = makeRuntime()
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await runtime.wait(.event("order.shipped", matching: nil)) }
            group.addTask {
                try await Task.sleep(for: .milliseconds(10))
                try await runtime.emit(event: "order.shipped", payload: [:])
            }
            try await group.waitForAll()
        }
    }

    @Test("event predicate filters on payload field")
    func eventPredicateFilter() async throws {
        let runtime = makeRuntime()
        let waitTask = Task {
            try await runtime.wait(.event("payment.confirmed", matching: { e in
                e.payload["order_id"] == .string("o-999")
            }))
        }
        try await Task.sleep(for: .milliseconds(10))

        // Wrong payload — should not wake.
        let wrongPayload = Event(timestamp: Date(), runID: "ext", sequence: 1, kind: .emit,
                                 payload: ["event": .string("payment.confirmed"), "order_id": .string("o-111")])
        await runtime.deliverEvent(wrongPayload)
        try await Task.sleep(for: .milliseconds(10))
        #expect(!waitTask.isCancelled, "should still be waiting")

        // Correct payload — should wake.
        let rightPayload = Event(timestamp: Date(), runID: "ext", sequence: 1, kind: .emit,
                                 payload: ["event": .string("payment.confirmed"), "order_id": .string("o-999")])
        await runtime.deliverEvent(rightPayload)
        try await waitTask.value
    }
}
