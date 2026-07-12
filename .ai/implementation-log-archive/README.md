# Implementation log archive

Frozen snapshots moved from the root [`IMPLEMENTATION_LOG.md`](../../IMPLEMENTATION_LOG.md)
to keep the active log small for AI context budgets. **New entries always go in the
root file** — never append here.

When you need decision history, task context, phase audits, or rationale behind a
pattern, search **both** the active log and these archives (oldest → newest).

## Files

| File | Date range | Moved on |
|---|---|---|
| [`IMPLEMENTATION_LOG_2026-04-29_through_2026-07-03.md`](IMPLEMENTATION_LOG_2026-04-29_through_2026-07-03.md) | 2026-04-29 → 2026-07-03T12:38:40Z | 2026-07-04 |
| [`IMPLEMENTATION_LOG_2026-07-03_through_2026-07-11.md`](IMPLEMENTATION_LOG_2026-07-03_through_2026-07-11.md) | 2026-07-03T14:15:00Z → 2026-07-11T22:12:13Z | 2026-07-12 |

## How to search

1. Start with [`IMPLEMENTATION_LOG.md`](../../IMPLEMENTATION_LOG.md) for recent work.
2. If the topic predates the active entries, grep this folder:

```bash
rg -n "phrase or date" .ai/implementation-log-archive/
```

3. Many code comments and docs cite `IMPLEMENTATION_LOG.md` with a date or headline —
   use that timestamp to pick the right archive file.
