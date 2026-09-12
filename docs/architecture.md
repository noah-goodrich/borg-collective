# Architecture Guide

How every component of Borg fits together.

---

## System Overview

Borg is an AI development orchestration framework with two layers:

1. **`borg` (orchestration)** — Runs on the host. Manages a JSON registry of projects, scores
   priorities, enforces work/life boundaries, launches an orchestrator Claude session for morning
   briefings, and provides the `borg next` / `Ctrl+Space >` hotkey for instant context switching.

2. **`drone` (project lifecycle)** — Runs on the host. Manages Docker Compose containers, tmux
   windows, and pane layouts. Launches Claude Code sessions inside project containers. Forked
   from `dev.sh`.

Knowledge persistence is file-based: user-authored session checkpoints are stored per-project at
`<project>/.borg/checkpoints/`. (Borg previously integrated with cairn, a separate
PostgreSQL+pgvector knowledge graph service, for cross-project semantic recall; cairn was
decommissioned 2026-08-08 and its corpus exported to per-project `.borg/knowledge/` markdown,
which is grep-reachable directly — no service required.)

### Data Flow

```
Session lifecycle:

  drone up project          → Container starts, tmux window created
  drone claude project      → Claude Code session begins
  borg-link-down.sh fires   → Registry: status=active
                            → Injects additionalContext: latest checkpoint
                            ↓
  [developer works]         → Claude uses skills, reads checkpoint from last session
                            ↓
  Claude needs input        → borg-notify.sh fires → Registry: status=waiting + reason
                            ↓
  Developer runs /borg-link-up before stopping:
                            → Skill writes structured checkpoint to
                              <project>/.borg/checkpoints/<YYYY-MM-DD-HHMM>.md
                            ↓
  Session ends              → borg-link-up.sh fires:
                               1. Registry: status=idle
                               2. Warn if uncommitted changes remain
                               3. Nudge if no recent checkpoint exists
```

### Registry Writes

All registry updates are atomic: write to `registry.json.tmp.$$`, then `mv` to `registry.json`.
This prevents corruption from concurrent hook executions.

---

## File System Layout

### Repository

The repo has grown past a size where a full file listing stays accurate for long — run
`ls hooks/ lib/ skills/ agents/ launchd/ bin/` for the current, complete inventory. As of this
writing: **12 hooks**, **~14 lib files**, **17 skills**, **6 agents** (5 specialists + `ROUTING.md`),
**5 launchd plists**, plus `bin/` pollers (`borg-usage-watch`, `borg-cortex-watch`,
`borg-vinculum-watch`, `borg-notifyd`, `run-in`).

