# The Borg Collective — Project Handoff

## What This Is

AI development orchestration framework. Two CLIs — `borg` (orchestration) and `drone` (project
lifecycle) — that coordinate parallel Claude Code sessions across projects and containers.
Cross-session knowledge persists via user-authored checkpoints (`.borg/checkpoints/`) and Claude
Code's own project-memory system — see "Cairn decommission" under Learned for why a separate
knowledge-graph service was retired.

## Architecture

```
borg (orchestrator)     drone (project lifecycle)
  - Morning briefing      - Container up/down
  - Priority scoring      - tmux window management
  - Work/life boundaries  - Claude session launching
  - Checkpoint briefing   - 3-pane dev layout
```

Two independent tools that compose:
- **borg** — Session coordination, recommendations, boundaries. Runs on host.
- **drone** — Container lifecycle, tmux windows, pane layouts. Forked from dev.sh. Runs on host.

## Current State (v2, release v0.8.9)

### Implemented
- Core borg CLI: init, claude, next, link, switch, scan, add, rm, help, and the
  wider command surface below (recon, nanoprobes, spend, watch, doctor, sync, focus, pin/unpin,
  setup, store-secret, sever, tidy, reap-worktrees, and more — see `borg help`).
  **The `ls`/`status`/`hail`/`brief`/`briefing`/`refresh` aliases for `link` were removed
  2026-08-10** — six names for one command meant the docs, skills, and research all disagreed
  about what to call it. `borg link` is the only name.
- CoCo (Cortex Code CLI) integration: session discovery, `[X]` badge in `borg link`
- `drone` CLI: up, down, claude, sh, restart, rebuild, fix, status, feature, cortex, exec, toggle,
  scaffold
- Hooks (12): borg-link-down.sh (status=active + latest-checkpoint injection), borg-link-up.sh
  (status=idle + uncommitted-changes tracking + no-checkpoint nudge), borg-notify.sh, plus
  bash-guard, borg-dispatch-guard, borg-memory-read-log, borg-plan-promote, borg-supabase-guard,
  notify, pre-commit-remind, tool-count-nudge (full list under Files below)
- Skills (16): adhd-guardrails, borg-link-up, borg-plan, borg-review, borg-assimilate, borg-verify,
  and 10 more (full list under Files below)
- Agents (6, ephemeral nanoprobe roster): borg-grunt, borg-nanoprobe, borg-researcher,
  borg-reviewer, borg-scout, ROUTING
- Usage guardian: 85% checkpoint sweep (bin/borg-usage-watch) + `borg-dispatch-guard.sh`
  >=92% hard-stop veto on new Agent/Workflow dispatch — both fail-open, dispatch-guard is
  default-OFF (`BORG_USAGE_HALT_ENABLED=1` to arm)
- Recon fan-out: `borg recon --json` / `/borg-recon` — pluggable source adapters, since-mark
  resolution, checkpoint-vs-source contradiction detection. **`recon` retired as a human verb
  2026-08-26** (bare `borg recon` dies pointing at `borg link`); the engine and its two machine
  flags (`--json`, `--adapters`) survive
