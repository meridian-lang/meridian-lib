import Foundation
import Testing
@testable import MeridianCore

@Suite("ParserTrace — structured spans and concurrency")
struct ParserTraceSpanConcurrencyTests {

    @Test("concurrent nested spans on one trace stay balanced")
    func concurrentNestedSpans() async {
        let cap = ParserTrace.capturing(categories: [.lowering, .symbols])
        let trace = cap.trace
        let correlation = trace.correlationID
        let taskCount = 8
        let depth = 3

        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<taskCount {
                group.addTask {
                    var tokens: [ParserTrace.Token] = []
                    for level in 0..<depth {
                        let tok = trace.push(.lowering, "task \(taskIndex) level \(level)")
                        tokens.append(tok)
                    }
                    for tok in tokens.reversed() {
                        trace.pop(tok, "done \(taskIndex)")
                    }
                }
            }
        }

        let lines = cap.lines()
        let opens = lines.filter { $0.contains("▶") }.count
        let closes = lines.filter { $0.contains("◀") }.count
        #expect(opens == taskCount * depth)
        #expect(closes == taskCount * depth)
        #expect(trace.correlationID == correlation)
    }

    @Test("sequences are unique and monotonic across concurrent writers")
    func monotonicSequences() async {
        final class SeqCollector: @unchecked Sendable {
            private let lock = NSLock()
            private(set) var values: [UInt64] = []
            func append(_ v: UInt64) {
                lock.lock(); defer { lock.unlock() }
                values.append(v)
            }
        }

        let collector = SeqCollector()
        let trace = ParserTrace()
        trace.disableAll()
        trace.enable([.lowering])
        trace.outputFormat = .jsonl
        trace.sink = .custom { line in
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }
            let seq: UInt64?
            if let value = object["seq"] as? UInt64 {
                seq = value
            } else if let value = object["seq"] as? Int {
                seq = UInt64(value)
            } else if let value = object["seq"] as? NSNumber {
                seq = value.uint64Value
            } else {
                seq = nil
            }
            if let seq { collector.append(seq) }
        }

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<12 {
                group.addTask {
                    let tok = trace.openSpan(.lowering, "worker \(i)")
                    trace.log(.lowering, "event \(i)")
                    trace.closeSpan(tok)
                }
            }
        }

        let seqs = collector.values.sorted()
        #expect(seqs.count == 12 * 3) // open + event + close per worker
        #expect(Set(seqs).count == seqs.count)
        for (index, value) in seqs.enumerated() {
            #expect(value == UInt64(index + 1))
        }
    }

    @Test("disabled category does not evaluate autoclosure side effects")
    func disabledSkipsAutoclosure() {
        final class Counter: @unchecked Sendable {
            private let lock = NSLock()
            var value = 0
            func bump() {
                lock.lock(); defer { lock.unlock() }
                value += 1
            }
        }

        let counter = Counter()
        let cap = ParserTrace.capturing(categories: [])
        func expensiveMessage() -> String {
            counter.bump()
            return "should not run"
        }
        cap.trace.openSpan(.lowering, expensiveMessage())
        cap.trace.log(.lowering, expensiveMessage())
        cap.trace.push(.lowering, expensiveMessage())
        #expect(counter.value == 0)
        #expect(cap.lines().isEmpty)
    }

    @Test("jsonl format emits parseable lines with span and parent fields")
    func jsonlSpanFields() {
        let cap = ParserTrace.capturing(categories: [.validation])
        cap.trace.outputFormat = .jsonl
        let outer = cap.trace.openSpan(.validation, "outer")
        let inner = cap.trace.openSpan(.validation, "inner")
        cap.trace.closeSpan(inner, outcome: .success, result: "inner done")
        cap.trace.closeSpan(outer, outcome: .success, result: "outer done")

        let lines = cap.lines()
        #expect(lines.count == 4)

        var records: [[String: Any]] = []
        for line in lines {
            let data = Data(line.utf8)
            let object = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
            records.append(object)
        }

        let corr = cap.trace.correlationID
        for record in records {
            #expect(record["corr"] as? String == corr)
            #expect(record["cat"] as? String == "validation")
            #expect(record["kind"] != nil)
        }

        let openOuter = records.first { ($0["kind"] as? String) == "open" && ($0["op"] as? String) == "outer" }!
        let openInner = records.first { ($0["kind"] as? String) == "open" && ($0["op"] as? String) == "inner" }!
        let outerSpan = openOuter["span"] as! UInt64
        let innerSpan = openInner["span"] as! UInt64
        let innerParent = openInner["parent"] as! UInt64
        #expect(innerParent == outerSpan)
        #expect(innerSpan != outerSpan)

        let closeInner = records.first { ($0["kind"] as? String) == "close" && ($0["msg"] as? String)?.contains("inner done") == true }!
        #expect(closeInner["span"] as! UInt64 == innerSpan)
        #expect(closeInner["parent"] as! UInt64 == outerSpan)
        #expect(closeInner["outcome"] as? String == "success")
    }
}
