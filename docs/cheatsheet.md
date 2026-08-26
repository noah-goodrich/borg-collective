# Borg Collective Cheatsheet

## Borg Commands (Orchestration)

```
borg init                    First-time setup + launch orchestrator
borg                         What needs attention? Switch to it.
borg claude                  Launch/resume orchestrator Claude session

borg link [project]          Primary overview: dashboard (no arg) or deep dive (with project)
borg next                    Single recommendation: what to work on now
borg next --switch           Recommend AND switch to that project
borg switch                  fzf picker → jump to tmux window
borg switch <name>           Jump directly (skips fzf)

borg recon --json            Machine surface only: reconciled sweep JSON (/borg-recon, gather.py)
borg recon --adapters        List the source adapters discovered on this machine
                             The human digest retired 2026-08-26 — borg link sweeps now

borg nanoprobes (np)         List recent nanoprobe (subagent) runs
borg nanoprobe-log <id>      Show transcript for a nanoprobe run
borg reap-worktrees [proj]   Remove stale borg-managed nanoprobe worktrees
borg spend                   Main-vs-subagent spend split + trend
borg doctor                  Verify the launchd agents

borg scan                    Auto-discover projects from session history
borg add [path]              Register a project (defaults to $PWD)
borg rm <name>               Unregister a project
borg help                    Show help

```

## Drone Commands (Project Lifecycle)

```
drone feature <project> <branch>  Create worktree + branch, launch Claude (Boris workflow)
drone up [project]           Start container + create tmux window (resume existing work)
drone down [project]         Stop container + remove window
drone claude [project]       Launch Claude Code in project context
drone cortex [project]       Launch Cortex Code (CoCo) in project context
drone sh [project]           Shell into container
drone exec [project] -- <cmd>  Run a command inside the container
drone restart [project]      Restart container + re-exec panes
drone fix [project]          Restore standard 2-pane layout
drone toggle [project]       Show/hide top-right side pane (2-pane ↔ 3-pane)
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
/borg-next                   What project needs attention most urgently?
/borg-switch                 Switch to a different project's tmux window
/borg-recon                  Cross-source synthesis over `borg recon --json` (`borg link` is the front door)
/borg-verify                 Independent pre-merge evaluator gate (PASS/FAIL)
/borg-resume                 Auto-resume a workflow paused by a session/usage limit
/adhd-guardrails             Cognitive load guardrails (always active, auto)
/simplify                    Review changed code for reuse, quality, efficiency (borg-installed)
/fable-reviewer               Fable's 5-gate working discipline (scope, evidence, adversarial review)
/break-glass                  Add a local permission exception to settings.local.json
/no-unnecessary-read-perms     Suppress redundant read-permission prompts (always active)

Full list (16 skills): docs/skills-guide.md or run /help in a session.
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
drone feature my-project my-feature  Create worktree + branch, launch Claude
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
BORG_ORCHESTRATOR_ROOT=~/dev         Workspace root; orchestrator-mode session runs here
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
