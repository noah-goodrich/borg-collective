# Competitive Landscape
*Last reviewed: 2026-04-01*

Borg-collective exists in a fast-moving ecosystem. This document tracks how borg compares to
alternatives so we can make informed decisions about where to invest, what to deprecate, and
when to pivot.

---

## Borg's Three Layers (ordered by longevity)

1. **Philosophy** (longest-lived): Boundaries, shipping discipline, cognitive load awareness,
   "automated beats discipline." Survives regardless of platform changes.
2. **Skills + hooks** (medium-lived): borg-plan, borg-assimilate, adhd-guardrails, session-lifecycle
   hooks (link-down / link-up). The automation that replaces discipline. Cheap to adapt if APIs
   change.
3. **CLI plumbing** (shortest-lived): borg/drone CLIs, registry JSON, tmux automation. Useful
   now but may be absorbed by Claude Code's native features.

**Investment rule**: Prioritize layers 1-2. Maintain layer 3, don't expand it.

---

## Feature Comparison

| Feature | Borg | gstack | Citadel | Claude Code Native |
|---------|------|--------|---------|-------------------|
| Multi-session orchestration | Yes | Conductor (10 sessions) | Yes | Agent Teams (experimental) |
| Session checkpoints | Yes (user-authored, per-project) | No | No | No |
| Work/life boundaries | Yes | No | No | No |
| Shipping discipline | Yes (locked criteria) | Think→Ship phases | No | No |
| Cross-session persistence | Yes (checkpoints + cairn) | No | Campaign persistence | No (wiped on restart) |
| Container-first design | Yes | No | No | No |
| Role-based skills | No | Yes (23 specialists) | No | No |
| Knowledge graph | Yes (cairn, optional) | No | No | No |
| Persistent browser | No | Yes (Chromium, 100-200ms) | No | No |
| Plugin/skill ecosystem | 6 custom skills | Marketplace | Plugins | Official marketplace |

### Key competitors

**gstack** (Garry Tan, 39k+ stars) — Role-based skills transforming Claude Code into a
23-specialist virtual dev team. Optimized for single-session velocity (10k+ LOC/day). Includes
Conductor for parallel session orchestration. Different problem domain: "ship faster in one
session" vs borg's "manage multiple sessions sustainably." Complementary, not competing.

**Citadel** — Agent orchestration harness with 4-tier routing, campaign persistence, parallel
agents in worktrees, discovery relay, and lifecycle hooks. Closest architectural competitor to
borg's CLI plumbing layer.

**Claude-Mem** — Automatic session capture + context injection. Similar goal to borg's checkpoint
system but fully automatic (uses compression) rather than user-authored. Borg deliberately keeps
the checkpoint prose in the developer's hands so it actually gets read the next morning.

**CCPM** (Automazeio) — Project management using GitHub Issues + git worktrees for parallel
agent execution.

**Claude Code Agent Teams** (native, experimental) — Multi-session coordination with shared task
lists and inter-agent messaging. Key gap: state wiped on restart (issue #33764). No checkpoints,
no boundaries, no cross-session persistence.

---

## Decision Criteria

When to re-evaluate borg's components:

- **If Claude Code Agent Teams solve persistence** → evaluate deprecating borg/drone CLIs.
  Keep skills and hooks (they're the philosophy layer).
- **If gstack adds sustainability features** (boundaries, persistent checkpoints) → evaluate
  adopting gstack + borg hooks as a lighter combination.
- **If a tool solves the complete stack better** → migrate philosophy into that tool's skill
  format. The ideas matter more than the implementation.
- **If borg's CLI plumbing becomes maintenance burden** → extract skills/hooks into a standalone
  plugin, deprecate the CLIs.

---

## Review Cadence

- **Quarterly**, or when a major tool release happens
- Check these sources:
  - [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) — curated ecosystem
  - Claude Code changelog / release notes
  - gstack releases
  - Anthropic blog / announcements about Agent Teams
- Update this document with findings

---

## Design Philosophy

Borg optimizes for the 90%, not the 1%. Most AI tooling presents power-user results (20-30
PRs/day, 10k LOC/day) as typical. Borg targets developers who need:

- Fewer decisions, not more parallel streams
- Clear guardrails that prevent the tool from running away
- Sustainability over velocity
- Trust that the tool won't break things or waste their time

If a competitor serves this audience better, we should adopt it. No sunk cost attachment.
