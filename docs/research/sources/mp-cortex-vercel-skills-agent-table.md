# Source: vercel-labs/skills README, supported agents table (Cortex Code row)

**Full citation:** Vercel Labs. "skills" (the `npx skills` CLI) README, supported-agents table. GitHub. https://github.com/vercel-labs/skills. Observed 2026-10-13.
**URL:** https://github.com/vercel-labs/skills
**Date accessed:** 2026-10-13
**Evidence level:** 5 (practitioner tooling documentation; the maintainer's own table)
**Research topic area:** Installing third-party skill libraries (including Matt's) into Cortex Code

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Maintainer of the cross-agent skills installer that Matt's README itself recommends. |
| 2 | Evidence Quality | 7/10 | A table row plus matching `agents.ts` entry in source; no end-to-end test of Cortex installs. |
| 3 | Currency | 9/10 | Active repo; Cortex row present in October 2026. |
| 4 | Intent | 8/10 | Tool documentation. |
| 5 | Bias & Objectivity | 8/10 | Neutral lookup table. |
| 6 | Logic & Coherence | 8/10 | Consistent between README and source. |
| 7 | Corroboration | 8/10 | Paths match Snowflake docs (`.cortex/skills/`, `~/.snowflake/cortex/skills/`). |
| 8 | Intellectual Honesty | 7/10 | Does not claim verified compatibility per agent. |
| 9 | Specificity | 9/10 | Exact agent id and both paths. |
| 10 | Relevance | 10/10 | The concrete mechanism by which Matt's skills could land in Cortex. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The `skills` CLI has a first-class `cortex` agent with project dir `.cortex/skills/` and global dir `~/.snowflake/cortex/skills/`.
- Matt's README documents `npx skills@latest add mattpocock/skills -a <agent>`; the combination implies `-a cortex` is an available install route, although no source shows anyone doing it (inference).
- The CLI's detection of Cortex is by existence of `~/.snowflake/cortex`.

## Verified Quote(s)

**Location reference:** Supported agents table, row "Cortex Code" (README raw text); the same README repeats `.cortex/skills/` in its path list.

> | Cortex Code | `cortex` | `.cortex/skills/` | `~/.snowflake/cortex/skills/` |

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Establishes the install mechanism and closes the question of whether third-party libraries have a supported path into Cortex.

**Redundancy check:** Distinct from Snowflake docs (which describe `/skill add` rather than the third-party installer).

**Perspective category:** Practitioner
