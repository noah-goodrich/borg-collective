# Skills Guide

This guide explains every skill that Borg installs, how to use each one, and why it exists.

---

## What Are Skills?

Skills are reusable instruction files (SKILL.md with YAML frontmatter) that extend Claude Code's
behavior. They're the portable unit of discipline — they work identically across Claude Code and Cortex
Code CLI, propagate automatically via `~/.claude/` bind mount into devcontainers, and encode patterns
you'd otherwise have to remember and re-explain every session.

### How Skills Work

1. **Discovery**: Claude reads skill descriptions on startup (~100 tokens each)
2. **Activation**: Automatic (always-on) or manual (you type `/skill-name`)
3. **Loading**: Full instructions load on activation (~2,000-5,000 tokens)

### Scope

- **User scope**: `~/.claude/skills/` — available in all sessions
- **Project scope**: `.claude/skills/` in project root — available in that project only
- **Devcontainer scope**: Propagates via `~/.claude/` bind mount

---

## Borg Skills (Custom)

### /borg-plan — Project Planning

**Activation**: Manual (`/borg-plan`)

Structured project planning where Claude does the thinking and you validate. Claude reads the codebase,
git history, and existing docs, then proposes:

1. **Objective** — What we're building (Claude proposes, you confirm or adjust)
2. **Acceptance criteria** — Specific, testable criteria including things you might miss (tests, docs,
   error cases, regressions)
3. **Verification strategy** — For each criterion, how to verify it (commands, tests, checks)
4. **Scope boundaries** — What we're explicitly NOT building
5. **Ship definition** — What "shipped" literally means (PR merged? deployed? documented?)
6. **Timeline** — Estimated effort with reasoning
7. **Risks** — What could go wrong, flagged by Claude based on code analysis

Output: `PROJECT_PLAN.md` in the project root. Once written, criteria are **locked** — scope changes
require explicit confirmation. This prevents infinite refinement and scope creep.

**Why it exists**: Without explicit acceptance criteria, work expands to fill available time. The plan
gives both you and Claude a clear stopping point.

### /borg-assimilate — Shipping Checklist + Execution

**Activation**: Manual (`/borg-assimilate`)

Evaluates current state against PROJECT_PLAN.md with evidence, runs a Collective review, then
executes shipping:

- For each criterion: met / not met / partially met, with proof (file exists, test passes, command
  output)
- Runs verification commands itself — doesn't ask you to
- Invokes `/borg-collective-review` to stress-test the decision to ship
- Three verdicts:
  - **Ready to ship** — walks you through the shipping steps (merge PR, archive plan) with
    confirmation
  - **Not ready** — specific remaining items and estimated effort
  - **Done but still working** — "This meets all criteria. Ship it. Are you polishing or is there a
    real problem?"

**Why it exists**: The hardest part of shipping is knowing when to stop. This skill enforces the
contract from `/borg-plan` and closes the loop by actually shipping.

### /borg-collective-review — Adversarial Multi-Persona Review

**Activation**: Manual (`/borg-collective-review`) or invoked by `/borg-plan` and
`/borg-assimilate`

Runs an adversarial design review: six core personas plus one rotating specialist debate a plan or
shipping decision. Surfaces risks, trade-offs, and counter-arguments before you commit.

**Why it exists**: A single-LLM "looks fine" is not a review. The Collective forces multiple
viewpoints into the conversation.

### /borg-review — Mid-Session Diagnostic

**Activation**: Manual (`/borg-review`)

Performs a structured diagnostic of the current session. Does the analysis itself, then presents
findings:

- **Progress check**: Criteria met / in progress / not started / blocked
- **Scope creep detection**: Compares actual work to plan, flags drift
- **Loop detection**: Same error 3+ times, undo-redo patterns, yak shaving (3 levels deep from
  original task), perfectionism spiral (criteria met but still refining)
- **Verification gaps**: Criteria completed but not verified
- **Energy/momentum**: Detects declining message quality, suggests breaks or simpler tasks

Ends with **ONE recommendation** — not a menu. One action. Because multiple choices cause decision
paralysis.

**Why it exists**: When you're deep in a session, you can't see the forest for the trees. This skill
is the outside perspective.

### /borg-link-up — Flush Session State to a Checkpoint

**Activation**: Manual (`/borg-link-up`)

Writes a structured checkpoint from the live session to
`<project>/.borg/checkpoints/<YYYY-MM-DD-HHMM>.md`. Five sections:

