# The Borg Collective

> Your sessions will be assimilated.

An AI development orchestration framework. Two commands — `borg` for orchestration, `drone` for project
lifecycle — that coordinate parallel Claude Code sessions across projects and containers.

Built for sustainable AI-assisted development. Tracks sessions, enforces work/life boundaries, manages
cognitive load, persists context across sessions, and answers the question that causes decision paralysis:
**"What should I work on next?"**

**New here?** Read [How to Ship Like Boris (and Not Lose Your Mind)](docs/boris-workflow.md) first.

## Installation

### Homebrew (recommended)

```bash
brew tap noah-goodrich/borg-collective https://github.com/noah-goodrich/borg-collective.git
brew install borg-collective
borg setup
```

`borg setup` registers Claude Code hooks, installs skills, and configures the tmux keybinding.
Safe to re-run.

### From source (dev install)

```bash
git clone https://github.com/noah-goodrich/borg-collective ~/dev/borg-collective
cd ~/dev/borg-collective && ./install.sh
borg init
```

### First run

```bash
borg scan   # auto-discover projects from Claude session history
borg init   # morning briefing + launch orchestrator session
```

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
| `drone feature <project> <branch>` | Create git worktree + branch, start window, launch Claude |
| `drone up [project]` | Start container + create tmux window (resume existing work) |
| `drone down [project]` | Stop container + remove tmux window |
| `drone claude [project]` | Launch Claude Code session in project context |
| `drone sh [project]` | Shell into project container |
| `drone restart [project\|--all]` | Restart container(s) + re-exec all panes |
| `drone rebuild [project\|--all]` | Rebuild image (no cache) + restart + re-exec panes |
| `drone fix [project\|--all]` | Restore standard 2-pane layout |
| `drone toggle [project]` | Add/remove top-right side pane (2-pane ↔ 3-pane) |
| `drone scaffold <dir>` | Generate `.devcontainer/` from templates |
| `drone status` | Show all drones (container + session state) |

### Hotkey

`Ctrl+Space >` — Jump to the most pressing project (runs `borg next --switch`).

## How It Works

### Hooks Track Session Lifecycle

Three hooks update the registry automatically:

| Hook | Event | What happens |
|------|-------|-------------|
| `borg-link-down.sh` | SessionStart | Status → active; injects latest checkpoint + plan nudge if no PROJECT_PLAN.md |
| `borg-notify.sh` | Notification | Status → waiting, captures what Claude needs |
| `borg-link-up.sh` | Stop | Status → idle; warns on uncommitted changes; nudges if no recent checkpoint |
| `pre-commit-remind.sh` | PreToolUse | Reminds Claude to run /simplify before git commit |

### Session Checkpoints

The session lifecycle uses a "link up / link down" metaphor — Claude links down from the collective
when a session starts (SessionStart hook downloads the latest checkpoint), and you run
`/borg-link-up` before stopping to flush the session state to a timestamped checkpoint at
`<project>/.borg/checkpoints/<ts>.md`. The next session's SessionStart hook automatically loads it
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

**`/borg-link-up`** — Flush session state to a checkpoint before stopping. Five-section structured
summary (Goal, Accomplished, Ready to Commit, Blockers, Next Session). Writes to
`<project>/.borg/checkpoints/<timestamp>.md`. The next SessionStart hook (`borg-link-down.sh`) loads
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
- Switching to a work project after hours: `"It's 10:30 PM. api-service is work. Switch? [y/N]"`
- Capacity warning when more than 3 sessions need attention
- These are speed bumps (one keystroke), not walls

## Knowledge Persistence (Cairn)

[Cairn](https://github.com/your-username/cairn) is an optional knowledge graph (PostgreSQL + pgvector)
that persists decisions, patterns, and session context across sessions and projects. When available:

- Cross-session patterns and decisions can be committed to the graph for vector search
- `borg search "query"` finds relevant past decisions and patterns
- Orchestrator briefings include cairn knowledge

Borg works without cairn — checkpoints live in each project's `.borg/checkpoints/` and are loaded
on session start. Cairn adds cross-project search and long-term knowledge persistence.

## Devcontainer Setup

If you run projects in Docker Compose devcontainers, add these volume mounts so Claude Code skills,
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
resolve inside the container. See `drone scaffold` to generate this automatically for new projects.

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
