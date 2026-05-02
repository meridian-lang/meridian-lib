import Foundation

/// Source location in a Meridian source file.
/// Carried through the IR, preserved in generated Swift via line comments,
/// and surfaced in events and errors for diagnostics.
public struct SourceRange: Codable, Sendable, Hashable {
    public let file: String
    public let startLine: Int
    public let startColumn: Int
    public let endLine: Int
    public let endColumn: Int

    public init(file: String, line: Int, column: Int) {
        self.file = file
        self.startLine = line
        self.startColumn = column
        self.endLine = line
        self.endColumn = column
    }

    public init(
        file: String,
        startLine: Int,
        startColumn: Int,
        endLine: Int,
        endColumn: Int
    ) {
        self.file = file
        self.startLine = startLine
        self.startColumn = startColumn
        self.endLine = endLine
        self.endColumn = endColumn
    }
}

extension SourceRange: CustomStringConvertible {
    public var description: String {
        "\(file):\(startLine):\(startColumn)"
    }
}
