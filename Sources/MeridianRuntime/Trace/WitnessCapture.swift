import Foundation

public enum WitnessCaptureMode: String, Sendable, Codable, Equatable {
    case full
    case redacted
    case hashOnly
    case omitted

    public static let defaultPIIKeys: [String] = [
        "email", "phone", "ssn", "password", "token", "secret",
        "api_key", "apiKey", "authorization", "credit_card", "creditCard"
    ]
}

public struct WitnessEnvelope: Sendable, Equatable {
    public let failingCount: Int
    public let witnessHash: String
    public let subjectKey: String?
    public let body: [String: Value]?

    public init(
        failingCount: Int,
        witnessHash: String,
        subjectKey: String? = nil,
        body: [String: Value]? = nil
    ) {
        self.failingCount = failingCount
        self.witnessHash = witnessHash
        self.subjectKey = subjectKey
        self.body = body
    }

    public func encodedJSON() throws -> String {
        var object: [String: Value] = [
            "failingCount": .number(Decimal(failingCount)),
            "witnessHash": .string(witnessHash)
        ]
        if let subjectKey {
            object["subjectKey"] = .string(subjectKey)
        }
        if let body {
            object["body"] = .record(body)
        }
        return String(decoding: try CanonicalJSON.data(for: object), as: UTF8.self)
    }
}

public enum WitnessCapture {
    public static func buildEnvelope(
        body: [String: Value],
        mode: WitnessCaptureMode,
        redactedFields: [String] = WitnessCaptureMode.defaultPIIKeys,
        subjectKey: String? = nil,
        failingCount: Int = 1
    ) throws -> WitnessEnvelope {
        let witnessHash = try CanonicalJSON.sha256Hex(for: body)
        switch mode {
        case .full:
            return WitnessEnvelope(
                failingCount: failingCount,
                witnessHash: witnessHash,
                subjectKey: subjectKey,
                body: body
            )
        case .redacted:
            let redactedBody = redactRecord(body, keys: Set(redactedFields))
            return WitnessEnvelope(
                failingCount: failingCount,
                witnessHash: witnessHash,
                subjectKey: subjectKey,
                body: redactedBody
            )
        case .hashOnly:
            return WitnessEnvelope(
                failingCount: failingCount,
                witnessHash: witnessHash,
                subjectKey: subjectKey,
                body: nil
            )
        case .omitted:
            return WitnessEnvelope(
                failingCount: failingCount,
                witnessHash: witnessHash,
                subjectKey: nil,
                body: nil
            )
        }
    }

    public static func applyCapturePolicy(
        _ policy: TraceCapturePolicy,
        body: [String: Value],
        subjectKey: String? = nil,
        failingCount: Int = 1
    ) throws -> WitnessEnvelope {
        switch policy {
        case .full:
            return try buildEnvelope(body: body, mode: .full, subjectKey: subjectKey, failingCount: failingCount)
        case .hashOnly:
            return try buildEnvelope(body: body, mode: .hashOnly, subjectKey: subjectKey, failingCount: failingCount)
        case .redacted(let keys):
            return try buildEnvelope(
                body: body,
                mode: .redacted,
                redactedFields: keys.isEmpty ? WitnessCaptureMode.defaultPIIKeys : keys,
                subjectKey: subjectKey,
                failingCount: failingCount
            )
        case .omitted:
            return try buildEnvelope(body: body, mode: .omitted, failingCount: failingCount)
        }
    }

    private static func redactRecord(_ dict: [String: Value], keys: Set<String>) -> [String: Value] {
        dict.reduce(into: [:]) { acc, pair in
            acc[pair.key] = keys.contains(pair.key)
                ? .string("<redacted>")
                : redactValue(pair.value, keys: keys)
        }
    }

    private static func redactValue(_ value: Value, keys: Set<String>) -> Value {
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