- `borg-sync` (lib/borg-sync.zsh): mtime-based file sync helpers shared by the CLI and hooks
- Auto-memory read instrumentation: `borg-memory-read-log.sh` (PostToolUse/Read) logs every read
  of a Claude Code project-memory file to `$BORG_DIR/memory-hits.log`; `bin/memory-hits-report`
  computes reads/session against a pre-registered null (see cairn's decommission research)
- Work/life boundary checks on switch
- Capacity warnings
- tmux hotkey (Ctrl+Space >)
- Registry-based project tracking with atomic writes
- User-authored session checkpoints at <project>/.borg/checkpoints/<ts>.md (via /borg-link-up)
- Session context loaded at start from the latest checkpoint
- `borg init` orchestrator: morning briefing from registry + checkpoints

### Commands

```
borg init                Launch orchestrator: morning briefing + Claude session
borg / borg next         What needs attention? Switch to it.
borg claude              Launch/resume orchestrator Claude session
borg link [project]      ONE document, seven sections, always the same spine (AC2)
                           Scope widens or narrows it; it is never a different page
                             — except `--brief`, the one invocation that prints prose
                           --brief   Same document, same sweep, PROSE not the seven
                                     sections (AC1). Falls back to the real page.
                           --refresh Regenerate summaries
                           --all     Include archived projects
                           --local   Opt down from the network sweep (hot loops only)
                           --json / --porcelain  the two machine surfaces
                           --deep    Parsed and IGNORED since AC2; kept for borg.zsh:3111
borg switch [query]      fzf picker → tmux window switch
borg scan                Auto-discover from session history
borg add [path]          Register a project
borg rm <project>        Unregister
borg focus               Zoom current pane / project window
borg pin / unpin         Pin (or unpin) a project to the top of borg link
borg reap / reap-worktrees  Reap stale active/waiting statuses; clean stale nanoprobe worktrees
borg recon --json        Machine surface only: reconciled sweep JSON (bare `recon` retired; use link)
borg recon --adapters    List the source adapters discovered on this machine
borg nanoprobes (np)     List recent ephemeral subagent runs
borg nanoprobe-log <id>  Fetch the transcript/summary for a nanoprobe run
borg spend               Summarize accurate token spend from ~/.claude/token-spend.jsonl
borg doctor              Environment/dependency health check
borg setup               Install/refresh hooks, skills, agents, tmux keybinding
                           NOT launchd — plists are installed by install.sh only, which calls
                           `borg setup` at the end. A new launchd job needs an install.sh run.
borg store-secret        Patch a project's secrets.zsh with a new keychain export
borg sever               Retire/archive a directive or project without deleting it
borg tidy                Housekeeping pass over registry/checkpoints
borg color / image       Cosmetic project registry fields (tmux color, session image)
borg version             Print BORG_VERSION
borg help                Full command reference

drone up [project]       Start container + tmux window
drone down [project]     Stop container + remove window
drone claude [project]   Launch Claude in project context
drone cortex [project]   Launch Cortex Code (CoCo) in project context
drone sh [project]       Shell into container
drone exec [project] -- <cmd>  Run a command inside the devcontainer (never on host)
drone restart [project]  Restart container
drone rebuild [project]  Rebuild + restart container
drone fix [project]      Repair a broken container/window state
drone feature <project> <branch>  Create a git worktree on <branch> + open its dev window/container
drone toggle [project]   Toggle the optional 3rd side pane (2 ↔ 3 panes)
drone pane <direction>   Split the active pane top|bottom|left|right (devcontainer-aware)
drone scaffold --supabase|--supabase-shared <dir>  Generate a devcontainer + borg-hooks for Supabase
drone link               Deep dive on current project (alias for borg link)
```

### Hotkey

`Ctrl+Space >` — jump to most pressing project (runs `borg next --switch`)

### Files

```
borg.zsh                    Main CLI (case dispatch over cmd_* functions)
drone.zsh                   Project lifecycle (forked from dev.sh + drone claude)
lib/
    registry.zsh            Registry CRUD for ~/.config/borg/registry.json
    tmux.zsh                tmux window listing + switching
    claude.zsh              Session discovery from ~/.claude/projects/
    coco.zsh                Session discovery from ~/.snowflake/cortex/projects/
    desktop.zsh             Claude Desktop session reader
    colors.zsh              tmux window color helpers (registry → hash fallback)
    secrets.zsh             `borg store-secret` idempotent secrets.zsh patcher
    drone-hooks.zsh         Host-side pre-up/post-down borg-hooks runner for drone
    reaper.sh               Shared staleness predicate (portable sh, hooks + zsh CLI)
    recon/adapters/         Recon adapter scripts (e.g. recon-adapter-github)
    borg-hooks.sh           Shared bash helpers for hook scripts (sync, session-mode classifier)
    borg-sync.zsh           mtime-based file sync helpers for the zsh CLI (mirrors borg-hooks.sh)
borg_core/                  Python core the CLI dispatches into (see Architecture Rules)
    paths.py                Config-path resolution + defaults (the CLI's `_borg_py` mirror)
    registry/               Registry read/write core, shell adapter, CLI entry
    recon/                  Recon fan-out engine: since-mark, adapters, merge (was lib/recon.sh)
    manifest/               Reader for <project>/.borg/programs/*.json program manifests
    link/                   `borg link` document build + renderer
        core.py             Registry/plan/checkpoint reads, scope resolution, relative time
        grid.py             Manifests → the topology wire: levels, nodes, parents/children/seq
        shell.py            The impure rungs: adapter sweep, targeted `gh` fetch, manifest load
        picture.py          PURE topological picture — refs+edges in, ANSI rows out. No I/O.
        render.py           `document()` + the seven-section SECTIONS spine; calls picture.py
        cli.py              argparse, `_mode` (json|porcelain|human), BrokenPipeError, dispatch
hooks/
    borg-link-down.sh       SessionStart → status=active + latest-checkpoint injection
    borg-link-up.sh         Stop → status=idle + uncommitted warning + checkpoint nudge
    borg-notify.sh          Notification → status=waiting + waiting_reason
    borg-plan-promote.sh    PreToolUse (Edit/Write/NotebookEdit) → auto-promote ExitPlanMode plan
    bash-guard.sh           PreToolUse (Bash) → destructive-pattern hard-block + RO pre-approval
    borg-memory-read-log.sh PostToolUse (Read) → logs project-memory reads to memory-hits.log
    borg-dispatch-guard.sh  PreToolUse (Agent/Workflow) → >=92% usage hard-stop veto (default-OFF)
    borg-supabase-guard.sh  PreToolUse (Bash) → blocks non-stillpoint supabase start/stop/db reset
    notify.sh               Host-side macOS notification on turn completion (skipped in-container)
    pre-commit-remind.sh    PreToolUse (Bash) → nudge to run /simplify + /borg-assimilate on commit
    tool-count-nudge.sh     PostToolUse → review reminder every 75 tool calls
skills/ (16)
    adhd-guardrails/        Cognitive load guardrails (always active)
    borg-plan/              Project planning + Collective review
    borg-assimilate/        Shipping checklist + Collective review + execution
    borg-collective-review/ Adversarial multi-persona review (The Collective)
    borg-review/            Mid-session diagnostic + loop detection
    borg-link/              Consolidated project intelligence (overview + deep dive)
    borg-link-up/           Flush session state to <project>/.borg/checkpoints/<ts>.md
    borg-verify/            Independent pre-merge evaluator gate (spawn reviewer, PASS/FAIL verdict)
    borg-next/              "What should I work on?" priority answer
    borg-recon/             Morning link-up: fan out adapters, reconcile against checkpoints
    borg-resume/            Auto-resume a workflow paused/killed by a session or usage limit
    borg-switch/            Switch to a project's tmux window by name
    break-glass/            Add a local permission exception to a project's settings.local.json
    fable-reviewer/         Fable's 5-gate discipline distilled into a skill (scope, evidence, review)
    no-unnecessary-read-perms/  Suppress redundant read-permission prompts (always active)
    simplify/               Review session-touched code for reuse/quality/efficiency, then fix
agents/ (6, ephemeral nanoprobe roster)
    borg-nanoprobe.md       Default worker: one discrete unit of work, manages its own worktree
    borg-grunt.md           Narrow mechanical task executor
    borg-researcher.md      Read-heavy investigation/research subagent
    borg-reviewer.md        Independent review/verdict subagent
    borg-scout.md           Lightweight recon/discovery subagent
    ROUTING.md              Guidance for which agent to spawn for a given task shape
install.sh                  Installer: deps, symlinks, hooks, skills, launchd agents, tmux keybinding
launchd/
    com.stillpoint-labs.borg.notifyd.plist       LaunchAgent: borg-notifyd (fswatch daemon)
    com.stillpoint-labs.borg.cortex-wake.plist   LaunchAgent: borg-cortex-watch (30s interval)
    com.stillpoint-labs.borg.reap.plist          LaunchAgent: borg reap-worktrees (hourly)
    com.stillpoint-labs.borg.usage-watch.plist   LaunchAgent: borg-usage-watch (usage guardian sweep)
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
- **`drone scaffold --supabase-shared <dir>` (opt-in, INERT until cutover)**: a second,
  separate scaffold path for the shared-local-Supabase consolidation. Instead of a
  per-project Supabase instance, the generated devcontainer joins the fixed, always-on
  `supabase_network_stillpoint` Docker network (containers `supabase_*_stillpoint`, ports
  API 54321 / DB 54322 / Analytics 54327). Shared config lives in the `stillpoint` repo
  (`~/dev/stillpoint/supabase`, overridable via `BORG_STILLPOINT_SUPABASE_DIR`). Templates
  at `templates/supabase-shared/`. The shared stack is **ALWAYS-ON** — started once, never
  per-drone: `borg-hooks/pre-up.sh` checks `docker inspect -f '{{.State.Running}}'
  supabase_db_stillpoint` and only runs `supabase start` (from the stillpoint repo) if it
  isn't already running; it never runs a per-project `supabase init`/`start`.
  `borg-hooks/post-down.sh` is a hard no-op — an individual `drone down` must never stop
  infra shared by other projects. Stop the shared stack explicitly and deliberately from
  the stillpoint repo (`supabase stop`), never via a drone's lifecycle. Does not alter
  `--supabase` semantics; the two scaffold paths are independent. This mechanism is scaffolded
  but not yet wired into any project — no per-project cutover has happened.
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
- **`borg link` is ONE renderer, not three (AC2)**: there is a single human renderer,
  `render.document()`, which iterates a module-level `SECTIONS` tuple — header, `▸ IN FOCUS`,
  `▸ REPOSITORIES`, `▸ CHAINS`, `▸ QUEUED`, `▸ SHIPPED`, `▸ NEXT`, `▸ SIGNALS` — with **no branch on
  scope, mode or emptiness**. (`▸ NEXT` is AC4's, inserted between SHIPPED and SIGNALS so the page
  reads history-then-future; adding it turned the spine test red on purpose, which AC2's directive
  chose over reserving an always-empty slot in advance.) `render.overview` and `render.deep` are
  deleted, and `--deep` is parsed and ignored (kept in the parser because `borg.zsh:3111`'s positional
  arm — every `borg link <project>`, the fzf preview included — still passes it, and argparse exiting
  2 there is a blank pane with nothing on stderr). **Scope changes which ROWS
  a section prints, never which sections exist** — the contexts differ in breadth only, so a reader
  who learns the page once has learned every invocation of it. Section headers are byte-identical
  in both contexts; `focus` now follows scope, so a bare `borg link` inside a repository renders
  `▸ IN FOCUS` for it. `DOCUMENT_VERSION` stays 2: breadth is applied in the renderer, so no
  pre-existing JSON key narrowed and `skills/borg-link/SKILL.md`'s version gate is untouched.
- **`picture.py` is pure; `render.py` is the page**: the topological picture (columns, connectors,
  crossings, glyph seam, OSC-8 links, the `PICTURE_BUDGET` width) lives in `borg_core/link/picture.py`
  and does **no I/O of any kind** — it imports only `re`, `link.grid` and `manifest.core`, takes refs
  plus edges, and returns ANSI rows. `render.py` composes those rows into sections. The split is what
  lets the picture be pinned against `picture-{fork,crossing}.expected`, two HAND-AUTHORED fixtures
  that are never regenerated — an oracle that does not come from the implementation it checks. Keep
  it that way: a subprocess or a file read in `picture.py` destroys that property.
- **`--brief` is a presentation mode of the document, not a second path (AC1, 2026-08-27)**:
  `_borg_print_briefing` (borg.zsh) builds the `borg link` document ONCE — the same
  `_borg_py borg_core.link.cli --json` call every other dispatch arm makes, with `--all`/`--local`
  forwarded identically — projects that JSON into the narrative prompt with one `jq`, and when the
  narrative fails pipes **those same bytes** back through `borg_core.link.cli --render-document`,
  a non-mode seam gated in `main()` above `_mode`. One sweep, one `generated_at`, two consumers. It
  used to be 177 lines of a second registry walk that never reached Python at all, which is why AC1
  stayed unticked with both verify clauses passing.
  **It IS still a different page, and the AC2 line above is qualified rather than rescued.** The
  narrative path prints prose: no cube, none of the seven `▸` sections. What the fold bought is that
  the prose is now a *rendering of the same document* rather than of a second board, and that the
  FALLBACK is the real page byte for byte. "Never a different page" holds for every invocation of
  `borg link` except `--brief`'s success path; do not read the AC2 line as covering it.
  Four rules follow. (1) **Never re-derive here.**
  A `borg_registry_with_state` call inside that function undoes the fold. (2) **Never rebuild for the
  fallback.** A second `--json` call would re-read the clock and re-sweep, so the page could disagree
  with the prompt it fell back from — two truth levels inside one invocation. (3) **The `claude -p`
  call stays in zsh.** `borg_core/proc.py` DEVNULLs stderr and returns `None` (not rc 124) on
  timeout, so moving it silently deletes the reason line's captured stderr and the timeout branch,
  both of which `tests/briefing.bats` pins. (4) **Every scope-dependent list on the wire goes through
  the projection's `$breadth` binding**, which transcribes `render._scoped_rows`: `--json` always
  carries the registry-WIDE `directives`/`assimilated` (`cli.py`'s `need_aggregate`), and the human
  page narrows them to `focus` in repository scope — so a projection reading the top level
  unconditionally puts a different QUEUED count in the prompt than on the page it falls back to.
  That shipped once, measured at 141 aggregate directives against 0 focused, and is pinned by
  `tests/briefing.bats`'s "in repository scope the prompt's QUEUED/SHIPPED match the page's".
  Sweep parity is asserted by **subprocess count** in
  `tests/link_sweep.bats`, never by reading the arm.
- **The `borg link` parity harness's `render` leg was retired 2026-08-27 (AC2/S4)**:
  `bin/link-parity-harness render` byte-compared the current tree against the last zsh renderer at
  `ad99612`. After AC2 that oracle renders a *different document*, so the comparison is
  unreproducible by construction and would print the redesign back as one intended diff. `render`
  survives as a recognized argparse token that exits 2 with the reason and points at the goldens
  that replaced it — same "the artifact that implements the command owns the invariant" altitude as
  the `borg recon` gate below. The `primitives` leg is untouched and still live: its shell originals
  exist verbatim in the file, so it remains a real differential.
- **Recon fan-out (`borg recon --json` + `/borg-recon`)**: source-agnostic sweep primitive.
  **Retired as a human verb 2026-08-26** — `borg link` folds the same fan-out into its own document,
  so bare `borg recon` (and any invocation without `--json`/`--adapters`) dies with a pointer at
  `borg link`. The gate lives in `borg_core/recon/cli.py::main()`, guarding the `_run()` call on
  `args.json_only or args.adapters` — the artifact that implements the command owns the invariant,
  not its zsh caller. `borg.zsh`'s `recon)` arm is a pure pass-through plus the two things argparse
  doesn't do (`--list` alias, unknown-flag `die`). See
  `docs/plans/assimilated/2026-08-26-recon-retirement-gate-altitude.md` for why it moved there.
  The engine (`borg_core/recon/{core,shell,cli}.py`) resolves a `since` mark (explicit >
  newest checkpoint mtime > last-run marker > 24h), fans out concurrently+bounded over pluggable
  **adapters**, normalizes every finding to an Item
  `{project,source,ref,title,state,changed,owner,action_needed,urgency,one_line}`,
  merges by project, and detects checkpoint-blocker-vs-resolved-source contradictions. An adapter is
  ANY executable named `recon-adapter-<source>` on `BORG_RECON_ADAPTER_PATH` (config dir shadows the
  repo dir) — dropping a file registers a source, no code change. Sources are NEVER hardcoded: Ontra
  adapters (Slack/Jira/Notion) are a separate machine-injected layer; this repo ships ONE reference
  adapter (`lib/recon/adapters/recon-adapter-github`, via `gh`). `borg recon --json` emits the
  reconciled doc the `/borg-recon` skill synthesizes into a by-project, most-urgent-first, ELI10
  briefing + Yours(human)-vs-Mine(agent) action lists + a bounded read-only kickoff batch. zsh gotchas
  baked in: never a `path` loop var (tied to `$PATH`); quoted `find`, not bare globs (zsh NOMATCH is
  fatal); jq `//` treats `false` as empty (use `if has("ok")`, not `.ok // true`).

