# Proposed addition to ~/.claude/CLAUDE.md

Apply via the `update-config` skill (or hand-edit). Insert as a new subsection under "## Subagent Rules",
directly after the existing bullet list. Rationale: the current Subagent Rules govern the `Agent` tool; nothing
governs the `Workflow` tool's `agent()` calls, which inherit the Fable 5 session model and caused repeated
limit trips (see 00-cost-and-routing-audit.md).

---

## Workflow model routing (cost guardrail)

The `Workflow` tool's `agent(prompt, opts)` inherits the **session model** (currently Fable 5, the most
expensive tier) unless `opts.model` is set. An unqualified fan-out is the fastest way to burn the allotment.

- **Every `agent()` call MUST pass an explicit `model:`.** Treat a missing `model:` as a bug unless the stage
  is genuinely open-ended reasoning that cannot be briefed.
  - `model: 'haiku', effort: 'low'` — mechanical: extract/reformat, run tests, grep, rote edits, read-only
    inventory.
  - `model: 'sonnet'` — analysis, synthesis, writing a draft, from-zero web research.
  - `model: 'sonnet', effort: 'high'` — blind review / verification gate that guards a deliverable.
  - omit `model:` (inherit) — only the one or two stages per workflow that truly cannot be briefed.
- **Prefer `agentType:` for search/locate stages** (`agent(p, { agentType: 'borg-scout' })`) so both the model
  and the system prompt come from the borg specialist.
- **Gate stages want Sonnet-high, not the top tier** — rigor comes from the blind setup and high effort.
- See `claude-plugins/borg-collective/agents/ROUTING.md` → "Model routing inside Workflow scripts" for the full
  matrix; that doc is the canonical source and this rule is its enforcement hook.
