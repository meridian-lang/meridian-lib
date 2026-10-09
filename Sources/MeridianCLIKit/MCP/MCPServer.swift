import Foundation
import MeridianCore

public struct MCPServer: Sendable {
    public init() {}

    public enum MCPTool: String, CaseIterable, Sendable {
        case compile = "meridian_compile"
        case check = "meridian_check"
        case explain = "meridian_explain"

        var description: String {
            switch self {
            case .compile: return "Compile a .meridian/.meri source string to Swift."
            case .check: return "Parse and lower a source string; return diagnostics."
            case .explain: return "Return canonical English for a source string."
            }
        }

        var inputSchema: [String: Any] {
            [
                "type": "object",
                "properties": [
                    "source": ["type": "string", "description": "Meridian source text."],
                    "file": ["type": "string", "description": "Virtual filename for diagnostics."],
                    "merconfig": ["type": "string", "description": "Optional .merconfig source."],
                    "merconfig_file": ["type": "string", "description": "Virtual merconfig filename."],
                    "rulebook": ["type": "string", "description": "Optional .merrules source."],
                    "rulebook_file": ["type": "string", "description": "Virtual rulebook filename."],
                ] as [String: Any],
                "required": ["source", "file"],
            ]
        }
    }

    public func handle(_ request: [String: Any]) throws -> [String: Any] {
        guard let method = request["method"] as? String else {
            return errorResponse(id: request["id"], code: -32600, message: "Missing method")
        }
        let id = request["id"]
        switch method {
        case "initialize":
            return successResponse(id: id, result: [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:] as [String: Any]],
                "serverInfo": ["name": "meridian", "version": "0.1.0-alpha"],
            ])
        case "notifications/initialized", "initialized":
            return [:]
        case "tools/list":
            return successResponse(id: id, result: ["tools": Self.toolList()])
        case "tools/call":
            let params = request["params"] as? [String: Any] ?? [:]
            return try successResponse(id: id, result: callTool(params))
        case "ping":
            return successResponse(id: id, result: [:])
        default:
            return errorResponse(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    public func callTool(_ params: [String: Any]) throws -> [String: Any] {
        guard let name = params["name"] as? String,
              let tool = MCPTool(rawValue: name)
        else {
            throw MCPRoutingError.toolNotFound(params["name"] as? String ?? "<missing>")
        }
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        let source = arguments["source"] as? String ?? ""
        let file = arguments["file"] as? String ?? "input.meridian"
        let merconfig = arguments["merconfig"] as? String
        let merconfigFile = arguments["merconfig_file"] as? String ?? "input.merconfig"
        let rulebook = arguments["rulebook"] as? String
        let rulebookFile = arguments["rulebook_file"] as? String ?? "input.merrules"

        var vocabularies: [Compiler.VocabularyInput] = []
        if let merconfig {
            vocabularies.append(.init(name: URL(fileURLWithPath: merconfigFile).deletingPathExtension().lastPathComponent,
                                      file: merconfigFile, source: merconfig))
        }
        var rulebooks: [RulebookInput] = []
        if let rulebook {
            rulebooks.append(.init(name: URL(fileURLWithPath: rulebookFile).deletingPathExtension().lastPathComponent,
                                 file: rulebookFile, source: rulebook))
        }

        let compiler = Compiler(options: .init())
        switch tool {
        case .compile:
            let swift = try compiler.compile(Compiler.CompilationUnit(
                sources: [Compiler.SourceInput(source: source, file: file)],
                vocabularies: vocabularies, rulebooks: rulebooks))[file]?.swift
            return toolResult(text: swift ?? "")
        case .check:
            do {
                _ = try compiler.compile(Compiler.CompilationUnit(
                    sources: [Compiler.SourceInput(source: source, file: file)],
                    vocabularies: vocabularies, rulebooks: rulebooks))
                return toolResult(text: "ok")
            } catch {
                return toolResult(text: String(describing: error), isError: true)
            }
        case .explain:
            let model = try compiledModel(
                compiler, source, file, vocabularies, rulebooks)
            let text = try Verbalizer(model: model).verbalize()
            return toolResult(text: text)
        }
    }

    public static func toolList() -> [[String: Any]] {
        MCPTool.allCases.map {
            [
                "name": $0.rawValue,
                "description": $0.description,
                "inputSchema": $0.inputSchema,
            ]
        }
    }

    private func toolResult(text: String, isError: Bool = false) -> [String: Any] {
        var result: [String: Any] = [
            "content": [["type": "text", "text": text]],
        ]
        if isError { result["isError"] = true }
        return result
    }

    private func successResponse(id: Any?, result: [String: Any]) -> [String: Any] {
        var response: [String: Any] = ["jsonrpc": "2.0", "result": result]
        if let id { response["id"] = id }
        return response
    }

    private func errorResponse(id: Any?, code: Int, message: String) -> [String: Any] {
        var response: [String: Any] = [
            "jsonrpc": "2.0",
            "error": ["code": code, "message": message],
        ]
        if let id { response["id"] = id }
        return response
    }
}

public enum MCPRoutingError: Error, Sendable, Equatable {
    case toolNotFound(String)
    case invalidRequest(String)
}

public enum MCPStdioTransport {
    public static func readMessage(from handle: FileHandle = .standardInput) throws -> [String: Any]? {
        var headerBuffer = Data()
        while true {
            let chunk = handle.readData(ofLength: 1)
            if chunk.isEmpty { return headerBuffer.isEmpty ? nil : nil }
            headerBuffer.append(chunk)
            if headerBuffer.suffix(4) == Data("\r\n\r\n".utf8) { break }
            if headerBuffer.count > 65_536 {
                throw MCPRoutingError.invalidRequest("Header too large")
            }
        }
        guard let header = String(data: headerBuffer, encoding: .utf8),
              let length = contentLength(from: header)
        else {
            throw MCPRoutingError.invalidRequest("Missing Content-Length header")
        }
        guard length > 0 else { return [:] }
        let payload = try readExact(length, from: handle)
        guard let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            throw MCPRoutingError.invalidRequest("Payload was not a JSON object")
        }
        return object
    }

    public static func writeMessage(_ object: [String: Any], to handle: FileHandle = .standardOutput) throws {
        guard !object.isEmpty else { return }
        let payload = try JSONSerialization.data(withJSONObject: object)
        let header = "Content-Length: \(payload.count)\r\n\r\n"
        handle.write(Data(header.utf8))
        handle.write(payload)
    }

    private static func contentLength(from headerBlock: String) -> Int? {
        for rawLine in headerBlock.components(separatedBy: "\r\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.lowercased().hasPrefix("content-length:") else { continue }
            let value = line.split(separator: ":", maxSplits: 1).last.map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.flatMap(Int.init)
        }
        return nil
    }

    private static func readExact(_ count: Int, from handle: FileHandle) throws -> Data {
        var buffer = Data()
        while buffer.count < count {
            let chunk = handle.readData(ofLength: count - buffer.count)
            if chunk.isEmpty {
                throw MCPRoutingError.invalidRequest("Unexpected EOF while reading MCP payload")
            }
            buffer.append(chunk)
        }
        return buffer
    }
}
