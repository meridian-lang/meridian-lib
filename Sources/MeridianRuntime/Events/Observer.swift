import Foundation

// MARK: - Observer protocol

public protocol Observer: Sendable {
    func record(_ event: Event) async
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

    public func record(_ event: Event) async {
        let line = formatEvent(event)
        switch destination {
        case .standardOutput:
            print(line)
        case .file(let url):
            let data = (line + "\n").data(using: .utf8) ?? Data()
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private func formatEvent(_ event: Event) -> String {
        var dict: [String: Any] = [
            "ts": ISO8601DateFormatter.meridianFormatter.string(from: event.timestamp),
            "run_id": event.runID,
            "seq": event.sequence,
            "kind": event.kind.rawValue
        ]

        // Flatten well-known payload fields to top-level (matching golden JSONL shape)
        var payloadDict: [String: Any] = [:]
        for (k, v) in event.payload {
            payloadDict[k] = v.jsonObject
        }

        // Per-kind top-level promotions matching the golden event format
        switch event.kind {
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
            if let parentRunID = event.parentRunID {
                dict["parent_run_id"] = parentRunID
            }
            if let parentSeq = event.parentSequence {
                dict["parent_seq"] = parentSeq
            }
            dict["payload"] = payloadDict
        default:
            if !payloadDict.isEmpty {
                dict["payload"] = payloadDict
            }
        }

        if let source = event.sourceRange {
            dict["source"] = ["file": source.file, "line": source.startLine, "col": source.startColumn]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"kind\":\"\(event.kind.rawValue)\",\"error\":\"serialization_failed\"}"
        }
        return str
    }
}

// MARK: - InMemoryObserver

public actor InMemoryObserver: Observer {
    private var _events: [Event] = []

    public init() {}

    public var events: [Event] { _events }

    public func record(_ event: Event) async {
        _events.append(event)
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

    public func record(_ event: Event) async {
        for observer in observers {
            await observer.record(event)
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

extension ISO8601DateFormatter {
    nonisolated(unsafe) static let meridianFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - Value.jsonObject helper

extension Value {
    var jsonObject: Any {
        switch self {
        case .string(let s): return s
        case .number(let n): return (n as NSDecimalNumber).doubleValue
        case .boolean(let b): return b
        case .money(let m): return m.description
        case .duration(let d): return d.description
        case .date(let d): return ISO8601DateFormatter.meridianFormatter.string(from: d)
        case .dateTime(let d): return ISO8601DateFormatter.meridianFormatter.string(from: d)
        case .enumValue(let v, _): return v
        case .record(let dict): return dict.mapValues { $0.jsonObject }
        case .list(let arr): return arr.map { $0.jsonObject }
        case .reference(let r): return r
        case .null: return NSNull()
        case .opaque(let box): return String(describing: box)
        }
    }
}
