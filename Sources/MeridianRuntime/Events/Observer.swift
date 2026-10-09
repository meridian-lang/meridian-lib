import Foundation

// MARK: - Observer protocol

public protocol Observer: Sendable {
    func record(_ record: TraceRecord) async throws
}

// MARK: - JSONLObserver

/// Writes events as JSONL to stdout or a file.
public struct JSONLObserver: Observer {
    public enum Destination: Sendable {
        case standardOutput
        case file(URL)
    }

    private let destination: Destination
    private let encoder: JSONEncoder

    public init(destination: Destination = .standardOutput) {
        self.destination = destination
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = []
        self.encoder = enc
    }

    public func record(_ record: TraceRecord) async throws {
        let line = try formatEvent(record)
        switch destination {
        case .standardOutput:
            print(line)
        case .file(let url):
            guard let data = (line + "\n").data(using: .utf8) else {
                throw ObserverError.writeFailed(path: url.path, underlying: "utf8 encoding failed")
            }
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: url, options: .atomic)
            }
        }
    }

    private func formatEvent(_ record: TraceRecord) throws -> String {
        var dict: [String: Any] = [
            "ts": ISO8601DateFormatter.meridianFormatter.string(from: record.at),
            "run_id": record.run,
            "seq": record.ingestOrder,
            "kind": record.kind.rawValue
        ]

        var payloadDict: [String: Any] = [:]
        for (k, v) in record.payload ?? [:] {
            payloadDict[k] = v.jsonEncodableObject
        }

        switch record.kind {
        case .invokeStart, .invokeEnd, .invokeError:
            if let tool = payloadDict["tool"] as? String {
                dict["tool"] = tool
                payloadDict.removeValue(forKey: "tool")
            }
            if let dms = payloadDict["duration_ms"] {
                dict["payload"] = ["duration_ms": dms, "output_summary": payloadDict["output_summary"] ?? ""]
                payloadDict.removeValue(forKey: "duration_ms")
                payloadDict.removeValue(forKey: "output_summary")
                if !payloadDict.isEmpty { dict["payload"] = payloadDict }
            } else {
                dict["payload"] = payloadDict
            }
        case .workflowStarted, .workflowCompleted, .workflowFailed:
            if let parentRunID = record.parentRunID {
                dict["parent_run_id"] = parentRunID
            }
            if let parentSeq = record.parentSequence {
                dict["parent_seq"] = parentSeq
            }
            dict["payload"] = payloadDict
        default:
            if !payloadDict.isEmpty {
                dict["payload"] = payloadDict
            }
        }

        if let source = record.sourceRange {
            dict["source"] = ["file": source.file, "line": source.startLine, "col": source.startColumn]
        }

        let data = try JSONSerialization.data(withJSONObject: dict)
        guard let str = String(data: data, encoding: .utf8) else {
            throw ObserverError.serializationFailed(record)
        }
        return str
    }
}

// MARK: - InMemoryObserver

public actor InMemoryObserver: Observer {
    private var _events: [TraceRecord] = []

    public init() {}

    public var events: [TraceRecord] { _events }

    public func record(_ record: TraceRecord) async throws {
        _events.append(record)
    }

    public func clear() async {
        _events = []
    }
}

// MARK: - CompositeObserver

public struct CompositeObserver: Observer {
    private let observers: [any Observer]

    public init(_ observers: [any Observer]) {
        self.observers = observers
    }

    public func record(_ record: TraceRecord) async throws {
        for observer in observers {
            try await observer.record(record)
        }
    }
}

// MARK: - Convenience static factories

public extension JSONLObserver {
    static var stdout: JSONLObserver { JSONLObserver(destination: .standardOutput) }

    static func file(_ path: URL) throws -> JSONLObserver {
        JSONLObserver(destination: .file(path))
    }
}

// MARK: - ISO8601DateFormatter cache

public extension ISO8601DateFormatter {
    nonisolated(unsafe) static let meridianFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
