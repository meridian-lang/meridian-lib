import Foundation

public protocol Discretion: Sendable {
    func decide(_ context: DiscretionContext) async throws -> Bool
}

public struct DiscretionContext: Sendable {
    public let question: String
    public let snapshot: StateSnapshot

    public init(question: String, snapshot: StateSnapshot) {
        self.question = question
        self.snapshot = snapshot
    }
}

public struct DefaultDiscretion: Discretion {
    public init() {}

    public func decide(_ context: DiscretionContext) async throws -> Bool {
        false
    }
}
