import Testing
import Foundation
import MeridianTestKit
@testable import MeridianRuntime

/// Runtime integration for SEM-2-02 (MERIDIAN_SEMANTICS §2.3): optional/`nothing`
/// member projection must not default-match, and recover routing must engage when a
/// blocking assert on a missing projection fails — mirroring generated
/// `state.get("page.owner")` + `MeridianComparison` + `do { } catch { recover }`.
@Suite("Inform7 SEM-2-02 — optional/nothing projection + recover")
struct SEM202NothingRecoverRuntimeTests {
    private let pageWithoutOwner = Value.record(["id": .string("p-1")])
    private let pageWithOwner = Value.record([
        "id": .string("p-2"),
        "owner": .string("alice"),
    ])

    @Test("SEM_2_02 State.get projection stays nothing and does not default-match")
    func stateProjectionDoesNotDefaultMatch() {
        var state = State()
        state.bind("page", pageWithoutOwner)
        #expect(state.get("page.owner") == nil)
        #expect(!MeridianComparison.eq(state.get("page.owner"), .string("alice")))
        #expect(!MeridianComparison.isNotEmpty(state.get("page.owner")))

        state.bind("page", pageWithOwner)
        #expect(state.get("page.owner") == .string("alice"))
        #expect(MeridianComparison.eq(state.get("page.owner"), .string("alice")))
    }

    @Test("SEM_2_02 Value.member projection stays nothing through nested paths")
    func memberProjectionThroughNothing() {
        #expect(pageWithoutOwner.member("owner") == nil)
        #expect(pageWithoutOwner.member("owner.email") == nil)
        #expect(!MeridianComparison.eq(pageWithoutOwner.member("owner"), .string("alice")))

        #expect(pageWithOwner.member("owner") == .string("alice"))
        #expect(MeridianComparison.eq(pageWithOwner.member("owner"), .string("alice")))
    }

    @Test("SEM_2_02 guarded branch does not fire when owner projection is nothing")
    func guardedBranchSkipsNothingPath() {
        var state = State()
        state.bind("page", pageWithoutOwner)
        let ownerPresent = MeridianComparison.isNotEmpty(state.get("page.owner"))
        let ownerMatchesAlice = MeridianComparison.eq(state.get("page.owner"), .string("alice"))
        #expect(!ownerPresent)
        #expect(!ownerMatchesAlice)
        let branchTaken = ownerPresent && ownerMatchesAlice
        #expect(!branchTaken)
    }

    @Test("SEM_2_02 recover routes when nothing projection fails blocking assert")
    func recoverRoutesMissingOwnerAssertion() async throws {
        let harness = await WorkflowTestHarness()
        let outcome = try await harness.run { runtime -> Value in
            var state = State()
            state.bind("page", Value.record(["id": .string("p-1")]))
            await runtime.workflowStarted(workflowName: "ReviewPage", parameters: [:])
            var recovered = false
            do {
                try await runtime.assert(
                    MeridianComparison.isNotEmpty(state.get("page.owner")),
                    message: "page must have an owner before review"
                )
                await runtime.complete(reason: "owned")
            } catch {
                try await runtime.recordRecoverEngaged(pattern: "any", step: "/ReviewPage/recover")
                recovered = true
                await runtime.complete(reason: "missing owner")
            }
            return .boolean(recovered)
        }
        #expect(outcome.succeeded)
        if case .boolean(let recovered) = outcome.result {
            #expect(recovered)
        } else {
            Issue.record("expected recovered=true, got \(outcome.result)")
        }
        let kinds = await harness.eventKinds()
        #expect(kinds.contains(.recoverEngaged))
        let events = await harness.events()
        let recoverEvent = events.first { $0.kind == .recoverEngaged }
        #expect((recoverEvent?.payload ?? [:])["pattern"] == .string("any"))
        #expect((recoverEvent?.payload ?? [:])["step"] == .string("/ReviewPage/recover"))
    }
}
