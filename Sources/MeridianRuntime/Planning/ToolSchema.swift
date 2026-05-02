import Foundation

public struct ToolSchema: Sendable, Equatable {
    public let id: String
    public let arguments: [ToolArgSpec]

    public init(id: String, arguments: [ToolArgSpec] = []) {
        self.id = id
        self.arguments = arguments
    }
}

public struct ToolArgSpec: Sendable, Equatable {
    public let name: String
    public let type: String
    public let required: Bool

    public init(name: String, type: String = "Value", required: Bool = true) {
        self.name = name
        self.type = type
        self.required = required
    }
}
