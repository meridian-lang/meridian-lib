import Testing
@testable import MeridianCore

@Suite("SymbolTable — verb form and tool resolution")
struct SymbolTableVerbTests {
    private func symbols() throws -> SymbolTable {
        let cfg = try MerConfigParser(trace: .silent()).parse("""
        === vocabulary ===
        A user is a kind of thing.
        A page is a kind of thing.
        A page has an owner, which is a String.

        Ownership relates one user to various pages.
        Ownership is read from the page's owner.
        The verb to own (it owns, it is owned) means the ownership relation.

        === tools ===

        Archive Page
        ============
        ~ archivePage(id: String) : Page
        """, file: "t.merconfig")
        return SymbolTable.build(from: cfg, sourceFile: "t.merconfig", trace: .silent())
    }

    @Test("isVerbForm recognizes base, third-person, and participle forms")
    func verbForms() throws {
        let s = try symbols()
        #expect(s.isVerbForm("own"))
        #expect(s.isVerbForm("owns"))
        #expect(s.isVerbForm("owned"))
        #expect(!s.isVerbForm("frobnicate"))
    }

    @Test("resolveVerbForm carries the role for each surface form")
    func verbRole() throws {
        let s = try symbols()
        #expect(s.resolveVerbForm("owned")?.role == .pastParticiple)
        #expect(s.resolveVerbForm("own")?.verb.base == "own")
    }

    @Test("a declared tool resolves by display name and methodName")
    func toolLookup() throws {
        let s = try symbols()
        #expect(s.tool(named: "archivePage") != nil)
    }
}