## External Dependencies

| Tool | Command | Purpose |
|------|---------|---------|
| jq | `jq` | Registry JSON CRUD |
| fzf | `fzf` | Fuzzy picker for `borg switch` |
| claude | `claude` | LLM debriefs (Sonnet), orchestrator session |
| cortex | `cortex` | Cortex Code CLI (CoCo) — optional, detected at install |

## Architecture Rules

- Logic goes in a testable core. Shell is a wrapper. New modules ship with tests in the same commit.
- Prior decisions live in `.borg/checkpoints/`, `.borg/knowledge/`, and `docs/plans/assimilated/` —
  grep them before assuming something is undocumented.

## Style Rules

- All markdown and text files must wrap at 120 characters. No line may exceed 120 chars.
- 4-space indentation (except YAML/Lua: 2-space)
- zsh functions over aliases for anything > 1 line
- No `$()` substitution in Bash tool calls
- No inline `#` comments in one-liner bash commands
- No temp scripts

## Learned

- **Cairn decommission (2026-08)**: cairn (a Postgres+pgvector knowledge-graph service) was retired
  after a research pass found its sole differentiating claim — cross-project semantic recall —
  measured at 0.4% restatement, indistinguishable from a null baseline; same-project restatement
  (17%) was real but already served by checkpoints. See `~/dev/cairn/docs/research/README.md` for
  the full evidence base and `docs/plans/directives/2026-08-08-cairn-decommission-and-unconditional-block.md`
  for the teardown. The transferable lesson: build capture that derives from an artifact the agent
  already produces (checkpoint mining worked); never build capture that asks the agent to
  volunteer (four shipped, tested, exposed voluntary-write surfaces produced one real row in five
  months). `borg-memory-read-log.sh` now instruments the replacement (Claude Code project memory)
  so the same blind spot can't recur unnoticed.
