# The Borg Collective

> Your Claude sessions will be assimilated.

A CLI for managing multiple Claude Code sessions across projects. When you're juggling five tmux windows, three devcontainers, and can't remember which session was doing what — `borg` is the command center.

Built for developers with ADHD who need external scaffolding, not willpower. Tracks sessions, enforces work/life boundaries, manages cognitive load, and answers the question that causes decision paralysis: **"What should I work on next?"**

## Quick Start

```bash
git clone https://github.com/your-username/borg-collective ~/dev/borg-collective
cd ~/dev/borg-collective
./install.sh
```

The installer handles everything:
1. Checks dependencies (jq, fzf, python3, node, tmux) — installs via Homebrew if missing
2. Installs npm packages (`claude-code-monitor`, `@tradchenko/claude-sessions`)
3. Symlinks `borg` to `~/.local/bin/borg`
4. Installs and registers Claude Code hooks (SessionStart, Stop, Notification)
5. Installs custom skills (`adhd-guardrails`, `checkpoint-enhanced`)
6. Runs `borg scan` to discover projects from `~/.claude/session-log.md`

After install, generate summaries and install the community skills marketplace:

```bash
borg refresh --all
```

Then in any Claude Code session:

```
/plugin marketplace add alirezarezvani/claude-skills
```

### Dotfiles Integration

If you manage your environment with a dotfiles repo, add one line to your installer:

```bash
[[ -x "$HOME/dev/borg-collective/install.sh" ]] && bash "$HOME/dev/borg-collective/install.sh" --quiet
```

The `--quiet` flag skips the ASCII art for clean integration with parent installers.

## Requirements

- macOS (AppleScript for notifications, `sandbox-exec` for Claude Code)
- zsh, tmux, jq, fzf, python3, node >= 18
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
- A running tmux session (default name: `dev`, configurable via `BORG_TMUX_SESSION`)

## Commands

| Command | Description |
|---------|-------------|
| `borg ls` | Dashboard: all projects with status, last active, summary |
| `borg ls --all` | Include archived projects |
| `borg switch` | fzf fuzzy picker to jump between tmux windows |
| `borg switch <name>` | Jump directly to a named project (skips fzf) |
| `borg next` | Single recommendation: what to work on now |
| `borg status [project]` | Detailed view (defaults to current directory) |
| `borg scan` | Auto-discover projects from session history |
| `borg add [path]` | Register a project (defaults to `$PWD`) |
| `borg rm <name>` | Unregister a project |
| `borg refresh [--all]` | Regenerate summary from latest transcript |
| `borg pin <project>` | Mark as priority (sorts first, preferred by `next`) |
| `borg unpin <project>` | Remove priority flag |
| `borg tidy` | Archive stale projects (idle > 48h) |
| `borg focus <project>` | Alias for `borg switch <project>` |
| `borg help` | Show help |

## How It Works

### Hooks Track Session Lifecycle

Three Claude Code hooks update the registry automatically as you work:

| Hook | Event | Registry Update |
|------|-------|-----------------|
| `borg-start.sh` | SessionStart | `status=active` |
| `borg-notify.sh` | Notification | `status=waiting` (Claude needs input) |
| `borg-stop.sh` | Stop | `status=idle`, extract summary from transcript |

These run alongside your existing hooks — they augment, not replace.

### Status Indicators

| Status | Meaning | Color |
|--------|---------|-------|
| `active` | Claude is processing | Green |
| `waiting` | Claude finished, needs your input | Yellow |
| `idle` | Session ended | Dim |
| `stale` | Idle > 48 hours | Dim + `[stale]` tag |
| `archived` | Hidden from default `ls` | Shown with `--all` |

### Summaries Without LLM Calls

`summarize.py` extracts 2-3 sentences from JSONL transcripts using pure text extraction (no LLM, no API calls, runs in < 1 second):

```
Goal: Fix Snowflake UDF deployment | Modified: deploy.py, config.yml | Last request: Add error handling
```

## Skills

Borg installs two custom skills to `~/.claude/skills/`:

### /adhd-guardrails

