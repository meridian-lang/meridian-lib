import Foundation
import Parsing
import PegexBuilder

enum POCValue: Equatable {
    case number(Double)
    case string(String)
    case word(String)
}

indirect enum POCNode: Equatable {
    case comparison(lhs: String, op: String, rhs: POCValue)
    case and(POCNode, POCNode)
    case or(POCNode, POCNode)
    case not(POCNode)
    case either(POCNode, POCNode)
    case description(quantifier: String, adjectives: [String], kind: String, whose: [POCNode])
    case symbolicDescription(quantifier: String, adjectives: [String], kind: String, relation: String, object: String)
    case sentinel(String)
}

struct POCParseError: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

struct MockSymbols {
    let kinds: Set<String>
    let adjectives: Set<String>
    let verbs: Set<String>

    static let brain = MockSymbols(
        kinds: ["page", "deal", "entity"],
        adjectives: ["stale", "active", "urgent", "orphaned"],
        verbs: ["mentions", "owns", "links"]
    )
}

struct POCGrammar {
    let symbols: MockSymbols
    let comparators: [(marker: String, op: String)] = [
        ("is", "=="),
        ("is not", "!="),
        ("equals", "=="),
        ("is more than", ">"),
        ("is less than", "<"),
        ("is at least", ">="),
        ("is at most", "<="),
        ("contains", "contains"),
    ]
    let quantifiers = ["every", "all", "any", "some", "no"]
    let adjectives = ["stale", "active", "urgent", "orphaned", "old"]

    init(symbols: MockSymbols = .brain) {
        self.symbols = symbols
    }

    var expressionParser: AnyParser<Substring, POCNode> {
        let atom = AnyParser<Substring, POCNode> { input in
            if let either = try? parseEither(&input) {
                return either
            }
            return try parseComparison(&input)
        }

        return PrecedenceGroup<Substring, POCNode>(atom: atom) {
            AtomLevel { atom }
            InfixLeftLevel(precedence: 1, WhitespaceKeyword(word: "or")) { (lhs: POCNode, rhs: POCNode) in
                .or(lhs, rhs)
            }
            InfixLeftLevel(precedence: 2, WhitespaceKeyword(word: "and")) { (lhs: POCNode, rhs: POCNode) in
                .and(lhs, rhs)
            }
            PrefixLevel(precedence: 3, WhitespaceKeyword(word: "not")) { (node: POCNode) in
                .not(node)
            }
        }
        .eraseToAnyParser()
    }

    func parseExpression(_ text: String) throws -> POCNode {
        var input = text[...]
        let node = try expressionParser.parse(&input)
        skipWhitespace(&input)
        guard input.isEmpty else {
            throw POCParseError(message: "unconsumed input: \(input)")
        }
        return node
    }

    func parseDescription(_ text: String) throws -> POCNode {
        var input = text[...]
        skipWhitespace(&input)
        guard let quantifier = consumeAnyKeyword(&input, quantifiers) else {
            throw POCParseError(message: "expected a quantifier")
        }

        var parsedAdjectives: [String] = []
        while let adjective = consumeAnyKeyword(&input, adjectives), nextTokenStartsWord(input) {
            parsedAdjectives.append(adjective)
        }

        skipWhitespace(&input)
        guard let kind = scanWord(&input) else {
            throw POCParseError(message: "expected a kind noun")
        }

        var whose: [POCNode] = []
        if keywordAhead(input, "whose") {
            _ = consumeKeyword(&input, "whose")
            whose.append(try parseComparison(&input))
            while keywordAhead(input, "and") {
                _ = consumeKeyword(&input, "and")
                whose.append(try parseComparison(&input))
            }
        }

        skipWhitespace(&input)
        guard input.isEmpty else {
            throw POCParseError(message: "unconsumed description tail: \(input)")
        }
        return .description(
            quantifier: quantifier,
            adjectives: parsedAdjectives,
            kind: kind,
            whose: whose
        )
    }

