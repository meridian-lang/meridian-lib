// MARK: - ToolError

public enum ToolError: Error, Sendable {
    case implementation(code: String, message: String, cause: (any Error)?)
    case argumentCoercion(field: String, expected: String, actual: String)
    case timeout(Duration)
    case subprocess(SubprocessToolError)
    case http(statusCode: Int, body: String)
    case mcp(McpToolError)
}

// MARK: - Supporting error types

public struct SubprocessToolError: Error, Sendable {
    public let exitCode: Int
    public let stderr: String
    public init(exitCode: Int, stderr: String) {
        self.exitCode = exitCode
        self.stderr = stderr
    }
}

public struct McpToolError: Error, Sendable {
    public let code: String
    public let message: String
    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

// MARK: - MeridianRuntimeError

public enum MeridianRuntimeError: Error, Sendable {
    case toolError(ToolError, sourceRange: SourceRange?)
    case assertion(message: String, sourceRange: SourceRange?)
    case assertionFailed(message: String)
    case timeout(condition: WaitCondition, sourceRange: SourceRange?)
    case stateError(StateError, sourceRange: SourceRange?)
    case recoveryExhausted(originalError: any Error, handlerError: any Error)
    case checkpointFailed(String, sourceRange: SourceRange?)
    case instanceNotFound(name: String)
    case toolNotFound(id: String)
    case nestingLimitExceeded(maxDepth: Int)
    case cancelled
    /// Thrown when `wait(.approval(...))` receives a `.denied` verdict.
    /// Can be caught by `recover from approval.denied:` in generated code.
    case approvalDenied(role: String, sourceRange: SourceRange?)
}

// MARK: - Error pattern matching helpers
//
// Used by generated `catch` clauses from `recover from …:` blocks.
// These free functions are emitted into the generated Swift file header
// so they are available from `do { … } catch let e where matches(e, …) { … }`.

/// Returns `true` when `error` is a `ToolError.implementation` whose `code`
/// matches `name`, or a `MeridianRuntimeError.approvalDenied` whose role matches.
public func meridianMatches(_ error: any Error, named name: String) -> Bool {
    if let te = error as? ToolError, case .implementation(let code, _, _) = te {
        return code == name
    }
    if let te = error as? ToolError, meridianMatches(toolError: te, named: name) {
        return true
    }
    if let re = error as? MeridianRuntimeError, case .toolError(let toolError, _) = re {
        return meridianMatches(toolError: toolError, named: name)
    }
    if let re = error as? MeridianRuntimeError, case .approvalDenied(let role, _) = re {
        return role == name || "approval.denied" == name
    }
    return false
}

private func meridianMatches(toolError: ToolError, named name: String) -> Bool {
    switch toolError {
    case .implementation(let code, _, _):
        return code == name
    case .argumentCoercion:
        return name == "tool.argument_coercion"
    case .timeout:
        return name == "tool.timeout" || name == "subprocess.timeout" || name == "http.timeout"
    case .subprocess:
        return name == "subprocess.exit_failure" || name == "subprocess.error"
    case .http(let statusCode, _):
        return name == "http.status" || name == "http.status_\(statusCode)"
    case .mcp(let err):
        return name == "mcp.error" || name == err.code
    }
}

/// Returns `true` when `error`'s dynamic type matches `type`.
public func meridianMatches(_ error: any Error, typed type: Any.Type) -> Bool {
    return Swift.type(of: error) == type
}
