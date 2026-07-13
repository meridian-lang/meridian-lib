import Foundation
import Testing
@testable import MeridianCore

@Suite("Typed list and optional merconfig property types")
struct TypedListOptionalPropertyTests {

    private func parseAllProperties(_ cfg: String) throws -> [PropertyEntry] {
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        return config.vocabulary.compactMap { stmt -> [PropertyEntry]? in
            if case .property(let p) = stmt { return p.properties }
            return nil
        }.flatMap { $0 }
    }

    private func compile(_ cfg: String) throws -> String {
        let mer = """
        ---
        name: typed props
        vocabulary: t.merconfig
        ---
        To probe:
          complete.
        """
        return try Compiler(options: .init(
            emitterOptions: SwiftEmitter.Options(includeTimestamp: false, emitSourceLineComments: false)
        )).compile(
            meridianSource: mer,
            meridianFile: "probe.meridian",
            merconfigSource: cfg,
            merconfigFile: "t.merconfig"
        )
    }

    @Test("parse list of kind and optional kind surface forms")
    func parseTypedSurface() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        A shipment has line items, which is a list of order.
        A shipment has a note, which is an optional String.
        """
        let props = try parseAllProperties(cfg)
        #expect(props.count == 2)
        guard case .listOf(.explicit("order")) = props[0].type else {
            Issue.record("expected list of order, got \(props[0].type)")
            return
        }
        guard case .optional(.explicit("String")) = props[1].type else {
            Issue.record("expected optional String, got \(props[1].type)")
            return
        }
    }

    @Test("bare list still parses as untyped string list compat")
    func bareListCompat() throws {
        let cfg = """
        === vocabulary ===
        A validation result is a kind of thing.
        A validation result has issues, which is a List.
        """
        guard case .explicit("List") = try parseAllProperties(cfg)[0].type else {
            Issue.record("expected explicit List")
            return
        }
        let swift = try compile(cfg)
        #expect(swift.contains("var issues: [String]"))
    }

    @Test("domain emission uses typed Swift property types")
    func domainEmission() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        An order has an id, which is a String.
        A customer is a kind of thing.
        A customer has a name, which is a String.
        A shipment is a kind of thing.
        A shipment has orders, which is a list of order.
        A shipment has a sponsor, which is an optional customer.
        """
        let swift = try compile(cfg)
        #expect(swift.contains("var orders: [Order]"))
        #expect(swift.contains("var sponsor: Customer?"))
        #expect(swift.contains("orders: [Order] = []"))
        #expect(swift.contains("sponsor: Customer? = nil"))
    }

    @Test("SymbolTable threads resolved property type AST")
    func symbolTablePropertyType() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        A shipment is a kind of thing.
        A shipment has orders, which is a list of order.
        """
        let config = try MerConfigParser(trace: .silent()).parse(cfg, file: "t.merconfig")
        let symbols = SymbolTable.build(from: config, sourceFile: "t.merconfig", trace: .silent())
        guard case .listOf(.explicit("order")) = symbols.propertyType(of: "shipment", property: "orders") else {
            Issue.record("expected listOf(order) on shipment.orders")
            return
        }
    }

    @Test("nested optional list of kind resolves to optional array Swift type")
    func nestedOptionalList() throws {
        let cfg = """
        === vocabulary ===
        An order is a kind of thing.
        A shipment is a kind of thing.
        A shipment has drafts, which is an optional list of order.
        """
        let swift = try compile(cfg)
        #expect(swift.contains("var drafts: [Order]?"))
    }
}