    func parseSymbolicDescription(_ text: String) throws -> POCNode {
        var input = text[...]
        skipWhitespace(&input)
        guard let quantifier = consumeAnyKeyword(&input, quantifiers) else {
            throw POCParseError(message: "expected a quantifier")
        }

        var parsedAdjectives: [String] = []
        while let adjective = consumeAnyKeyword(&input, symbols.adjectives.sorted()), nextTokenStartsWord(input) {
            parsedAdjectives.append(adjective)
        }

        skipWhitespace(&input)
        guard let kind = scanWord(&input), symbols.kinds.contains(kind) else {
            throw POCParseError(message: "expected a declared kind")
        }
        guard consumeKeyword(&input, "that") else {
            throw POCParseError(message: "expected a relation clause")
        }
        skipWhitespace(&input)
        guard let verb = scanWord(&input), symbols.verbs.contains(verb) else {
            throw POCParseError(message: "expected a declared verb")
        }
        skipWhitespace(&input)
        guard let object = scanWord(&input), symbols.kinds.contains(object) else {
            throw POCParseError(message: "expected a declared object kind")
        }

        skipWhitespace(&input)
        guard input.isEmpty else {
            throw POCParseError(message: "unconsumed symbolic description tail: \(input)")
        }
        return .symbolicDescription(
            quantifier: quantifier,
            adjectives: parsedAdjectives,
            kind: kind,
            relation: verb,
            object: object
        )
    }

    func parseSentinelAtom(_ text: String) throws -> POCNode {
        var input = text[...]
        skipWhitespace(&input)
        guard input.first == "\u{E000}" || input.first == "\u{E001}" else {
            throw POCParseError(message: "expected a private-use sentinel")
        }
        let sentinel = String(input)
        input = input[input.endIndex...]
        return .sentinel(sentinel)
    }

    func parseComparison(_ input: inout Substring) throws -> POCNode {
        skipWhitespace(&input)
        let lhs = try scanOperand(&input)
        let op = try parseComparator(&input)
        let rhs = try parseValue(&input)
        return .comparison(lhs: lhs, op: op, rhs: rhs)
    }

    private func parseEither(_ input: inout Substring) throws -> POCNode {
        var copy = input
        guard consumeKeyword(&copy, "either") else {
            throw POCParseError(message: "expected either")
        }
        let lhs = try parseComparison(&copy)
        guard consumeKeyword(&copy, "or") else {
            throw POCParseError(message: "expected or")
        }
        let rhs = try parseComparison(&copy)
        input = copy
        return .either(lhs, rhs)
    }

    private func parseComparator(_ input: inout Substring) throws -> String {
        for entry in longestFirst(comparators) {
            var copy = input
            if consumeKeyword(&copy, entry.marker) {
                input = copy
                return entry.op
            }
        }
        throw POCParseError(message: "expected a comparator")
    }

    private func parseValue(_ input: inout Substring) throws -> POCValue {
        skipWhitespace(&input)
        if input.first == "\"" {
            return try .string(StringLiteral<Substring>(quote: "\"").parse(&input))
        }

        var probe = input
        var number = ""
        while let character = probe.first, character.isNumber || character == "." {
            number.append(character)
            probe = probe.dropFirst()
        }
        if let parsed = Double(number), !number.isEmpty {
            input = probe
            return .number(parsed)
        }

        if let word = scanWord(&input) {
            return .word(word)
        }
        throw POCParseError(message: "expected a value")
    }

    private func scanOperand(_ input: inout Substring) throws -> String {
        var words: [String] = []
        while true {
            skipWhitespace(&input)
            if comparators.contains(where: { keywordAhead(input, $0.marker) }) {
                break
            }
            guard let word = scanWord(&input) else {
                break
            }
            words.append(word)
        }
        guard !words.isEmpty else {
            throw POCParseError(message: "expected an operand")
        }
        return words.joined(separator: " ")
    }

    private func consumeAnyKeyword(_ input: inout Substring, _ phrases: [String]) -> String? {
        for phrase in longestFirst(phrases) where consumeKeyword(&input, phrase) {
            return phrase
        }
        return nil
    }
}

struct WhitespaceKeyword: Parser {
    let word: String

    func parse(_ input: inout Substring) throws {
        guard consumeKeyword(&input, word) else {
            throw POCParseError(message: "expected \(word)")
        }
    }
}

func longestFirst(_ phrases: [String]) -> [String] {
    phrases.sorted {
        let leftWords = $0.split(separator: " ").count
        let rightWords = $1.split(separator: " ").count
        if leftWords != rightWords {
            return leftWords > rightWords
        }
        return $0.count > $1.count
    }
}

