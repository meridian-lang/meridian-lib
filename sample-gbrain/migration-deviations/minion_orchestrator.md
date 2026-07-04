# Deviation: minion_orchestrator.meri

- Original: `minion-orchestrator/SKILL.md`
- Ported: `minion_orchestrator.meri`
- Tier: 1 (near-verbatim)
- Similarity: 87%
- Lines: 303 -> 333 (+56 / -26)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed
- inert-section-added

## Inert deviations

These sections were made non-executable in the port and should be reviewed as migration deviations:
- L44 `Shell Jobs (Deterministic Scripts)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L79 `Submit (CLI, operator or autopilot)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L121 `Control (MCP-callable)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L133 `Subagent Jobs (LLM Orchestration)`: reference-documentation - Reference documentation, rationale, examples, or changelog.
- L239 `Output Format`: template - Template/output shape is metadata unless explicit output assertions are authored.
- L278 `Tools Used`: tools-metadata - Tools sections are metadata-mining, not workflow execution.

## Metrics
- Sections inert total: 8/16 (50% total inert; includes intentional docs/templates/tools metadata)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=6, template=1, tools-metadata=1
- Judgment: 8 blocks, 0 lines

### Inert section details
- L25 `Route the Request: Shell Job vs Subagent`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L44 `Shell Jobs (Deterministic Scripts)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L79 `Submit (CLI, operator or autopilot)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L104 `Monitor (agents or operator)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L121 `Control (MCP-callable)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L133 `Subagent Jobs (LLM Orchestration)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L239 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L278 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/minion-orchestrator/SKILL.md
+++ skills/minion_orchestrator.meri
@@ -44,7 +44,8 @@
 
 # Minion Orchestrator
 
-## Contract
+## Contract (( role: procedure ))
+use judgment to follow the Contract guidance:
 
 Minions is a Postgres-native job queue for durable, observable background work.
 This single skill handles two lanes:
@@ -64,8 +65,15 @@
 - Jobs can be paused, resumed, or cancelled at any time
 - Parent-child DAGs with configurable failure policies
 
-## Route the Request: Shell Job vs Subagent
-
+## Route the Request: Shell Job vs Subagent (( inert ))
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
@@ -76,15 +84,13 @@
 | Needs restart durability/observability | Submit as Minion job |
 | Parallel work (2+ streams) | `gbrain agent run --fanout-manifest` or parent + child subagents |
 
-If intent is ambiguous, ask one clarification:
-"Do you want a deterministic shell command job, or an LLM agent job?"
-
-## Shell Jobs (Deterministic Scripts)
+## Shell Jobs (Deterministic Scripts) (( inert ))
 
 Use for reproducible command execution, ETL steps, cron work, and scriptable
 tasks where no LLM reasoning loop is needed.
 
 ### Preconditions (read before submitting your first shell job)
+use judgment to follow the Preconditions (read before submitting your first shell job) guidance:
 
 - **`GBRAIN_ALLOW_SHELL_JOBS=1` must be set on the worker environment.**
   Without it, the shell handler refuses to register and submissions sit in
@@ -92,22 +98,28 @@
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
+#### Preconditions (read before submitting your first shell job) — steps
+
+> - **Execution mode — pick one:**
+  - Postgres + daemon: `gbrain jobs work` runs a persistent worker that
+    claims and executes jobs from the queue.
+  - PGLite + --follow: `gbrain jobs submit ... --follow` runs inline.
+    The daemon mode is not available on PGLite (exclusive file lock). See
+    `docs/guides/minions-shell-jobs.md`.
+
+#### Preconditions (read before submitting your first shell job) — steps 2
+
+- Verify setup: after configuration, run `gbrain jobs stats` (CLI) to
   confirm the worker is registered and consuming the queue.
 
-### Submit (CLI, operator or autopilot)
+### Submit (CLI, operator or autopilot) (( inert ))
 
 Shell jobs take their command via `--params` as a JSON object with `cmd` (string)
 or `argv` (array), plus `cwd` and optional `env`.
@@ -132,7 +144,7 @@
 `--backoff-delay`, `--backoff-jitter`, `--timeout-ms`, `--idempotency-key`,
 `--dry-run`.
 
-### Monitor (agents or operator)
+### Monitor (agents or operator) (( inert ))
 
 These operations are MCP-callable and safe for agent use:
 
