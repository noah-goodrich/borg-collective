# Quickstart Guide

This guide takes you from zero to a working `borg` installation in under ten minutes. No prior context is assumed. If you have never heard of The Borg Collective, read the [six-pager narrative](six-pager.md) first for the full rationale.

---

## What You Are Installing

The Borg Collective is a command-line tool (`borg`) that coordinates multiple Claude Code sessions across tmux windows. It provides:

- A dashboard (`borg ls`) showing all your projects, their status, and what Claude was last working on
- A fuzzy picker (`borg switch`) to jump between project tmux windows
- A recommendation engine (`borg next`) that tells you what to work on
- Work/life time boundaries that dim and gate projects based on time of day
- Automatic status tracking via Claude Code hooks (active, waiting, idle)
- Session summaries extracted from transcripts without LLM calls

Borg does NOT replace Claude Code, tmux, or any existing tool. It is a thin coordination layer (~500 lines of zsh) that glues them together.

---

## Prerequisites

You need these installed before running the installer:

| Tool | Check | Install |
|------|-------|---------|
| macOS | `uname` shows Darwin | Required (AppleScript for notifications, tmux for switching) |
| zsh | `zsh --version` | Comes with macOS |
| tmux | `tmux -V` | `brew install tmux` |
| jq | `jq --version` | `brew install jq` |
| fzf | `fzf --version` | `brew install fzf` |
| python3 | `python3 --version` | `brew install python3` |
| node >= 18 | `node --version` | `brew install node` |
| Claude Code | `claude --version` | `npm install -g @anthropic-ai/claude-code` |

The installer will check for missing tools and offer to install them via Homebrew.

You also need a running tmux session. Borg assumes your development tmux session is named `dev` (configurable via `BORG_TMUX_SESSION` environment variable).

---

## Step 1: Clone and Install

```bash
git clone https://github.com/your-username/borg-collective ~/dev/borg-collective
cd ~/dev/borg-collective
./install.sh
```

The installer will:
1. Check and install dependencies (jq, fzf, python3, node)
2. Install npm packages globally (`claude-code-monitor`, `@tradchenko/claude-sessions`)
3. Create `~/.config/borg/` and initialize `registry.json`
4. Symlink `borg` to `~/.local/bin/borg`
5. Symlink hooks to `~/.claude/hooks/`
6. Register hooks in `~/.claude/settings.json` (Stop, Notification, SessionStart events)
7. Install the skills ecosystem (see Step 2)
8. Run `borg scan` to discover existing projects

Make sure `~/.local/bin` is in your PATH. If not, add to `~/.zshrc`:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## Step 2: Install Skills

After the installer runs, install the community skills that encode best practices:

```bash
# In any Claude Code session:
/plugin marketplace add alirezarezvani/claude-skills
```

This gives you access to Boris Cherny's 57-tip framework, 205+ engineering skills, and the Scope Guard skill that prevents scope creep.

The installer also creates two custom skills:

**`~/.claude/skills/adhd-guardrails/SKILL.md`** — Compassionate constraints based on Zack Proser's framework for neurodivergent developers. Pushes back on perfectionism, suggests breaks after 2 hours, flags scope expansion, uses shame-free language.

**`~/.claude/skills/checkpoint-enhanced/SKILL.md`** — Session checkpoint that produces a summary with explicit next-session entry point. Answers: what was the goal, what was accomplished, what blockers remain, what should the next session focus on.

Both skills are installed in `~/.claude/skills/` and are automatically available in every Claude Code session. Because `~/.claude/` is bind-mounted into devcontainers, they also propagate to container sessions.

---

## Step 3: Bootstrap Your Registry

If the installer did not run `borg scan` automatically:

```bash
borg scan
```

This reads `~/.claude/session-log.md` and discovers all projects you have previously opened in Claude Code. Each project is registered with its path, tmux window name, and latest session ID.

Verify the registry:
```bash
borg ls
```

You should see a table with your projects, their status, and any available summaries.

---

## Step 4: Generate Summaries