func longestFirst<T>(_ entries: [(marker: String, op: T)]) -> [(marker: String, op: T)] {
    entries.sorted {
        let leftWords = $0.marker.split(separator: " ").count
        let rightWords = $1.marker.split(separator: " ").count
        if leftWords != rightWords {
            return leftWords > rightWords
        }
        return $0.marker.count > $1.marker.count
    }
}

func skipWhitespace(_ input: inout Substring) {
    while let character = input.first, character == " " || character == "\t" {
        input = input.dropFirst()
    }
}

func consumeKeyword(_ input: inout Substring, _ phrase: String) -> Bool {
    var copy = input
    skipWhitespace(&copy)
    let words = phrase.split(separator: " ").map(String.init)
    if (try? Keyword<Substring>(words: words).parse(&copy)) != nil {
        input = copy
        return true
    }
    return false
}

func keywordAhead(_ input: Substring, _ phrase: String) -> Bool {
    var copy = input
    return consumeKeyword(&copy, phrase)
}

func scanWord(_ input: inout Substring) -> String? {
    var word = ""
    while let character = input.first,
          character.isLetter || character.isNumber || character == "_" || character == "'" {
        word.append(character)
        input = input.dropFirst()
    }
    return word.isEmpty ? nil : word
}

func nextTokenStartsWord(_ input: Substring) -> Bool {
    var copy = input
    skipWhitespace(&copy)
    return copy.first?.isLetter == true
}

@main
struct PegexSyntaxPOC {
    static func main() throws {
        var runner = Runner()
        try runner.run()
    }
}

struct Runner {
    let grammar = POCGrammar()
    var passed = 0
    var failed = 0

    mutating func run() throws {
        let grammar = self.grammar

        print("== Data-driven, ordered longest-match comparators ==")
        check(
            "total amount is more than 500",
            try grammar.parseExpression("total amount is more than 500"),
            .comparison(lhs: "total amount", op: ">", rhs: .number(500))
        )
        check(
            "status is not active",
            try grammar.parseExpression("status is not active"),
            .comparison(lhs: "status", op: "!=", rhs: .word("active"))
        )
        check(
            "x is at least 3",
            try grammar.parseExpression("x is at least 3"),
            .comparison(lhs: "x", op: ">=", rhs: .number(3))
        )
        check(
            "name is \"bob\"",
            try grammar.parseExpression("name is \"bob\""),
            .comparison(lhs: "name", op: "==", rhs: .string("bob"))
        )

        print("== Quote shielding ==")
        check(
            "label is \"a is b\"",
            try grammar.parseExpression("label is \"a is b\""),
            .comparison(lhs: "label", op: "==", rhs: .string("a is b"))
        )

        print("== Boolean precedence and explicit grouping ==")
        check(
            "a is active and b is stale or c is old",
            try grammar.parseExpression("a is active and b is stale or c is old"),
            .or(
                .and(
                    .comparison(lhs: "a", op: "==", rhs: .word("active")),
                    .comparison(lhs: "b", op: "==", rhs: .word("stale"))
                ),
                .comparison(lhs: "c", op: "==", rhs: .word("old"))
            )
        )
        check(
            "a is active or b is stale and c is old",
            try grammar.parseExpression("a is active or b is stale and c is old"),
            .or(
                .comparison(lhs: "a", op: "==", rhs: .word("active")),
                .and(
                    .comparison(lhs: "b", op: "==", rhs: .word("stale")),
                    .comparison(lhs: "c", op: "==", rhs: .word("old"))
                )
            )
        )
        check(
            "not x is active",
            try grammar.parseExpression("not x is active"),
            .not(.comparison(lhs: "x", op: "==", rhs: .word("active")))
        )
        check(
            "either a is active or b is stale",
            try grammar.parseExpression("either a is active or b is stale"),
            .either(
                .comparison(lhs: "a", op: "==", rhs: .word("active")),
                .comparison(lhs: "b", op: "==", rhs: .word("stale"))
            )
        )

        print("== Quantified descriptions and whose clauses ==")
        check(
            "every stale page whose status is active",
            try grammar.parseDescription("every stale page whose status is active"),
            .description(
                quantifier: "every",
                adjectives: ["stale"],
                kind: "page",
                whose: [.comparison(lhs: "status", op: "==", rhs: .word("active"))]
            )
        )
        check(
            "no orphaned deal",
            try grammar.parseDescription("no orphaned deal"),
            .description(quantifier: "no", adjectives: ["orphaned"], kind: "deal", whose: [])
        )
        check(
            "any urgent stale deal whose owner is bob and status is active",
            try grammar.parseDescription("any urgent stale deal whose owner is bob and status is active"),
            .description(
                quantifier: "any",
                adjectives: ["urgent", "stale"],
                kind: "deal",
                whose: [
                    .comparison(lhs: "owner", op: "==", rhs: .word("bob")),
                    .comparison(lhs: "status", op: "==", rhs: .word("active")),
                ]
            )
        )

        print("== 5A-0 spike: symbol closures and sentinel passthrough ==")
        check(
            "every stale page that mentions entity",
            try grammar.parseSymbolicDescription("every stale page that mentions entity"),
            .symbolicDescription(
                quantifier: "every",
                adjectives: ["stale"],
                kind: "page",
                relation: "mentions",
                object: "entity"
            )
        )
        check(
            "private-use codeblock sentinel",
            try grammar.parseSentinelAtom("\u{E000}codeblock:plain:abc"),
            .sentinel("\u{E000}codeblock:plain:abc")
        )
        check(
            "private-use either sentinel",
            try grammar.parseSentinelAtom("\u{E001}either:abc"),
            .sentinel("\u{E001}either:abc")
        )
        checkConstructionCost()

        print("== Located diagnostics ==")
        checkLocatedDiagnostic()

        print("\n== SUMMARY: \(passed) passed, \(failed) failed ==")
        if failed > 0 {
            Foundation.exit(1)
        }
    }

