import Foundation
import MeridianRuntime

public actor RecordingTool {
    public struct Call: Sendable, Equatable {
        public let args: [String: Value]
        public init(args: [String: Value]) {
            self.args = args
        }
    }

    private var calls: [Call] = []
    private let response: @Sendable ([String: Value]) async throws -> Value

    public init(return value: Value = .null) {
        self.response = { _ in value }
    }

    public init(response: @escaping @Sendable ([String: Value]) async throws -> Value) {
        self.response = response
    }

    public func handler(_ args: [String: Value]) async throws -> Value {
        calls.append(Call(args: args))
        return try await response(args)
    }

    public func recordedCalls() -> [Call] {
        calls
    }
}
