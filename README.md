# The Borg Collective

> Your sessions will be assimilated.

An AI development orchestration framework. Two commands — `borg` for orchestration, `drone` for project
lifecycle — that coordinate parallel Claude Code sessions across projects and containers.

Built for sustainable AI-assisted development. Tracks sessions, enforces work/life boundaries, manages
cognitive load, persists context across sessions, and answers the question that causes decision paralysis:
**"What should I work on next?"**

**New here?** Read [How to Ship Like Boris (and Not Lose Your Mind)](docs/boris-workflow.md) first.

## Quick Start

```bash
git clone https://github.com/your-username/borg-collective ~/dev/borg-collective
cd ~/dev/borg-collective && ./install.sh
borg init
```

The installer handles everything:
1. Checks dependencies (jq, fzf, tmux) — installs via Homebrew if missing
2. Symlinks `borg` and `drone` to `~/.local/bin/`
3. Installs and registers Claude Code hooks (SessionStart, Stop, Notification, PreToolUse)
4. Installs skills (cognitive load guardrails, planning, shipping, review, debrief, checkpoint)
5. Configures tmux keybinding (`Ctrl+Space >` → jump to most pressing project)
6. Runs `borg scan` to discover projects

Then in any Claude Code session:

```
/plugin marketplace add alirezarezvani/claude-skills
```

This installs Boris Cherny's 57-tip framework, Scope Guard, and 205+ community skills.

## Requirements

- macOS (Apple Silicon or Intel)
- zsh, tmux, jq, fzf
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- Docker (optional, for devcontainer-based projects)
- [Cairn](https://github.com/your-username/cairn) (optional, for cross-session knowledge persistence)

## Commands

### `borg` — Orchestration

| Command | Description |
|---------|-------------|
| `borg init` | Morning briefing + launch orchestrator Claude session |
| `borg` / `borg next` | What needs attention? Switch to it. |
| `borg claude` | Resume orchestrator Claude session |
| `borg ls [--all]` | Dashboard: all projects sorted by urgency |
| `borg switch [query]` | fzf picker → jump to project tmux window |
| `borg status [project]` | Detailed status for one project |
| `borg hail [project]` | Morning briefing (no arg) or project detail |
| `borg search "query"` | Search knowledge graph (requires cairn) |
| `borg scan` | Auto-discover projects from session history |
| `borg add [path]` | Register a project (defaults to `$PWD`) |
| `borg rm <name>` | Unregister a project |
| `borg help` | Full command reference |

### `drone` — Project Lifecycle

| Command | Description |
|---------|-------------|
| `drone start <project> <feature>` | Create git worktree + branch, start window, launch Claude |
| `drone up [project]` | Start container + create tmux window (resume existing work) |
| `drone down [project]` | Stop container + remove tmux window |
| `drone claude [project]` | Launch Claude Code session in project context |
| `drone sh [project]` | Shell into project container |
| `drone restart [project]` | Restart container + re-exec all panes |
| `drone fix [project]` | Restore standard 3-pane layout |
| `drone toggle [project]` | Show/hide the top-right side pane |
| `drone status` | Show all drones (container + session state) |

### Hotkey

`Ctrl+Space >` — Jump to the most pressing project (runs `borg next --switch`).

## How It Works

### Hooks Track Session Lifecycle

Three hooks update the registry automatically:

| Hook | Event | What happens |
|------|-------|-------------|
| `borg-start.sh` | SessionStart | Status → active; injects last debrief + plan nudge if no PROJECT_PLAN.md |
| `borg-notify.sh` | Notification | Status → waiting, captures what Claude needs |
| `borg-stop.sh` | Stop | Status → idle; runs deep session debrief; warns on uncommitted changes |
| `pre-commit-remind.sh` | PreToolUse | Reminds Claude to run /simplify before git commit |

### Session Debriefs

When a Claude session ends, the stop hook runs a structured analysis of the full transcript using
Claude Sonnet (~$0.10/session). The debrief captures: objective, outcome, decisions made with
reasoning, patterns discovered, and specific next steps. This debrief is stored and automatically
loaded as context when you start your next session in that project.

No more "where was I?" — Claude already knows.

### Status Indicators

| Status | Meaning | Color |
|--------|---------|-------|
| `active` | Claude is processing | Green |
| `waiting` | Claude finished, needs your input | Yellow |
| `idle` | Session ended | Dim |
| `archived` | Hidden from default `ls` | Shown with `--all` |

## Skills

Borg installs six skills to `~/.claude/skills/`:

### Always Active

**`/adhd-guardrails`** — Cognitive load guardrails. Pushes back on perfectionism, flags scope expansion,
suggests breaks after sustained work, uses shame-free language. Based on
[Zack Proser's framework](https://zackproser.com/blog/claude-external-brain-adhd-autistic).

### Planning and Shipping

**`/borg-plan`** — Project planning that does the thinking for you. Reads the codebase, proposes
objectives, acceptance criteria, verification strategy, scope boundaries, and ship definition. You
validate and confirm. Criteria are locked once established — scope changes require explicit confirmation.

**`/borg-ship`** — Shipping checklist. Evaluates every acceptance criterion with evidence from code,
tests, and git. Tells you what's done, what's left, and provides the exact commands to ship.

**`/borg-review`** — Mid-session diagnostic. Checks progress against the plan, detects scope creep and
bad loops (same error 3+ times, yak shaving, perfectionism spirals), and gives ONE recommendation for
what to do next.

### Session Management

**`/borg-debrief`** — Deep session analysis. Runs automatically via stop hook. Captures objective,
outcome, decisions, patterns, and next steps in structured format for future sessions.

**`/borg-checkpoint`** — Manual session checkpoint. Structured summary with next-session entry point.
Use before breaks or when switching projects.

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
- Switching to a work project after hours: `"It's 10:30 PM. api-service is work. Switch? [y/N]"`
- Capacity warning when more than 3 sessions need attention
- These are speed bumps (one keystroke), not walls

## Knowledge Persistence (Cairn)

[Cairn](https://github.com/your-username/cairn) is an optional knowledge graph (PostgreSQL + pgvector)
that persists decisions, patterns, and session context across sessions and projects. When available:

- Session debriefs are stored as structured records with vector embeddings
- `borg search "query"` finds relevant past decisions and patterns
- Orchestrator briefings include cairn knowledge

Borg works without cairn — debriefs are stored as markdown files and loaded on next session start.
Cairn adds cross-project search and long-term knowledge persistence.

## Devcontainer Setup

If you run projects in Docker Compose devcontainers, add this volume mount:

```yaml
volumes:
  - ~/.claude:/home/vscode/.claude:cached           # hooks, skills, settings
  - ~/.config/borg:/home/vscode/.config/borg:cached  # borg registry + debriefs
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BORG_TMUX_SESSION` | `borg` | tmux session name |
| `BORG_ROOT` | `~/dev` | Root directory for project discovery |
| `BORG_MAX_ACTIVE` | `3` | Capacity warning threshold |
| `BORG_WORK_HOURS` | (unset) | e.g. `09:00-18:00` |
| `BORG_WORK_DAYS` | (unset) | e.g. `Mon,Tue,Wed,Thu,Fri` |
| `BORG_WORK_PROJECTS` | (unset) | Comma-separated project names |
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
