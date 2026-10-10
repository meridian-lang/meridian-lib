import Foundation

/// Emits the workflow-run drivers used by `RuntimeExecutor` (the
/// `.meridian.test` subprocess runner) and `SwiftPMPackageRunner` (the CLI
/// `run` driver). Both scaffold a temp SwiftPM package and write a
/// `Driver.swift` that bridges JSON→`Value`, registers closure tool stubs,
/// decodes workflow parameters, and runs the workflow. Every difference
/// between the two generated drivers is a `DriverSpec` field; `driver(spec:)`
/// is the only emitter.
///
/// All string inputs are escaped here, so callers pass raw values. The driver
/// source is compiled and run (never golden-diffed), so a single canonical form
/// is emitted — cosmetic indent/whitespace differences between the old inline
/// copies are intentionally collapsed.
enum DriverSourceBuilder {

    /// One generated driver's shape.
    struct DriverSpec {
        /// The program shell the run body is emitted into.
        enum Shell {
            /// Free `Task { do { … } catch { fputs(…) } }` + `await _task.value`
            /// — the `.meridian.test` runner, which reports results through
            /// stdout and must not throw out of the top-level program.
            case detachedTask
            /// `@main struct Driver { static func main() async throws { … } }`
            /// — the CLI `run` driver, where `JSONLObserver.stdout` emits the
            /// JSONL itself and a run error propagates to `swift run`.
            case mainEntryPoint
        }

        /// How a `.detachedTask` driver reports the run's observed events on
        /// stdout. Unused by `.mainEntryPoint` (its observer prints JSONL).
        struct ResultReporting {
            /// Prefix of the sentinel line carrying the final
            /// completion/failure `reason` payload string.
            let finalReasonSentinel: String
            /// Prefix of the sentinel line carrying a final binding's
            /// `scalarDescription`.
            let finalBindingSentinel: String
            /// Emit the final-binding sentinel line for this binding key;
            /// `nil` omits the block.
            let finalBindingKey: String?
        }

        var shell: Shell
        /// Modules imported between `MeridianRuntime` and `GeneratedWorkflow`.
        var extraImports: [String] = []
        /// Emit the section comments (`// Value JSON helper`, `// Entry
        /// point`) and the blank-line separators around the parameter-decode
        /// block — the `.meridian.test` driver's annotated layout.
        var sectionSpacing = false
        /// `{amount, currency}` JSON records decode to `.money` (the test
        /// runner relies on this); otherwise records stay records.
        var moneyCoercion = false
        /// Register the built-in tool set before the stubs.
        var registerBuiltins = false
        /// Expression constructing the observer.
        var observerExpr: String
        /// Expression constructing the checkpointer.
        var checkpointRootExpr: String
        /// Run identifier embedded in the default trace-store filename.
        var runID: String
        /// `try` on parameter decode instead of `(try? …) ?? Type()`.
        var strictParamDecode = false
        /// Workflow struct to instantiate.
        var workflowStructName: String
        /// The struct carries a `runtimeTraceConfiguration`.
        var hasTraceConfiguration: Bool
        /// `(parameter name, kind type name)` pairs, in order.
        var parameters: [(name: String, kindName: String)]
        /// `(parameter name, JSON)` inputs; a parameter with no input decodes
        /// from `{}`.
        var inputs: [(name: String, json: String)]
        /// `(tool ID, JSON)` closure stubs.
        var toolStubs: [(name: String, json: String)]
        /// `nil` discards the run result (CLI `run`).
        var reporting: ResultReporting?
        /// Body indent — the two shells nest the body at different depths.
        var indent: String
    }

