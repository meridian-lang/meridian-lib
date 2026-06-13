import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - ToolKind

public enum ToolKind: Sendable {
    case closure(@Sendable ([String: Value]) async throws -> Value)
    /// Subprocess tool — implemented in Phase 5.
    case subprocess(SubprocessSpec)
    /// HTTP tool — implemented in Phase 5.
    case http(HTTPSpec)
    /// MCP tool — deferred to v1.1.
    case mcp(MCPSpec)
}

// MARK: - Spec stubs (fleshed out in Phase 5)

public struct SubprocessSpec: Sendable {
    public let binary: String
    public let argTemplate: [String]
    public let timeout: Duration

    public init(binary: String, argTemplate: [String] = [], timeout: Duration = .seconds(60)) {
        self.binary = binary
        self.argTemplate = argTemplate
        self.timeout = timeout
    }
}

public struct HTTPSpec: Sendable {
    public let url: String
    public let method: String
    public let timeout: Duration
    public let headers: [String: String]

    public init(url: String, method: String = "POST", timeout: Duration = .seconds(30), headers: [String: String] = [:]) {
        self.url = url
        self.method = method
        self.timeout = timeout
        self.headers = headers
    }
}

public struct MCPSpec: Sendable {
    public let endpoint: String
    public let transport: MCPTransport

    public init(endpoint: String) {
        self.endpoint = endpoint
        self.transport = .httpJSONRPC(url: endpoint)
    }

    public init(transport: MCPTransport = .dynamic) {
        self.endpoint = ""
        self.transport = transport
    }
}

public enum MCPTransport: Sendable {
    case dynamic
    case httpJSONRPC(url: String, headers: [String: String] = [:], timeout: Duration = .seconds(30))
    case stdio(binary: String, arguments: [String] = [], timeout: Duration = .seconds(30))
}

public protocol MCPClient: Sendable {
    func call(method: String, params: Value, transport: MCPTransport) async throws -> Value
}

public struct DefaultMCPClient: MCPClient {
    public init() {}

    public func call(method: String, params: Value, transport: MCPTransport) async throws -> Value {
        switch transport {
        case .dynamic:
            throw ToolError.argumentCoercion(field: "transport", expected: "configured MCP transport", actual: "dynamic")
        case .httpJSONRPC(let url, let headers, let timeout):
            return try await callHTTP(method: method, params: params, url: url, headers: headers, timeout: timeout)
        case .stdio(let binary, let arguments, let timeout):
            return try await callStdio(method: method, params: params, binary: binary, arguments: arguments, timeout: timeout)
        }
    }

    private func callHTTP(
        method: String,
        params: Value,
        url urlText: String,
        headers: [String: String],
        timeout: Duration
    ) async throws -> Value {
        guard let url = URL(string: urlText),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            throw ToolError.argumentCoercion(field: "url", expected: "valid URL", actual: urlText)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try jsonRPCRequest(method: method, params: params)

        let finalRequest = request
        let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask { try await URLSession.shared.data(for: finalRequest) }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ToolError.timeout(timeout)
            }
            guard let first = try await group.next() else {
                throw ToolError.mcp(.init(code: "mcp.transport", message: "MCP HTTP request produced no result"))
            }
            group.cancelAll()
            return first
        }

        guard let http = response as? HTTPURLResponse else {
            throw ToolError.mcp(.init(code: "mcp.transport", message: "MCP response was not HTTP"))
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw ToolError.http(statusCode: http.statusCode, body: body)
        }
        return try decodeJSONRPCResponse(data)
    }

    private func callStdio(
        method: String,
        params: Value,
        binary: String,
        arguments: [String],
        timeout: Duration
    ) async throws -> Value {
        let payload = try jsonRPCRequest(method: method, params: params)
        let input = (String(data: payload, encoding: .utf8) ?? "{}") + "\n"
        let record = try await ProcessRunner.run(
            binary: binary,
            arguments: arguments,
            stdin: input,
            timeout: timeout
        )
        guard record.exitCode == 0 else {
            throw ToolError.subprocess(SubprocessToolError(exitCode: record.exitCode, stderr: record.stderr))
        }
        guard let data = record.stdout.data(using: .utf8) else {
            throw ToolError.mcp(.init(code: "mcp.decode", message: "MCP stdio response was not UTF-8"))
        }
        return try decodeJSONRPCResponse(data)
    }

    private func jsonRPCRequest(method: String, params: Value) throws -> Data {
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params.jsonEncodableObject
        ]
        return try JSONSerialization.data(withJSONObject: request)
    }

    private func decodeJSONRPCResponse(_ data: Data) throws -> Value {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dict = object as? [String: Any] else {
            throw ToolError.mcp(.init(code: "mcp.decode", message: "MCP response must be a JSON object"))
        }
        if let error = dict["error"] as? [String: Any] {
            let code = error["code"].map { String(describing: $0) } ?? "mcp.error"
            let message = error["message"].map { String(describing: $0) } ?? "MCP error"
            throw ToolError.mcp(.init(code: code, message: message))
        }
        if let result = dict["result"] {
            return valueFromJSONObject(result)
        }
        return valueFromJSONObject(dict)
    }
}

