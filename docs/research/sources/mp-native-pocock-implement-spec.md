# Source: mattpocock/skills implement-spec skill

**Full citation:** Pocock, Matt. "implement-spec" SKILL.md, repository mattpocock/skills, skills/engineering/implement-spec. https://github.com/mattpocock/skills/blob/main/skills/engineering/implement-spec/SKILL.md. Fetched 2026-10-13.
**URL:** https://raw.githubusercontent.com/mattpocock/skills/main/skills/engineering/implement-spec/SKILL.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (primary artifact by practitioner)
**Research topic area:** Which Matt skills depend on native subagents, worktrees, and background execution

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Skill author |
| 2 | Evidence Quality | 5/10 | Prose procedure, untested here |
| 3 | Currency | 10/10 | Current main |
| 4 | Intent | 7/10 | Operating procedure |
| 5 | Bias & Objectivity | 6/10 | Single design |
| 6 | Logic & Coherence | 8/10 | Clear task-graph steps |
| 7 | Corroboration | 7/10 | Matches native /batch pattern |
| 8 | Intellectual Honesty | 6/10 | No caveats stated |
| 9 | Specificity | 9/10 | Nine numbered steps |
| 10 | Relevance | 9/10 | Overlaps native orchestration |

- Authority: it is the skill's own text.
- Evidence Quality: a procedure, with no evidence of outcomes; inclusion here is as an artifact, not as proof it works.
- Currency: fetched from main on 2026-10-13.
- Intent: instructs an agent how to work, no sales content.
- Bias: encodes one author's workflow.
- Logic: spec, tickets, frontier, implementer subagents, merger subagent, code review, cleanup.
- Corroboration: the native `/batch` skill and workflows describe the same fan-out shape, from the harness side.
- Honesty: no stated failure modes.
- Specificity: names the integration branch, worktree per implementer, merger subagent, `code-review` close-out.
- Relevance: the clearest skill that rebuilds a native capability as prose.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- `implement-spec` is `disable-model-invocation: true` and treats tickets as a task graph with a "frontier" of ready work, run by implementer subagents in the background.
- Each implementer works in its own worktree on its own branch and calls the `tdd` skill; a separate merger subagent merges into one integration branch.
- It closes with `code-review` on the integration branch and cleans up worktrees, so it composes his skills by instructing the agent to call the Skill tool.
- The mechanics (background subagents, worktrees) are native; the contribution is the ticket-graph process and ticket-blocking edges, which a native dynamic workflow could encode as a script but does not provide on its own.
- Compared with borg: borg adds locked acceptance criteria and a blind reviewer; this skill relies on a single `code-review` pass at the end.

## Verified Quote(s)

**Location reference:** Paragraph beginning "**Implementer subagents** should be run..." (just before "## Steps"); Steps list, item 4.

> **Implementer subagents** should be run in the background where possible for maximum concurrency.

> Use **implementer subagents** to implement each ticket, each in its own worktree on its own branch.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** The best concrete example of a Matt skill whose mechanics duplicate native capability while its process does not.

**Redundancy check:** The README lists the skill in one line; this card shows the actual procedure.

**Perspective category:** Practitioner
