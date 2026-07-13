import Foundation

public struct OTLPAttribute: Codable, Sendable, Equatable {
    public let key: String
    public let value: OTLPAnyValue

    public init(key: String, value: OTLPAnyValue) {
        self.key = key
        self.value = value
    }
}

public struct OTLPAnyValue: Codable, Sendable, Equatable {
    public let stringValue: String?
    public let intValue: String?
    public let boolValue: Bool?
    public let doubleValue: Double?

    public static func string(_ value: String) -> OTLPAnyValue {
        OTLPAnyValue(stringValue: value, intValue: nil, boolValue: nil, doubleValue: nil)
    }

    public static func int(_ value: Int) -> OTLPAnyValue {
        OTLPAnyValue(stringValue: nil, intValue: String(value), boolValue: nil, doubleValue: nil)
    }

    public static func bool(_ value: Bool) -> OTLPAnyValue {
        OTLPAnyValue(stringValue: nil, intValue: nil, boolValue: value, doubleValue: nil)
    }

    public static func double(_ value: Double) -> OTLPAnyValue {
        OTLPAnyValue(stringValue: nil, intValue: nil, boolValue: nil, doubleValue: value)
    }
}

public struct OTLPSpan: Codable, Sendable, Equatable {
    public let traceId: String
    public let spanId: String
    public let name: String
    public let kind: Int
    public let startTimeUnixNano: String
    public let endTimeUnixNano: String
    public let attributes: [OTLPAttribute]
    public let status: OTLPStatus

    public init(
        traceId: String,
        spanId: String,
        name: String,
        kind: Int = 1,
        startTimeUnixNano: String,
        endTimeUnixNano: String,
        attributes: [OTLPAttribute],
        status: OTLPStatus
    ) {
        self.traceId = traceId
        self.spanId = spanId
        self.name = name
        self.kind = kind
        self.startTimeUnixNano = startTimeUnixNano
        self.endTimeUnixNano = endTimeUnixNano
        self.attributes = attributes
        self.status = status
    }
}

public struct OTLPStatus: Codable, Sendable, Equatable {
    public let code: Int
    public let message: String?

    public init(code: Int, message: String? = nil) {
        self.code = code
        self.message = message
    }
}

public struct OTLPScopeSpans: Codable, Sendable, Equatable {
    public let scope: OTLPInstrumentationScope
    public let spans: [OTLPSpan]

    public init(scope: OTLPInstrumentationScope, spans: [OTLPSpan]) {
        self.scope = scope
        self.spans = spans
    }
}

public struct OTLPInstrumentationScope: Codable, Sendable, Equatable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

public struct OTLPResource: Codable, Sendable, Equatable {
    public let attributes: [OTLPAttribute]

    public init(attributes: [OTLPAttribute]) {
        self.attributes = attributes
    }
}

public struct OTLPResourceSpans: Codable, Sendable, Equatable {
    public let resource: OTLPResource
    public let scopeSpans: [OTLPScopeSpans]

    public init(resource: OTLPResource, scopeSpans: [OTLPScopeSpans]) {
        self.resource = resource
        self.scopeSpans = scopeSpans
    }
}

public struct OTLPExportRequest: Codable, Sendable, Equatable {
    public let resourceSpans: [OTLPResourceSpans]

    public init(resourceSpans: [OTLPResourceSpans]) {
        self.resourceSpans = resourceSpans
    }
}

public enum OTLPTraceExporter {
    public static let contentType = "application/json"
    public static let tracesEndpointPath = "/v1/traces"

    public static func exportRequest(
        for records: [TraceRecord],
        serviceName: String = "meridian-runtime"
    ) -> OTLPExportRequest {
        let spans = records.map(span(for:))
        return OTLPExportRequest(resourceSpans: [
            OTLPResourceSpans(
                resource: OTLPResource(attributes: [
                    OTLPAttribute(key: "service.name", value: .string(serviceName))
                ]),
                scopeSpans: [
                    OTLPScopeSpans(
                        scope: OTLPInstrumentationScope(name: "meridian.trace", version: "1"),
                        spans: spans
                    )
                ]
            )
        ])
    }

