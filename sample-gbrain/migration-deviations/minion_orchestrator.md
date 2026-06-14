# Deviation: minion_orchestrator.meri

- Original: `minion-orchestrator/SKILL.md`
- Ported: `minion_orchestrator.meri`
- Tier: 3 (structural rewrite)
- Similarity: 50%
- Lines: 303 -> 306 (+154 / -151)

## Frontmatter
- Added: (none)
- Removed: (none)

## Categories
- section-marker-added
- shell-block-routed

## Metrics
- Sections: 9/16 inert (56% inert ratio)
- Operational inert: 0
- Unclassified inert: 0
- Inert categories: reference-documentation=7, template=1, tools-metadata=1
- Judgment: 5 blocks, 69 lines

### Inert section details
- L26 `Route the Request: Shell Job vs Subagent`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L41 `Shell Jobs (Deterministic Scripts)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L69 `Submit (CLI, operator or autopilot)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L94 `Monitor (agents or operator)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L108 `Control (MCP-callable)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L120 `Subagent Jobs (LLM Orchestration)`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L191 `Phase 4: Lifecycle`: reference-documentation — Reference documentation, rationale, examples, or changelog.
- L212 `Output Format`: template — Template/output shape is metadata unless explicit output assertions are authored.
- L251 `Tools Used`: tools-metadata — Tools sections are metadata-mining, not workflow execution.

## Unified diff

