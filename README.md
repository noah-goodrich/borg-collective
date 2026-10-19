# The Borg Collective

> Your sessions will be assimilated.

An AI development orchestration framework. Two commands — `borg` for orchestration, `drone` for repository
lifecycle — that coordinate parallel Claude Code sessions across repositories and containers.

Built for sustainable AI-assisted development. Tracks sessions, enforces work/life boundaries, manages
cognitive load, persists context across sessions, and answers the question that causes decision paralysis:
**"What should I work on next?"**

**New here?** Read [How to Ship Like Boris (and Not Lose Your Mind)](docs/boris-workflow.md) first.

## Installation

```bash
git clone https://github.com/noah-goodrich/borg-collective ~/dev/borg-collective
cd ~/dev/borg-collective && ./install.sh
borg init
```

`install.sh` installs the `borg` + `drone` CLIs and runs `borg setup`, which registers Claude Code
hooks, installs skills, and configures the tmux keybinding. Safe to re-run.

Upgrading an existing machine, or setting one up from scratch? Follow [Upgrading borg on any machine](docs/upgrading.md).

### First run

```bash
borg scan   # auto-discover repositories from Claude session history
borg init   # launch the Queen: morning briefing + Claude session
```

## Requirements

- macOS (Apple Silicon or Intel)
- zsh, tmux, jq, fzf
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- Docker (optional, for devcontainer-based repositories)

## Commands

### `borg` — Orchestration

| Command | Description |
|---------|-------------|
| `borg init` | Launch the Queen: morning briefing + Claude session |
| `borg` / `borg next` | What needs attention? Switch to it. |
| `borg claude` | Resume the Queen session (continue most recent) |
| `borg link [repository]` | **Front door.** At the Queen's root (the workspace root) it is the cross-repository overview; anywhere else, or with a repository, it is a page about that one directory (identity, session, its own checkpoints, what waits on it). `--overview` forces the overview from any directory, and `--overview --full` prints it with no page budget (the default page fits one screen: STACKS and QUEUED are counts) |
| `borg switch [query]` | fzf picker → jump to repository tmux window |
| `borg recon --json` | Machine surface only: the reconciled sweep document. Human digest retired — use `borg link` |
| `borg nanoprobes` (`np`) | List recent nanoprobe runs (subagents) |
| `borg nanoprobe-log <id>` | Show transcript for a nanoprobe run |
| `borg reap-worktrees [repository]` | Remove stale borg-managed nanoprobe worktrees |
| `borg spend` | Main-vs-subagent spend split + trend |
| `borg doctor` | Verify the launchd agents (registered/exit status/fresh output) |
| `borg scan` | Auto-discover repositories from session history |
| `borg add [path]` | Register a repository (defaults to `$PWD`) |
| `borg rm <name>` | Unregister a repository |
| `borg help` | Full command reference |

### `drone` — Repository Lifecycle

| Command | Description |
|---------|-------------|
| `drone feature <repository> <branch>` | Create git worktree + branch, start window, launch Claude |
| `drone up [repository]` | Start container + create tmux window (resume existing work) |
| `drone down [repository]` | Stop container + remove tmux window |
| `drone claude [repository]` | Launch Claude Code session in repository window |
| `drone cortex [repository]` | Launch Cortex Code (CoCo) session in repository window |
| `drone sh [repository]` | Shell into repository container |
| `drone exec [repository] -- <cmd>` | Run a command inside the repository container |
| `drone restart [repository\|--all]` | Restart container(s) + re-exec all panes |
| `drone rebuild [repository\|--all]` | Rebuild image (no cache) + restart + re-exec panes |
| `drone fix [repository\|--all]` | Restore standard 2-pane layout |
| `drone toggle [repository]` | Add/remove top-right side pane (2-pane ↔ 3-pane) |
| `drone scaffold <dir>` | Generate `.devcontainer/` from templates |

### Hotkey

