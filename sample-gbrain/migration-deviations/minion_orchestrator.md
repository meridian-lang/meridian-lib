# Deviation: minion_orchestrator.meri

- Original: `minion-orchestrator/SKILL.md`
- Ported: `minion_orchestrator.meri`
- Tier: 1 (near-verbatim)
- Similarity: 95%
- Lines: 303 -> 303 (+15 / -15)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added

## Metrics
- Sections: 16/16 inert (100% inert ratio)
- Judgment: 0 blocks, 0 lines

## Unified diff

```diff
--- original-skills/minion-orchestrator/SKILL.md
+++ skills/minion_orchestrator.meri
@@ -44,7 +44,7 @@
 
 # Minion Orchestrator
 
-## Contract
+## Contract (( inert, role: invariants ))
 
 Minions is a Postgres-native job queue for durable, observable background work.
 This single skill handles two lanes:
@@ -64,7 +64,7 @@
 - Jobs can be paused, resumed, or cancelled at any time
 - Parent-child DAGs with configurable failure policies
 
-## Route the Request: Shell Job vs Subagent
+## Route the Request: Shell Job vs Subagent (( inert ))
 
 | Condition | Action |
 |---|---|
@@ -79,12 +79,12 @@
 If intent is ambiguous, ask one clarification:
 "Do you want a deterministic shell command job, or an LLM agent job?"
 
-## Shell Jobs (Deterministic Scripts)
+## Shell Jobs (Deterministic Scripts) (( inert ))
 
 Use for reproducible command execution, ETL steps, cron work, and scriptable
 tasks where no LLM reasoning loop is needed.
 
-### Preconditions (read before submitting your first shell job)
+### Preconditions (read before submitting your first shell job) (( inert ))
 
 - **`GBRAIN_ALLOW_SHELL_JOBS=1` must be set on the worker environment.**
   Without it, the shell handler refuses to register and submissions sit in
@@ -107,7 +107,7 @@
 - **Verify setup:** after configuration, run `gbrain jobs stats` (CLI) to
   confirm the worker is registered and consuming the queue.
 
-### Submit (CLI, operator or autopilot)
+### Submit (CLI, operator or autopilot) (( inert ))
 
 Shell jobs take their command via `--params` as a JSON object with `cmd` (string)
 or `argv` (array), plus `cwd` and optional `env`.
@@ -132,7 +132,7 @@
 `--backoff-delay`, `--backoff-jitter`, `--timeout-ms`, `--idempotency-key`,
 `--dry-run`.
 
-### Monitor (agents or operator)
+### Monitor (agents or operator) (( inert ))
 
 These operations are MCP-callable and safe for agent use:
 
@@ -146,7 +146,7 @@
 timings) from `get_job`. Use `gbrain jobs stats` (CLI) for worker/queue
 health dashboard.
 
-### Control (MCP-callable)
+### Control (MCP-callable) (( inert ))
 
 ```
 cancel_job id=ID
@@ -158,7 +158,7 @@
 
 Use idempotency keys for recurring shell workloads to avoid duplicate runs.
 
-## Subagent Jobs (LLM Orchestration)
+## Subagent Jobs (LLM Orchestration) (( inert ))
 
 Use for open-ended reasoning, tool-using research, and fan-out synthesis.
 
@@ -168,7 +168,7 @@
 submission requires `{allowProtectedSubmit: true}`, which `gbrain agent run`
 supplies.
 
-## Phase 1: Submit
+## Phase 1: Submit (( inert, role: procedure ))
 
 ```
 gbrain agent run "Research Acme Corp revenue" --tools "search,query"
@@ -205,7 +205,7 @@
 raw `subagent` handler via `gbrain jobs submit` (requires CLI trust) if you
 need those knobs.
 
-## Phase 2: Monitor
+## Phase 2: Monitor (( inert, role: procedure ))
 
 ```
 list_jobs --status active          # MCP — what's running?
@@ -217,7 +217,7 @@
 
 Progress includes: step count, total steps, message, token usage, last tool called.
 
-## Phase 3: Steer
+## Phase 3: Steer (( inert, role: procedure ))
 
 Send a message to redirect a running agent:
 ```
@@ -229,7 +229,7 @@
 
 Only the parent job or admin can send messages (sender validation).
 
-## Phase 4: Lifecycle
+## Phase 4: Lifecycle (( inert, role: procedure ))
 
 ```
 pause_job id=ID                    # freeze without losing state
@@ -241,7 +241,7 @@
 
 All lifecycle ops are MCP-callable.
 
-## Phase 5: Review Results
+## Phase 5: Review Results (( inert, role: procedure ))
 
 ```
 get_job ID                         # result, token counts, transcript
@@ -280,7 +280,7 @@
 Total tokens so far: 4.3k
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( inert, role: prohibitions ))
 
 - Don't spawn a Minion for a single search query (use search tool directly)
 - Don't fire-and-forget without checking results
@@ -288,7 +288,7 @@
 - For subagent work, don't use `sessions_spawn` with `runtime: "subagent"` when Minions is available (use `gbrain agent run` instead)
 - Don't poll `get_job` in a tight loop (use `get_job_progress` for lightweight checks)
 
-## Tools Used
+## Tools Used (( inert ))
 
 - Submit a background job — `submit_job` (MCP, non-protected names only; shell jobs are CLI-only, subagent jobs via `gbrain agent run`)
 - Get job details — `get_job` (MCP)
```
