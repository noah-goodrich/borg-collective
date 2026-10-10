# T3 (flow) search log

**Date:** 2026-10-03. Engine for all queries: WebSearch (Claude Code web search tool). Verbatim quotes were checked by
fetching each page with curl, stripping HTML, and asserting the exact string is present.

## Queries

| # | Query | Engine | Date | Results used |
|---|-------|--------|------|--------------|
| 1 | DORA 2024 Accelerate State of DevOps report AI adoption delivery throughput stability findings | WebSearch | 2026-10-03 | Google Cloud 2024 blog |
| 2 | DORA 2025 State of AI-assisted Software Development report findings | WebSearch | 2026-10-03 | Google Cloud 2025 blog |
| 3 | DORA metrics criticism Goodhart gaming four keys | WebSearch (falsification) | 2026-10-03 | dora.dev four-keys guide |
| 4 | Kanban Guide 2020 Daniel Vacanti Prateek Singh WIP flow metrics definition | WebSearch | 2026-10-03 | Kanban Guide 2020.12 |
| 5 | SPACE framework developer productivity Forsgren Storey ACM Queue | WebSearch | 2026-10-03 | (led to #17) |
| 6 | METR randomized controlled trial AI experienced open-source developers slower | WebSearch | 2026-10-03 | METR blog |
| 7 | WIP limits empirical evidence study effect on lead time software teams kanban | WebSearch | 2026-10-03 | Sjoberg ESEM 2018 (SINTEF) |
| 8 | WIP limits don't help criticism kanban evidence weak | WebSearch (falsification) | 2026-10-03 | ProKanban WIP post (read, not carded) |
| 9 | Little's Law software development cycle time WIP throughput Vacanti Actionable Agile | WebSearch | 2026-10-03 | led to #19 |
| 10 | trunk-based development research small batches continuous integration DORA capability | WebSearch | 2026-10-03 | DORA trunk-based page |
| 11 | solo developer personal kanban WIP limit one-person team experience | WebSearch | 2026-10-03 | none (low-quality blogs) |
| 12 | DORA metrics are harmful misleading critique Accelerate statistical validity methodology | WebSearch (falsification) | 2026-10-03 | led to #20 |
| 13 | "An empirical study of WIP in kanban teams" authors abstract | WebSearch | 2026-10-03 | SINTEF record |
| 14 | Faros AI Productivity Paradox report 10,000 developers | WebSearch | 2026-10-03 | Faros page |
| 15 | Kent Beck Gergely Orosz measuring developer productivity McKinsey response | WebSearch (contrarian) | 2026-10-03 | Beck/Orosz newsletter |
| 16 | solo developer AI coding agents shipping workflow lessons small batches review bottleneck | WebSearch (experiential) | 2026-10-03 | Folkman (excluded), Osmani (not carded) |
| 17 | "SPACE of Developer Productivity" "productivity cannot be reduced to a single dimension" | WebSearch | 2026-10-03 | atlas.science mirror |
| 18 | DORA pausing annual survey 2026 dora.dev announcement | WebSearch | 2026-10-03 | dora.dev/survey (no primary pause statement found) |
| 19 | Vacanti Little's Law assumptions flow metrics stable system | WebSearch | 2026-10-03 | 55 Degrees post |
| 20 | Accelerate DORA research critique self-reported survey causal claims methodology | WebSearch (falsification) | 2026-10-03 | Keunwoo Lee review |
| 21 | Goodhart's law software engineering metrics empirical study gaming velocity story points | WebSearch (falsification) | 2026-10-03 | none (blogs only; no empirical study found) |
| 22 | arXiv survey solo developers agile practices one-person software projects | WebSearch | 2026-10-03 | arXiv 2605.18461 |
| 23 | Hacker News Ask HN solo developer how do you manage tasks WIP limit kanban | WebSearch (experiential) | 2026-10-03 | HN item 41473997 (excluded) |

Also fetched directly: scrumguides.org (Definition of Done).

## Triage out

| Source | Reason |
|--------|--------|
| Medium: "DORA Report 2024 reviewed", RedMonk, New Stack, OpsLevel, Scribd copies | Secondary summaries of a primary already fetched |
| Scrum.org DORA 2025 summary | Secondary; Google blog is primary |
| Honeycomb / Faros DORA 2025 takeaways | Vendor summaries of the same report |
| codepulsehq, keypup, typoapp, alekseialeinikov, neuralwired Goodhart/DORA posts | Vendor or low-credibility content marketing; DORA guide already states Goodhart |
| Aviator "Everything wrong with DORA metrics", Medium "Optimisation Trap" | Vendor/blog opinion; Lee review covers the substantive critique |
| Bryan Finster "How to Misuse & Abuse DORA Metrics" PDF | Promising practitioner source; PDF returned binary, not text-verifiable this run (follow-up candidate) |
| InfoQ "How Not to Use the DORA Metrics" | Fetched; overlaps DORA guide and pre-dates 2024; not carded |
| Thoughtworks Radar DORA metrics | Page did not render usable text (JS); not verified |
| super-productivity.com, easykanb, miro, kanbantool, teachingagile WIP posts | Vendor marketing; no evidence |
| Medium Little's Law posts, leanability, calade, resumelens | Secondary explanations; 55 Degrees (Vacanti's firm) used instead |
| ProKanban "WIP: what it is" post | Read; conceptual, no evidence beyond assertion; claim that the ProKanban guide removed the WIP-limit requirement was not verified and the 2020 Guide still says "often using WIP Limits" |
| Osmani "AI writes code faster..." (Jan 2026) | Read; opinion with unsourced statistics (75% logic errors); overlaps Faros/Folkman themes |
| Waydev "DORA is pausing the survey" | Vendor blog; primary dora.dev announcement not found, so claim left unused |
| METR 2026 follow-up and ingenire/particula summaries | Secondary; Feb 2026 METR follow-up not fetched (gap) |
| DORA 2025 PDF/ROI report | Not fetched; Google blog used instead |
| Folkman substack (carded) | Rubric band reject: anecdote, unverified credentials |
| HN Ask solo developer thread (carded) | Rubric band reject: anonymous anecdotes |
| tameflow, spamcast, agilelaws, businessmap | Secondary / low-authority |
