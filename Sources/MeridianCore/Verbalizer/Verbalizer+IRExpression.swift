import Foundation
import MeridianRuntime

// MARK: - IRExpression verbalization

extension Verbalizer {
    public func verbalize(_ expr: IRExpression) -> String {
        switch expr {
        case .literal(let literal):
            return CanonicalForms.literal(literal)
        case .constantRef(let name):
            return surface.definiteArticle + CanonicalForms.words(fromIdentifier: name)
        case .identifierRef(let name):
            return CanonicalForms.words(fromIdentifier: name)
        case .instanceRef(let name):
            return surface.definiteArticle + CanonicalForms.words(fromIdentifier: name)
        case .propertyAccess(let base, let propertyName):
            return possessive(base: base, property: propertyName)
        case .relationTraversal(let base, let relationName, let target):
            if let target {
                return "\(verbalize(base)) \(CanonicalForms.words(fromIdentifier: relationName)) \(verbalize(target))"
            }
            return "\(verbalize(base)) \(CanonicalForms.words(fromIdentifier: relationName))"
        case .comparison(let lhs, let op, let rhs):
            return verbalizeComparison(lhs, op, rhs)
        case .logical(let op, let operands):
            return verbalizeLogical(op, operands)
        case .envVar(let name):
            return surface.envVarPrefix + name
        case .nowExpression:
            return surface.nowKeyword
        case .invocation(let invoke):
            return invokeInverter.surface(for: invoke, renderExpression: verbalize)
        case .interpolatedString(let segments):
            return CanonicalForms.quoted(interpolationText(segments))
        case .recordList(let fields, let rows):
            let header = fields.map(CanonicalForms.words(fromIdentifier:)).joined(separator: surface.tableCellSeparator)
            let renderedRows = rows.map { row in
                row.map(verbalize).joined(separator: surface.tableCellSeparator)
            }
            return ([header] + renderedRows).joined(separator: surface.recordListSeparator)
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return surface.definiteArticle
                + CanonicalForms.words(fromIdentifier: valueColumn)
                + grammar.tableLookup.correspondingToMarker
                + CanonicalForms.words(fromIdentifier: keyColumn)
                + " \(verbalize(key))"
                + grammar.tableLookup.inTableMarker
                + CanonicalForms.words(fromIdentifier: table)
        case .definitionPredicate(let functionName, let subject):
            if let record = definitionRecord(functionName: functionName) {
                return verbalize(subject) + surface.definitionPredicateCopula + record.adjective
            }
            return verbalize(subject) + surface.definitionPredicateCopula + CanonicalForms.words(fromIdentifier: functionName)
        case .quantified(let quantifier):
            return verbalizeQuantifier(quantifier)
        case .description(let description):
            return verbalizeDescription(description)
        case .aggregate(let kind, let description):
            switch kind {
            case .count:
                return surface.aggregateCountPrefix + verbalizeDescription(description)
            case .list:
                return surface.aggregateListPrefix + verbalizeDescription(description)
            }
        case .superlative(let superlative):
            let direction = superlative.ascending
                ? surface.superlativeSmallestLabel
                : surface.superlativeLargestLabel
            return surface.definiteArticle
                + direction
                + " \(verbalizeDescription(superlative.description))"
                + grammar.passiveByMarker
                + CanonicalForms.words(fromIdentifier: superlative.sortPath)
        case .eventPattern(let pattern):
            return verbalizeEventPattern(pattern)
        case .traceTemporal(let temporal):
            return verbalizeTraceTemporal(temporal)
        case .traceStatistical(let statistical):
            return verbalizeTraceStatistical(statistical)
        }
    }

    func verbalizeComparison(_ lhs: IRExpression, _ op: ComparisonOp, _ rhs: IRExpression) -> String {
        switch op {
        case .isEmpty, .isNotEmpty:
            return "\(verbalize(lhs)) \(CanonicalForms.comparison(op, lexicon: model.lexicon))"
        case .withinPast, .withinFuture:
            return "\(verbalize(lhs)) \(CanonicalForms.comparison(op, lexicon: model.lexicon)) \(verbalize(rhs))"
        case .equal, .notEqual, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual,
             .oneOf, .contains, .startsWith, .endsWith, .withinDuration,
             .matchesPattern, .identifies:
            return "\(verbalize(lhs)) \(CanonicalForms.comparison(op, lexicon: model.lexicon)) \(verbalize(rhs))"
        }
    }