Always-active skill based on [Zack Proser's compassionate constraints framework](https://zackproser.com/blog/claude-external-brain-adhd-autistic). Pushes back on perfectionism, flags scope expansion, suggests breaks after 2 hours, uses shame-free language, and includes "done when" criteria in every plan.

### /checkpoint-enhanced

Invoke with `/checkpoint-enhanced` at the end of a session. Produces a structured summary: goal, accomplishments, files ready to commit, blockers, and a concrete next-session entry point. Eliminates the 23-minute context-rebuild cost when you return to a project.

### Community Skills

After installing the [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) marketplace, you get access to 205+ skills including Boris Cherny's complete 57-tip Claude Code framework and Scope Guard for preventing scope creep.

## Work/Life Boundaries

Create `~/.config/borg/config.zsh` to enable time-aware behavior:

```zsh
BORG_WORK_HOURS="09:00-18:00"
BORG_WORK_DAYS="Mon,Tue,Wed,Thu,Fri"
BORG_WORK_PROJECTS="cairn,wayfinderai-waypoint"
BORG_PERSONAL_PROJECTS="wallpaper-kit,borg-collective"
BORG_MAX_ACTIVE=3
BORG_SESSION_WARN_HOURS=2
```

With boundaries enabled:
- Work projects are dimmed in `borg ls` after hours (and vice versa)
- `borg switch cairn` at 10 PM asks: `"It's 10:00 PM. cairn is work. Switch? [y/N]"`
- Capacity warning when more than 3 sessions need attention
- Break suggestion after 2 hours in one project

These are speed bumps (one extra keystroke), not walls. Research: "External systems, not willpower, solve executive function challenges" ([NIH/PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC4425416/)).

## Devcontainer Setup

If you run Claude Code inside Docker Compose devcontainers, add this volume mount so hooks can update the registry from inside containers:

```yaml
# docker-compose.yml
volumes:
  - ~/.claude:/home/vscode/.claude:cached           # hooks, skills, settings
  - ~/.config/borg:/home/vscode/.config/borg:cached  # borg registry
```

Skills and hooks propagate automatically via the `~/.claude` bind mount. The `~/.config/borg` mount is the only addition borg requires.

## Cortex Code CLI (CoCo) Compatibility

Skills are [100% portable](https://medium.com/@kelly.kohlleffel/one-skill-two-ai-coding-assistants-snowflake-cortex-code-and-claude-code-92e0de8dfef2) between Claude Code and CoCo (same SKILL.md format). Symlink to make borg skills available in CoCo:

```bash
ln -s ~/.claude/skills/adhd-guardrails ~/.snowflake/cortex/skills/adhd-guardrails
ln -s ~/.claude/skills/checkpoint-enhanced ~/.snowflake/cortex/skills/checkpoint-enhanced
```

CoCo session tracking is not yet implemented but the architecture is forward-compatible — the registry uses string fields for `source` (`"cli"`, `"coco"`, `"desktop"`) and session discovery is modular by design. Docker (devcontainers) and Podman (CoCo) coexist without conflict.

## Composing Existing Tools

Borg is a thin coordination layer (~500 lines of zsh) on top of tools that already do the hard work:

- **[claude-code-monitor](https://github.com/onikan27/claude-code-monitor)** — Real-time status detection + Ghostty terminal focus. Run `ccm` for a live web dashboard.
- **[@tradchenko/claude-sessions](https://github.com/tradchenko/claude-sessions)** — AI-powered session picker with summaries. Run `cs` for a standalone TUI.

Borg adds: project registry, tmux window coordination, work/life boundaries, cognitive load management, and the "what next?" recommendation engine.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BORG_TMUX_SESSION` | `dev` | tmux session name |
| `BORG_DEBUG` | (unset) | Enable debug output |
| `BORG_WORK_HOURS` | (unset) | e.g. `09:00-18:00` |
| `BORG_WORK_DAYS` | (unset) | e.g. `Mon,Tue,Wed,Thu,Fri` |
| `BORG_WORK_PROJECTS` | (unset) | Comma-separated project names |
| `BORG_PERSONAL_PROJECTS` | (unset) | Comma-separated project names |
| `BORG_MAX_ACTIVE` | `3` | Soft limit on active+waiting sessions |
| `BORG_SESSION_WARN_HOURS` | `2` | Hyperfocus duration warning |

## Documentation

Full documentation lives in [`docs/`](docs/README.md):

| Document | Description |
|----------|-------------|
| [Six-Pager Narrative](docs/six-pager.md) | Formal proposal with full rationale and research citations |
| [Quickstart Guide](docs/quickstart.md) | Step-by-step installation and first run |
| [Cheatsheet](docs/cheatsheet.md) | Single-page command reference |
| [Architecture Guide](docs/architecture.md) | System design, data flow, registry schema |
| [Skills Guide](docs/skills-guide.md) | Every installed skill explained |
| [Research Foundation](docs/research.md) | 50+ citations backing every design decision |
| [Devcontainer & CoCo Guide](docs/devcontainer-coco.md) | Container and Cortex Code compatibility |

## License

MIT
