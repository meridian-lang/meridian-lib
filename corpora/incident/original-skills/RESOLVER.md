# Incident Resolver

Routes an SRE on-call request to the synthetic incident skill that owns it.

## Dispatch table

| trigger phrase | skill |
| --- | --- |
| triage firing alerts | triagealert |
| roll back unhealthy deploys | rollbackdeploy |
| sweep service health | healthchecksweep |
| escalate open incidents | escalateincident |
| mitigate open incidents | mitigateincident |
| render postmortem | postmortemrender |
| run oncall handoff | oncallhandoff |
| watch alert cooldown | cooldownwatch |
| check release health | releasehealthsentinel |

## Workflow

Look up the skill corresponding to the trigger phrase and emit the selected
skill id.