    /// Emit the complete driver source for `spec`.
    static func driver(spec: DriverSpec) -> String {
        var lines: [String] = [
            "import Foundation",
            "import MeridianRuntime",
        ]
        lines += spec.extraImports.map { "import \($0)" }
        lines.append("import GeneratedWorkflow")
        lines.append("")
        if spec.sectionSpacing { lines.append("// Value JSON helper") }
        lines += jsonBridge(includeMoneyCoercion: spec.moneyCoercion)
        lines.append("")
        if spec.sectionSpacing { lines.append("// Entry point") }

        switch spec.shell {
        case .detachedTask:
            lines.append("let _task = Task {")
            lines.append("    do {")
        case .mainEntryPoint:
            lines.append("@main")
            lines.append("struct Driver {")
            lines.append("    static func main() async throws {")
        }

        let indent = spec.indent
        lines.append("\(indent)let registry = ToolRegistry()")
        if spec.registerBuiltins { lines.append("\(indent)await registry.registerBuiltins()") }
        for stub in spec.toolStubs {
            lines += toolStub(name: stub.name, json: stub.json, indent: indent)
        }
        lines.append("\(indent)let observer = \(spec.observerExpr)")
        lines += runtimeBootstrap(
            workflowStructName: spec.workflowStructName,
            hasTraceConfiguration: spec.hasTraceConfiguration,
            runID: spec.runID,
            observerExpr: "observer",
            checkpointRootExpr: spec.checkpointRootExpr,
            indent: indent
        )
        if spec.sectionSpacing { lines.append("") }

        let inputsByName = Dictionary(spec.inputs.map { ($0.name, $0.json) }, uniquingKeysWith: { _, new in new })
        for param in spec.parameters {
            lines += paramDecode(
                name: param.name,
                swiftType: IdentifierNaming.pascalCase(param.kindName),
                json: inputsByName[param.name] ?? "{}",
                indent: indent,
                force: spec.strictParamDecode
            )
        }

        let arguments = (["runtime: runtime"] + spec.parameters.map { "\($0.name): \($0.name)" })
            .joined(separator: ", ")
        let runCall = "try await \(spec.workflowStructName)(\(arguments)).run()"

        if let reporting = spec.reporting {
            lines.append("")
            lines.append("\(indent)var __meridianResult: WorkflowResult?")
            lines.append("\(indent)do {")
            lines.append("\(indent)    __meridianResult = \(runCall)")
            lines.append("\(indent)} catch {}")
            lines.append("")
            lines.append("\(indent)let events = await observer.events")
            lines.append("\(indent)for event in events {")
            lines.append("\(indent)    print(event.kind.rawValue)")
            lines.append("\(indent)}")
            lines.append("\(indent)if let final = events.last(where: { $0.kind == .workflowCompleted || $0.kind == .workflowFailed }),")
            lines.append("\(indent)   case .string(let reason)? = (final.payload ?? [:])[\"reason\"] {")
            lines.append("\(indent)    print(\"\(escapeSwiftStringLiteral(reporting.finalReasonSentinel))\\(reason)\")")
            lines.append("\(indent)}")
            if let bindingKey = reporting.finalBindingKey {
                lines.append("\(indent)if let v = __meridianResult?.bindings?[\"\(escapeSwiftStringLiteral(bindingKey))\"] {")
                lines.append("\(indent)    print(\"\(escapeSwiftStringLiteral(reporting.finalBindingSentinel))\\(v.scalarDescription)\")")
                lines.append("\(indent)}")
            }
        } else {
            lines.append("\(indent)_ = \(runCall)")
        }

        switch spec.shell {
        case .detachedTask:
            lines.append("    } catch {")
            lines.append("        fputs(\"driver: \\(error)\\n\", stderr)")
            lines.append("    }")
            lines.append("}")
            lines.append("await _task.value")
        case .mainEntryPoint:
            lines.append("    }")
            lines.append("}")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// The `valueFromJSON` / `convertAny` JSON→`Value` bridge.
    /// Parameter includeMoneyCoercion: when `true`, a `{amount, currency}`
    ///   record decodes to `.money` (the `.meridian.test` runner relies on
    ///   this); the CLI `run` driver omits it (records stay records).
    static func jsonBridge(includeMoneyCoercion: Bool) -> [String] {
        var lines = [
            "func meridianParameterDecoder() -> JSONDecoder {",
            "    let decoder = JSONDecoder()",
            "    decoder.dateDecodingStrategy = .iso8601",
            "    return decoder",
            "}",
            "func valueFromJSON(_ s: String) -> Value {",
            "    guard let data = s.data(using: .utf8),",
            "          let obj = try? JSONSerialization.jsonObject(with: data) else { return .string(s) }",
            "    return convertAny(obj)",
            "}",
            "func convertAny(_ obj: Any) -> Value {",
            "    if obj is NSNull { return .null }",
            "    if let s = obj as? String { return .string(s) }",
            "    if let b = obj as? Bool { return .boolean(b) }",
            "    if let n = obj as? NSNumber {",
            "        if CFGetTypeID(n) == CFBooleanGetTypeID() { return .boolean(n.boolValue) }",
            "        return .number(Decimal(string: n.stringValue) ?? 0)",
            "    }",
            "    if let arr = obj as? [Any] { return .list(arr.map(convertAny)) }",
        ]
        if includeMoneyCoercion {
            lines += [
                "    if let dict = obj as? [String: Any] {",
                "        if let amt = dict[\"amount\"] as? NSNumber,",
                "           let cur = dict[\"currency\"] as? String {",
                "            return .money(Money(amount: Decimal(string: amt.stringValue) ?? 0, currency: cur))",
                "        }",
                "        return .record(dict.mapValues(convertAny))",
                "    }",
            ]
        } else {
            lines.append("    if let dict = obj as? [String: Any] { return .record(dict.mapValues(convertAny)) }")
        }
        lines += [
            "    return .null",
            "}",
        ]
        return lines
    }

    /// Lines registering a closure tool stub that returns a fixed JSON value.
    static func toolStub(name: String, json: String, indent: String) -> [String] {
        [
            "\(indent)await registry.register(tool: \"\(escapeSwiftStringLiteral(name))\", .closure { _ in",
            "\(indent)    valueFromJSON(\"\(escapeSwiftStringLiteral(json))\")",
            "\(indent)})",
        ]
    }

    /// Lines decoding one workflow parameter from JSON.
    /// Parameter force: `true` uses `try` and lets a decode failure propagate
    ///   (CLI `run`); `false` falls back to a zero-arg `Type()` (test runner,
    ///   which tolerates partial fixtures).
    static func paramDecode(name: String, swiftType: String, json: String, indent: String, force: Bool) -> [String] {
        // ISO-8601 dates: the vocabulary's `date`/`dateTime` properties are
        // Swift `Date`s, whose default `Codable` form is a Double epoch — an
        // author passing `"2026-10-01T00:00:00Z"` must decode.
        let decode = force
            ? "\(indent)let \(name) = try meridianParameterDecoder().decode(\(swiftType).self, from: _\(name)Data)"
            : "\(indent)let \(name) = (try? meridianParameterDecoder().decode(\(swiftType).self, from: _\(name)Data)) ?? \(swiftType)()"
        return [
            "\(indent)let _\(name)Data = Data(\"\(escapeSwiftStringLiteral(json))\".utf8)",
            decode,
        ]
    }

    /// Runtime construction with optional trace-store wiring from compiled trace config.
    static func runtimeBootstrap(
        workflowStructName: String,
        hasTraceConfiguration: Bool,
        runID: String,
        observerExpr: String,
        checkpointRootExpr: String,
        indent: String
    ) -> [String] {
        if hasTraceConfiguration {
            return [
                "\(indent)let __meridianTraceConfig = \(workflowStructName).runtimeTraceConfiguration!",
                "\(indent)let __meridianTraceStore: any TraceStore",
                "\(indent)switch __meridianTraceConfig.store {",
                "\(indent)case .memory:",
                "\(indent)    __meridianTraceStore = InMemoryTraceStore(configuration: __meridianTraceConfig.trace)",
                "\(indent)case .file:",
                "\(indent)    let url: URL",
                "\(indent)    if let storePath = __meridianTraceConfig.storePath {",
                "\(indent)        url = URL(fileURLWithPath: storePath)",
                "\(indent)    } else {",
                "\(indent)        url = FileManager.default.temporaryDirectory",
                "\(indent)            .appendingPathComponent(\"meridian-trace-\(escapeSwiftStringLiteral(runID)).jsonl\")",
                "\(indent)    }",
                "\(indent)    __meridianTraceStore = try JSONLTraceStore(fileURL: url, configuration: __meridianTraceConfig.trace)",
                "\(indent)}",
                "\(indent)let runtime = Runtime(",
                "\(indent)    toolRegistry: registry,",
                "\(indent)    observer: \(observerExpr),",
                "\(indent)    traceStore: __meridianTraceStore,",
                "\(indent)    checkpointer: \(checkpointRootExpr),",
                "\(indent)    runID: \"\(escapeSwiftStringLiteral(runID))\",",
                "\(indent)    traceConfiguration: __meridianTraceConfig.trace,",
                "\(indent)    traceSkillIdentity: __meridianTraceConfig.skillIdentity",
                "\(indent))",
            ]
        }
        return [
            "\(indent)let runtime = Runtime(toolRegistry: registry, observer: \(observerExpr), checkpointer: \(checkpointRootExpr), runID: \"\(escapeSwiftStringLiteral(runID))\")",
        ]
    }
}
