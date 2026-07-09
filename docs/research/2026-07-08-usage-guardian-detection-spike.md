# Usage-Guardian — Detection Feasibility Spike (Findings)

*Date: 2026-07-08 · Branch: `feat/usage-guardian-detection-spike` · Plan: `PROJECT_PLAN.md`*
*Scope: read/doc-only go/no-go. No guardian built. Resume engine pre-locked to local launchd.*

## VERDICT: GO

A trustworthy, **zero-token, zero-cost, server-authoritative** usage signal exists and is reachable
non-interactively. The predictive path is viable.

**Signal**  — `claude -p "/usage"` → stdout line `Current session: N% used · resets <when>`
**Threshold** — checkpoint all active drones at `session_pct >= 85`; hard-stop new dispatch at `session_pct >= 92`;
warn on `week_pct >= 90`.

This **falsifies** the assumption written into the shipped `borg-resume` skill (§4), which states the account limit
"is not predictable from inside a session." It is not exposed *to hooks or workflows* — but a **subprocess** shells
out to it for free. That one fact is the whole spike.

---

## AC1 — Is `/usage` parseable non-interactively?

**YES.** Working PoC, verified on Claude Code `2.1.205`:

```sh
claude -p "/usage" | awk -F'[:%]' '/^Current session:/ {gsub(/ /,"",$2); print "session_pct=" $2}'
```

Verified behaviours:

- **Needs a PTY?** No — ran piped into `head`/`awk`, output intact.
- **Model inference cost:** Zero. `--output-format json` reports `total_cost_usd: 0`, `num_turns: 0`, and all
  token counts `0`.
- **Wall latency:** 0.9 s – 3.7 s, timed across 8 invocations.
- **`claude usage` subcommand:** absent. Not in `claude --help` `Commands:` — the slash command is the only path.
- **Machine-readable output:** partial. `--output-format json` wraps the **human text** in `.result`; there is no
  structured usage object.

Raw output (verbatim):

```
Current session: 21% used · resets Jul 9 at 1:20am (America/Denver)
Current week (all models): 39% used · resets Jul 14 at 7am (America/Denver)
Current week (Fable): 26% used · resets Jul 14 at 7am (America/Denver)
```

### The number is server-authoritative, not a local guess

This is the load-bearing question for trust, and it resolves in our favour. The bundled binary
(`~/.local/share/claude/versions/2.1.205`) contains the endpoint literal **`/api/oauth/usage`** and the response
schema field names:

```
 112 utilization      98 seven_day      41 five_hour
  25 resets_at         9 rate_limit_tier  5 seven_day_oauth
```

So the three percentages come from Anthropic's own rate-limit accounting — **account-wide, all devices**. The
`duration_api_ms: 0` in the JSON envelope is *not* evidence of a local computation; that field counts **model
inference** time only, and `/usage` performs none.

The caveat printed in the output — *"Approximate, based on local sessions on this machine"* — sits under the
**"What's contributing to your limits usage?"** heading and qualifies only the *attribution breakdown* (top
subagents/plugins/MCP), not the three headline percentages.

Corroborating: the percentage tracked **live** across the spike (21% → 22% → 23%) as this session burned quota.

### Three failure modes the guardian must handle

1. **Silent blind failure under a stripped environment.** With `env -i HOME=… PATH=…`, `/usage` prints **nothing**
   and still **exits 0**. The discriminator is **`USER`** — without it the keychain OAuth lookup fails silently:

   | Environment | Result |
   |---|---|
   | `HOME` + `PATH` | *(no usage output, exit 0)* |
   | `HOME` + `PATH` + `USER` | `Current session: 23% used …` |

   **This is the single biggest implementation trap.** launchd hands jobs a minimal environment. The plist **must**
   set `USER` (plus `HOME`, `PATH`) via `EnvironmentVariables`, and the parser **must fail closed** — an empty parse
   means `UNKNOWN`, never `0% used`.

2. **`--bare` destroys the signal.** `--bare` skips keychain reads and forces `ANTHROPIC_API_KEY`/`apiKeyHelper` auth,
   so there is no OAuth subscription to report on. It prints only the cost footer. The tempting "skip hooks with
   `--bare`" optimisation **cannot be used**.

3. **Each poll appends a `$0` record to `token-spend.jsonl`.** The `SessionEnd` hook fires for `-p` sessions.
   Measured: 253 → 254 → 255 records across two polls. **`--settings '{"hooks":{}}'` does NOT suppress this**
   (tested; the record count still incremented). It is benign — `est_cost_usd: 0`, and no registry mutation, since
   `registry.json` mtime was unchanged across polls — but downstream token-cost analytics should filter
   `est_cost_usd > 0`, or the guardian should carry an env guard the hook respects. Filed as a build task, not a
   blocker.

---

## AC2 — Is `token-spend.jsonl` usable as a live estimate?

**NO. It is structurally incapable of being a live signal.** Not "inaccurate" — *blind*.