```
~/dev/borg-collective/
    borg.zsh                    Main orchestration CLI
    drone.zsh                   Project lifecycle CLI
    lib/
        registry.zsh            Registry CRUD
        tmux.zsh                tmux window listing + switching
        claude.zsh              Session discovery from ~/.claude/projects/
        coco.zsh                Session discovery from ~/.snowflake/cortex/projects/
        desktop.zsh             Claude Desktop session reader
        recon/adapters/         Recon source adapters (recon-adapter-<source>)
        borg-hooks.sh           Shared bash helpers used by hooks (not sourced by borg.zsh)
        borg-sync.zsh           Skill/hook sync helpers
        drone-hooks.zsh         Project-side pre-up/post-down hook runner
        reaper.sh               Stale-worktree reaping (portable sh core for `borg reap-worktrees`)
        colors.zsh, secrets.zsh Output styling + secret handling helpers
    borg_core/                  Python core; the zsh CLI dispatches into it via `_borg_py`
        paths.py                Config-path resolution + defaults
        registry/               Registry read/write core, shell adapter, CLI entry
        recon/                  Recon fan-out engine (ported from the deleted lib/recon.sh)
        manifest/               Reader for <project>/.borg/programs/*.json program manifests
        link/                   `borg link` document build + renderer
    hooks/
        borg-link-down.sh       SessionStart → status=active + checkpoint injection
        borg-link-up.sh         Stop → status=idle + uncommitted warning + checkpoint nudge
        borg-notify.sh          Notification → status=waiting + reason
        borg-plan-promote.sh    PreToolUse (Edit/Write/NotebookEdit) → auto-promote ExitPlanMode plan
        borg-dispatch-guard.sh  PreToolUse → >=92% usage dispatch veto (Usage Guardian)
        borg-nanoprobe-log.sh   SubagentStop → append nanoprobe completion to agents.jsonl
        bash-guard.sh, borg-supabase-guard.sh, notify.sh,
        pre-commit-remind.sh, tool-count-nudge.sh  Smaller guardrail/reminder hooks
    skills/
        adhd-guardrails/        Cognitive load guardrails (always active)
        borg-plan/              Project planning + Collective review
        borg-assimilate/        Shipping checklist + Collective review + execution
        borg-collective-review/ Adversarial multi-persona review (The Collective)
        borg-review/            Mid-session diagnostic + loop detection
        borg-link/              Consolidated project intelligence (overview + deep dive)
        borg-link-up/           Flush session state to a per-project checkpoint file
        borg-recon/             Synthesize cross-source recon fan-out into an ELI10 briefing
        borg-next/, borg-resume/, borg-switch/, borg-verify/, break-glass/,
        simplify/, fable-reviewer/, no-unnecessary-read-perms/   Remaining user-invocable skills
    agents/
        borg-grunt.md            Haiku — fully-specified mechanical execution
        borg-scout.md            Haiku — read-only locate/search
        borg-nanoprobe.md        Sonnet — single-task judgment work (implement/fix/refactor)
        borg-researcher.md       Sonnet — from-zero web research, one track
        borg-reviewer.md         Sonnet/high — blind adversarial review
        ROUTING.md               Model/effort routing matrix for all of the above
    bin/
        borg-usage-watch         Usage Guardian poller (see below)
    launchd/
        com.stillpoint-labs.borg.notifyd.plist       fswatch presence daemon
        com.stillpoint-labs.borg.cortex-wake.plist    30s Cortex Code session watcher
        com.stillpoint-labs.borg.reap.plist           Hourly `borg reap-worktrees`
        com.stillpoint-labs.borg.usage-watch.plist    Usage Guardian poller schedule
        com.stillpoint-labs.borg.memory-gate.plist    Daily auto-memory read-instrument check
    install.sh                  Installer
    docs/                       Documentation
```

### Runtime State

```
~/.config/borg/
    config.zsh                  User configuration (work hours, limits)
    registry.json               Project registry (auto-managed by hooks)

<project>/.borg/
    checkpoints/                User-authored session checkpoints (written by /borg-link-up)
        2026-04-23-1114.md
        2026-04-22-1730.md

~/.claude/
    hooks/                      COPIES of hooks/*.sh, refreshed by `borg setup`
        bash-guard.sh           (not symlinks — devcontainers bind-mount ~/.claude and
        borg-link-down.sh        cannot follow host-absolute symlink targets)
        borg-link-up.sh
        ...                     all 12 hooks in hooks/
    lib/                        COPIES of lib/*.sh, sourced by the hooks at runtime
    bin/                        COPIES of bin/*, put on PATH for hook and skill helpers
    skills/                     NOT borg's. `borg setup` DELETES every directory here
                                bearing a .borg-managed marker; hand-authored skills stay.
    agents/                     NOT borg's. `borg setup` DELETES any file here whose name
                                matches a source agent (borg-nanoprobe.md, …).

~/dev/claude-plugins/borg-collective/    ← where skills and agents actually live
    skills/                     17 skills, built from this repo's skills/
    agents/                     6 agent definitions, built from this repo's agents/
    hooks/hooks.json            hook registration (NOT ~/.claude/settings.json)

~/.local/bin/
    borg                        Symlink → borg.zsh          (install.sh)
    drone                       Symlink → drone.zsh         (install.sh)
    borg-notifyd, borg-cortex-watch, borg-usage-watch, borg-memory-gate,
    borg-vinculum-watch         Symlinks → bin/*            (install.sh)

~/Library/LaunchAgents/         install.sh only — `borg setup` never touches launchd
    com.stillpoint-labs.borg.notifyd.plist
    com.stillpoint-labs.borg.cortex-wake.plist
    com.stillpoint-labs.borg.usage-watch.plist
    com.stillpoint-labs.borg.reap.plist
    com.stillpoint-labs.borg.memory-gate.plist
```

