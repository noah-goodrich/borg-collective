# The Borg Collective: An ADHD-Optimized Multi-Session Claude Code Command Center

*A narrative proposal for building a productivity tool that enforces mental health boundaries while maximizing output across parallel AI coding sessions.*

---

## 1. Introduction

Software development in 2026 has been transformed by AI coding agents. Tools like Claude Code, Cortex Code CLI, and their peers allow individual developers to run three, five, or even ten parallel coding sessions across projects. Boris Cherny, the creator of Claude Code, ships twenty to thirty pull requests per day by running five simultaneous git worktrees. Teams at incident.io reduced a two-hour JavaScript editor upgrade to ten minutes using four parallel Claude agents. The productivity ceiling has never been higher.

For developers with ADHD, this new paradigm presents a cruel paradox. The same executive function deficits that make organizing work across multiple streams nearly impossible also make parallel AI agents extraordinarily appealing. The dopamine hit of shipping code rapidly, the novelty of spinning up a new session for each idea, the hyperfocus potential of deep AI-assisted work sessions that stretch past midnight: these are not just productivity patterns. They are behavioral addiction vectors that clinical researchers have already begun documenting through the AI Addiction Scale (AIAS-21), a twenty-one-item instrument that measures compulsive use, craving, tolerance, and withdrawal from generative AI tools.

This document proposes The Borg Collective, a thin command-line coordination layer that sits on top of Claude Code's native capabilities and the existing skills ecosystem to solve a specific problem: how does a developer with ADHD manage a dozen parallel work streams across projects, tools, and contexts without losing their mind, their relationships, or their ability to actually ship anything?

The answer, supported by research from neuroscience, UX design for neurodivergent users, and the lived experience of ADHD developers in the Claude Code community, is that productivity tools must enforce boundaries as aggressively as they remove friction. Borg does both.

---

## 2. Goals

The Borg Collective will be measured against five objectives, each tied to a specific research-backed ADHD need:

- **Decision paralysis elimination.** The `borg next` command answers "what should I do?" with a single recommendation. Target: reduce context-switching decision time from minutes to seconds. Research basis: accountability check-ins increase goal achievement from twenty-five percent to ninety-five percent (Edge Foundation).

- **Cognitive load management.** No more than three to five active sessions visible at any time. Target: `borg ls` never shows more than five un-archived projects. Research basis: fMRI studies show ADHD brains work significantly harder during decision tasks and cannot filter irrelevant information (Relational Psychology Group).

- **Work/life boundary enforcement.** Work projects are dimmed and gated after hours. Target: switching to a work project at 10 PM requires explicit confirmation. Research basis: hyperfocus recovery is as important as breaking hyperfocus; without structured breaks, ADHD burnout cycles are inevitable (Dr. Sharon Saline, PMC).

- **Shipping discipline.** Every project in the registry can define acceptance criteria. Target: `borg status` shows "done when" for every pinned project. Research basis: without explicit exit criteria, Claude burns tokens refactoring perfectly functional code and adding unasked-for features (LogRocket/Ralph analysis).

- **Zero adoption friction.** The tool matches existing muscle memory. Target: the entire CLI follows the same `dev.sh` patterns Noah already uses daily. Research basis: ADHD research consistently shows that adoption friction kills tools; new habits require external scaffolding, not willpower (NIH/PMC).

---

## 3. Tenets

These principles are non-negotiable. They override any feature request, architectural decision, or scope expansion:

**External scaffolding, not willpower.** Every boundary must be enforced by the system, not remembered by the developer. If it requires a human to "just remember to" do something, it will fail for ADHD users. This is not a preference; it is a neurological constraint documented across hundreds of studies of executive function in ADHD.

**Compose, do not rebuild.** Claude Code already provides worktrees, task tracking, agent teams, channels, skills, hooks, context management, and a desktop app. Borg builds only what these native features do not provide: tmux window coordination, work/life time boundaries, cognitive load guardrails, and a "what should I do next?" recommendation engine. Anything Claude Code does natively, borg delegates to it.

**Skills are the portable unit of discipline.** CLAUDE.md is tool-specific. Skills are portable across Claude Code and Cortex Code CLI. Any workflow pattern worth encoding goes into a skill, not a config file. This is a direct application of Boris Cherny's insight that "if you do something more than once a day, make it a skill."

