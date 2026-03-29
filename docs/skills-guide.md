# Skills Guide

This guide explains every skill that The Borg Collective installs, how to use each one, and why it exists. No prior knowledge of Claude Code skills is assumed.

---

## What Are Skills?

Skills are reusable instruction files that extend Claude Code's capabilities. Each skill is a markdown file (`SKILL.md`) with YAML frontmatter that tells Claude when to activate and what to do. Skills are the portable unit of discipline: they work identically in Claude Code and Cortex Code CLI, and they propagate automatically to devcontainers via the `~/.claude/` bind mount.

Skills solve a specific problem for ADHD developers: instead of remembering to follow a process every time, you encode the process in a skill and it activates automatically or on demand.

---

## How Skills Work

### Discovery

When a Claude Code session starts, Claude reads the description of every installed skill (~100 tokens each). It uses these descriptions to decide which skills are relevant to the current task.

### Activation

Skills activate in two ways:
- **Automatic:** Claude detects that a skill's description matches the current context and loads it
- **Manual:** You type `/skill-name` in the Claude Code prompt

### Loading

When activated, the full skill instructions are loaded into Claude's context (~5,000 tokens). This is called "progressive disclosure" — keep startup fast, load details on demand.

### Scope

- **User scope** (`~/.claude/skills/`): Available in all your projects, on all machines where `~/.claude/` is present
- **Project scope** (`.claude/skills/`): Available only in that project, shared with team via git
- **Devcontainer scope**: Skills in `~/.claude/skills/` propagate automatically when `~/.claude/` is bind-mounted

---

## Marketplace Skills

### Installation

```bash
# In any Claude Code session:
/plugin marketplace add alirezarezvani/claude-skills
```

This adds the `alirezarezvani/claude-skills` repository to your plugin sources, giving you access to 205+ production-ready skills across nine domains.

### Boris Cherny's 57 Tips

**What it does:** Encodes the complete Claude Code workflow framework from Boris Cherny, the creator of Claude Code. Covers parallel execution, plan mode discipline, CLAUDE.md best practices, verification loops, model selection, skills and slash commands, hooks, MCP integrations, and advanced customization.

**Why it matters for ADHD:** Externalizes "how to use Claude Code well" so you don't have to remember the framework. Claude automatically applies the patterns when relevant.

**Key patterns encoded:**
- Run 3-5 parallel worktrees simultaneously (biggest productivity multiplier)
- Start complex tasks in Plan Mode (Shift+Tab), refine until solid, then auto-accept
- Invest in CLAUDE.md as living documentation of patterns and corrections
- Give Claude a way to verify its work (tests, screenshots, expected outputs) for 2-3x quality
- Use `/simplify` after implementation for code quality review

### Engineering Skills Bundle

**Install:** `/plugin install engineering-skills@claude-code-skills`

**What it does:** 26 engineering skills covering architecture, QA, DevOps, and specialized areas. Plus 25 POWERFUL-tier skills including RAG architect, database designer, security auditor, and CI/CD pipeline builder.

**Why it matters for ADHD:** Removes decision fatigue about "how should I approach this?" Each skill encodes expert-level patterns for specific engineering tasks.

### Scope Guard

**What it does:** Automatically cross-references requests against the current feature scope. When it detects scope creep — a request that goes beyond the original task — it flags it explicitly before proceeding.

**Why it matters for ADHD:** ADHD perfectionism makes scope creep the number one shipping killer. Without external enforcement, "just one more feature" loops indefinitely. Scope Guard provides the friction that willpower cannot.

