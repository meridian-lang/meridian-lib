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
        case sinceLast(
            anchor: TraceEventPatternQuery,
            holds: TraceEventPatternQuery?,
            holdsStatePredicateJSON: String?,
            holdsUsesStateHistory: Bool
        )
        case boundedFutureMonitor(conditionJSON: String, horizon: Duration, mode: FutureMonitorMode)
    }

    public enum FutureMonitorMode: String, Sendable {
        case eventuallyWithin
        case alwaysFor
    }

    public let scope: TraceScope
    public let scopeSkills: [String]
    public let kind: Kind

    public init(scope: TraceScope = .currentRun, scopeSkills: [String] = [], kind: Kind) {
        self.scope = scope
        self.scopeSkills = scopeSkills
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
    public let scopeSkills: [String]
    public let pattern: TraceEventPatternQuery
    public let bound: TraceStatisticalBound
    public let denominator: TraceStatisticalDenominator
    public let window: Duration?
    public let confidencePercent: Double?

    public init(
        scope: TraceScope = .currentRun,
        scopeSkills: [String] = [],
        pattern: TraceEventPatternQuery,
        bound: TraceStatisticalBound,
        denominator: TraceStatisticalDenominator,
        window: Duration? = nil,
        confidencePercent: Double? = nil
    ) {
        self.scope = scope
        self.scopeSkills = scopeSkills
        self.pattern = pattern
        self.bound = bound
        self.denominator = denominator
        self.window = window
        self.confidencePercent = confidencePercent
    }
}

public struct TraceEvaluationContext: Sendable {
    public let runID: String?
    public let skillName: String
    public let evaluationInstant: Date
    public let sampleFloor: Int
    /// When set, bounded-future monitors measure from this instant; otherwise the
    /// monitor starts at `evaluationInstant` (assert-time semantics).
    public let monitorStart: Date?

