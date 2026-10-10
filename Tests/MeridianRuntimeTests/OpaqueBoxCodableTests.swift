import Foundation
import Testing
import MeridianRuntime

@Suite("Opaque box round-trip and instance Codable")
struct OpaqueBoxCodableTests {

    private struct Payload: Hashable, Sendable, Encodable {
        let id: String
        let count: Int
    }

    private struct OpaquePayload: Hashable, Sendable {
        let id: String
    }

    @Test("an Encodable box renders as its fields in JSON payloads")
    func encodableBoxRendersAsRecord() {
        let box = AnyHashableSendable(Payload(id: "p-1", count: 2))
        let object = Value.opaque(box).jsonEncodableObject
        guard let dict = object as? [String: Any] else {
            Issue.record("expected a record, got \(object)")
            return
        }
        #expect(dict["id"] as? String == "p-1")
        #expect((dict["count"] as? NSNumber)?.intValue == 2)
    }

    @Test("a non-Encodable box keeps its description form")
    func opaqueBoxFallsBackToDescription() {
        let object = Value.opaque(AnyHashableSendable(OpaquePayload(id: "x"))).jsonEncodableObject
        #expect(object is String)
    }

    @Test("an Encodable box hashes as its fields in canonical JSON")
    func canonicalJSONUsesFields() throws {
        let box = AnyHashableSendable(Payload(id: "p-1", count: 2))
        let json = String(decoding: try CanonicalJSON.data(for: ["box": .opaque(box)]), as: UTF8.self)
        #expect(json.contains("\"id\""))
        #expect(json.contains("p-1"))
        #expect(!json.contains("AnyHashableSendable"))
    }

    @Test("dot-path traversal reaches an Encodable box's fields")
    func traversalReachesFields() {
        var state = State()
        state.bind("payload", Payload(id: "p-9", count: 1))
        #expect(state.get("payload.id") == .string("p-9"))
    }

    @Test("a non-Encodable box hashes as its description string")
    func canonicalJSONFallsBackToDescription() throws {
        let json = String(
            decoding: try CanonicalJSON.data(for: ["box": .opaque(AnyHashableSendable(OpaquePayload(id: "x")))]),
            as: UTF8.self
        )
        #expect(json.contains("OpaquePayload"))
    }

    @Test("InstanceHandle and PropertyValue round-trip through Codable")
    func instanceHandleCodable() throws {
        let handle = InstanceHandle(
            kind: "mailer_server",
            name: "primary",
            properties: [
                "host": .literal(.string("smtp.example")),
                "api_key": .envVar("MAIL_KEY"),
            ]
        )
        let data = try JSONEncoder().encode(handle)
        let decoded = try JSONDecoder().decode(InstanceHandle.self, from: data)
        #expect(decoded == handle)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("MAIL_KEY"))
        #expect(json.contains("smtp.example"))
    }
}
