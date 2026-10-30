# Implemented, current state and hotkey

Reference moved verbatim from the top-level CLAUDE.md.

## Current State (v2, release v0.9.13)

### Implemented
- Core borg CLI: init, claude, next, link, switch, scan, add, rm, help, and the
  wider command surface below (recon, nanoprobes, spend, doctor, focus, pin/unpin,
  setup, store-secret, down, tidy, reap-worktrees, and more — see `borg help`).
  **`watch` and `sync` were both listed here and NEITHER is a command.** Neither has an arm in
  `borg.zsh`'s case dispatch, and both exit 1 with `unknown command`; removed 2026-08-28. (`sync`
  survived the first removal pass because only `watch` was checked — the whole line has now been run
  name-by-name against the dispatch, which is what a partial sweep costs. The only `cmd_sync` in the
  tree belongs to `merge-tree/coordinator.py`, a different CLI.) `borg help` is the surface of record.
  **The `ls`/`status`/`hail`/`brief`/`briefing`/`refresh` aliases for `link` were removed
  2026-08-10** — six names for one command meant the docs, skills, and research all disagreed
  about what to call it. `borg link` is the only name.
- CoCo (Cortex Code CLI) integration: session discovery, `[X]` badge in `borg link`
- `drone` CLI: up, down, claude, sh, restart, rebuild, fix, feature, cortex, exec, toggle, pane,
  scaffold, link. **`status` was listed here and is not a command** — there is no `cmd_status` in
  `drone.zsh` and no `status)` arm in its case dispatch; `./drone.zsh status` exits 1 with "unknown
  command 'status'". Removed 2026-08-28, same reason as `borg watch` above. The drone table below is
  the surface of record.
- Hooks (18, incl. borg-nanoprobe-guard): borg-link-down.sh (status=active + latest-checkpoint injection), borg-link-up.sh
  (status=idle + uncommitted-changes tracking + no-checkpoint nudge), borg-notify.sh, plus
  bash-guard, borg-dispatch-guard, borg-agent-model-guard, borg-workflow-model-guard, borg-memory-read-log, borg-plan-promote, borg-supabase-guard, borg-verifier-guard, borg-resume-hook, borg-nanoprobe-log, borg-prefer-tool-log,
  notify, pre-commit-remind, tool-count-nudge (full list under Files below)
- Skills (16): adhd-guardrails, borg-link-up, borg-plan, borg-review, borg-assimilate, borg-verify,
  pane, and 9 more (full list under Files below)
- Agents (6, ephemeral nanoprobe roster): borg-grunt, borg-nanoprobe, borg-researcher,
  borg-reviewer, borg-scout, borg-verifier (routing guide: docs/agent-routing.md)
- Usage guardian: 85% checkpoint sweep (bin/borg-usage-watch) + `borg-dispatch-guard.sh`
  >=92% hard-stop veto on new Agent/Workflow dispatch — both fail-open, dispatch-guard is
  default-OFF (`BORG_USAGE_HALT_ENABLED=1` to arm)
- Recon fan-out: `borg recon --json` / `/borg-recon` — pluggable source adapters, since-mark
  resolution, checkpoint-vs-source contradiction detection. **`recon` retired as a human verb
  2026-08-26** (bare `borg recon` dies pointing at `borg link`); the engine and its two machine
  flags (`--json`, `--adapters`) survive
- Doorways one-screen board (v0.9.10): the Queen page (`borg link --overview`) is one screen of about 50 lines with
  a legend, `--full` restores the long form, and the page no longer contradicts itself; `/borg-link` paints the CLI
  page verbatim; `borg next --line` is a one-line glance (at most 80 columns); `borg setup --statusline` is the
  opt-in Claude Code status line (`--statusline=off` removes it); a tmux `status-right` string is in
  `docs/agents/commands.md`; `/borg-next` shows preview cards (additive `card` field in `--json`). `borg next` no
  longer marks a PR stacked on an open PR as mergeable now
- Arrival brief (v0.9.11): `hooks/borg-arrival-brief.sh` is a SessionStart hook that prints a four-line brief (last
  time, next, watch out, since then) as a visible message when a session starts or resumes in a repository; the Queen
  session gets one line, the same as `borg next --line`; a repository session gets the directory name as its title,
  only when it has none. It is built from the same document as `borg link`, plus one additive `--json` key,
  `focus.since.head_moves`. Directive: `docs/plans/assimilated/2026-10-18-arrival-brief-on-sessionstart.md`
