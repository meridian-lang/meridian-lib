/// The shared marker-first section-role decision. `SkillSectionBuilder.resolve`
/// (the authoritative compiler path) and `SkillMetrics.sectionExecutes` (the
/// reporting path) must agree on whether a heading executes; this is the single
/// source of that decision. Each caller supplies the heading-text derivation it
/// uses (`derivedRole` — builder: rulebook alias ?? builtin; metrics: builtin
/// only), consulted only when there is no authoritative `(( … ))` marker, and
/// layers its own retention / error / reporting policy on top.
enum SectionRoleResolver {

    struct Decision {
        /// The role candidate (marker role, or derived role), before any
        /// caller-specific retention filtering.
        let role: SkillSectionRole?
        let executes: Bool
        let recordedRole: String
        /// True when an authoritative marker decided the role (vs. heading
        /// derivation) — the builder retains the role on different rules per case.
        let fromMarker: Bool
        /// False ⇒ no authoritative marker and no derived role (unresolved).
        let resolved: Bool
    }

    static func decide(marker: SkillSectionRole.SectionMarker?, derivedRole: SkillSectionRole?) -> Decision {
        if let marker, marker.inert || marker.role != nil {
            let role = marker.role
            let executes = !marker.inert && (role?.isExecutable ?? false)
            return Decision(role: role, executes: executes,
                            recordedRole: role?.rawValue ?? "inert", fromMarker: true, resolved: true)
        }
        if let role = derivedRole {
            return Decision(role: role, executes: role.isExecutable,
                            recordedRole: role.rawValue, fromMarker: false, resolved: true)
        }
        return Decision(role: nil, executes: false, recordedRole: "inert", fromMarker: false, resolved: false)
    }
}
