import MeridianTestKit
import Testing
@testable import MeridianRuntime

@Suite("Planning failure codes")
struct PlanningFailureCodeTests {

    @Test("planning failure codes are stable and unique")
    func codesAreStableAndUnique() {
        let codes = PlanningFailureCode.allCases.map(\.rawValue)
        #expect(Set(codes).count == codes.count)
        #expect(codes.allSatisfy { $0.hasPrefix("planning.") })
    }

    @Test("oversized prose has a distinct recoverable code")
    func oversizedProseCode() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime.Builder()
            .setObserver(observer)
            .setPlanningLimits(PlanningResourceLimits(maxProseBytes: 4))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(
                prose: "too long",
                snapshot: State().snapshot(),
                scopedTools: []
            )
        }

        expect(error, hasCode: .prosePayloadTooLarge)
        let events = await observer.events
        #expect(events.contains {
            $0.kind == .planRejected &&
                $0.payload["code"] == .string(PlanningFailureCode.prosePayloadTooLarge.rawValue)
        })
    }

    @Test("too many proposed actions has a distinct recoverable code")
    func tooManyActionsCode() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime.Builder()
            .setObserver(observer)
            .setPlanningLimits(PlanningResourceLimits(maxActions: 1))
            .setPlanner(MockPlanner(actions: [
                ProposedAction(toolID: "demo.one"),
                ProposedAction(toolID: "demo.two")
            ]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(
                prose: "too many",
                snapshot: State().snapshot(),
                scopedTools: ["demo.one", "demo.two"]
            )
        }

        expect(error, hasCode: .tooManyActions)
        let events = await observer.events
        #expect(events.contains {
            $0.kind == .planError &&
                $0.payload["error_code"] == .string(PlanningFailureCode.tooManyActions.rawValue)
        })
    }

    @Test("oversized tool arguments have a distinct recoverable code")
    func toolArgumentsPayloadCode() async throws {
        let registry = ToolRegistry()
        let observer = InMemoryObserver()
        await registry.register(tool: "demo.tool", .closure { _ in .string("should not run") })
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setObserver(observer)
            .setPlanningLimits(PlanningResourceLimits(maxToolArgumentBytes: 4))
            .setPlanner(MockPlanner(actions: [
                ProposedAction(toolID: "demo.tool", arguments: ["payload": .string("too long")])
            ]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(
                prose: "ok",
                snapshot: State().snapshot(),
                scopedTools: ["demo.tool"]
            )
        }

        expect(error, hasCode: .toolArgumentsPayloadTooLarge)
        let events = await observer.events
        #expect(events.contains {
            $0.kind == .planRejected &&
                $0.payload["code"] == .string(PlanningFailureCode.toolArgumentsPayloadTooLarge.rawValue)
        })
    }

    @Test("host policy denial has a distinct recoverable code")
    func hostPolicyDeniedCode() async throws {
        let registry = ToolRegistry()
        let observer = InMemoryObserver()
        await registry.register(tool: "danger.tool", .closure { _ in .string("should not run") })
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setObserver(observer)
            .setPlanPolicy(DenyListPlanPolicy(deniedToolIDs: ["danger.tool"]))
            .setPlanner(MockPlanner(actions: [ProposedAction(toolID: "danger.tool")]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(
                prose: "try danger",
                snapshot: State().snapshot(),
                scopedTools: ["danger.tool"]
            )
        }

        expect(error, hasCode: .hostPolicyDenied)
        let events = await observer.events
        #expect(events.contains {
            $0.kind == .planRejected &&
                $0.payload["code"] == .string(PlanningFailureCode.hostPolicyDenied.rawValue)
        })
    }

    @Test("out-of-scope planner tool has a distinct recoverable code")
    func toolOutOfScopeCode() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime.Builder()
            .setObserver(observer)
            .setPlanner(MockPlanner(actions: [ProposedAction(toolID: "attacker.tool")]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(
                prose: "try to escape",
                snapshot: State().snapshot(),
                scopedTools: ["allowed.tool"]
            )
        }

        expect(error, hasCode: .toolOutOfScope)
        let events = await observer.events
        #expect(events.contains {
            $0.kind == .planError &&
                $0.payload["error_code"] == .string(PlanningFailureCode.toolOutOfScope.rawValue)
        })
    }

    @Test("unregistered in-scope planner tool has a distinct recoverable code")
    func toolNotRegisteredCode() async throws {
        let observer = InMemoryObserver()
        let runtime = Runtime.Builder()
            .setObserver(observer)
            .setPlanner(MockPlanner(actions: [ProposedAction(toolID: "missing.tool")]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(
                prose: "try missing",
                snapshot: State().snapshot(),
                scopedTools: ["missing.tool"]
            )
        }

        expect(error, hasCode: .toolNotRegistered)
        let events = await observer.events
        #expect(events.contains {
            $0.kind == .planError &&
                $0.payload["error_code"] == .string(PlanningFailureCode.toolNotRegistered.rawValue)
        })
    }

    @Test("autonomy max steps has a distinct recoverable code")
    func autonomyMaxStepsCode() async throws {
        let runtime = Runtime.Builder()
            .setObserver(InMemoryObserver())
            .build()

        let error = await captureError {
            _ = try await runtime.executeAutonomousLoop(
                prose: "keep working",
                snapshot: State().snapshot(),
                scopedTools: [],
                maxSteps: 0
            )
        }

        expect(error, hasCode: .maxStepsExceeded)
    }

    @Test("autonomy replan action cap has a distinct recoverable code")
    func replanTooManyActionsCode() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "fail.tool", .closure { _ in
            throw ToolError.implementation(code: "demo.failure", message: "boom", cause: nil)
        })
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setObserver(InMemoryObserver())
            .setActPlanner(MockActPlanner([.action(ProposedAction(toolID: "fail.tool"))]))
            .setPlanner(MockPlanner(actions: [
                ProposedAction(toolID: "repair.one"),
                ProposedAction(toolID: "repair.two")
            ]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeAutonomousLoop(
                prose: "recover",
                snapshot: State().snapshot(),
                scopedTools: ["fail.tool", "repair.one", "repair.two"],
                maxSteps: 2,
                replanAfterFailures: 1
            )
        }

        expect(error, hasCode: .replanTooManyActions)
    }

    @Test("oversized snapshot has a distinct recoverable code")
    func oversizedSnapshotCode() async throws {
        var state = State()
        state.bind("large", Value.string("too large"))
        let observer = InMemoryObserver()
        let runtime = Runtime.Builder()
            .setObserver(observer)
            .setPlanningLimits(PlanningResourceLimits(maxSnapshotBytes: 4))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(
                prose: "ok",
                snapshot: state.snapshot(),
                scopedTools: []
            )
        }

        expect(error, hasCode: .snapshotPayloadTooLarge)
        let events = await observer.events
        #expect(events.contains {
            $0.kind == .planRejected &&
                $0.payload["code"] == .string(PlanningFailureCode.snapshotPayloadTooLarge.rawValue)
        })
    }

    @Test("oversized planner proposal has a distinct recoverable code")
    func oversizedProposalCode() async throws {
        let runtime = Runtime.Builder()
            .setObserver(InMemoryObserver())
            .setPlanningLimits(PlanningResourceLimits(maxProposalBytes: 8))
            .setPlanner(MockPlanner([PlanProposal(actions: [], rationale: "this proposal is too large")]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(
                prose: "ok",
                snapshot: State().snapshot(),
                scopedTools: []
            )
        }

        expect(error, hasCode: .proposalPayloadTooLarge)
    }

    @Test("oversized autonomy history has a distinct recoverable code")
    func oversizedHistoryCode() async throws {
        let registry = ToolRegistry()
        await registry.register(tool: "fail.tool", .closure { _ in
            throw ToolError.implementation(code: "demo.failure", message: "a long failure message", cause: nil)
        })
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setObserver(InMemoryObserver())
            .setPlanningLimits(PlanningResourceLimits(maxHistoryBytes: 4))
            .setActPlanner(MockActPlanner([
                .action(ProposedAction(toolID: "fail.tool")),
                .action(ProposedAction(toolID: "fail.tool"))
            ]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeAutonomousLoop(
                prose: "keep trying",
                snapshot: State().snapshot(),
                scopedTools: ["fail.tool"],
                maxSteps: 3,
                replanAfterFailures: 0
            )
        }

        expect(error, hasCode: .historyPayloadTooLarge)
    }

    private func captureError(_ body: () async throws -> Void) async -> any Error {
        do {
            try await body()
            Issue.record("Expected operation to throw a planning failure")
            return MeridianRuntimeError.cancelled
        } catch {
            return error
        }
    }

    private func expect(_ error: any Error, hasCode expected: PlanningFailureCode) {
        #expect(implementationCode(from: error) == expected.rawValue)
        #expect(meridianMatches(error, named: expected.rawValue))
    }

    private func implementationCode(from error: any Error) -> String? {
        guard case .toolError(.implementation(let code, _, _), _) = error as? MeridianRuntimeError else {
            return nil
        }
        return code
    }
}
