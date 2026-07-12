import Foundation

public actor TraceIDGenerator {
    private let now: @Sendable () -> Date
    private let randomBytes: @Sendable (Int) -> [UInt8]
    private var lastTimestampMS: UInt64?
    private var lastEntropy: [UInt8] = Array(repeating: 0, count: 10)

    public init(
        now: @escaping @Sendable () -> Date = { Date() },
        randomBytes: @escaping @Sendable (Int) -> [UInt8] = TraceIDGenerator.secureRandomBytes
    ) {
        self.now = now
        self.randomBytes = randomBytes
    }

    public func nextID() -> String {
        nextID(at: now())
    }

    public func nextID(at date: Date) -> String {
        let rawTimestampMS = UInt64((date.timeIntervalSince1970 * 1_000).rounded(.down))
        var timestampMS = rawTimestampMS
        if let lastTimestampMS, timestampMS < lastTimestampMS {
            timestampMS = lastTimestampMS
        }

        var entropy: [UInt8]
        if timestampMS == lastTimestampMS {
            entropy = TraceIDGenerator.increment(lastEntropy)
            if entropy.allSatisfy({ $0 == 0 }) {
                timestampMS += 1
                entropy = randomBytes(10)
            }
        } else {
            entropy = randomBytes(10)
        }

        lastTimestampMS = timestampMS
        lastEntropy = entropy

        return TraceIDGenerator.encode(timestampMS: timestampMS, entropy: entropy)
    }

    public static func secureRandomBytes(_ count: Int) -> [UInt8] {
        var generator = SystemRandomNumberGenerator()
        return (0..<count).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) }
    }

    private static func increment(_ bytes: [UInt8]) -> [UInt8] {
        var output = bytes
        for index in output.indices.reversed() {
            if output[index] == UInt8.max {
                output[index] = 0
                continue
            }
            output[index] += 1
            return output
        }
        return output
    }

    private static func encode(timestampMS: UInt64, entropy: [UInt8]) -> String {
        let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        var bytes = [UInt8](repeating: 0, count: 16)
        bytes[0] = UInt8((timestampMS >> 40) & 0xFF)
        bytes[1] = UInt8((timestampMS >> 32) & 0xFF)
        bytes[2] = UInt8((timestampMS >> 24) & 0xFF)
        bytes[3] = UInt8((timestampMS >> 16) & 0xFF)
        bytes[4] = UInt8((timestampMS >> 8) & 0xFF)
        bytes[5] = UInt8(timestampMS & 0xFF)
        for (offset, byte) in entropy.enumerated() where offset < 10 {
            bytes[6 + offset] = byte
        }

        var bits: [UInt8] = [0, 0]
        bits.reserveCapacity(130)
        for byte in bytes {
            for shift in stride(from: 7, through: 0, by: -1) {
                bits.append((byte >> shift) & 1)
            }
        }

        var encoded = String()
        encoded.reserveCapacity(26)
        for index in stride(from: 0, to: bits.count, by: 5) {
            var value = 0
            for bitOffset in 0..<5 {
                value = (value << 1) | Int(bits[index + bitOffset])
            }
            encoded.append(alphabet[value])
        }
        return encoded
    }
}
