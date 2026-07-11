# Deviation: minion_orchestrator.meri

- Original: `minion-orchestrator/SKILL.md`
- Ported: `minion_orchestrator.meri`
- Tier: 2 (light edits)
- Similarity: 84%
- Lines: 303 -> 338 (+69 / -34)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- doc-section-marked

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L83 `Submit (CLI, operator or autopilot)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L125 `Control (MCP-callable)`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L245 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L275 `Anti-Patterns`: reference-documentation - Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L283 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 11/14 (79% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert markers (`(( inert ))`, target 0 — the migrator never emits these): 0
- Inert categories: reference-documentation=9, template=1, tools-metadata=1
- Judgment: 2 blocks, 0 lines
- canonical_drift: synonym=0, structure=0, desugar=0, meaning=234

### Inert section details
- L4 `Contract`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L23 `Route the Request: Shell Job vs Subagent`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L51 `Preconditions (read before submitting your first shell job)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L83 `Submit (CLI, operator or autopilot)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L108 `Monitor (agents or operator)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L125 `Control (MCP-callable)`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L154 `Phase 1: Submit`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L233 `Phase 5: Review Results`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L245 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L275 `Anti-Patterns`: reference-documentation — Marked `(( role: reference ))`: documentary content with no lowerable or AI-inference-cued signal.
- L283 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/minion-orchestrator/SKILL.md
+++ skills/minion_orchestrator.meri
@@ -44,18 +44,12 @@
 
 # Minion Orchestrator
 
-## Contract
+## Contract (( role: reference ))
 
 Minions is a Postgres-native job queue for durable, observable background work.
 This single skill handles two lanes:
 - Deterministic shell jobs (`gbrain jobs submit shell ...`)
 - LLM subagent jobs (`gbrain agent run ...`)
-
-When to route to Minions: durable, observable work that must survive restarts,
-fan out across many parallel tasks, or persist across sessions. Routing policy
-is defined in `skills/conventions/subagent-routing.md` — the project default is
-`pain_triggered` (native subagents first, Minions after specific pain signals
-fire); Mode A (all-through-Minions) is opt-in.
 
 Guarantees:
 - Jobs survive gateway restart (Postgres-backed)
@@ -64,8 +58,20 @@
 - Jobs can be paused, resumed, or cancelled at any time
 - Parent-child DAGs with configurable failure policies
 
-## Route the Request: Shell Job vs Subagent
-
+
+### Contract — steps (( role: reference ))
+
+When to route to Minions: durable, observable work that must survive restarts, fan out across many parallel tasks, or persist across sessions. Routing policy is defined in `skills/conventions/subagent-routing.md` — the project default is `pain_triggered` (native subagents first, Minions after specific pain signals fire); Mode A (all-through-Minions) is opt-in.
+
+## Route the Request: Shell Job vs Subagent (( role: reference ))
+
+If intent is ambiguous, ask one clarification:
+"Do you want a deterministic shell command job, or an LLM agent job?"
+
+
+### Route the Request: Shell Job vs Subagent — steps
+
+!!! table (( ai-discretion ))
 | Condition | Action |
 |---|---|
 | User asks for deterministic command/script run | Shell job (CLI: `gbrain jobs submit shell ...`) |
@@ -76,38 +82,48 @@
 | Needs restart durability/observability | Submit as Minion job |
 | Parallel work (2+ streams) | `gbrain agent run --fanout-manifest` or parent + child subagents |
 
-If intent is ambiguous, ask one clarification:
-"Do you want a deterministic shell command job, or an LLM agent job?"
-
 ## Shell Jobs (Deterministic Scripts)
 
+
+### Shell Jobs (Deterministic Scripts) — steps
+
+use judgment to follow the Shell Jobs (Deterministic Scripts) — steps guidance:
 Use for reproducible command execution, ETL steps, cron work, and scriptable
 tasks where no LLM reasoning loop is needed.
 
-### Preconditions (read before submitting your first shell job)
-
-- **`GBRAIN_ALLOW_SHELL_JOBS=1` must be set on the worker environment.**
-  Without it, the shell handler refuses to register and submissions sit in
-  `waiting` silently. Gate lives in `src/core/minions/handlers/shell.ts`.
+### Preconditions (read before submitting your first shell job) (( role: reference ))
+
 - **Security:** flipping `GBRAIN_ALLOW_SHELL_JOBS=1` authorizes arbitrary
   command execution on the worker. On a shared queue, this is a remote code
   execution surface. Treat as privileged infrastructure authorization.
