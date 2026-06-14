import Testing
import Foundation
@testable import MeridianRuntime

@Suite("MeridianComparison — ordering, equality, emptiness, identity, windows")
struct ComparisonCoverageTests {
    @Test("eq / neq over Values")
    func equality() {
        #expect(MeridianComparison.eq(.number(1), .number(1)))
        #expect(MeridianComparison.eq(nil, nil))            // both treated as .null
        #expect(MeridianComparison.neq(.string("a"), .string("b")))
    }

    @Test("numeric ordering across number/money/duration/string and typed constants")
    func ordering() {
        #expect(MeridianComparison.lt(.number(1), .number(2)))
        #expect(MeridianComparison.le(.number(2), .number(2)))
        #expect(MeridianComparison.gt(.money(.init(amount: 5, currency: "USD")), .number(3)))
        #expect(MeridianComparison.ge(.duration(.seconds(10)), .number(10)))
        #expect(MeridianComparison.lt(.string("3"), .number(4)))   // string parses to Decimal
        // typed-constant overloads (both directions)
        #expect(MeridianComparison.lt(.number(1), 2))
        #expect(MeridianComparison.gt(5, .number(2)))
        // non-numeric operands → false
        #expect(!MeridianComparison.lt(.boolean(true), .number(1)))
    }

    @Test("orderedBefore total order: dates, numbers, strings; unorderable sorts last")
    func orderedBefore() {
        let early = Value.date(Date(timeIntervalSince1970: 0))
        let late = Value.date(Date(timeIntervalSince1970: 100))
        #expect(MeridianComparison.orderedBefore(early, late))
        #expect(MeridianComparison.orderedBefore(late, early, ascending: false))
        #expect(MeridianComparison.orderedBefore(.number(1), .number(2)))
        #expect(MeridianComparison.orderedBefore(.string("a"), .string("b")))
        #expect(!MeridianComparison.orderedBefore(.number(2), .number(2)))   // tie → false
        #expect(!MeridianComparison.orderedBefore(nil, nil))
        #expect(!MeridianComparison.orderedBefore(.boolean(true), .number(1))) // a unorderable → last
        #expect(MeridianComparison.orderedBefore(.number(1), .boolean(true)))  // b unorderable
    }

    @Test("isEmpty / isNotEmpty over null, strings, lists, records, scalars")
    func emptiness() {
        #expect(MeridianComparison.isEmpty(nil))
        #expect(MeridianComparison.isEmpty(.null))
        #expect(MeridianComparison.isEmpty(.string("   ")))
        #expect(MeridianComparison.isEmpty(.list([])))
        #expect(MeridianComparison.isEmpty(.record([:])))
        #expect(!MeridianComparison.isEmpty(.number(0)))
        #expect(!MeridianComparison.isEmpty(.string("x")))
        #expect(MeridianComparison.isNotEmpty(.list([.null])))
    }

    @Test("identifies matches by id string, record id, list membership; nil never matches")
    func identifies() {
        #expect(MeridianComparison.identifies(.string("u1"), .string("u1")))
        #expect(MeridianComparison.identifies(.reference("u1"), .string("u1")))
        #expect(MeridianComparison.identifies(.record(["id": .string("u1")]), .string("u1")))
        #expect(MeridianComparison.identifies(.list([.string("a"), .string("u1")]), .string("u1")))
        #expect(!MeridianComparison.identifies(.string("u1"), .string("u2")))
        #expect(!MeridianComparison.identifies(nil, .string("u1")))
        #expect(!MeridianComparison.identifies(.string("u1"), nil))
        // fallback whole-value equality for non-identity values
        #expect(MeridianComparison.identifies(.number(7), .number(7)))
    }

    @Test("isWithin / isWithinPast / isWithinFuture time windows")
    func windows() {
        let now = Date(timeIntervalSince1970: 1000)
        let recentPast = Value.date(Date(timeIntervalSince1970: 940))   // 60s ago
        let future = Value.date(Date(timeIntervalSince1970: 1060))      // 60s ahead
        #expect(MeridianComparison.isWithin(recentPast, .seconds(120), of: now))
        #expect(MeridianComparison.isWithinPast(recentPast, .seconds(120), of: now))
        #expect(!MeridianComparison.isWithinPast(future, .seconds(120), of: now))   // future fails past
        #expect(MeridianComparison.isWithinFuture(future, .seconds(120), of: now))
        #expect(!MeridianComparison.isWithinFuture(recentPast, .seconds(120), of: now))
        #expect(!MeridianComparison.isWithin(.string("not a date"), .seconds(1), of: now))
    }

    @Test("NumericConvertible conformances bridge to Decimal")
    func numericConvertible() {
        #expect(Decimal(5).asDecimal == 5)
        #expect(Int(5).asDecimal == 5)
        #expect(Double(5).asDecimal == 5)
        #expect(Money(amount: 5, currency: "USD").asDecimal == 5)
        #expect(Duration.seconds(5).asDecimal == 5)
    }
}

@Suite("meridianMatches — recover pattern matching")
struct ErrorMatchingTests {
    @Test("named implementation code matches directly and through MeridianRuntimeError")
    func namedCode() {
        let te = ToolError.implementation(code: "payment.declined", message: "no", cause: nil)
        #expect(meridianMatches(te, named: "payment.declined"))
        #expect(!meridianMatches(te, named: "other"))
        let wrapped = MeridianRuntimeError.toolError(te, sourceRange: nil)
        #expect(meridianMatches(wrapped, named: "payment.declined"))
    }

    @Test("structured tool errors map to canonical names")
    func structured() {
        #expect(meridianMatches(ToolError.argumentCoercion(field: "x", expected: "Int", actual: "String"),
                                named: "tool.argument_coercion"))
        #expect(meridianMatches(ToolError.timeout(.seconds(1)), named: "tool.timeout"))
        #expect(meridianMatches(ToolError.subprocess(.init(exitCode: 1, stderr: "")),
                                named: "subprocess.exit_failure"))
        #expect(meridianMatches(ToolError.http(statusCode: 404, body: ""), named: "http.status_404"))
        #expect(meridianMatches(ToolError.http(statusCode: 500, body: ""), named: "http.status"))
        #expect(meridianMatches(ToolError.mcp(.init(code: "rpc.fail", message: "")), named: "rpc.fail"))
        #expect(meridianMatches(ToolError.mcp(.init(code: "x", message: "")), named: "mcp.error"))
    }

    @Test("approval denial matches role and approval.denied")
    func approval() {
        let e = MeridianRuntimeError.approvalDenied(role: "manager", sourceRange: nil)
        #expect(meridianMatches(e, named: "manager"))
        #expect(meridianMatches(e, named: "approval.denied"))
        #expect(!meridianMatches(e, named: "other"))
    }

    @Test("typed matching compares dynamic type")
    func typed() {
        let e: any Error = MeridianRuntimeError.cancelled
        #expect(meridianMatches(e, typed: MeridianRuntimeError.self))
        #expect(!meridianMatches(e, typed: ToolError.self))
    }
}
