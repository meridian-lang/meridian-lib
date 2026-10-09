import CryptoKit
import Foundation

/// Canonical SHA-256 over a primitive's semantic fields. Position- and
/// annotation-independent: `sourceRange`, `sourceFile` and `stableStepPath`
/// are stripped before hashing so identity does not depend on where the
/// primitive sits or on the annotate pass itself.
enum IRFingerprint {
    /// Keys carrying provenance rather than semantics. `sourceRange`/`sourceFile`
    /// record where the primitive was authored; `stableStepPath` is the annotate
    /// pass's own output (hashing it would make identity self-referential).
    static let strippedKeys: Set<String> = ["sourceRange", "sourceFile", "stableStepPath"]

    static func sha256(of primitive: IRPrimitive) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(primitive)
        let object = try JSONSerialization.jsonObject(with: encoded, options: [.fragmentsAllowed])
        let canonical = try JSONSerialization.data(
            withJSONObject: strippingProvenance(object),
            options: [.sortedKeys]
        )
        return SHA256.hash(data: canonical).map { String(format: "%02x", $0) }.joined()
    }

    private static func strippingProvenance(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return object.reduce(into: [String: Any]()) { result, entry in
                guard !strippedKeys.contains(entry.key) else { return }
                result[entry.key] = strippingProvenance(entry.value)
            }
        }
        if let array = value as? [Any] {
            return array.map(strippingProvenance)
        }
        return value
    }
}
