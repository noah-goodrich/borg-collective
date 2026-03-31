# Quickstart Guide

This guide takes you from zero to a working borg installation in under ten minutes. If you're new,
read [How to Ship Like Boris](boris-workflow.md) first for context on why this exists.

## What You're Installing

Borg is two command-line tools:
- **`borg`** — Orchestrates your AI development sessions (recommendations, boundaries, planning)
- **`drone`** — Manages project containers and tmux windows (start/stop, shell access, Claude launch)

Plus six Claude Code skills, four hooks, and a tmux keybinding.

## Prerequisites

- macOS with zsh
- [tmux](https://github.com/tmux/tmux), [jq](https://jqlang.github.io/jq/),
  [fzf](https://github.com/junegunn/fzf)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
- Docker (optional, for devcontainer-based projects)
- [Cairn](https://github.com/your-username/cairn) (optional, for cross-session knowledge persistence)

## Step 1: Clone and Install

```bash
git clone https://github.com/your-username/borg-collective ~/dev/borg-collective
cd ~/dev/borg-collective
./install.sh
```

The installer:
1. Checks and installs missing dependencies via Homebrew
2. Creates `~/.config/borg/` (registry, config, debriefs)
3. Symlinks `borg` and `drone` to `~/.local/bin/`
4. Registers hooks in `~/.claude/settings.json` (SessionStart, Stop, Notification, PreToolUse)
5. Installs skills to `~/.claude/skills/`
6. Adds tmux keybinding (`Ctrl+Space >`)
7. Runs `borg scan` to discover existing projects

## Step 2: Install Community Skills

In any Claude Code session:

```
/plugin marketplace add alirezarezvani/claude-skills
```

This gives you Boris Cherny's 57-tip framework, Scope Guard, and 205+ engineering skills.

## Step 3: First Run

```bash
borg init
```

This launches the orchestrator — a Claude session that knows about all your projects. It opens with a
morning briefing: what's waiting for input, what's in progress, and one recommendation for where to
start. Resume any time with `borg claude`.

## Step 4: Try It Out

```bash
# What needs attention?
borg next

# Dashboard
borg ls

# Start new feature work (creates git worktree + branch, launches Claude)
drone start my-project my-feature

# Or resume existing work
drone up my-project
drone claude my-project

# Inside a Claude session — the Boris workflow
/borg-plan          # Lock objectives + acceptance criteria
# ... implement ...
/simplify           # Review changed code
/checkpoint         # Document session milestone before committing

# Check if you're done
/borg-ship

# Mid-session sanity check
/borg-review

# Jump to most pressing project
# (or press Ctrl+Space >)
borg next --switch
```

## Step 5: Configure Boundaries (Optional)

Create `~/.config/borg/config.zsh`:

```zsh
BORG_WORK_HOURS="09:00-18:00"
BORG_WORK_DAYS="Mon,Tue,Wed,Thu,Fri"
BORG_WORK_PROJECTS="project-a,project-b"
BORG_MAX_ACTIVE=3
```

This adds:
- Confirmation prompt when switching to work projects after hours
- Capacity warning when too many sessions need attention

## Step 6: Devcontainer Setup (Optional)

If you run projects in Docker Compose devcontainers, add this volume mount to each project's
`docker-compose.yml`:

```yaml
volumes:
  - ~/.claude:/home/vscode/.claude:cached
  - ~/.config/borg:/home/vscode/.config/borg:cached
```

This lets hooks update the registry and load skills from inside containers.

## Verification Checklist

After installation, verify:

- [ ] `which borg` → `~/.local/bin/borg`
- [ ] `which drone` → `~/.local/bin/drone`
- [ ] `borg ls` → shows discovered projects (or "No projects registered")
- [ ] `borg help` → shows full command reference
- [ ] `ls ~/.claude/skills/` → includes borg-plan, borg-ship, borg-review, etc.
- [ ] In a Claude session: `/borg-plan` is recognized as a skill

## Troubleshooting

**`borg: command not found`**
`~/.local/bin` is not in your PATH. Add to `~/.zshrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Hooks not updating registry from devcontainers**
Add the `~/.config/borg` volume mount to your container's docker-compose.yml.

**Skills not available in Claude session**
Run the installer again: `./install.sh`. It re-symlinks skills idempotently.

**`borg next` recommends a project but doesn't switch**
The project may not have a tmux window. Start it with `drone up <project>` first.
