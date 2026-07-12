import Foundation

public struct TraceEventPatternQuery: Sendable {
    public enum Subject: Sendable {
        case step(String)
        case named(String)

        var rawValue: String {
            switch self {
            case .step(let name), .named(let name):
                return name
            }
        }
    }

    public enum Outcome: String, Sendable {
        case failed
        case succeeded
        case invoked
        case emitted
        case prevented
        case violated
        /// Generic completion, regardless of tag — matches any record for the
        /// subject/subjectKey/payload. Used for `E has ever occurred` and
        /// outcome-less kind-flavored anchors.
        case occurred
    }

    public let subject: Subject
    public let outcome: Outcome
    public let subjectKey: String?
    public let payloadContains: [String: Value]?
    /// `no <event pattern>` event negation — only meaningful in the `holds`
    /// position of a `sinceLast` temporal query (see `TraceEvaluator.replay`).
    public let negated: Bool

    public init(
        subject: Subject,
        outcome: Outcome,
        subjectKey: String? = nil,
        payloadContains: [String: Value]? = nil,
        negated: Bool = false
    ) {
        self.subject = subject
        self.outcome = outcome
        self.subjectKey = subjectKey
        self.payloadContains = payloadContains
        self.negated = negated
    }
}

public enum TraceCountComparator: Sendable {
    case atLeast(Int)
    case atMost(Int)
    case exactly(Int)
}

public struct TraceTemporalQuery: Sendable {
    public indirect enum Kind: Sendable {
        case ever(TraceEventPatternQuery)
        case withinWindow(TraceEventPatternQuery, duration: Duration)
        case countInWindow(TraceEventPatternQuery, comparator: TraceCountComparator, duration: Duration)
        case inARow(TraceEventPatternQuery, count: Int)
        case sinceLast(anchor: TraceEventPatternQuery, holds: TraceEventPatternQuery)
    }

    public let scope: TraceScope
    public let kind: Kind

    public init(scope: TraceScope = .currentRun, kind: Kind) {
        self.scope = scope
        self.kind = kind
    }
}

public enum TraceStatisticalBound: Sendable, Equatable {
    case atLeast(Double)
    case atMost(Double)
}

public enum TraceStatisticalDenominator: String, Sendable, Equatable {
    case runs
    case occurrences
}

public struct TraceStatisticalQuery: Sendable {
    public let scope: TraceScope
    public let pattern: TraceEventPatternQuery
    public let bound: TraceStatisticalBound
    public let denominator: TraceStatisticalDenominator
    public let window: Duration?

    public init(
        scope: TraceScope = .currentRun,
        pattern: TraceEventPatternQuery,
        bound: TraceStatisticalBound,
        denominator: TraceStatisticalDenominator,
        window: Duration? = nil
    ) {
        self.scope = scope
        self.pattern = pattern
        self.bound = bound
        self.denominator = denominator
        self.window = window
    }
}

public struct TraceEvaluationContext: Sendable {
    public let runID: String?
    public let skillName: String
    public let evaluationInstant: Date
    public let sampleFloor: Int

    public init(runID: String?, skillName: String, evaluationInstant: Date, sampleFloor: Int = 0) {
        self.runID = runID
        self.skillName = skillName
        self.evaluationInstant = evaluationInstant
        self.sampleFloor = sampleFloor
    }
}

public struct TraceReplayResult: Sendable, Codable, Equatable {
    public let truthValue: TruthValue
    public let witnessEventIDs: [String]

    public init(truthValue: TruthValue, witnessEventIDs: [String]) {
        self.truthValue = truthValue
        self.witnessEventIDs = witnessEventIDs
    }
}

