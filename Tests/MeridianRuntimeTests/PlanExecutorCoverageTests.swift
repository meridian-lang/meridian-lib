import Foundation
import Testing
@testable import MeridianRuntime

@Suite("PlanExecutor — validate coverage")
struct PlanExecutorCoverageTests {

    private func expectPlanningCode(_ error: any Error, _ expected: PlanningFailureCode) {
        guard let runtimeError = error as? MeridianRuntimeError,
              case .toolError(.implementation(let code, _, _), _) = runtimeError else {
            Issue.record("expected planning implementation error, got \(error)")
            return
        }
        #expect(code == expected.rawValue)
    }

    @Test("out-of-scope tool is rejected before lookup")
    func outOfScope() async {
        let reg = ToolRegistry()
        await reg.register(tool: "demo.tool", .closure { _ in .null })
        let executor = PlanExecutor(toolRegistry: reg)
        do {
            try await executor.validate(ProposedAction(toolID: "demo.tool"), scopedTools: [])
            Issue.record("expected throw")
        } catch {
            expectPlanningCode(error, .toolOutOfScope)
        }
    }

    @Test("unregistered tool is rejected")
    func unregistered() async {
        let executor = PlanExecutor(toolRegistry: ToolRegistry())
        do {
            try await executor.validate(ProposedAction(toolID: "missing.tool"), scopedTools: ["missing.tool"])
            Issue.record("expected throw")
        } catch {
            expectPlanningCode(error, .toolNotRegistered)
        }
    }

    @Test("schema-less tools skip argument validation")
    func schemaLessToolPasses() async throws {
        let reg = ToolRegistry()
        await reg.register(tool: "noop.tool", .closure { _ in .null })
        let executor = PlanExecutor(toolRegistry: reg)
        try await executor.validate(
            ProposedAction(toolID: "noop.tool", arguments: ["anything": .string("ok")]),
            scopedTools: ["noop.tool"]
        )
    }

    @Test("all supported argument types validate when values match")
    func allSupportedTypesPass() async throws {
        let reg = ToolRegistry()
        let schema = ToolSchema(id: "typed.tool", arguments: [
            ToolArgSpec(name: "b", type: "boolean"),
            ToolArgSpec(name: "n", type: "number"),
            ToolArgSpec(name: "m", type: "money"),
            ToolArgSpec(name: "d", type: "duration"),
            ToolArgSpec(name: "dt", type: "date"),
            ToolArgSpec(name: "dtt", type: "datetime"),
            ToolArgSpec(name: "r", type: "record"),
            ToolArgSpec(name: "l", type: "list"),
            ToolArgSpec(name: "ref", type: "reference"),
            ToolArgSpec(name: "custom", type: "WidgetKind"),
        ])
        await reg.register(tool: "typed.tool", .closure { _ in .null }, schema: schema)
        let executor = PlanExecutor(toolRegistry: reg)
        let now = Date()
        try await executor.validate(
            ProposedAction(toolID: "typed.tool", arguments: [
                "b": .boolean(true),
                "n": .number(3),
                "m": .money(Money(amount: 1, currency: "USD")),
                "d": .duration(.seconds(2)),
                "dt": .date(now),
                "dtt": .dateTime(now),
                "r": .record([:]),
                "l": .list([]),
                "ref": .reference("entity-1"),
                "custom": .string("anything"),
            ]),
            scopedTools: ["typed.tool"]
        )
    }

    @Test("permission argument constraints reject mismatched planner actions")
    func permissionArgumentConstraints() async {
        let reg = ToolRegistry()
        await reg.register(tool: "demo.tool", .closure { _ in .null })
        let permissionRegistry = PermissionRegistry()
        await permissionRegistry.register(toolPattern: ToolPermissionPattern(
            toolID: "demo.tool",
            argumentConstraints: [ToolArgumentConstraint(path: "channel", expected: .string("#alerts"))]
        ))
        let executor = PlanExecutor(toolRegistry: reg)
        do {
            try await executor.validate(
                ProposedAction(toolID: "demo.tool", arguments: ["channel": .string("#general")]),
                scopedTools: ["demo.tool"],
                permissionRegistry: permissionRegistry
            )
            Issue.record("expected throw")
        } catch {
            expectPlanningCode(error, .toolOutOfScope)
        }
    }

    @Test("legacy bare scopedTools pass when no permission patterns registered")
    func legacyBareScopedTools() async throws {
        let reg = ToolRegistry()
        await reg.register(tool: "demo.tool", .closure { _ in .null })
        let executor = PlanExecutor(toolRegistry: reg)
        try await executor.validate(
            ProposedAction(toolID: "demo.tool"),
            scopedTools: ["demo.tool"],
            permissionRegistry: .empty
        )
    }

    @Test("wrong argument types are rejected per schema slot")
    func wrongTypesRejected() async {
        let cases: [(String, String, Value)] = [
            ("b", "boolean", .string("nope")),
            ("n", "number", .string("nope")),
            ("m", "money", .number(1)),
            ("d", "duration", .number(1)),
            ("dt", "date", .number(1)),
            ("dtt", "datetime", .number(1)),
            ("r", "record", .string("nope")),
            ("l", "list", .string("nope")),
            ("ref", "reference", .string("nope")),
        ]
        for (name, type, badValue) in cases {
            let reg = ToolRegistry()
            await reg.register(
                tool: "typed.tool",
                .closure { _ in .null },
                schema: ToolSchema(id: "typed.tool", arguments: [ToolArgSpec(name: name, type: type)])
            )
            let executor = PlanExecutor(toolRegistry: reg)
            do {
                try await executor.validate(
                    ProposedAction(toolID: "typed.tool", arguments: [name: badValue]),
                    scopedTools: ["typed.tool"]
                )
                Issue.record("expected invalid type for \(name)")
            } catch {
                expectPlanningCode(error, .invalidToolArgumentType)
            }
        }
    }
}
