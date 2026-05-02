import Foundation

// MARK: - SpecParser

/// Parses `.meridian.test` spec files into `MeridianTestRunner.Spec`.
///
/// Format rules:
///   - Lines starting with `#` or empty are ignored.
///   - `key: value` — simple key/value pair.
///   - `key: ```` (with an optional info-string suffix, e.g. ```` ```meridian````)
///     opens a fenced code block. The body is read verbatim — no indent
///     stripping — until a line whose trimmed content is exactly the closing
///     fence (```` ```` ```). This is preferred for any value that itself
///     contains markdown-y boundaries (frontmatter `---`, list markers, etc.)
///     because the fence makes the value boundary unambiguous.
///   - Keys may contain spaces (e.g. `tool_stub validate an order`).
///   - Repeatable keys: `vocab`, `vocab_inline <name>`, `expect_swift_contains`,
///     `expect_invoke_tool`, `expect_emit_event`, `expect_trace_contains`,
///     `tool_stub <id>`, `input <param>`, and any other `expect_*` assertion key.
struct SpecParser {

    struct ParseError: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }

    // MARK: - Entry point

    func parse(_ content: String, fileURL: URL) throws -> MeridianTestRunner.Spec {
        let pairs = try tokenize(content)
        return try buildSpec(from: pairs, fileURL: fileURL)
    }

    // MARK: - Tokenise

    /// Returns `[(key, value)]`. For heredocs the value is the assembled body string.
    private func tokenize(_ content: String) throws -> [(key: String, value: String)] {
        var result: [(key: String, value: String)] = []
        let rawLines = content.components(separatedBy: "\n")
        var i = 0

        while i < rawLines.count {
            let line = rawLines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                i += 1
                continue
            }

            guard let colonRange = trimmed.range(of: ":") else {
                i += 1
                continue
            }

            let key   = trimmed[..<colonRange.lowerBound].trimmingCharacters(in: .whitespaces)
            let after = trimmed[colonRange.upperBound...].trimmingCharacters(in: .whitespaces)

            if after.hasPrefix("```") {
                // Fenced code block. The opening fence may carry an info
                // string (e.g. ```meridian) which we ignore. The closing
                // fence is a line whose trimmed text is exactly ```.
                i += 1
                var bodyLines: [String] = []
                var closed = false
                while i < rawLines.count {
                    let bodyLine = rawLines[i]
                    if bodyLine.trimmingCharacters(in: .whitespaces) == "```" {
                        closed = true
                        i += 1
                        break
                    }
                    bodyLines.append(bodyLine)
                    i += 1
                }
                guard closed else {
                    throw ParseError(message: "unterminated fenced block for key '\(key)' (missing closing ```)")
                }
                result.append((key: key, value: bodyLines.joined(separator: "\n")))
            } else if after == "|" {
                throw ParseError(message: "key '\(key)': YAML-style `|` heredoc is no longer supported; use a fenced code block (``` … ```) instead.")
            } else {
                result.append((key: key, value: after))
                i += 1
            }
        }
        return result
    }

    // MARK: - Build Spec

    private func buildSpec(
        from pairs: [(key: String, value: String)],
        fileURL: URL
    ) throws -> MeridianTestRunner.Spec {
        let baseDir = fileURL.deletingLastPathComponent()

        // Defaults
        var displayName      = defaultDisplayName(from: fileURL)
        var description: String?   = nil
        var tags: [String]         = []
        var only                   = false
        var skip: MeridianTestRunner.SkipMode = .none
        var traceCategories: [ParserTrace.Category] = []
        var sourceInput: MeridianTestRunner.SourceInput? = nil
        var vocabInputs: [MeridianTestRunner.VocabInput]  = []
        var compileExpectation: MeridianTestRunner.CompileExpectation = .pass
        var assertions: [Assertion] = []
        var noLineComments         = false

        // Runtime spec components (assembled below)
        var expectRun              = false
        var workflowName: String?  = nil
        var inputs:    [(paramName: String, json: String)] = []
        var toolStubs: [(toolID: String, json: String)]    = []
        var expectEventKinds: [String]?       = nil
        var expectEventKindsPrefix: [String]? = nil
        var expectFinalEventKind: String?     = nil
        var expectRunSucceeded: Bool?         = nil

        // Error-assertion components (folded into assertions at the end)
        var expectErrorKind: CompileErrorKind?     = nil
        var expectErrorContains: String?           = nil
        var expectErrorLine: Int?                  = nil

        for (key, value) in pairs {
            switch key {

            // Metadata
            case "name":        displayName = value
            case "description": description = value
            case "tags":
                tags = value.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            case "only":        only = value == "true"
            case "skip":        if value == "true" { skip = .skipped(reason: nil) }
            case "skip_reason": skip = .skipped(reason: value)
            case "trace":       traceCategories = parseTraceCategories(value)

            // Sources
            case "source":        sourceInput = .path(value)
            case "source_inline": sourceInput = .inline(value)
            case "vocab":         vocabInputs.append(.path(value))

            // Legacy key kept for backwards compatibility
            case "golden_swift":  assertions.append(.goldenSwift(path: value))

            case "no_line_comments": noLineComments = value == "true"

            // Compile expectation
            case "expect_compile":
                switch value.lowercased() {
                case "fail": compileExpectation = .fail
                case "pass": compileExpectation = .pass
                default: throw ParseError(message: "unknown expect_compile value: '\(value)' (use 'pass' or 'fail')")
                }

            // Error sub-assertions (only relevant when expect_compile: fail)
            case "expect_error_kind":
                switch value.lowercased() {
                case "syntax":   expectErrorKind = .syntax
                case "semantic": expectErrorKind = .semantic
                case "codegen":  expectErrorKind = .codegen
                default: throw ParseError(message: "unknown expect_error_kind: '\(value)'")
                }
            case "expect_error_contains": expectErrorContains = value
            case "expect_error_line":
                guard let n = Int(value) else {
                    throw ParseError(message: "expect_error_line must be an integer, got '\(value)'")
                }
                expectErrorLine = n

            // Swift-output assertions
            case "expect_swift_contains":     assertions.append(.swiftContains(value))
            case "expect_swift_not_contains": assertions.append(.swiftNotContains(value))
            case "expect_swift_matches":      assertions.append(.swiftMatches(value))
            case "golden_swift_path":         assertions.append(.goldenSwift(path: value))
            case "golden_manifest":           assertions.append(.goldenManifest(path: value))
            case "expect_swift_line_count_min":
                if let n = Int(value) { assertions.append(.swiftLineCountMin(n)) }
            case "expect_swift_line_count_max":
                if let n = Int(value) { assertions.append(.swiftLineCountMax(n)) }

            // IR assertions
            case "expect_workflow_count":
                if let n = Int(value) { assertions.append(.workflowCount(n)) }
            case "expect_workflow_named": assertions.append(.workflowNamed(value))
            case "expect_no_unresolved":  assertions.append(.noUnresolved)
            case "expect_invoke_tool":    assertions.append(.invokeToolID(value))
            case "expect_emit_event":     assertions.append(.emitEventID(value))

            case "expect_primitive_count":
                // value is "<kind> <N>"
                let parts = value.split(separator: " ", maxSplits: 1)
                guard parts.count == 2, let n = Int(parts[1]),
                      let kind = IRPrimitiveKind(rawValue: String(parts[0])) else {
                    throw ParseError(message: "expect_primitive_count value must be '<kind> <N>', got '\(value)'")
                }
                assertions.append(.primitiveCount(kind, n))

            case "expect_workflow_mode":
                // value is "<StructName> strict|lenient"
                let parts = value.split(separator: " ", maxSplits: 1)
                guard parts.count == 2 else {
                    throw ParseError(message: "expect_workflow_mode value must be '<StructName> strict|lenient', got '\(value)'")
                }
                let structName = String(parts[0])
                let mode: ExecutionMode = String(parts[1]).lowercased() == "lenient" ? .lenient : .strict
                assertions.append(.workflowMode(structName: structName, mode: mode))

            // Formatter
            case "expect_formatter_idempotent":
                if value == "true" { assertions.append(.formatterIdempotent) }

            // Trace
            case "expect_trace_contains": assertions.append(.traceContains(value))

            // Runtime
            case "expect_run":    expectRun = value == "true"
            case "workflow":      workflowName = value
            case "expect_event_kinds":
                expectEventKinds = value.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            case "expect_event_kinds_prefix":
                expectEventKindsPrefix = value.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            case "expect_final_event_kind": expectFinalEventKind = value
            case "expect_run_succeeded":    expectRunSucceeded = value == "true"

            default:
                // Compound keys with spaces in them
                if key.hasPrefix("vocab_inline ") {
                    let vocabName = String(key.dropFirst("vocab_inline ".count))
                        .trimmingCharacters(in: .whitespaces)
                    vocabInputs.append(.inline(name: vocabName, source: value))

                } else if key.hasPrefix("input ") {
                    let paramName = String(key.dropFirst("input ".count))
                        .trimmingCharacters(in: .whitespaces)
                    inputs.append((paramName: paramName, json: value))

                } else if key.hasPrefix("tool_stub ") {
                    let toolID = String(key.dropFirst("tool_stub ".count))
                        .trimmingCharacters(in: .whitespaces)
                    toolStubs.append((toolID: toolID, json: value))
                }
                // Unknown keys are silently ignored so older runners can
                // still process specs with keys added by newer versions.
            }
        }

        guard sourceInput != nil else {
            throw MeridianTestRunner.SpecError.missingRequiredKey(
                "source or source_inline",
                file: fileURL.lastPathComponent
            )
        }

        // Fold error sub-assertions into the main assertions list.
        // They appear first so error checks print before other mismatches.
        if compileExpectation == .fail {
            if let k = expectErrorKind { assertions.insert(.errorKind(k), at: 0) }
            if let s = expectErrorContains { assertions.insert(.errorContains(s), at: 0) }
            if let l = expectErrorLine { assertions.insert(.errorLine(l), at: 0) }
            // Even with no sub-assertions, the runner will check that compile failed.
        }

        // Assemble optional runtime spec
        let runtimeSpec: MeridianTestRunner.RuntimeSpec? = expectRun ? .init(
            workflowName:         workflowName,
            inputs:               inputs,
            toolStubs:            toolStubs,
            expectEventKinds:     expectEventKinds,
            expectEventKindsPrefix: expectEventKindsPrefix,
            expectFinalEventKind: expectFinalEventKind,
            expectRunSucceeded:   expectRunSucceeded
        ) : nil

        return MeridianTestRunner.Spec(
            displayName:        displayName,
            baseDir:            baseDir,
            description:        description,
            tags:               tags,
            only:               only,
            skip:               skip,
            traceCategories:    traceCategories,
            source:             sourceInput!,
            vocab:              vocabInputs,
            compileExpectation: compileExpectation,
            assertions:         assertions,
            runtime:            runtimeSpec,
            noLineComments:     noLineComments
        )
    }

    // MARK: - Helpers

    private func defaultDisplayName(from url: URL) -> String {
        var name = url.deletingPathExtension().lastPathComponent
        if name.hasSuffix(".meridian") {
            name = String(name.dropLast(".meridian".count))
        }
        return name
    }

    private func parseTraceCategories(_ spec: String) -> [ParserTrace.Category] {
        spec.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ", "))
            .filter { !$0.isEmpty }
            .compactMap { token in
                if token == "all" {
                    return ParserTrace.Category.allCases
                }
                return ParserTrace.Category.allCases.filter { cat in
                    cat.rawValue == token || cat.rawValue.hasPrefix(token + ".")
                }
            }
            .flatMap { $0 }
    }
}