    mutating func check(_ name: String, _ actual: @autoclosure () throws -> POCNode, _ expected: POCNode) {
        do {
            let parsed = try actual()
            if parsed == expected {
                passed += 1
                print("  PASS  \(name)")
            } else {
                failed += 1
                print("  FAIL  \(name)")
                print("        expected: \(expected)")
                print("        actual:   \(parsed)")
            }
        } catch {
            failed += 1
            print("  FAIL  \(name) (threw: \(error))")
        }
    }

    mutating func checkLocatedDiagnostic() {
        let source = "total amount is more than"
        let grammar = self.grammar
        let parser = AnyParser<Substring, POCNode> { input in
            try grammar.parseComparison(&input)
        }

        do {
            _ = try parser.parseWithLocation(source)
            failed += 1
            print("  FAIL  expected a located error but parse succeeded")
        } catch let error as PEGExLocatedError {
            let expected = (line: 1, column: 26, offset: 25)
            if error.location.line == expected.line,
               error.location.column == expected.column,
               error.location.offset == expected.offset {
                passed += 1
                print("  PASS  located error: line 1, column 26, offset 25")
                print("        message: \(error.message)")
            } else {
                failed += 1
                print("  FAIL  located error had wrong position: \(error.location)")
            }
        } catch {
            failed += 1
            print("  FAIL  expected PEGExLocatedError, got \(error)")
        }
    }

    mutating func checkConstructionCost() {
        let iterations = 10_000
        let constructionNanos = measure {
            for _ in 0..<iterations {
                _ = POCGrammar(symbols: .brain).expressionParser
            }
        }
        let parseNanos = measure {
            for _ in 0..<iterations {
                _ = try? grammar.parseExpression("total amount is more than 500")
            }
        }

        passed += 1
        let constructionMs = Double(constructionNanos) / 1_000_000
        let parseMs = Double(parseNanos) / 1_000_000
        let ratio = parseNanos == 0 ? 0 : Double(constructionNanos) / Double(parseNanos)
        print("  PASS  construction micro-benchmark")
        print(String(format: "        build 10k parser sets: %.2f ms", constructionMs))
        print(String(format: "        parse 10k expressions: %.2f ms", parseMs))
        print(String(format: "        build/parse ratio: %.2fx", ratio))
    }
}

func measure(_ body: () -> Void) -> UInt64 {
    let start = DispatchTime.now().uptimeNanoseconds
    body()
    return DispatchTime.now().uptimeNanoseconds - start
}
