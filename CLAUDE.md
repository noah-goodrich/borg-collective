# The Borg Collective — Project Handoff

## What This Is

AI development orchestration framework. Two CLIs — `borg` (orchestration) and `drone` (project
lifecycle) — that coordinate parallel Claude Code sessions across projects and containers. Uses cairn
(PostgreSQL + pgvector knowledge graph) as an optional persistence layer for cross-session knowledge.

## Architecture

```
borg (orchestrator)     drone (project lifecycle)     cairn (knowledge, optional)
  - Morning briefing      - Container up/down           - Decisions + reasoning
  - Priority scoring      - tmux window management      - Patterns + gotchas
  - Work/life boundaries  - Claude session launching    - Session debriefs
  - Knowledge search      - 3-pane dev layout           - Vector search
```

Three independent tools that compose:
- **borg** — Session coordination, recommendations, boundaries. Runs on host.
- **drone** — Container lifecycle, tmux windows, pane layouts. Forked from dev.sh. Runs on host.
- **cairn** — Knowledge graph. Runs in a container with PostgreSQL. Optional.

## Current State (v2)

### Implemented
- Core borg CLI: init, claude, next, ls, switch, status, hail, search, scan, add, rm, help
- CoCo (Cortex Code CLI) integration: session discovery, `[X]` badge in `borg ls`, cairn records
- `drone` CLI: up, down, claude, sh, restart, fix, status
- Hooks: borg-link-down.sh (status=active + latest-checkpoint injection + cairn context + presence
  open/related), borg-link-up.sh (status=idle + uncommitted-changes tracking + no-checkpoint nudge +
  presence close), borg-notify.sh
- Skills: adhd-guardrails, borg-link-up, borg-plan, borg-review, borg-assimilate, borg-verify
- Work/life boundary checks on switch
- Capacity warnings
- tmux hotkey (Ctrl+Space >)
- Registry-based project tracking with atomic writes
- User-authored session checkpoints at <project>/.borg/checkpoints/<ts>.md (via /borg-link-up)
- Session context loaded at start from latest checkpoint + cairn (if available)
- `borg init` orchestrator: morning briefing from registry + checkpoints + cairn
- Cairn integration: optional knowledge-graph persistence; knowledge search via `borg search`

### Commands

```
borg init                Launch orchestrator: morning briefing + Claude session
borg / borg next         What needs attention? Switch to it.
borg claude              Launch/resume orchestrator Claude session
borg link [project]      Overview (no arg) or deep dive (with project)
                           --brief   LLM narrative briefing
                           --refresh Regenerate summaries
                           --all     Include archived projects
borg switch [query]      fzf picker → tmux window switch
borg search "query"      Search cairn knowledge graph
borg scan                Auto-discover from session history
borg add [path]          Register a project
borg rm <project>        Unregister
borg help                Full command reference

drone up [project]       Start container + tmux window
drone down [project]     Stop container + remove window
drone claude [project]   Launch Claude in project context
drone sh [project]       Shell into container
drone restart [project]  Restart container
drone link               Deep dive on current project (alias for borg link)
drone status             Show all drones
```

### Hotkey

`Ctrl+Space >` — jump to most pressing project (runs `borg next --switch`)

### Files

```
borg.zsh                    Main CLI (~770 lines)
drone.zsh                   Project lifecycle (forked from dev.sh + drone claude)
lib/
    registry.zsh            Registry CRUD for ~/.config/borg/registry.json
    tmux.zsh                tmux window listing + switching
    claude.zsh              Session discovery from ~/.claude/projects/
    coco.zsh                Session discovery from ~/.snowflake/cortex/projects/
    desktop.zsh             Claude Desktop session reader
hooks/
    borg-link-down.sh       SessionStart → status=active + latest-checkpoint injection
    borg-link-up.sh         Stop → status=idle + uncommitted warning + checkpoint nudge
    borg-notify.sh          Notification → status=waiting + waiting_reason
    borg-plan-promote.sh    PreToolUse (Edit/Write/NotebookEdit) → auto-promote ExitPlanMode plan
skills/
    adhd-guardrails/        Cognitive load guardrails (always active)
    borg-plan/              Project planning + Collective review
    borg-assimilate/        Shipping checklist + Collective review + execution
    borg-collective-review/ Adversarial multi-persona review (The Collective)
    borg-review/            Mid-session diagnostic + loop detection
    borg-link/              Consolidated project intelligence (overview + deep dive)
    borg-link-up/           Flush session state to <project>/.borg/checkpoints/<ts>.md
    borg-verify/            Independent pre-merge evaluator gate (spawn reviewer, PASS/FAIL verdict)
install.sh                  Installer: deps, symlinks, hooks, skills, launchd agents, tmux keybinding
launchd/
    com.stillpoint-labs.borg.notifyd.plist    LaunchAgent: borg-notifyd (fswatch daemon)
    com.stillpoint-labs.borg.cortex-wake.plist LaunchAgent: borg-cortex-watch (30s interval)
    com.stillpoint-labs.borg.reap.plist        LaunchAgent: borg reap-worktrees (hourly)
docs/
    boris-workflow.md       ELI5 guide to the workflow (start here)
    plans/assimilated/      Shipped plans for borg-collective itself (per-project convention)
    plans/directives/       Backlog for borg-collective itself; every project owns its own
    ...
```

