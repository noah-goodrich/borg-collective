# hooks/ rules

Rules owned by this directory, moved verbatim from the top-level CLAUDE.md. Claude Code loads this file when a file under hooks/ is read.

- **A hook body's language is decided by SUBPROCESS COUNT, not by taste — and this QUALIFIES a ratified
  decision.** `docs/plans/assimilated/2026-08-11-python-core-toolchain-and-enforced-clean-architecture.md`
  concluded "**Hooks stay shell — permanently, and this is arithmetic rather than preference**", and the
  arithmetic compared `zsh -c true` against `python3 -c pass`, times ~250 tool calls a session. That is a
  comparison between EMPTY INTERPRETERS, and it is the whole of the recorded basis. Measured on the shipped
  artifact, the comparison inverts: `hooks/bash-guard.sh` costs MORE than Python's entire interpreter startup
  (`python3 -c pass`) on every machine measured, and an equivalent Python guard costs startup plus a few ms.
  The bash hook loses because it is not one process: it is bash plus roughly two dozen `sed`/`grep`/`tr`/`jq`
  forks per call.
  **The tests pin the direction only.** Any ratio below is an observation with a machine attached, and absolute
  figures swing with load and hardware (about 35% between runs on one machine), so none is a contract. Method:
  20 sequential runs, total wall clock / 20, `printf '%s' "$P" | bash hooks/bash-guard.sh`. On one Darwin arm64
  machine (M3 Pro) the hook measured 63.5 ms/call on a typical payload, 80.1 ms on one built to defeat early
  exit, and `python3 -c pass` 24.1 ms, about 2.6x; a second machine measured 4.4 to 4.8x. The direction held in
  every 20-run mean on both.
    1. **At most one helper process** (env vars, paths, exit codes, a single `jq` read) → **shell**. Genuinely
       cheaper, and this is the majority of the 13 hooks.
    2. **Two or more** (JSON parse PLUS string work — the shape of every real policy hook) → **Python 3,
       stdlib only**, behind `command -v python3 >/dev/null 2>&1 || exit 0` so a machine without an
       interpreter degrades the way the fail-open contract requires.
    3. **Never node or ruby in a hook body** — their interpreter startup is worse than the bash they would
       replace.
  **The ratified line is not wrong, it is narrow**: trivial hooks really do stay shell. What it never measured
  is a hook that works. Do NOT read this as licence to port hooks wholesale — `bash-guard.sh` spawns two dozen
  subprocesses and qualifies, but porting it is worth doing when it next needs a substantive change, not as a
  migration.
- **Queen vs repository sessions**: every Claude Code / Cortex Code SessionStart,
  Stop, and Notification hook now classifies the session via `_borg_session_mode` (in
  `lib/borg-hooks.sh`). A session whose `$CWD` *exactly* equals `$BORG_ORCHESTRATOR_ROOT`
  (default `$HOME/dev`) is the **Queen** session (`orchestrator`) — it renders a cross-repository overview
  on start and writes **nothing** to `~/.config/borg/registry.json`. Every other CWD is a
  **repository** session (the mode value stays `project`, a contract name) and uses the existing
  per-repository flow (status flips, checkpoint
  injection, uncommitted-change tracking). Two-variable vocabulary: `BORG_ORCHESTRATOR_ROOT`
  is the workspace root; `BORG_ROOT` (exposed by `install.sh`) is the install path of the
  borg source tree.
