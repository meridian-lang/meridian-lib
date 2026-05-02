import Foundation
import MeridianRuntime

public struct MockToolRegistry: Sendable {
    public let registry: ToolRegistry

    public init() {
        self.registry = ToolRegistry()
    }

    public func stub(_ toolID: String, return value: Value) async {
        await registry.register(tool: toolID, .closure { _ in value })
    }

    public func stub(
        _ toolID: String,
        handler: @escaping @Sendable ([String: Value]) async throws -> Value
    ) async {
        await registry.register(tool: toolID, .closure(handler))
    }
}