```diff
--- original-skills/minion-orchestrator/SKILL.md
+++ skills/minion_orchestrator.meri
@@ -44,27 +44,29 @@
 
 # Minion Orchestrator
 
-## Contract
-
-Minions is a Postgres-native job queue for durable, observable background work.
-This single skill handles two lanes:
-- Deterministic shell jobs (`gbrain jobs submit shell ...`)
-- LLM subagent jobs (`gbrain agent run ...`)
-
-When to route to Minions: durable, observable work that must survive restarts,
-fan out across many parallel tasks, or persist across sessions. Routing policy
-is defined in `skills/conventions/subagent-routing.md` — the project default is
-`pain_triggered` (native subagents first, Minions after specific pain signals
-fire); Mode A (all-through-Minions) is opt-in.
-
-Guarantees:
-- Jobs survive gateway restart (Postgres-backed)
-- Every job has structured progress, token accounting, and session transcripts
-- Running agents can be steered mid-flight via inbox messages
-- Jobs can be paused, resumed, or cancelled at any time
-- Parent-child DAGs with configurable failure policies
-
-## Route the Request: Shell Job vs Subagent
+## Contract (( role: procedure ))
+
+> Minions is a Postgres-native job queue for durable, observable background work.
+> This single skill handles two lanes:
+!!! checklist (( ai-autonomy ))
+- [ ] Deterministic shell jobs (`gbrain jobs submit shell ...`)
+- [ ] LLM subagent jobs (`gbrain agent run ...`)
+
+> When to route to Minions: durable, observable work that must survive restarts,
+> fan out across many parallel tasks, or persist across sessions. Routing policy
+> is defined in `skills/conventions/subagent-routing.md` — the project default is
+> `pain_triggered` (native subagents first, Minions after specific pain signals
+> fire); Mode A (all-through-Minions) is opt-in.
+
+> Guarantees:
+!!! checklist (( ai-autonomy ))
+- [ ] Jobs survive gateway restart (Postgres-backed)
+- [ ] Every job has structured progress, token accounting, and session transcripts
+- [ ] Running agents can be steered mid-flight via inbox messages
+- [ ] Jobs can be paused, resumed, or cancelled at any time
+- [ ] Parent-child DAGs with configurable failure policies
+
+## Route the Request: Shell Job vs Subagent (( inert ))
 
 | Condition | Action |
 |---|---|
@@ -79,86 +81,86 @@
 If intent is ambiguous, ask one clarification:
 "Do you want a deterministic shell command job, or an LLM agent job?"
 
-## Shell Jobs (Deterministic Scripts)
+## Shell Jobs (Deterministic Scripts) (( inert ))
 
 Use for reproducible command execution, ETL steps, cron work, and scriptable
 tasks where no LLM reasoning loop is needed.
 
-### Preconditions (read before submitting your first shell job)
-
-- **`GBRAIN_ALLOW_SHELL_JOBS=1` must be set on the worker environment.**
-  Without it, the shell handler refuses to register and submissions sit in
-  `waiting` silently. Gate lives in `src/core/minions/handlers/shell.ts`.
-- **Security:** flipping `GBRAIN_ALLOW_SHELL_JOBS=1` authorizes arbitrary
-  command execution on the worker. On a shared queue, this is a remote code
-  execution surface. Treat as privileged infrastructure authorization.
-- **Execution mode — pick one:**
-  - **Postgres + daemon:** `gbrain jobs work` runs a persistent worker that
-    claims and executes jobs from the queue.
-  - **PGLite + --follow:** `gbrain jobs submit ... --follow` runs inline.
-    The daemon mode is not available on PGLite (exclusive file lock). See
-    `docs/guides/minions-shell-jobs.md`.
-- **MCP boundary:** shell-job submission is CLI-only. `submit_job name="shell"`
-  over MCP throws an `OperationError` with code `permission_denied` ("'shell'
-  jobs cannot be submitted over MCP") because `shell` is in `PROTECTED_JOB_NAMES`.
-  Agents CAN observe shell jobs via `get_job` / `list_jobs` / `get_job_progress`
-  (not protected), but cannot submit them. Operator or autopilot submits;
-  agent observes.
-- **Verify setup:** after configuration, run `gbrain jobs stats` (CLI) to
-  confirm the worker is registered and consuming the queue.
-
-### Submit (CLI, operator or autopilot)
-
+### Preconditions (read before submitting your first shell job) (( role: procedure ))
+
+use judgment to follow the Preconditions (read before submitting your first shell job) guidance:
+  item: **`GBRAIN_ALLOW_SHELL_JOBS=1` must be set on the worker environment.**
+    Without it, the shell handler refuses to register and submissions sit in
+    `waiting` silently. Gate lives in `src/core/minions/handlers/shell.ts`.
+  item: **Security:** flipping `GBRAIN_ALLOW_SHELL_JOBS=1` authorizes arbitrary
+    command execution on the worker. On a shared queue, this is a remote code
+    execution surface. Treat as privileged infrastructure authorization.
+  item: **Execution mode — pick one:**
+  item: **Postgres + daemon:** `gbrain jobs work` runs a persistent worker that
+      claims and executes jobs from the queue.
+  item: **PGLite + --follow:** `gbrain jobs submit ... --follow` runs inline.
+      The daemon mode is not available on PGLite (exclusive file lock). See
+      `docs/guides/minions-shell-jobs.md`.
+  item: **MCP boundary:** shell-job submission is CLI-only. `submit_job name="shell"`
+    over MCP throws an `OperationError` with code `permission_denied` ("'shell'
+    jobs cannot be submitted over MCP") because `shell` is in `PROTECTED_JOB_NAMES`.
+    Agents CAN observe shell jobs via `get_job` / `list_jobs` / `get_job_progress`
+    (not protected), but cannot submit them. Operator or autopilot submits;
+    agent observes.
+  item: **Verify setup:** after configuration, run `gbrain jobs stats` (CLI) to
+    confirm the worker is registered and consuming the queue.
+### Submit (CLI, operator or autopilot) (( inert ))
+  
 Shell jobs take their command via `--params` as a JSON object with `cmd` (string)
 or `argv` (array), plus `cwd` and optional `env`.
-
+  
 Command string form:
 ```
 gbrain jobs submit shell --params '{"cmd":"echo hello","cwd":"/abs/path"}'
 ```
-
+  
 Argv form (no shell expansion):
 ```
 gbrain jobs submit shell --params '{"argv":["bash","-lc","echo hello"],"cwd":"/abs/path"}'
 ```
-
+  
 Inline execution on PGLite or any one-shot deployment:
 ```
 gbrain jobs submit shell --params '{"cmd":"echo hello","cwd":"/tmp"}' --follow
 ```
-
+  
 Queue/lifecycle flags exposed by `gbrain jobs submit --help`: `--queue`,
 `--priority`, `--delay`, `--max-attempts`, `--max-stalled`, `--backoff-type`,
 `--backoff-delay`, `--backoff-jitter`, `--timeout-ms`, `--idempotency-key`,
 `--dry-run`.
-
-### Monitor (agents or operator)
-
+  
+### Monitor (agents or operator) (( inert ))
+  
 These operations are MCP-callable and safe for agent use:
-
+  
 ```
 list_jobs --name shell --status active
 get_job ID
 get_job_progress ID
 ```
-
+  
 Check structured result fields (exit code, stdout/stderr tails, attempts,
 timings) from `get_job`. Use `gbrain jobs stats` (CLI) for worker/queue
 health dashboard.
-
-### Control (MCP-callable)
-
+  
+### Control (MCP-callable) (( inert ))
+  
 ```
 cancel_job id=ID
 replay_job id=ID
 ```
-
+  
 `replay_job` is not protected — only shell *submission* is. Agents can
 cancel or replay a shell job without CLI access.
-
+  
 Use idempotency keys for recurring shell workloads to avoid duplicate runs.
 
-## Subagent Jobs (LLM Orchestration)
+## Subagent Jobs (LLM Orchestration) (( inert ))
 
 Use for open-ended reasoning, tool-using research, and fan-out synthesis.
 
@@ -168,68 +170,68 @@
 submission requires `{allowProtectedSubmit: true}`, which `gbrain agent run`
 supplies.
 
-## Phase 1: Submit
-
-```
-gbrain agent run "Research Acme Corp revenue" --tools "search,query"
-```
-
-`--tools` accepts a comma-separated subset of `BRAIN_TOOL_ALLOWLIST` (see
-`src/core/minions/tools/brain-allowlist.ts`): `query`, `search`, `get_page`,
-`list_pages`, `file_list`, `file_url`, `get_backlinks`, `traverse_graph`,
-`resolve_slugs`, `get_ingest_log`, `put_page`. Anything outside the allow-list
-is rejected at submit time with `allowed_tools references unknown tool`.
-
-For parallel work with a fan-out manifest:
-```
-gbrain agent run --fanout-manifest companies.json
-```
-
-The manifest describes N children + 1 aggregator. Each child runs
-`name="subagent"` under the hood; the aggregator runs `name="subagent_aggregator"`
-and claims AFTER every child terminates. See
-`src/core/minions/handlers/subagent.ts` and
-`src/core/minions/handlers/subagent-aggregator.ts`.
-
-Flags (from `src/commands/agent.ts`):
-- `--subagent-def <name>` — named subagent definition
-- `--model <id>` — override model
-- `--max-turns <N>` — cap the LLM loop
-- `--tools <csv>` — allow-listed brain tools (see above)
-- `--timeout-ms <N>` — hard timeout per job
-- `--fanout-manifest <file>` — N children + 1 aggregator
-- `--follow` / `--no-follow` — stream logs + wait (default on TTY)
-- `--detach` — submit and return immediately
-
-Queue/priority/retry tuning is not exposed by `gbrain agent run`; submit the
-raw `subagent` handler via `gbrain jobs submit` (requires CLI trust) if you
-need those knobs.
-
-## Phase 2: Monitor
-
-```
-list_jobs --status active          # MCP — what's running?
-get_job ID                         # MCP — full details + logs + tokens
-get_job_progress ID                # MCP — structured progress snapshot
-gbrain jobs stats                  # CLI — queue health dashboard
-gbrain agent logs ID --follow      # CLI — streaming transcript + heartbeat
-```
-
-Progress includes: step count, total steps, message, token usage, last tool called.
-
-## Phase 3: Steer
-
-Send a message to redirect a running agent:
-```
-send_job_message id=ID payload={"directive":"focus on revenue, skip headcount"}
-```
-
-The agent handler reads inbox messages on each iteration and injects them as
-context. Messages are acknowledged (read receipts tracked).
-
-Only the parent job or admin can send messages (sender validation).
-
-## Phase 4: Lifecycle
+## Phase 1: Submit (( role: procedure ))
+
+use judgment to follow the Phase 1: Submit guidance:
+  ```
+  gbrain agent run "Research Acme Corp revenue" --tools "search,query"
+  ```
+  
+  `--tools` accepts a comma-separated subset of `BRAIN_TOOL_ALLOWLIST` (see
+  `src/core/minions/tools/brain-allowlist.ts`): `query`, `search`, `get_page`,
+  `list_pages`, `file_list`, `file_url`, `get_backlinks`, `traverse_graph`,
+  `resolve_slugs`, `get_ingest_log`, `put_page`. Anything outside the allow-list
+  is rejected at submit time with `allowed_tools references unknown tool`.
+  
+  For parallel work with a fan-out manifest:
+  ```
+  gbrain agent run --fanout-manifest companies.json
+  ```
+  
+  The manifest describes N children + 1 aggregator. Each child runs
+  `name="subagent"` under the hood; the aggregator runs `name="subagent_aggregator"`
+  and claims AFTER every child terminates. See
+  `src/core/minions/handlers/subagent.ts` and
+  `src/core/minions/handlers/subagent-aggregator.ts`.
+  
+  Flags (from `src/commands/agent.ts`):
+  item: `--subagent-def <name>` — named subagent definition
+  item: `--model <id>` — override model
+  item: `--max-turns <N>` — cap the LLM loop
+  item: `--tools <csv>` — allow-listed brain tools (see above)
+  item: `--timeout-ms <N>` — hard timeout per job
+  item: `--fanout-manifest <file>` — N children + 1 aggregator
+  item: `--follow` / `--no-follow` — stream logs + wait (default on TTY)
+  item: `--detach` — submit and return immediately
+  
+  Queue/priority/retry tuning is not exposed by `gbrain agent run`; submit the
+  raw `subagent` handler via `gbrain jobs submit` (requires CLI trust) if you
+  need those knobs.
+## Phase 2: Monitor (( role: procedure ))
+
+use judgment to follow the Phase 2: Monitor guidance:
+  ```
+  list_jobs --status active          # MCP — what's running?
+  get_job ID                         # MCP — full details + logs + tokens
+  get_job_progress ID                # MCP — structured progress snapshot
+  gbrain jobs stats                  # CLI — queue health dashboard
+  gbrain agent logs ID --follow      # CLI — streaming transcript + heartbeat
+  ```
+  
+  Progress includes: step count, total steps, message, token usage, last tool called.
+## Phase 3: Steer (( role: procedure ))
+
+use judgment to follow the Phase 3: Steer guidance:
+  Send a message to redirect a running agent:
+  ```
+  send_job_message id=ID payload={"directive":"focus on revenue, skip headcount"}
+  ```
+  
+  The agent handler reads inbox messages on each iteration and injects them as
+  context. Messages are acknowledged (read receipts tracked).
+  
+  Only the parent job or admin can send messages (sender validation).
+## Phase 4: Lifecycle (( inert, role: procedure ))
 
 ```
 pause_job id=ID                    # freeze without losing state
