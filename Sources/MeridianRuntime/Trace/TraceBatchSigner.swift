import CryptoKit
import Foundation

public enum TraceSigningAlgorithm: String, Sendable, Codable, Equatable {
    case hmacSHA256 = "hmac-sha256"
    case ed25519 = "ed25519"
    case hashChainAnchor = "hash-chain-anchor"
}

public struct TraceBatchAnchor: Sendable, Codable, Equatable {
    public let runID: String
    public let recordCount: Int
    public let headHash: String
    public let tailHash: String
    public let anchoredAt: Date
    public let algorithm: TraceSigningAlgorithm
    public let signature: String?

    public init(
        runID: String,
        recordCount: Int,
        headHash: String,
        tailHash: String,
        anchoredAt: Date,
        algorithm: TraceSigningAlgorithm,
        signature: String? = nil
    ) {
        self.runID = runID
        self.recordCount = recordCount
        self.headHash = headHash
        self.tailHash = tailHash
        self.anchoredAt = anchoredAt
        self.algorithm = algorithm
        self.signature = signature
    }
}

public enum TraceBatchSigner {
    public static func anchor(
        records: [TraceRecord],
        runID: String,
        anchoredAt: Date,
        signingKey: SymmetricKey? = nil,
        ed25519PrivateKey: Curve25519.Signing.PrivateKey? = nil
    ) throws -> TraceBatchAnchor {
        let ordered = records
            .filter { $0.run == runID }
            .sorted(by: TraceRecordOrdering.runLocal)
        guard let first = ordered.first, let last = ordered.last else {
            throw TraceStoreError.traceStoreFailure("no records to anchor for run \(runID)")
        }
        let headHash = first.recordHash ?? first.payloadHash
        let tailHash = last.recordHash ?? last.payloadHash
        let algorithm: TraceSigningAlgorithm
        let signature: String?
        if let ed25519PrivateKey {
            algorithm = .ed25519
            let unsigned = TraceBatchAnchor(
                runID: runID,
                recordCount: ordered.count,
                headHash: headHash,
                tailHash: tailHash,
                anchoredAt: anchoredAt,
                algorithm: algorithm,
                signature: nil
            )
            signature = try sign(anchor: unsigned, privateKey: ed25519PrivateKey)
            return TraceBatchAnchor(
                runID: unsigned.runID,
                recordCount: unsigned.recordCount,
                headHash: unsigned.headHash,
                tailHash: unsigned.tailHash,
                anchoredAt: unsigned.anchoredAt,
                algorithm: algorithm,
                signature: signature
            )
        }
        if let signingKey {
            algorithm = .hmacSHA256
            let unsigned = TraceBatchAnchor(
                runID: runID,
                recordCount: ordered.count,
                headHash: headHash,
                tailHash: tailHash,
                anchoredAt: anchoredAt,
                algorithm: algorithm,
                signature: nil
            )
            signature = try sign(anchor: unsigned, key: signingKey)
            return TraceBatchAnchor(
                runID: unsigned.runID,
                recordCount: unsigned.recordCount,
                headHash: unsigned.headHash,
                tailHash: unsigned.tailHash,
                anchoredAt: unsigned.anchoredAt,
                algorithm: algorithm,
                signature: signature
            )
        }
        return TraceBatchAnchor(
            runID: runID,
            recordCount: ordered.count,
            headHash: headHash,
            tailHash: tailHash,
            anchoredAt: anchoredAt,
            algorithm: .hashChainAnchor,
            signature: nil
        )
    }

    public static func sign(anchor: TraceBatchAnchor, key: SymmetricKey) throws -> String {
        let payload = try CanonicalJSON.data(for: anchorPayload(anchor))
        let digest = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return Data(digest).map { String(format: "%02x", $0) }.joined()
    }

    public static func sign(anchor: TraceBatchAnchor, privateKey: Curve25519.Signing.PrivateKey) throws -> String {
        let payload = try CanonicalJSON.data(for: anchorPayload(anchor))
        let signature = try privateKey.signature(for: payload)
        return Data(signature).base64EncodedString()
    }

    public static func verify(anchor: TraceBatchAnchor, key: SymmetricKey) throws -> Bool {
        guard anchor.algorithm == .hmacSHA256, let signature = anchor.signature else { return false }
        let expected = try sign(anchor: unsignedAnchor(anchor), key: key)
        return constantTimeEquals(signature, expected)
    }

    public static func verify(anchor: TraceBatchAnchor, publicKey: Curve25519.Signing.PublicKey) throws -> Bool {
        guard anchor.algorithm == .ed25519, let signatureText = anchor.signature else { return false }
        guard let signatureData = Data(base64Encoded: signatureText) else { return false }
        let payload = try CanonicalJSON.data(for: anchorPayload(unsignedAnchor(anchor)))
        return publicKey.isValidSignature(signatureData, for: payload)
    }

    private static func unsignedAnchor(_ anchor: TraceBatchAnchor) -> TraceBatchAnchor {
        TraceBatchAnchor(
            runID: anchor.runID,
            recordCount: anchor.recordCount,
            headHash: anchor.headHash,
            tailHash: anchor.tailHash,
            anchoredAt: anchor.anchoredAt,
            algorithm: anchor.algorithm,
            signature: nil
        )
    }

    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs.utf8, rhs.utf8) {
            difference |= left ^ right
        }
        return difference == 0
    }

    private static func anchorPayload(_ anchor: TraceBatchAnchor) -> [String: Value] {
        [
            "runID": .string(anchor.runID),
            "recordCount": .number(Decimal(anchor.recordCount)),
            "headHash": .string(anchor.headHash),
            "tailHash": .string(anchor.tailHash),
            "anchoredAt": .string(ISO8601DateFormatter.meridianFormatter.string(from: anchor.anchoredAt)),
            "algorithm": .string(anchor.algorithm.rawValue)
        ]
    }
}