## Key Patterns

- **Orchestrator-mode vs project-mode sessions**: every Claude Code / Cortex Code SessionStart,
  Stop, and Notification hook now classifies the session via `_borg_session_mode` (in
  `lib/borg-hooks.sh`). A session whose `$CWD` *exactly* equals `$BORG_ORCHESTRATOR_ROOT`
  (default `$HOME/dev`) is the **orchestrator** session — it renders a cross-project overview
  on start and writes **nothing** to `~/.config/borg/registry.json`. Every other CWD is a
  **project** session and uses the existing per-project flow (status flips, checkpoint
  injection, uncommitted-change tracking). Two-variable vocabulary: `BORG_ORCHESTRATOR_ROOT`
  is the workspace root; `BORG_ROOT` (exposed by `install.sh`) is the install path of the
  borg source tree.
- **CLI structure mirrors dev.sh**: `set -e`, case dispatch, colored output, `cmd_*` naming
- **Registry writes are atomic**: write to tmp file, `mv` to final path
- **Skills do the thinking**: Claude proposes, developer validates. Minimum cognitive load.
- **Debriefs replace summaries**: LLM analysis at session stop, not regex extraction
- **Boundaries are speed bumps**: one-keystroke confirmations, not hard blocks
- **Cairn is optional**: borg works without it (registry + file debriefs), cairn adds persistence
- **Cross-session presence (v0.8.4)**: SessionStart publishes a presence row to cairn
  (`/presence/open`) and queries related active rows (`/presence/related`). When another session in the
  same project is active, ONE distilled line is appended to `additionalContext` (format:
  `▸ N other active session(s) — closest: session <id8> editing <file> in <project>`). Stop closes the
  row (`/presence/close`). Strictly silent/no-op on every failure path (cairn down, 404, timeout).
  Requires cairn server migration 004 + `cairn presence` subcommand in dotfiles cairn client. v1
  limitations: heartbeat only at SessionStart (30-min TTL), touched_paths is a one-time snapshot,
  orchestrator-mode sessions do NOT publish presence.
- **Auto-plan promotion (`borg-plan-promote.sh`)**: a `PreToolUse` hook that fires on `Edit`,
  `Write`, and `NotebookEdit`. When Claude exits plan mode (`ExitPlanMode`) and the user
  proceeds to the first file edit, the hook scans the session JSONL for the most recent
  `ExitPlanMode` call since the current user turn, extracts the plan, and writes it to
  `<repo-root>/docs/plans/PROJECT_PLAN.md` — silently, without blocking. Gates: project-mode
  only, edit target inside repo, no existing `PROJECT_PLAN.md` at either canonical location,
  cwd is a git repo. Always exits 0 (never blocks on any failure). Idempotent: if
  `PROJECT_PLAN.md` already exists, the hook is a no-op.
- **borg-hooks (host-side lifecycle)**: projects can ship executable `.devcontainer/borg-hooks/pre-up.sh`
  and `.devcontainer/borg-hooks/post-down.sh` scripts. `pre-up.sh` runs on the host before
  `docker compose up -d` (strict: non-zero aborts `drone up`); `post-down.sh` runs after
  `docker compose down` in `drone down` only (lenient: non-zero warns, drone exits 0). Hooks
  run with `cwd=$project_dir` and `BORG_PROJECT_NAME` exported. Transient downs during
  `drone restart`/`rebuild` do NOT fire `post-down.sh` — external stacks (e.g. Supabase)
  must persist across cycles. New Supabase projects scaffold via `drone scaffold --supabase <dir>`.
- **`drone scaffold --supabase <dir>`**: generate a devcontainer joined to the external
  `supabase_network_<project>` network plus standard borg-hooks that call `supabase start`
  on up and `supabase stop` on down.
