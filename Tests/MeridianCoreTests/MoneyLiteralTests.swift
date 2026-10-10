import Foundation
import Testing
@testable import MeridianCore

@Suite("Money and env-var literals")
struct MoneyLiteralTests {

    private let grammar = LiteralGrammar(lexicon: .default)

    @Test("$5000 is a Money literal (USD)")
    func dollarAmountIsMoney() {
        guard case .literal(.money(let amount, let currency))? = grammar.parse("$5000") else {
            Issue.record("expected a money literal, got \(String(describing: grammar.parse("$5000")))")
            return
        }
        #expect(amount == 5000)
        #expect(currency == "USD")
    }

    @Test("$5000.00 AUD carries an explicit currency")
    func dollarAmountWithCurrency() {
        guard case .literal(.money(let amount, let currency))? = grammar.parse("$5000.00 AUD") else {
            Issue.record("expected a money literal with a currency")
            return
        }
        #expect(amount == 5000)
        #expect(currency == "AUD")
    }

    @Test("$HOME stays an environment-variable reference")
    func dollarNameIsEnvVar() {
        guard case .envVar(let name)? = grammar.parse("$HOME") else {
            Issue.record("expected an env-var reference")
            return
        }
        #expect(name == "HOME")
    }

    @Test("a $ token that is neither a name nor an amount is rejected")
    func invalidDollarTokenIsMalformed() {
        guard case .malformed(let info)? = grammar.parse("$1000x") else {
            Issue.record("expected a malformed literal, got \(String(describing: grammar.parse("$1000x")))")
            return
        }
        #expect(info.0.contains("$1000x"))
    }

    @Test("a $ token with a non-currency suffix is rejected")
    func malformedMoneySuffix() {
        guard case .malformed(let info)? = grammar.parse("$5000.00 AUD extra") else {
            Issue.record("expected a malformed literal")
            return
        }
        #expect(info.0.contains("$5000.00 AUD extra"))
    }

    @Test("a bare $ and a non-alphabetic currency are rejected")
    func malformedMoneyShapes() {
        for token in ["$", "$5000.00 A1D"] {
            guard case .malformed? = grammar.parse(token) else {
                Issue.record("expected \(token) to be rejected, got \(String(describing: grammar.parse(token)))")
                continue
            }
        }
    }

    @Test("a bounded permission with a money bound lowers to a comparison against that amount")
    func boundedPermissionMoneyBound() throws {
        let config = """
        === vocabulary ===
        An order is a kind of thing.
          An order has a total which is Money.
        """
        let symbols = SymbolTable.build(from: try MerConfigParser().parse(config, file: "t.merconfig"))
        let source = """
        A manager may approve an order whose total is at most $10000.

        To approve an order:
          complete.
        """
        let unit = Compiler.CompilationUnit(
            sources: [Compiler.SourceInput(source: source, file: "t.meridian")],
            vocabularies: [Compiler.VocabularyInput(name: "t", file: "t.merconfig", source: config)]
        )
        _ = symbols
        let out = try Compiler().compile(unit)["t.meridian"]
        let swift = try #require(out?.swift)
        #expect(swift.contains("10000"))
        #expect(!swift.contains("processInfo.environment"))
    }
}