public enum TraceEvaluator {
    public static func evaluate(
        temporal: TraceTemporalQuery,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> TruthValue {
        let replayResult = try await replay(temporal: temporal, store: store, context: context)
        return replayResult.truthValue
    }

    public static func replay(
        temporal: TraceTemporalQuery,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> TraceReplayResult {
        switch temporal.kind {
        case .ever(let pattern):
            let matches = try await matchingRecords(
                pattern: pattern,
                scope: temporal.scope,
                window: TraceWindow(end: context.evaluationInstant),
                store: store,
                context: context
            )
            return TraceReplayResult(
                truthValue: .from(!matches.isEmpty),
                witnessEventIDs: witnessIDs(for: matches)
            )

        case .withinWindow(let pattern, let duration):
            let window = TraceWindow.last(duration, endingAt: context.evaluationInstant)
            let matches = try await matchingRecords(
                pattern: pattern,
                scope: temporal.scope,
                window: window,
                store: store,
                context: context
            )
            return TraceReplayResult(
                truthValue: .from(!matches.isEmpty),
                witnessEventIDs: witnessIDs(for: matches)
            )

        case .countInWindow(let pattern, let comparator, let duration):
            let window = TraceWindow.last(duration, endingAt: context.evaluationInstant)
            let matches = try await matchingRecords(
                pattern: pattern,
                scope: temporal.scope,
                window: window,
                store: store,
                context: context
            )
            return TraceReplayResult(
                truthValue: .from(compare(count: matches.count, comparator: comparator)),
                witnessEventIDs: witnessIDs(for: matches)
            )

        case .inARow(let pattern, let count):
            guard count > 0 else {
                return TraceReplayResult(truthValue: .true, witnessEventIDs: [])
            }
            let candidates = try await qualifyingRecords(
                for: pattern,
                scope: temporal.scope,
                window: TraceWindow(end: context.evaluationInstant),
                store: store,
                context: context
            )
            guard candidates.count >= count else {
                return TraceReplayResult(
                    truthValue: .false,
                    witnessEventIDs: witnessIDs(for: candidates)
                )
            }
            let suffix = candidates.suffix(count)
            return TraceReplayResult(
                truthValue: .from(suffix.allSatisfy { fullMatch($0, pattern: pattern) }),
                witnessEventIDs: witnessIDs(for: Array(suffix))
            )

        case .sinceLast(let anchor, let holds):
            let anchors = try await matchingRecords(
                pattern: anchor,
                scope: temporal.scope,
                window: TraceWindow(end: context.evaluationInstant),
                store: store,
                context: context
            )
            guard let lastAnchor = anchors.last else {
                return TraceReplayResult(truthValue: .indeterminate, witnessEventIDs: [])
            }
            let trailing = try await qualifyingRecords(
                for: holds,
                scope: temporal.scope,
                window: TraceWindow(end: context.evaluationInstant),
                store: store,
                context: context
            ).filter { strictlyAfter($0, anchor: lastAnchor, scope: temporal.scope) }
            // Event negation (`no <event pattern>`, SEM-5-6/cookbook 18.5): the
            // held claim is that NO qualifying event exists strictly after the
            // anchor, not that every qualifying event satisfies the pattern.
            let truthValue: TruthValue = holds.negated
                ? .from(trailing.isEmpty)
                : .from(trailing.allSatisfy { fullMatch($0, pattern: holds) })
            return TraceReplayResult(
                truthValue: truthValue,
                witnessEventIDs: witnessIDs(for: [lastAnchor] + trailing)
            )
        }
    }

    public static func evaluate(
        statistical: TraceStatisticalQuery,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> TruthValue {
        let replayResult = try await replay(statistical: statistical, store: store, context: context)
        return replayResult.truthValue
    }

    public static func replay(
        statistical: TraceStatisticalQuery,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> TraceReplayResult {
        let window = statistical.window.map { TraceWindow.last($0, endingAt: context.evaluationInstant) }
            ?? TraceWindow(end: context.evaluationInstant)
        let records = try await qualifyingRecords(
            for: statistical.pattern,
            scope: statistical.scope,
            window: window,
            store: store,
            context: context
        )
        let (successes, sampleSize): (Int, Int)
        switch statistical.denominator {
        case .occurrences:
            sampleSize = records.count
            successes = records.filter { fullMatch($0, pattern: statistical.pattern) }.count
        case .runs:
            let perRun = Dictionary(grouping: records, by: \.run)
            let lastPerRun = perRun.values.compactMap { runRecords in
                runRecords.max { lhs, rhs in
                    TraceRecordOrdering.crossRun(lhs, rhs)
                }
            }
            sampleSize = lastPerRun.count
            successes = lastPerRun.filter { fullMatch($0, pattern: statistical.pattern) }.count
            let truthValue: TruthValue
            if sampleSize < context.sampleFloor {
                truthValue = .indeterminate
            } else {
                let ratio = sampleSize == 0 ? 0 : Double(successes) / Double(sampleSize)
                switch statistical.bound {
                case .atLeast(let threshold):
                    truthValue = .from(ratio >= threshold)
                case .atMost(let threshold):
                    truthValue = .from(ratio <= threshold)
                }
            }
            return TraceReplayResult(
                truthValue: truthValue,
                witnessEventIDs: witnessIDs(for: lastPerRun)
            )
        }
        let truthValue: TruthValue
        guard sampleSize >= context.sampleFloor else {
            return TraceReplayResult(
                truthValue: .indeterminate,
                witnessEventIDs: witnessIDs(for: records)
            )
        }
        let ratio = sampleSize == 0 ? 0 : Double(successes) / Double(sampleSize)
        switch statistical.bound {
        case .atLeast(let threshold):
            truthValue = .from(ratio >= threshold)
        case .atMost(let threshold):
            truthValue = .from(ratio <= threshold)
        }
        return TraceReplayResult(
            truthValue: truthValue,
            witnessEventIDs: witnessIDs(for: records)
        )
    }

    private static func matchingRecords(
        pattern: TraceEventPatternQuery,
        scope: TraceScope,
        window: TraceWindow?,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        let broad = try await baseRecords(
            pattern: pattern,
            scope: scope,
            window: window,
            store: store,
            context: context
        )
        return broad.filter { fullMatch($0, pattern: pattern) }
    }

    private static func qualifyingRecords(
        for pattern: TraceEventPatternQuery,
        scope: TraceScope,
        window: TraceWindow?,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        let broad = try await baseRecords(
            pattern: pattern,
            scope: scope,
            window: window,
            store: store,
            context: context
        )
        return broad.filter { qualifiesIgnoringOutcome($0, pattern: pattern) }
    }

    private static func baseRecords(
        pattern: TraceEventPatternQuery,
        scope: TraceScope,
        window: TraceWindow?,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        try await store.query(
            scope: scope,
            runID: context.runID,
            skillName: context.skillName,
            window: window,
            pattern: TraceQueryPattern(
                subject: pattern.subject.rawValue,
                subjectKey: pattern.subjectKey,
                payloadContains: pattern.payloadContains
            )
        )
    }

    private static func fullMatch(_ record: TraceRecord, pattern: TraceEventPatternQuery) -> Bool {
        guard commonMatch(record, pattern: pattern) else { return false }
        switch pattern.outcome {
        case .failed:
            return record.tag == .failed || record.outcome == .failure
        case .succeeded:
            return record.tag == .completed || record.outcome == .success
        case .invoked:
            return record.tag == .invoked
        case .emitted:
            return record.tag == .emitted
        case .prevented:
            return record.tag == .violated
                && (record.operationalDetail?.localizedCaseInsensitiveContains("prevented") ?? false)
        case .violated:
            return record.tag == .violated
        case .occurred:
            return true
        }
    }

    private static func qualifiesIgnoringOutcome(_ record: TraceRecord, pattern: TraceEventPatternQuery) -> Bool {
        guard commonMatch(record, pattern: pattern) else { return false }
        switch pattern.outcome {
        case .failed, .succeeded:
            return record.tag == .completed || record.tag == .failed
        case .invoked:
            return record.tag == .invoked
        case .emitted:
            return record.tag == .emitted
        case .prevented:
            return false
        case .violated:
            return record.tag == .violated
        case .occurred:
            return true
        }
    }

    private static func commonMatch(_ record: TraceRecord, pattern: TraceEventPatternQuery) -> Bool {
        guard record.subject == pattern.subject.rawValue else { return false }
        if let subjectKey = pattern.subjectKey, record.subjectKey != subjectKey {
            return false
        }
        if let payload = pattern.payloadContains {
            guard let recordPayload = record.payload else { return false }
            for (key, value) in payload where recordPayload[key] != value {
                return false
            }
        }
        return true
    }

    private static func compare(count: Int, comparator: TraceCountComparator) -> Bool {
        switch comparator {
        case .atLeast(let expected):
            return count >= expected
        case .atMost(let expected):
            return count <= expected
        case .exactly(let expected):
            return count == expected
        }
    }

    private static func strictlyAfter(_ record: TraceRecord, anchor: TraceRecord, scope: TraceScope) -> Bool {
        switch scope {
        case .currentRun:
            return TraceRecordOrdering.runLocal(anchor, record)
        case .acrossAllRuns:
            return TraceRecordOrdering.crossRun(anchor, record)
        }
    }

    private static func witnessIDs(for records: [TraceRecord]) -> [String] {
        records.map(\.id).sorted()
    }
}
