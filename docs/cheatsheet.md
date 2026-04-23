# Borg Collective Cheatsheet

## Borg Commands (Orchestration)

```
borg init                    First-time setup + launch orchestrator
borg                         What needs attention? Switch to it.
borg claude                  Launch/resume orchestrator Claude session

borg ls                      Dashboard: projects sorted by urgency
borg ls --all                Include archived projects
borg next                    Single recommendation: what to work on now
borg next --switch           Recommend AND switch to that project
borg switch                  fzf picker → jump to tmux window
borg switch <name>           Jump directly (skips fzf)

borg search "query"          Search knowledge graph (requires cairn)
borg search "query" --project <name>   Filter to a project

borg scan                    Auto-discover projects from session history
borg add [path]              Register a project (defaults to $PWD)
borg rm <name>               Unregister a project
borg help                    Show help
```

## Drone Commands (Project Lifecycle)

```
drone start <project> <feature>  Create worktree + branch, launch Claude (Boris workflow)
drone up [project]           Start container + create tmux window (resume existing work)
drone down [project]         Stop container + remove window
drone claude [project]       Launch Claude Code in project context
drone sh [project]           Shell into container
drone restart [project]      Restart container + re-exec panes
drone fix [project]          Restore 3-pane layout
drone toggle [project]       Show/hide top-right side pane
drone status                 Show all drones
```

## Skills

```
/borg-plan                   Project planning (Claude proposes, you validate)
/borg-assimilate             Shipping checklist + Collective review + execution
/borg-review                 Mid-session diagnostic + loop detection
/borg-collective-review      Adversarial multi-persona review (The Collective)
/borg-link                   Project intelligence (overview or per-project deep dive)
/borg-link-up                Flush session state to <project>/.borg/checkpoints/<ts>.md
/adhd-guardrails             Cognitive load guardrails (always active, auto)
/simplify                    Three parallel code review agents (built-in)
```

## Hotkey

```
Ctrl+Space >                 Jump to most pressing project (borg next --switch)
```

## Status Indicators

```
active    Claude is currently processing          (green)
waiting   Claude finished, needs your input       (yellow)
idle      Session ended                           (dim)
archived  Hidden from default ls                  (shown with --all)
```

## Boundary Behaviors

```
After hours + work project    "It's 10:30 PM. api-service is work. Switch? [y/N]"
Over capacity                 "4 sessions need attention (limit: 3)"
```

## Typical Daily Workflow

```
borg init                         Morning: orchestrator presents briefing
Ctrl+Space >                      Switch to recommended project
drone start my-project my-feature Create worktree + branch, launch Claude
/borg-plan                        Lock objectives + acceptance criteria
[work]                            Claude has last session's checkpoint as context
/simplify                         Review changed code before committing
/checkpoint                       Document session milestone
git commit                        Commit (pre-commit hook reminds /simplify if skipped)
/borg-review                      Mid-session check: am I on track?
/borg-assimilate                  Am I done? Ship it.
/borg-link-up                     Flush session state to a checkpoint before stopping
/exit                             Stop hook sets status=idle + nudges if no checkpoint
Ctrl+Space >                      Next project
```

## Configuration

```
~/.config/borg/config.zsh            Work/life boundaries, limits
~/.config/borg/registry.json         Session registry (auto-managed)
<project>/.borg/checkpoints/         User-authored checkpoints (via /borg-link-up)
```

### Config Variables

```
BORG_TMUX_SESSION=borg               tmux session name
BORG_ROOT=~/dev                      Root directory for project discovery
BORG_MAX_ACTIVE=3                    Capacity warning threshold
BORG_WORK_HOURS=09:00-18:00          Work hours (empty to disable)
BORG_WORK_DAYS=Mon,Tue,Wed,Thu,Fri   Work days
BORG_WORK_PROJECTS=proj1,proj2       Comma-separated work project names
BORG_DEBUG=1                         Enable debug output
```

## File Layout

```
~/dev/borg-collective/
    borg.zsh                 Main orchestration CLI
    drone.zsh                Project lifecycle CLI
    lib/*.zsh                Library modules
    hooks/*.sh               Claude Code hooks
    skills/*/SKILL.md        Skill definitions
    install.sh               Installer
    docs/                    Documentation

~/.config/borg/
    config.zsh               User configuration
    registry.json            Project registry

<project>/.borg/
    checkpoints/             User-authored session checkpoints

~/.claude/
    hooks/                   Symlinked hook scripts
    skills/                  Symlinked skill directories
    settings.json            Hook registrations
```
