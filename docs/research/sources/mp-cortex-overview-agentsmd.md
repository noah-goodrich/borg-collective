# Source: Snowflake docs, Cortex Code overview (AGENTS.md support)

**Full citation:** Snowflake Inc. "Cortex Code." Snowflake Documentation. https://docs.snowflake.com/user-guide/cortex-code/cortex-code. Living page, observed 2026-10-13.
**URL:** https://docs.snowflake.com/user-guide/cortex-code/cortex-code
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Cortex Code CLI AGENTS.md and agent customization

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Vendor overview page. |
| 2 | Evidence Quality | 5/10 | States support for AGENTS.md in one line with no loading rules, precedence, or CLAUDE.md mention. |
| 3 | Currency | 9/10 | Current 2026 page. |
| 4 | Intent | 7/10 | Overview with a marketing flavor. |
| 5 | Bias & Objectivity | 6/10 | Feature-list framing. |
| 6 | Logic & Coherence | 8/10 | Clear feature bullets. |
| 7 | Corroboration | 6/10 | Extensibility page and changelog never mention AGENTS.md; grep of both found no occurrence, so the claim stands on this page alone. |
| 8 | Intellectual Honesty | 6/10 | No caveats. |
| 9 | Specificity | 4/10 | Does not say which files are read, from where, or how they merge. |
| 10 | Relevance | 8/10 | Only documentation hit for AGENTS.md support. |

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The CLI is documented as supporting `AGENTS.md` files and Agent Skills for per-project behavior.
- The page lists the extensibility surface as custom tools, skills, subagents, hooks, and profiles.
- No Snowflake documentation page found describes CLAUDE.md loading; the absence is itself a finding for a user whose projects use CLAUDE.md.
- The loading semantics of AGENTS.md (location, precedence) are undocumented in the pages checked.

## Verified Quote(s)

**Location reference:** Bulleted feature list near the top of the page, bullet "Agent customization" (first line) and bullet "Extensibility". Quotes taken from the page's markdown rendering at the card URL (append .md).

> - **Agent customization:** Support for `AGENTS.md` files and Agent Skills allows you to define custom behaviors for the agent within

> - **Extensibility:** The CLI can be extended with custom tools, skills, subagents, hooks, and profiles to fit your organization's workflows.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline on specificity and corroboration, kept as the sole documentation of AGENTS.md support (gap-fill, named). Lowest-scoring source that cleared the bar in this topic area.

**Redundancy check:** Only source for AGENTS.md; not dominated.

**Perspective category:** Institutional
