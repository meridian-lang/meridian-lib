import Foundation

public enum ShellHoleRedaction {
    public static let shellToolIDs: Set<String> = ["shell.run"]
    public static let sensitiveArgKeys: Set<String> = ["command", "script", "stdin"]
    public static let sensitiveOutputKeys: Set<String> = ["stdout", "stderr", "output_summary", "output"]

    public static func isShellTool(_ toolID: String) -> Bool {
        shellToolIDs.contains(toolID)
    }

    public static func redactInvokeArgs(
        toolID: String,
        args: [String: Value],
        capturePolicy: TraceCapturePolicy?
    ) -> [String: Value] {
        guard isShellTool(toolID) else { return args }
        guard let capturePolicy else {
            return redactKeys(args, keys: sensitiveArgKeys)
        }
        return applyCapture(capturePolicy, to: ["args": .record(args)])["args"]?.recordValue ?? args
    }

    public static func redactInvokeOutput(
        toolID: String,
        payload: [String: Value],
        capturePolicy: TraceCapturePolicy?
    ) -> [String: Value] {
        guard isShellTool(toolID) else { return payload }
        guard let capturePolicy else {
            return redactKeys(payload, keys: sensitiveOutputKeys)
        }
        return applyCapture(capturePolicy, to: payload)
    }

    public static func applyCapture(_ policy: TraceCapturePolicy, to payload: [String: Value]) -> [String: Value] {
        switch policy {
        case .full:
            return payload
        case .hashOnly, .omitted:
            return payload.reduce(into: [:]) { acc, pair in
                let sensitive = sensitiveOutputKeys.contains(pair.key) || sensitiveArgKeys.contains(pair.key)
                acc[pair.key] = sensitive ? .string("<redacted>") : pair.value
            }
        case .redacted(let keys):
            let keySet = Set(keys).union(sensitiveArgKeys).union(sensitiveOutputKeys)
            return redactKeys(payload, keys: keySet)
        }
    }

    private static func redactKeys(_ dict: [String: Value], keys: Set<String>) -> [String: Value] {
        dict.reduce(into: [:]) { acc, pair in
            if keys.contains(pair.key) {
                acc[pair.key] = .string("<redacted>")
            } else if case .record(let nested) = pair.value {
                acc[pair.key] = .record(redactKeys(nested, keys: keys))
            } else {
                acc[pair.key] = pair.value
            }
        }
    }
}

private extension Value {
    var recordValue: [String: Value]? {
        if case .record(let dict) = self { return dict }
        return nil
    }
}
