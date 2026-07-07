# Governance Resolver

Routes a governance/compliance operator request to the synthetic governance skill that owns it.

## Dispatch table

| trigger phrase | skill |
| --- | --- |
| grant access | grantaccess |
| review access requests | reviewrequests |
| rotate credentials | rotatecredentials |
| revoke stale access | revokestaleaccess |
| render access matrix | accessmatrix |
| audit policy coverage | policyaudit |
| escalate pending requests | escalatepending |
| classify resources | classifyresource |

## Workflow

Look up the skill corresponding to the trigger phrase and emit the selected
skill id.
