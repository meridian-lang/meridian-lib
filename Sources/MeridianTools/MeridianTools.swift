import Foundation
import MeridianRuntime

public enum MeridianTools {

    public static let version = "1.0"

    /// Blueprint built-ins from `00_BLUEPRINT.md` §9.5. These are opt-in:
    /// `ToolRegistry()` starts empty and hosts call `registerBuiltins()` when
    /// they explicitly want this broad surface area.
    public static let allToolIDs: [String] = [
        "http.get", "http.post", "http.put", "http.delete",
        "file.read", "file.write", "file.append",
        "json.parse", "json.stringify", "json.transform",
        "regex.match", "regex.replace",
        "shell.run",
        "mcp.call",
        "llm.chat",
        "llm.decide", "llm.judge",
        "validate.json_schema",
        "time.now", "time.format",
        "uuid.generate"
    ]

    public static func invoke(_ toolID: String, args: [String: Value] = [:]) async throws -> Value {
        switch toolID {
        case "file.read": return try readFile(args)
        case "file.write": return try writeFile(args, append: false)
        case "file.append": return try writeFile(args, append: true)
        case "json.parse": return try parseJSON(args)
        case "json.stringify": return try stringifyJSON(args)
        case "json.transform": return transformJSON(args)
        case "regex.match": return try regexMatch(args)
        case "regex.replace": return try regexReplace(args)
        case "mcp.call":
            throw ToolError.implementation(
                code: "mcp.requires_registry",
                message: "mcp.call is dispatched through ToolRegistry's replaceable MCP adapter",
                cause: nil
            )
        case "llm.chat":
            throw ToolError.implementation(
                code: "llm.not_implemented",
                message: "llm.chat is intentionally not implemented yet",
                cause: nil
            )
        case "llm.decide", "llm.judge":
            return try await decideLLM(args)
        case "validate.json_schema": return validateJSONSchema(args)
        case "time.now": return .dateTime(Date())
        case "time.format": return formatTime(args)
        case "uuid.generate": return .string(UUID().uuidString)
        default: return .null
        }
    }

    /// B4: Default implementation returns `false` deterministically so tests are
    /// safe and reproducible. Hosts override by registering their own `llm.decide`
    /// tool in `ToolRegistry` before running workflows.
    static func decideLLM(_ args: [String: Value]) async throws -> Value {
        _ = stringArg(args, "question")
        return .boolean(false)
    }

    static func readFile(_ args: [String: Value]) throws -> Value {
        let path = try requiredString(args, "path")
        return .string(try String(contentsOfFile: path, encoding: .utf8))
    }

    static func writeFile(_ args: [String: Value], append: Bool) throws -> Value {
        let path = try requiredString(args, "path")
        let content = try requiredString(args, "content")
        let url = URL(fileURLWithPath: path)
        if append, FileManager.default.fileExists(atPath: path) {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(content.utf8))
            try handle.close()
        } else {
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
        return .null
    }

    static func parseJSON(_ args: [String: Value]) throws -> Value {
        let text = try requiredString(args, "text")
        let obj = try JSONSerialization.jsonObject(with: Data(text.utf8))
        return value(fromJSONObject: obj)
    }

    static func stringifyJSON(_ args: [String: Value]) throws -> Value {
        let value = args["value"] ?? .null
        let data = try JSONSerialization.data(withJSONObject: value.jsonEncodableObject, options: [.sortedKeys])
        return .string(String(data: data, encoding: .utf8) ?? "null")
    }

    static func transformJSON(_ args: [String: Value]) -> Value {
        var current = args["value"] ?? .null
        let path = parsePath(stringArg(args, "path") ?? "")
        for component in path {
            switch (component, current) {
            case (.key(let key), .record(let dict)):
                guard let next = dict[key] else { return .null }
                current = next
            case (.index(let index), .list(let list)):
                guard list.indices.contains(index) else { return .null }
                current = list[index]
            default:
                return .null
            }
        }
        return current
    }

    static func regexMatch(_ args: [String: Value]) throws -> Value {
        let pattern = try requiredString(args, "pattern")
        let text = try requiredString(args, "text")
        let re = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let nsText = text as NSString
        let matches = re.matches(in: text, range: range).map { match -> Value in
            var groups: [Value] = []
            for idx in 0..<match.numberOfRanges {
                let groupRange = match.range(at: idx)
                groups.append(groupRange.location == NSNotFound ? .null : .string(nsText.substring(with: groupRange)))
            }
            return .record([
                "text": .string(nsText.substring(with: match.range)),
                "range": .record([
                    "location": .number(Decimal(match.range.location)),
                    "length": .number(Decimal(match.range.length))
                ]),
                "groups": .list(groups)
            ])
        }
        return .record(["matched": .boolean(!matches.isEmpty), "matches": .list(matches)])
    }