    func verbalizeEventPattern(_ pattern: EventPatternIR) -> String {
        // `TraceEventPatternGrammar.parse`'s outcome-marker scan only accepts
        // the outcome verb as the very last token of the clause (a `whose …`
        // payload predicate, if any, must precede it — `subject whose … is …
        // outcome`); an outcome verb followed by a trailing `whose` clause
        // does not match either the infix or suffix marker form and silently
        // falls through to the quantifier `no …` ambiguity on reparse. So the
        // predicate must be verbalized before the outcome verb, not after.
        let negation = pattern.negated ? grammar.traceEventNegationPrefix : ""
        var text = negation + verbalizeEventPatternSubject(pattern)
        if let payloadPredicate = pattern.payloadPredicate {
            text += " " + grammar.iterationMarkers.whoseMarker.trimmingCharacters(in: .whitespaces) + " " + verbalize(payloadPredicate)
        }
        text += " " + pattern.outcome.rawValue
        return text
    }

    func verbalizeEventPatternSubject(_ pattern: EventPatternIR) -> String {
        let subject: String
        switch pattern.subject {
        case .step(let name):
            subject = surface.definiteArticle + name + " step"
        case .named(let name):
            subject = surface.definiteArticle + name
        }
        return subject
    }

    func verbalizeTraceTemporal(_ temporal: TraceTemporalIR) -> String {
        let scoped: (String) -> String = { body in
            switch temporal.scope {
            case .acrossAllRuns:
                return grammar.traceAcrossAllRunsMarker + body
            case .currentRun:
                return body
            case .acrossSkills(let skills):
                return grammar.traceAcrossSkillsMarker + skills.joined(separator: ", ") + ", " + body
            }
        }
        switch temporal.kind {
        case .ever(let pattern):
            var subjectSide = verbalizeEventPatternSubject(pattern)
            if let payloadPredicate = pattern.payloadPredicate {
                subjectSide += " " + grammar.iterationMarkers.whoseMarker.trimmingCharacters(in: .whitespaces) + " " + verbalize(payloadPredicate)
            }
            return scoped(subjectSide + grammar.traceHasEverMarker + pattern.outcome.rawValue)
        case .withinWindow(let pattern, let duration):
            return scoped(verbalizeEventPattern(pattern) + grammar.traceWithinLastMarker + CanonicalForms.duration(duration))
        case .countInWindow(let pattern, let comparator, let duration):
            let comparatorText: String
            switch comparator {
            case .atLeast(let value): comparatorText = "at least \(value) times"
            case .atMost(let value): comparatorText = "at most \(value) times"
            case .exactly(let value): comparatorText = "exactly \(value) times"
            }
            return scoped(verbalizeEventPattern(pattern) + " " + comparatorText + grammar.traceWithinLastMarker + CanonicalForms.duration(duration))
        case .inARow(let pattern, let count):
            return scoped(verbalizeEventPattern(pattern) + " \(count)" + grammar.traceInARowSuffix)
        case .sinceLast(let anchor, let holds, _, _):
            // `holdsPattern` is emitter/evaluator material; both the resolved
            // and unresolved-holds cases emit the same authored `holds` surface.
            if case .eventPattern(let pattern) = holds, pattern.negated {
                return scoped(grammar.traceSinceLastAnchorFirstMarker
                    + verbalizeEventPattern(anchor) + ", " + verbalize(holds))
            }
            return scoped(verbalize(holds) + grammar.traceSinceLastMarker + verbalizeEventPattern(anchor))
        case .boundedFutureMonitor(let condition, let horizon, let mode):
            let intro = mode == .eventuallyWithin
                ? grammar.traceEventuallyWithinMarker
                : grammar.traceAlwaysForMarker
            return scoped(intro + CanonicalForms.duration(horizon) + ", " + verbalize(condition))
        }
    }