**Speed bumps, not walls.** Boundaries are implemented as one-extra-keystroke confirmations, not hard blocks. A developer who wants to work on a work project at midnight can do so by pressing "y" instead of just Enter. The friction is intentional but surmountable. Hard blocks get disabled; speed bumps get internalized.

**Ship, then improve.** Phase 0 is the only mandatory phase. If borg never advances past "scan, list, switch," that is a success. The irony of spending months perfecting a shipping-discipline tool that never ships is the single most likely failure mode of this project.

---

## 4. State of the Business

The Borg Collective exists today as approximately four hundred lines of zsh source code across eight files, with three known bugs that prevent any command from running successfully. All code has been written; nothing has been tested. The project was created during a single intensive session and has not yet produced a working `borg ls` command.

The codebase follows a compose-first architecture that remains sound. Two existing npm packages, `claude-code-monitor` for real-time status detection and `@tradchenko/claude-sessions` for AI-powered session summaries, provide the session intelligence layer. Borg adds the coordination layer: a JSON registry at `~/.config/borg/registry.json` that tracks project metadata, tmux window mappings, session status, and extractive summaries generated by a Python script that parses JSONL transcripts without LLM calls.

Three Claude Code hooks have been written: a Stop hook that marks sessions idle and extracts summaries, a Notification hook that marks sessions as waiting for input, and a SessionStart hook (not yet created) that would mark sessions as active. The hooks are designed to fire inside devcontainers where Claude Code runs, but the registry directory (`~/.config/borg/`) is not currently volume-mounted into any container, meaning hooks fire but their registry updates are written into the container's ephemeral filesystem and lost on rebuild.

The project's development context is complex. Noah runs Claude Code inside Docker Compose devcontainers across five projects, with `~/.claude/` bind-mounted from the macOS host into each container. He also uses Snowflake's Cortex Code CLI (CoCo) for data engineering work, which stores its configuration in `~/.snowflake/cortex/` and uses Podman rather than Docker for sandboxing. Skills are fully portable between Claude Code and CoCo, sharing the identical SKILL.md format, but hooks and session tracking use different directory structures.

The Claude Code ecosystem has matured significantly since borg's initial design. The plugin marketplace now hosts over twenty-three hundred skills. Boris Cherny's complete fifty-seven-tip framework has been encoded as an installable skill. Scope Guard, a community skill that prevents scope creep by cross-referencing requests against current feature boundaries, is available on MCPMarket. Claude Code itself now provides native features for task management (TaskCreate/TaskUpdate), agent teams for multi-session coordination, channels for push notifications via Telegram and Discord, and git worktrees for automatic session isolation. The original borg plan was written before many of these features existed, and it duplicates several of them.

The gap analysis identified seven areas where the current plan gets things wrong, the most critical being the complete absence of work/life boundary enforcement, session capacity limits, or any mechanism to prevent the tool from becoming an enabler of the very overwhelm it was designed to address.

---

## 5. Lessons Learned

The first lesson came from the gap analysis itself. The original borg plan contained a Phase 3 that listed five features: a live dashboard, a resume command, a cost tracker, a log timeline, and LLM-refined summaries. Every single item either duplicates an existing tool (`borg cost` is what `cs` already provides, `borg log` is `cat ~/.claude/session-log.md`, `borg watch` is `watch -n5 borg ls`) or contradicts a design decision (LLM summaries versus the deliberate choice to use fast extractive summaries in hooks). Phase 3 was scope creep disguised as a roadmap. It has been deleted.

The second lesson came from the ADHD research. The initial assumption was that borg's value lay in making it easier to find and switch between sessions. The research revealed the opposite: making session-switching frictionless without adding boundaries is dangerous for ADHD users. Adam Drake's article on Claude Code Channels articulated this precisely: "The friction we had before to start a project was actually good. It filtered trash ideas." Every removed friction point must be paired with an added boundary, or the tool becomes an addiction enabler. The AI Addiction Scale (AIAS-21), published in 2025, measures exactly the behavioral patterns that an unguarded multi-session manager could encourage.