-- **Execution mode — pick one:**
-  - **Postgres + daemon:** `gbrain jobs work` runs a persistent worker that
-    claims and executes jobs from the queue.
-  - **PGLite + --follow:** `gbrain jobs submit ... --follow` runs inline.
-    The daemon mode is not available on PGLite (exclusive file lock). See
-    `docs/guides/minions-shell-jobs.md`.
 - **MCP boundary:** shell-job submission is CLI-only. `submit_job name="shell"`
   over MCP throws an `OperationError` with code `permission_denied` ("'shell'
   jobs cannot be submitted over MCP") because `shell` is in `PROTECTED_JOB_NAMES`.
   Agents CAN observe shell jobs via `get_job` / `list_jobs` / `get_job_progress`
   (not protected), but cannot submit them. Operator or autopilot submits;
   agent observes.
-- **Verify setup:** after configuration, run `gbrain jobs stats` (CLI) to
+
+### Preconditions (read before submitting your first shell job) — steps
+
+- `GBRAIN_ALLOW_SHELL_JOBS=1` must be set on the worker environment.
+  Without it, the shell handler refuses to register and submissions sit in
+  `waiting` silently. Gate lives in `src/core/minions/handlers/shell.ts`.
+
+### Preconditions (read before submitting your first shell job) — steps 2
+
+> - **Execution mode — pick one:**
+  - Postgres + daemon: `gbrain jobs work` runs a persistent worker that
+    claims and executes jobs from the queue.
+  - PGLite + --follow: `gbrain jobs submit ... --follow` runs inline.
+    The daemon mode is not available on PGLite (exclusive file lock). See
+    `docs/guides/minions-shell-jobs.md`.
+
+### Preconditions (read before submitting your first shell job) — steps 3
+
+- Verify setup: after configuration, run `gbrain jobs stats` (CLI) to
   confirm the worker is registered and consuming the queue.
 
-### Submit (CLI, operator or autopilot)
+### Submit (CLI, operator or autopilot) (( role: reference ))
 
 Shell jobs take their command via `--params` as a JSON object with `cmd` (string)
 or `argv` (array), plus `cwd` and optional `env`.
@@ -132,7 +148,7 @@
 `--backoff-delay`, `--backoff-jitter`, `--timeout-ms`, `--idempotency-key`,
 `--dry-run`.
 
-### Monitor (agents or operator)
+### Monitor (agents or operator) (( role: reference ))
 
 These operations are MCP-callable and safe for agent use:
 
@@ -142,11 +158,14 @@
 get_job_progress ID
 ```
 
+
+### Monitor (agents or operator) — steps
+
 Check structured result fields (exit code, stdout/stderr tails, attempts,
 timings) from `get_job`. Use `gbrain jobs stats` (CLI) for worker/queue
 health dashboard.
 
-### Control (MCP-callable)
+### Control (MCP-callable) (( role: reference ))
 
 ```
 cancel_job id=ID
@@ -160,15 +179,22 @@
 
 ## Subagent Jobs (LLM Orchestration)
 
+
+### Subagent Jobs (LLM Orchestration) — steps
+
+use judgment to follow the Subagent Jobs (LLM Orchestration) — steps guidance:
 Use for open-ended reasoning, tool-using research, and fan-out synthesis.
 
-**User-facing entrypoint:** `gbrain agent run <prompt>` is the canonical way
+
+### Subagent Jobs (LLM Orchestration) — steps 2
+
+User-facing entrypoint: `gbrain agent run <prompt>` is the canonical way
 to submit subagent work. It handles the elevated-trust plumbing — `subagent`
 and `subagent_aggregator` are both in `PROTECTED_JOB_NAMES`, so direct MCP
 submission requires `{allowProtectedSubmit: true}`, which `gbrain agent run`
 supplies.
 
-## Phase 1: Submit
+## Phase 1: Submit (( role: reference ))
 
 ```
 gbrain agent run "Research Acme Corp revenue" --tools "search,query"
@@ -190,6 +216,10 @@
 and claims AFTER every child terminates. See
 `src/core/minions/handlers/subagent.ts` and
 `src/core/minions/handlers/subagent-aggregator.ts`.
+
+- `--follow` / `--no-follow` — stream logs + wait (default on TTY)
+
+### Phase 1: Submit — steps
 
 Flags (from `src/commands/agent.ts`):
 - `--subagent-def <name>` — named subagent definition
@@ -198,7 +228,9 @@
 - `--tools <csv>` — allow-listed brain tools (see above)
 - `--timeout-ms <N>` — hard timeout per job
 - `--fanout-manifest <file>` — N children + 1 aggregator
-- `--follow` / `--no-follow` — stream logs + wait (default on TTY)
+
+### Phase 1: Submit — steps 2
+
 - `--detach` — submit and return immediately
 
 Queue/priority/retry tuning is not exposed by `gbrain agent run`; submit the
@@ -241,16 +273,19 @@
 
 All lifecycle ops are MCP-callable.
 
-## Phase 5: Review Results
+## Phase 5: Review Results (( role: reference ))
 
 ```
 get_job ID                         # result, token counts, transcript
 ```
 
 Token accounting: every job tracks `tokens_input`, `tokens_output`, `tokens_cache_read`.
+
+### Phase 5: Review Results — steps
+
 Child tokens roll up to parent automatically on completion.
 
-## Output Format
+## Output Format (( role: template ))
 
 When reporting job status to the user:
 
@@ -280,7 +315,7 @@
 Total tokens so far: 4.3k
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: reference ))
 
 - Don't spawn a Minion for a single search query (use search tool directly)
 - Don't fire-and-forget without checking results
@@ -288,7 +323,7 @@
 - For subagent work, don't use `sessions_spawn` with `runtime: "subagent"` when Minions is available (use `gbrain agent run` instead)
 - Don't poll `get_job` in a tight loop (use `get_job_progress` for lightweight checks)
 
-## Tools Used
+## Tools Used (( role: tools ))
 
 - Submit a background job — `submit_job` (MCP, non-protected names only; shell jobs are CLI-only, subagent jobs via `gbrain agent run`)
 - Get job details — `get_job` (MCP)
```
