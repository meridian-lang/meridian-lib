import Foundation
import MeridianRuntime

// MARK: - Trace section

extension MerConfigParser {
    func parseTraceSection(_ lines: [SourceLine], file: String) throws -> TraceConfigurationAST {
        var store: TraceConfigValue<TraceStoreKind>?
        var retention: TraceConfigValue<Duration>?
        var hashChaining: TraceConfigValue<Bool>?
        var payloadLimit: TraceConfigValue<Int>?
        var usuallyThreshold: TraceConfigValue<Double>?
        var rarelyThreshold: TraceConfigValue<Double>?
        var sampleFloor: TraceConfigValue<Int>?
        var defaultMonitorCadence: TraceConfigValue<Duration>?
        var profile: TraceConfigValue<TraceProfile>?
        var storeFailurePolicy: TraceConfigValue<TraceStoreFailurePolicy>?
        var deploymentZone: TraceConfigValue<String>?
        var crossSkillAllowList: TraceConfigValue<[String]>?
        var stateHistoryRetention: TraceConfigValue<Bool>?
        var storePath: TraceConfigValue<String>?
        var storeEndpoint: TraceConfigValue<String>?

        for line in lines where line.isContent {
            let statement = line.statement.trimmingCharacters(in: .whitespaces)
            guard let colon = statement.firstIndex(of: ":") else {
                try reportToolDiagnostic(
                    message: "malformed trace setting: \"\(statement)\"",
                    range: SourceRange(file: file, line: line.number, column: 1),
                    help: "Use `key: value` entries inside `=== trace ===`."
                )
                continue
            }
            let key = statement[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = statement[statement.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            switch key {
            case "store":
                guard let parsed = TraceStoreKind(rawValue: value.lowercased()) else {
                    try reportToolDiagnostic(
                        message: "unknown trace store `\(value)`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use `memory`, `file`, `sqlite`, or `http`."
                    )
                    continue
                }
                store = .init(parsed, file: file, line: line.number)
            case "store path":
                guard !value.isEmpty else {
                    try reportToolDiagnostic(
                        message: "store path cannot be empty",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Provide a filesystem path for `sqlite` or `file` stores."
                    )
                    continue
                }
                storePath = .init(String(value), file: file, line: line.number)
            case "store endpoint":
                guard !value.isEmpty else {
                    try reportToolDiagnostic(
                        message: "store endpoint cannot be empty",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Provide an HTTP(S) base URL for `http` stores."
                    )
                    continue
                }
                storeEndpoint = .init(String(value), file: file, line: line.number)
            case "retention":
                guard let parsed = parseTraceDuration(String(value)) else {
                    try reportToolDiagnostic(
                        message: "invalid trace retention `\(value)`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use a duration such as `30 days`."
                    )
                    continue
                }
                retention = .init(parsed, file: file, line: line.number)
            case "hash chaining":
                let lower = value.lowercased()
                guard lower == "enabled" || lower == "disabled" else {
                    try reportToolDiagnostic(
                        message: "invalid hash chaining setting `\(value)`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use `enabled` or `disabled`."
                    )
                    continue
                }
                hashChaining = .init(lower == "enabled", file: file, line: line.number)
            case "payload limit":
                guard let parsed = Int(value) else {
                    try reportToolDiagnostic(
                        message: "invalid payload limit `\(value)`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use an integer byte limit such as `8192`."
                    )
                    continue
                }
                payloadLimit = .init(parsed, file: file, line: line.number)
            case "usually at least":
                usuallyThreshold = .init(try parsePercent(value, file: file, line: line.number, key: String(key)), file: file, line: line.number)
            case "rarely at most":
                rarelyThreshold = .init(try parsePercent(value, file: file, line: line.number, key: String(key)), file: file, line: line.number)
            case "sample floor":
                guard let parsed = Int(value) else {
                    try reportToolDiagnostic(
                        message: "invalid sample floor `\(value)`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use an integer sample count."
                    )
                    continue
                }
                sampleFloor = .init(parsed, file: file, line: line.number)
            case "default monitor cadence":
                guard let parsed = parseTraceDuration(String(value)) else {
                    try reportToolDiagnostic(
                        message: "invalid monitor cadence `\(value)`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use a duration such as `1 days`."
                    )
                    continue
                }
                defaultMonitorCadence = .init(parsed, file: file, line: line.number)
            case "profile":
                guard let parsed = TraceProfile(rawValue: value.lowercased()) else {
                    try reportToolDiagnostic(
                        message: "unknown trace profile `\(value)`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use `development` or `production`."
                    )
                    continue
                }
                profile = .init(parsed, file: file, line: line.number)
            case "store failure policy":
                let normalized = value.lowercased().replacingOccurrences(of: "-", with: "")
                let parsed: TraceStoreFailurePolicy?
                switch normalized {
                case "auto": parsed = .auto
                case "failopen": parsed = .failOpen
                case "failclosed": parsed = .failClosed
                default: parsed = nil
                }
                guard let parsed else {
                    try reportToolDiagnostic(
                        message: "unknown trace store failure policy `\(value)`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use `fail-open`, `fail-closed`, or `auto`."
                    )
                    continue
                }
                storeFailurePolicy = .init(parsed, file: file, line: line.number)
            case "deployment zone":
                deploymentZone = .init(String(value), file: file, line: line.number)
            case "cross-skill allow-list":
                let skills = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                crossSkillAllowList = .init(skills, file: file, line: line.number)
            case "state history":
                let lower = value.lowercased()
                guard lower == "enabled" || lower == "disabled" else {
                    try reportToolDiagnostic(
                        message: "invalid state history setting `\(value)`",
                        range: SourceRange(file: file, line: line.number, column: 1),
                        help: "Use `enabled` or `disabled`."
                    )
                    continue
                }
                stateHistoryRetention = .init(lower == "enabled", file: file, line: line.number)
            default:
                try reportToolDiagnostic(
                    message: "unknown trace setting `\(key)`",
                    range: SourceRange(file: file, line: line.number, column: 1),
                    help: "Use documented keys such as `store`, `retention`, `hash chaining`, or `profile`."
                )
            }
        }

        return TraceConfigurationAST(
            store: store,
            retention: retention,
            hashChaining: hashChaining,
            payloadLimit: payloadLimit,
            usuallyThreshold: usuallyThreshold,
            rarelyThreshold: rarelyThreshold,
            sampleFloor: sampleFloor,
            defaultMonitorCadence: defaultMonitorCadence,
            profile: profile,
            storeFailurePolicy: storeFailurePolicy,
            deploymentZone: deploymentZone,
            crossSkillAllowList: crossSkillAllowList,
            stateHistoryRetention: stateHistoryRetention,
            storePath: storePath,
            storeEndpoint: storeEndpoint
        )
    }

    func parsePercent(_ value: String, file: String, line: Int, key: String) throws -> Double {
        let text = value.trimmingCharacters(in: .whitespaces)
        let stripped = text.hasSuffix("%") ? String(text.dropLast()) : text
        guard let percent = Double(stripped) else {
            try reportToolDiagnostic(
                message: "invalid percentage for `\(key)`: \"\(text)\"",
                range: SourceRange(file: file, line: line, column: 1),
                help: "Use a percentage such as `90%` or `10`."
            )
            return 0
        }
        return percent > 1 ? percent / 100.0 : percent
    }

    func parseTraceDuration(_ raw: String) -> Duration? {
        guard let (amount, unit) = lexicon.parseDuration(raw) else {
            return nil
        }
        return .seconds(Int64(amount * Double(unit.inSeconds)))
    }

    func reportToolDiagnostic(message: String, range: SourceRange, help: String) throws {
        let diag = Diagnostic.structural(
            .vocabularyDeclarationUnrecognized,
            message: message,
            range: range,
            help: help)
        if let diagnostics {
            diagnostics.report(diag)
        } else {
            throw CompilerError.diagnostics([diag])
        }
    }
}
