# S1 search log: status displays and situational awareness

**Date:** 2026-10-04. **Tooling note:** the session-wide WebSearch budget (200 calls, shared with the other parallel tracks) ran out partway through this track. Roughly 9 WebSearch calls were made; the remaining planned queries were replaced by the OpenAlex scholarly adapter, the Europe PMC and Hacker News Algolia APIs, and direct page fetches. Subtopics that therefore got fewer than three varied queries are marked.

## Queries run

| # | Subtopic | Query (tool) | Result |
|---|----------|--------------|--------|
| 1 | SA theory | "Endsley 1995 toward a theory of situation awareness ... three levels" (WebSearch) | Level definitions; primary paper paywalled (Sage) |
| 2 | SA falsification | "situation awareness construct criticism Dekker Flach circular explanation" (WebSearch) | Led to the Carsten and Vanderhaegen editorial (open) and the Bakdash meta-analysis |
| 3 | SA measurement | "situation awareness global assessment technique SAGAT validity" (scholarly adapter) | Endsley SAGAT chapter (abstract only) |
| 4 | SA validity | "situation awareness meta-analysis performance validity" (scholarly adapter) | Bakdash 2021 |
| 5 | Alarms | "EEMUA 191 alarm systems guide alarm rate per operator per 10 minutes" (WebSearch) | Led to the ASM Consortium benchmark paper |
| 6 | Alarms | "HSE The management of alarm systems Bransby Jenkinson research report 166" (WebSearch) | HSE PDF URL 404 on fetch; logged paywalled |
| 7 | Alarms | "alarm flood operator alarm management human factors" (scholarly adapter) | Guy 2016 thesis, Buddaraju 2011 thesis, human-factors chapter |
| 8 | Alert fatigue | "Ancker 2017 effects of workload, work complexity, and repeated alerts on alert fatigue" (WebSearch) | Ancker 2017 |
| 9 | Dashboards falsification | "dashboards don't improve decisions evidence dashboard use effectiveness study" (WebSearch) | Xie 2022 SR of RCTs; Rossi 2025 (abstract read, not carded) |
| 10 | Dashboards | "Stephen Few Dashboard Design for Real-Time Situation Awareness pdf" (WebSearch) | URL resolved; PDF fetched and read |
| 11 | Dashboards practitioner | Hacker News Algolia "alert fatigue", "dashboard" (API) | Timeframe post (47113728) |
| 12 | Kanban / flow | "cumulative flow diagram kanban board comprehension experiment" (WebSearch) | Only vendor how-to pages, no evidence; none carded |
| 13 | Kanban / flow | "kanban board visualization team awareness" and "burndown chart agile visualization empirical" (scholarly adapter); Europe PMC for "cumulative flow diagram", "burndown chart", "task board" | Rodrigues 2026, Sandvik 2011 thesis; no CFD or burn-chart evidence; Europe PMC returned irrelevant hits |
| 14 | Glanceability | "glanceable display peripheral display evaluation" (scholarly adapter); web query blocked by budget | Matthews 2006 abstracts only (no findings in the abstract) |
| 15 | CLI design | direct fetch of clig.dev (no search; chosen from prior knowledge of the field, flagged) | Read in full |

Subtopics with fewer than three varied queries: glanceability (1), CLI/terminal information design (0 searches), "single pane of glass" critique (0, blocked), alert-fatigue (1).

## Triage-outs (cuts)

| Source | Reason |
|--------|--------|
| Wikipedia, Wrike, Kanbantool, Adobe, Kissflow, Microtool CFD explainers | Vendor or tutorial content; no comprehension evidence (level 9) |
| Buddaraju 2011, "Performance of control room operators in alarm management" (LSU thesis, 25 operators) | Master's thesis, abstract only; experimental result (response time differs between 25 and 30 alarms per 10 min; categorical display better but not significant) is redundant with Reising 2005 on rate limits; cut |
| Guy 2016, "Best practice management of industrial process control alarm floods" (USQ thesis) | Abstract only; interesting claim that alarms are assigned high priority at 5-6 times the standard percentage, but not verified from full text; cut, noted as a lead |
| Matthews 2006, glanceable displays (two abstracts) | Proposal-style abstract with no findings; full text not retrievable; cut. Glanceability left as an evidence gap |
| Ericsson and Granlof 2011, Sandvik Kanban thesis | Student thesis, interview survey, abstract only; reports less stress and more focus on quality; superseded by Rodrigues 2026 as the (weak) Kanban source |
| "A study on Kanban methodology influence on workflow" | Abstract-level claims only; no methods or numbers |
| Seqent, Industry Digits, Emerson, ABB, exida alarm-rationalization pages | Vendor marketing around EEMUA numbers; the open ASM paper preferred |
| Dashboards: medium.com survey, ResearchGate "interactive dashboards improve managerial decision-making", arXiv 2507.20985 and 2605.31224 | Weak or not fetched; some are preprints on LLM interfaces; cut unread |
| Hacker News comments on dashboards | Noise; no comment gave a verifiable design claim; only the Timeframe post kept |
| Flach 1995, Dekker and Hollnagel 2004, Endsley 1995 and 2015, Sarter and Woods 1995 | Paywalled; listed in paywalled-candidates.md |

## Real-cut note

The lowest-scoring kept source is the Timeframe post (weighted average about 5.0, borderline floor); the lowest `keep` band is Ancker 2017 (about 7.6). Cuts above satisfy the real-cut rule.