See [Deployment Model](#deployment-model-source--distro) below for who writes each of these, and
`docs/diagrams/deployment-ownership.html` for the same map as a picture.

---

## Deployment Model: Source → Distro

This repo is **source**. `~/dev/claude-plugins/borg-collective` is **build output**. Claude Code
loads the build output, never this repo. Everything below follows from that one fact, and most of
the surprising details ("why did setup delete my skills?") stop being surprising once you have it.

```
borg-collective/            scripts/build-plugin.sh        claude-plugins/borg-collective/
  skills/         ───────────────────────────────────────▶   skills/
  agents/              (invoked by `borg setup`, step 4a-ii)  agents/
  hooks/                                                      hooks/  + hooks.json
                                                                     │
                                                                     ▼
                                                        Claude Code loads the plugin
                                                        (claude plugin install
                                                         borg-collective@noah-local)
```

**Three producers, disjoint targets.** Nothing writes to a path another one owns:

- **`install.sh`** → `~/.local/bin/` symlinks and the five `~/Library/LaunchAgents/` plists
  (notifyd, cortex-wake, usage-watch, reap, memory-gate). Run once, by a human. **`borg setup` does
  not touch launchd** — a new launchd job needs an `install.sh` run.
- **`borg setup`** → `~/.claude/hooks/`, `~/.claude/lib/`, `~/.claude/bin/`. **Copies, not
  symlinks**, deliberately: devcontainers bind-mount `~/.claude`, and a host-absolute symlink target
  does not resolve inside the container.
- **`scripts/build-plugin.sh`** → `~/dev/claude-plugins/borg-collective/`. Called by `borg setup`
  (step 4a-ii). Writes skills, agents, curated self-contained hooks, and the `hooks.json` that
  registers them.

**`borg setup` also deletes.** Two sweeps, both idempotent and both one-time migrations that match
nothing on a machine that never ran the pre-plugin installer:

- `~/.claude/skills/*/` — removed, but **only** directories carrying a `.borg-managed` ownership
  marker. Hand-authored neighbours are untouched.
- `~/.claude/agents/<name>.md` — removed for every file whose name matches an agent in this repo's
  `agents/`.

These were the pre-plugin copy loops. Leaving them in place alongside the plugin caused
double-loading, so setup now removes them. **Skills and agents do not live under `~/.claude` at
all.**

**Hook registration moved too.** It is no longer written into `~/.claude/settings.json`; the
plugin's `hooks/hooks.json` owns it. `borg setup` actively *unregisters* the literal-path
`$HOME/.claude/hooks/...` entries that earlier versions wrote, so the plugin can own them without
hooks firing twice. Note that there is no `hooks/hooks.json` in this repo — `build-plugin.sh`
generates it into the distro.

**The direction is one-way, and guarded.** Source → distro, never the reverse. Editing the distro
is how the two rosters silently diverge, so `scripts/check-agent-roster.sh` asserts that every
agent in `agents/` has an identical twin in the distro and vice-versa, failing loudly with a
per-file breakdown when they drift. The inversion is not available even in principle: Cortex Code
has no plugin system, so the plugin cannot be the source of truth for both runtimes.

**One exception.** Because CoCo cannot load plugins, CoCo skills still install directly from
`$BORG_HOME/skills` via `cortex skill add` (`borg setup`, step 3). That is the only case where a
skill installs outside the plugin.

The same map, drawn: [`docs/diagrams/deployment-ownership.html`](diagrams/deployment-ownership.html).

---

## Registry Schema

```json
{
  "projects": {
    "project-name": {
      "path": "/absolute/path/to/project",
      "source": "cli",
      "tmux_session": "borg",
      "tmux_window": "project-name",
      "claude_session_id": "uuid",
      "last_activity": "2026-03-30T14:30:00Z",
      "status": "active",
      "summary": "Short description from latest checkpoint or plan",
      "pinned": false,
      "waiting_reason": "Claude needs permission to use Bash",
      "goal": "Optional: project objective from /borg-plan",
      "done_when": "Optional: acceptance criteria from /borg-plan"
    }
  }
}
```

**Status values**: `active`, `waiting`, `idle`, `archived`, `unknown`

**Source values**: `cli` (Claude Code), `desktop` (Claude Desktop), `coco` (Cortex Code CLI)

---

## CLI Architecture

### borg.zsh

Follows `dev.sh` conventions: `set -e`, case-statement dispatch, `cmd_*` functions, colored output
via `info`/`warn`/`die`.

```
borg.zsh
  ├── PATH setup + hash -r (non-interactive zsh fix)
  ├── Source lib/*.zsh
  ├── Load config.zsh (boundaries, limits)
  ├── Helpers (_borg_relative_time, _borg_boundary_check, _borg_active_count,
  │           _borg_orchestrator_context)
  └── Dispatch: case "${1:-help}" — one arm per verb, in source order
      ├── init              cmd_init                Briefing context → claude --append-system-prompt
      ├── claude            cmd_claude              claude --continue from BORG_ORCHESTRATOR_ROOT
      ├── next              cmd_next                Priority scoring → recommendation → switch
      ├── link              _borg_link_dispatch     → borg_core.link.cli (the seven-section document)
      ├── switch            cmd_switch              fzf picker or direct switch
      ├── recon             (inline)                → borg_core.recon.cli; machine surface only
      ├── scan              cmd_scan                Auto-discover from session history
      ├── add               (inline)                → borg_core.registry.cli add
      ├── rm                (inline)                → borg_core.registry.cli rm
      ├── color             cmd_color               tmux window color
      ├── image             cmd_image               Session image
      ├── pin / unpin       cmd_pin / cmd_unpin     Pin a project to the top of borg link
      ├── sever | down      cmd_down                Retire/archive without deleting
      ├── regenerate | tidy cmd_tidy                Housekeeping over registry/checkpoints
      ├── setup             cmd_setup               Hooks + lib + bin, plugin build, tmux keybinding
      ├── store-secret      cmd_store_secret        Patch a project's secrets.zsh
      ├── start             cmd_start               Promote a directive to PROJECT_PLAN.md
      ├── focus             cmd_focus               Zoom current pane / project window
      ├── cortex-resume     cmd_cortex_resume       Resume a CoCo session
      ├── nanoprobes | np   cmd_nanoprobes          List recent ephemeral subagent runs
      ├── nanoprobe-log     cmd_nanoprobe_log       Fetch a nanoprobe transcript/summary
      ├── spend             cmd_spend               Token spend from ~/.claude/token-spend.jsonl
      ├── reap              cmd_reap                Reap stale active/waiting statuses
      ├── reap-worktrees    cmd_reap_worktrees      Clean stale nanoprobe worktrees
      ├── doctor            cmd_doctor              Environment/dependency health check
      ├── chain             cmd_chain               Program/chain manifests
      ├── vinculum | vinc   cmd_vinculum            Cross-session message bus (see vinculum.md)
      ├── version|--version|-V  cmd_version
      ├── help|--help|-h    cmd_help                Command reference (also the no-arg default)
      ├── ls|status|hail|brief|briefing|refresh     Removed 2026-08-10 — die, pointing at `link`
      ├── program                                   Renamed 2026-08-31 — die, pointing at `chain`
      └── *                                         die "unknown command"
```

`cmd_ls` and `cmd_status` still exist as functions, but they are internal helpers with no dispatch
arm — `borg ls` and `borg status` die with a pointer at `borg link`. `cmd_hail` does not exist at
all. Derive this tree from the `case` block rather than hand-editing it; it has drifted before.

### drone.zsh

Forked from `~/dev/dev.sh`. Same conventions. Manages:
- Docker Compose container lifecycle
- tmux window creation (side-by-side 2-pane layout by default)
- Container shell access
- Claude Code session launching inside containers

---

## Hook Architecture

Hooks are bash scripts that read JSON from stdin. They run inside the same environment as the Claude
Code session (which may be inside a container).

```bash
INPUT=$(cat /dev/stdin 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')
```

**Design rules:**
- Always exit 0 (failures must not block Claude)
- Registry writes are atomic (tmp + mv)
- Graceful degradation (if registry is missing, skip)
- Fast path only — no LLM calls in hooks; the expensive work (authoring checkpoints) is user-driven

### Link-up / Link-down Semantics

The hook names reflect a collective metaphor: at session start, the drone **links down** from the
host — it pulls state (the latest checkpoint) into the session. At session end, the
drone **links up** — it flushes state back (status update, uncommitted-changes warning, checkpoint
nudge). The user-invoked `/borg-link-up` skill is the explicit flush: it writes the checkpoint that
the next session's `borg-link-down.sh` will read.

### Hook Registration

**Not in `~/.claude/settings.json`.** Registration is owned by the borg-collective plugin, whose
`hooks/hooks.json` is generated into the distro by `scripts/build-plugin.sh` — there is no
`hooks/hooks.json` in this repo. Claude Code reads it when the plugin is installed
(`claude plugin install borg-collective@noah-local`).

`borg setup` plays two roles here, and only two:

1. It **copies** `hooks/*.sh` and `lib/*.sh` into `~/.claude/hooks/` and `~/.claude/lib/`, so the
   scripts exist on disk (and inside devcontainers, which bind-mount `~/.claude`).
2. It **unregisters** the literal-path `$HOME/.claude/hooks/...` entries that earlier versions of
   setup wrote into `settings.json`. Leaving them would double-fire every hook now that the plugin
   registers them. Permissions and every other `settings.json` key are preserved.

CoCo is the exception again: Cortex Code has no plugin system, so `borg setup` copies the hooks to
`~/.snowflake/cortex/hooks/` and *does* register them in `~/.snowflake/cortex/settings.json`.

The twelve hooks and their events are listed in the project `CLAUDE.md`; the authoritative wiring is
whatever `build-plugin.sh` emits.

`borg-plan-promote.sh` fires on `Edit`, `Write`, and `NotebookEdit` tool calls. It scans the
session JSONL for an `ExitPlanMode` tool call since the most recent real user message. If found,
and no `PROJECT_PLAN.md` already exists in the repo, it writes the plan to
`docs/plans/PROJECT_PLAN.md` (creating the directory if needed) and emits a one-line note to
stderr. Always exits 0 — it never blocks the edit. Project-mode only; orchestrator sessions are
excluded via `_borg_session_mode`.

---

## Skills Architecture

Skills use progressive disclosure:
- **Startup**: Claude reads descriptions (~100 tokens each). Low overhead.
- **Activation**: Full instructions load (~2,000-5,000 tokens). Rich context.

### Borg Skills Philosophy

**Claude does the thinking, developer validates.** Skills don't ask open-ended questions. They read
the codebase, form proposals, and present them for confirmation. This minimizes cognitive load.

| Skill | Trigger | Role |
|-------|---------|------|
| adhd-guardrails | Auto (always) | Prevent scope creep, suggest breaks, shame-free language |
| borg-plan | Manual | Propose + lock project objectives and acceptance criteria |
| borg-assimilate | Manual | Shipping checklist + Collective review + execution |
| borg-collective-review | Manual / invoked | Adversarial multi-persona review (The Collective) |
| borg-review | Manual | Mid-session diagnostic, loop detection, one recommendation |
| borg-link | Manual | Consolidated project intelligence (overview or per-project deep dive) |
| borg-link-up | Manual | Flush session state to `<project>/.borg/checkpoints/<ts>.md` |
| borg-recon | Manual | Synthesize `borg recon --json` output into a by-project, urgency-ranked briefing |
| borg-next / borg-resume / borg-switch / borg-verify | Manual | Skill-form CLI wrappers |
| break-glass | Manual | Explicit, logged override for a normally-blocked action |
| simplify / fable-reviewer / no-unnecessary-read-perms | Manual / auto | Code + permission hygiene guardrails |

The full, current roster (17 skills as of this writing) is always `ls skills/` — this table lists
role, not an exhaustive spec.

---

## Usage Guardian (default OFF)

A two-part safety net that prevents runaway agent fan-out from silently burning a usage window,
without ever hard-blocking work by default:

1. **`bin/borg-usage-watch`** — a launchd-scheduled poller (`launchd/com.stillpoint-labs.borg.usage-watch.plist`)
   that samples `claude -p "/usage"` on an interval and appends one JSONL row per poll to
   `~/.local/state/borg/usage-samples.jsonl` (schema: `ts`, `status` — `ok` / `idle` / `suspect` /
   `error` — plus `session_pct`, `week_pct`, `resets_at` when known). Silence in the samples file has
   exactly one meaning: the poller did not run.
2. **85% checkpoint sweep** — at 85% session usage, the poller nudges in-flight sessions toward
   writing a checkpoint (`/borg-link-up`) before the window resets, so work is resumable rather than
   lost mid-stream.
3. **`hooks/borg-dispatch-guard.sh`** — a `PreToolUse` hook that hard-vetoes *new* Agent/Workflow
   dispatch once session usage reaches `BORG_USAGE_HALT_PCT` (default **92%**). It does not touch
   already-running work — only new fan-out. Disable with `BORG_USAGE_HALT_ENABLED=0`.

**Default posture: OFF and fail-OPEN.** Neither the poller nor the guard is installed/enabled by
default; when enabled, any failure to read a usage sample (binary not found, parse failure, stale
data) fails open — it never blocks dispatch on its own error. This is opt-in cost protection, not a
default constraint.

---

## Recon Fan-Out

The recon fan-out is a source-agnostic sweep primitive that answers "what happened everywhere since
I last looked?" across every registered project.

**`recon` is not a human-facing verb.** It retired 2026-08-26 (AC1 of the one-front-door plan):
`borg link` folds the same fan-out into its own document, so a human never needs to run the sweep
directly. Running bare `borg recon` dies with a pointer at `borg link`. What survives is the
**machine surface** — `borg recon --json` (consumed by the `/borg-recon` skill and
`merge-tree/gather.py`) and `borg recon --adapters` — because the engine was never the thing AC1
asked to remove. The gate lives in `borg_core/recon/cli.py::main()`, guarding the `_run()` call on
`args.json_only or args.adapters` — the module that implements the command owns the invariant.
`borg.zsh`'s `recon)` arm is a pure pass-through, plus the two things `argparse` does not do
(the `--list` alias for `--adapters`, and dying on an unknown flag). `python3 -m borg_core.recon.cli`
with no flags is gated identically to `borg recon` bare. `core.render_digest` is unreachable through
either front door — no argv combination reaches `_run()` with `json_only=False, adapters=False` — but
it is not dead code: it is the engine's own digest capability, still exercised directly by
`test_run_digest_output` and the core suite. See
`docs/plans/assimilated/2026-08-26-recon-retirement-gate-altitude.md` for the measurements behind
the move.

- **Engine**: `borg_core/recon/{core,shell,cli}.py`. It resolves a `since` mark (explicit override >
  newest checkpoint mtime > last-run marker > 24h fallback), then fans out concurrently (bounded
  parallelism) over pluggable **adapters**. (`borg link`'s fold does NOT reuse that ladder — it cuts
  a fixed 90-day window so one ref cannot answer two ways in two scopes, and it never writes the
  last-run marker.)
- **Adapter contract**: any executable named `recon-adapter-<source>` found on
  `BORG_RECON_ADAPTER_PATH` registers a new source — no code change required. The config directory
  shadows the repo directory. This repo ships exactly one reference adapter,
  `lib/recon/adapters/recon-adapter-github` (via `gh`); Slack/Jira/Notion adapters are a separate,
  machine-specific injected layer, never hardcoded here.
- **Normalization**: every finding becomes an Item —
  `{project, source, ref, title, state, changed, owner, action_needed, urgency, one_line}` — merged
  by project across all adapters.
- **Contradiction reconciliation**: recon cross-checks each project's latest checkpoint against
  fresh source state and flags checkpoint-blocker-vs-resolved-source contradictions (e.g. a
  checkpoint says "blocked on review" but the PR merged since).
- **Output**: `borg recon --json` emits the reconciled document; `/borg-recon` synthesizes it into
  a by-project, most-urgent-first, ELI10 briefing plus Yours(human)-vs-Mine(agent) action lists and
  a bounded read-only kickoff batch.

---

## Agent Roster and Nanoprobe Delegation

The orchestrator session never edits project files directly — it briefs, spawns, monitors, and
synthesizes. Actual work is delegated to ephemeral subagents via the Agent tool, routed by model
tier per `agents/ROUTING.md`:

| Agent | Model | Role |
|-------|-------|------|
| borg-grunt | Haiku | Fully-specified mechanical execution: apply an edit, run tests, rote refactor |
| borg-scout | Haiku | Read-only locate/search — never writes |
| borg-nanoprobe | Sonnet | Single discrete task requiring judgment — implement, fix, refactor |
| borg-researcher | Sonnet | From-zero web research on one track, structured findings |
| borg-reviewer | Sonnet (high effort) | Blind adversarial review, arrives cold with no author context |

Nanoprobes (and any subagent doing multi-file work) manage their own git worktrees rather than
relying on harness-level isolation: `git -C <repo_path> worktree add
/Users/noah/.local/state/borg/worktrees/<repo>/<slug> -b <branch>`. All edits and commits happen
inside that worktree; on completion the subagent removes it. `borg reap-worktrees`
(`launchd/com.stillpoint-labs.borg.reap.plist`, hourly) is the safety net that auto-cleans any borg
worktree whose branch has merged or that has gone stale (`BORG_REAP_STALE_HOURS`, default 12h).
Nanoprobe lifecycle is logged by `hooks/borg-nanoprobe-log.sh` (`SubagentStop`) to
`~/.config/borg/agents.jsonl`; inspect with `borg nanoprobes` (alias `np`) and pull transcripts with
`borg nanoprobe-log <id-prefix>`.

---

## Cairn Integration (Decommissioned)

Borg previously integrated with cairn, a separate PostgreSQL+pgvector knowledge graph service, for
cross-project search, briefing enrichment, and cross-session presence tracking. Cairn was
decommissioned 2026-08-08 (its differentiating cross-project recall measured indistinguishable from
a null baseline), and every integration point — `borg search`, cairn-enriched briefings, and
presence publish/close — was removed along with it. The corpus was exported to per-project
`.borg/knowledge/*.md` markdown, which is grep-reachable directly and requires no service.
Knowledge persistence today is purely file-based: checkpoints in `<project>/.borg/checkpoints/`,
loaded on session start.

---

## Devcontainer Integration

Claude Code runs inside Docker Compose containers with `~/.claude/` bind-mounted from the host.
This propagates hooks, skills, and settings automatically.

Borg requires one additional mount for registry access:

```yaml
volumes:
  - ~/.claude:/home/vscode/.claude:cached
  - ~/.config/borg:/home/vscode/.config/borg:cached
```

### Path Resolution

Inside containers, CWD is typically `/workspaces/<project>`, not the host path. Hooks use
`basename($CWD)` to identify the project, which works when docker-compose project names match
directory names.

---

## Dependencies

| Tool | Required | Purpose |
|------|----------|---------|
| jq | Yes | Registry JSON CRUD |
| fzf | Yes | Fuzzy picker for `borg switch` |
| tmux | Yes | Session multiplexing |
| claude | Optional | Orchestrator session, `borg link --brief` narrative over the link document |
| Docker | Optional | Devcontainer support |
