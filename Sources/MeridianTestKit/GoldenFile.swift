import Foundation

public struct GoldenFile: Sendable {
    public let url: URL

    public init(_ url: URL) {
        self.url = url
    }

    public func assertMatches(_ actual: String, update: Bool = false) throws -> Bool {
        let normalizedActual = normalize(actual)
        if update || !FileManager.default.fileExists(atPath: url.path) {
            try normalizedActual.write(to: url, atomically: true, encoding: .utf8)
            return true
        }
        let expected = try String(contentsOf: url, encoding: .utf8)
        return normalize(expected) == normalizedActual
    }

    public func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}
