/// Single source of truth for converting natural-language phrases into Swift
/// identifiers. The codebase needs a handful of *behaviorally distinct* naming
/// conventions (lower-camel vs Pascal, case-preserving vs lower-rest, which
/// separators split words); this collapses the byte-identical copies of each
/// into one parameterised `convert` plus thin named wrappers, so the logic
/// lives once. Families that genuinely diverge (hyphen-splitting, bespoke
/// fallbacks) keep their own implementations — never cross-merge them.
enum IdentifierNaming {

    enum Casing { case camel, pascal }

    /// The two word-separator sets the convergent families use. Families that
    /// also split on `-` are intentionally separate (they keep their own code).
    static let spaceOnly: Set<Character> = [" "]
    static let spaceAndUnderscore: Set<Character> = [" ", "_"]

    /// Convert `raw` to an identifier.
    /// - casing: `.camel` keeps the first word verbatim; `.pascal` upper-cases
    ///   the first letter of every word.
    /// - lowercaseInputFirst: lower-case the whole input before splitting
    ///   (lower-camel family); the empty/all-separator fallback then returns the
    ///   lower-cased input.
    /// - lowercaseWordRest: lower-case each word's tail (Pascal "lower-rest"
    ///   family); when false the tail is preserved verbatim.
    static func convert(
        _ raw: String,
        separators: Set<Character>,
        casing: Casing,
        lowercaseInputFirst: Bool = false,
        lowercaseWordRest: Bool = false
    ) -> String {
        let source = lowercaseInputFirst ? raw.lowercased() : raw
        let words = source.split(whereSeparator: { separators.contains($0) }).map(String.init)
        guard !words.isEmpty else {
            // camel families fall back to the (possibly lower-cased) input;
            // Pascal families produce an empty identifier.
            return casing == .camel ? source : ""
        }
        var out = ""
        for (i, word) in words.enumerated() {
            if i == 0 && casing == .camel {
                out += word
                continue
            }
            let tail = lowercaseWordRest ? word.dropFirst().lowercased() : String(word.dropFirst())
            out += word.prefix(1).uppercased() + tail
        }
        return out
    }

    // MARK: - Named families

    /// lowerCamelCase, splitting on space/underscore, lower-casing the input
    /// first (`"Mailer Server"` → `"mailerServer"`). Phrase-parameter naming.
    static func lowerCamel(_ raw: String) -> String {
        convert(raw, separators: spaceAndUnderscore, casing: .camel, lowercaseInputFirst: true)
    }

    /// camelCase preserving each word's existing case, splitting on
    /// space/underscore (`"order ID"` → `"orderID"`). Bind/result naming.
    static func camelPreservingCase(_ raw: String) -> String {
        convert(raw, separators: spaceAndUnderscore, casing: .camel)
    }

    /// PascalCase, splitting on spaces only, lower-casing each word's tail
    /// (`"pull request"` → `"PullRequest"`). Kind/type naming from prose.
    static func pascalCaseFromSpaces(_ raw: String) -> String {
        convert(raw, separators: spaceOnly, casing: .pascal, lowercaseWordRest: true)
    }

    /// PascalCase, splitting on space/underscore, lower-casing each word's tail
    /// (`"validation result"` → `"ValidationResult"`). Domain/type naming.
    static func pascalCase(_ raw: String) -> String {
        convert(raw, separators: spaceAndUnderscore, casing: .pascal, lowercaseWordRest: true)
    }
}

/// Escape a string for embedding inside a Swift double-quoted string literal.
/// The full set (`\ " \n \r \t`) is the single source for every site that
/// emits Swift source: `SwiftEmitter`, the `RuntimeExecutor`/`SwiftPMPackageRunner`
/// test drivers, etc. Drivers previously omitted `\r`/`\t`; routing them here
/// makes the escaping uniform (a tab or CR in a stub value no longer breaks the
/// generated driver).
func escapeSwiftStringLiteral(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
     .replacingOccurrences(of: "\n", with: "\\n")
     .replacingOccurrences(of: "\r", with: "\\r")
     .replacingOccurrences(of: "\t", with: "\\t")
}