@@ -142,11 +154,14 @@
 get_job_progress ID
 ```
 
+
+#### Monitor (agents or operator) — steps
+
 Check structured result fields (exit code, stdout/stderr tails, attempts,
 timings) from `get_job`. Use `gbrain jobs stats` (CLI) for worker/queue
 health dashboard.
 
-### Control (MCP-callable)
+### Control (MCP-callable) (( inert ))
 
 ```
 cancel_job id=ID
@@ -158,7 +173,7 @@
 
 Use idempotency keys for recurring shell workloads to avoid duplicate runs.
 
-## Subagent Jobs (LLM Orchestration)
+## Subagent Jobs (LLM Orchestration) (( inert ))
 
 Use for open-ended reasoning, tool-using research, and fan-out synthesis.
 
@@ -169,6 +184,7 @@
 supplies.
 
 ## Phase 1: Submit
+use judgment to follow the Phase 1: Submit guidance:
 
 ```
 gbrain agent run "Research Acme Corp revenue" --tools "search,query"
@@ -190,6 +206,14 @@
 and claims AFTER every child terminates. See
 `src/core/minions/handlers/subagent.ts` and
 `src/core/minions/handlers/subagent-aggregator.ts`.
+
+- `--follow` / `--no-follow` — stream logs + wait (default on TTY)
+Queue/priority/retry tuning is not exposed by `gbrain agent run`; submit the
+raw `subagent` handler via `gbrain jobs submit` (requires CLI trust) if you
+need those knobs.
+
+
+### Phase 1: Submit — steps
 
 Flags (from `src/commands/agent.ts`):
 - `--subagent-def <name>` — named subagent definition
@@ -198,14 +222,13 @@
 - `--tools <csv>` — allow-listed brain tools (see above)
 - `--timeout-ms <N>` — hard timeout per job
 - `--fanout-manifest <file>` — N children + 1 aggregator
-- `--follow` / `--no-follow` — stream logs + wait (default on TTY)
+
+### Phase 1: Submit — steps 2
+
 - `--detach` — submit and return immediately
 
-Queue/priority/retry tuning is not exposed by `gbrain agent run`; submit the
-raw `subagent` handler via `gbrain jobs submit` (requires CLI trust) if you
-need those knobs.
-
 ## Phase 2: Monitor
+use judgment to follow the Phase 2: Monitor guidance:
 
 ```
 list_jobs --status active          # MCP — what's running?
@@ -218,6 +241,7 @@
 Progress includes: step count, total steps, message, token usage, last tool called.
 
 ## Phase 3: Steer
+use judgment to follow the Phase 3: Steer guidance:
 
 Send a message to redirect a running agent:
 ```
@@ -230,6 +254,7 @@
 Only the parent job or admin can send messages (sender validation).
 
 ## Phase 4: Lifecycle
+use judgment to follow the Phase 4: Lifecycle guidance:
 
 ```
 pause_job id=ID                    # freeze without losing state
@@ -242,15 +267,19 @@
 All lifecycle ops are MCP-callable.
 
 ## Phase 5: Review Results
+use judgment to follow the Phase 5: Review Results guidance:
 
 ```
 get_job ID                         # result, token counts, transcript
 ```
 
 Token accounting: every job tracks `tokens_input`, `tokens_output`, `tokens_cache_read`.
+
+### Phase 5: Review Results — steps
+
 Child tokens roll up to parent automatically on completion.
 
-## Output Format
+## Output Format (( inert, role: template ))
 
 When reporting job status to the user:
 
@@ -280,7 +309,8 @@
 Total tokens so far: 4.3k
 ```
 
-## Anti-Patterns
+## Anti-Patterns (( role: procedure ))
+use judgment to follow the Anti-Patterns guidance:
 
 - Don't spawn a Minion for a single search query (use search tool directly)
 - Don't fire-and-forget without checking results
@@ -288,7 +318,7 @@
 - For subagent work, don't use `sessions_spawn` with `runtime: "subagent"` when Minions is available (use `gbrain agent run` instead)
 - Don't poll `get_job` in a tight loop (use `get_job_progress` for lightweight checks)
 
-## Tools Used
+## Tools Used (( inert, role: tools ))
 
 - Submit a background job — `submit_job` (MCP, non-protected names only; shell jobs are CLI-only, subagent jobs via `gbrain agent run`)
 - Get job details — `get_job` (MCP)
```