    public static func span(for record: TraceRecord) -> OTLPSpan {
        let startNanos = unixNanos(record.at)
        let attributes = attributes(for: record)
        return OTLPSpan(
            traceId: paddedHex(from: record.run, length: 32),
            spanId: paddedHex(from: record.id, length: 16),
            name: record.tag.rawValue,
            startTimeUnixNano: startNanos,
            endTimeUnixNano: startNanos,
            attributes: attributes,
            status: status(for: record)
        )
    }

    private static func attributes(for record: TraceRecord) -> [OTLPAttribute] {
        var attrs: [OTLPAttribute] = [
            OTLPAttribute(key: "meridian.id", value: .string(record.id)),
            OTLPAttribute(key: "meridian.run", value: .string(record.run)),
            OTLPAttribute(key: "meridian.step", value: .string(record.step)),
            OTLPAttribute(key: "meridian.skill_name", value: .string(record.skillName)),
            OTLPAttribute(key: "meridian.skill_version_hash", value: .string(record.skillVersionHash)),
            OTLPAttribute(key: "meridian.ingest_order", value: .int(record.ingestOrder)),
            OTLPAttribute(key: "meridian.payload_hash", value: .string(record.payloadHash)),
            OTLPAttribute(key: "meridian.schema_version", value: .int(record.schemaVersion))
        ]
        if let subject = record.subject {
            attrs.append(OTLPAttribute(key: "meridian.subject", value: .string(subject)))
        }
        if let subjectKey = record.subjectKey {
            attrs.append(OTLPAttribute(key: "meridian.subject_key", value: .string(subjectKey)))
        }
        if let outcome = record.outcome {
            attrs.append(OTLPAttribute(key: "meridian.outcome", value: .string(outcome.rawValue)))
        }
        if let witness = record.witness {
            attrs.append(OTLPAttribute(key: "meridian.witness", value: .string(witness)))
        }
        if let legacyKind = record.legacyKind {
            attrs.append(OTLPAttribute(key: "meridian.legacy_kind", value: .string(legacyKind)))
        }
        if let payload = record.payload {
            for (key, value) in payload.sorted(by: { $0.key < $1.key }) {
                attrs.append(OTLPAttribute(key: "meridian.payload.\(key)", value: .string(value.description)))
            }
        }
        return attrs
    }

    private static func status(for record: TraceRecord) -> OTLPStatus {
        switch record.outcome {
        case .success:
            return OTLPStatus(code: 1)
        case .failure:
            return OTLPStatus(code: 2, message: record.operationalDetail)
        case .indeterminate, .none:
            return OTLPStatus(code: 0)
        }
    }

    private static func unixNanos(_ date: Date) -> String {
        let seconds = Int64(date.timeIntervalSince1970)
        return String(seconds * 1_000_000_000)
    }

    private static func paddedHex(from source: String, length: Int) -> String {
        let digest = source.utf8.reduce(into: [UInt8]()) { acc, byte in
            acc.append(byte)
        }
        var hex = digest.map { String(format: "%02x", $0) }.joined()
        if hex.count < length {
            hex += String(repeating: "0", count: length - hex.count)
        }
        return String(hex.prefix(length))
    }
}

public struct OTLPHTTPExporter: Sendable {
    private let endpoint: URL
    private let session: URLSession
    private let serviceName: String
    private let encoder: JSONEncoder

    public init(endpoint: URL, serviceName: String = "meridian-runtime", session: URLSession = .shared) {
        self.endpoint = endpoint
        self.serviceName = serviceName
        self.session = session
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    public func export(records: [TraceRecord]) async throws {
        let requestBody = OTLPTraceExporter.exportRequest(for: records, serviceName: serviceName)
        let data = try encoder.encode(requestBody)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(OTLPTraceExporter.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw TraceStoreError.traceStoreFailure("OTLP export failed with status \(status)")
        }
    }
}