    func verbalizeTraceStatistical(_ statistical: TraceStatisticalIR) -> String {
        let scoped: (String) -> String = { body in
            switch statistical.scope {
            case .acrossAllRuns:
                return grammar.traceAcrossAllRunsMarker + body
            case .currentRun:
                return body
            case .acrossSkills(let skills):
                return grammar.traceAcrossSkillsMarker + skills.joined(separator: ", ") + ", " + body
            }
        }
        var subject: String
        switch statistical.pattern.subject {
        case .step(let name):
            subject = surface.definiteArticle + name + " step"
        case .named(let name):
            subject = surface.definiteArticle + name
        }
        if let payloadPredicate = statistical.pattern.payloadPredicate {
            subject += " " + grammar.iterationMarkers.whoseMarker.trimmingCharacters(in: .whitespaces) + " " + verbalize(payloadPredicate)
        }
        let outcome = statistical.outcome == .succeeds
            ? grammar.traceStatisticalSuccessKeyword
            : grammar.traceStatisticalFailureKeyword
        let bound: String
        switch statistical.bound {
        case .atLeast(let ratio):
            bound = grammar.traceStatisticalAtLeastMarker + percentText(ratio) + grammar.traceStatisticalPercentOfMarker
        case .atMost(let ratio):
            bound = grammar.traceStatisticalAtMostMarker + percentText(ratio) + grammar.traceStatisticalPercentOfMarker
        }
        let denominator = statistical.denominator == .runs
            ? grammar.traceStatisticalRunsWord
            : grammar.traceStatisticalOccurrencesWord
        var body = subject + " " + outcome + bound + denominator
        if let window = statistical.window {
            body += grammar.traceWithinLastMarker + CanonicalForms.duration(window)
        }
        if let cadence = statistical.monitorCadence {
            body += grammar.traceStatisticalCheckedEveryMarker + CanonicalForms.duration(cadence)
        }
        if statistical.blocking {
            body += grammar.traceStatisticalBlockingSuffix
        }
        if let confidence = statistical.confidencePercent {
            let percent = confidence > 1 ? confidence : confidence * 100
            body += grammar.traceStatisticalWithConfidenceMarker + percentText(percent / 100) + "%" + grammar.traceStatisticalConfidenceSuffix
        }
        return scoped(body)
    }

    func percentText(_ ratio: Double) -> String {
        let percent = ratio * 100
        if percent.rounded() == percent {
            return "\(Int(percent))"
        }
        return "\(percent)"
    }

    func verbalizeLogical(_ op: LogicalOp, _ operands: [IRExpression]) -> String {
        let connectors = grammar.booleanConnectors
        switch op {
        case .and:
            return operands.map(verbalize).joined(separator: connectors.andMarker)
        case .or:
            guard operands.count > 1 else { return operands.first.map(verbalize) ?? surface.falsyLiteral }
            return connectors.eitherPrefix + operands.map(verbalize).joined(separator: connectors.orMarker)
        case .not:
            return connectors.notPrefix + (operands.first.map(verbalize) ?? surface.truthyLiteral)
        }
    }

    func verbalizeQuantifier(_ quantifier: QuantifierIR) -> String {
        let base = CanonicalForms.quantifier(quantifier.kind, noun: verbalizeDescription(quantifier.description))
        if let body = quantifier.body {
            if let phrase = quantifierBodyPhrase(body, elementVar: quantifier.description.elementVar) {
                return "\(base) \(phrase)"
            }
            if case .definitionPredicate(let functionName, let subject) = body,
               let record = definitionRecord(functionName: functionName),
               isLoopSubject(subject, elementVar: quantifier.description.elementVar)
                || isLoopSubject(unwrapLoopPropertySubject(subject, elementVar: quantifier.description.elementVar),
                                 elementVar: quantifier.description.elementVar) {
                return base + surface.definitionPredicateCopula + record.adjective
            }
            if case .propertyAccess(.identifierRef(let baseName), let property) = body,
               identifierMatches(baseName, quantifier.description.elementVar) {
                // Opaque boolean property (`orderHasInventoryReserved`) — emit
                // as `have <words>` so emptiness grammar can recover `has a`
                // only when the property is a plain noun; otherwise keep words.
                let words = CanonicalForms.words(fromIdentifier: property)
                if let stripped = stripLeadingHasWords(words) {
                    return "\(base) \(surface.quantifierBodyHaveMarker)\(stripped)"
                }
                return "\(base) \(surface.quantifierBodyHaveMarker)\(words)"
            }
            return "\(base) \(surface.quantifierBodyHaveMarker)\(verbalize(body))"
        }
        return base
    }

