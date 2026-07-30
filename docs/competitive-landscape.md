# Competitive Landscape
*Last reviewed: 2026-07-30*

Borg-collective exists in a fast-moving ecosystem. This document tracks how borg compares to
alternatives so we can make informed decisions about where to invest, what to deprecate, and
when to pivot.

**2026-Q3 refresh:** see the full research deliverable at
`docs/research/2026-07-30-competitive-refresh/analysis.md` for sourcing, methodology, and the
blind-reviewed recommendations. Headline: borg is not being out-competed, it is being *partially
absorbed by the platform* — Anthropic made the parallel-fan-out mechanism native (background-by-
default subagents, depth-3 nesting, 200-cap, shipped Jun-Jul 2026), which is convergence on borg's
nanoprobe approach, not a threat to it. Three pillars remain uncontested: the ADHD/boundary layer,
recon's checkpoint-vs-source contradiction reconciliation, and cairn's local opt-in knowledge graph.

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
| Multi-session orchestration | Yes | Conductor (10 sessions) | Yes | Background subagents (depth-3, 200-cap) |
| Session checkpoints | Yes (user-authored, per-project) | No | No | Beta agent-checkpointing (task-tree only) |
| Work/life boundaries | Yes | No | No | No |
| Shipping discipline | Yes (locked criteria) | Think→Ship phases | No | No |
| Cross-session persistence | Yes (checkpoints + cairn) | No | Campaign persistence (markdown) | No — Agent Teams persistence closed #33764 |
| Container-first design | Yes | No | No | No |
| Role-based skills | No | Yes (23 specialists) | No | No |
| Knowledge graph | Yes (cairn, optional, Postgres+pgvector) | No | No | Managed Agents Memory (cloud-only) |
| Persistent browser | No | Yes (Chromium, 100-200ms) | No | No |
| Plugin/skill ecosystem | 6 custom skills | Marketplace | Plugins | Official marketplace |

### Key competitors

**gstack** (125k★, up from 39k in April) — Still a persona/skill pack transforming Claude Code
into a 23-specialist virtual dev team, plus Conductor for parallel session orchestration. No
graph, no boundary layer. Different problem domain: "ship faster in one session" vs borg's
"manage multiple sessions sustainably." Complementary, not competing.

**Citadel** — Rebranded messaging to an "operating layer" (persistent memory, routing, cost
telemetry, worktree fleets). Closest philosophical overlap to borg's CLI plumbing layer, but its
memory is markdown-file based, not a pgvector graph.

**claude-mem** (89k★, up from 46k) — Automatic session capture + context injection, now
multi-harness — the highest handoff-overlap competitor. Borg deliberately keeps checkpoint prose
in the developer's hands so it actually gets read the next morning; a claude-mem bake-off is
worth running, but only as a *replacement* for borg's automatic under-layer with an explicit
SessionStart token budget, never as a fourth stacked injection alongside checkpoint + cairn +
presence context (see analysis.md Rec 5).

**CCPM** (Automazeio) — Project management using GitHub Issues + git worktrees. Stalled since
March 2026.

**Claude Code native (Jun-Jul 2026 changelog)** — Shipped background-by-default subagents,
depth-3 nesting, a 200-spawn cap, and a maturing `isolation:worktree`. This is a genuine partial
convergence on borg's nanoprobe fan-out mechanism — keep worktree hygiene, cairn logging, and
bounded-termination discipline, but re-test whether native background agents now work when the
orchestrator CWD is not a git repo before reducing investment further (analysis.md Rec 2).
Agent Teams cross-session persistence was formally closed "not planned" (issue #33764) — this
remains a durable gap borg fills and is unlikely to close natively.

**New entrants (2026-Q3, watch list, not yet adopted):** bernstein (deterministic/auditable
fan-out with signed lineage), maestro-flow and total-agent-memory (independent cairn-shaped
knowledge-graph entrants), Ruflo (31.1k★, unverified). See analysis.md §5 Track 2 for sourcing.

**i-have-adhd** (14.2k★, single-file output-style skill) — Orthogonal, not competitive. It shapes
*response verbosity* (action-first phrasing, numbered steps, capped lists, state recap); borg's
`adhd-guardrails` handles human *executive function and boundaries*. They compose. The
transferable insight is packaging: a zero-infra, one-file, forkable, agent-agnostic skill drove
its adoption — borg should extract `adhd-guardrails` into that same shape (analysis.md Rec 3).

---

## Decision Criteria

When to re-evaluate borg's components:

- **If Claude Code Agent Teams solve persistence** → evaluate deprecating borg/drone CLIs.
  Keep skills and hooks (they're the philosophy layer). Currently moot: #33764 closed "not planned."
- **If gstack adds sustainability features** (boundaries, persistent checkpoints) → evaluate
  adopting gstack + borg hooks as a lighter combination.
- **If native background subagents pass a direct re-test** (non-git-repo orchestrator CWD,
  `isolation:worktree` maturity) → reduce investment in the custom nanoprobe fan-out mechanism,
  but keep worktree hygiene, cairn logging, and bounded-termination as borg-level discipline
  regardless (analysis.md Rec 2).
- **If recon's shipped contradiction logic (`ebf866a`, #46 Track 2) proves deficient at scale** →
  evaluate Graphiti for the temporal-edge reconciliation; do not swap on a hypothesis alone
  (analysis.md Rec 4).
- **If a claude-mem bake-off is run** → it may only *replace* borg's automatic
  under-layer within a defined SessionStart token budget, never stack as a fourth injection
  alongside checkpoint + cairn + presence (analysis.md Rec 5).
- **Before any core-path dependency (Graphiti, claude-mem) goes load-bearing** → require a
  bus-factor/license/maintenance gate first (analysis.md Rec 6).
- **If a tool solves the complete stack better** → migrate philosophy into that tool's skill
  format. The ideas matter more than the implementation.
- **If borg's CLI plumbing becomes maintenance burden** → extract skills/hooks into a standalone
  plugin, deprecate the CLIs.

---

## Review Cadence

- **Quarterly**, or when a major tool release happens. Last full refresh: 2026-07-30
  (`docs/research/2026-07-30-competitive-refresh/analysis.md`, three parallel researcher tracks +
  one blind adversarial review). Next due: ~2026-10-30.
- Check these sources:
  - [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) — curated ecosystem
  - Claude Code changelog / release notes
  - gstack, claude-mem, Citadel releases
  - Anthropic blog / announcements about Agent Teams and Managed Agents Memory (watch for a
    cloud-only → CLI backport that would compete with cairn)
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
