import Testing
import Foundation
@testable import MeridianRuntime

@Suite("Permission + PermissionRegistry")
struct PermissionTests {
    @Test("a permission evaluates its predicate over a scope")
    func evaluate() {
        let p = Permission(subjectKind: "user", actionDisplayName: "place order",
                           description: "users may place orders") { scope in
            scope.actor != nil
        }
        #expect(p.isBounded == false)
        #expect(p.evaluate(PermissionScope(actor: .string("alice"))))
        #expect(!p.evaluate(PermissionScope()))
    }

    @Test("registry allows unknown actions and ORs registered permissions")
    func registry() async {
        let reg = PermissionRegistry()
        // No permissions registered → allowed by default.
        #expect(await reg.evaluate(action: "anything", scope: PermissionScope()))

        await reg.register(Permission(subjectKind: "user", actionDisplayName: "Approve",
                                      description: "", isBounded: true) { $0.actor != nil })
        #expect(await reg.evaluate(action: "approve", scope: PermissionScope(actor: .string("x"))))
        #expect(!(await reg.evaluate(action: "approve", scope: PermissionScope())))
    }

    @Test("the shared empty registry allows everything")
    func emptyRegistry() async {
        #expect(await PermissionRegistry.empty.evaluate(action: "x", scope: PermissionScope()))
    }

    @Test("tool permission patterns gate planned actions on argument constraints")
    func toolPermissionPatterns() async {
        let reg = PermissionRegistry()
        #expect(await reg.hasToolPatterns == false)

        await reg.register(toolPattern: ToolPermissionPattern(
            toolID: "demo.tool",
            argumentConstraints: [ToolArgumentConstraint(path: "channel", expected: .string("#alerts"))]
        ))
        #expect(await reg.hasToolPatterns == true)

        #expect(await reg.permitsPlannedAction(ProposedAction(toolID: "other.tool")))
        #expect(await reg.permitsPlannedAction(
            ProposedAction(toolID: "demo.tool", arguments: ["channel": .string("#alerts")])
        ))
        #expect(!(await reg.permitsPlannedAction(
            ProposedAction(toolID: "demo.tool", arguments: ["channel": .string("#general")])
        )))
        #expect(!(await reg.permitsPlannedAction(ProposedAction(toolID: "demo.tool"))))
    }
}

@Suite("Clock — SystemClock and TestClock")
struct ClockTests {
    @Test("SystemClock.now advances with wall time and is reachable via .system")
    func systemClock() {
        let c = SystemClock.system
        #expect(c.now().timeIntervalSince1970 > 0)
    }

    @Test("TestClock advance wakes a sleeper whose duration has elapsed")
    func testClockAdvance() async throws {
        let clock = TestClock()
        let start = await clock.currentDate()
        await clock.advance(by: .seconds(60))
        let after = await clock.currentDate()
        #expect(after.timeIntervalSince(start) == 60)
        // nonisolated now() returns the fixed golden timestamp.
        #expect(clock.now().timeIntervalSince1970 == 1_745_913_600)
    }

    @Test("a sleeper resumes once virtual time passes its duration")
    func testClockSleep() async throws {
        let clock = TestClock()
        let task = Task { try await clock.sleep(for: .seconds(5)) }
        // Give the task a moment to register its continuation.
        try await Task.sleep(for: .milliseconds(20))
        await clock.advance(by: .seconds(10))
        try await task.value   // resumes without throwing
    }
}

@Suite("Runtime.wait(.duration, timeout:)")
struct WaitDurationTimeoutTests {

    @Test("a timeout shorter than the wait duration throws MeridianRuntimeError.timeout")
    func timeoutShorterThanDurationThrows() async throws {
        let clock = TestClock()
        let runtime = Runtime(toolRegistry: ToolRegistry(), clock: clock)
        let task = Task {
            try await runtime.wait(.duration(.seconds(10)), timeout: .seconds(2))
        }
        try await Task.sleep(for: .milliseconds(20))
        await clock.advance(by: .seconds(2))

        var threwTimeout = false
        do {
            try await task.value
        } catch let err as MeridianRuntimeError {
            if case .timeout = err { threwTimeout = true }
        }
        #expect(threwTimeout)
    }

    @Test("a timeout longer than the wait duration lets the wait complete normally")
    func timeoutLongerThanDurationSucceeds() async throws {
        let clock = TestClock()
        let runtime = Runtime(toolRegistry: ToolRegistry(), clock: clock)
        let task = Task {
            try await runtime.wait(.duration(.seconds(2)), timeout: .seconds(10))
        }
        try await Task.sleep(for: .milliseconds(20))
        await clock.advance(by: .seconds(2))
        try await task.value   // resolves without throwing
    }

    @Test("no timeout sleeps for the full duration")
    func noTimeoutSleepsFullDuration() async throws {
        let clock = TestClock()
        let runtime = Runtime(toolRegistry: ToolRegistry(), clock: clock)
        let task = Task { try await runtime.wait(.duration(.seconds(3))) }
        try await Task.sleep(for: .milliseconds(20))
        await clock.advance(by: .seconds(3))
        try await task.value
    }
}

@Suite("LLMProvider value types")
struct LLMProviderTests {
    @Test("request and response carry their fields")
    func types() {
        let req = LLMRequest(messages: [LLMMessage(role: .system, content: "be terse"),
                                        LLMMessage(role: .user, content: "hi")],
                             temperature: 0.5, maxTokens: 100,
                             responseFormat: .jsonSchema("{}"), stop: ["END"])
        #expect(req.messages.count == 2)
        #expect(req.messages[0].role == .system)
        #expect(req.responseFormat == .jsonSchema("{}"))
        #expect(req.stop == ["END"])

        let resp = LLMResponse(text: "ok", model: "m", inputTokens: 3, outputTokens: 4, stopReason: "stop")
        #expect(resp.text == "ok")
        #expect(resp.outputTokens == 4)
        #expect(LLMRole.assistant.rawValue == "assistant")
        #expect(LLMResponseFormat.text != .jsonObject)
    }
}