    static func regexReplace(_ args: [String: Value]) throws -> Value {
        let pattern = try requiredString(args, "pattern")
        let text = try requiredString(args, "text")
        let replacement = try requiredString(args, "replacement")
        let re = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return .string(re.stringByReplacingMatches(in: text, range: range, withTemplate: replacement))
    }

    static func validateJSONSchema(_ args: [String: Value]) -> Value {
        guard case .record(let schema)? = args["schema"],
              case .record(let value)? = args["value"]
        else {
            return .record(["valid": .boolean(false), "errors": .list([.string("schema and value must be records")])])
        }
        let required: [String]
        if case .list(let list)? = schema["required"] {
            required = list.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        } else {
            required = []
        }
        let missing = required.filter { value[$0] == nil }
        return .record([
            "valid": .boolean(missing.isEmpty),
            "errors": .list(missing.map { .string("missing:\($0)") })
        ])
    }

    static func formatTime(_ args: [String: Value]) -> Value {
        let date: Date
        if case .dateTime(let d)? = args["value"] { date = d }
        else if case .date(let d)? = args["value"] { date = d }
        else { date = Date() }
        if case .string(let format)? = args["format"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: stringArg(args, "locale") ?? "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: stringArg(args, "timezone") ?? "UTC")
            formatter.dateFormat = format
            return .string(formatter.string(from: date))
        }
        let formatter = ISO8601DateFormatter()
        if let timeZone = stringArg(args, "timezone").flatMap(TimeZone.init(identifier:)) {
            formatter.timeZone = timeZone
        }
        return .string(formatter.string(from: date))
    }

    private enum PathComponent {
        case key(String)
        case index(Int)
    }

    private static func parsePath(_ raw: String) -> [PathComponent] {
        raw.split(separator: ".").flatMap { segment -> [PathComponent] in
            var components: [PathComponent] = []
            var cursor = String(segment)
            if let bracket = cursor.firstIndex(of: "[") {
                let key = String(cursor[..<bracket])
                if !key.isEmpty { components.append(.key(key)) }
            } else if !cursor.isEmpty {
                components.append(.key(cursor))
            }
            while let open = cursor.firstIndex(of: "["),
                  let close = cursor[open...].firstIndex(of: "]") {
                let rawIndex = cursor[cursor.index(after: open)..<close]
                if let index = Int(rawIndex) {
                    components.append(.index(index))
                }
                cursor = String(cursor[cursor.index(after: close)...])
            }
            return components
        }
    }

    private static func stringArg(_ args: [String: Value], _ key: String) -> String? {
        if case .string(let s)? = args[key] { return s }
        return nil
    }

    private static func requiredString(_ args: [String: Value], _ key: String) throws -> String {
        guard let value = stringArg(args, key) else {
            throw ToolError.argumentCoercion(field: key, expected: "String", actual: String(describing: args[key] ?? .null))
        }
        return value
    }

    private static func value(fromJSONObject obj: Any) -> Value {
        switch obj {
        case let s as String: return .string(s)
        case let n as NSNumber:
            return CFGetTypeID(n) == CFBooleanGetTypeID() ? .boolean(n.boolValue) : .number(n.decimalValue)
        case let dict as [String: Any]:
            return .record(dict.mapValues(value(fromJSONObject:)))
        case let list as [Any]:
            return .list(list.map(value(fromJSONObject:)))
        default:
            return .null
        }
    }

}

// MARK: - ToolRegistry integration

public extension ToolRegistry {

    /// Register the Blueprint built-ins. Existing registrations under the same
    /// name are overwritten — the last call wins.
    func registerBuiltins() {
        for toolID in MeridianTools.allToolIDs {
            switch toolID {
            case "http.get": register(tool: toolID, .http(HTTPSpec(url: "{url}", method: "GET")))
            case "http.post": register(tool: toolID, .http(HTTPSpec(url: "{url}", method: "POST")))
            case "http.put": register(tool: toolID, .http(HTTPSpec(url: "{url}", method: "PUT")))
            case "http.delete": register(tool: toolID, .http(HTTPSpec(url: "{url}", method: "DELETE")))
            case "shell.run": register(tool: toolID, .subprocess(SubprocessSpec(binary: "/bin/sh", argTemplate: ["-c", "{command}"])))
            case "mcp.call": register(tool: toolID, .mcp(MCPSpec()))
            case "llm.decide", "llm.judge":
                register(tool: toolID, .closure { args in
                    try await MeridianTools.invoke(toolID, args: args)
                })
            default:
                register(tool: toolID, .closure { args in
                    try await MeridianTools.invoke(toolID, args: args)
                })
            }
        }
    }
}
