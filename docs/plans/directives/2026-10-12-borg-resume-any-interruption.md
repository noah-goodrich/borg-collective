# Directive: borg-resume v2: fire on any interruption

*Filed: 2026-10-12 · Status: Proposed*

## tl;dr

- Today borg-resume only fires if a live model turn notices a failed Workflow. When the main loop itself dies on a limit, no turn exists, so it never fires. PR #290 swaps the scheduler to CronCreate, which is still model-invoked, session-scoped, and Workflow-only.
- The fix moves detection and scheduling out of the model. A few rare-event hooks (`StopFailure`, `SessionStart`, `SessionEnd`, `SubagentStart/Stop`, `Notification`, and `Pre/PostToolUse` on `Agent|Workflow` only) append facts to a durable per-session ledger under `/Users/noah/.local/state/borg/resume/`. A launchd watcher (`borg-resume watch`, every 30s, modeled on `borg-cortex-watch`) folds those facts into interruption records, decides when each is due, and injects a one-line prompt with `tmux send-keys`.
- The one mechanism that makes it deterministic: hooks only APPEND events (plus one write-once registry file per session), and a single-instance watcher owns every state transition and every counter. Two independent detectors feed it (hook events and a transcript/journal/liveness scan), so a missed hook, a SIGKILL, or a reboot still produces a record. Both converge on one record per (session, scope), which is the idempotency key. Transcripts are ground truth; hooks are accelerators.
- Injection is gated on POSITIVE evidence, never on absence of activity. The watcher injects only into a pane that is bound to the session id (tmux pane option `@borg_sid`), whose claude process provably owns the session, whose composer is provably empty with no dialog showing, and whose attached human is not typing. If any of that cannot be proven the record stays deferred and Noah is notified; there is no "inject anyway" path.
- What was in flight is reconstructed from disk at resume time, not trusted from the hook payload: the first record of each `subagents/agent-*.jsonl` is the original brief, its `.meta.json` has `toolUseId`, `agentType`, `model`, and the workflow manifest `wf_<id>.json` has `scriptPath`. Workflow-owned agents (under `subagents/workflows/wf_<id>/`) are resumed only through their workflow, never through `SendMessage`.
- Deliberate ends are detected, not assumed: a trailing `[Request interrupted by user*]` record in the main or an agent transcript closes the turn as `interrupted_by_user`, so Esc, a skipped agent, and Ctrl+X Ctrl+K are never resumed, even if the pane is closed afterwards.
- Safety: kill switch (`BORG_RESUME_DISABLE=1` or the `DISABLED` sentinel), 3 consecutive no-progress resumes per session then stop-and-notify, a cap of 2 concurrently auto-resumed sessions, a fail-closed usage probe for limit-class records, `borg resume status|cancel|pause|run`, notify-only outside tmux. No new runtime dependency (bash, jq, tmux, launchd).
- Build: 17 slices, each at most 2 deliverables. Real payloads and transcripts are captured first (S0a/S0b) and gate the slices that depend on them; a local real-claude smoke lane backs the stubbed bats suite.

## Ground truth this design stands on

