# Quickstart Guide

This guide takes you from zero to a working borg installation in under ten minutes. If you're new,
read [How to Ship Like Boris](boris-workflow.md) first for context on why this exists.

## What You're Installing

Borg is two command-line tools:
- **`borg`** — Orchestrates your AI development sessions (recommendations, boundaries, planning)
- **`drone`** — Manages project containers and tmux windows (start/stop, shell access, Claude launch)

Plus 17 Claude Code skills, 12 hooks, and a tmux keybinding.

## Prerequisites

- macOS with zsh
- [tmux](https://github.com/tmux/tmux), [jq](https://jqlang.github.io/jq/),
  [fzf](https://github.com/junegunn/fzf)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
- Docker (optional, for devcontainer-based projects)

## Step 1: Clone and Install

```bash
git clone https://github.com/your-username/borg-collective ~/dev/borg-collective
cd ~/dev/borg-collective
./install.sh
```

The installer:
1. Checks and installs missing dependencies via Homebrew
2. Creates `~/.config/borg/` (registry, config)
3. Symlinks `borg` and `drone` to `~/.local/bin/`, plus the five launchd plists in
   `~/Library/LaunchAgents/` (only `install.sh` writes those — `borg setup` never touches launchd)
4. Runs `borg setup`, which does the rest:
   - Copies hooks and their shared lib into `~/.claude/hooks/` and `~/.claude/lib/`. Copies, not
     symlinks — devcontainers bind-mount `~/.claude` and can't follow host-absolute symlinks.
   - Builds the borg-collective **plugin** into `~/dev/claude-plugins/`. Skills, agents and hook
     registration all ship through the plugin, not through `~/.claude`. See
     [Deployment Model](architecture.md#deployment-model-source--distro).
   - Adds the tmux keybinding (`Ctrl+Space >`)
   - Runs `borg scan` to discover existing projects

Then install the plugin once, from any Claude Code session:

```
claude plugin install borg-collective@noah-local
```

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

# Overview of all projects
borg link

# Start new feature work (creates git worktree + branch, launches Claude)
drone feature my-project my-feature

# Or resume existing work
drone up my-project
drone claude my-project

# Inside a Claude session — the Boris workflow
/borg-plan          # Lock objectives + acceptance criteria
# ... implement ...
/simplify           # Review changed code
/checkpoint         # Document session milestone before committing

# Check if you're done
/borg-assimilate

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

This lets hooks run and update the registry from inside containers. It is also why `borg setup`
copies hooks into `~/.claude/hooks/` instead of symlinking them — a host-absolute symlink target
does not resolve on the container side of the bind mount.

## Verification Checklist

After installation, verify:

- [ ] `which borg` → `~/.local/bin/borg`
- [ ] `which drone` → `~/.local/bin/drone`
- [ ] `borg link` → shows discovered projects (or "No projects registered")
- [ ] `borg help` → shows full command reference
- [ ] `ls ~/.claude/hooks/` → includes borg-link-down.sh, borg-link-up.sh, bash-guard.sh, etc.
- [ ] `ls ~/dev/claude-plugins/borg-collective/skills/` → the built distro: borg-plan,
      borg-assimilate, borg-review, borg-link-up, etc.
- [ ] `claude plugin list` → `borg-collective@noah-local` present and `enabled`
- [ ] In a Claude session: `/borg-plan` is recognized as a skill

Do **not** expect anything under `~/.claude/skills/` or `~/.claude/agents/` — `borg setup` removes
borg's entries there on purpose. See
[Deployment Model](architecture.md#deployment-model-source--distro).

## Troubleshooting

**`borg: command not found`**
`~/.local/bin` is not in your PATH. Add to `~/.zshrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Hooks not updating registry from devcontainers**
Add the `~/.config/borg` volume mount to your container's docker-compose.yml.

**Skills not available in Claude session**
Skills come from the plugin, not from `~/.claude/skills/`. Check `claude plugin list` — if
`borg-collective@noah-local` is missing or disabled, install or enable it. If it is enabled but
stale, run `borg setup` to rebuild the distro (idempotent, diff-guarded), then restart the session.

**`borg next` recommends a project but doesn't switch**
The project may not have a tmux window. Start it with `drone up <project>` first.
