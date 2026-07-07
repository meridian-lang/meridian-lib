---
name: payment retry
description: Retry declined payments on unpaid invoices until they clear.
triggers:
  - "retry declined payments"
  - "reattempt invoice collection"
---

# Payment Retry

## When this applies
- "retry declined payments"
- "reattempt invoice collection"

## Workflow
1. fetch unpaid invoices.
2. Check: any unpaid invoices.
3. for each invoice:
  until it is not the case that the invoice is unpaid,
    1. collect payment for the invoice.
    2. recover where the error code equals "payment.declined":
      escalate the invoice.
4. Publish: "payment retry pass complete".

## Controls
Do not retry payments for a customer whose account is under manual review.
