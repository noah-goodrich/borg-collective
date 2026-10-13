# Source: Capital One Software, hands-on review of Cortex Code CLI

**Full citation:** Capital One Software. "Cortex Code CLI: Hands-on review of Snowflake's CoCo CLI" (blog). April 16, 2026. https://capitalonesoftware.com/blog/snowflake-coco-cli (301 from capitalone.com/software/blog/snowflake-cortex-code-cli/).
**URL:** https://capitalonesoftware.com/blog/snowflake-coco-cli
**Date accessed:** 2026-10-13
**Evidence level:** 5 (practitioner structured test with documented method, TPC-DS sample data)
**Research topic area:** Practitioner experience with Cortex Code, skills, and dbt

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | An engineering vendor in the Snowflake ecosystem with hands-on testing; a company blog, not independent research. |
| 2 | Evidence Quality | 7/10 | Structured five-area test on a standard dataset; single run, no repeats stated. |
| 3 | Currency | 8/10 | April 2026; the CLI has since moved from roughly 1.0.x to 1.1.87, so details may have drifted. |
| 4 | Intent | 6/10 | Capital One Software sells Snowflake cost tooling, so FinOps framing has commercial interest. |
| 5 | Bias & Objectivity | 6/10 | Largely favorable ("it absolutely understands Snowflake") but lists weaknesses. |
| 6 | Logic & Coherence | 8/10 | Escalating test design. |
| 7 | Corroboration | 6/10 | Consistent with Snowflake's own blog on dbt; no independent replication found. |
| 8 | Intellectual Honesty | 7/10 | Names warehouse sizing, browser deployment, and token cost as weaknesses. |
| 9 | Specificity | 8/10 | Dataset, test areas, and concrete outputs (21 files). |
| 10 | Relevance | 7/10 | Gives Cortex-native skill and dbt behavior; says nothing about third-party skill libraries. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Cortex consults its built-in skills proactively (Streamlit skills in the test), so bundled Snowflake skills already cover the domain work (dbt, Streamlit, Airflow) that a generic skill library would not.
- dbt generation worked end to end in the test: dependency-aware creation of missing staging models, `incremental_strategy='merge'`, 21 files for a full project.
- Listed weaknesses: warehouse sizing is the user's responsibility, Streamlit deployment still needs a browser, token cost accumulates in agentic sessions.
- The author frames Cortex as competing with manual Snowflake work, not with general coding agents, which cuts against using it as a general-purpose Claude Code substitute.

## Verified Quote(s)

**Location reference:** Section "Who's it for" (first sentences); weaknesses list heading text "Token cost accumulates."; skills passage in the Streamlit test section.

> CoCo CLI isn’t competing with general coding agents for general software development.

> Before writing a single line of code, CoCo invoked its built-in skill system

> Token cost accumulates.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Best available hands-on, dated evidence of how Cortex skills behave in practice; also the nearest thing to a limiting voice on scope.

**Redundancy check:** Only independent practitioner test found; other hits were vendor or aggregator pages.

**Perspective category:** Boots-on-the-ground
