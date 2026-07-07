# Clinical Resolver

Routes a clinical-safety operator request to the synthetic clinical skill that owns it.

## Dispatch table

| trigger phrase | skill |
| --- | --- |
| capture patient consent | consentcapture |
| review discharge | dischargereview |
| check dose count | dosecheck |
| administer medication | medicationadminister |
| render protocol | protocolrender |
| run shift handoff | shifthandoff |
| triage patient | triagepatient |
| monitor patient vitals | vitalsmonitor |

## Workflow

Look up the skill corresponding to the trigger phrase and emit the selected
skill id.
