# File map

Reference moved verbatim from the top-level CLAUDE.md.

### Files

```
borg.zsh                    Main CLI (case dispatch over cmd_* functions)
drone.zsh                   Repository lifecycle (forked from dev.sh + drone claude)
lib/
    registry.zsh            Registry CRUD for ~/.config/borg/registry.json
    tmux.zsh                tmux window listing + switching
    claude.zsh              Session discovery from ~/.claude/projects/
    coco.zsh                Session discovery from ~/.snowflake/cortex/conversations/ (one JSON per session with its working directory, plus a history file)
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
    extensions/             Local-extension resolution: layer precedence, prefer-tool, liveness
    manifest/               Reader for <repository>/.stacks/ manifests, one root
    link/                   `borg link` document build + renderer
        core.py             Registry/plan/checkpoint reads, scope resolution, relative time
        grid.py             Manifests → the topology wire: levels, nodes, parents/children/seq
        shell.py            The impure rungs: adapter sweep, targeted `gh` fetch, manifest load
        picture.py          PURE topological picture — refs+edges in, ANSI rows out. No I/O.
        render.py           `document()` + the seven-section SECTIONS spine; calls picture.py
        cli.py              argparse, `_mode` (json|porcelain|human), BrokenPipeError, dispatch
hooks/
    borg-link-down.sh       SessionStart → status=active + latest-checkpoint injection
    borg-arrival-brief.sh   SessionStart (startup|resume) → the arrival brief as a systemMessage
    borg-link-up.sh         Stop → status=idle + uncommitted warning + checkpoint nudge
    borg-notify.sh          permission/elicitation Notification → status=waiting + waiting_reason
    borg-plan-promote.sh    PreToolUse (Edit/Write/NotebookEdit) → auto-promote ExitPlanMode plan
                            Cortex: PostToolUse ExitPlanMode → plan from tool_input.plan (+ team plan file)
    borg-cortex-plan.sh     Cortex only: PostToolUse EnterPlanMode inject, PreToolUse ExitPlanMode gate
    bash-guard.sh           PreToolUse (Bash) → destructive-pattern hard-block + RO pre-approval
    borg-memory-read-log.sh PostToolUse (Read) → logs project-memory reads to memory-hits.log
    borg-dispatch-guard.sh  PreToolUse (Agent/Workflow) → >=92% usage hard-stop veto (default-OFF)
    borg-agent-model-guard.sh     PreToolUse (Agent|Task) → deny-by-default subagent_type allowlist + sonnet/haiku, low-high caps
                                  Cortex: full model ids; its Snowflake agents need a pin
    borg-workflow-model-guard.sh  PreToolUse (Workflow) → every agent() must pass the same allowlist/caps (fail-closed)
    borg-prefer-tool-log.sh PostToolUse (Bash) → logs bypasses of a live prefer-tool preference
    borg-supabase-guard.sh  PreToolUse (Bash) → blocks non-stillpoint supabase start/stop/db reset
    borg-verifier-guard.sh  PreToolUse (Bash) → verifier: git/gh reads
    borg-nanoprobe-guard.sh PreToolUse (Skill/Write/Edit/Bash) → nanoprobe: skill grant + no borg/extensions access
    borg-resume-hook.sh     Events → borg-resume ledger (append-only)
    notify.sh               Host-side macOS notification on turn completion (skipped in-container)
    pre-commit-remind.sh    PreToolUse (Bash) → nudge to run /simplify + /borg-assimilate on commit
    tool-count-nudge.sh     PostToolUse → review reminder every 75 tool calls
skills/ (16)
    adhd-guardrails/        Cognitive load guardrails (always active)
    borg-plan/              Project planning + Collective review
    borg-assimilate/        Shipping checklist + Collective review + execution
    borg-collective-review/ Adversarial multi-persona review (The Collective)
    borg-review/            Mid-session diagnostic + loop detection
    borg-link/              The front door: Queen overview, or this directory's page
    borg-link-up/           Flush session state to <repository>/.borg/checkpoints/<ts>.md
    borg-verify/            Independent pre-merge evaluator gate (spawn reviewer, PASS/FAIL verdict)
    borg-next/              "What should I work on?" priority answer
    borg-recon/             Morning link-up: fan out adapters, reconcile against checkpoints
    borg-resume/            Auto-resume a workflow paused/killed by a session or usage limit
    borg-switch/            Switch to a repository's tmux window by name
    break-glass/            Add a local permission exception to a repository's settings.local.json
    fable-reviewer/         Fable's 5-gate discipline distilled into a skill (scope, evidence, review)
    no-unnecessary-read-perms/  Suppress redundant read-permission prompts (always active)
    pane/                   Split the current tmux pane in a given direction
agents/ (6, ephemeral nanoprobe roster; routing guide is docs/agent-routing.md)
    borg-nanoprobe.md       Default worker: one discrete unit of work, manages its own worktree
    borg-grunt.md           Narrow mechanical task executor
    borg-researcher.md      Read-heavy investigation/research subagent
    borg-reviewer.md        Independent review/verdict subagent
    borg-scout.md           Lightweight recon/discovery subagent
    borg-verifier.md        Read-only pre-merge evaluator (PASS/FAIL)
bin/borg-statusline         Statusline script `borg setup --statusline` installs (opt-in): `borg next --line` + model/context
state root next-glance      `<state root>/next-glance`: `<epoch>\t<glance line>`, ONE cache file. Written (atomic) by
                            `borg link` only (`link.cli._record_glance` -> `render.glance_line`, via `nextpick.shell.write_glance`),
                            read by `borg next --line` in zsh. Not a `.borg/` store, so the reader census does not list it.
install.sh                  Installer: deps, symlinks, hooks, skills, launchd agents, tmux keybinding
lib/launchd-label.zsh       THE launchd label resolver (see "launchd labels" under Key Patterns)
lib/launchd-agents.zsh      borg setup warning for shipped launchd agents that are not loaded
launchd/                    Templates; Label is `{{LABEL}}`, installed as <label>.plist
    borg.notifyd.plist      LaunchAgent: borg-notifyd (fswatch daemon)
    borg.cortex-wake.plist  LaunchAgent: borg-cortex-watch (30s interval)
    borg.reap.plist         LaunchAgent: borg reap-worktrees (hourly)
    borg.usage-watch.plist  LaunchAgent: borg-usage-watch (usage guardian sweep)
    borg.pr-watch.plist     LaunchAgent: borg-pr-watch (default-OFF; can post to GitHub)
    borg.memory-gate.plist  LaunchAgent: borg-memory-gate (daily read-instrument check)
docs/
    boris-workflow.md       ELI5 guide to the workflow (start here)
    extensions.md           Local extensions: layers, load points, the prefer-tool type
    plans/assimilated/      Shipped plans for borg-collective itself (per-repository convention)
    plans/directives/       Backlog for borg-collective itself; every repository owns its own
    ...
```

