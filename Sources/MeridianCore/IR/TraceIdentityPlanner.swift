import Foundation
import MeridianRuntime

enum TraceIdentityPlanner {
    static func skillVersionHash(
        meridianSource: String,
        vocabularies: [Compiler.VocabularyInput],
        rulebooks: [RulebookInput]
    ) throws -> String {
        let payload: [String: Value] = [
            "ir_version": .string(MERIDIAN_IR_VERSION),
            "source": .string(normalizeText(meridianSource)),
            "vocabularies": .list(vocabularies.map {
                .record([
                    "name": .string($0.name),
                    "file": .string($0.file),
                    "source": .string(normalizeText($0.source))
                ])
            }),
            "rulebooks": .list(rulebooks.map {
                .record([
                    "name": .string($0.name),
                    "file": .string($0.file),
                    "source": .string(normalizeText($0.source))
                ])
            })
        ]
        return try CanonicalJSON.sha256Hex(for: payload)
    }

    static func runtimeTraceConfiguration(
        from config: MerConfigFile,
        skillName: String,
        skillVersionHash: String,
        workflows: [IRWorkflow] = []
    ) -> RuntimeTraceConfiguration {
        let ast = config.traceConfiguration
        // D8/SEM-4-07: `.auto` resolves at compile time to `.failClosed` so
        // `Runtime` never sees an unresolved `.auto` (which would otherwise
        // behave as fail-open). Explicit `.failOpen` / `.failClosed` are
        // preserved verbatim.
        let declaredPolicy = ast.storeFailurePolicy?.value ?? .auto
        let resolvedPolicy: TraceStoreFailurePolicy = declaredPolicy == .auto
            ? .failClosed
            : declaredPolicy
        let trace = TraceConfiguration(
            retention: ast.retention?.value ?? .seconds(60 * 60 * 24 * 30),
            hashChaining: ast.hashChaining?.value ?? true,
            payloadLimit: ast.payloadLimit?.value,
            usuallyThreshold: ast.usuallyThreshold?.value ?? 0.9,
            rarelyThreshold: ast.rarelyThreshold?.value ?? 0.1,
            sampleFloor: ast.sampleFloor?.value ?? 20,
            defaultMonitorCadence: ast.defaultMonitorCadence?.value ?? .seconds(60 * 60 * 24),
            profile: ast.profile?.value ?? .development,
            storeFailurePolicy: resolvedPolicy,
            deploymentZone: ast.deploymentZone?.value ?? "UTC"
        )
        let toolPolicies = config.tools.reduce(into: ast.toolCapturePolicies.mapValues(\.value)) { result, tool in
            if let capture = tool.capturePolicy {
                result[tool.methodName] = capture
            }
        }
        return RuntimeTraceConfiguration(
            store: ast.store?.value ?? .memory,
            trace: trace,
            skillIdentity: TraceSkillIdentity(name: skillName, versionHash: skillVersionHash),
            toolCapturePolicies: toolPolicies
        )
    }

    static func annotate(
        workflows: [IRWorkflow],
        skillSections: [SkillSectionRecord],
        runtimeTraceConfiguration: RuntimeTraceConfiguration
    ) throws -> [IRWorkflow] {
        let sectionIndex = SectionIndex(skillSections: skillSections)
        return try workflows.map { workflow in
            var ordinalByCandidate: [String: Int] = [:]
            let body = try annotateBlock(
                workflow.body,
                workflow: workflow,
                sectionIndex: sectionIndex,
                nestedRoles: [],
                ordinalByCandidate: &ordinalByCandidate
            )
            return IRWorkflow(
                name: workflow.name,
                parameters: workflow.parameters,
                body: body,
                mode: workflow.mode,
                sourceFile: workflow.sourceFile,
                sourceRange: workflow.sourceRange,
                explicitStructName: workflow.explicitStructName,
                allowsDiscretion: workflow.allowsDiscretion,
                skillName: runtimeTraceConfiguration.skillIdentity.name,
                skillVersionHash: runtimeTraceConfiguration.skillIdentity.versionHash,
                runtimeTraceConfiguration: runtimeTraceConfiguration
            )
        }
    }

