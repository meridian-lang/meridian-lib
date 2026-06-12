import Testing
import Foundation
@testable import MeridianRuntime

// Detailed unit coverage for the runtime helpers introduced by the Inform-7-tier
// program (Wave 1): `Value.member` (1B/1C element-property reads),
// `MeridianComparison.orderedBefore` (1C `sorted by`), and
// `isWithinPast` / `isWithinFuture` (1C `within the last` / `in the next`).
// These are pure functions with precise semantics that codegen depends on, so
// they are exercised directly rather than only through generated Swift.

// MARK: - Value.member (dot-path traversal)

@Suite("Wave 1B/1C — Value.member")
struct ValueMemberTests {

    private let record = Value.record([
        "id": .string("o-1"),
        "total": .number(42),
        "customer": .record([
            "name": .string("Ada"),
            "address": .record(["city": .string("London")]),
        ]),
        "tags": .list([.string("urgent"), .string("vip")]),
    ])

    @Test("a single segment reads a top-level field")
    func singleSegment() {
        #expect(record.member("id") == .string("o-1"))
        #expect(record.member("total") == .number(42))
    }

    @Test("a dotted path walks nested records")
    func nestedPath() {
        #expect(record.member("customer.name") == .string("Ada"))
        #expect(record.member("customer.address.city") == .string("London"))
    }

    @Test("an empty path returns self")
    func emptyPath() {
        #expect(record.member("") == record)
    }

    @Test("a missing segment returns nil")
    func missingSegment() {
        #expect(record.member("missing") == nil)
        #expect(record.member("customer.phone") == nil)
        #expect(record.member("customer.address.zip") == nil)
    }

    @Test("traversing into a non-record segment returns nil")
    func traverseIntoNonRecord() {
        // `total` is a number; `total.cents` cannot be walked.
        #expect(record.member("total.cents") == nil)
        // `tags` is a list, not a record.
        #expect(record.member("tags.0") == nil)
    }

    @Test("member on a non-record value is nil for any non-empty path")
    func nonRecordReceiver() {
        #expect(Value.string("x").member("anything") == nil)
        #expect(Value.number(1).member("a.b") == nil)
        // Empty path is identity even for scalars.
        #expect(Value.string("x").member("") == .string("x"))
    }
}

// MARK: - MeridianComparison.orderedBefore (total order for `sorted by`)

@Suite("Wave 1C — orderedBefore total order")
struct OrderedBeforeTests {

    @Test("numbers order ascending and descending")
    func numbers() {
        #expect(MeridianComparison.orderedBefore(.number(1), .number(2), ascending: true))
        #expect(!MeridianComparison.orderedBefore(.number(2), .number(1), ascending: true))
        #expect(MeridianComparison.orderedBefore(.number(2), .number(1), ascending: false))
        #expect(!MeridianComparison.orderedBefore(.number(1), .number(2), ascending: false))
    }

    @Test("dates order by instant")
    func dates() {
        let early = Value.date(Date(timeIntervalSince1970: 1_000))
        let late = Value.date(Date(timeIntervalSince1970: 2_000))
        #expect(MeridianComparison.orderedBefore(early, late, ascending: true))
        #expect(MeridianComparison.orderedBefore(late, early, ascending: false))
        // dateTime and date are both date-like and compare cross-case.
        let lateDT = Value.dateTime(Date(timeIntervalSince1970: 2_000))
        #expect(MeridianComparison.orderedBefore(early, lateDT, ascending: true))
    }

    @Test("alphabetic strings order lexicographically")
    func strings() {
        #expect(MeridianComparison.orderedBefore(.string("apple"), .string("banana"), ascending: true))
        #expect(!MeridianComparison.orderedBefore(.string("banana"), .string("apple"), ascending: true))
        #expect(MeridianComparison.orderedBefore(.string("banana"), .string("apple"), ascending: false))
    }

    @Test("equal values are never ordered before each other (stable ties)")
    func ties() {
        #expect(!MeridianComparison.orderedBefore(.number(5), .number(5), ascending: true))
        #expect(!MeridianComparison.orderedBefore(.number(5), .number(5), ascending: false))
        #expect(!MeridianComparison.orderedBefore(.string("x"), .string("x"), ascending: true))
        let d = Value.date(Date(timeIntervalSince1970: 7))
        #expect(!MeridianComparison.orderedBefore(d, d, ascending: true))
    }

    @Test("nil and unorderable values sort last")
    func nilsSortLast() {
        // a == nil: a never precedes b.
        #expect(!MeridianComparison.orderedBefore(nil, .number(1), ascending: true))
        #expect(!MeridianComparison.orderedBefore(nil, .number(1), ascending: false))
        // b == nil (and a is orderable): a precedes b.
        #expect(MeridianComparison.orderedBefore(.number(1), nil, ascending: true))
        #expect(MeridianComparison.orderedBefore(.number(1), nil, ascending: false))
        // both nil: tie.
        #expect(!MeridianComparison.orderedBefore(nil, nil, ascending: true))
        // a boolean is unorderable → treated like nil (sorts last).
        #expect(MeridianComparison.orderedBefore(.number(1), .boolean(true), ascending: true))
        #expect(!MeridianComparison.orderedBefore(.boolean(true), .number(1), ascending: true))
    }

    @Test("mixed orderable kinds (number vs alphabetic string) do not cross-order")
    func mixedKinds() {
        // Different ranks but both non-nil: no defined order → false either way.
        #expect(!MeridianComparison.orderedBefore(.number(1), .string("apple"), ascending: true))
        #expect(!MeridianComparison.orderedBefore(.string("apple"), .number(1), ascending: true))
    }