- **Log retention (AC4 part C)**: every unbounded append-only writer in the state root (plan-promote-debug.log,
  cortex-plan-debug.log, memory-hits.log, agents.jsonl, prefer-tool.jsonl, pr-watch.log, usage-watch.log, usage-samples.jsonl) calls
  `_borg_rotate_log` (`lib/borg-hooks.sh`; Python sibling `borg_core/retention.py::rotate_log`) immediately before
  its append. At `BORG_LOG_CAP_BYTES` (default 1 MiB) the file is renamed to `<file>.1`, ONE generation, replacing
  any older `.1`. Fail-open and silent. Readers that need history read `.1` then the live file: `memory-hits-report`
  and `borg nanoprobes` / `nanoprobe-log`. The briefing stderr logs are overwritten per run, not appended, so they
  are bounded already. `data.json.bak.<timestamp>` has no writer in the tree (hand-made copies of the merge-tree
  board's `data.json`); the board is slated for retirement, so no retention was built for it.
- **Auto-plan promotion (`borg-plan-promote.sh`)**: a `PreToolUse` hook that fires on `Edit`,
  `Write`, and `NotebookEdit`. When Claude exits plan mode (`ExitPlanMode`) and the user
  proceeds to the first file edit, the hook scans the session JSONL for the most recent
  `ExitPlanMode` call since the current user turn, extracts the plan, and writes it to
  `<repo-root>/docs/plans/PROJECT_PLAN.md` — silently, without blocking. Gates: repository-mode
  only, edit target inside repo, no existing `PROJECT_PLAN.md` at either canonical location,
  cwd is a git repo. Always exits 0 (never blocks on any failure). Idempotent: if
  `PROJECT_PLAN.md` already exists, the hook is a no-op.
- **`cmd >> file 2>/dev/null` does NOT silence a redirect-open error**: bash opens redirection
  targets left-to-right BEFORE the command runs, so it opens `>> file` while fd2 is still the
  terminal — a missing directory prints `<script>: line N: <path>: No such file or directory` to
  stderr no matter where `2>/dev/null` sits on the same simple command. In a hook whose stdout is
  JSON, and whose stderr a consumer merges into stdout (`bats run`, any `2>&1` wrapper), that leaked
  line splices ahead of the JSON and breaks `jq`. Fix: brace-group so the stderr redirect is
  established first — `{ cmd >> "$dir/f"; } 2>/dev/null` — or `mkdir -p "$dir"` before writing.
  This bug kept claude-plugins CI red for weeks (borg-link-down.bats 12/14/15, "Invalid numeric
  literal at line 1, column 88" — the 87-char CI hook path + `: line N:`). It only reproduces where
  the target dir is absent; the CI bats setup overrode `HOME` but not `XDG_CONFIG_HOME`, so the
  hook recomputed `BORG_DIR` from the runner's real config home, which didn't exist in the sandbox.
- **Hooks recompute their own config paths — test isolation must override `XDG_CONFIG_HOME` too**:
  `borg-link-down.sh` derives `BORG_DIR` from `${XDG_CONFIG_HOME:-$HOME/.config}/borg`, ignoring any
  exported `BORG_DIR`. A bats suite that overrides only `HOME` leaks the host/runner
  `XDG_CONFIG_HOME` into the hook and points it outside the sandbox. Override both (or unset
  `XDG_CONFIG_HOME`) in hook-integration test setup.
- **macOS `/bin/bash` 3.2: a failed `source` is fatal under `set -e`, even inside `{ ...; } || true`**: `borg-nanoprobe-log.sh` (`set -euo pipefail`) exited 1 BEFORE appending its row on a machine with no `~/.claude/lib` (plugin installed, `borg setup` never run) or with `borg-hooks.sh` present but its sibling `reaper.sh` missing. The other two log hooks (`borg-memory-read-log.sh`, `borg-prefer-tool-log.sh`) lack `-e`, so the change there is hardening. Run best-effort sources in a subshell, `( source ... && ... ) >/dev/null 2>&1 || true`; the three log hooks now do. When `reaper.sh` is missing the rotation is skipped for that call, but the row is still appended. Linux bash 4+ does not reproduce it, so only the contract-macos lane exercises `tests/hook_rotate_subshell.bats`, which must invoke `/bin/bash hook` explicitly (the `env bash` shebang resolves to Homebrew bash) and must reset `~/.claude/lib`, which `setup_temp_dirs` pre-populates.
- **`borg-arrival-brief.sh` (SessionStart, `startup|resume` only)**: prints the arrival brief as a top-level `systemMessage`, four lines in a repository session and exactly `borg next --line` in the Queen session. A thin bash wrapper over `borg_core/link/arrival_hook.py` (pure renderer: `borg_core/link/arrival.py`). It makes ONE `borg` call (`link <repository> --json`, or `next --line`), spawns no `git`, and writes no registry. `_borg_session_mode` and `_borg_find_repository` are ported to Python and `tests/arrival_brief.bats` runs both on one table, so change them together. It is copied by `build-plugin.sh` WITHOUT the "borg on PATH" guard, because a missing borg must print one `unavailable` line, never nothing. It APPENDS to PATH (the lifecycle hooks prepend) so a caller's `borg` wins. `sessionTitle` is the directory name, only in a repository session and only when the input's `session_title` is empty; the hooks doc says it renames the session like `/rename`, and the 2026-10-18 spike saw it become the session's name in the agent list, which is why the Queen never gets one (her address comes from ListAgents). Latency: the hook adds about 0.1 s to `borg link --json`'s 1.0 to 1.5 s.
- **Cortex plan mode (`borg-cortex-plan.sh` and the Cortex branch of `borg-plan-promote.sh`, 2026-10-22)**: Cortex hook payloads carry Claude-style tool names (`ExitPlanMode`, `EnterPlanMode`), a `transcript_path` ending `.json` (not Claude's `.jsonl`), and `permission_mode` that stays `default` in plan mode, so nothing branches on it. `borg-cortex-plan.sh` is Cortex-only (not in `build-plugin.sh`; `borg setup` copies it with the other `hooks/*.sh`): PostToolUse `EnterPlanMode` prints `additionalContext` (PostToolUse context reaches Cortex's model, SessionStart's does not), PreToolUse `ExitPlanMode` exits 2 unless the plan has Acceptance Criteria, Scope Boundaries (or a "NOT building" line) and a `- Plan-slug:` line. No-op in the Queen session, outside git, with a `PROJECT_PLAN.md` present, and with `BORG_PLAN_GATE=off`. `borg-plan-promote.sh` takes an early branch on `hook_event_name == PostToolUse` for `ExitPlanMode|exit_plan_mode`: only when the response says "Plan mode has ended", it writes `docs/plans/PROJECT_PLAN.md` from `tool_input.plan` and overwrites the team file `.cortex/plans/plan-<task-id>.md` named after "Plan saved to"; the underscore `plan_<timestamp>.md` files are never touched. Registration is by tool-name matcher in `_borg_register_cortex_hooks` (entries are `event|script[|matcher]`). Debug log: `cortex-plan-debug.log` in the state root. Tests: `tests/cortex_plan_hook.bats`, `tests/plan_promote.bats`, `tests/cortex_hooks.bats`, `tests/cortex_payload_replay.bats` (synthetic payloads in `tests/fixtures/cortex/`). Directive: `docs/plans/assimilated/2026-10-22-borg-plan-in-cortex-plan-mode.md`.
- **Context nudge and the PreCompact checkpoint (#503)**: `tool-count-nudge.sh` nudges on context size, read from `${XDG_CACHE_HOME:-$HOME/.cache}/borg/context/<session_id>.json`, which `bin/borg-statusline` writes atomically from the statusline stdin (`context_window.total_input_tokens` is the context in the window now, not a running total). It fires at `BORG_CONTEXT_NUDGE_TOKENS` (default 120000), again every +40k, re-arms when the context shrinks (a compaction), and falls back to the 75-call count when the file is missing, which is always the case unless `borg setup --statusline` was run. `borg-precompact-checkpoint.sh` (PreCompact, plugin only) is a thin wrapper over `borg_core/checkpoint/precompact_hook.py`; it writes where `/borg-link-up` would (`prepare_shell.repository_root`, so the Queen lands in the orchestrator root) and only where borg already lives (`.borg/` or `.borg-project` in the root, or the Queen's directory). **The newest checkpoint is read whole by `borg next`, `borg link` and the arrival brief, so an automatic checkpoint must not hide the real one: it carries the previous checkpoint's tl;dr, Goal, Blockers (with `Waits on you:`) and Next Session forward verbatim**, and says in prose, with no list item, when there was nothing to carry. A `<!-- borg:auto-checkpoint ... -->` comment marks it. A same-session retry (PreCompact fires on every attempt, including a failed one) refreshes the file in place. Measured 2026-11-02 with `claude -p`: PreCompact fires headless, `CLAUDE_CODE_AUTO_COMPACT_WINDOW=100000` forces compaction, and a prompt that is one giant message fails with `too_few_groups`, so fill the context with several Read calls instead.
