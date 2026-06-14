import Testing
@testable import MeridianCore

@Suite("ExpressionAST.traceDescription — every case, both detail levels")
struct ExpressionTraceDescriptionTests {
    private func v(_ e: ExpressionAST) -> String { e.traceDescription(detail: .verbose) }
    private func c(_ e: ExpressionAST) -> String { e.traceDescription(detail: .compact) }

    @Test("literals render their value (verbose) and collapse to lit (compact) where applicable")
    func literals() {
        #expect(v(.literal(.string("hi"))) == "\"hi\"")
        #expect(v(.literal(.integer(7))) == "7")
        #expect(v(.literal(.double(1.5))) == "1.5")
        #expect(v(.literal(.boolean(true))) == "true")
        #expect(c(.literal(.boolean(true))) == "lit")
        #expect(v(.literal(.money(5, currency: "USD"))).contains("USD"))
        #expect(c(.literal(.money(5, currency: "USD"))) == "lit")
        #expect(v(.literal(.duration(2, .hour))).contains("2"))
        #expect(c(.literal(.duration(2, .hour))) == "lit")
    }

    @Test("refs, property access, env, now")
    func refs() {
        #expect(v(.identifierRef("x")) == "id(x)")
        #expect(v(.instanceRef("s")) == "inst(s)")
        #expect(v(.constantRef("k")) == "const(k)")
        #expect(v(.propertyAccess(.identifierRef("order"), "id")) == "id(order).id")
        #expect(v(.envVar("HOME")) == "$HOME")
        #expect(v(.now) == "now")
    }

    @Test("comparison and logical collapse in compact mode")
    func comparisonLogical() {
        let cmp = ExpressionAST.comparison(.identifierRef("a"), .equal, .literal(.integer(1)))
        #expect(v(cmp).hasPrefix("("))
        #expect(c(cmp) == "cmp(...)")
        let log = ExpressionAST.logical(.and, [cmp, cmp])
        #expect(v(log).hasPrefix("logical(and"))
        #expect(c(log) == "logical(...)")
    }

    @Test("invoke, decideWhether, interpolatedString, recordList, malformed")
    func misc() {
        #expect(v(.invoke("http.get", [])) == "invoke(http.get)")
        #expect(v(.decideWhether(question: "ship?")) == "decide(ship?)")
        #expect(v(.interpolatedString([.literal("a")])) == "interp(1 segs)")
        #expect(v(.recordList(fields: ["a", "b"], rows: [])) == "recordList(2 fields, 0 rows)")
        #expect(v(.malformed("boom")) == "malformed(boom)")
    }

    @Test("Wave 2/3 cases: quantified, verbPredicate, relationTraversal, description, aggregate, superlative")
    func waveCases() {
        let desc = DescriptionAST(noun: "pages")
        #expect(v(.quantified(QuantifierAST(kind: .all, description: desc))).hasPrefix("quant("))
        #expect(c(.quantified(QuantifierAST(kind: .all, description: desc))) == "quant(all)")
        let verb = ExpressionAST.verbPredicate(subject: .identifierRef("u"), verb: "owns", object: .identifierRef("p"))
        #expect(v(verb).contains("owns"))
        #expect(c(verb) == "verb(owns)")
        let rel = ExpressionAST.relationTraversal(.identifierRef("u"), relation: "ownership", navKind: "page")
        #expect(v(rel).contains("ownership"))
        #expect(c(rel) == "rel(ownership)")
        #expect(v(.description(desc)) == "desc(pages)")
        #expect(v(.aggregate(.count, desc)) == "agg(count, pages)")
        let sup = SuperlativeAST(description: desc, property: "amount", ascending: false)
        #expect(v(.superlative(sup)).contains("max"))
        #expect(c(.superlative(sup)) == "super(amount)")
    }
}