To populate summaries for all discovered projects:

```bash
borg refresh --all
```

This runs `summarize.py` on the latest JSONL transcript for each project and stores the result in the registry. Summaries are 2-3 sentences extracted from the transcript: the initial goal, files modified, and last request.

Going forward, summaries are generated automatically by the Stop hook whenever a Claude Code session ends.

---

## Step 5: Try It Out

```bash
# See all your projects
borg ls

# Get a recommendation for what to work on
borg next

# Switch to a specific project (skips fzf if exact match)
borg switch cairn

# Open the fuzzy picker to choose a project
borg switch

# See detailed status for a project
borg status cairn

# Pin a priority project (sorts first in ls, preferred by next)
borg pin wallpaper-kit

# Archive a stale project (hides from default ls)
borg tidy
```

---

## Step 6: Devcontainer Setup (If Applicable)

If you run Claude Code inside Docker Compose devcontainers, add this volume mount to each project's `docker-compose.yml`:

```yaml
volumes:
  # ... existing mounts (e.g., ~/.claude, ~/.ssh, etc.) ...
  - ~/.config/borg:/home/vscode/.config/borg:cached  # Borg registry
```

Without this mount, borg hooks fire inside the container but registry updates are written to the container filesystem and lost on rebuild.

No other changes are needed. Since `~/.claude/` is already bind-mounted, hooks, skills, and settings propagate automatically from host to container.

---

## Step 7: Configure Boundaries (Phase 1)

After using borg for a few days, set up work/life boundaries by creating `~/.config/borg/config.zsh`:

```zsh
# Work/life boundaries
BORG_WORK_HOURS="09:00-18:00"
BORG_WORK_DAYS="Mon,Tue,Wed,Thu,Fri"
BORG_WORK_PROJECTS="cairn,wayfinderai-waypoint"
BORG_PERSONAL_PROJECTS="wallpaper-kit,borg-collective"

# Cognitive load limits
BORG_MAX_ACTIVE=3
BORG_SESSION_WARN_HOURS=2
```

With this config:
- Work projects are dimmed in `borg ls` after 6 PM
- `borg switch cairn` at 10:30 PM asks: "It's 10:30 PM. cairn is work. Switch? [y/N]"
- `borg ls` shows a warning when more than 3 sessions need attention
- After 2 hours in one project, borg suggests a break

---

## Verification Checklist

After installation, verify each component works:

- [ ] `borg scan` discovers projects from `~/.claude/session-log.md`
- [ ] `borg ls` shows a table with project names, status, and summaries
- [ ] `borg switch <project>` lands in the correct tmux window
- [ ] `borg switch` (no argument) opens fzf picker with preview
- [ ] `borg status <project>` shows detailed information
- [ ] `borg next` recommends a project
- [ ] Start a Claude Code session in a tracked project, then exit. Verify `borg ls` shows the updated summary.

---

## Troubleshooting

**`borg: command not found`**
- Ensure `~/.local/bin` is in your PATH
- Run: `ls -la ~/.local/bin/borg` to verify the symlink exists

**`borg scan` shows no projects**
- Check that `~/.claude/session-log.md` exists and has entries
- Run: `wc -l ~/.claude/session-log.md`

**Hooks don't update registry from devcontainers**
- Verify `~/.config/borg/` is volume-mounted in docker-compose.yml
- Check: `docker exec <container> ls ~/.config/borg/registry.json`

**`borg switch` can't find tmux session**
- Verify tmux is running: `tmux ls`
- Check session name: default is `dev`, configurable via `BORG_TMUX_SESSION`

**Skills not available in Claude Code**
- Run `/plugin` in a Claude Code session to verify installed plugins
- Check `~/.claude/skills/` for custom skill files

---

## What's Next

- Read the [cheatsheet](cheatsheet.md) for a single-page command reference
- Read the [architecture guide](architecture.md) for how all the pieces fit together
- Read the [skills guide](skills-guide.md) for details on each installed skill
- Read the [research foundation](research.md) for the ADHD research backing every design decision
