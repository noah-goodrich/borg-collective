# Borg Collective Cheatsheet

## Commands

```
borg ls                      Show all projects (status, summary, last active)
borg ls --all                Include archived projects
borg ls --porcelain          Machine-readable tab-delimited output

borg switch                  Open fzf picker, jump to selected tmux window
borg switch <name>           Jump directly to named project (skips fzf)

borg next                    Single recommendation: what to work on now

borg status [project]        Detailed view (defaults to current directory)

borg scan                    Auto-discover projects from ~/.claude/session-log.md
borg add [path]              Manually register (defaults to $PWD)
borg rm <name>               Unregister a project

borg refresh [project]       Regenerate summary from latest transcript
borg refresh --all           Regenerate all summaries

borg pin <project>           Mark as priority (sorts first, preferred by next)
borg unpin <project>         Remove priority flag

borg tidy                    Interactive cleanup of stale (idle >48h) projects

borg help                    Show help
```

## Status Indicators

```
active    Claude is currently processing          (green)
waiting   Claude finished, needs your input       (yellow)
idle      Session ended                           (dim)
stale     Idle for 48+ hours                      (dim + [stale] tag)
archived  Hidden from default ls                  (shown with --all)
unknown   Not yet tracked                         (gray)
```

## Source Badges

```
[C]       Claude Code CLI session
[D]       Claude Desktop conversation
```

## Boundary Behaviors

```
After hours + work project    "It's 10:30 PM. cairn is work. Switch? [y/N]"
During hours + personal       Personal projects dimmed (still accessible)
>3 active sessions            "WARNING: 5 sessions need attention (max: 3)"
>2 hours in one project       "You've been in cairn for 2h. Take a break?"
```

## Configuration

File: `~/.config/borg/config.zsh`

```zsh
BORG_WORK_HOURS="09:00-18:00"          # Empty to disable
BORG_WORK_DAYS="Mon,Tue,Wed,Thu,Fri"   # Comma-separated
BORG_WORK_PROJECTS="cairn,waypoint"    # Comma-separated project names
BORG_PERSONAL_PROJECTS="wallpaper-kit" # Comma-separated project names
BORG_MAX_ACTIVE=3                      # Soft limit on active+waiting
BORG_SESSION_WARN_HOURS=2              # Hyperfocus warning threshold
BORG_TMUX_SESSION="dev"                # tmux session name
BORG_DEBUG=""                          # Set to 1 for debug output
```

## Registry

Location: `~/.config/borg/registry.json`

```json
{
  "projects": {
    "cairn": {
      "path": "/Users/noah/dev/cairn",
      "source": "cli",
      "tmux_session": "dev",
      "tmux_window": "cairn",
      "claude_session_id": "813c927e-...",
      "last_activity": "2026-03-28T10:00:00Z",
      "status": "idle",
      "summary": "Goal: ... | Modified: ... | Last: ...",
      "pinned": false,
      "goal": "Ship v1.0",
      "done_when": "deploy runs on staging"
    }
  }
}
```

## Hooks

```
borg-start.sh     SessionStart  -> status=active
borg-stop.sh      Stop          -> status=idle, extract summary
borg-notify.sh    Notification  -> status=waiting
```

Location: `~/.claude/hooks/` (symlinked from repo)

## Installed Skills

```
/adhd-guardrails          Compassionate constraints (auto, no invocation needed)
/checkpoint-enhanced      Session summary + next-session entry point
/simplify                 3-agent parallel code review (built-in)
/checkpoint               Quick session summary (built-in)
/batch                    Parallelized large changes (built-in)
```

## Key Files

```
~/dev/borg-collective/
  borg.zsh                Main CLI entry point
  lib/registry.zsh        Registry CRUD
  lib/tmux.zsh            tmux integration
  lib/claude.zsh          Session discovery
  lib/desktop.zsh         Desktop session reader
  summarize.py            Transcript -> summary (no LLM)
  hooks/borg-start.sh     SessionStart hook
  hooks/borg-stop.sh      Stop hook
  hooks/borg-notify.sh    Notification hook
  install.sh              Installer
  docs/                   This documentation

~/.config/borg/
  registry.json           Project registry
  config.zsh              Boundary configuration

~/.claude/
  hooks/                  Hooks (symlinked)
  skills/                 Custom skills
  settings.json           Hook registration
  session-log.md          Session history
  projects/               Per-project JSONL transcripts
```

## Devcontainer Volume Mount

Add to `docker-compose.yml`:
```yaml
- ~/.config/borg:/home/vscode/.config/borg:cached
```

## Common Workflows

```bash
# Morning: see what needs attention
borg ls && borg next

# Switch to recommended project
borg switch cairn

# End of session: checkpoint (inside Claude)
/checkpoint-enhanced

# End of day: clean up
borg tidy

# New project: register
borg add ~/dev/new-project

# Shipping focus: set acceptance criteria
borg status cairn   # then manually edit registry to add goal/done_when
```

## Companion Tools (Not Part of Borg)

```
ccm                       claude-code-monitor: live web dashboard
cs                        claude-sessions: AI-powered session picker
claude --worktree <name>  Git worktree isolation (native)
/compact                  Context compression (native)
/clear                    Reset context (native)
/rewind                   Navigate checkpoints (native)
```