    func unwrapLoopPropertySubject(_ expression: IRExpression, elementVar: String) -> IRExpression {
        // Lowering sometimes wraps the element as `<element>.<camelElement>`
        // when spaced vs camel loop-var keys disagree; treat that as the element.
        if case .propertyAccess(let base, let property) = expression,
           case .identifierRef(let baseName) = base,
           identifierMatches(baseName, elementVar),
           identifierMatches(property, elementVar) {
            return base
        }
        return expression
    }

    func stripLeadingHasWords(_ words: String) -> String? {
        let lower = words.lowercased()
        // Bare `has` / `have` (no trailing space) are not stripable prefixes.
        // `CanonicalForms.words` collapses whitespace, so a `has ` / `have `
        // prefix always leaves a non-empty rest when it matches.
        for prefix in statement.possessionPrefixes where lower.hasPrefix(prefix) {
            return String(words.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    func verbalizeDescription(_ description: DescriptionIR) -> String {
        let adjectiveFilters = description.filters.compactMap {
            definitionAdjectiveFilter($0, elementVar: description.elementVar)
        }
        // A relation-backed `.identifies` filter (`services owned by the
        // user`) must round trip through the same `<participle> by
        // <operand>` verb-clause surface `QuantifierGrammar`/
        // `DescriptionGrammar` parse it from — never through the generic
        // `whose <property> identifies <operand>` filter rendering below,
        // since "identifies" is a pure IR comparison tag with no parser-side
        // surface form (it can't be reparsed back into a comparison at all).
        let verbClauseFilters = description.filters.compactMap {
            verbClauseFilterText($0, elementVar: description.elementVar)
        }
        let residualFilters = description.filters.filter {
            definitionAdjectiveFilter($0, elementVar: description.elementVar) == nil
                && verbClauseFilterText($0, elementVar: description.elementVar) == nil
        }
        var text = ([adjectiveFilters.joined(separator: " "), descriptionHead(description)]
            .filter { !$0.isEmpty })
            .joined(separator: " ")
        if !verbClauseFilters.isEmpty {
            text += " " + verbClauseFilters.joined(separator: " " + grammar.booleanConnectors.andMarker.trimmingCharacters(in: .whitespaces) + " ")
        }
        if !residualFilters.isEmpty {
            let whose = grammar.iterationMarkers.whoseMarker
            let andMarker = grammar.booleanConnectors.andMarker
            text += whose + residualFilters
                .map { verbalizeDescriptionFilter($0, elementVar: description.elementVar) }
                .joined(separator: andMarker)
        }
        if let sort = description.sort {
            let direction = sort.ascending ? surface.sortAscendingLabel : surface.sortDescendingLabel
            text += sortByMarker()
                + CanonicalForms.words(fromIdentifier: sort.path)
                + " "
                + direction
        }
        if let take = description.take {
            text = surface.takeTheFirstPrefix + "\(take) \(text)"
        }
        return text
    }

    func descriptionHead(_ description: DescriptionIR) -> String {
        if case .identifierRef(let name) = description.collection {
            return CanonicalForms.words(fromIdentifier: name)
        }
        return description.elementVar + surface.descriptionElementInMarker + verbalize(description.collection)
    }

    func verbalizeDescriptionFilter(_ expression: IRExpression, elementVar: String) -> String {
        switch expression {
        case .comparison(let lhs, let op, let rhs):
            switch op {
            case .isEmpty, .isNotEmpty:
                return "\(verbalizeLoopRelative(lhs, elementVar: elementVar)) \(CanonicalForms.comparison(op, lexicon: model.lexicon))"
            case .equal, .notEqual, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual,
                 .oneOf, .contains, .startsWith, .endsWith, .withinDuration, .withinPast,
                 .withinFuture, .matchesPattern, .identifies:
                return "\(verbalizeLoopRelative(lhs, elementVar: elementVar)) \(CanonicalForms.comparison(op, lexicon: model.lexicon)) \(verbalizeLoopRelative(rhs, elementVar: elementVar))"
            }
        case .logical(let op, let operands):
            let connectors = grammar.booleanConnectors
            switch op {
            case .and:
                return operands.map { verbalizeDescriptionFilter($0, elementVar: elementVar) }
                    .joined(separator: connectors.andMarker)
            case .or:
                return connectors.eitherPrefix
                    + operands.map { verbalizeDescriptionFilter($0, elementVar: elementVar) }
                    .joined(separator: connectors.orMarker)
            case .not:
                return connectors.notPrefix
                    + (operands.first.map { verbalizeDescriptionFilter($0, elementVar: elementVar) } ?? surface.truthyLiteral)
            }
        case .definitionPredicate(let functionName, let subject):
            if let record = definitionRecord(functionName: functionName),
               isLoopSubject(subject, elementVar: elementVar) {
                return record.adjective
            }
            return verbalize(expression)
        case .literal, .constantRef, .identifierRef, .instanceRef, .propertyAccess,
             .relationTraversal, .envVar, .nowExpression, .invocation, .interpolatedString,
             .recordList, .tableLookup, .quantified, .description, .aggregate, .superlative,
             .eventPattern, .traceTemporal, .traceStatistical:
            return verbalizeLoopRelative(expression, elementVar: elementVar)
        }
    }

    func verbalizeLoopRelative(_ expression: IRExpression, elementVar: String) -> String {
        switch expression {
        case .propertyAccess(.identifierRef(let base), let property) where identifierMatches(base, elementVar):
            // Spaced words, not raw camelCase: reparse of `totalAmount` vs
            // `total amount` otherwise oscillates across verbalize passes.
            return CanonicalForms.words(fromIdentifier: property)
        case .identifierRef(let name) where name == elementVar:
            return CanonicalForms.words(fromIdentifier: name)
        case .comparison, .logical, .definitionPredicate:
            return verbalizeDescriptionFilter(expression, elementVar: elementVar)
        case .literal, .constantRef, .identifierRef, .instanceRef, .propertyAccess,
             .relationTraversal, .envVar, .nowExpression, .invocation, .interpolatedString,
             .recordList, .tableLookup, .quantified, .description, .aggregate, .superlative,
             .eventPattern, .traceTemporal, .traceStatistical:
            return verbalize(expression)
        }
    }

    func quantifierBodyPhrase(_ expression: IRExpression, elementVar: String) -> String? {
        guard case .comparison(let lhs, let op, _) = expression,
              case .propertyAccess(.identifierRef(let base), let property) = lhs,
              identifierMatches(base, elementVar) else {
            return nil
        }
        switch op {
        case .isNotEmpty:
            return emptinessBodyPhrase(isEmpty: false, property: property)
        case .isEmpty:
            return emptinessBodyPhrase(isEmpty: true, property: property)
        case .equal, .notEqual, .lessThan, .lessOrEqual, .greaterThan, .greaterOrEqual,
             .oneOf, .contains, .startsWith, .endsWith, .withinDuration, .withinPast,
             .withinFuture, .matchesPattern, .identifies:
            return nil
        }
    }

    /// Quantifier-body emptiness surface from lexicon `emptyMarkers` /
    /// `filledMarkers`. Prefers a `have …` form so reparse hits the same
    /// emptiness production the parser already keys on.
    func emptinessBodyPhrase(isEmpty: Bool, property: String) -> String {
        let markers = isEmpty ? model.lexicon.emptyMarkers : model.lexicon.filledMarkers
        let preferred = markers.first { $0.lowercased().contains("have") } ?? markers.first
        let verbPhrase = (preferred ?? (isEmpty ? " have no " : " have a "))
            .trimmingCharacters(in: .whitespaces)
        return "\(verbPhrase) \(CanonicalForms.words(fromIdentifier: property))"
    }

    func isLoopSubject(_ expression: IRExpression, elementVar: String) -> Bool {
        if case .identifierRef(let name) = expression {
            return identifierMatches(name, elementVar)
        }
        return false
    }

    func definitionAdjectiveFilter(_ expression: IRExpression, elementVar: String) -> String? {
        guard case .definitionPredicate(let functionName, let subject) = expression,
              let record = definitionRecord(functionName: functionName),
              isLoopSubject(subject, elementVar: elementVar) else {
            return nil
        }
        return record.adjective
    }

    /// Reverse a property-backed `.identifies` filter (`comparison(<loop
    /// var>.<property>, .identifies, <operand>)`) back into the declared
    /// verb's passive surface (`<pastParticiple> by <operand>`) that
    /// `DescriptionGrammar.parsePassiveClauseSuffix` parses it from. Returns
    /// `nil` when the filter isn't this shape or no declared verb covers the
    /// backing relation (falls back to the generic `whose` filter text).
    func verbClauseFilterText(_ expression: IRExpression, elementVar: String) -> String? {
        guard case .comparison(let lhs, .identifies, let rhs) = expression,
              case .propertyAccess(let base, let propertyName) = lhs,
              isLoopSubject(base, elementVar: elementVar) else { return nil }
        guard let relationName = model.symbols.relationBackings.first(where: { _, backing in
            if case .property(_, let path) = backing { return path.lowercased() == propertyName.lowercased() }
            return false
        })?.key else { return nil }
        guard let verb = model.symbols.verbs.values.first(where: { $0.relation == relationName }) else { return nil }
        return verb.pastParticiple + grammar.passiveByMarker + verbalizeLoopRelative(rhs, elementVar: elementVar)
    }

    func identifierMatches(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || normalizedIdentifier(lhs) == normalizedIdentifier(rhs)
    }

    func normalizedIdentifier(_ value: String) -> String {
        CanonicalForms.words(fromIdentifier: value)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }

    func possessive(base: IRExpression, property: String) -> String {
        let prop = CanonicalForms.words(fromIdentifier: property)
        switch base {
        case .identifierRef(let name):
            return surface.definiteArticle + CanonicalForms.words(fromIdentifier: name) + surface.possessiveSuffix + prop
        case .propertyAccess, .literal, .constantRef, .instanceRef, .relationTraversal,
             .comparison, .logical, .envVar, .nowExpression, .invocation,
             .interpolatedString, .recordList, .tableLookup, .definitionPredicate,
             .quantified, .description, .aggregate, .superlative, .eventPattern, .traceTemporal, .traceStatistical:
            return verbalize(base) + surface.possessiveSuffix + prop
        }
    }

    func definitionRecord(functionName: String) -> SymbolTable.DefinitionRecord? {
        model.symbols.definitions.values.first { $0.functionName == functionName }
    }

    func shellCommand(_ expr: IRExpression) -> String {
        switch expr {
        case .literal(.string(let command)):
            return command
        case .interpolatedString(let segments):
            return interpolationText(segments, holeStyle: .shell)
        case .literal, .constantRef, .identifierRef, .instanceRef, .propertyAccess,
             .relationTraversal, .comparison, .logical, .envVar, .nowExpression,
             .invocation, .recordList, .tableLookup, .definitionPredicate,
             .quantified, .description, .aggregate, .superlative, .eventPattern, .traceTemporal, .traceStatistical:
            return surface.shellHoleOpen + verbalize(expr) + surface.shellHoleClose
        }
    }

    enum InterpolationHoleStyle {
        case template
        case shell
    }

    func interpolationText(
        _ segments: [IRInterpolationSegment],
        holeStyle: InterpolationHoleStyle = .template
    ) -> String {
        let directives = grammar.templateDirectives
        return segments.map { segment in
            switch segment {
            case .literal(let value):
                return value
            case .expression(let expression), .shellEscapedExpression(let expression):
                return hole(verbalize(expression), style: holeStyle)
            case .conditional(let condition, let thenSegments, let otherwiseSegments):
                let thenText = interpolationText(thenSegments, holeStyle: holeStyle)
                let otherwiseText = interpolationText(otherwiseSegments, holeStyle: holeStyle)
                return "\(directives.ifPrefix)\(verbalize(condition))]"
                    + thenText
                    + directives.otherwiseTerminator
                    + otherwiseText
                    + directives.endIfTerminator
            case .forEach(let variable, let collection, let body):
                return "\(directives.forEachPrefix)\(variable)\(directives.loopInMarker)\(verbalize(collection))]"
                    + interpolationText(body, holeStyle: holeStyle)
                    + directives.endForTerminator
            case .formatted(let expression, let formatter):
                return hole(
                    "\(verbalize(expression))\(directives.formatAsMarker)\(formatter)",
                    style: holeStyle
                )
            }
        }.joined()
    }

    func hole(_ content: String, style: InterpolationHoleStyle) -> String {
        switch style {
        case .template:
            return surface.templateHoleOpen + content + surface.templateHoleClose
        case .shell:
            return surface.shellHoleOpen + content + surface.shellHoleClose
        }
    }

}
