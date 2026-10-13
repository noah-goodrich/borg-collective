# Source: Claude Code docs, Skills (invocation control extensions)

**Full citation:** Anthropic. "Extend Claude with skills." Claude Code Documentation. https://code.claude.com/docs/en/skills. Living page, observed 2026-10-13.
**URL:** https://code.claude.com/docs/en/skills
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Claude Code skill extensions that Cortex may not honor

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | The vendor that defines the Claude Code frontmatter keys. |
| 2 | Evidence Quality | 8/10 | Explicit key semantics with examples. |
| 3 | Currency | 10/10 | Living 2026 documentation. |
| 4 | Intent | 8/10 | Instructional. |
| 5 | Bias & Objectivity | 7/10 | Vendor-specific; presents its extensions as native features. |
| 6 | Logic & Coherence | 9/10 | Clear. |
| 7 | Corroboration | 7/10 | Matt's skills use these keys, confirming they are in real use. |
| 8 | Intellectual Honesty | 7/10 | Does not discuss other agents' support. |
| 9 | Specificity | 9/10 | Exact keys. |
| 10 | Relevance | 8/10 | Defines what Matt's frontmatter means in its home environment. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- `disable-model-invocation: true` stops Claude from triggering a skill automatically, making it user-invoked only; most of Matt's workflow skills (to-tickets, triage, setup, implement, grill-me) use it.
- The same page documents `context: fork`, which runs a skill in its own subagent context; this is a Claude Code feature with no documented Cortex equivalent in the pages reviewed.
- If Cortex ignores `disable-model-invocation`, those skills would become eligible for automatic invocation instead of explicit-only (inference; the behavior is undocumented on Snowflake's side).

## Verified Quote(s)

**Location reference:** Section "Control who invokes a skill" area, paragraph beginning "Task content gives Claude step-by-step instructions" (rendered page text; italics/bold markers omitted).

> Add `disable-model-invocation: true` to prevent Claude from triggering it automatically.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Establishes the semantics of the one frontmatter key that most affects Matt's skills on a non-Claude host.

**Redundancy check:** Not covered by the spec card or Snowflake docs.

**Perspective category:** Institutional