- One owned next list (v0.9.12): `borg next`, `borg link` and the arrival brief read each repository's newest
  checkpoint whole. The items under `Waits on you:` become YOU rows, the `Next Session` items become AGENT rows (a
  checkpoint older than 30 days adds none), and a checkpoint newer than `PROJECT_PLAN.md` replaces the plan row. The
  Queen's own checkpoint feeds the Queen scope, and `/borg-link-up` writes the `Waits on you:` list. A row with no
  owner shows as `unowned` and is counted apart (`+N unowned`), and when a checkpoint holds a Next Session item,
  every surface names it with its owner instead of saying nothing is ready. The repository page shows Last time,
  Waits on you and Next whole, wrapped, capped by whole items with `+N more  borg link --full`; the 5-row cap on
  decisions that are yours shares its slots across repositories so the Queen's rows are not pushed out. `--json`
  gains additive keys only (`hidden.unowned`, `waiting.next`, `waiting.next_items`; `DOCUMENT_VERSION` stays 2).
  `evals/link-next` replaces the `borg-link` and `borg-next` eval waivers. Directive:
  `docs/plans/assimilated/2026-10-20-one-owned-next-list.md`
- 0.9.13: borg-plan in Cortex plan mode. Cortex registers an inject (PostToolUse `EnterPlanMode`), a gate (PreToolUse `ExitPlanMode`, exit 2 without Acceptance Criteria, Scope Boundaries and a Plan-slug; `BORG_PLAN_GATE=off` disables) and a promote (PostToolUse `ExitPlanMode`, writes `docs/plans/PROJECT_PLAN.md` and the team `plan-<task-id>.md`) in `hooks.json`; `tests/cortex_payload_replay.bats` replays synthetic Cortex payloads through every registered hook. Evidence: `docs/evidence/2026-10-cortex-*.md`. Directive: `docs/plans/assimilated/2026-10-22-borg-plan-in-cortex-plan-mode.md`
- 0.9.13: borg's six agents load in Cortex Code. `borg setup` copies `agents/*.md` to `~/.snowflake/cortex/agents/` (`_borg_install_cortex_agents`, `tests/cortex_agents.bats`). borg-grunt and borg-scout carry one-line descriptions (Cortex skipped the folded `>` form) and the four Sonnet agents pin `claude-sonnet-5-5` (Cortex ignores the `sonnet` alias and runs the session model); `tests/agent_frontmatter.bats` pins both rules. Cortex registers an agent under its exact `name:`, so the next entry installs the copies as `borg-collective:<name>`.
- 0.9.13: one agent name in both CLIs, and the guard and run logger work in Cortex Code. `borg setup` installs each Cortex agent copy as `name: "borg-collective:<name>"` (`_borg_cortex_agent_copy`), so borg-verify, the routing card and the guard's namespaced allowlist resolve in Cortex too. `hooks/borg-agent-model-guard.sh` is registered in Cortex's `hooks.json` (`Agent|Task`; twelve entries now) with two Cortex-only rules after the shared policy block: a per-call model must be a full `claude-sonnet-*`/`claude-haiku-*` id (Cortex ignores aliases), and Cortex's own Snowflake agents need such a pin. `hooks/borg-nanoprobe-log.sh` and `borg nanoprobes` read `<id>.history.jsonl` beside Cortex's `<id>.json` snapshot, so Cortex rows carry a model and effort and a real write is no longer flagged ZERO-WRITE. Cortex has no per-agent effort, so `borg setup` warns when `CORTEX_THINKING_EFFORT` is `xhigh` or `max`. Tests: `tests/cortex_agents.bats`, `tests/agent_model_guard.bats`, `tests/cortex_hooks.bats`, `tests/cortex_payload_replay.bats`, `tests/zero_write_transcript.bats`, `tests/nanoprobe.bats`, `tests/nanoprobes_columns.bats`; live evidence and its offline replay: `evals/cortex-agents/` (`live.sh` against headless Cortex 1.2.24, `run.sh` in CI). Guide: `docs/agent-routing.md`, "Cortex Code".
- 0.9.13: a smaller session context. The `borg-link-up`, `borg-plan` and `borg-collective-review` skill bodies are shorter, with their reference prose in `references/` files read on demand; a nudge tells the session to start fresh at 75 tool calls; the CLAUDE.md history moved to `docs/agents/learned.md`. PRs 468, 469 and 470.
- 0.9.13: `drone up` starts the shared dev-postgres only for repositories that name it under `.devcontainer/`, so a repository that does not use it no longer starts it. PR 473.
- `borg-sync` (lib/borg-sync.zsh): mtime-based file sync helpers shared by the CLI and hooks
- Auto-memory read instrumentation: `borg-memory-read-log.sh` (PostToolUse/Read) logs every read
  of a Claude Code project-memory file to `$BORG_DIR/memory-hits.log`; `bin/memory-hits-report`
  computes reads/session against a pre-registered null (see cairn's decommission research)
- Work/life boundary checks on switch
- Capacity warnings
- tmux hotkey (Ctrl+Space >)
- Registry-based repository tracking with atomic writes
- User-authored session checkpoints at <repository>/.borg/checkpoints/<ts>.md (via /borg-link-up)
- Session context loaded at start from the latest checkpoint
- `borg init` launches the Queen: morning briefing from registry + checkpoints

### Hotkey

`Ctrl+Space >` — jump to most pressing repository (runs `borg next --switch`)