    private static func annotateBlock(
        _ block: IRBlock,
        workflow: IRWorkflow,
        sectionIndex: SectionIndex,
        nestedRoles: [String],
        ordinalByCandidate: inout [String: Int]
    ) throws -> IRBlock {
        let statements = try block.statements.map { primitive in
            let section = sectionIndex.section(for: primitive.sourceRange.startLine)
            let rolePath = [section.role] + nestedRoles
            let fingerprint = try primitiveFingerprint(primitive)
            let base = "/" + ([workflow.structName, section.slug] + rolePath + [fingerprint]).joined(separator: "/")
            let ordinal = ordinalByCandidate[base, default: 0] + 1
            ordinalByCandidate[base] = ordinal
            let stableStepPath = ordinal == 1 ? base : "\(base)~\(ordinal)"
            return try annotatePrimitive(
                primitive,
                workflow: workflow,
                sectionIndex: sectionIndex,
                stableStepPath: stableStepPath,
                ordinalByCandidate: &ordinalByCandidate
            )
        }
        return IRBlock(statements: statements, sourceRange: block.sourceRange)
    }

    private static func annotatePrimitive(
        _ primitive: IRPrimitive,
        workflow: IRWorkflow,
        sectionIndex: SectionIndex,
        stableStepPath: String,
        ordinalByCandidate: inout [String: Int]
    ) throws -> IRPrimitive {
        switch primitive {
        case .invoke(let ir):
            return .invoke(InvokeIR(
                toolID: ir.toolID,
                arguments: ir.arguments,
                resultBinding: ir.resultBinding,
                comment: ir.comment,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .bind(let ir):
            return .bind(BindIR(
                name: ir.name,
                expression: ir.expression,
                isRebind: ir.isRebind,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .branch(let ir):
            let thenBlock = try annotateBlock(
                ir.thenBlock,
                workflow: workflow,
                sectionIndex: sectionIndex,
                nestedRoles: ["branch.then"],
                ordinalByCandidate: &ordinalByCandidate
            )
            let elseBlock = try ir.elseBlock.map {
                try annotateBlock(
                    $0,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["branch.else"],
                    ordinalByCandidate: &ordinalByCandidate
                )
            }
            return .branch(BranchIR(
                condition: ir.condition,
                thenBlock: thenBlock,
                unknownBlock: try ir.unknownBlock.map {
                    try annotateBlock(
                        $0,
                        workflow: workflow,
                        sectionIndex: sectionIndex,
                        nestedRoles: ["branch.unknown"],
                        ordinalByCandidate: &ordinalByCandidate
                    )
                },
                elseBlock: elseBlock,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .iterate(let ir):
            return .iterate(IterateIR(
                mode: ir.mode,
                body: try annotateBlock(
                    ir.body,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["iterate.body"],
                    ordinalByCandidate: &ordinalByCandidate
                ),
                source: ir.source,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .assert(let ir):
            let otherwiseAction = try ir.otherwiseAction.map {
                try annotateBlock(
                    $0,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["assert.otherwise"],
                    ordinalByCandidate: &ordinalByCandidate
                )
            }
            return .assert(AssertIR(
                condition: ir.condition,
                message: ir.message,
                otherwiseAction: otherwiseAction,
                monitored: ir.monitored,
                cadence: ir.cadence,
                blocking: ir.blocking,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .emit(let ir):
            return .emit(EmitIR(
                eventID: ir.eventID,
                payload: ir.payload,
                strict: ir.strict,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .wait(let ir):
            return .wait(WaitIR(
                condition: ir.condition,
                timeout: ir.timeout,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .commit(let ir):
            return .commit(CommitIR(
                label: ir.label,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .recover(let ir):
            return .recover(RecoverIR(
                pattern: ir.pattern,
                handler: try annotateBlock(
                    ir.handler,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["recover.handler"],
                    ordinalByCandidate: &ordinalByCandidate
                ),
                attachedTo: try annotateBlock(
                    ir.attachedTo,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["recover.body"],
                    ordinalByCandidate: &ordinalByCandidate
                ),
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .simultaneously(let ir):
            let branches = try ir.branches.map {
                try annotateBlock(
                    $0,
                    workflow: workflow,
                    sectionIndex: sectionIndex,
                    nestedRoles: ["simultaneously.branch"],
                    ordinalByCandidate: &ordinalByCandidate
                )
            }
            return .simultaneously(SimultaneouslyIR(
                branches: branches,
                detached: ir.detached,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        case .aiJudgment(let ir):
            return .aiJudgment(AIJudgmentIR(
                text: ir.text,
                scopedTools: ir.scopedTools,
                snapshotKeys: ir.snapshotKeys,
                sourceRange: ir.sourceRange,
                guidance: ir.guidance,
                stableStepPath: stableStepPath,
                outputKind: ir.outputKind
            ))
        case .aiAutonomy(let ir):
            return .aiAutonomy(AIAutonomyIR(
                text: ir.text,
                scopedTools: ir.scopedTools,
                snapshotKeys: ir.snapshotKeys,
                autonomy: ir.autonomy,
                sourceRange: ir.sourceRange,
                guidance: ir.guidance,
                stableStepPath: stableStepPath,
                outputKind: ir.outputKind
            ))
        case .complete(let ir):
            return .complete(CompleteIR(
                reason: ir.reason,
                sourceRange: ir.sourceRange,
                stableStepPath: stableStepPath
            ))
        }
    }

    private static func primitiveFingerprint(_ primitive: IRPrimitive) throws -> String {
        try CanonicalJSON.sha256Hex(for: ["primitive": primitiveValue(primitive)])
    }

    private static func primitiveValue(_ primitive: IRPrimitive) -> Value {
        switch primitive {
        case .invoke(let ir):
            return .record([
                "kind": .string("invoke"),
                "tool_id": .string(ir.toolID),
                "arguments": .list(ir.arguments.map { .record(["key": .string($0.key), "value": expressionValue($0.value)]) }),
                "result_binding": ir.resultBinding.map(Value.string) ?? .null
            ])
        case .bind(let ir):
            return .record([
                "kind": .string("bind"),
                "name": .string(ir.name),
                "expression": expressionValue(ir.expression),
                "is_rebind": .boolean(ir.isRebind)
            ])
        case .branch(let ir):
            return .record([
                "kind": .string("branch"),
                "condition": branchConditionValue(ir.condition),
                "then": blockValue(ir.thenBlock),
                "else": ir.elseBlock.map(blockValue) ?? .null
            ])
        case .iterate(let ir):
            return .record([
                "kind": .string("iterate"),
                "mode": iterateModeValue(ir.mode),
                "body": blockValue(ir.body),
                "source": ir.source.map(iterationRefinementValue) ?? .null
            ])
        case .assert(let ir):
            return .record([
                "kind": .string("assert"),
                "condition": expressionValue(ir.condition),
                "message": ir.message.map(Value.string) ?? .null,
                "otherwise": ir.otherwiseAction.map(blockValue) ?? .null,
                "monitored": .boolean(ir.monitored),
                "cadence": ir.cadence.map(durationValue) ?? .null,
                "blocking": .boolean(ir.blocking)
            ])
        case .emit(let ir):
            return .record([
                "kind": .string("emit"),
                "event_id": .string(ir.eventID),
                "payload": .list(ir.payload.map { .record(["key": .string($0.key), "value": expressionValue($0.value)]) }),
                "strict": .boolean(ir.strict)
            ])
        case .wait(let ir):
            return .record([
                "kind": .string("wait"),
                "condition": waitConditionValue(ir.condition),
                "timeout": ir.timeout.map(durationValue) ?? .null
            ])
        case .commit(let ir):
            return .record([
                "kind": .string("commit"),
                "label": ir.label.map(Value.string) ?? .null
            ])
        case .recover(let ir):
            return .record([
                "kind": .string("recover"),
                "pattern": errorPatternValue(ir.pattern),
                "handler": blockValue(ir.handler),
                "attached": blockValue(ir.attachedTo)
            ])
        case .simultaneously(let ir):
            return .record([
                "kind": .string("simultaneously"),
                "detached": .boolean(ir.detached),
                "branches": .list(ir.branches.map(blockValue))
            ])
        case .aiJudgment(let ir):
            return .record([
                "kind": .string("aiJudgment"),
                "text": .string(normalizeText(ir.text)),
                "scoped_tools": .list(ir.scopedTools.sorted().map(Value.string)),
                "snapshot_keys": .list(ir.snapshotKeys.sorted().map(Value.string)),
                "guidance": ir.guidance.map { .string(normalizeText($0)) } ?? .null
            ])
        case .aiAutonomy(let ir):
            return .record([
                "kind": .string("aiAutonomy"),
                "text": .string(normalizeText(ir.text)),
                "scoped_tools": .list(ir.scopedTools.sorted().map(Value.string)),
                "snapshot_keys": .list(ir.snapshotKeys.sorted().map(Value.string)),
                "guidance": ir.guidance.map { .string(normalizeText($0)) } ?? .null,
                "autonomy": autonomyValue(ir.autonomy)
            ])
        case .complete(let ir):
            return .record([
                "kind": .string("complete"),
                "reason": ir.reason.map(Value.string) ?? .null
            ])
        }
    }

    private static func blockValue(_ block: IRBlock) -> Value {
        .list(block.statements.map(primitiveValue))
    }

    private static func branchConditionValue(_ condition: BranchCondition) -> Value {
        switch condition {
        case .predicate(let expr):
            return .record(["kind": .string("predicate"), "expression": expressionValue(expr)])
        case .match(let expr, let cases):
            return .record([
                "kind": .string("match"),
                "expression": expressionValue(expr),
                "cases": .list(cases.map { .record(["pattern": patternValue($0.pattern), "block": blockValue($0.block)]) })
            ])
        }
    }

    private static func iterateModeValue(_ mode: IterateMode) -> Value {
        switch mode {
        case .overCollection(let parameter, let kind, let collection):
            return .record([
                "kind": .string("overCollection"),
                "parameter": .string(parameter),
                "collection_kind": .string(kind.name),
                "collection": expressionValue(collection)
            ])
        case .whileCondition(let expr):
            return .record(["kind": .string("whileCondition"), "expression": expressionValue(expr)])
        case .untilCondition(let expr):
            return .record(["kind": .string("untilCondition"), "expression": expressionValue(expr)])
        }
    }

    private static func iterationRefinementValue(_ refinement: IRIterationRefinement) -> Value {
        .record([
            "filters": .list(refinement.filters.map(expressionValue)),
            "sort": refinement.sort.map { .record(["path": .string($0.path), "ascending": .boolean($0.ascending)]) } ?? .null,
            "take": refinement.take.map { .number(Decimal($0)) } ?? .null
        ])
    }

    private static func waitConditionValue(_ condition: WaitConditionIR) -> Value {
        switch condition {
        case .duration(let duration):
            return .record(["kind": .string("duration"), "value": durationValue(duration)])
        case .signal(let name):
            return .record(["kind": .string("signal"), "name": .string(name)])
        case .approval(let expr, let approver):
            return .record(["kind": .string("approval"), "of": expressionValue(expr), "by": .string(approver)])
        case .event(let event, let matching):
            return .record(["kind": .string("event"), "event": .string(event), "matching": matching.map(expressionValue) ?? .null])
        case .choice(let prompt, let options):
            return .record(["kind": .string("choice"), "prompt": .string(prompt), "options": .list(options.map(Value.string))])
        }
    }

    private static func errorPatternValue(_ pattern: ErrorPattern) -> Value {
        switch pattern {
        case .anyError:
            return .record(["kind": .string("anyError")])
        case .named(let name):
            return .record(["kind": .string("named"), "name": .string(name)])
        case .typed(let kind):
            return .record(["kind": .string("typed"), "name": .string(kind.name)])
        case .predicate(let expr):
            return .record(["kind": .string("predicate"), "expression": expressionValue(expr)])
        }
    }

    private static func patternValue(_ pattern: IRPattern) -> Value {
        switch pattern {
        case .literal(let literal):
            return .record(["kind": .string("literal"), "value": literalValue(literal)])
        case .enumValue(let value, let kind):
            return .record(["kind": .string("enumValue"), "value": .string(value), "enum_kind": .string(kind)])
        case .wildcard:
            return .record(["kind": .string("wildcard")])
        }
    }

    private static func autonomyValue(_ autonomy: AutonomyConfigIR) -> Value {
        .record([
            "until": autonomy.until.map(expressionValue) ?? .null,
            "unless": autonomy.unless.map(expressionValue) ?? .null,
            "replan_after_failures": .number(Decimal(autonomy.replanAfterFailures)),
            "max_steps": .number(Decimal(autonomy.maxSteps))
        ])
    }

    private static func expressionValue(_ expression: IRExpression) -> Value {
        switch expression {
        case .literal(let literal):
            return .record(["kind": .string("literal"), "value": literalValue(literal)])
        case .constantRef(let name):
            return .record(["kind": .string("constantRef"), "name": .string(name)])
        case .identifierRef(let name):
            return .record(["kind": .string("identifierRef"), "name": .string(name)])
        case .instanceRef(let name):
            return .record(["kind": .string("instanceRef"), "name": .string(name)])
        case .propertyAccess(let base, let propertyName):
            return .record(["kind": .string("propertyAccess"), "base": expressionValue(base), "property": .string(propertyName)])
        case .relationTraversal(let base, let relationName, let target):
            return .record(["kind": .string("relationTraversal"), "base": expressionValue(base), "relation": .string(relationName), "target": target.map(expressionValue) ?? .null])
        case .comparison(let lhs, let op, let rhs):
            return .record(["kind": .string("comparison"), "op": .string(String(describing: op)), "lhs": expressionValue(lhs), "rhs": expressionValue(rhs)])
        case .logical(let op, let expressions):
            return .record(["kind": .string("logical"), "op": .string(String(describing: op)), "items": .list(expressions.map(expressionValue))])
        case .envVar(let name):
            return .record(["kind": .string("envVar"), "name": .string(name)])
        case .nowExpression:
            return .record(["kind": .string("nowExpression")])
        case .invocation(let invoke):
            return .record(["kind": .string("invocation"), "invoke": primitiveValue(.invoke(invoke))])
        case .interpolatedString(let segments):
            return .record(["kind": .string("interpolatedString"), "segments": .list(segments.map(interpolationValue))])
        case .recordList(let fields, let rows):
            return .record(["kind": .string("recordList"), "fields": .list(fields.map(Value.string)), "rows": .list(rows.map { .list($0.map(expressionValue)) })])
        case .tableLookup(let table, let keyColumn, let key, let valueColumn):
            return .record(["kind": .string("tableLookup"), "table": .string(table), "keyColumn": .string(keyColumn), "key": expressionValue(key), "valueColumn": .string(valueColumn)])
        case .definitionPredicate(let functionName, let subject):
            return .record(["kind": .string("definitionPredicate"), "function": .string(functionName), "subject": expressionValue(subject)])
        case .quantified(let quantifier):
            return .record(["kind": .string("quantified"), "value": quantifierValue(quantifier)])
        case .description(let description):
            return .record(["kind": .string("description"), "value": descriptionValue(description)])
        case .aggregate(let aggregate, let description):
            return .record(["kind": .string("aggregate"), "aggregate": .string(String(describing: aggregate)), "description": descriptionValue(description)])
        case .superlative(let superlative):
            return .record(["kind": .string("superlative"), "description": descriptionValue(superlative.description), "sortPath": .string(superlative.sortPath), "ascending": .boolean(superlative.ascending)])
        case .eventPattern(let pattern):
            let subject: Value
            switch pattern.subject {
            case .step(let name):
                subject = .record(["kind": .string("step"), "name": .string(name)])
            case .named(let name):
                subject = .record(["kind": .string("named"), "name": .string(name)])
            }
            return .record([
                "kind": .string("eventPattern"),
                "subject": subject,
                "outcome": .string(pattern.outcome.rawValue),
                "payload": pattern.payloadPredicate.map(expressionValue) ?? .null,
            ])
        case .traceTemporal(let temporal):
            return .record([
                "kind": .string("traceTemporal"),
                "scope": .string(String(describing: temporal.scope)),
                "value": traceTemporalValue(temporal),
            ])
        case .traceStatistical(let statistical):
            return .record([
                "kind": .string("traceStatistical"),
                "scope": .string(String(describing: statistical.scope)),
                "value": traceStatisticalValue(statistical),
            ])
        }
    }

    private static func traceTemporalValue(_ temporal: TraceTemporalIR) -> Value {
        switch temporal.kind {
        case .ever(let pattern):
            return .record(["kind": .string("ever"), "pattern": expressionValue(.eventPattern(pattern))])
        case .withinWindow(let pattern, let duration):
            return .record(["kind": .string("withinWindow"), "pattern": expressionValue(.eventPattern(pattern)), "duration": literalValue(.duration(duration))])
        case .countInWindow(let pattern, let comparator, let duration):
            let comparatorValue: Value
            switch comparator {
            case .atLeast(let value):
                comparatorValue = .record(["kind": .string("atLeast"), "value": .number(Decimal(value))])
            case .atMost(let value):
                comparatorValue = .record(["kind": .string("atMost"), "value": .number(Decimal(value))])
            case .exactly(let value):
                comparatorValue = .record(["kind": .string("exactly"), "value": .number(Decimal(value))])
            }
            return .record([
                "kind": .string("countInWindow"),
                "pattern": expressionValue(.eventPattern(pattern)),
                "comparator": comparatorValue,
                "duration": literalValue(.duration(duration)),
            ])
        case .inARow(let pattern, let count):
            return .record([
                "kind": .string("inARow"),
                "pattern": expressionValue(.eventPattern(pattern)),
                "count": .number(Decimal(count)),
            ])
        case .sinceLast(let anchor, let holds, _):
            return .record([
                "kind": .string("sinceLast"),
                "anchor": expressionValue(.eventPattern(anchor)),
                "holds": expressionValue(holds),
            ])
        }
    }

    private static func traceStatisticalValue(_ statistical: TraceStatisticalIR) -> Value {
        let subject: Value
        switch statistical.pattern.subject {
        case .step(let name):
            subject = .record(["kind": .string("step"), "name": .string(name)])
        case .named(let name):
            subject = .record(["kind": .string("named"), "name": .string(name)])
        }
        let outcome: Value = .string({
            switch statistical.outcome {
            case .succeeds: return "succeeds"
            case .fails: return "fails"
            }
        }())
        let bound: Value = {
            switch statistical.bound {
            case .atLeast(let ratio):
                return .record(["kind": .string("atLeast"), "ratio": .number(Decimal(ratio))])
            case .atMost(let ratio):
                return .record(["kind": .string("atMost"), "ratio": .number(Decimal(ratio))])
            }
        }()
        let denominator: Value = .string(statistical.denominator == .runs ? "runs" : "occurrences")
        return .record([
            "pattern": .record([
                "subject": subject,
                "payload": statistical.pattern.payloadPredicate.map(expressionValue) ?? .null
            ]),
            "outcome": outcome,
            "bound": bound,
            "denominator": denominator,
            "window": statistical.window.map(durationValue) ?? .null,
            "monitor_cadence": statistical.monitorCadence.map(durationValue) ?? .null,
            "blocking": .boolean(statistical.blocking),
            "subject_key": statistical.subjectKeyExpr.map(expressionValue) ?? .null
        ])
    }

    private static func quantifierValue(_ quantifier: QuantifierIR) -> Value {
        .record([
            "kind": quantifierKindValue(quantifier.kind),
            "description": descriptionValue(quantifier.description),
            "body": quantifier.body.map(expressionValue) ?? .null
        ])
    }

    private static func quantifierKindValue(_ kind: QuantifierKind) -> Value {
        switch kind {
        case .all: return .record(["kind": .string("all")])
        case .any: return .record(["kind": .string("any")])
        case .none: return .record(["kind": .string("none")])
        case .atLeast(let value): return .record(["kind": .string("atLeast"), "value": .number(Decimal(value))])
        case .atMost(let value): return .record(["kind": .string("atMost"), "value": .number(Decimal(value))])
        case .exactly(let value): return .record(["kind": .string("exactly"), "value": .number(Decimal(value))])
        }
    }

    private static func descriptionValue(_ description: DescriptionIR) -> Value {
        .record([
            "collection": expressionValue(description.collection),
            "elementVar": .string(description.elementVar),
            "filters": .list(description.filters.map(expressionValue)),
            "sort": description.sort.map { .record(["path": .string($0.path), "ascending": .boolean($0.ascending)]) } ?? .null,
            "take": description.take.map { .number(Decimal($0)) } ?? .null
        ])
    }

    private static func interpolationValue(_ segment: IRInterpolationSegment) -> Value {
        switch segment {
        case .literal(let text):
            return .record(["kind": .string("literal"), "text": .string(normalizeText(text))])
        case .expression(let expression):
            return .record(["kind": .string("expression"), "value": expressionValue(expression)])
        case .conditional(let condition, let then, let otherwise):
            return .record([
                "kind": .string("conditional"),
                "condition": expressionValue(condition),
                "then": .list(then.map(interpolationValue)),
                "otherwise": .list(otherwise.map(interpolationValue))
            ])
        case .forEach(let variable, let collection, let body):
            return .record([
                "kind": .string("forEach"),
                "variable": .string(variable),
                "collection": expressionValue(collection),
                "body": .list(body.map(interpolationValue))
            ])
        case .formatted(let expression, let formatter):
            return .record(["kind": .string("formatted"), "expression": expressionValue(expression), "formatter": .string(formatter)])
        case .shellEscapedExpression(let expression):
            return .record(["kind": .string("shellEscapedExpression"), "expression": expressionValue(expression)])
        }
    }

    private static func literalValue(_ literal: IRLiteral) -> Value {
        switch literal {
        case .string(let value):
            return .record(["kind": .string("string"), "value": .string(value)])
        case .number(let value):
            return .record(["kind": .string("number"), "value": .number(value)])
        case .boolean(let value):
            return .record(["kind": .string("boolean"), "value": .boolean(value)])
        case .money(let amount, let currency):
            return .record(["kind": .string("money"), "amount": .number(amount), "currency": .string(currency)])
        case .duration(let duration):
            return .record(["kind": .string("duration"), "value": durationValue(duration)])
        case .date(let date):
            return .record(["kind": .string("date"), "value": .string(ISO8601DateFormatter.meridianFormatter.string(from: date))])
        case .dateTime(let dateTime):
            return .record(["kind": .string("dateTime"), "value": .string(ISO8601DateFormatter.meridianFormatter.string(from: dateTime))])
        case .enumValue(let value, let kind):
            return .record(["kind": .string("enumValue"), "value": .string(value), "enum_kind": .string(kind)])
        }
    }

    private static func durationValue(_ duration: Duration) -> Value {
        .record([
            "seconds": .number(Decimal(duration.components.seconds)),
            "attoseconds": .number(Decimal(string: String(duration.components.attoseconds)) ?? 0)
        ])
    }

    private static func normalizeText(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

private struct SectionIndex {
    private let sections: [SectionEntry]

    init(skillSections: [SkillSectionRecord]) {
        // `SkillSectionRecord.line` is the heading's line, not the only line
        // owned by the section. Markdown section ownership continues through
        // the line before the next heading, so sorting the starts gives us the
        // same half-open ranges without persisting a redundant end line.
        self.sections = skillSections
            .map {
                SectionEntry(
                    slug: Self.slugify($0.heading),
                    role: $0.role.isEmpty ? "procedure" : $0.role,
                    startLine: $0.line
                )
            }
            .sorted { $0.startLine < $1.startLine }
    }

    func section(for line: Int) -> (slug: String, role: String) {
        guard line > 0 else { return ("root", "procedure") }
        if let section = sections.last(where: { $0.startLine <= line }) {
            return (section.slug, section.role)
        }
        return ("root", "procedure")
    }

    private struct SectionEntry {
        let slug: String
        let role: String
        let startLine: Int
    }

    private static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        let raw = String(scalars)
        let collapsed = raw
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "root" : collapsed
    }
}