The third lesson came from the skills ecosystem research. The original plan treated Boris Cherny's framework and the community skills library as background reading. Noah's feedback was direct: "Nothing in your plan mentions installing the skills and tools that have been specifically released in response to Boris's writing." This was a fundamental error. Skills are not reference material; they are tools to install. The Scope Guard skill prevents scope creep. The `/simplify` command runs three parallel review agents. The `/checkpoint` command creates session summaries. Building custom versions of these capabilities when production-ready implementations exist is the definition of building against the grain of Claude Code rather than with it.

The fourth lesson emerged from the devcontainer analysis. Noah's workflow involves running Claude Code inside Docker Compose containers with `~/.claude/` bind-mounted from the host. This means skills and hooks propagate automatically from host to container, but the borg registry directory (`~/.config/borg/`) was not mounted, creating a silent failure: hooks fire inside containers, attempt to update the registry, and write to a path that does not exist on the host filesystem. The fix is a single line in each devcontainer's `docker-compose.yml`, but the failure was invisible because the hooks exit 0 regardless of whether the registry update succeeds.

The fifth lesson is about the Cortex Code CLI. CoCo is not a fork of Claude Code; it is a separate Snowflake-native product with its own configuration directory, session tracking, and hook system. However, skills are one hundred percent portable between the two tools. This means the portable unit of discipline is the skill, not the CLAUDE.md file, because CLAUDE.md is tool-specific while skills transcend tools. Any workflow pattern worth encoding should be a skill first, a CLAUDE.md directive second.

---

## 6. Strategic Priorities

The revised plan organizes work into three phases with explicit exit criteria, a list of explicitly deferred work, and forward-compatibility constraints for devcontainers and CoCo.

**Phase 0: Make it work and install skills.** This is the only mandatory phase. It has a single exit criterion: `borg scan && borg ls` produces correct output, `borg switch` lands in the right tmux window, and the skills ecosystem is installed. The estimated effort is one session of approximately sixty minutes.

The work begins with fixing the PATH bug in `lib/claude.zsh`. The function `borg_claude_scan_session_log()` calls `awk` and `sort` by name, which resolve correctly in interactive zsh but fail in non-interactive subshells because the PATH does not include `/usr/bin/`. The fix is to use absolute paths (`/usr/bin/awk`, `/usr/bin/sort`) or rewrite the function using zsh builtins. This bug was confirmed via `zsh -x borg.zsh scan` tracing and is the sole blocker for the first successful run.

The second fix addresses the fragile fzf preview in `cmd_switch`. The current implementation sources three library files inline within the preview command string, which is error-prone and listed as a known bug. The replacement is straightforward: `--preview "borg status {1}"`. The borg command is already in PATH, and `cmd_status` already produces formatted output suitable for a preview pane.

The third change merges `borg focus` into `borg switch`. Both commands switch to a project's tmux window. The distinction is that `switch` opens an fzf picker while `focus` takes a direct argument. When `borg switch` receives an argument that matches exactly one project, it should skip fzf and switch directly. This is approximately five lines of conditional logic.

The fourth addition is a SessionStart hook (`hooks/borg-start.sh`) that sets `status=active` when a Claude Code session begins. Without this hook, the status lifecycle is incomplete: projects go from `unknown` or `idle` directly to `waiting` (when Claude finishes a turn), skipping `active`. The `active` status is documented in the README but never actually set by any existing hook.

