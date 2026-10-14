# Source: Agent Skills specification (agentskills.io)

**Full citation:** Agent Skills project. "Specification." agentskills.io. https://agentskills.io/specification. Observed 2026-10-13.
**URL:** https://agentskills.io/specification
**Date accessed:** 2026-10-13
**Evidence level:** 4 (open standard specification)
**Research topic area:** Portability baseline for SKILL.md across agents

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | The published open standard that Claude Code, Cortex (via Snowflake-Labs), and others reference. |
| 2 | Evidence Quality | 8/10 | Normative field table with constraints. |
| 3 | Currency | 9/10 | Live spec page; `allowed-tools` still marked experimental. |
| 4 | Intent | 9/10 | Standards documentation. |
| 5 | Bias & Objectivity | 8/10 | Vendor-neutral by design. |
| 6 | Logic & Coherence | 9/10 | Clear. |
| 7 | Corroboration | 8/10 | Snowflake-Labs README links to agentskills.io; Claude docs describe the same standard. |
| 8 | Intellectual Honesty | 8/10 | Flags experimental fields. |
| 9 | Specificity | 9/10 | Exact field names and limits. |
| 10 | Relevance | 8/10 | Defines the common denominator; shows that `disable-model-invocation` is outside it. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The standard frontmatter fields are name, description, license, compatibility, metadata, and allowed-tools (experimental); `disable-model-invocation` does not appear in the page text (searched).
- A skill that stays inside those fields is portable by design; Matt's invocation-control and tool-call conventions are the Claude-specific layer.
- Skills may include optional `scripts/`, `references/`, and `assets/` directories, matching the Snowflake-Labs repo layout.

## Verified Quote(s)

**Location reference:** Section "SKILL.md format" > "Frontmatter" (first sentence), and "Directory structure".

> The SKILL.md file must contain YAML frontmatter followed by Markdown content.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Needed as the neutral baseline for the portability analysis; supports (not drives) findings.

**Redundancy check:** Distinct from the Claude docs card (which documents the extension keys).

**Perspective category:** Institutional