- **tmux zoom is a toggle**: `resize-pane -Z` toggles zoom on/off. If a helper zooms a pane and
  the caller also zooms it, the second call unzooms. Apply zoom in exactly one place — the final
  caller, not intermediate helpers.
- **Notifications must not steal focus**: macOS notifications should only activate the target app
  on click (`-activate`), never on fire. Unsolicited focus changes interrupt whatever the user is
  doing.
- **devcontainer postStartCommand vs postCreateCommand**: `drone` runs BOTH. `run_post_create_command`
  executes `postCreateCommand` ONCE — sentinel-guarded by `/tmp/.drone-created`, so one-time deps
  (pip/npm install, chmod) run on first create and are skipped thereafter. `run_post_start_command`
  executes `postStartCommand` on EVERY start (per-start symlinks: zshrc, .p10k, workspace symlink).
  So per-start setup belongs in `postStartCommand`; one-time dependency install belongs in
  `postCreateCommand`. (Earlier docs said drone never ran `postCreateCommand` — that is now stale;
  it is invoked from the `drone up`/start paths in `drone.zsh`.)
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
- **A shell variable is not an environment variable — the zsh→Python boundary loses every config var**:
  `borg.zsh` assigns its whole config surface without `export` (`BORG_DIR` :24, `BORG_MAX_ACTIVE`/
  `BORG_CORTEX_WAKES` :43-48, `BORG_REGISTRY` in `lib/registry.zsh:15`, `BORG_TMUX_SESSION` in
  `lib/tmux.zsh:5`, `BORG_REAP_STALE_HOURS` in `lib/reaper.sh:11`). An in-process zsh function sees all of
  them; a `python3 -m borg_core...` child sees none. This shipped: `borg recon` read `BORG_REGISTRY` from the
  environment with no fallback and died with `no registry at ` on **every** real invocation except
  `--adapters`, which returns before the check — the command was non-functional from the migration until
  2026-08-13. Two rules follow. (1) Route every Python dispatch through `_borg_py` (defined just above the
  `case` block in `borg.zsh`) so the child gets the config surface, with defaults applied *in the wrapper* —
  an exported-empty `BORG_REAP_STALE_HOURS` makes `int("")` raise, so an unset var must arrive as its default
  or not at all. (2) The Python side still resolves its own defaults (`borg_core/paths.py`), because a module
  invoked directly has no wrapper. **Why no test caught it**: every test reaching the Python core puts
  `BORG_REGISTRY` in the environment *itself* — `tests/test_helper/setup.bash` exports it, the pytest suites
  monkeypatch it — so the inheritance path was the one line no test ever executed. Same shape as the
  usage-watch and memory-gate blind spots below: **when a test supplies the value the production path is
  supposed to derive, it proves nothing about production.**