`~/.claude/token-spend.jsonl` is written by a **`SessionEnd`** hook. A session contributes **nothing until it ends**.
Confirmed directly: the live session ID for this spike returns **0 matches** in the file while running.

That is fatal, because per `/usage`'s own attribution, **98% of last-24h usage came from subagent-heavy sessions** and
**53% of 7d usage from sessions active 8+ hours** — i.e. exactly the long-lived sessions that are still open, still
burning, and still absent from the file. The signal is missing precisely the thing it would need to measure.

Schema check — no window/limit/percentage field exists:

```
keys: cwd end_reason est_cost_usd main project schema session_id subagents ts
paths matching limit|window|pct|percent|reset|quota  →  NONE
```

Attempting the correlation anyway, over the current 5-hour window: 11 records, **`$184.77`** total — dominated by
`dev $126.59` and `troth $51.21` (both *other* projects, already ended), with the current session at `$0`. Meanwhile
`/usage` reported `22%`. There is no way to falsify a `$ → %` mapping from this:

- The rate limit is **not dollar-denominated**. It is weighted by model, request count, and context size (`/usage`
  itself reports `72% of your usage was at >150k context` as an independent factor).
- `est_cost_usd` is an **API-pay-as-you-go-equivalent** figure, explicitly not the subscription's accounting unit.
- Anthropic's window math is unpublished.

**Error bound: unbounded, and unfalsifiable.** Any threshold derived from it would be the exact "false-confidence trap"
named in the plan's risk list. `token-spend.jsonl` remains excellent for **post-hoc** cost accounting; it must not be
promoted to a guardrail.

---

## AC3 — Filesystem / API / env sweep for undocumented sources

Everything checked, and its result:

1. `~/.claude/` top level, any `usage|limit|quota|rate|window` entry — **ABSENT**.
2. `~/.claude.json`, all 60 top-level keys — **ABSENT**. The nearest misses are `cachedExtraUsageDisabledReason`,
   `pluginUsage`, `skillUsage`, and `passesLastSeenRemaining`; none carry window state.
3. `~/.claude/statsig/` — **ABSENT**, the directory does not exist.
4. `~/.claude/projects/**`, grepped for `resetsAt|rate_limit|usage_limit|five_hour` — **ABSENT** as state; the only
   match was a workflow script.
5. `~/.claude/token-spend.jsonl` — **FOUND**, but carries no window or quota field. See AC2.
6. Session transcripts, 429 errors — **FOUND**, roughly 20+ sessions carry one, shaped as
   `{"error":"rate_limit","apiErrorStatus":429,"message":…"You've hit your session limit · resets 7:10am
   (America/Denver)"}`. Reactive only: it arrives *after* the cap.
7. Bundled binary `2.1.205` — **FOUND**. Contains `/api/oauth/usage`,
   `/api/claude_code/discovery/team_usage`, and the `five_hour` / `seven_day` / `utilization` / `resets_at` /
   `rate_limit_tier` schema.
8. Env vars `CLAUDE*` / `ANTHROPIC*` — **FOUND** but irrelevant: `CLAUDE_EFFORT`, `CLAUDE_CODE_ENTRYPOINT`,
   `CLAUDE_CODE_CHILD_SESSION`, `CLAUDE_CODE_EXECPATH`, `CLAUDE_CODE_SESSION_ID`, `CLAUDECODE`, `ANTHROPIC_SDK_KEY`.
   No quota, limit, or reset variable.
9. `claude --help` `Commands:` — **ABSENT**. No `usage` subcommand; the list is `agents auth auto-mode doctor
   gateway install mcp plugin project setup-token ultrareview update`.

**Conclusion:** there is exactly **one** usable source — the `/usage` slash command, which fronts `/api/oauth/usage`.
No file, env var, or subcommand exposes it. Calling `/api/oauth/usage` directly was **considered and rejected**: it
would require extracting the OAuth token from the keychain and hand-rolling refresh, trading a supported (if
text-formatted) surface for an unsupported one. Shell out to the CLI.

---

## AC4 — Prior art

### `borg-resume` skill — `~/.claude/skills/borg-resume/SKILL.md`

*(Note: the skill is installed to `~/.claude/skills/` but has **no source under `borg-collective/skills/`** — it is
unowned by the canonical repo. Flagged; not fixed in this read-only spike.)*

- Fires **reactively**, after a Workflow returns a usage-limit failure/pause.
- Takes two coordinates from the failure output: `scriptPath` and the `wf_…` `runId`.
- Parses the reset time out of the human error string (`resets 7:10am America/Denver`); defaults to `+60 min` if absent.
- Schedules a **one-shot** trigger (`create_trigger` / `run_once_at`) that re-fires
  `Workflow({scriptPath, resumeFromRunId})` — completed `agent()` calls return cached, so no work is lost.
- Explicitly disclaims prediction: *"It cannot predict the account limit (that headroom is not exposed to
  hooks/workflows) … the account limit itself is not predictable from inside a session."*