`Ctrl+Space >` — Jump to the most pressing repository (runs `borg next --switch`).

## Drones vs Nanoprobes

Two assimilation units, two lifetimes. Don't blur them.

| Unit | What it is | Lifetime | Scope | Spawned by |
|------|------------|----------|-------|------------|
| **Drone** | Persistent devcontainer (Docker Compose) | Long-lived; one per repository | Whole repository — toolchain, dependencies, runtime | `drone up <repository>` |
| **Nanoprobe** | Ephemeral Claude Code subagent (`borg-nanoprobe`) | Single task; exits on completion | One discrete unit of work in a git worktree | The Queen via the Agent tool |

The Queen session never edits repository files inline. It spawns nanoprobes (background, worktree-isolated)
that perform the work, commit, and exit. The `SubagentStop` hook (`borg-nanoprobe-log.sh`) appends a JSONL
record to `~/.config/borg/agents.jsonl` so you can list recent runs with `borg nanoprobes` and pull
transcripts with `borg nanoprobe-log <id>`.

## How It Works

### Hooks Track Session Lifecycle

Three hooks update the registry automatically:

| Hook | Event | What happens |
|------|-------|-------------|
| `borg-link-down.sh` | SessionStart | Status → active; injects latest checkpoint + plan nudge if no PROJECT_PLAN.md |
| `borg-notify.sh` | Notification | Status → waiting, captures what Claude needs |
| `borg-link-up.sh` | Stop | Status → idle; warns on uncommitted changes; nudges if no recent checkpoint |
| `borg-nanoprobe-log.sh` | SubagentStop | Appends one JSONL line per nanoprobe completion to `~/.config/borg/agents.jsonl` |
| `pre-commit-remind.sh` | PreToolUse | Reminds Claude to run /simplify before git commit |
| `borg-plan-promote.sh` | PreToolUse | Auto-promotes ExitPlanMode plan to `docs/plans/PROJECT_PLAN.md` |

### Session Checkpoints

The session lifecycle uses a "link up / link down" metaphor — Claude links down from the collective
when a session starts (SessionStart hook downloads the latest checkpoint), and you run
`/borg-link-up` before stopping to flush the session state to a timestamped checkpoint at
`<repository>/.borg/checkpoints/<ts>.md`. The next session's SessionStart hook automatically loads it
back as context.

Checkpoints are user-authored (you own the prose) and stored in-repo — no LLM spend, no hidden
summaries, portable across machines via git if you want. If you stop without checkpointing, the
stop hook prints a one-line nudge.

No more "where was I?" — your last checkpoint tells you.

### Status Indicators

| Status | Meaning | Color |
|--------|---------|-------|
| `active` | Claude is processing | Green |
| `waiting` | Claude finished, needs your input | Yellow |
| `idle` | Session ended | Dim |
| `archived` | Hidden from default `ls` | Shown with `--all` |

## Skills

Borg installs 16 skills to `~/.claude/skills/`. See [Skills Guide](docs/skills-guide.md) for the full
list, or run `/help` in a Claude Code session — the highlights:

### Always Active