- `StopFailure` exists in 2.1.296, fires instead of `Stop` on an API error, is fire-and-forget, carries `error`, `error_details`, `last_assistant_message`, plus the common fields (`session_id`, `cwd`, `transcript_path`). It cannot continue the turn, so it can only record.
- The same error writes a synthetic transcript record (`type:"assistant"`, `isApiErrorMessage:true`, `error:"<same string>"`). That record is the second, hook-independent signal.
- User interrupts leave `[Request interrupted by user]` (or `... for tool use]`) user records and no synthetic error record. `Stop` is reported not to fire on a user interrupt (feature request claude-code #9516; unverified here, spike U15), so the hook-side turn state cannot be trusted after Esc. The trailing interrupt marker in the transcript is therefore the deliberate-end signal on every path (scan and liveness), not just an exclusion by absence.
- The limit reset time is text only: `You've hit your weekly limit · resets Jul 7 at 7am (America/Denver)`, or `resets 7:10am (America/Denver)` for session limits. Parse it, fall back to backoff.
- A synthetic error record is not always the LAST record. The real sleep-interrupted main transcript (`beb3b143`) ends `permission-mode`, `pr-link`, `system:stop_hook_summary`, `system:turn_duration`, `cost-state` after the synthetic `server_error`. The scan therefore looks at the last MEANINGFUL record, defined in S2 by an allowlist of bookkeeping types and tested against a scrubbed capture of that transcript.
- A subagent transcript's first record is the brief (`type:"user"`, `isSidechain:true`, `cwd`, `agentId`, `sessionId`). Its sibling `.meta.json` has `agentType, description, model, spawnDepth, toolUseId`.
- Two agent locations exist. Agent-tool agents live at `<sid>/subagents/agent-*.jsonl`. Workflow agents live at `<sid>/subagents/workflows/wf_<id>/agent-*.jsonl` beside `journal.jsonl`. The manifest is `<sid>/workflows/wf_<id>.json` with `runId`, `scriptPath`, `script`, `args`, and `result` when finished. The inventory treats the two locations as different kinds.
- Per the docs, a limit-hit `agent()` inside `parallel()`/`pipeline()` resolves to `null` and the run FINISHES, so a finished manifest can hide failed agents. The journal has no error record and no `null` result has been observed on this machine.
- Workflow resume is documented as same-session only. A killed process therefore must come back with `claude --resume <session_id>` so the saved results are reachable, not a fresh session.
- `claude --resume` can show a dialog: "Resuming the full session will consume a substantial portion of your usage limits. We recommend resuming from a summary." The summary option may fork the session id. Launch also may show trust-folder or permission prompts. Any text injected before these are handled lands in the dialog.
- Native `autoContinueAtUsageLimit` exists in-process for claude.ai limits on the main loop (24h cap, re-arm cap 2, lost when the process exits). Its default is unknown. When it is off, a limit dialog offers the wait as a choice, so a pane can be sitting in that dialog rather than at the composer. The `Notification` matchers `quota_auto_resume_fired|stale|disabled` expose it to hooks.
- Drone hooks run INSIDE the container (`notify.sh` exits on `/.dockerenv`). `$TMUX_PANE` is not available there, and the state dir is not obviously bind-mounted. Handled in S3.
- The usage guardian is dead since 2026-10-03 (launchd exit 1, empty stderr, cause unknown), so `usage-guardian.json` is stale and the claude-from-launchd environment is known to be fragile. This design does not rely on the guardian file.
- `borg-dispatch-guard.sh` can deny `Agent|Workflow` when usage is high (default-off flag), and `Bash(borg-resume:*)` is not in the global allowlist today. Both can stall an unattended resume.

## Coverage matrix

Columns: Auto is yes, notify, capped, or excluded. Details per row are in the bullets below the table.

| Case | Detect | Resume | Auto |
|------|--------|--------|------|
| Session limit, main | StopFailure, scan | reset+2m | yes |
| Weekly limit, main | StopFailure, scan | reset+2m | yes* |
| Limit, Agent-tool | scan, SubagentStop | reset, SendMsg | yes |
| Limit, workflow | journal+agent scan | resumeFromRunId | yes |
| Transient, main | StopFailure, scan | backoff | yes |
| Transient, Agent-tool | scan, StopFailure | backoff, SendMsg | yes |
| Transient, wf agent | wf agent scan | backoff, resume | yes |
| Finished, null wf agents | wf agent scan | resume/new run | yes |
| max_output_tokens | StopFailure, scan | +15s, small steps | yes |
| Prompt too long | StopFailure, scan | /compact, resume | yes |
| Crash, no hook | liveness scan | relaunch --resume | yes |
| Pane closed | liveness scan | relaunch, grace | yes |
| Sleep / reboot | liveness, scan | staged relaunch | capped |
| Docker VM wedge | container check | drone relaunch | yes |
| Workflow killed | journal scan | resumeFromRunId | yes |
| Auth / billing | StopFailure | none | notify |
| Esc, Ctrl-C, skip, Ctrl+X Ctrl+K | marker | none | excluded |
| Pane not provably idle | gate | none | notify |

- Usage limit, main: `StopFailure` with `error=rate_limit` and a "hit your ... limit" sentence. Resume at parsed reset plus 120s grace (gives native auto-continue first shot), subject to the concurrency cap and the fail-closed usage probe.
- Weekly limit (`yes*`): the reset is often more than 24h out, beyond native auto-continue's cap, so borg is the only thing that can resume it. Policy: auto-resume stays on, but it is never silent. Notify at detection with the resume time, notify again 15 minutes before with the cancel command, and require full idle proof at fire time. Age is measured from `resume_at` (see Age rule), with a 7-day ceiling from `first_seen`. Decision 9 lets Noah switch this to notify-only.
- Usage limit, Agent-tool agents: the limit hits main and every subagent at once, so one main-scope record covers the session; per-agent records are created only for agents whose transcript ends in the synthetic error. The single resume prompt lists all of them.
- Transient (overloaded, server_error, unknown, timeout, connection lost, stream stalled): Claude Code already retried 10 times, so backoff starts long: 45s, 2m, 5m, 15m, then stop and notify. Sleep-truncated errors (`truncatedAfterOutput:true`) get the first backoff only, since the cause is already gone.
- Transient Agent-tool agent or workflow agent while main is alive: the main model may already be handling it. The watcher waits one backoff step, then applies the supersede rules (agent transcript advanced, or a later re-spawn of the same task, see Pre-flight gate); if so the record is `superseded`.
- Finished with null workflow agents: the manifest has a `result` but one or more workflow agents' transcripts end in a synthetic error, or the result contains nulls. Detected as workflow status `finished_with_failures`. Whether `resumeFromRunId` re-runs agents whose journaled result is null, or replays the null, is gating spike U8; if it replays null, the prompt uses the "new run with the same args" path and says so.
- `max_output_tokens`: resume after 15s with the "smaller steps" variant of the prompt. No real record exists on this machine, so the class is fixture-driven only.
- Prompt too long (`invalid_request` plus "Prompt is too long"): a plain resume would loop. Inject `/compact` once, confirm the transcript grew a compact boundary, then the normal resume prompt. If it fails twice, notify. Spiked (U12).
- Crash, pane closed, reboot, Docker wedge: no hook fires. The liveness scan finds sessions with open work whose process or pane is gone and which have no deliberate end. Open work is derived from the transcript tail (last meaningful record is not a clean turn close and not an interrupt marker) or an unfinished, non-interrupted agent or workflow. Relaunch with `claude --resume <sid>`, verify the session id, then inject.
- Workflow killed: manifest has no `result`, journal has `started` without `result`, and the journal has been idle for 5 minutes with no live owner session, or the owner session logged a limit error.
- Auth and billing (`authentication_failed`, `oauth_org_not_allowed`, `account_on_hold`, `verification_required`, `billing_error`, `cloud_credential_error`, `model_not_found`, monthly spend or team budget text): notify with the exact message, never inject.
- Excluded (deliberate): Esc, Ctrl-C, user skipping an agent, Ctrl+X Ctrl+K (all leave a trailing `[Request interrupted by user*]` record). Also excluded: `SessionEnd` reasons `prompt_input_exit`, `clear`, `logout`, and anything closed by `drone down` or `borg sever`. An interrupt followed by closing the pane is still excluded, because the marker, not the pane state, decides.
- Pane not provably idle: permission dialog, AskUserQuestion, plan approval, limit dialog, a half-typed human draft, or a human typing right now. The record stays `deferred`, Noah is notified once with the window name and `borg resume run <rid>`, and the watcher keeps re-checking each pass until the age limit. It never injects without proof.

## Components

1. `bin/borg-resume` (bash + jq, one file, subcommands). Verbs: `record <event>` (called by the hook), `watch [--once]`, `inventory <sid>`, `prompt <rid>`, `ack <rid>`, `defer <rid> --reason <r>`, `status [--json]`, `cancel`, `pause`, `unpause`, `run <rid> [--now|--print]`, `probe`, `log`.
2. `hooks/borg-resume-hook.sh`, one thin script registered for several events. It reads stdin, checks the kill switch, `exec`s `$HOME/.claude/bin/borg-resume record` if executable, and always exits 0 with no stdout. It never emits a decision, so it cannot interfere with `borg-dispatch-guard.sh`. Every registration sets an explicit `"timeout": 5` in `hooks.json`.
3. `lib/borg/resume-classify.sh`: error string plus message text to class, action, and `resume_at`. Includes the reset-text parser, the bookkeeping-record allowlist, and the interrupt-marker matcher. Pure functions, take `BORG_RESUME_NOW_EPOCH`.
4. `lib/borg/inject.sh`: pane enumeration regex for `claude` or a version string, text then separate Enter 0.3s apart, pane binding and ownership verification, `pane_state` classifier (`idle_empty|draft|dialog|busy|unknown`), client-activity check. Created for `borg-resume`; `borg-usage-watch` is NOT refactored to source it in this effort (see S8 and Risks).
5. `launchd/borg.resume-watch.plist` (StartInterval 30, ThrottleInterval 10, RunAtLoad, absolute `BORG_CLAUDE_BIN` and a PATH that includes `~/.local/bin` in its EnvironmentVariables), rendered by `install.sh` with `_borg_launchd_label`, same shape as `borg.cortex-wake.plist`.
6. `borg.zsh` verb `borg resume ...` delegating to `bin/borg-resume`, and a `borg doctor` check.
7. Skill `skills/borg-resume/SKILL.md` rewritten as the manual and fallback path (see PR #290 section).

Installed layout (what launchd and hooks actually see): `/Users/noah/.claude/bin/borg-resume` plus `/Users/noah/.claude/lib/borg/*.sh`. `bin/borg-resume` resolves its libs relative to its own resolved path (`../lib/borg`), overridable with `BORG_RESUME_LIBDIR` for tests. `install.sh` installs the lib files explicitly, and a bats test copies the files into a temp layout and runs the watcher from there with a minimal launchd-like `PATH`.

### Hook wiring (hooks.json via `scripts/build-plugin.sh` Phase 4)

| Event | Matcher | Records |
|-------|---------|---------|
| SessionStart | all | session, pane |
| PreToolUse | Agent, Workflow | dispatch intent |
| PostToolUse | Agent, Workflow | bind ids |
| SubagentStart | all | agent started |
| SubagentStop | all | agent done/err |
| StopFailure | all | interruption |
| SessionEnd | all | end reason |
| Notification | regex, see below | idle/perm/native |

- Notification matcher is the regex `idle_prompt|permission_prompt|quota_auto_resume_.*` (hook matchers are regex, not globs; anchoring behavior is checked in S0b). It records the idle and permission signals the idle proof and the stall watchdog use, and the native auto-continue hint.
- `Stop` and `UserPromptSubmit` are deliberately NOT registered. They fire on every turn, and the facts they would carry (turn open/closed, prompt head) are derived from the transcript tail at scan time. `Stop` is already wired to `borg-link-up.sh`, which is left alone. This keeps per-turn hook cost at zero.
- Only `SessionStart` calls tmux (`tmux set-option -p -t "$TMUX_PANE" @borg_sid <sid>` and one `display -p` for the pane facts). Hot-ish events (`Pre/PostToolUse` on Agent and Workflow, which the matcher already restricts to rare calls) do one `jq` read and one append, no tmux. Measured in S4 with budgets of 100ms for rare events and 50ms for the Pre/PostToolUse pair; these are measured, not assumed.
- PreToolUse records an intent keyed by `tool_use_id`. It is only trusted once PostToolUse or SubagentStart confirms it, or the `.meta.json` with the same `toolUseId` appears. This prevents ghost in-flight items when `borg-dispatch-guard.sh` denies the dispatch.
- Every payload field is read with `jq -r '.x // empty'` and tolerates absence. If `StopFailure` turns out not to fire for subagents (unverified), the scan detector still catches them.
- The 5s hook timeout is the fail-open bound for a wedged VirtioFS write from a container hook (U14).

## Data formats

All under `${XDG_STATE_HOME:-$HOME/.local/state}/borg/resume/` (`/Users/noah/.local/state/borg/resume/`), resolved with `_borg_state_root`. Overridable with `BORG_RESUME_DIR` for tests.

```
resume/
  DISABLED              sentinel: pause everything
  sessions/<sid>.json   HOOK-owned registry, written by SessionStart
  events/<sid>.jsonl    append-only facts (hooks append only)
  state/<sid>.json      WATCHER-owned counters
  pending/<rid>.json    interruption records (watcher owns)
  done/<rid>.json       terminal records (moved by watcher)
  prompts/<rid>.md      rendered resume prompt (watcher)
  usage-probe.json      watcher's cached /usage probe result
  spike/SPIKE_RESULTS.json   read-only, see Test strategy
  watch.log             watcher log (rotated at 1MiB, tested)
  .watch.lock/          mkdir lock, pid inside, stale-checked
```

Ownership rule: no file has two writers. Hooks write `events/` (append) and their own `sessions/<sid>.json` (only the `session_start` handler for that sid writes it, tmp + mv). The watcher writes everything else. Anything else a consumer needs (turn state, ended, transcript path, progress) is DERIVED by folding events and reading transcripts, never stored by a hook.

Session registry, immutable facts captured at `SessionStart` (hook-owned):

```
{
  "session_id": "00000000-0000-4000-8000-000000000001",
  "source": "startup",
  "cwd": "/Users/noah/dev/example-project",
  "project": "example-project",
  "mode": "project",
  "in_container": false,
  "claude_pid": 41233,
  "claude_start": "Mon Oct 12 00:10:02 2026",
  "tmux": {"pane_id": "%12", "pane_pid": 41200,
           "session": "borg", "window": "example-project",
           "window_index": 3, "pane_index": 1,
           "project_dir": "/Users/noah/dev/example-project"}
}
```

- `source` is the SessionStart source (`startup`, `resume`, ...). A `--resume` relaunch writes a fresh registry for that sid, which is how the watcher verifies the session came back.
- `transcript` is never stored; it is re-resolved on the host by globbing `/Users/noah/.claude/projects/*/<sid>.jsonl`, because containers see a different prefix.
- `mode` comes from `_borg_session_mode` (orchestrator, project); container-ness is the separate `in_container` field. `project` from the same cwd helper.
- `claude_pid` is the hook's parent claude process (`$PPID`, unverified, U9) with its start time, used for the ownership check. Container sessions have no pid and no pane in the record.

Watcher counters (`state/<sid>.json`, watcher-owned):

```
{
  "consecutive": 0,
  "resumed_total": 0,
  "injections_today": 0,
  "day": "2026-10-12",
  "last_progress_lines": 0
}
```

Event line (one JSON object per line, under 4KB, `last_assistant_message` truncated to 600 chars):

```
{"t":1791800000,"ev":"stop_failure","sid":"00000000-0000-4000-8000-000000000001",
 "scope":"main","agent_id":null,"error":"rate_limit",
 "msg":"You've hit your session limit · resets 7:10am (MT)",
 "tool_use_id":null}
```

`ev` values: `session_start`, `dispatch_intent`, `dispatch_bound`, `agent_start`, `agent_stop`, `stop_failure`, `session_end`, `idle_prompt`, `permission_prompt`, `native_resume`. Extra fields: `run_id`, `script_path`, `agent_type`, `reason`. There are no `turn_open` or `turn_close` events.

Interruption record (`pending/<rid>.json`, `rid` = `r_` + 6 hex of sha1(sid, scope, first-seen epoch)):

```
{
  "rid": "r_7f3a2c",
  "sid": "00000000-0000-4000-8000-000000000001",
  "scope": "main",
  "class": "usage_limit",
  "action": "resume",
  "error": "rate_limit",
  "reset_text": "resets 7:10am (America/Denver)",
  "detected_by": ["hook", "scan"],
  "evidence": {"transcript_line": 4812, "uuid": "..."},
  "first_seen": 1791790000,
  "resume_at": 1791796920,
  "attempt": 0,
  "state": "scheduled",
  "state_log": [["scheduled", 1791790001]],
  "inject_tries": 0,
  "notified": false
}
```

States: ACTIVE = `new`, `scheduled`, `deferred` (headroom, not provably idle, pane missing, concurrency cap, probe failed), `injecting`, `injected`, `confirmed`. TERMINAL = `done`, `superseded`, `cancelled`, `capped`, `notify_only`, `expired`, `failed`, `stalled`.

- `confirmed` means "the prompt tag landed", which proves receipt, not completion. It is ACTIVE and counts toward the concurrency cap. It becomes `done` on the first of: `ack` run, transcript progress of at least 25 lines since confirmation, or 30 minutes after confirmation (a timeout `done` increments `consecutive`, a progress or ack `done` resets it). It becomes `stalled` (terminal, notify) via the post-confirmation watchdog.
- Dedupe rule (the idempotency key): at most one ACTIVE record per (sid, scope). A later event for the same key merges into it only while it is in `new`, `scheduled`, `deferred`, `injecting`, or `injected` (max of `resume_at`, union of `detected_by`). Events are never merged into `confirmed` or terminal records: a new interruption with an `evidence.uuid` that was not already attached creates a fresh record (attempt + 1 via the counters), and an error whose uuid is already attached to any record, including terminal ones, creates nothing.
- Scope is `main`, `agent:<agent_id>`, or `workflow:<run_id>`. To keep the prompt singular, the watcher groups all ACTIVE records of a session into ONE injection (the rendered prompt lists every scope); the grouped records move together.
- Hooks never mutate `pending/`. Only the watcher does, holding `.watch.lock`.

### In-flight inventory (`borg-resume inventory <sid> --json`)

Rebuilt from disk at render time, cross-checked with the ledger:

- Session-level: turn state (derived from the transcript tail), prompt head, newest `.borg/checkpoints/*.md` of the cwd, git branch and dirty state.
- Agent-tool agents: every `<sid>/subagents/agent-*.jsonl` (non-recursive glob) with its `.meta.json`. Status: `done` (SubagentStop event or last meaningful record is a normal assistant end), `errored` (last meaningful record is a synthetic error), `interrupted_by_user` (last meaningful record is the interrupt marker), `orphaned` (none of the above and no activity for 5 min), `running` (transcript mtime under 5 min). Only `errored` and `orphaned` go in the prompt; `interrupted_by_user` and `done` never do. Brief = first record's text, stored as a file reference (path plus line 1), not copied into the prompt. Worktree = the agent's `cwd` when it is under a worktree root, with `git -C` branch, last commit, and dirty flag.
- Workflow agents: every `<sid>/subagents/workflows/wf_<id>/agent-*.jsonl`, kind `workflow_agent`, owned by that run id, statuses as above. They are never listed under Agents and never get `SendMessage`; they appear only inside their workflow entry.
- Workflows: `<sid>/workflows/wf_*.json` manifests joined with `subagents/workflows/wf_*/journal.jsonl` and the owned agent transcripts. Status: `finished` (manifest has `result`, no unfinished `started`, no errored owned agent, no null in the result), `finished_with_failures` (manifest has `result` but an owned agent errored or the result contains a null), `partial` (`started` lacking `result`), `unfinished` (no `result`), `interrupted_by_user` (owned agents ended with the marker; excluded). Carries `runId`, `scriptPath`, and a `script_inline` flag when only inline source exists.

## Detection and scheduling flow

1. Hook path: `StopFailure` appends a `stop_failure` event. `record` runs the classifier immediately so the event already carries `class` and `resume_at`. Notification `quota_auto_resume_fired` appends `native_resume`.
2. Scan path (every watcher pass, bounded to sessions with a registry row touched in the last 72h): for the main transcript and each non-`done` agent transcript (Agent-tool and workflow-owned), read the last 60 lines and find the last MEANINGFUL record (skip the bookkeeping allowlist: `last-prompt`, `permission-mode`, `pr-link`, `cost-state`, `file-history-snapshot`, `attachment`, and `system` records of subtype `stop_hook_summary` and `turn_duration`; the S2 helper `resume_last_meaningful_with_close` returns that record together with a `trailing_clean_close` flag, true when a `system:turn_duration` follows it, which is how a clean turn close is detected). If it is a synthetic error not already attached to a record, create a `scan_error` event. If it is an interrupt marker, mark that scope `interrupted_by_user` (deliberate end). Scan workflow manifests and journals, including finished ones, for `finished_with_failures`. This path covers: `StopFailure` not firing for subagents, sleep records written after wake, and hook failures.
3. Liveness path: for sessions with open work and no deliberate end (no `SessionEnd` of a deliberate reason, no `mark-closed`, no trailing interrupt marker), check the bound pane (`list-panes -a -F` including `#{@borg_sid}`, `pane_current_command`) and, for the host process, `claude_pid` alive with unchanged start time; for containers, `docker ps` for the drone container. Dead plus open work for 5 minutes (grace, with a notification and a cancel hint at minute 0) creates a `process_death` record.
4. The watcher folds events into `pending/` records, computes `resume_at`, and for each due record runs the pre-flight gate (below) then injects.
5. After injection it waits for confirmation (the transcript contains the user prompt tag `[borg-resume <rid>]`, or `ack` was run). No confirmation in 90s: re-verify idle proof, re-send with double Enter (the `borg-linkup-all` trick), at most 2 tries, then `failed` plus notify.
6. Post-confirmation watchdog: confirmation is not progress. If a `confirmed` record shows no transcript growth for 10 minutes (`BORG_RESUME_STALL_MIN`) and either a `permission_prompt` Notification arrived after injection or the pane classifies as `dialog`, the record becomes `stalled` and Noah is notified with the window name. This catches the unattended-permission-prompt case.

### Pre-flight gate (all must pass, else the record stays `deferred` with a reason; the gate has no override except the manual `borg resume run <rid> --now`)

- Not paused: no `DISABLED`, `BORG_RESUME_DISABLE` unset, no `.borg/no-resume` in the project, `BORG_NO_SESSION_HOOKS` not set for that session.
- Not superseded: the session transcript has no meaningful record after the interruption evidence (bookkeeping allowlist ignored). If the transcript advanced, or a `native_resume` event exists, mark `superseded`. For agent scope the record is also `superseded` when: the agent transcript advanced; or the main transcript contains a `SendMessage` to that `agent_id` after the error; or the main transcript contains ANY later `Agent` tool call whose `description` or sha1 of `prompt` equals the old agent's `.meta.json` description or brief, or whose `toolUseId` lineage links to it (a model that re-spawned the task under a new agent_id). Workflow scope is `superseded` when a later `Workflow` call has the same `runId` in `resumeFromRunId`, or a newer run of the same `scriptPath` and args exists.
- Age: measured from `resume_at` (or `first_seen` when there is none). Under `BORG_RESUME_MAX_AGE_HOURS` (48) from that instant, else `expired` plus notify. Limit-class records with a parsed future reset are additionally allowed up to a 7-day ceiling from `first_seen`, so a weekly limit that resets in 5 days is not expired before it fires.
- Cap: the session `consecutive` counter is below `BORG_RESUME_MAX_CONSECUTIVE` (3), else `capped` plus notify.
- Concurrency: at most `BORG_RESUME_MAX_ACTIVE` (2) sessions with an ACTIVE record in `injecting`, `injected`, or `confirmed` at once. Ordering of due records: orchestrator first, then oldest `first_seen`. Others stay `deferred` (reason `concurrency`) and are released as earlier ones reach `done`. This bounds the post-reset stampede, because each `--resume` is expensive and many simultaneous sessions would burn the fresh window.
- Headroom and limit cleared: the watcher runs its own probe, `borg-resume probe`, which calls `claude -p "/usage"` through the absolute `BORG_CLAUDE_BIN` and caches the result for 120s in `usage-probe.json`. A fresh `usage-guardian.json` (under 300s) may be used instead of probing. For limit-class records the probe runs at `resume_at` and must confirm the limit cleared and utilization is under `BORG_RESUME_HEADROOM_MAX` (90). Probe failure FAILS CLOSED for limit-class records: the record stays `deferred`, retries with backoff, and Noah is notified after 3 consecutive probe failures with the pointer to `borg doctor`. For non-limit classes an unknown headroom does not block (crash recovery must not depend on the probe), but the concurrency cap still applies. Stubbed in tests with `BORG_RESUME_USAGE_CMD`.
- Dispatch guard: the record is `deferred` (reason `dispatch_guard`) while the same headroom signal that `borg-dispatch-guard.sh` uses would deny `Agent|Workflow`, so the model is not sent into a veto. If the model is denied anyway, the prompt tells it to run `borg-resume defer <rid> --reason dispatch_guard`, which writes a deferral event instead of leaving the record `confirmed`.
- Pane bound, owned, and provably idle (see Pane binding and idle proof). If it cannot be proven the record stays `deferred`. There is no timeout after which the gate injects anyway.
- Rate: at most `BORG_RESUME_MAX_PER_PASS` (1) injection per watcher pass. This only staggers starts; the concurrency cap is what bounds simultaneous work.

### Pane binding and idle proof

Binding. At `SessionStart` the hook runs `tmux set-option -p -t "$TMUX_PANE" @borg_sid <sid>` (host sessions). The watcher resolves a session's pane ONLY by `tmux list-panes -a -F '#{pane_id} #{@borg_sid} #{pane_pid} #{pane_current_command}'` and selecting the pane whose `@borg_sid` equals the sid. A tmux server restart wipes the options and renumbers ids, so a stale registry `pane_id` can never match a different live session. For container (drone) sessions there is no `$TMUX_PANE`; the watcher binds host-side: it sets `@borg_sid` on the drone window's pane only when the window (by `@project_dir`) has exactly one claude pane, the drone container is healthy, and the transcript's recent writes are consistent with it. With two or more claude panes in the window the session stays unbound and the outcome is notify-only. The rightmost-claude-pane rule and window-name lookups (`borg sever`, `borg_tmux_find_window`) are used only to tell Noah where the session probably is in a notification, never to choose an injection target.

Ownership. Before every injection the watcher verifies, for host sessions, that the registry `claude_pid` is alive with the recorded start time and sits in the process tree of the pane's `pane_pid`. For container sessions it verifies the drone container is up and the transcript is that session's file. A failed check leaves the record `deferred` (or sends it to the liveness path if the process is dead).

Idle proof. All must hold, evaluated immediately before sending:

- `pane_state` from `tmux capture-pane -p` of the pane tail is `idle_empty`: the composer is present and empty, and no dialog is showing. `draft` (text in the composer), `dialog` (permission prompt, AskUserQuestion, plan approval, the usage-limit dialog, resume-size or trust prompt), `busy`, and `unknown` all block. Patterns are taken from captured real panes (S0a) so the classifier is fixture-driven.
- Positive idle signal: the newest `idle_prompt` Notification for the sid is newer than the transcript's last write, or the capture shows `idle_empty` (the limit state may not emit `idle_prompt`).
- No human at the keys: no attached tmux client has `#{client_activity}` newer than 30s (`tmux list-clients -F '#{client_activity}'`). A human typing means defer, not inject.
- Transcript quiet for 20s.

If the pane is at the limit dialog, the watcher does NOT send a dismissal key unless spike U16 proves a safe key sequence for this build; the default outcome is notify-only for that record with the pane's location. Text is sent as separate `send-keys -l` and Enter calls (the proven transport), so a queued prompt never interrupts a running tool.

### Relaunch (process death only)

- Never build a shell string from transcript or payload text. The `sid` must match the UUID regex, and `cwd` must be an existing directory that is a registered project dir, a known worktree of one, or under `BORG_RESUME_CWD_ALLOW` (default `/Users/noah/dev`). Anything else is `notify_only`.
- Pane gone, tmux up: orchestrator uses the `_borg_launch_in_tmux` path with `--resume <sid>`; drones use `drone up <project> --resume <sid>` (new flag, S3). Where the watcher itself creates a window it uses tmux's argv form (`tmux new-window -d -c "$cwd" -- claude --resume "$sid"`) so no shell parses the values.
- Pane alive at a shell prompt (`zsh`, empty prompt proven by `capture-pane`): send one line built with `printf %q` for both values: `cd <quoted-cwd> && claude --resume <quoted-sid>`.
- After launch the watcher polls `capture-pane` and handles the screens it may meet BEFORE any injection. The resume-size dialog ("Resuming the full session will consume a substantial portion of your usage limits...") is answered with the option that resumes the FULL session, because the summary option may fork the session id and break same-session Workflow resume (default; Decision 11 lets Noah choose the other way, and the exact keys are fixed by spike U17). The trust-folder prompt and any permission prompt are not answered: the record goes `notify_only` and the pane is left for the human. An unrecognized screen is also `notify_only`.
- Verify the resumed session: a `session_start` event for the same sid with `source:"resume"` must arrive and the pane's `@borg_sid` must be that sid. A different session id means the session forked: the ledger records the new id, `resumeFromRunId` is not used, and the prompt takes the "run the workflow from the manifest `script`" path. No verification within 90s means `notify_only`, and nothing is injected.
- tmux server gone (reboot): recorded, notified, and staged. `BORG_RESUME_MAX_RELAUNCH_PER_HOUR` (3) bounds how many relaunch per hour, orchestrator first. The rest wait or are run by hand with `borg resume run <rid>`.
- Docker not healthy (`docker info` fails): `deferred` with backoff; never `drone up` into a wedged VM.

## The resume prompt

Injected into the pane (one line, no newlines, sanitized like `borg-vinculum-watch`):

```
[borg-resume r_7f3a2c] Your work was interrupted (usage limit, now
reset). Read /Users/noah/.local/state/borg/resume/prompts/r_7f3a2c.md
and carry it out, then run: borg-resume ack r_7f3a2c
```

(In the real injection this is one line.) The rendered file `prompts/<rid>.md`:

```
# borg-resume r_7f3a2c  (attempt 1 of 3)

Interrupted: usage_limit, scope main + 2 agents + 1 workflow
When: 2026-10-12T05:02Z. Cause cleared: yes (limit reset 07:10 MDT).
This resume was triggered automatically. Do not ask the user whether
to continue. Resume now. Be brief.

## Step 0: check before acting
- Run: borg-resume inventory 00000000 --json
- If the conversation already moved on past the interruption (the
  user gave a newer instruction, or these items were already
  resumed), skip this file, run the ack, and say so in one line.
- If a tool call below is DENIED (dispatch guard or a permission
  rule), do not retry it. Run: borg-resume defer r_7f3a2c --reason
  denied, tell the user in one line, and stop.

## Step 1: what was in flight
Main task: "<turn_prompt_head>"
Checkpoint: <path of newest .borg/checkpoints file>

Workflows
- wf_ab12cd  script: <scriptPath>  state: unfinished
- wf_cd34ef  script: <scriptPath>  state: finished_with_failures
  (2 owned agents errored; see resume note below)

Agents (Agent tool only; interrupted-by-user ones are omitted)
- a0b6facb8e5d1b6ac  nanoprobe  "Write contributor docs"  errored
  worktree: <path>  branch: <branch>  dirty: yes, 3 commits ahead
  brief: <transcript path>, line 1
- (3 agents already done, nothing to do)

## Step 2: resume each item
Workflow, unfinished, partial, or finished_with_failures:
  Workflow({ scriptPath: "<scriptPath>", resumeFromRunId: "wf_ab12cd" })
  Completed agents return cached. If it fails with "nothing to
  resume", re-run with the same args as a new run and tell the user.
  No scriptPath on disk: write the manifest `script` to a file first.
  Workflow agents are resumed ONLY this way, never with SendMessage.

Agent (Agent tool), errored or orphaned:
  1. SendMessage({ to: "<agent_id>", message: "Continue from where
     you stopped. Check git status and git log in your worktree
     first. Do not redo committed work." })
  2. If SendMessage cannot reach it, re-spawn the same agent type
     with the ORIGINAL brief (read it from the transcript above)
     plus: "Work in the existing worktree <path>. Run git status and
     git log first and continue; do not recreate the branch."

Main task: continue the last task above from the checkpoint. Do not
restart finished steps.

## Step 3: close out
- Run: borg-resume ack r_7f3a2c
- One line to the user: what you resumed and what is still pending.
- If this prompt appears again for the same items without progress,
  stop and tell the user. The cap is 3.
```

Variants chosen by `class`:

- `transient`: header says "an API error interrupted this; it was retried automatically".
- `max_output_tokens`: adds "Work in smaller steps; write files incrementally".
- `prompt_too_long`: the first injected line is `/compact`, and the file is only injected after the compact boundary appears.
- `process_death`: header says the process was restarted with `--resume`; Step 0 adds "check `git status` in the cwd for half-written files".

Permissions for unattended runs: the prompt runs `borg-resume`, `Workflow`, `SendMessage`, and `Agent`. `install.sh` merges these allowlist entries into the global settings idempotently with jq (never project-level): `Bash(/Users/noah/.claude/bin/borg-resume:*)`, `Bash(borg-resume:*)`, `Read(/Users/noah/.local/state/borg/resume/**)`. `borg doctor` fails loudly if they are missing. Because this touches the global `settings.json`, it needs Noah's explicit OK (Decision 10). `Workflow`, `SendMessage`, and `Agent` are not added to the allowlist; if they would prompt, the post-confirmation watchdog reports `stalled`.

## Safety rules

- Idempotence: one ACTIVE record per (sid, scope); records grouped per session into one injection; a record leaves `injected` only via `confirmed` or a terminal state; the pre-flight supersede check blocks a second resume if anything else (native auto-continue, the user, the model, a re-spawned agent) already continued.
- Cap: `consecutive` increments per injection and resets when the session shows progress, defined as the transcript growing by at least 25 lines between confirmation and the next interruption (watcher-measured, no per-tool hook). At 3, state `capped`, one notification with the last error, no more injection until `borg resume run <rid> --force` or the session shows progress. Hard cap of 12 injections per session per day. Counters live only in the watcher-owned `state/<sid>.json`.
- Concurrency cap: at most 2 sessions actively auto-resumed at once (Pre-flight gate).
- Kill switch: `BORG_RESUME_DISABLE=1` (checked by hooks and watcher), the `DISABLED` sentinel (`borg resume pause`, survives launchd where env cannot change), and `.borg/no-resume` per project. Recording is also off when disabled by env; with the sentinel, recording continues but nothing injects.
- Notify-only classes: auth, billing, spend limit, model not found, repeated prompt-too-long, any record past max age, outside tmux, pane unbound or not provably idle for 10 minutes (notified once, still re-checked), a dialog-state pane, cap hit, failed confirmation, stalled resume, unrecognized launch screen, forked session id. Notification uses `_borg_osa_notify` (host side only, since container hooks cannot reach Notification Center) and states the exact manual command.
- Deliberate exit protection: `SessionEnd` reasons `prompt_input_exit`, `clear`, `logout` end the session deliberately, and a trailing interrupt marker ends a scope deliberately. `drone down` and `borg sever` call `borg-resume mark-closed <project>`. A session with no end record, or `other`, and open work and no interrupt marker, is treated as a death.
- Guardian: resume does not depend on `usage-guardian.json` being alive. It never raises the guardian's sweep; the sweep's `/borg-link-up` keeps its once-per-window behavior.
- Privacy and size: events keep 600 chars of assistant text; prompts and the ledger stay local; `watch.log` rotates at 1MiB.
- Prompt injection hygiene: text from transcripts that reaches `send-keys` is never included in the injected line (only `rid` and a fixed sentence), and the rendered file quotes transcript text as data inside fences. The same rule covers relaunch: payload `cwd` and `session_id` are validated and quoted, never interpolated raw.
- Degrade outside tmux: record and classify as normal; the watcher writes the prompt file and sends a notification with `borg resume run <rid> --print`. No fallback to other injectors.
- No new dependencies: bash 3.2 compatible, jq, tmux, launchd, `date -j`, and the existing `claude` binary.

## Interaction with native auto-continue and CronCreate

- Native `autoContinueAtUsageLimit`: leave it as the user has it. For a main-scope limit the watcher waits `BORG_RESUME_NATIVE_GRACE_SEC` (120s) after the reset, then the supersede check sees whether native fired (transcript advanced, or a `native_resume` hint event) and skips. If native is off or died with the process, borg resumes 2 minutes after the reset. Native does not cover subagents, workflow agents, non-limit errors, process death, or resets more than 24h away, which is why borg is still needed.
- PR #290's CronCreate change, where it still fits: keep the swap from the nonexistent `create_trigger` to `CronCreate` with `recurring:false` as the in-session fallback in the skill, used only when `borg-resume status` reports the watcher is not installed or not running (non-macOS, or launchd job missing). Keep its honest caveats (lost on exit, `RemoteTrigger` is cloud-only).
- Where it does not fit: as the primary mechanism. It is model-invoked (no turn when the main loop dies), session-scoped (lost on exit, reboot, closed pane), Workflow-only, and docs do not say it fires during a limit wait. The skill must first run `borg-resume status --json`; if the watcher already holds a record for that run, do nothing and tell the user the time. The CronCreate prompt gets "if the run already finished or was resumed, do nothing" so a late fire cannot double-run.
- `agents/borg-verifier.md` and `tests/verifier_resume.bats` from #290 are independent and merge as they are; S15 updates the text-grep test to the new contract.

## Test strategy

Principle: the decisive behaviors must be exercised against REAL payloads and a real tmux, not only against fixtures derived from the same assumptions.

- Fixture provenance. Every fixture in `tests/fixtures/resume/` is tagged in `fixtures.json` as `captured` (taken from a real Claude Code 2.1.296 run or a real transcript, scrubbed) or `synthetic`. A bats meta-test lists the fixtures each slice declares as `required_captured`, and fails if any is missing or tagged synthetic. S4 (hook), S7 (watcher) and S16 (E2E) therefore cannot go green on synthetic payloads alone.
- Spike results gate downstream slices. S0b runs the gating spikes and writes `spike/SPIKE_RESULTS.json` (id, outcome `pass|fail|unknown`, claude version, date, evidence path). Later slices' tests read it: a slice that depends on spike U6 asserts its outcome is `pass`, or asserts the documented fallback path was chosen. S5 and S6 do not start until U6, U7, U8, U1 and U15 are recorded; S8 until U9, U13 and U16; S11 until U17.
- Real-tmux tests. The injector and relaunch bats run against a private tmux server (`tmux -L borgtest`) hosting a fake `claude` script that prints captured composer, permission-dialog, AskUserQuestion, plan-approval, limit-dialog, resume-size-dialog and draft-in-composer screens. This exercises real `send-keys`, `capture-pane`, pane options and `list-clients`. Tests that need tmux skip with a named reason when it is absent.
- Real-claude smoke lane (local, not CI): `tests/smoke/resume_real.sh` runs the real `claude` binary with an isolated settings file that installs the logging hook, against (a) a local stub HTTP server returning a 429 `rate_limit_error` via the base-URL override, to capture a real `StopFailure` payload and synthetic record, and (b) a deliberately invalid model to capture `model_not_found`. Whether the stub proxy produces the same `StopFailure` as a true usage limit is itself spike U2.
- Negative cases are first-class: permission dialog, draft in composer, human typing (recent `client_activity`), limit dialog, reused pane id, tmux restart, Esc then pane kill, skipped agent, Ctrl+X Ctrl+K, re-spawned agent with a new agent_id, concurrent hook upsert plus watcher counter update.

## Slices

Deliverables are code artifacts. Tests are listed separately. Every slice is proven without a real limit, and every slice that consumes real payload shapes depends on the captured fixtures.

| Slice | Title | Depends |
|-------|-------|---------|
| S0a | Capture harness + fixtures | none |
| S0b | Gating spike run | S0a |
| S0c | Launchd claude viability | none |
| S1 | Ledger core + kill switch | S0a |
| S2 | Classifier + reset parser | S0a |
| S3 | Drone ledger mount | S1 |
| S4 | Hook script + wiring | S1,S2,S3,S0b |
| S5 | Inventory builder | S0b,S1,S2 |
| S6 | Prompt renderer | S5, S2 |
| S7 | Watcher: fold + scan | S1,S2,S5 |
| S8 | Inject lib + pane proof | S0b,S1,S4 |
| S9 | Pre-flight gate + confirm | S6,S7,S8,S0c |
| S10 | Liveness detector | S7, S8 |
| S11 | Relaunch + resume dialog | S10, S3 |
| S12 | launchd plist + install | S9, S0c |
| S13 | Doctor checks | S12 |
| S14 | CLI verbs | S1, S9 |
| S15 | Skill rewrite + #290 | S4, S9, S14 |
| S16 | E2E + real-claude smoke | S11,S13,S15 |

### S0a Capture harness and fixture manifest

- Deliverables: `scripts/spike-resume-payloads.sh` (installs a temporary logging hook for all candidate events into a temp settings file and prints captured payloads, plus pane captures via `capture-pane`); `tests/fixtures/resume/` with `fixtures.json` provenance tags.
- Fixtures: scrubbed CAPTURES where a real one exists on this machine (main transcript ending in synthetic `rate_limit`, the sleep-interrupted `beb3b143` transcript tail, `server_error`, `authentication_failed`, `invalid_request`, a user-interrupt ending, subagent trees with `.meta.json`, workflow trees with manifest and journal, pane captures of composer/permission/limit dialogs); `synthetic` entries only where no capture is possible (`max_output_tokens`, weekly-phrasing variants), each marked as such.
- Proof: `tests/resume_fixtures.bats` validates each fixture with jq against a shape checklist and verifies the provenance tags and the `required_captured` list per slice. Fixtures are scrubbed (no real paths beyond `/Users/noah/dev/example`).

### S0b Gating spike run

- Deliverables: `spike/SPIKE_RESULTS.json` populated by running the gating spikes on 2.1.296; `docs/resume/spike-results.md` summarizing evidence paths.
- Gating spikes (blocking the slices named in Test strategy): U1 and U2 (StopFailure for subagents and for 429), U6 (`--resume` keeps the session id and replays workflow results), U7 (`resumeFromRunId` accepted), U8 (journal shape for killed and null-result agents), U9 (pane and pid identity in hooks), U13 (send-keys queue behavior), U15 (Stop on Esc, Ctrl+X Ctrl+K, interrupt marker in agent transcripts), U16 (what the pane looks like after a limit and whether a dialog persists), U17 (resume-size dialog and its keys). Non-gating spikes are recorded as `unknown` and tracked.
- Tests: `tests/spike_results.bats` asserts the file exists, parses, and has an entry for each gating id; it does not assert `pass` (a `fail` outcome selects the documented fallback in the design).

### S0c Launchd claude viability (hard prerequisite for auto-injection)

- Deliverables: root-cause fix of the guardian's launchd failure (`com.example.borg.usage-watch` exits 1, empty stderr, since 2026-10-03; suspect `claude` resolution under the plist PATH) plus `borg-resume probe` calling `claude -p "/usage"` through an absolute `BORG_CLAUDE_BIN`.
- Proof: `launchctl kickstart` of a probe job shows exit 0 and a parsed `Current session: N% used` line from inside the launchd environment (recorded in `SPIKE_RESULTS.json` as `launchd_probe`); `tests/usage_watch.bats` stays green. Until this passes, S9 treats every limit-class record as `deferred` and notify-only, so the feature degrades safely.

### S1 Ledger core and kill switch

- Deliverables: `bin/borg-resume` with `record` (event append, the SessionStart-only registry write, pane facts via `tmux display -p -t $TMUX_PANE`, `@borg_sid` set) and `pause|unpause`; `lib/borg/resume-paths.sh` (state dir, kill-switch check, atomic append, tmp+mv, per-owner file helpers).
- Tests: `tests/resume_ledger.bats` using `BORG_RESUME_DIR`: event append is a single valid JSON line; 50 concurrent background appends all parse; the registry is written only by the `session_start` handler and a second `session_start` for the same sid replaces it atomically; concurrent hook registry upsert plus a watcher counter update on `state/<sid>.json` loses neither (the files have different owners); kill switch by env and sentinel; no-pane case; container case (`BORG_IN_CONTAINER=1` stub); `BORG_NO_SESSION_HOOKS`; a bash 3.2 syntax check as in `hook_bash32_parse.bats`.

### S2 Classifier and reset parser

- Deliverables: `lib/borg/resume-classify.sh` (error plus text to class and action; the bookkeeping allowlist; `is_interrupt_marker`; `last_meaningful_record`); `last_meaningful_with_close` (the last meaningful record plus a `trailing_clean_close` flag, true when a `system:turn_duration` follows it; `turn_duration` is in the bookkeeping allowlist so it never hides a synthetic error, and S10 reads the flag, not the record, to tell a finished turn from open work); reset-text parser with `BORG_RESUME_NOW_EPOCH` and zone handling via `TZ=<zone> date -j` (a reset text with no zone uses the machine local zone; the relative form parses only the duration after `resets in`; the absolute form accepts an optional `at`); unknown `error` kinds fail closed to `notify_only` and are logged with the raw kind. Extras beyond the minimum: `resume_plan` (class, action, resume_at with the grace and backoff schedule) and small transcript helpers.
- Tests: `tests/resume_classify.bats`, table-driven from the captured fixtures: each `error` value in the StopFailure list maps to the matrix class; "resets 7:10am (America/Denver)" and "resets Jul 7 at 7am (America/Denver)" and "resets in 3 hours" parse to the right epoch for fixed `NOW`; a time earlier than now rolls to tomorrow; unparseable falls to backoff; spend-limit and team-budget text map to `notify_only`; "Prompt is too long" maps to `prompt_too_long`; the captured `beb3b143` tail yields the synthetic `server_error` as the last meaningful record despite five trailing bookkeeping records; `[Request interrupted by user]` and `... for tool use]` are interrupt markers and a later user message cancels the marker.

### S3 Drone ledger mount

- Deliverables: bind mount of `resume/` into drone containers in the compose template in `drone.zsh` (so in-container hooks write the same ledger); `drone up <project> --resume <sid>` flag.
- Tests: extend `tests/drone_hooks.bats` / `tests/drone_pane.bats`: the rendered compose contains the mount; `--resume` passes through to the claude command line; without the flag the command line is unchanged (regression). Hook-in-container simulated with `/.dockerenv` stub path variable and the `in_container:true` registry field.

### S4 Hook script and plugin wiring

- Deliverables: `hooks/borg-resume-hook.sh` (thin, always exit 0, silent); `scripts/build-plugin.sh` Phase 4 entries plus regenerated `hooks.json` for the eight registrations (explicit `timeout: 5`, regex Notification matcher).
- Tests: `tests/resume_hook.bats` pipes each CAPTURED payload into the hook and asserts the event line, asserts empty stdout and exit 0 on garbage and empty stdin, asserts no `decision` key ever, asserts it is a no-op when `~/.claude/bin/borg-resume` is missing, asserts only `SessionStart` invokes tmux (stub records calls), and records the per-event wall time against the 100ms/50ms budgets. A `plugin_dedup`-style test asserts the mirror copy in `claude-plugins/borg-collective/hooks/` is self-contained (no `source` of repo lib) and `hooks.json` lists exactly the intended events and no `Stop`/`UserPromptSubmit`.

### S5 Inventory builder

- Deliverables: `borg-resume inventory <sid> [--json]` (Agent-tool agents, workflow agents, workflows, worktrees, checkpoint, turn state); host-side transcript resolution by glob on session id.
- Tests: `tests/resume_inventory.bats` over fixture trees: done, errored, orphaned, running (by mtime with `touch -t`), `interrupted_by_user`; the non-recursive glob never lists workflow agents under Agents; workflow finished, `finished_with_failures`, partial, unfinished, `interrupted_by_user`; brief reference points at line 1; worktree dirty flag using a throwaway git repo created in `$BATS_TEST_TMPDIR`.

### S6 Prompt renderer

- Deliverables: `borg-resume prompt <rid>` rendering `prompts/<rid>.md` from inventory plus record; the one-line injection string builder with sanitization.
- Tests: `tests/resume_prompt.bats`: golden files for each class variant, assertions that every `runId`, `scriptPath` and Agent-tool `agent_id` in the inventory appears, that no workflow-owned agent id appears under Agents, that `interrupted_by_user` items never appear, the injected line has no newline or control character, transcript text containing backticks, `$(`, and ANSI escapes appears only inside fences in the file and never in the line, and the file lines stay readable under 100 columns.

### S7 Watcher: fold and scan

- Deliverables: `borg-resume watch --once` (lock, fold events into `pending/`, dedupe on ACTIVE states only, state log, move terminal to `done/`, `confirmed` to `done` rules); scan detector for transcripts, Agent-tool and workflow agents, and workflow journals including finished runs.
- Tests: `tests/resume_watch.bats` with `BORG_RESUME_NOW_EPOCH`: hook event plus scan for the same error yields one record; two sessions yield two; a user-interrupt fixture yields none, and so does Esc followed by a pane kill (interrupt marker plus no SessionEnd); a skipped agent and a Ctrl+X Ctrl+K fixture yield none; auth fixture yields `notify_only`; a `finished_with_failures` workflow yields a workflow-scope record; a stale `confirmed` record does not swallow a new interruption with a new evidence uuid; the same uuid never creates a second record; a second `watch --once` run is a no-op (idempotent); an overlapping run exits on the lock; stale lock with a dead pid is taken over.

### S8 Inject lib and pane proof

- Deliverables: `lib/borg/inject.sh` (pane enumeration regex, text then Enter, double-Enter retry, `@borg_sid` resolution, ownership check, `pane_state` classifier, client-activity check), installed to `~/.claude/lib/borg/` by `install.sh`; the container-session binding rule.
- Tests: `tests/resume_inject.bats` against the private real-tmux server with the fake `claude`: the stubbed send-keys sequence matches the one `borg-usage-watch` produces for the same input (equivalence test; `borg-usage-watch` itself is not modified); `idle_empty` allows; permission dialog, AskUserQuestion, plan approval, limit dialog, resume-size dialog, and draft-in-composer all block and nothing is sent; a recent `client_activity` blocks; a reused pane id whose `@borg_sid` is another session is never targeted; after a tmux server restart nothing resolves; two claude panes in one window never bind a container session and never fall back to the rightmost; a dead `claude_pid` fails ownership; sourcing from a temp installed layout with a minimal `PATH` works.

### S9 Pre-flight gate and confirmation

- Deliverables: the pre-flight gate (pause, supersede incl. re-spawn lineage, age from `resume_at`, cap, concurrency, probe fail-closed, dispatch guard) inside `watch`; confirmation, retry, and the post-confirmation stall watchdog.
- Tests: `tests/resume_gate.bats` with `BORG_RESUME_PANES_CMD`, `BORG_RESUME_SENDKEYS_CMD`, `BORG_RESUME_USAGE_CMD` stubs: injection only at or after `resume_at`; not before; deferred when not provably idle and NEVER injected after 10 minutes of deferral (notified once, still deferred); deferred on probe at 95%; limit-class deferred when the probe fails and notified after 3 failures, non-limit class proceeds on unknown headroom; superseded when the fixture transcript has a newer assistant record; superseded on a `native_resume` event; superseded when a later `Agent` call re-spawns the same description with a new agent_id; cap after 3; expired at 49h from `resume_at`, but a weekly-limit record resetting in 5 days is not expired at day 3; third due session stays deferred behind a concurrency cap of 2 and is released when one reaches `done`; one injection per pass; confirmation by the prompt tag appearing in the transcript; `confirmed` becomes `done` on ack, on 25 lines of progress, and on the 30-minute timeout; retry then `failed`; `stalled` after a `permission_prompt` Notification with no progress; `borg-resume defer` writes a deferral event.

### S10 Liveness detector

- Deliverables: liveness detector (bound pane gone or at a shell, `claude_pid` dead, container gone, open work derived from the transcript tail, no deliberate end, 5-minute grace, early notification).
- Tests: `tests/resume_liveness.bats` with stubbed `tmux list-panes` and `docker ps` commands: idle session with no open work is never resumed; killed-with-agent-in-flight is; `prompt_input_exit` end is not; Esc then pane kill is not; `mark-closed` project is not; tmux down gives `notify_only`; Docker unhealthy defers.

### S11 Relaunch and resume dialog

- Deliverables: relaunch for host panes and the orchestrator (argv-form `new-window`, `printf %q` shell-prompt path, sid and cwd validation); post-launch screen handling and same-session verification.
- Tests: `tests/resume_relaunch.bats` on the private tmux server with a fake `claude` that shows the resume-size dialog, the trust prompt, a permission prompt, an unknown screen, a forked-session-id start, and a clean start: the full-session option is chosen and verified; trust, permission, and unknown screens go `notify_only` with nothing injected; a forked id switches the prompt to the manifest-script path; a `cwd` containing `$(touch pwned)`, a backtick, a space, a newline, or a quote runs nothing and produces a correctly quoted or rejected command; a non-UUID sid is rejected; the hourly relaunch cap holds with 5 dead sessions.

### S12 launchd plist and install

- Deliverables: `launchd/borg.resume-watch.plist` and `install.sh` rendering (label via `_borg_launchd_label`, absolute `BORG_CLAUDE_BIN`, PATH with `~/.local/bin`); `install.sh` installing `lib/borg/*.sh` and merging the allowlist entries (with Noah's OK).
- Tests: `tests/launchd_label.bats` extended for the new label; plist lints with `plutil -lint` on macOS (skipped on the ubuntu lane); an installed-layout test that runs `borg-resume watch --once` from the installed directory with a launchd-like environment; the allowlist merge is idempotent and never writes a project-level settings file.

### S13 Doctor checks

- Deliverables: `borg doctor` checks: watcher loaded, last `watch.log` line under 120s old, a probe that succeeds under the launchd environment, `usage-guardian.json` freshness (surfaces the currently dead guardian), allowlist entries present, installed lib files present.
- Tests: `tests/doctor.bats` extended with stubbed `launchctl print` output (running, not running, exit 1), a stale guardian fixture, a missing-allowlist fixture, and a failing probe.

### S14 CLI verbs

- Deliverables: `borg resume status|cancel|run|log|defer` in `borg.zsh` delegating to `bin/borg-resume` (pause and unpause already ship in S1 and are only wired here); `status --json` machine output used by the skill.
- Tests: `tests/resume_cli.bats` plus `tests/cli_contract.bats` entry: `status` lists records with state and due time (fixed `NOW`), `cancel <rid>` and `cancel --session` and `cancel --all` move records to `cancelled` and block re-creation for the same evidence uuid, `run <rid> --print` prints the prompt without injecting, `run --now` bypasses the wait but not the kill switch or the idle proof, `pause` creates the sentinel and the watcher then injects nothing.

### S15 Skill rewrite and PR #290 rebase

- Deliverables: rewritten `skills/borg-resume/SKILL.md` (manual and fallback path, CronCreate kept as the no-watcher fallback, doc fixes: remove the "limit is unpredictable" framing and the nonexistent `create_trigger`); rebase of #290's scheduler change onto it.
- Tests: `verifier_resume.bats` and `prose_contracts.bats` updated for the new contract (skill calls `borg-resume status --json` first, mentions `CronCreate` only as fallback, mentions `resumeFromRunId` and `SendMessage`, says workflow agents are never `SendMessage`d).

### S16 End-to-end and real-claude smoke lane

- Deliverables: `tests/resume_e2e.bats`; `tests/smoke/resume_real.sh` (local, not CI).
- Tests: E2E bats on the private tmux server with captured payloads: `stop_failure` payload into the hook, advance `BORG_RESUME_NOW_EPOCH` past reset plus grace, `watch --once`, assert one send-keys pair with the exact prompt line into the `@borg_sid`-bound pane, assert the prompt file lists the fixture workflow and errored agent, run `ack`, assert `confirmed` then `done` and counter reset after progress; the same flow with a SIGKILL-style fixture (no hook event, only liveness plus scan plus relaunch); the same flow with a permission dialog on screen asserting nothing is sent. The smoke script runs the real binary against the 429 stub and the invalid model and asserts the captured payloads match the checked-in captured fixtures' shape.

## Defaults (stated so you can override in a word)

- Auto-injection is ON once installed and the launchd probe is proven (S0c); recording is always on; `borg resume pause` is the off switch.
- Injection happens only with positive idle proof; otherwise notify and keep deferring. There is no inject-anyway.
- Native `autoContinueAtUsageLimit` untouched; borg waits 120s after reset.
- 3 consecutive no-progress resumes, 12 per session per day, at most 2 sessions auto-resumed concurrently, 1 injection per 30s pass.
- Age: 48h from `resume_at` (limit-class with a parsed reset: up to 7 days from `first_seen`).
- Weekly limit: auto, but never silent (notify at detection and 15 minutes before).
- Transient backoff 45s, 2m, 5m, 15m, then notify.
- Process death: 5-minute grace, relaunch with `claude --resume <sid>` (full-session option at the size dialog), same-session verification before injecting, max 3 relaunches per hour.
- Limit-class records fail closed when the `/usage` probe fails; other classes do not need the probe.
- Scope is main, Agent-tool agents, and workflows in one grouped resume per session; workflow agents only via their workflow.
- Deliberate interrupts (any trailing `[Request interrupted by user*]`) and billing/auth are never auto-resumed.

## Decisions

1. Auto-relaunch after a full reboot (tmux server gone)? Lean: stage it, cap 3 per hour, orchestrator first, rest by `borg resume run`. A reboot can strand a dozen sessions; relaunching all at once recreates the Docker VM wedge and a usage stampede.
2. Max age for a record? Lean: 48h from `resume_at`, with the 7-day ceiling for parsed limit resets. A resume days after a non-limit interruption would run on stale context; past the age the record notifies instead.
3. Prompt-too-long: auto `/compact` then resume, or notify only? Lean: try `/compact` once, notify on failure. It is the only exhaustion case with a known remedy, but it is spike-dependent (U12).
4. Pane-closed-by-user with work in flight: resume or not? Lean: resume after the 5-minute grace with a notification and a one-word cancel, because it is indistinguishable from a crash unless an interrupt marker is present (then never). Alternative is notify-only for that sub-case.
5. Guardian repair: now a HARD prerequisite (S0c), because the probe that gates limit-class resumes runs in the same launchd environment where the guardian fails. Scope is only what is needed for a working probe plus doctor visibility; broader guardian work (log rotation, staleness alarm design) stays a separate ticket. Lean: yes, do S0c first.
6. Ledger location for drones: bind mount `resume/` (S3) or spool through the already mounted `~/.config/borg`? Lean: mount, since it keeps one ledger; fallback spool if the mount cannot be verified.
7. Should the watcher also take over the guardian's `/borg-link-up` sweep? Lean: no, keep them separate.
8. Schedule a resume for the deliberately skipped agent? Lean: never; the user's intent wins.
9. Weekly limit: auto-resume with two notifications, or notify-only with the command? Lean: auto with notifications, because the whole point is unattended recovery, and the cancel is one command. Switch is `BORG_RESUME_WEEKLY=notify`.
10. Merge the three `borg-resume` allowlist entries into the global settings.json from `install.sh`? Lean: yes; without them an unattended resume stalls at a Bash permission prompt. This is the only change to global settings and needs Noah's explicit OK.
11. At the `claude --resume` size dialog, resume the full session or from a summary? Lean: full, because the summary may fork the session id and break same-session Workflow resume; it costs more usage. If the summary option is chosen, the workflow path is the manifest-script re-run.
12. Refactor `borg-usage-watch` to source the shared inject lib? Lean: not in this effort; revisit once the guardian has run healthy for a week.

## Risks

- A wrong supersede check could suppress a needed resume (false negative) or allow a double resume (false positive). Mitigation: the check ignores bookkeeping record types by an allowlist, covers a re-spawn under a new agent_id by description, prompt hash and toolUseId lineage, is fixture-tested with native-fired, re-spawned and nothing-fired transcripts, and `borg resume run --force` is the manual override.
- Injecting into the wrong or an unready pane. Mitigation: binding by `@borg_sid`, process ownership check, positive idle proof via `capture-pane`, client-activity check, no inject-anyway, and real-tmux negative tests. Residual: `capture-pane` pattern drift on a Claude Code update; the classifier returns `unknown` (blocks) when it cannot recognize the composer, and the fixtures are recaptured per version.
- Resume loops on a persistent non-limit error. Mitigation: the 3-resume cap with the progress definition, backoff series ending in notify.
- Resuming into a wedged pane (input loop dead). Mitigation: the confirmation step and 2 retries, then `failed` plus notify. The wedge itself is not detected as an interruption.
- `--resume` costs a large share of usage per the binary's own warning, and many sessions released by one reset multiply it. Mitigation: relaunch only for sessions with open work; the concurrency cap of 2; the hourly relaunch cap; fail-closed probe for limit-class; the prompt is deliberately short.
- Container hooks cannot reach the host ledger if the mount is missing. Mitigation: S3, plus the scan path reads transcripts from the host `~/.claude/projects` regardless, so detection still works without any hook; container panes bind host-side or stay notify-only.
- The usage guardian is currently dead (launchd exit 1, last sample 2026-10-03). Mitigation: resume does not read it by default and runs its own probe; S0c proves a probe works under launchd before limit-class auto-injection is enabled; `borg doctor` surfaces the failure. Not refactoring `borg-usage-watch` avoids adding a new failure surface to a script that is already failing in production.
- Unattended permission or dispatch-guard stalls. Mitigation: allowlist entries (Decision 10), dispatch-guard deferral, the `defer` verb, and the `stalled` watchdog.
- The `Notification` quota matchers are named but not documented; if they never fire, only the supersede check protects against double-fire. That is still sufficient on its own.
- Hook cost on rare events is a measured budget, not a claim; `Stop` and `UserPromptSubmit` are not hooked at all, which removes per-turn cost.
- Tolerated overlap: `borg-linkup-all` (outside the repo), `borg-usage-watch` and the new inject lib each implement the text-then-Enter transport; the equivalence test in S8 keeps them from drifting.

## Unverified assumptions (each needs a spike or test; G marks gating spikes recorded in S0b)

1. G. Does `StopFailure` fire for subagent API errors, and does the payload carry `agent_id`? Spike: run a nanoprobe with a deliberately invalid model override or during a forced network failure, with the S0a logging hook. Without it, the scan path covers subagents.
2. G. Does `StopFailure` fire for the weekly or session usage limit (429) in the main loop, does `error_details` include a structured reset, and does a local 429 stub proxy reproduce it? Spike: the smoke lane stub, or a real limit with the logger installed.
3. Does `SubagentStop` fire when a subagent dies of an API error, and does `agent_transcript_path` exist in the payload?
4. Does `SessionEnd` fire on SIGTERM and SIGHUP (tmux kill-pane) within its 1.5s budget, and with which `reason`?
5. Hook-write ordering: does the synthetic transcript record exist at the moment `StopFailure` runs? (Affects only the evidence uuid; dedupe also keys on time.)
6. G. Does `claude --resume <sid>` keep the same session id, and can `Workflow({scriptPath, resumeFromRunId})` then replay the saved results? Spike: run a small workflow, kill the process mid-flight, `--resume`, resume by runId. If the id changes, the fallback prompt path applies.
7. G. Does a fresh `Workflow` call accept `resumeFromRunId` at all in 2.1.296 (the docs say "ask Claude to relaunch")? Same spike.
8. G. Does a failed workflow `agent()` leave a `started` journal record with no `result`; does `agent()` returning null get journaled; and does `resumeFromRunId` re-run an agent whose journaled result is null or replay the null? Spike: kill or fail a workflow agent via a short-timeout fixture script, then resume.
9. G. Can a hook's `$PPID` or `$TMUX_PANE` identify the claude pid and pane for host sessions in 2.1.296 (as `notify.sh` assumes), and what identifies the pane for container sessions? Does `tmux set-option -p` from a hook persist? Spike: log `env | grep -i tmux` and `ps` ancestry from the hook on host and in a drone.
10. Is `~/.local/state/borg` reachable from inside the drone containers today? Evidence so far is negative (no mount in `drone.zsh`); S3 assumes it must be added.
11. Is the default of `autoContinueAtUsageLimit` on or off here, and does its firing add a transcript record or Notification we can key on? Spike: `claude -p "/config"` style inspection, then an observed real limit.
12. Does `/compact` succeed when the prompt is already too long? Spike with the prompt-too-long fixture session.
13. G. Does a queued `send-keys` input to a busy session behave (queued, not interrupting) in 2.1.296, and does text sent while a permission dialog is open really act on the dialog (the reason it is blocked)? Spike with the private tmux server.
14. Does the Docker wedge leave transcripts and the ledger intact on the bind mounts, and does a hook write during a wedge fail open within the 5s timeout?
15. G. Does `Stop` fire on Esc, and does Ctrl+X Ctrl+K stop background agents with a trailing `[Request interrupted by user*]` in their transcripts? Is the marker always the last meaningful record after Esc? Claude-code #9516 reports Stop does not fire on interrupt; unconfirmed on this machine. Also: which transcript record exactly closes a clean turn (`system:turn_duration` assumed).
16. G. What does the pane look like after a main-loop limit (idle composer, or a persistent limit dialog with auto-continue off), does `idle_prompt` fire there, and is there a safe key sequence that dismisses the limit dialog? Default if unknown: dialog means notify-only.
17. G. Exact text, option order, and keys of the `claude --resume` size dialog, and which option keeps the session id. Also what the trust-folder and permission prompts at launch look like for `capture-pane` detection.
18. Hook matcher anchoring: does the Notification matcher `idle_prompt|permission_prompt|quota_auto_resume_.*` match as an anchored regex or a substring?

## Review disposition

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| 1 | blocker | Inject-anyway, no idle proof | applied |
| 2 | blocker | Interrupt not a deliberate end | applied |
| 3 | blocker | Relaunch dialog + shell quoting | applied |
| 4 | major | Pane resolution unbound | applied |
| 5 | major | Workflow agents, null results | applied |
| 6 | major | Double-resume, confirmed state | applied |
| 7 | major | Storm control, probe fail-open | applied |
| 8 | major | Weekly limit vs 48h age | applied |
| 9 | major | Hooks-only-append vs registry | applied |
| 10 | major | Fixtures synthetic, spikes manual | applied |
| 11 | major | Unattended permission stalls | applied |
| 12 | minor | Sleep-case scan order | applied |
| 13 | minor | Slice sizing, usage-watch refactor | applied* |
| 14 | minor | Hook cost, matcher notation | applied |

- 1 applied: the inject-anyway fallback is removed; the gate requires `pane_state == idle_empty` from `capture-pane`, a positive idle signal, and no attached-client activity within 30s; anything else is notify-only and keeps deferring. Bats cases for permission-dialog, AskUserQuestion, plan-approval, limit-dialog and draft-in-composer panes are in S8 and S9.
- 2 applied: a trailing `[Request interrupted by user*]` record closes the scope as `interrupted_by_user` in the scan, inventory, and liveness paths; the "excluded for free" claim is replaced; Stop-on-Esc and Ctrl+X Ctrl+K are spike U15; fixtures and the Esc-then-pane-kill test are in S2, S7 and S10.
- 3 applied: sid UUID validation, cwd allowlist, argv-form `new-window` and `printf %q`; resume-size dialog handled explicitly (full-session option by default, keys fixed by U17) with same-session verification via the resumed `session_start` event before any injection; trust and permission prompts go notify-only.
- 4 applied: `@borg_sid` pane option set at SessionStart, resolution only by it, process-ownership check, no rightmost-pane fallback for injection, reused-pane-id and tmux-restart tests.
- 5 applied: `finished_with_failures` is a detected state; workflow agents are a separate kind and never get `SendMessage`; spikes U6, U7, U8 are gating and run before S5 and S6.
- 6 applied: supersede covers a later `Agent` call with the same description, prompt hash or toolUseId lineage; `confirmed` is ACTIVE with defined exits to `done` or `stalled`; dedupe applies only to the pre-confirmation states.
- 7 applied: concurrency cap of 2 with priority order, own probe, limit-class fails closed, absolute `BORG_CLAUDE_BIN`, and the launchd probe fix is the hard prerequisite S0c (Decision 5 changed from "separate ticket").
- 8 applied: age is measured from `resume_at`, with a 7-day ceiling for parsed limit resets; the weekly policy is auto-but-never-silent (Decision 9).
- 9 applied: no file has two writers; the registry is immutable facts written only by SessionStart, turn state and ended are derived, and counters live in the watcher-owned `state/<sid>.json`; the concurrent-update test is in S1.
- 10 applied: fixtures carry `captured`/`synthetic` tags with a `required_captured` meta-test, S0b writes `SPIKE_RESULTS.json` that later slices read, a real-tmux test lane and a local real-claude smoke lane (429 stub, invalid model) are added.
- 11 applied: allowlist entries delivered by `install.sh` (needs Noah's OK, Decision 10), dispatch-guard denial is a deferral reason with a `defer` verb, and the post-confirmation `stalled` watchdog is added.
- 12 applied: "last meaningful record" is defined by a bookkeeping allowlist and tested against a scrubbed capture of the `beb3b143` tail (S2).
- 13 applied*: S7, S8, S10, S12 and S15 are split as requested and drone support moves ahead of the hooks (S3 before S4); lib files are installed explicitly and tested from the installed layout; the duplicate pause/unpause in S11 is removed. Adjusted on one point: instead of refactoring `borg-usage-watch` to source the new lib, the refactor is dropped from this effort (Decision 12) and an equivalence test guards against drift, which avoids a new failure surface in a script that is currently failing under launchd.
- 14 applied: `Stop` and `UserPromptSubmit` are no longer hooked (state is derived from transcripts), tmux is called only at SessionStart, hook timeouts are explicit at 5s, the Notification matcher is the regex `quota_auto_resume_.*` form (anchoring is U18), and the latency budgets are measured in S4 rather than asserted.
- Rejected findings: none.