- **Nanoprobe orchestrator (drones vs nanoprobes)**: drones are persistent devcontainers (long-lived,
  one per project); nanoprobes are ephemeral Claude Code subagents (`agents/borg-nanoprobe.md`)
  spawned by the orchestrator via the Agent tool with `background: true` (no harness worktree
  isolation — `isolation: worktree` caused hard failures when the orchestrator CWD is not a git
  repo). **Nanoprobes manage their own git worktrees** when the orchestrator supplies a branch name:
  `git -C <repo_path> worktree add /Users/noah/.local/state/borg/worktrees/<repo>/<slug> -b <branch>`.
  All work and commits happen inside the worktree; on completion the nanoprobe removes it so the
  repo stays clean. `borg reap-worktrees` auto-cleans stale borg worktrees (merged branch or older
  than `BORG_REAP_STALE_HOURS`). Worktrees live under `~/.local/state/borg/worktrees/` (NOT inside
  `.borg/`, which is reserved for user checkpoints).
  The orchestrator session never edits project files — it briefs, spawns, monitors, and synthesizes.
  Lifecycle is logged by `hooks/borg-nanoprobe-log.sh` (a `SubagentStop` hook) which appends one
  JSONL line per completion to `~/.config/borg/agents.jsonl` (`id`, `agent_type`, `transcript_path`,
  `summary` from `last_assistant_message`, hard-coded `status: "completed"`, `finished_at`, `cwd`).
  Inspect runs with `borg nanoprobes` (alias `np`) and pull transcripts with
  `borg nanoprobe-log <id-prefix>`. The agent file installs to `~/.claude/agents/borg-nanoprobe.md`
  via `borg setup`, where both Claude Code and Cortex Code discover it.
- **Bounded termination (agent loops)**: when fanning out nanoprobes or running any retry/until
  loop, set an explicit ceiling (max spawns / max iterations) up front and stop when hit. Never
  rely on judgment to exit loops — explicit stopping conditions only (e.g., `MAX_RETRIES=3`
  declared before the loop; hard-stop with a failure summary when reached).
- **Skill extensions (v1, may evolve)**: `borg-plan` and `borg-assimilate` read markdown extension
  files at three load points — `01-context` (start), `02-output` (before artifact), `03-followup`
  (after artifact). At each point both paths are read in order:
    1. `~/.config/borg/extensions/skill-extensions/<skill>/<hook>.md` (per machine)
    2. `<project>/.borg/skill-extensions/<skill>/<hook>.md` (per project, layered after machine)
  Missing files are skipped silently. Markdown only — no executable scripts. One file per hook;
  if multiple integrations land on one machine, merge manually. Keep extension files terse — they
  load on every invocation. Example: drop a `01-context.md` for `borg-plan` on the work machine
  that says "Ask which JIRA ticket this work targets, then read it via `acli jira workitem view`
  and use its description as the plan source." On a personal machine, the file doesn't exist and
  `/borg-plan` behaves exactly as it always did.

## External Dependencies

| Tool | Command | Purpose |
|------|---------|---------|
| jq | `jq` | Registry JSON CRUD |
| fzf | `fzf` | Fuzzy picker for `borg switch` |
| claude | `claude` | LLM debriefs (Sonnet), orchestrator session |
| cortex | `cortex` | Cortex Code CLI (CoCo) — optional, detected at install |
| cairn | `cairn` | Knowledge persistence (optional) |

## Style Rules

- All markdown and text files must wrap at 120 characters. No line may exceed 120 chars.
- 4-space indentation (except YAML/Lua: 2-space)
- zsh functions over aliases for anything > 1 line
- No `$()` substitution in Bash tool calls
- No inline `#` comments in one-liner bash commands
- No temp scripts

## Learned

- **tmux zoom is a toggle**: `resize-pane -Z` toggles zoom on/off. If a helper zooms a pane and
  the caller also zooms it, the second call unzooms. Apply zoom in exactly one place — the final
  caller, not intermediate helpers.
- **Notifications must not steal focus**: macOS notifications should only activate the target app
  on click (`-activate`), never on fire. Unsolicited focus changes interrupt whatever the user is
  doing.
- **devcontainer postStartCommand vs postCreateCommand**: `drone` only runs `postStartCommand`.
  Symlinks and per-start setup (zshrc, CLAUDE.md, .claude.json) must live in `postStartCommand`.
  `postCreateCommand` is for one-time setup (pip install, chmod) and is never run by `drone`.
- **`claude plugin install` takes a marketplace name, not a file path**: the correct syntax is
  `claude plugin install <name>@<marketplace>`, not `claude plugin install <file>.plugin`. The
  local marketplace (`noah-local`) resolves from the plugins source directory, not `dist/`.
- **`borg.zsh` sources only `lib/*.zsh`, not `lib/*.sh`**: helpers intended for both the CLI and
  bash hook scripts must be defined in two places — `lib/borg-hooks.sh` (bash, sourced by hooks)
  and `lib/<name>.zsh` (zsh, picked up by the CLI glob). Check the source path before writing a
  shared helper.
- **Don't track copy success via mtime deltas**: if a helper function copies a file and you need
  to know whether it acted, return a status code or accept a callback — don't read before/after
  mtime from outside the helper. That's leaky and adds syscalls. Simplest: just log
  unconditionally or restructure so the caller does the condition check itself.
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
