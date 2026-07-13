import Foundation

public struct RuntimeOperationalDiagnostic: Sendable, Equatable {
    public let code: String
    public let message: String
    public let runID: String
    public let timestamp: Date

    public init(code: String, message: String, runID: String, timestamp: Date) {
        self.code = code
        self.message = message
        self.runID = runID
        self.timestamp = timestamp
    }
}
