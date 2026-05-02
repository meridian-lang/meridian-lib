import Testing
import Foundation
@testable import MeridianCore

@Suite("MerconfigDocsRenderer")
struct MerconfigDocsRendererTests {

    private let parser = MerConfigParser()

    @Test("renders a complete HTML doctype + page sections")
    func wellFormedDocument() throws {
        let parsed = try parser.parse(sampleConfig, file: "sample.merconfig")
        let html = MerconfigDocsRenderer().render(parsed)
        #expect(html.hasPrefix("<!doctype html>"))
        #expect(html.contains("<title>Meridian vocabulary</title>"))
        #expect(html.contains("<h2>Kinds</h2>"))
        #expect(html.contains("<h2>Properties</h2>"))
        #expect(html.contains("<h2>Phrases</h2>"))
        #expect(html.contains("<h2>Constants</h2>"))
        #expect(html.contains("<h2>Instances</h2>"))
        #expect(html.contains("<h2>Tools</h2>"))
        #expect(html.hasSuffix("</html>"))
    }

    @Test("each kind appears with its declared name")
    func kindsRendered() {
        // Build the AST directly so this test is independent of any
        // parser quirks for `is a kind of …` phrasing.
        let config = MerConfigFile(vocabulary: [
            .kind(KindDeclaration(name: "order",    parent: "thing")),
            .kind(KindDeclaration(name: "customer", parent: "person"))
        ])
        let html = MerconfigDocsRenderer().render(config)
        #expect(html.contains("<code>order</code>"))
        #expect(html.contains("<code>customer</code>"))
        #expect(html.contains("extends <code>thing</code>"))
        #expect(html.contains("extends <code>person</code>"))
    }

    @Test("multi-config render groups each file under its own article")
    func multiConfigUsesArticles() throws {
        let parsed = try parser.parse(sampleConfig, file: "a.merconfig")
        let html = MerconfigDocsRenderer().render([
            (name: "first.merconfig",  config: parsed),
            (name: "second.merconfig", config: parsed)
        ])
        #expect(html.contains("first.merconfig"))
        #expect(html.contains("second.merconfig"))
        // Two articles → two h2 headings naming the file
        let firstRange  = html.range(of: "first.merconfig")
        let secondRange = html.range(of: "second.merconfig")
        #expect(firstRange != nil && secondRange != nil)
    }

    @Test("special characters in kind names are HTML-escaped")
    func htmlEscaping() throws {
        // Manually-built MerConfigFile so we don't have to coax the parser
        // into accepting an `<` in a kind name.
        let kind = KindDeclaration(name: "weird<&\"name", parent: "")
        let config = MerConfigFile(vocabulary: [.kind(kind)])
        let html = MerconfigDocsRenderer().render(config)
        #expect(html.contains("weird&lt;&amp;&quot;name"))
        #expect(!html.contains("weird<&\"name"))
    }

    // MARK: - Fixtures

    private let sampleConfig = """
    === vocabulary ===
    order is a kind of thing.
    customer is a kind of person.

    an order has an id, a status, and a total amount.

    === constants ===
    minimum order amount is 1.00 USD.

    === instances ===
    primary mailer is a mailer server with the host set to "smtp.example.com".

    === tools ===
    validate order(an order) returns a verdict.
    """
}
