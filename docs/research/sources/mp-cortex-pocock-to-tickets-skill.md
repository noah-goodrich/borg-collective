# Source: mattpocock/skills, to-tickets SKILL.md (tracker dependence, Claude-style frontmatter)

**Full citation:** Pocock, Matt. "to-tickets" skill (SKILL.md). GitHub, mattpocock/skills, skills/engineering/to-tickets. https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md. Observed 2026-10-13.
**URL:** https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md
**Date accessed:** 2026-10-13
**Evidence level:** 5 (primary practitioner artifact)
**Research topic area:** What would and would not port to Cortex Code

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | The skill's author. |
| 2 | Evidence Quality | 9/10 | The artifact itself; directly inspectable. |
| 3 | Currency | 10/10 | Main branch on the day of access. |
| 4 | Intent | 8/10 | Functional instructions. |
| 5 | Bias & Objectivity | 8/10 | N/A beyond author choices; used as evidence of file contents, not of quality. |
| 6 | Logic & Coherence | 8/10 | Coherent tracer-bullet instructions. |
| 7 | Corroboration | 7/10 | Same pattern (tracker config, `disable-model-invocation`) in triage, setup, and implement skills fetched. |
| 8 | Intellectual Honesty | 7/10 | Falls back to local files when no tracker. |
| 9 | Specificity | 9/10 | Exact frontmatter and instructions. |
| 10 | Relevance | 9/10 | Shows the tracker coupling and frontmatter key that govern portability. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The frontmatter carries `disable-model-invocation: true`, a Claude Code key that is not in the Agent Skills open specification's field list; whether Cortex honors it is not documented (Cortex's own options table did not render).
- The skill depends on an issue tracker configured by a prior `/setup-matt-pocock-skills` run; GitHub is the default, with local markdown files as an alternative.
- Related skills (implement, triage) instruct the agent to "Call the Skill tool", a Claude Code tool name; Cortex invokes skills via `$name` or by loading `/skill`, so these cross-skill calls may not resolve (inference; untested).
- The tracker coupling is the main non-portable element for Snowflake work, where tickets live in Jira or similar and the work product is SQL, dbt, and warehouse objects (inference).

## Verified Quote(s)

**Location reference:** Frontmatter block (lines 1-5) and the first body paragraph after the H1 "To Tickets".

> disable-model-invocation: true

> The issue tracker and triage label vocabulary should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Direct evidence for the port analysis; the only way to ground "what would port" without a real Cortex test.

**Redundancy check:** Not redundant with the README; this is the actual skill text.

**Perspective category:** Practitioner
