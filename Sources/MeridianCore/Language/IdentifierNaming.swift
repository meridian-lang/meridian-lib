import Foundation

/// Single source of truth for converting natural-language phrases into Swift
/// identifiers. The codebase needs a handful of *behaviorally distinct* naming
/// conventions (lower-camel vs Pascal, case-preserving vs lower-rest, which
/// separators split words); this collapses the byte-identical copies of each
/// into one parameterised `convert` plus thin named wrappers, so the logic
/// lives once. Families that genuinely diverge (hyphen-splitting, bespoke
/// fallbacks) keep their own implementations — never cross-merge them.
public enum IdentifierNaming {

    enum Casing { case camel, pascal }

    /// The word-separator sets the convergent families use.
    static let spaceOnly: Set<Character> = [" "]
    static let spaceAndUnderscore: Set<Character> = [" ", "_"]
    static let spaceUnderscoreHyphen: Set<Character> = [" ", "_", "-"]

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

    /// lowerCamelCase, splitting on space/underscore/hyphen. Used for surfaces
    /// that historically accepted hyphenated field-ish names as one family.
    static func lowerCamelSplittingHyphen(_ raw: String) -> String {
        convert(raw, separators: spaceUnderscoreHyphen, casing: .camel, lowercaseInputFirst: true)
    }

    /// Method-style lowerCamelCase from a tool or trigger phrase. Splits on any
    /// non-alphanumeric separator, filters stopwords, and optionally limits the
    /// number of retained tokens.
    static func methodize(_ raw: String, stopwords: Set<String> = [], limit: Int? = nil, fallback: String? = nil) -> String {
        let tokens = raw.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopwords.contains($0) }
        let retained = limit.map { Array(tokens.prefix($0)) } ?? tokens
        guard let first = retained.first else { return fallback ?? raw }
        return first + retained.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// camelCase preserving each word's existing case, splitting on
    /// space/underscore/hyphen (`"order ID"` → `"orderID"`,
    /// `"webhook-transform"` → `"webhookTransform"`). Bind/result naming.
    static func camelPreservingCase(_ raw: String) -> String {
        convert(raw, separators: spaceUnderscoreHyphen, casing: .camel)
    }

    /// PascalCase, splitting on spaces only, lower-casing each word's tail
    /// (`"pull request"` → `"PullRequest"`). Kind/type naming from prose.
    static func pascalCaseFromSpaces(_ raw: String) -> String {
        convert(raw, separators: spaceOnly, casing: .pascal, lowercaseWordRest: true)
    }

    /// PascalCase, splitting on space/underscore/hyphen, lower-casing each
    /// word's tail (`"validation result"` → `"ValidationResult"`,
    /// `"webhook-transform"` → `"WebhookTransform"`). Domain/type naming.
    ///
    /// `Protocol` and `Type` get a `Value` suffix appended (`"protocol"` →
    /// `"ProtocolValue"`, not bare `"Protocol"`). Both read as perfectly
    /// ordinary identifiers everywhere *except* as a nested type member,
    /// where Swift's postfix `X.Protocol` / `X.Type` syntax for a
    /// protocol-existential/instance metatype takes over the parse —
    /// "type member must not be named 'Protocol'/'Type'" is a hard compile
    /// error there. Every caller of `pascalCase` here derives a domain
    /// kind's generated Swift struct name, which is always emitted as
    /// exactly that kind of nested type member (`Namespace.Protocol`), so a
    /// vocabulary noun literally named "protocol" or "type" hits this for
    /// real, not hypothetically (shipped broken in `corpora/clinical`, which
    /// declares `A protocol is a kind of artifact.` — see
    /// IMPLEMENTATION_LOG.md).
    static func pascalCase(_ raw: String) -> String {
        let result = convert(raw, separators: spaceUnderscoreHyphen, casing: .pascal, lowercaseWordRest: true)
        return (result == "Protocol" || result == "Type") ? result + "Value" : result
    }

    /// PascalCase, splitting on space/underscore/hyphen while preserving each
    /// word's existing tail case. Used for synthetic lowering helper names where
    /// historical output preserved author casing.
    static func pascalCaseSplittingHyphenPreservingCase(_ raw: String) -> String {
        convert(raw, separators: spaceUnderscoreHyphen, casing: .pascal)
    }

    /// PascalCase from an arbitrary file stem or generated namespace. Splits on
    /// non-alphanumeric boundaries and prefixes `_` when the result would start
    /// with a digit.
    public static func swiftTypeNameFromStem(_ raw: String, fallback: String = "Skill") -> String {
        let parts = raw.split(whereSeparator: { !($0.isLetter || $0.isNumber) })
        let joined = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
        guard let first = joined.first else { return fallback }
        return first.isNumber ? "_" + joined : joined
    }

    /// Swift reserved words that collide with a bare local-variable/parameter
    /// identifier (`let protocol = …` is a parse error, not a warning). This
    /// mirrors `DomainEmitter`'s own private keyword set (kept separate
    /// rather than merged — that one escapes *enum case* identifiers via
    /// backticks, a narrower and already-battle-tested call site; changing
    /// its shared list risks an unrelated regression there for no benefit
    /// here). Callers needing a *local variable* name that's guaranteed to be
    /// valid Swift (`SwiftEmitter.emitInvoke`'s `let <resultBinding> = …`)
    /// use `escapeIfReservedIdentifier` below instead.
    static let reservedIdentifiers: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
        "func", "import", "init", "inout", "internal", "let", "open", "operator",
        "private", "precedencegroup", "protocol", "public", "rethrows", "static",
        "struct", "subscript", "typealias", "var", "break", "case", "catch",
        "continue", "default", "defer", "do", "else", "fallthrough", "for",
        "guard", "if", "in", "repeat", "return", "throw", "switch", "where",
        "while", "as", "Any", "false", "is", "nil", "self", "Self", "super",
        "throws", "true", "try",
    ]

    /// Backtick-escape `identifier` when it's a Swift reserved word, so it's
    /// safe to emit as a bare `let`/parameter/local-variable name rather than
    /// a string-literal state key. Natural-language bind names are
    /// user-chosen nouns (`bind protocol = …`, `bind type = …`) with no
    /// reason to avoid an English word that happens to also be a Swift
    /// keyword — the compiler must handle it, not the domain author (shipped
    /// broken as `let protocol = try await runtime.invoke(…)` in
    /// `corpora/clinical/protocol_render`; see IMPLEMENTATION_LOG.md).
    static func escapeIfReservedIdentifier(_ identifier: String) -> String {
        reservedIdentifiers.contains(identifier) ? "`\(identifier)`" : identifier
    }

    /// Reverse of `pascalCase`/`pascalCaseFromSpaces`: insert a space before
    /// every internal uppercase letter that follows a lowercase/digit
    /// (`"MedicationOrder"` → `"Medication Order"`, `"SLO"` stays `"SLO"`).
    /// Used to recover word boundaries from a `KindRef.name` (which is always
    /// stored as a concatenated Swift type name) before token/stem matching —
    /// `WordStemmer.tokenize` only splits on non-alphanumerics, so a
    /// multi-word kind name would otherwise collapse into a single token that
    /// can never intersect with its own space-separated prose form.
    public static func decamelize(_ raw: String) -> String {
        var out = ""
        var previous: Character?
        for ch in raw {
            if let prev = previous, ch.isUppercase, (prev.isLowercase || prev.isNumber) {
                out.append(" ")
            }
            out.append(ch)
            previous = ch
        }
        return out
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
