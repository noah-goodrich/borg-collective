# Borg Collective Cheatsheet

## Borg Commands (Orchestration)

```
borg init                    First-time setup + launch the Queen
borg                         What needs attention? Switch to it.
borg claude                  Resume the Queen session (most recent)

borg link [repository]       Front door: the Queen's overview at the
                             workspace root; ONE directory's page
                             anywhere else
borg link --overview         Force the Queen's overview from any directory
borg next                    Single recommendation: what to work on now
borg next --switch           Recommend AND switch to that repository
borg switch                  fzf picker → jump to tmux window
borg switch <name>           Jump directly (skips fzf)

borg recon --json            Machine surface only: reconciled sweep JSON (/borg-recon)
borg recon --adapters        List the source adapters discovered on this machine
                             The human digest retired 2026-08-26 — borg link sweeps now

borg nanoprobes (np)         List recent nanoprobe (subagent) runs
borg nanoprobe-log <id>      Show transcript for a nanoprobe run
borg reap-worktrees [repository]  Remove stale nanoprobe worktrees
borg spend                   Main-vs-subagent spend split + trend
borg doctor                  Verify the launchd agents

borg scan                    Discover repositories from session history
borg add [path]              Register a repository (defaults to $PWD)
borg rm <name>               Unregister a repository
borg help                    Show help

```

## Drone Commands (Repository Lifecycle)

```
drone feature <repository> <branch>
                             Create worktree + branch, launch Claude
                             (Boris workflow)
drone up [repository]        Start container + create tmux window
drone down [repository]      Stop container + remove window
drone claude [repository]    Launch Claude Code in repository window
drone cortex [repository]    Launch Cortex Code in repository window
drone sh [repository]        Shell into container
drone exec [repository] -- <cmd>
                             Run a command inside the container
drone restart [repository]   Restart container + re-exec panes
drone fix [repository]       Restore standard 2-pane layout
drone toggle [repository]    Show/hide side pane (2 ↔ 3 panes)
```

## Skills

```
/borg-plan                   Project planning (Claude proposes, you validate)
/borg-assimilate             Shipping checklist + Collective review + execution
/borg-review                 Mid-session diagnostic + loop detection
/borg-collective-review      Adversarial multi-persona review (The Collective)
/borg-link                   This directory's page (Queen: overview)
/borg-link-up                Flush session state to a checkpoint
/borg-next                   Which repository needs attention first?
/borg-switch                 Switch to a repository's tmux window
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
Ctrl+Space >                 Jump to most pressing repository
                             (runs borg next --switch)
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
After hours + work repository
    "It's 10:30 PM. api-service is work. Switch? [y/N]"
Over capacity
    "4 sessions need attention (limit: 3)"
```

## Typical Daily Workflow

```
borg init                         Morning: the Queen presents briefing
Ctrl+Space >                      Switch to recommended repository
drone feature my-repo my-feature  Create worktree, launch Claude
/borg-plan                        Lock objectives + acceptance criteria
[work]                            Claude has last session's checkpoint as context
/simplify                         Review changed code before committing
/checkpoint                       Document session milestone
git commit                        Commit (pre-commit hook reminds /simplify if skipped)
/borg-review                      Mid-session check: am I on track?
/borg-assimilate                  Am I done? Ship it.
/borg-link-up                     Flush session state to a checkpoint before stopping
/exit                             Stop hook sets status=idle + nudges if no checkpoint
Ctrl+Space >                      Next repository
```

## Configuration

```
~/.config/borg/config.zsh            Work/life boundaries, limits
~/.config/borg/registry.json         Session registry (auto-managed)
<repository>/.borg/checkpoints/   Checkpoints (via /borg-link-up)
```

### Config Variables

```
BORG_TMUX_SESSION=borg               tmux session name
BORG_ORCHESTRATOR_ROOT=~/dev         Workspace root; the Queen runs here
BORG_MAX_ACTIVE=3                    Capacity warning threshold
BORG_WORK_HOURS=09:00-18:00          Work hours (empty to disable)
BORG_WORK_DAYS=Mon,Tue,Wed,Thu,Fri   Work days
BORG_WORK_PROJECTS=repo1,repo2       Work repository names (comma-sep)
BORG_DEBUG=1                         Enable debug output
```

## File Layout

```
~/dev/borg-collective/
    borg.zsh                 Main orchestration CLI
    drone.zsh                Repository lifecycle CLI
    lib/*.zsh                Library modules
    hooks/*.sh               Claude Code hooks
    skills/*/SKILL.md        Skill definitions
    install.sh               Installer
    docs/                    Documentation

~/.config/borg/
    config.zsh               User configuration
    registry.json            Repository registry

<repository>/.borg/
    checkpoints/             User-authored session checkpoints

~/.claude/
    hooks/                   Symlinked hook scripts
    skills/                  Symlinked skill directories
    settings.json            Hook registrations
```
