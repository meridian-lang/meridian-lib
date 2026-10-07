import ArgumentParser
import Foundation
import MeridianRuntime

public struct TraceVerifyCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "trace-verify",
        abstract: "Verify a semantic trace store JSONL file for tampering and corruption."
    )

    @Argument(help: "Path to a semantic trace-store .jsonl file.")
    var input: String

    @Option(name: .customLong("run"), help: "Run ID whose semantic chain should be verified.")
    var runID: String

    @Flag(name: .long, help: "Emit a stable JSON report instead of human-readable text.")
    var json: Bool = false

    public func run() throws {
        try TraceVerifyRunner.run(input: input, runID: runID, json: json)
    }
}

enum TraceVerifyRunner {
    private struct LineEnvelope: Decodable {
        let record: TraceRecord
        let checksum: String
    }

    private struct LoadedLine {
        let lineNumber: Int
        let record: TraceRecord
        let checksum: String
    }

    private struct CheckStatus: Encodable {
        let schema: Bool
        let checksums: Bool
        let order: Bool
        let content: Bool
    }

    private struct QuarantineStatus: Encodable {
        let present: Bool
        let files: [String]
    }

    private struct Issue: Encodable {
        let kind: String
        let message: String
        let line: Int?
        let recordID: String?

        enum CodingKeys: String, CodingKey {
            case kind
            case message
            case line
            case recordID = "record_id"
        }
    }

    private struct Report: Encodable {
        let file: String
        let runID: String
        let ok: Bool
        let lineCount: Int
        let matchedRunRecords: Int
        let schemaVersions: [Int]
        let checks: CheckStatus
        let quarantine: QuarantineStatus
        let issues: [Issue]

        enum CodingKeys: String, CodingKey {
            case file
            case runID = "run_id"
            case ok
            case lineCount = "line_count"
            case matchedRunRecords = "matched_run_records"
            case schemaVersions = "schema_versions"
            case checks
            case quarantine
            case issues
        }
    }

    static func run(input: String, runID: String, json: Bool) throws {
        let url = URL(fileURLWithPath: input).standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(input)")
        }

