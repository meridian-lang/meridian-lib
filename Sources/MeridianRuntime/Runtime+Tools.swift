import Foundation

// Tool invocation + capture/redaction helpers — extracted from Runtime for Phase 3 readability.

extension Runtime {

    // MARK: - Tool invocation

    /// Invoke a registered tool. Emits invoke.start and invoke.end/invoke.error events.
    public func invoke(
        tool toolID: String,
        args: [String: Value],
        step traceStep: String? = nil,
        capturePolicy: TraceCapturePolicy? = nil,
        sourceRange: SourceRange? = nil
    ) async throws -> Value {
        let seq = nextSeq()
        let startDate = clock.now()

        var argsPayload: [String: Value] = ["args": .record(args)]
        let hasTool = await toolRegistry.has(tool: toolID)
        if let capturePolicy {
            let redactedArgs = ShellHoleRedaction.redactInvokeArgs(
                toolID: toolID,
                args: args,
                capturePolicy: capturePolicy
            )
            argsPayload = capture(payload: ["args": .record(redactedArgs)], policy: capturePolicy)
        } else if hasTool {
            let policy = await toolRegistry.redactionPolicy(for: toolID)
            argsPayload = redact(payload: argsPayload, policy: policy)
            if ShellHoleRedaction.isShellTool(toolID) {
                let redactedArgs = ShellHoleRedaction.redactInvokeArgs(
                    toolID: toolID,
                    args: args,
                    capturePolicy: nil
                )
                argsPayload = ["args": .record(redactedArgs)]
            }
        }

        let fullArgsPayload = mergeDicts(["tool": .string(toolID)], ["args": .record(args)])
        let stepPayload: [String: Value] = traceStep.map { ["step": Value.string($0)] } ?? [:]
        try await emitOrThrow(
            kind: .invokeStart,
            at: startDate,
            ingestOrder: seq,
            payload: mergeDicts(mergeDicts(["tool": .string(toolID)], argsPayload), stepPayload),
            hashedPayload: mergeDicts(fullArgsPayload, stepPayload),
            sourceRange: sourceRange
        )

        do {
            let result = try await toolRegistry.dispatch(tool: toolID, args: args)
            let endDate = clock.now()
            let durationMS = (endDate.timeIntervalSince(startDate)) * 1000

            var endPayload: [String: Value] = [
                "tool": .string(toolID),
                "duration_ms": .number(Decimal(durationMS)),
                "output_summary": .string(summaryOf(result)),
                "step": traceStep.map(Value.string) ?? .null
            ]
            if let capturePolicy {
                endPayload = ShellHoleRedaction.redactInvokeOutput(
                    toolID: toolID,
                    payload: endPayload,
                    capturePolicy: capturePolicy
                )
            } else if ShellHoleRedaction.isShellTool(toolID) {
                endPayload = ShellHoleRedaction.redactInvokeOutput(
                    toolID: toolID,
                    payload: endPayload,
                    capturePolicy: nil
                )
            }

            try await emitOrThrow(
                kind: .invokeEnd,
                at: endDate,
                payload: endPayload,
                sourceRange: sourceRange
            )
            return result
        } catch {
            recordOperationalDiagnostic(code: "tool.dispatch", message: String(describing: error))
            let endDate = clock.now()
            try await emitOrThrow(
                kind: .invokeError,
                at: endDate,
                payload: [
                    "tool": .string(toolID),
                    "error": .string(RuntimeSecretRedaction.redact(String(describing: error))),
                    "step": traceStep.map(Value.string) ?? .null
                ],
                sourceRange: sourceRange
            )
            throw error
        }
    }


    private func summaryOf(_ value: Value) -> String {
        switch value {
        case .opaque(let box):
            return "<\(String(describing: box))>"
        default:
            return value.description
        }
    }

    private func redact(payload: [String: Value], policy: RedactionPolicy) -> [String: Value] {
        switch policy {
        case .none: return payload
        case .redactAll: return payload.mapValues { _ in .string("<redacted>") }
        case .redactKeys(let keys):
            let keySet = Set(keys)
            return redactRecord(payload, keys: keySet)
        }
    }

    private func capture(payload: [String: Value], policy: TraceCapturePolicy) -> [String: Value] {
        switch policy {
        case .full:
            return payload
        case .hashOnly:
            return [:]
        case .redacted(let keys):
            return redactRecord(payload, keys: Set(keys))
        case .omitted:
            return [:]
        }
    }

    private func redactRecord(_ dict: [String: Value], keys: Set<String>) -> [String: Value] {
        dict.reduce(into: [:]) { acc, pair in
            acc[pair.key] = keys.contains(pair.key)
                ? .string("<redacted>")
                : redactValue(pair.value, keys: keys)
        }
    }

    private func redactValue(_ value: Value, keys: Set<String>) -> Value {
        switch value {
        case .record(let dict):
            return .record(redactRecord(dict, keys: keys))
        case .list(let values):
            return .list(values.map { redactValue($0, keys: keys) })
        default:
            return value
        }
    }


}