// MARK: - RedactionPolicy

public enum RedactionPolicy: Sendable {
    case none
    case redactKeys([String])
    case redactAll
}

// MARK: - ToolRegistry

public actor ToolRegistry {

    private struct Entry: Sendable {
        let kind: ToolKind
        let redactionPolicy: RedactionPolicy
        let schema: ToolSchema
    }

    private var tools: [String: Entry] = [:]
    private let mcpClient: any MCPClient

    public init(mcpClient: any MCPClient = DefaultMCPClient()) {
        self.mcpClient = mcpClient
    }

    public func register(
        tool toolID: String,
        _ kind: ToolKind,
        redactionPolicy: RedactionPolicy = .none,
        schema: ToolSchema? = nil
    ) {
        tools[toolID] = Entry(
            kind: kind,
            redactionPolicy: redactionPolicy,
            schema: schema ?? ToolSchema(id: toolID)
        )
    }

    public func unregister(tool toolID: String) {
        tools.removeValue(forKey: toolID)
    }

    public func has(tool toolID: String) -> Bool {
        tools[toolID] != nil
    }

    public func toolIDs() -> [String] {
        Array(tools.keys)
    }

    public func schemas(_ ids: Set<String>) -> [ToolSchema] {
        ids.compactMap { tools[$0]?.schema }.sorted { $0.id < $1.id }
    }

    public func schema(for toolID: String) -> ToolSchema? {
        tools[toolID]?.schema
    }

    public func redactionPolicy(for toolID: String) -> RedactionPolicy {
        tools[toolID]?.redactionPolicy ?? .none
    }

    /// Dispatch a tool invocation. Called by Runtime.invoke.
    public func dispatch(
        tool toolID: String,
        args: [String: Value]
    ) async throws -> Value {
        guard let entry = tools[toolID] else {
            throw MeridianRuntimeError.toolNotFound(id: toolID)
        }

        switch entry.kind {
        case .closure(let fn):
            do {
                return try await fn(args)
            } catch let toolErr as ToolError {
                throw MeridianRuntimeError.toolError(toolErr, sourceRange: nil)
            } catch {
                throw MeridianRuntimeError.toolError(
                    .implementation(code: "tool_error", message: error.localizedDescription, cause: error),
                    sourceRange: nil
                )
            }

        case .subprocess(let spec):
            do {
                return try await dispatchSubprocess(spec, args: args)
            } catch let toolErr as ToolError {
                throw MeridianRuntimeError.toolError(toolErr, sourceRange: nil)
            } catch {
                throw MeridianRuntimeError.toolError(
                    .implementation(code: "subprocess.error", message: error.localizedDescription, cause: error),
                    sourceRange: nil
                )
            }

        case .http(let spec):
            do {
                return try await dispatchHTTP(spec, args: args)
            } catch let toolErr as ToolError {
                throw MeridianRuntimeError.toolError(toolErr, sourceRange: nil)
            } catch {
                throw MeridianRuntimeError.toolError(
                    .implementation(code: "http.transport", message: error.localizedDescription, cause: error),
                    sourceRange: nil
                )
            }

        case .mcp(let spec):
            do {
                return try await dispatchMCP(spec, args: args)
            } catch let toolErr as ToolError {
                throw MeridianRuntimeError.toolError(toolErr, sourceRange: nil)
            } catch {
                throw MeridianRuntimeError.toolError(
                    .implementation(code: "mcp.transport", message: error.localizedDescription, cause: error),
                    sourceRange: nil
                )
            }
        }
    }

    // MARK: - Subprocess dispatch

    private func dispatchSubprocess(_ spec: SubprocessSpec, args: [String: Value]) async throws -> Value {
        let renderedArgs = renderArguments(spec.argTemplate, args: args)
        let record = try await ProcessRunner.run(
            binary: spec.binary,
            arguments: renderedArgs,
            timeout: spec.timeout
        )

        guard record.exitCode == 0 else {
            throw ToolError.subprocess(SubprocessToolError(exitCode: record.exitCode, stderr: record.stderr))
        }

        return .record([
            "stdout": .string(record.stdout),
            "stderr": .string(record.stderr),
            "exitCode": .number(record.exitCode)
        ])
    }

    private func renderArguments(_ template: [String], args: [String: Value]) -> [String] {
        if template.isEmpty, case .list(let list)? = args["args"] {
            return list.map(valueString)
        }
        return template.map { item in
            var rendered = item
            for (key, value) in args {
                rendered = rendered.replacingOccurrences(of: "{\(key)}", with: valueString(value))
            }
            return rendered
        }
    }

    // MARK: - MCP dispatch

    private func dispatchMCP(_ spec: MCPSpec, args: [String: Value]) async throws -> Value {
        let method = try requiredString(args, "method")
        let params = args["params"] ?? .record([:])
        let transport = try resolveMCPTransport(spec.transport, args: args)
        return try await mcpClient.call(method: method, params: params, transport: transport)
    }

    private func resolveMCPTransport(_ configured: MCPTransport, args: [String: Value]) throws -> MCPTransport {
        switch configured {
        case .dynamic:
            let transport = args["transport"].map(valueString) ?? "http"
            switch transport {
            case "http", "http_json_rpc", "jsonrpc":
                let url = try requiredString(args, "url")
                return .httpJSONRPC(url: url, headers: stringRecord(args["headers"]), timeout: durationArg(args["timeout"]) ?? .seconds(30))
            case "stdio", "subprocess":
                let binary = try requiredString(args, "binary")
                let arguments = stringList(args["arguments"])
                return .stdio(binary: binary, arguments: arguments, timeout: durationArg(args["timeout"]) ?? .seconds(30))
            default:
                throw ToolError.argumentCoercion(field: "transport", expected: "http or stdio", actual: transport)
            }
        default:
            return configured
        }
    }

    // MARK: - HTTP dispatch

    private func dispatchHTTP(_ spec: HTTPSpec, args: [String: Value]) async throws -> Value {
        let urlText = args["url"].map(valueString) ?? renderTemplate(spec.url, args: args)
        guard let url = URL(string: urlText),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            throw ToolError.argumentCoercion(field: "url", expected: "valid URL", actual: urlText)
        }

        var request = URLRequest(url: url)
        request.httpMethod = args["method"].map(valueString) ?? spec.method
        for (key, value) in spec.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if case .record(let headers)? = args["headers"] {
            for (key, value) in headers {
                request.setValue(valueString(value), forHTTPHeaderField: key)
            }
        }

        if let body = args["body"] {
            request.httpBody = try httpBody(from: body)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let finalRequest = request
        let (data, response) = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
            group.addTask { try await URLSession.shared.data(for: finalRequest) }
            group.addTask {
                try await Task.sleep(for: spec.timeout)
                throw ToolError.timeout(spec.timeout)
            }

            guard let first = try await group.next() else {
                throw ToolError.implementation(code: "http.transport", message: "HTTP request produced no result", cause: nil)
            }
            group.cancelAll()
            return first
        }

        guard let http = response as? HTTPURLResponse else {
            throw ToolError.implementation(code: "http.transport", message: "response was not HTTP", cause: nil)
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            throw ToolError.http(statusCode: http.statusCode, body: body)
        }

        var headers: [String: Value] = [:]
        for (key, value) in http.allHeaderFields {
            headers[String(describing: key)] = .string(String(describing: value))
        }
        return .record([
            "status": .number(http.statusCode),
            "body": .string(body),
            "headers": .record(headers)
        ])
    }

    private func httpBody(from value: Value) throws -> Data {
        switch value {
        case .string(let s):
            return Data(s.utf8)
        default:
            let obj = value.jsonEncodableObject
            guard JSONSerialization.isValidJSONObject(obj) else {
                throw ToolError.argumentCoercion(field: "body", expected: "JSON-compatible value", actual: value.description)
            }
            return try JSONSerialization.data(withJSONObject: obj)
        }
    }

    private func renderTemplate(_ text: String, args: [String: Value]) -> String {
        var rendered = text
        for (key, value) in args {
            rendered = rendered.replacingOccurrences(of: "{\(key)}", with: valueString(value))
        }
        return rendered
    }

    private func valueString(_ value: Value) -> String {
        value.scalarDescription
    }

    private func requiredString(_ args: [String: Value], _ key: String) throws -> String {
        guard case .string(let value)? = args[key] else {
            throw ToolError.argumentCoercion(field: key, expected: "String", actual: String(describing: args[key] ?? .null))
        }
        return value
    }

    private func stringRecord(_ value: Value?) -> [String: String] {
        guard case .record(let dict)? = value else { return [:] }
        return dict.mapValues(valueString)
    }

    private func stringList(_ value: Value?) -> [String] {
        guard case .list(let list)? = value else { return [] }
        return list.map(valueString)
    }

    private func durationArg(_ value: Value?) -> Duration? {
        switch value {
        case .duration(let duration)?: return duration
        case .number(let seconds)?: return .seconds(Int64((seconds as NSDecimalNumber).doubleValue))
        default: return nil
        }
    }
}