**`/adhd-guardrails`** — Cognitive load guardrails. Pushes back on perfectionism, flags scope expansion,
suggests breaks after sustained work, uses shame-free language. Based on
[Zack Proser's framework](https://zackproser.com/blog/claude-external-brain-adhd-autistic).

### Planning and Shipping

**`/borg-plan`** — Project planning that does the thinking for you. Reads the codebase, proposes
objectives, acceptance criteria, verification strategy, scope boundaries, and ship definition. You
validate and confirm. Criteria are locked once established — scope changes require explicit confirmation.

**`/borg-assimilate`** — Shipping checklist + execution. Evaluates every acceptance criterion with
evidence from code, tests, and git, then executes shipping (merge PR, archive plan) with confirmation.

**`/borg-review`** — Mid-session diagnostic. Checks progress against the plan, detects scope creep and
bad loops (same error 3+ times, yak shaving, perfectionism spirals), and gives ONE recommendation for
what to do next.

### Session Management

**`/borg-link-up`** — Flush session state to a checkpoint before stopping. Five-section structured
summary (Goal, Accomplished, Ready to Commit, Blockers, Next Session). Writes to
`<repository>/.borg/checkpoints/<timestamp>.md`. The next SessionStart hook (`borg-link-down.sh`) loads
the newest checkpoint as context.

### Community Skills

Install via `/plugin marketplace add alirezarezvani/claude-skills`:
- Boris Cherny's complete 57-tip Claude Code framework
- Scope Guard (prevents scope creep)
- 205+ engineering, architecture, and DevOps skills

## Work/Life Boundaries

Create `~/.config/borg/config.zsh`:

```zsh
BORG_WORK_HOURS="09:00-18:00"
BORG_WORK_DAYS="Mon,Tue,Wed,Thu,Fri"
BORG_WORK_PROJECTS="api-service,data-pipeline"
BORG_MAX_ACTIVE=3
```

With boundaries enabled:
- Switching to a work repository after hours: `"It's 10:30 PM. api-service is work. Switch? [y/N]"`
- Capacity warning when more than 3 sessions need attention
- These are speed bumps (one keystroke), not walls

## Cross-Session Knowledge

Checkpoints live in each repository's `.borg/checkpoints/` (written via `/borg-link-up`) and are loaded
on session start — that is the durable, per-repository record. Cross-repository recall comes from Claude
Code's own project-memory system, instrumented by `borg-memory-read-log.sh` /
`bin/memory-hits-report` so its actual usage is visible rather than assumed.

## Devcontainer Setup

If you run repositories in Docker Compose devcontainers, add these volume mounts so Claude Code skills,
hooks, and settings are available inside the container:

```yaml
volumes:
  - ~/.claude:/home/dev/.claude:cached
  - ~/.config/borg:/home/dev/.config/borg:cached
  - ~/.config/dotfiles/claude:/home/dev/.config/dotfiles/claude:cached
  - ~/:/host-home:ro   # postStartCommand copies .claude.json fresh on each start
```

And in `devcontainer.json`:

```json
"postStartCommand": "ln -sf /home/dev/.config/dotfiles/claude/code/CLAUDE.md /home/dev/.claude/CLAUDE.md; cp /host-home/.claude.json /home/dev/.claude.json 2>/dev/null || true"
```

The CLAUDE.md symlink must be recreated on each start because the host-absolute symlink path does not
resolve inside the container. See `drone scaffold` to generate this automatically for new repositories.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BORG_TMUX_SESSION` | `borg` | tmux session name |
| `BORG_ORCHESTRATOR_ROOT` | `~/dev` | The Queen's workspace root |
| `BORG_MAX_ACTIVE` | `3` | Capacity warning threshold |
| `BORG_WORK_HOURS` | (unset) | e.g. `09:00-18:00` |
| `BORG_WORK_DAYS` | (unset) | e.g. `Mon,Tue,Wed,Thu,Fri` |
| `BORG_WORK_PROJECTS` | (unset) | Comma-separated repository names |
| `BORG_DEBUG` | (unset) | Enable debug output |

## Documentation

| Document | Description |
|----------|-------------|
| [Boris Workflow (ELI5)](docs/boris-workflow.md) | Start here. How parallel AI dev works and why borg exists. |
| [Quickstart](docs/quickstart.md) | Step-by-step installation and first run |
| [Cheatsheet](docs/cheatsheet.md) | Single-page command reference |
| [Architecture](docs/architecture.md) | System design, data flow, registry schema |
| [Skills Guide](docs/skills-guide.md) | Every skill explained |
| [Research](docs/research.md) | 50+ citations backing design decisions |
| [Devcontainer & CoCo](docs/devcontainer-coco.md) | Container and Cortex Code compatibility |

## License

MIT