        let report = try verify(fileURL: url, runID: runID)
        if json {
            try emitJSON(report)
        } else {
            emitHuman(report)
        }
        if !report.ok {
            throw ExitCode(1)
        }
    }

    private static func verify(fileURL: URL, runID: String) throws -> Report {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        let rawLines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var issues: [Issue] = []
        var parsed: [LoadedLine] = []
        let supportedSchemaVersions = supportedSchemaVersionSet()

        for (index, line) in rawLines.enumerated() {
            let lineNumber = index + 1
            guard let data = line.data(using: .utf8) else {
                issues.append(Issue(
                    kind: "corrupted_line",
                    message: "Line is not valid UTF-8.",
                    line: lineNumber,
                    recordID: nil
                ))
                continue
            }

            let envelope: LineEnvelope
            do {
                envelope = try decoder.decode(LineEnvelope.self, from: data)
            } catch {
                issues.append(Issue(
                    kind: "corrupted_line",
                    message: "Line is not a valid trace-store record envelope.",
                    line: lineNumber,
                    recordID: nil
                ))
                continue
            }

            parsed.append(LoadedLine(
                lineNumber: lineNumber,
                record: envelope.record,
                checksum: envelope.checksum
            ))

            if !supportedSchemaVersions.contains(envelope.record.schemaVersion) {
                issues.append(Issue(
                    kind: "unsupported_schema_version",
                    message: "Schema version \(envelope.record.schemaVersion) is not supported by this verifier.",
                    line: lineNumber,
                    recordID: envelope.record.id
                ))
            }

            let expectedChecksum = try CanonicalJSON.sha256Hex(for: envelope.record)
            if expectedChecksum != envelope.checksum {
                issues.append(Issue(
                    kind: "line_checksum_mismatch",
                    message: "Envelope checksum does not match the canonical checksum of the decoded record.",
                    line: lineNumber,
                    recordID: envelope.record.id
                ))
            }
        }

        let runLines = parsed.filter { $0.record.run == runID }
        if runLines.isEmpty {
            issues.append(Issue(
                kind: "run_not_found",
                message: "No trace records for run '\(runID)' were found in this file.",
                line: nil,
                recordID: nil
            ))
        }

        for loaded in runLines {
            guard let payload = loaded.record.payload else {
                continue
            }
            let expectedPayloadHash = try CanonicalJSON.sha256Hex(for: payload)
            if expectedPayloadHash != loaded.record.payloadHash {
                issues.append(Issue(
                    kind: "payload_hash_mismatch",
                    message: "Persisted payload does not match payload_hash.",
                    line: loaded.lineNumber,
                    recordID: loaded.record.id
                ))
            }
        }

        if let firstOrderIssue = firstOrderIssue(in: runLines) {
            issues.append(firstOrderIssue)
        }

        let quarantineFiles = try quarantineFilenames(for: fileURL)
        if !quarantineFiles.isEmpty {
            issues.append(Issue(
                kind: "quarantine_present",
                message: "Quarantined trace fragments were found beside the JSONL store.",
                line: nil,
                recordID: nil
            ))
        }

        let schemaOK = !issues.contains(where: { $0.kind == "unsupported_schema_version" || $0.kind == "corrupted_line" })
        let checksumsOK = !issues.contains(where: { $0.kind == "line_checksum_mismatch" || $0.kind == "corrupted_line" })
        let orderOK = !issues.contains(where: { $0.kind == "record_order_mismatch" || $0.kind == "run_not_found" })
        let contentOK = !issues.contains(where: { $0.kind == "payload_hash_mismatch" || $0.kind == "run_not_found" })
        return Report(
            file: fileURL.path,
            runID: runID,
            ok: issues.isEmpty,
            lineCount: rawLines.count,
            matchedRunRecords: runLines.count,
            schemaVersions: Array(Set(parsed.map(\.record.schemaVersion))).sorted(),
            checks: CheckStatus(
                schema: schemaOK,
                checksums: checksumsOK,
                order: orderOK,
                content: contentOK
            ),
            quarantine: QuarantineStatus(
                present: !quarantineFiles.isEmpty,
                files: quarantineFiles
            ),
            issues: issues
        )
    }

    private static func supportedSchemaVersionSet() -> Set<Int> {
        var versions: Set<Int> = [TraceRecord.currentSchemaVersion]
        if TraceRecord.currentSchemaVersion > 1 {
            versions.insert(TraceRecord.currentSchemaVersion - 1)
        }
        return versions
    }

    private static func firstOrderIssue(in runLines: [LoadedLine]) -> Issue? {
        guard runLines.count > 1 else { return nil }
        for index in 1..<runLines.count {
            let previous = runLines[index - 1]
            let current = runLines[index]
            if isRunLocalBefore(current.record, previous.record) {
                return Issue(
                    kind: "record_order_mismatch",
                    message: "Run-local file order does not match ingestOrder/at/id ordering.",
                    line: current.lineNumber,
                    recordID: current.record.id
                )
            }
        }
        return nil
    }

    private static func isRunLocalBefore(_ lhs: TraceRecord, _ rhs: TraceRecord) -> Bool {
        if lhs.ingestOrder != rhs.ingestOrder {
            return lhs.ingestOrder < rhs.ingestOrder
        }
        if lhs.at != rhs.at {
            return lhs.at < rhs.at
        }
        return lhs.id < rhs.id
    }

    private static func quarantineFilenames(for fileURL: URL) throws -> [String] {
        let directory = fileURL.deletingLastPathComponent()
        let prefix = fileURL.lastPathComponent + ".quarantine-"
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix(prefix) }
            .sorted()
    }

    private static func emitJSON(_ report: Report) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func emitHuman(_ report: Report) {
        var lines: [String] = []
        lines.append("Trace verification \(report.ok ? "passed" : "failed")")
        lines.append("File: \(report.file)")
        lines.append("Run: \(report.runID)")
        lines.append("Records: \(report.matchedRunRecords) matched run record(s) across \(report.lineCount) line(s)")
        lines.append("Checks:")
        lines.append("  schema: \(statusWord(report.checks.schema))")
        lines.append("  checksums: \(statusWord(report.checks.checksums))")
        lines.append("  order: \(statusWord(report.checks.order))")
        lines.append("  content: \(statusWord(report.checks.content))")
        lines.append("  quarantine: \(report.quarantine.present ? "present" : "none")")
        if !report.quarantine.files.isEmpty {
            for name in report.quarantine.files {
                lines.append("    - \(name)")
            }
        }
        if report.issues.isEmpty {
            lines.append("Issues: none")
        } else {
            lines.append("Issues:")
            for issue in report.issues {
                var prefix = "- \(issue.kind): \(issue.message)"
                if let line = issue.line {
                    prefix += " (line \(line))"
                }
                if let recordID = issue.recordID {
                    prefix += " [record \(recordID)]"
                }
                lines.append(prefix)
            }
        }
        FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    private static func statusWord(_ ok: Bool) -> String {
        ok ? "ok" : "failed"
    }
}
