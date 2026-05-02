import Foundation

// MARK: - EventAssertions
//
// Helpers for comparing event JSONL streams in tests.
// Normalization replaces non-deterministic fields (ts, duration_ms, run_id)
// with fixed sentinels so diffs are purely structural.

public enum EventAssertions {

    // MARK: - Normalize

    /// Normalize a JSONL event stream for deterministic comparison.
    ///
    /// Replacements:
    ///   "ts"          → "<ts>"
    ///   "duration_ms" → 0   (anywhere in the tree)
    ///   "run_id"      → the fixed sentinel "<run>"
    ///   "parent_run_id" → "<run>"
    public static func normalize(_ jsonl: String, fixedRunID: String = "<run>") -> [String] {
        jsonl
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { normalizeEvent(String($0), fixedRunID: fixedRunID) }
    }

    // MARK: - Diff

    /// Return a human-readable diff between two normalized JSONL sequences.
    /// Returns nil if they match.
    public static func diff(
        actual: [String],
        expected: [String]
    ) -> String? {
        if actual == expected { return nil }

        var lines: [String] = ["Event stream mismatch:"]
        let maxCount = max(actual.count, expected.count)
        for i in 0..<maxCount {
            let a = i < actual.count ? actual[i] : "<missing>"
            let e = i < expected.count ? expected[i] : "<missing>"
            if a == e {
                lines.append("  [\(i+1)] ✓ \(a)")
            } else {
                lines.append("  [\(i+1)] ✗ actual:   \(a)")
                lines.append("         expected: \(e)")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - JSONL loading

    /// Load a JSONL file and return its lines.
    public static func loadJSONL(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Private

    private static func normalizeEvent(_ line: String, fixedRunID: String) -> String {
        guard var dict = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
            return line
        }
        dict["ts"] = "<ts>"
        dict["run_id"] = fixedRunID
        if dict["parent_run_id"] != nil { dict["parent_run_id"] = fixedRunID }
        normalizeDurations(&dict)

        guard let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.sortedKeys]
        ), let str = String(data: data, encoding: .utf8) else {
            return line
        }
        return str
    }

    private static func normalizeDurations(_ dict: inout [String: Any]) {
        if let payload = dict["payload"] as? [String: Any] {
            var p = payload
            if p["duration_ms"] != nil { p["duration_ms"] = 0 }
            normalizeDurations(&p)
            dict["payload"] = p
        }
        if dict["duration_ms"] != nil { dict["duration_ms"] = 0 }
    }
}