- **Hooks recompute their own config paths — test isolation must override `XDG_CONFIG_HOME` too**:
  `borg-link-down.sh` derives `BORG_DIR` from `${XDG_CONFIG_HOME:-$HOME/.config}/borg`, ignoring any
  exported `BORG_DIR`. A bats suite that overrides only `HOME` leaks the host/runner
  `XDG_CONFIG_HOME` into the hook and points it outside the sandbox. Override both (or unset
  `XDG_CONFIG_HOME`) in hook-integration test setup.
- **A redirected `HOME` also silently deletes the test sandbox's git identity, and macOS won't tell
  you**: `setup_temp_dirs()` in `tests/test_helper/setup.bash` redirects `HOME`, which means
  `~/.gitconfig` is gone by construction for every bats case — but `recon_adapter_github.bats`'s
  "a linked worktree is swept" case needs `git commit` to work (a worktree needs a commit to point
  at). This passed on macOS for weeks because git auto-derives an identity from getpwuid plus a
  resolvable hostname and commits anyway with a warning (author lands as
  `Noah <noah@MacBook-Pro-4.local>`); measured in a Linux container the hostname has no domain and
  git refuses outright (`fatal: unable to auto-detect email address`, rc=128) — and CI's ubuntu lane
  runs exactly this suite. Fix: export `GIT_AUTHOR_NAME`/`_EMAIL`, `GIT_COMMITTER_NAME`/`_EMAIL`,
  and `GIT_CONFIG_NOSYSTEM=1` in `setup_temp_dirs()` — env vars, not a written `.gitconfig`, because
  the harness redirects both `HOME` and `XDG_CONFIG_HOME` and a file means picking the right one and
  staying right as either changes; env vars beat every config layer with no path resolution. Same
  family as the `XDG_CONFIG_HOME` leak above and "a shell variable is not an environment variable"
  below it in this list: the sandbox is incomplete in a way the dev machine silently papers over,
  which is exactly why it was invisible where it was being tested.
