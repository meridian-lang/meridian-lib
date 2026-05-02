import MeridianTestKit
import Testing
@testable import MeridianRuntime

@Suite("Planning validation hardening")
struct PlanningValidationTests {

    @Test("ToolRegistry exposes registered argument schemas")
    func toolRegistryExposesArgumentSchemas() async throws {
        let registry = ToolRegistry()
        let schema = ToolSchema(id: "demo.tool", arguments: [
            ToolArgSpec(name: "input", type: "String"),
            ToolArgSpec(name: "optional", type: "Boolean", required: false)
        ])
        await registry.register(tool: "demo.tool", .closure { _ in .null }, schema: schema)

        #expect(await registry.schemas(Set(["demo.tool"])) == [schema])
    }

    @Test("planner missing required argument is rejected before invocation")
    func missingRequiredArgument() async throws {
        let registry = ToolRegistry()
        await registry.register(
            tool: "demo.tool",
            .closure { _ in .string("should not run") },
            schema: ToolSchema(id: "demo.tool", arguments: [ToolArgSpec(name: "input", type: "String")])
        )
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setPlanner(MockPlanner(actions: [ProposedAction(toolID: "demo.tool")]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(prose: "go", snapshot: State().snapshot(), scopedTools: ["demo.tool"])
        }

        expect(error, hasCode: .missingToolArgument)
    }

    @Test("planner unexpected argument is rejected before invocation")
    func unexpectedArgument() async throws {
        let registry = ToolRegistry()
        await registry.register(
            tool: "demo.tool",
            .closure { _ in .string("should not run") },
            schema: ToolSchema(id: "demo.tool", arguments: [ToolArgSpec(name: "input", type: "String")])
        )
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setPlanner(MockPlanner(actions: [
                ProposedAction(toolID: "demo.tool", arguments: ["input": .string("ok"), "extra": .string("no")])
            ]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(prose: "go", snapshot: State().snapshot(), scopedTools: ["demo.tool"])
        }

        expect(error, hasCode: .unexpectedToolArgument)
    }

    @Test("planner wrong argument type is rejected before invocation")
    func wrongArgumentType() async throws {
        let registry = ToolRegistry()
        await registry.register(
            tool: "demo.tool",
            .closure { _ in .string("should not run") },
            schema: ToolSchema(id: "demo.tool", arguments: [ToolArgSpec(name: "input", type: "String")])
        )
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setPlanner(MockPlanner(actions: [
                ProposedAction(toolID: "demo.tool", arguments: ["input": .number(1)])
            ]))
            .build()

        let error = await captureError {
            _ = try await runtime.executeProsePlan(prose: "go", snapshot: State().snapshot(), scopedTools: ["demo.tool"])
        }

        expect(error, hasCode: .invalidToolArgumentType)
    }

    @Test("valid schema-conforming planner action invokes the tool")
    func validSchemaActionRuns() async throws {
        let registry = ToolRegistry()
        await registry.register(
            tool: "demo.tool",
            .closure { args in args["input"] ?? .null },
            schema: ToolSchema(id: "demo.tool", arguments: [ToolArgSpec(name: "input", type: "String")])
        )
        let runtime = Runtime.Builder()
            .setToolRegistry(registry)
            .setPlanner(MockPlanner(actions: [
                ProposedAction(toolID: "demo.tool", arguments: ["input": .string("ok")], resultBinding: "value")
            ]))
            .build()

        let result = try await runtime.executeProsePlan(
            prose: "go",
            snapshot: State().snapshot(),
            scopedTools: ["demo.tool"]
        )

        #expect(result["value"] == .string("ok"))
    }

    private func captureError(_ body: () async throws -> Void) async -> any Error {
        do {
            try await body()
            Issue.record("Expected operation to throw")
            return MeridianRuntimeError.cancelled
        } catch {
            return error
        }
    }

    private func expect(_ error: any Error, hasCode expected: PlanningFailureCode) {
        guard case .toolError(.implementation(let code, _, _), _) = error as? MeridianRuntimeError else {
            Issue.record("Expected planning implementation error, got \(error)")
            return
        }
        #expect(code == expected.rawValue)
        #expect(meridianMatches(error, named: expected.rawValue))
    }
}