private struct ProcessRecord: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int
}

private enum ProcessRunner {
    static func run(
        binary: String,
        arguments: [String],
        stdin: String? = nil,
        timeout: Duration
    ) async throws -> ProcessRecord {
        let process = Process()
        if binary.contains("/") {
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [binary] + arguments
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        if stdin != nil {
            process.standardInput = Pipe()
        }

        let box = ProcessBox(process: process)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            process.terminationHandler = { _ in
                if box.finish() {
                    cont.resume()
                }
            }

            do {
                try process.run()
                if let stdin, let input = process.standardInput as? Pipe {
                    input.fileHandleForWriting.write(Data(stdin.utf8))
                    try? input.fileHandleForWriting.close()
                }
            } catch {
                if box.finish() {
                    cont.resume(throwing: error)
                }
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout.dispatchInterval) {
                guard box.finish() else { return }
                if process.isRunning {
                    process.terminate()
                    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(100)) {
                        if process.isRunning {
                            process.interrupt()
                        }
                    }
                }
                cont.resume(throwing: ToolError.timeout(timeout))
            }
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        return ProcessRecord(stdout: stdout, stderr: stderr, exitCode: Int(process.terminationStatus))
    }
}

private final class ProcessBox: @unchecked Sendable {
    let process: Process
    private let lock = NSLock()
    private var finished = false

    init(process: Process) {
        self.process = process
    }

    func finish() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        return true
    }
}

private extension Duration {
    var dispatchInterval: DispatchTimeInterval {
        let seconds = Double(components.seconds)
        let fractional = Double(components.attoseconds) / 1.0e18
        let nanoseconds = max(0, min(Double(Int.max), (seconds + fractional) * 1.0e9))
        return .nanoseconds(Int(nanoseconds))
    }
}

private func valueFromJSONObject(_ obj: Any) -> Value {
    switch obj {
    case let s as String: return .string(s)
    case let b as Bool: return .boolean(b)
    case let n as NSNumber:
        return CFGetTypeID(n) == CFBooleanGetTypeID() ? .boolean(n.boolValue) : .number(n.decimalValue)
    case let dict as [String: Any]:
        return .record(dict.mapValues(valueFromJSONObject))
    case let list as [Any]:
        return .list(list.map(valueFromJSONObject))
    default:
        return .null
    }
}