- **Goal**: What this session was trying to accomplish
- **Accomplished**: Concrete outcomes (files, commits, decisions)
- **Ready to commit**: Staged or unstaged changes that should be committed
- **Blockers**: Anything unresolved (errors, open questions, waiting-on)
- **Next session**: Specific first action for when you pick this back up

The Stop hook (`borg-link-up.sh`) does NOT auto-run this skill — there's no automatic LLM call at
session end. If you stop without checkpointing, the Stop hook prints a one-line nudge reminding
you. The next session's SessionStart hook (`borg-link-down.sh`) reads the newest checkpoint from
that directory and injects it as `additionalContext`.

Checkpoints are user-authored (you own the prose), stored in-repo, and portable across machines
via git if you want. No hidden global summaries, no per-session LLM spend.

**Why it exists**: Session context is ephemeral. A short, deliberate checkpoint at the end of a
session is worth more than an auto-generated summary you don't read.

### /borg-link — Project Intelligence

**Activation**: Manual (`/borg-link`, or invoked from `borg link` / `drone link` on the CLI)

Consolidated project intelligence. No arguments gives an overview across all registered projects
(directives, recent ships, last checkpoint). With a project name, gives a deep dive: registry
entry, latest checkpoint, active plan, directive backlog, assimilated history, and cairn knowledge
if available. Works on the host and inside a drone container by reading the bind-mounted files
directly.

**Why it exists**: You forget what every project is doing. This skill rebuilds the picture without
round-tripping through multiple commands.

### /adhd-guardrails — Cognitive Load Guardrails

**Activation**: Automatic (always active)

Applies constraints to every interaction:

- **Scope discipline**: Names scope expansion when it happens. Suggests deferring to future sessions.
- **Perfectionism prevention**: "This meets the acceptance criteria. Ship it?" after work is done.
  Does NOT suggest additional improvements unless asked.
- **Energy and focus**: Suggests breaks after 2+ hours. Suggests simpler tasks when energy seems low.
- **Communication**: No shame language ("you should have", "obviously", "simply"). Focuses on next
  action, not what went wrong. Keeps explanations concise.

**Why it exists**: These are the constraints that prevent gradual burnout from sustained AI-assisted
development. They apply to everyone, not just neurodivergent developers.

---

## Marketplace Skills

Install with `/plugin marketplace add alirezarezvani/claude-skills` in any Claude Code session.

### Boris Cherny's 57 Tips

Complete Claude Code workflow framework from the creator of Claude Code. Covers:
- Parallel execution strategies (worktrees, multiple sessions)
- Plan Mode discipline (Shift+Tab)
- CLAUDE.md best practices
- Verification loops for quality
- Model selection
- Skills and hooks
- MCP integrations

### Scope Guard

Automatically cross-references requests against current feature scope. Flags scope creep before Claude
starts building something outside the defined boundaries. Complements `/borg-plan`'s locked criteria.

### Engineering Skills Bundle

26+ skills covering architecture, QA, DevOps, security auditing, CI/CD pipeline building, database
design, and more.

---

## Built-in Claude Code Skills

These come with Claude Code — no installation needed:

| Skill | What it does | When to use |
|-------|-------------|-------------|
| `/simplify` | Three parallel agents review code (efficiency, correctness, maintainability) | After implementation, before PR |
| `/checkpoint` | Quick 3-5 bullet summary | Before breaks |
| `/batch` | Parallelizes large changes into 5-30 units | Large-scale refactors |
| `/compact` | Compresses conversation context | When context gets long |
| `/clear` | Resets context completely | Fresh start |

---

## Creating Your Own Skills

Skills are just markdown files with YAML frontmatter:

```markdown
---
name: my-skill
description: >
  One-line description that Claude reads on startup. Be specific about
  when to use this skill — Claude uses the description to decide relevance.
user-invocable: true
---

# Skill Title

Instructions for Claude when this skill is activated.
```

**Key flags:**
- `user-invocable: true` — Developer can trigger with `/my-skill`
- `user-invocable: false` — Automatic, Claude activates based on description
- `disable-model-invocation: true` — Skill provides instructions only, no API calls

**Tips for effective skills:**
- Specific descriptions → Claude activates at the right time
- Include "Done when" criteria → Clear stopping point
- Encode patterns you repeat daily → Boris's insight: "If you do it more than once, make it a skill"
- Test with both Claude Code and Cortex Code CLI if portability matters