@@ -241,15 +243,15 @@
 
 All lifecycle ops are MCP-callable.
 
-## Phase 5: Review Results
-
-```
-get_job ID                         # result, token counts, transcript
-```
-
-Token accounting: every job tracks `tokens_input`, `tokens_output`, `tokens_cache_read`.
-Child tokens roll up to parent automatically on completion.
-
+## Phase 5: Review Results (( role: procedure ))
+
+use judgment to follow the Phase 5: Review Results guidance:
+  ```
+  get_job ID                         # result, token counts, transcript
+  ```
+  
+  Token accounting: every job tracks `tokens_input`, `tokens_output`, `tokens_cache_read`.
+  Child tokens roll up to parent automatically on completion.
 ## Output Format
 
 When reporting job status to the user:
@@ -280,24 +282,25 @@
 Total tokens so far: 4.3k
 ```
 
-## Anti-Patterns
-
-- Don't spawn a Minion for a single search query (use search tool directly)
-- Don't fire-and-forget without checking results
-- Don't spawn > 5 concurrent agents without checking `gbrain jobs stats` first
-- For subagent work, don't use `sessions_spawn` with `runtime: "subagent"` when Minions is available (use `gbrain agent run` instead)
-- Don't poll `get_job` in a tight loop (use `get_job_progress` for lightweight checks)
+## Anti-Patterns (( role: procedure ))
+
+!!! checklist (( ai-autonomy ))
+- [ ] Don't spawn a Minion for a single search query (use search tool directly)
+- [ ] Don't fire-and-forget without checking results
+- [ ] Don't spawn > 5 concurrent agents without checking `gbrain jobs stats` first
+- [ ] For subagent work, don't use `sessions_spawn` with `runtime: "subagent"` when Minions is available (use `gbrain agent run` instead)
+- [ ] Don't poll `get_job` in a tight loop (use `get_job_progress` for lightweight checks)
 
 ## Tools Used
 
-- Submit a background job — `submit_job` (MCP, non-protected names only; shell jobs are CLI-only, subagent jobs via `gbrain agent run`)
-- Get job details — `get_job` (MCP)
-- List jobs with filters — `list_jobs` (MCP)
-- Cancel a job — `cancel_job` (MCP)
-- Pause a job — `pause_job` (MCP)
-- Resume a paused job — `resume_job` (MCP)
-- Replay a completed/failed job — `replay_job` (MCP)
-- Send sidechannel message — `send_job_message` (MCP)
-- Get structured progress — `get_job_progress` (MCP)
-- Queue stats — `gbrain jobs stats` (CLI; no MCP equivalent)
-
+- Submit a background job (submit_job)
+- Get job details (get_job)
+- List jobs with filters (list_jobs)
+- Cancel a job (cancel_job)
+- Pause a job (pause_job)
+- Resume a paused job (resume_job)
+- Replay a completed/failed job (replay_job)
+- Send sidechannel message (send_job_message)
+- Get structured progress (get_job_progress)
+- Queue stats with `gbrain jobs stats` (shell.run)
+
```