- **A test's PREMISE can depend on the dev platform, not just its environment — and the macOS lane
  structurally cannot catch it**: four failures, one class, all found together on one PR. (1) pytest
  (unlike bats) never redirects `HOME`, so two `borg_core/manifest/test_shell.py` tests that shell to
  `git commit` passed on Noah's machine (global `~/.gitconfig` supplies an identity) and died with
  rc=128 on a bare GitHub runner (no identity at all) — fixed with an autouse `borg_core/conftest.py`
  fixture exporting the same `GIT_AUTHOR_*`/`GIT_COMMITTER_*`/`GIT_CONFIG_NOSYSTEM=1` values the bats
  harness uses, so the two suites can't drift. (2) `test_proc.py` built a "binary output" fixture with
  `printf 'ok-\xff-end'` inside a `#!/bin/sh` script — hex `\xNN` is a bash-ism; macOS `/bin/sh` is
  bash-in-sh-mode and understands it, Linux `/bin/sh` is dash and does not, so the "invalid UTF-8"
  test was asserting on a string that was never binary. Fixed with the POSIX octal form `\377`, which
  both shells agree on — verified in `debian:stable-slim`. (3) A bats test hid `gh` for a "gh not
  installed" test case via `PATH="/usr/bin:/bin"`, which assumes `gh` lives outside those directories
  — true on macOS (Homebrew → `/opt/homebrew/bin`), false on `ubuntu-latest`, which preinstalls `gh` at
  `/usr/bin/gh`. Fixed by deriving an ALLOWLIST bin dir from the adapter's own source (only the
  binaries it actually calls, symlinked in) instead of guessing which directories a binary isn't in —
  and that allowlist has to include `bash` itself, since the adapter's `#!/usr/bin/env bash` shebang
  makes `env` search the very PATH under test to find the interpreter. In all three cases the
  `contract-macos` lane is structurally incapable of catching the bug, because it is the one platform
  where the false premise holds — it is not a weaker check, it is checking a different fact. The
  transferable rule: when a test fixture depends on a shell built-in's behavior, a system path's
  contents, or an ambient identity, verify the ASSUMPTION on the CI platform, not just the assertion
  on your own machine — reproduce it in a container matching the runner (including the binary you're
  trying to hide) before trusting a green run.
