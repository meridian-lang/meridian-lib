import Foundation
import MeridianRuntime

public enum JSONLReplay {
    public static func eventKinds(from jsonl: String) -> [String] {
        jsonl.split(separator: "\n").compactMap { line in
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return object["kind"] as? String
        }
    }

    public static func canonicalize(_ jsonl: String) -> [String] {
        jsonl.split(separator: "\n").map(String.init).sorted()
    }
}