The fifth task installs the skills ecosystem. This includes adding the `alirezarezvani/claude-skills` marketplace plugin (which provides Boris Cherny's framework, engineering skills, and Scope Guard), creating a custom `adhd-guardrails` skill at `~/.claude/skills/adhd-guardrails/SKILL.md` based on Zack Proser's compassionate constraints framework, and creating a `checkpoint-enhanced` skill that produces session summaries with explicit next-session entry points.

Finally, `install.sh` is updated to include skill installation and to document the devcontainer volume mount requirement for `~/.config/borg/`.

**Phase 1: Boundaries and guidance.** This phase adds the ADHD-specific features that distinguish borg from a generic session manager. The exit criteria are: `borg next` returns a single recommendation, work projects are dimmed after 6 PM, switching to a work project at 11 PM requires confirmation, and a capacity warning appears when more than three sessions are active or waiting.

The implementation begins with a configuration file at `~/.config/borg/config.zsh` that defines work hours, work days, work project patterns, personal project patterns, maximum active sessions, and session duration warning thresholds. This file is sourced by `borg.zsh` after the library files.

The `cmd_next` function implements the "what should I do?" recommendation engine. Its logic is intentionally simple: return the single project with the most recent `waiting` status. If nothing is waiting, return the most recently active project. If the user has set pin flags, prefer pinned projects. The output includes the project name, how long it has been waiting, the most recent summary, and a `borg switch` command the user can copy-paste. This command is the "body doubling" principle in software form: the tool tells Noah what to do instead of presenting him with a list that triggers decision paralysis.

Work/life dimming modifies `cmd_ls` to use existing ANSI `$DIM` escape codes on projects that are out of context. During work hours, personal projects are dimmed. After work hours, work projects are dimmed. The dimming is visual only; dimmed projects are still shown and can be switched to. The time-boundary prompt in `cmd_switch` goes further: switching to a work project outside work hours shows "It's 10:30 PM. cairn is a work project. Switch anyway? [y/N]" with a default of No. Pressing Enter without typing does not switch. This is the external scaffolding principle: one keystroke of friction that willpower alone cannot provide.

The capacity warning in `cmd_ls` counts projects with status `active` or `waiting` and displays a warning line when the count exceeds `BORG_MAX_ACTIVE` (default three). The `cmd_add` command requires `--force` when adding a project that would exceed the limit. These are soft guardrails, not hard blocks.

Project pinning (`borg pin`, `borg unpin`) adds a boolean `pinned` field to registry entries. Pinned projects sort first in `borg ls` output and are preferred by `borg next`. This is the simplest possible prioritization structure: a binary flag, not a priority number.

The optional `goal` and `done_when` fields in the registry support shipping discipline. When set, `borg status` displays them, and `borg next` can incorporate them into recommendations. These fields are the "acceptance criteria as completion gates" pattern from the Prompt Contracts framework: without explicit "done" criteria, ADHD perfectionism drives infinite refinement.

**Phase 2: Cognitive load management.** This phase prevents the project list from growing indefinitely. The exit criteria are: after one week of daily use, `borg ls` shows only the three to five projects Noah is actively working on.

Staleness detection tags projects that have been idle for more than forty-eight hours with a `[stale]` indicator in `borg ls` output. The `borg tidy` command interactively prompts to archive stale projects, setting their status to `archived`. Archived projects are hidden from default `borg ls` output but shown with `--all`. No data is deleted; archiving is a display filter, not a destructive operation.

**Explicitly deferred work.** The following will not be built unless two or more weeks of daily use reveals a repeated, specific need: `borg watch` (use `watch -n5 borg ls`), `borg resume` (use `borg switch` followed by `claude --resume`), `borg cost` (use `cs`), `borg log` (use `cat ~/.claude/session-log.md`), LLM-refined summaries, Claude Desktop integration in `cmd_ls`/`cmd_scan`, Oura Ring or wearable integration, voice capture integration, and Obsidian vault integration.

**Forward compatibility.** Two constraints ensure the architecture does not box in future work. First, devcontainers: the installer documents the requirement to add `~/.config/borg:/home/vscode/.config/borg:cached` to devcontainer volume mounts, and hooks are tested to verify correct project name resolution from inside containers. Second, Cortex Code CLI: the registry uses a string field for source (not an enum), session discovery uses a variable for the Claude projects directory (not a hardcoded path), and a future `lib/coco.zsh` can follow the identical pattern of `lib/claude.zsh` with a different root directory.

---

## Appendix A: Research Citations

See `docs/research.md` for the complete citation index with URLs, organized by domain: ADHD and executive function (eleven sources), UX for neurodivergent users (three sources), shipping discipline (seven sources), Claude Code best practices (five sources), AI addiction risk (four sources), ADHD-specific Claude Code frameworks (five sources), skills ecosystem (four sources), devcontainers (six sources), and Cortex Code CLI (six sources).

## Appendix B: Architecture Diagrams

See `docs/architecture.md` for the complete system architecture, data flow diagrams, hook lifecycle, and skills integration map.

## Appendix C: Quick Reference

See `docs/cheatsheet.md` for the single-page command reference card.

## Appendix D: Getting Started

See `docs/quickstart.md` for the step-by-step installation and first-run guide.