**Reuse takeaway:** `borg-resume` is the **resume half, already built and correct** — keep it verbatim. This spike
only invalidates its stated *premise*. The guardian supplies the missing **prevention half**; `borg-resume` remains the
safety net for when prevention is bypassed (e.g. a limit hit between polls). Its `resumeFromRunId` caching is what makes
a pre-emptive checkpoint cheap to recover from. **Update the skill's disclaimer** as part of the build.

### `cortex-wake` launchd job — `launchd/com.stillpoint-labs.borg.cortex-wake.plist` + `bin/borg-cortex-watch`

- `StartInterval` = **30**; `ProgramArguments` = `["{{CORTEX_WATCH_BIN}}", "--once"]` — runs once, exits 0.
- Scans tmux panes where `pane_current_command == "cortex"`, regex-matching `Your limit will reset in N hours|minutes`.
- Persists `{pane_id, session, window, project, reset_at, detected_at}` to `~/.config/borg/cortex-wakes.json` via
  **atomic tmp+`mv`**.
- Fires `tmux send-keys "wake up!" Enter` when `reset_at <= now + 60s` grace; re-resolves pane IDs across tmux restarts;
  prunes orphaned entries; appends to `/var/log/borg/cortex-wake.log`.

**Reuse takeaway:** this is the **exact skeleton the guardian should clone** — launchd `--once` + interval, atomic
JSON state, grace window, orphan pruning, append-only log. The one inversion: cortex-wake *scrapes a TUI pane
reactively*;
the guardian *polls an authoritative endpoint predictively*. Every other mechanic transfers. Critically, it already
proves the launchd→tmux delivery path works, which is how a checkpoint gets driven into a live drone pane.

### `lib/reaper.sh` — `_borg_reap_worktrees`

- Invoked on demand (`borg reap-worktrees`) / hourly launchd, not continuously.
- Staleness = branch merged (`git merge-base --is-ancestor`) **or** mtime older than `BORG_REAP_STALE_HOURS`
  (default 12).
- **Refuses to act on a worktree with uncommitted changes** (`lib/reaper.sh:108`).

**Reuse takeaway:** the safety pattern — *never destroy unsaved work; skip and report instead.* The guardian's
checkpoint sweep must adopt the same stance: if a drone cannot be checkpointed cleanly, log and leave it alone rather
than force anything. Also supplies the `BORG_*_HOURS`-style env-tunable-threshold convention for `BORG_USAGE_*`.

---

## AC5 — Recommendation

### VERDICT: GO — predictive, with a reactive backstop

**Detection strategy: predictive.** Poll `claude -p "/usage"`, parse `session_pct` + `week_pct` + `resets_at`.

**Concrete signal**

```sh
claude -p "/usage" 2>/dev/null | awk -F'[:%]' '
  /^Current session:/            {gsub(/ /,"",$2); print "session_pct=" $2}
  /^Current week \(all models\):/ {gsub(/ /,"",$2); print "week_pct=" $2}'
```

**Concrete thresholds**

- **`session_pct >= 85` → checkpoint every active drone** (`/borg-link-up`). This leaves ~15% of a 5-hour window.
  Observed peak burn was ~1% per 4 min under heavy multi-agent orchestration, so 85% still buys roughly an hour —
  ample for N sequential checkpoints.
- **`session_pct >= 92` → hard-stop new nanoprobe/workflow dispatch.** Preserves the remainder for checkpoint and
  handover writes.
- **`week_pct >= 90` → warn only**, do not auto-checkpoint. The weekly window resets on a 7-day boundary, so a
  checkpoint sweep does not help.
- **Parse empty or non-numeric → `UNKNOWN`, take no action**, log, and alert after 3 consecutive. Fail closed;
  never coerce to `0`.

*Burn-rate caveat: the ~1%/4min figure is a single observation from this session, not a characterised rate. The build
should log `(timestamp, session_pct)` pairs for a week before anyone tunes 85 downward.*

**Poll cadence:** 120 s baseline; 60 s once `session_pct >= 70`. Polling is free in tokens, but each poll spawns a
~1 s CLI process and appends a `$0` record, so there is no reason to match cortex-wake's 30 s.

**Why not reactive-only:** the 429 transcript error (AC3 #6) arrives *after* the cap — at which point the drone cannot
write its own checkpoint, which is the entire failure we are trying to prevent. Reactive stays as the backstop:
`borg-resume` already covers it.

**Residual risk — TUI format drift.** The signal is a human-formatted string, not a stable API contract, and it lives
in a binary that auto-updates. Mitigation: fail-closed parsing (above) + a `bats` test asserting the regex against a
captured fixture, so a Claude Code upgrade that reformats the line breaks the suite loudly instead of silently
disarming the guardian. This is a real, permanent maintenance tax and the honest cost of the GO.

---

## AC6 — Read/doc-only

No shipped skill, hook, plist, or library was modified. `git status` shows only this findings doc and the build
directive. Side effects of probing were confined to append-only telemetry (~8 `$0` records in `token-spend.jsonl`) —
`~/.config/borg/registry.json` mtime was verified unchanged.

## Follow-up

Build directive filed: `docs/plans/directives/2026-07-08-usage-guardian-build.md`
