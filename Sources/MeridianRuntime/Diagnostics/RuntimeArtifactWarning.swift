import Foundation

public struct RuntimeArtifactWarning: Sendable, Equatable {
    public let code: String
    public let message: String
    public let runID: String
    public let artifactPath: String?

    public init(code: String, message: String, runID: String, artifactPath: String? = nil) {
        self.code = code
        self.message = message
        self.runID = runID
        self.artifactPath = artifactPath
    }
}

public protocol ArtifactWarningSource: Sendable {
    func consumeArtifactWarnings() async -> [RuntimeArtifactWarning]
}