**Source:** Available via the `alirezarezvani/claude-skills` marketplace or directly from [MCPMarket](https://mcpmarket.com/tools/skills/scope-guard-1).

---

## Built-in Skills

These come with Claude Code and require no installation.

### /simplify

**What it does:** Runs three parallel review agents that examine your code for:
1. Efficiency — Can anything be simplified or deduplicated?
2. Correctness — Are there bugs, edge cases, or logic errors?
3. Maintainability — Does the code follow project conventions?

**When to use:** After completing any implementation, before committing. This is your "is it good enough?" declaration.

**Why it matters for ADHD:** Automates the quality check that ADHD perfectionists agonize over. Instead of wondering if the code is good enough, you run `/simplify` and it tells you.

### /checkpoint

**What it does:** Summarizes the work done in the current session in 3-5 bullets.

**When to use:** Before ending a session, before a break, or any time you want to capture your current state.

**Why it matters for ADHD:** Creates the "next session entry point" that eliminates the 23-minute context-rebuild cost when you return to a project.

### /batch

**What it does:** Parallelizes large-scale changes by decomposing the work into 5-30 independent units and spawning isolated subagents for each.

**When to use:** Migrations, pattern enforcement across many files, large refactors.

**Why it matters for ADHD:** Reduces cognitive load on large tasks by handling orchestration automatically.

### /compact

**What it does:** Compresses the current conversation context, preserving critical information while freeing space.

**When to use:** When context feels bloated, when `/context` shows high usage, or when Claude starts forgetting earlier instructions.

**Why it matters for ADHD:** Context bloat causes Claude to lose track of important details, leading to frustrating "almost right but not quite" outputs. Proactive compaction prevents this.

### /clear

**What it does:** Resets the conversation context completely.

**When to use:** Between unrelated tasks in the same session.

**Why it matters for ADHD:** Prevents the "kitchen sink session" anti-pattern where bug fixes, database migrations, and CSS issues all bleed into one context.

### /rewind

**What it does:** Navigates to a previous checkpoint in the conversation and optionally summarizes everything since that point.

**When to use:** When you went down a wrong path and want to start over from a known-good state.

**Why it matters for ADHD:** Provides a safe undo mechanism without git complexity.

---

## Custom Skills (Created by Borg Installer)

### /adhd-guardrails

**Location:** `~/.claude/skills/adhd-guardrails/SKILL.md`

**Activation:** Automatic (always loaded, `user-invocable: false`)

**What it does:** Enforces compassionate constraints based on Zack Proser's framework for neurodivergent developers:

- **Pushes back on perfectionism.** When it detects iterative polishing beyond the original scope, it says "Good enough to ship" rather than allowing infinite refinement.
- **Suggests breaks after 2 hours.** Monitors session duration and prompts for a break when hyperfocus may be causing neglect of physical needs.
- **Flags scope expansion.** When a request goes beyond the original task, it names this explicitly: "This is expanding the scope beyond X. Continue?"
- **Uses shame-free language.** Values effort over outcomes. Never uses guilt, pressure, or "you should have" framing.
- **Suggests simpler tasks when energy seems low.** If responses become shorter, less specific, or less engaged, it recommends lighter work.
- **Includes clear "done" criteria in every plan.** Every plan has explicit acceptance criteria so you know when to stop.

**Why it exists:** Research shows that AI body doubling with boundaries measurably improves sustained attention and task completion for ADHD/autistic developers (ArXiv 2025, Zack Proser). The skill encodes the boundaries that willpower alone cannot provide.

**SKILL.md content:**
```yaml
---
name: adhd-guardrails
description: Enforce compassionate constraints for ADHD developer
user-invocable: false
---
When working with this developer:
- Push back on perfectionism. "Good enough to ship" > "perfect but never released"
- If the session exceeds 2 hours, suggest a break
- If scope expands beyond original request, flag it explicitly
- No shame language. Value effort over outcomes
- When energy seems low, suggest simpler tasks
- Include clear "done" criteria in every plan
```

### /checkpoint-enhanced

**Location:** `~/.claude/skills/checkpoint-enhanced/SKILL.md`

**Activation:** Manual only (invoke with `/checkpoint-enhanced`)

**What it does:** Produces a structured session summary with five components:

1. **What was the goal?** — The original intent of the session
2. **What was accomplished?** — Concrete deliverables completed
3. **What's ready to commit?** — Files changed that can be committed now
4. **What blockers remain?** — Issues that prevented completion
5. **What should the next session focus on?** — Explicit entry point for resuming work

**Why it exists:** The built-in `/checkpoint` provides a summary, but it does not explicitly define the next-session entry point. For ADHD developers, the hardest moment is returning to a project after time away. The "where was I?" paralysis can burn 15-30 minutes (per Wake Forest context-switching research). This skill eliminates that by providing a concrete starting point.

**SKILL.md content:**
```yaml
---
name: checkpoint-enhanced
description: Summarize session work and define next-session entry point
disable-model-invocation: true
---
Summarize this session:
1. What was the goal?
2. What was accomplished?
3. What's ready to commit?
4. What blockers remain?
5. What should the next session focus on?
```

---

## Creating Your Own Skills

### File Structure

```
~/.claude/skills/my-skill/
    SKILL.md            Required: instructions with YAML frontmatter
    REFERENCE.md        Optional: detailed docs loaded on demand
    scripts/            Optional: executable scripts
```

### SKILL.md Format

```yaml
---
name: my-skill
description: When and why to use this skill
disable-model-invocation: true    # true = only user can invoke
user-invocable: false             # false = only Claude can invoke (hidden)
allowed-tools: Read, Grep, Bash   # Optional: restrict tool access
context: fork                     # Optional: run in isolated subagent
---

Your instructions here in markdown...
```

### Tips for ADHD-Friendly Skills

- Keep descriptions specific so Claude knows exactly when to activate
- Include clear "done" criteria in skill instructions
- Use `disable-model-invocation: true` for skills you want to control manually
- Use `user-invocable: false` for guardrails that should always be active
- Test skills with the eval framework before relying on them

### Portability

Skills placed in `~/.claude/skills/` work in:
- Claude Code on the host
- Claude Code in any devcontainer that bind-mounts `~/.claude/`
- Cortex Code CLI (reads the same SKILL.md format)

To make a skill available in CoCo specifically, symlink or copy it to `~/.snowflake/cortex/skills/`.
