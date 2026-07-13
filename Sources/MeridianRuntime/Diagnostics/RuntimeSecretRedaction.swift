import Foundation

enum RuntimeSecretRedaction {
    private static let redactionRegexes: [(NSRegularExpression, String)] = {
        let specs: [(String, String)] = [
            (#"(?i)\b(Authorization\s*:\s*Bearer\s+)[^\s,;]+"#, "$1<redacted>"),
            (#"(?i)\b(Authorization\s*:\s*)(?!Bearer\s)[^\s,;]+"#, "$1<redacted>"),
            (#"(?i)\b(Bearer\s+)[A-Za-z0-9._~+/=-]+"#, "$1<redacted>"),
            (#"(?i)\b((?:password|api[_-]?key|apiKey|secret|[A-Za-z0-9_-]*secret)\s*[=:]\s*)[^\s,;]+"#, "$1<redacted>"),
        ]
        return specs.map { (try! NSRegularExpression(pattern: $0.0), $0.1) }
    }()

    static func redact(_ raw: String) -> String {
        var text = raw
        for (regex, template) in redactionRegexes {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
        }
        return text
    }
}