    public init(
        runID: String?,
        skillName: String,
        evaluationInstant: Date,
        sampleFloor: Int = 0,
        monitorStart: Date? = nil
    ) {
        self.runID = runID
        self.skillName = skillName
        self.evaluationInstant = evaluationInstant
        self.sampleFloor = sampleFloor
        self.monitorStart = monitorStart
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
                scopeSkills: temporal.scopeSkills,
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
                scopeSkills: temporal.scopeSkills,
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
                scopeSkills: temporal.scopeSkills,
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
                scopeSkills: temporal.scopeSkills,
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

        case .sinceLast(let anchor, let holds, let holdsStatePredicateJSON, let holdsUsesStateHistory):
            let anchors = try await matchingRecords(
                pattern: anchor,
                scope: temporal.scope,
                scopeSkills: temporal.scopeSkills,
                window: TraceWindow(end: context.evaluationInstant),
                store: store,
                context: context
            )
            guard let lastAnchor = anchors.last else {
                return TraceReplayResult(truthValue: .indeterminate, witnessEventIDs: [])
            }
            if holdsUsesStateHistory {
                let snapshots = try await stateSnapshots(
                    scope: temporal.scope,
                    scopeSkills: temporal.scopeSkills,
                    window: TraceWindow(end: context.evaluationInstant),
                    store: store,
                    context: context
                ).filter { strictlyAfter($0, anchor: lastAnchor, scope: temporal.scope) }
                guard !snapshots.isEmpty else {
                    return TraceReplayResult(truthValue: .indeterminate, witnessEventIDs: witnessIDs(for: [lastAnchor]))
                }
                let allMatch = snapshots.allSatisfy {
                    stateSnapshotMatchesPredicateJSON(holdsStatePredicateJSON, record: $0)
                }
                return TraceReplayResult(
                    truthValue: .from(allMatch),
                    witnessEventIDs: witnessIDs(for: [lastAnchor] + snapshots)
                )
            }
            guard let holds else {
                return TraceReplayResult(truthValue: .indeterminate, witnessEventIDs: witnessIDs(for: [lastAnchor]))
            }
            let trailing = try await qualifyingRecords(
                for: holds,
                scope: temporal.scope,
                scopeSkills: temporal.scopeSkills,
                window: TraceWindow(end: context.evaluationInstant),
                store: store,
                context: context
            ).filter { strictlyAfter($0, anchor: lastAnchor, scope: temporal.scope) }
            let truthValue: TruthValue = holds.negated
                ? .from(trailing.isEmpty)
                : .from(trailing.allSatisfy { fullMatch($0, pattern: holds) })
            return TraceReplayResult(
                truthValue: truthValue,
                witnessEventIDs: witnessIDs(for: [lastAnchor] + trailing)
            )

        case .boundedFutureMonitor(let conditionJSON, let horizon, let mode):
            let monitorStart = context.monitorStart ?? context.evaluationInstant
            let horizonEnd = monitorStart.addingTimeInterval(horizon.timeInterval)
            guard context.evaluationInstant >= horizonEnd else {
                return TraceReplayResult(truthValue: .indeterminate, witnessEventIDs: [])
            }
            let window = TraceWindow(start: monitorStart, end: horizonEnd)
            guard let condition = BoundedFutureCondition.decode(conditionJSON) else {
                return TraceReplayResult(truthValue: .indeterminate, witnessEventIDs: [])
            }
            switch condition {
            case .state(let fields):
                let snapshots = try await stateSnapshots(
                    scope: temporal.scope,
                    scopeSkills: temporal.scopeSkills,
                    window: window,
                    store: store,
                    context: context
                )
                let matching = snapshots.filter { snapshotMatchesStateFields(fields, record: $0) }
                let truthValue: TruthValue
                switch mode {
                case .eventuallyWithin:
                    truthValue = .from(!matching.isEmpty)
                case .alwaysFor:
                    truthValue = snapshots.isEmpty ? .indeterminate : .from(matching.count == snapshots.count)
                }
                return TraceReplayResult(
                    truthValue: truthValue,
                    witnessEventIDs: witnessIDs(for: matching)
                )
            case .event(let pattern):
                let records = try await qualifyingRecords(
                    for: pattern,
                    scope: temporal.scope,
                    scopeSkills: temporal.scopeSkills,
                    window: window,
                    store: store,
                    context: context
                )
                let matches = records.filter { fullMatch($0, pattern: pattern) }
                let truthValue: TruthValue
                switch mode {
                case .eventuallyWithin:
                    truthValue = .from(!matches.isEmpty)
                case .alwaysFor:
                    truthValue = records.isEmpty ? .indeterminate : .from(matches.count == records.count)
                }
                return TraceReplayResult(
                    truthValue: truthValue,
                    witnessEventIDs: witnessIDs(for: matches)
                )
            }
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
            scopeSkills: statistical.scopeSkills,
            window: window,
            store: store,
            context: context
        )
        let witnessRecords: [TraceRecord]
        let (successes, sampleSize): (Int, Int)
        switch statistical.denominator {
        case .occurrences:
            sampleSize = records.count
            successes = records.filter { fullMatch($0, pattern: statistical.pattern) }.count
            witnessRecords = records
        case .runs:
            let perRun = Dictionary(grouping: records, by: \.run)
            let lastPerRun = perRun.values.compactMap { runRecords in
                runRecords.max { lhs, rhs in
                    TraceRecordOrdering.crossRun(lhs, rhs)
                }
            }
            sampleSize = lastPerRun.count
            successes = lastPerRun.filter { fullMatch($0, pattern: statistical.pattern) }.count
            witnessRecords = lastPerRun
        }
        return statisticalTruthValue(
            successes: successes,
            sampleSize: sampleSize,
            bound: statistical.bound,
            confidencePercent: statistical.confidencePercent,
            sampleFloor: context.sampleFloor,
            witnessRecords: witnessRecords
        )
    }

    private static func statisticalTruthValue(
        successes: Int,
        sampleSize: Int,
        bound: TraceStatisticalBound,
        confidencePercent: Double?,
        sampleFloor: Int,
        witnessRecords: [TraceRecord]
    ) -> TraceReplayResult {
        guard sampleSize >= sampleFloor else {
            return TraceReplayResult(
                truthValue: .indeterminate,
                witnessEventIDs: witnessIDs(for: witnessRecords)
            )
        }
        let ratio = sampleSize == 0 ? 0 : Double(successes) / Double(sampleSize)
        let truthValue: TruthValue
        if let confidence = confidencePercent {
            guard let interval = WilsonScore.interval(
                successes: successes,
                sampleSize: sampleSize,
                confidencePercent: confidence
            ) else {
                return TraceReplayResult(
                    truthValue: .indeterminate,
                    witnessEventIDs: witnessIDs(for: witnessRecords)
                )
            }
            switch bound {
            case .atLeast(let threshold):
                truthValue = .from(interval.lower >= threshold)
            case .atMost(let threshold):
                truthValue = .from(interval.upper <= threshold)
            }
        } else {
            switch bound {
            case .atLeast(let threshold):
                truthValue = .from(ratio >= threshold)
            case .atMost(let threshold):
                truthValue = .from(ratio <= threshold)
            }
        }
        return TraceReplayResult(
            truthValue: truthValue,
            witnessEventIDs: witnessIDs(for: witnessRecords)
        )
    }

    private static func scopeSkills(for scope: TraceScope, explicit: [String]) -> [String] {
        switch scope {
        case .acrossSkills:
            return explicit
        case .currentRun, .acrossAllRuns:
            return []
        }
    }

    private static func runtimeScope(_ scope: TraceScope) -> TraceScope {
        scope
    }

    private static func stateSnapshots(
        scope: TraceScope,
        scopeSkills: [String],
        window: TraceWindow?,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        try await store.query(
            scope: scope,
            scopeSkills: scopeSkills,
            runID: context.runID,
            skillName: context.skillName,
            window: window,
            pattern: TraceQueryPattern(tags: [.stateSnapshot])
        )
    }

    private static func snapshotMatchesStateFields(_ fields: [String: Value], record: TraceRecord) -> Bool {
        guard let payload = record.payload else { return false }
        for (key, expected) in fields where payload[key] != expected {
            return false
        }
        return true
    }

    private static func stateSnapshotMatchesPredicateJSON(_ json: String?, record: TraceRecord) -> Bool {
        guard let json, let payload = record.payload else { return false }
        guard let data = json.data(using: .utf8),
              let expected = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        for (key, value) in expected {
            guard let actual = payload[key] else { return false }
            switch value {
            case let string as String:
                if case .string(let got) = actual, got == string { continue }
                return false
            case let number as Double:
                if case .number(let got) = actual, Double(truncating: got as NSNumber) == number { continue }
                return false
            case let boolean as Bool:
                if case .boolean(let got) = actual, got == boolean { continue }
                return false
            default:
                return false
            }
        }
        return true
    }

    private static func matchingRecords(
        pattern: TraceEventPatternQuery,
        scope: TraceScope,
        scopeSkills: [String],
        window: TraceWindow?,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        let broad = try await baseRecords(
            pattern: pattern,
            scope: scope,
            scopeSkills: scopeSkills,
            window: window,
            store: store,
            context: context
        )
        return broad.filter { fullMatch($0, pattern: pattern) }
    }

    private static func qualifyingRecords(
        for pattern: TraceEventPatternQuery,
        scope: TraceScope,
        scopeSkills: [String],
        window: TraceWindow?,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        let broad = try await baseRecords(
            pattern: pattern,
            scope: scope,
            scopeSkills: scopeSkills,
            window: window,
            store: store,
            context: context
        )
        return broad.filter { qualifiesIgnoringOutcome($0, pattern: pattern) }
    }

    private static func baseRecords(
        pattern: TraceEventPatternQuery,
        scope: TraceScope,
        scopeSkills: [String],
        window: TraceWindow?,
        store: any TraceStore,
        context: TraceEvaluationContext
    ) async throws -> [TraceRecord] {
        try await store.query(
            scope: scope,
            scopeSkills: scopeSkills,
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
        case .acrossAllRuns, .acrossSkills:
            return TraceRecordOrdering.crossRun(anchor, record)
        }
    }

    private static func witnessIDs(for records: [TraceRecord]) -> [String] {
        records.map(\.id).sorted()
    }
}
