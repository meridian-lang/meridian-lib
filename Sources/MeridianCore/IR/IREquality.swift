import Foundation
import MeridianRuntime

/// Structural IR equality: the comparison rules live in `IRNormalizer`, which
/// folds each field exactly the way this type used to hand-code it (identifier
/// folding for name-like fields, plain `==` for the rest, provenance dropped).
/// Each overload below is therefore a normalization plus a plain `==`.
public enum IREquality {
    public static func structurallyEqual(_ a: [IRWorkflow], _ b: [IRWorkflow]) -> Bool {
        a.map { IRNormalizer.normalized($0) } == b.map { IRNormalizer.normalized($0) }
    }

    public static func structurallyEqual(_ a: IRWorkflow, _ b: IRWorkflow) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: IRBlock, _ b: IRBlock) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: IRParameter, _ b: IRParameter) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: LoweredDefinition, _ b: LoweredDefinition) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: IRPrimitive, _ b: IRPrimitive) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: IRExpression, _ b: IRExpression) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: InvokeIR, _ b: InvokeIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: InvokeArg, _ b: InvokeArg) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: EmitField, _ b: EmitField) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: BranchCondition, _ b: BranchCondition) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: EventPatternIR, _ b: EventPatternIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: EventPatternIR?, _ b: EventPatternIR?) -> Bool {
        a.map { IRNormalizer.normalized($0) } == b.map { IRNormalizer.normalized($0) }
    }

    public static func structurallyEqual(_ a: EventPatternIR.Subject, _ b: EventPatternIR.Subject) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: TraceTemporalIR, _ b: TraceTemporalIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: TraceStatisticalPatternIR, _ b: TraceStatisticalPatternIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: TraceStatisticalIR, _ b: TraceStatisticalIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: TraceTemporalKind, _ b: TraceTemporalKind) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: TraceStatisticalOutcomeIR, _ b: TraceStatisticalOutcomeIR) -> Bool {
        a == b
    }

    public static func structurallyEqual(_ a: TraceStatisticalBoundIR, _ b: TraceStatisticalBoundIR) -> Bool {
        a == b
    }

    public static func structurallyEqual(_ a: TraceCountComparatorIR, _ b: TraceCountComparatorIR) -> Bool {
        a == b
    }

    public static func structurallyEqual(_ a: BranchCase, _ b: BranchCase) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: IRPattern, _ b: IRPattern) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: IterateMode, _ b: IterateMode) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: IRIterationRefinement?, _ b: IRIterationRefinement?) -> Bool {
        a.map { IRNormalizer.normalized($0) } == b.map { IRNormalizer.normalized($0) }
    }

    public static func structurallyEqual(_ a: IRIterationRefinement, _ b: IRIterationRefinement) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: WaitConditionIR, _ b: WaitConditionIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: ErrorPattern, _ b: ErrorPattern) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: AutonomyConfigIR, _ b: AutonomyConfigIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: IRInterpolationSegment, _ b: IRInterpolationSegment) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: QuantifierIR, _ b: QuantifierIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: QuantifierKind, _ b: QuantifierKind) -> Bool {
        a == b
    }

    public static func structurallyEqual(_ a: DescriptionIR, _ b: DescriptionIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: SuperlativeIR, _ b: SuperlativeIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: IRLiteral, _ b: IRLiteral) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: ComparisonOp, _ b: ComparisonOp) -> Bool {
        a == b
    }

    public static func structurallyEqual(_ a: LogicalOp, _ b: LogicalOp) -> Bool {
        a == b
    }

    public static func structurallyEqual(_ a: IRExpression?, _ b: IRExpression?) -> Bool {
        a.map { IRNormalizer.normalized($0) } == b.map { IRNormalizer.normalized($0) }
    }

    public static func structurallyEqual(_ a: IRBlock?, _ b: IRBlock?) -> Bool {
        a.map { IRNormalizer.normalized($0) } == b.map { IRNormalizer.normalized($0) }
    }

    public static func structurallyEqual(_ a: DeonticGuardIR?, _ b: DeonticGuardIR?) -> Bool {
        a.map { IRNormalizer.normalized($0) } == b.map { IRNormalizer.normalized($0) }
    }

    public static func structurallyEqual(_ a: DeonticGuardIR, _ b: DeonticGuardIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: ActionPatternIR, _ b: ActionPatternIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: ActionArgumentConstraint, _ b: ActionArgumentConstraint) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: NormIR, _ b: NormIR) -> Bool {
        IRNormalizer.normalized(a) == IRNormalizer.normalized(b)
    }

    public static func structurallyEqual(_ a: ActionPatternIR?, _ b: ActionPatternIR?) -> Bool {
        a.map { IRNormalizer.normalized($0) } == b.map { IRNormalizer.normalized($0) }
    }

    /// Public surface for diagnostics that must mirror structural identifier
    /// comparison (articles / case / non-alphanumerics stripped).
    public static func identifiersEqual(_ a: String, _ b: String) -> Bool {
        IRNormalizer.normalizeIdentifier(a) == IRNormalizer.normalizeIdentifier(b)
    }
}