    @Test("money and duration order numerically")
    func numericKinds() {
        let cheap = Value.money(Money(amount: 5, currency: "USD"))
        let dear = Value.money(Money(amount: 50, currency: "USD"))
        #expect(MeridianComparison.orderedBefore(cheap, dear, ascending: true))
        let short = Value.duration(.seconds(30))
        let long = Value.duration(.seconds(300))
        #expect(MeridianComparison.orderedBefore(short, long, ascending: true))
        #expect(MeridianComparison.orderedBefore(long, short, ascending: false))
    }

    @Test("orderedBefore drives a deterministic Swift sort")
    func driveSort() {
        let unsorted: [Value] = [.number(3), .number(1), .number(2)]
        let asc = unsorted.sorted { MeridianComparison.orderedBefore($0, $1, ascending: true) }
        #expect(asc == [.number(1), .number(2), .number(3)])
        let desc = unsorted.sorted { MeridianComparison.orderedBefore($0, $1, ascending: false) }
        #expect(desc == [.number(3), .number(2), .number(1)])
    }
}

// MARK: - one-sided temporal windows

@Suite("Wave 1C — isWithinPast / isWithinFuture")
struct TemporalWindowTests {

    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test("a recent past instant is within the past window")
    func pastInside() {
        let oneHourAgo = Value.dateTime(now.addingTimeInterval(-3_600))
        #expect(MeridianComparison.isWithinPast(oneHourAgo, .seconds(7_200), of: now))
    }

    @Test("a past instant beyond the window is excluded")
    func pastOutside() {
        let threeHoursAgo = Value.dateTime(now.addingTimeInterval(-10_800))
        #expect(!MeridianComparison.isWithinPast(threeHoursAgo, .seconds(7_200), of: now))
    }

    @Test("a future instant is never within the past window")
    func futureNotInPast() {
        let later = Value.dateTime(now.addingTimeInterval(3_600))
        #expect(!MeridianComparison.isWithinPast(later, .seconds(7_200), of: now))
    }

    @Test("a near-future instant is within the future window")
    func futureInside() {
        let inOneHour = Value.dateTime(now.addingTimeInterval(3_600))
        #expect(MeridianComparison.isWithinFuture(inOneHour, .seconds(7_200), of: now))
    }

    @Test("a far-future instant is excluded from the future window")
    func futureOutside() {
        let inThreeHours = Value.dateTime(now.addingTimeInterval(10_800))
        #expect(!MeridianComparison.isWithinFuture(inThreeHours, .seconds(7_200), of: now))
    }

    @Test("a past instant is never within the future window")
    func pastNotInFuture() {
        let earlier = Value.dateTime(now.addingTimeInterval(-3_600))
        #expect(!MeridianComparison.isWithinFuture(earlier, .seconds(7_200), of: now))
    }

    @Test("the window boundary is inclusive")
    func boundaryInclusive() {
        let exactlyWindowAgo = Value.dateTime(now.addingTimeInterval(-7_200))
        #expect(MeridianComparison.isWithinPast(exactlyWindowAgo, .seconds(7_200), of: now))
        let exactlyWindowAhead = Value.dateTime(now.addingTimeInterval(7_200))
        #expect(MeridianComparison.isWithinFuture(exactlyWindowAhead, .seconds(7_200), of: now))
    }

    @Test("a non-date value or nil is outside any window")
    func nonDateFails() {
        #expect(!MeridianComparison.isWithinPast(.string("yesterday"), .seconds(7_200), of: now))
        #expect(!MeridianComparison.isWithinPast(nil, .seconds(7_200), of: now))
        #expect(!MeridianComparison.isWithinFuture(.number(5), .seconds(7_200), of: now))
        #expect(!MeridianComparison.isWithinFuture(nil, .seconds(7_200), of: now))
    }
}

// MARK: - emptiness predicates (Wave 2 shared condition grammar)

@Suite("Wave 2 — isEmpty / isNotEmpty")
struct EmptinessTests {

    @Test("nil and null are empty")
    func nilAndNull() {
        #expect(MeridianComparison.isEmpty(nil))
        #expect(MeridianComparison.isEmpty(.null))
        #expect(!MeridianComparison.isNotEmpty(nil))
        #expect(!MeridianComparison.isNotEmpty(.null))
    }

    @Test("a blank or whitespace-only string is empty")
    func blankStrings() {
        #expect(MeridianComparison.isEmpty(.string("")))
        #expect(MeridianComparison.isEmpty(.string("   ")))
        #expect(MeridianComparison.isEmpty(.string("\n\t ")))
    }

    @Test("a non-blank string is not empty")
    func nonBlankString() {
        #expect(MeridianComparison.isNotEmpty(.string("hello")))
        #expect(!MeridianComparison.isEmpty(.string(" x ")))
    }

    @Test("an empty list or record is empty; a populated one is not")
    func collections() {
        #expect(MeridianComparison.isEmpty(.list([])))
        #expect(MeridianComparison.isEmpty(.record([:])))
        #expect(MeridianComparison.isNotEmpty(.list([.number(1)])))
        #expect(MeridianComparison.isNotEmpty(.record(["k": .string("v")])))
    }

    @Test("scalars other than string are never empty")
    func scalarsNeverEmpty() {
        #expect(!MeridianComparison.isEmpty(.number(0)))
        #expect(!MeridianComparison.isEmpty(.boolean(false)))
        #expect(MeridianComparison.isNotEmpty(.number(0)))
    }
}
