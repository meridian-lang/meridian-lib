import CryptoKit
import Foundation

public enum CanonicalJSON {
    enum Node {
        case null
        case bool(Bool)
        case string(String)
        case array([Node])
        case object([String: Node])
    }

    public static func data(for record: TraceRecord) throws -> Data {
        try data(for: traceRecordNode(record))
    }

    public static func data(for payload: [String: Value]) throws -> Data {
        try data(for: .object(payload.mapValues(valueNode)))
    }

    public static func sha256Hex(for record: TraceRecord) throws -> String {
        let digest = SHA256.hash(data: try data(for: record))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func sha256Hex(for payload: [String: Value]) throws -> String {
        let digest = SHA256.hash(data: try data(for: payload))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func data(for node: Node) throws -> Data {
        Data(serialize(node).utf8)
    }

    private static func traceRecordNode(_ record: TraceRecord) -> Node {
        var object: [String: Node] = [
            "schemaVersion": .string(String(record.schemaVersion)),
            "id": .string(record.id),
            "at": .string(ISO8601DateFormatter.meridianFormatter.string(from: record.at)),
            "ingestOrder": .string(String(record.ingestOrder)),
            "run": .string(record.run),
            "step": .string(record.step),
            "skillName": .string(record.skillName),
            "skillVersionHash": .string(record.skillVersionHash),
            "tag": .string(record.tag.rawValue),
            "payloadHash": .string(record.payloadHash)
        ]

        if let subject = record.subject {
            object["subject"] = .string(subject)
        }
        if let subjectKey = record.subjectKey {
            object["subjectKey"] = .string(subjectKey)
        }
        if let payload = record.payload {
            object["payload"] = .object(payload.mapValues(valueNode))
        }
        if let outcome = record.outcome {
            object["outcome"] = .string(outcome.rawValue)
        }
        if let operationalDetail = record.operationalDetail {
            object["operationalDetail"] = .string(operationalDetail)
        }
        // Hashed under the historical key so records written before the
        // Event/TraceRecord unification still verify: their stored checksum was
        // computed over a node whose event-kind field was named `legacyKind`.
        // The record's own JSON encoding uses `kind` (see `TraceRecord.encode`).
        object["legacyKind"] = .string(record.kind.rawValue)
        return .object(object)
    }

    private static func valueNode(_ value: Value) -> Node {
        switch value {
        case .string(let string):
            return .string(string)
        case .number(let decimal):
            return .string(decimal.description)
        case .boolean(let boolean):
            return .bool(boolean)
        case .money(let money):
            return .string("\(money.amount.description) \(money.currency)")
        case .duration(let duration):
            return .string(duration.description)
        case .date(let date), .dateTime(let date):
            return .string(ISO8601DateFormatter.meridianFormatter.string(from: date))
        case .enumValue(let value, let kind):
            return .object(["value": .string(value), "kind": .string(kind)])
        case .record(let record):
            return .object(record.mapValues(valueNode))
        case .list(let list):
            return .array(list.map(valueNode))
        case .reference(let reference):
            return .string(reference)
        case .null:
            return .null
        case .opaque(let box):
            // Mirror `jsonEncodableObject`: an Encodable domain value hashes as
            // its fields, not as a description string.
            guard let fields = Value.decodeOpaqueRecord(box) else {
                return .string(String(describing: box))
            }
            return .object(fields.mapValues(valueNode))
        }
    }

    private static func serialize(_ node: Node) -> String {
        switch node {
        case .null:
            return "null"
        case .bool(let value):
            return value ? "true" : "false"
        case .string(let value):
            return "\"\(escape(value))\""
        case .array(let values):
            return "[" + values.map(serialize).joined(separator: ",") + "]"
        case .object(let object):
            let pairs = object.keys.sorted().map { key in
                "\"\(escape(key))\":\(serialize(object[key] ?? .null))"
            }
            return "{" + pairs.joined(separator: ",") + "}"
        }
    }

    private static func escape(_ string: String) -> String {
        var output = ""
        output.reserveCapacity(string.count)
        for scalar in string.unicodeScalars {
            switch scalar.value {
            case 0x22:
                output.append("\\\"")
            case 0x5C:
                output.append("\\\\")
            case 0x08:
                output.append("\\b")
            case 0x0C:
                output.append("\\f")
            case 0x0A:
                output.append("\\n")
            case 0x0D:
                output.append("\\r")
            case 0x09:
                output.append("\\t")
            case 0x00...0x1F:
                output.append(String(format: "\\u%04x", scalar.value))
            default:
                output.append(String(scalar))
            }
        }
        return output
    }
}
