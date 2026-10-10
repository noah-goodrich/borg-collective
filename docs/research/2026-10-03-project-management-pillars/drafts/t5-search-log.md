# T5 capacity: search log

**Date:** 2026-10-03. Engines: WebSearch (web), OpenAlex scholarly adapter (`scholarly-adapter.sh search`, OpenAlex
backend), Semantic Scholar graph API and Europe PMC REST (abstract retrieval), direct fetch (curl/WebFetch/PDF read).

Note: the scholarly adapter wrote its auto-cards to the DEFAULT output dir
`/Users/noah/dev/claude-plugins/research-tools/hooks/docs/research/{sources,snapshots}` (14 files, prefix
`capacity-`), not to this run's dir. None were used as T5 cards (they are abstract-only and unreviewed); an attempt to
move them was denied by the permission classifier, so they remain there untracked and should be deleted by the owner.

## Queries

| # | Query | Engine | Framing | Results used |
|---|-------|--------|---------|--------------|
| 1 | task switching costs executive control | OpenAlex adapter | factual | Rubinstein 2001 identified (abstract via Europe PMC) |
| 2 | interrupted work cost | OpenAlex adapter | factual | Mark 2008 identified |
| 3 | burnout software engineering systematic | OpenAlex adapter | factual | Tulili 2023 |
| 4 | implementation intentions ADHD | OpenAlex adapter | factual | 0 results |
| 5 | working hours productivity output | OpenAlex adapter | factual | Pencavel; Collewet and Sauermann |
| 6 | Pencavel productivity of working hours output falls after 49 hours IZA | WebSearch | factual | IZA DP 8129 |
| 7 | WIP limits individual personal kanban evidence no empirical support | WebSearch | falsification | ESEM 2018 WIP study |
| 8 | ADHD productivity systems criticism evidence external scaffolding planners adults randomized trial | WebSearch | falsification | Work-MAP RCT; ScienceWorks (rejected); neural-revolution, pckt (cut) |
| 9 | Liebel "software engineers with ADHD" challenges strengths strategies case study arXiv | WebSearch | factual | Liebel 2024 |
| 10 | Gawrilow Gollwitzer implementation intentions facilitate response inhibition children ADHD | WebSearch | factual | Gawrilow 2008; Toli 2016 surfaced |
| 11 | Rubinstein Meyer Evans 2001 executive control of cognitive processes in task switching pdf | WebSearch | factual | Rubinstein bibliographic record; pop-press pages cut |
| 12 | Leroy 2009 "Why is it so hard to do my work" attention residue task switching | WebSearch | factual | Leroy identified (paywalled; blog explainers cut) |
| 13 | Tulili Capiluppi Rastogi Burnout in software engineering systematic mapping study IST | WebSearch | factual | Groningen portal record |
| 14 | SPACE of Developer Productivity "Satisfaction and well-being" "at least three dimensions" Forsgren Storey | WebSearch | factual | Azure blog (primary blocked) |
| 15 | developer with ADHD first-person experience task management what worked what failed blog software engineer time blindness | WebSearch | experiential | Talk Python 473; Medium and kodaps posts cut |
| 16 | Agile principle 8 / c2 wiki SustainablePace | WebFetch | factual | agilemanifesto.org; c2 wiki returned no text |

Not searched (gap): burnout drivers specific to solo developers; sleep deprivation and developer output (Fucci et al.
2018 "Need for sleep"); Pomodoro RCTs; time-blindness clinical measures beyond popular sources; Goodhart/gaming
literature on developer metrics beyond SPACE; DORA well-being findings. Reported honestly as discovery gaps.

## Triage-out list

| Source | Reason |
|--------|--------|
| ScienceWorks Health, External Systems for ADHD at Work | Carded then rejected: commercial intent, secondary citation of primary studies |
| neural-revolution.com ADHD coaching evidence blog | Commercial coaching site; claims not independently verifiable |
| pckt.blog "What Actually Works for Productivity With ADHD" | Anonymous-tier personal blog; page fetched but not usable |
| ScienceWorks "ADHD Software Engineers: Sprints and Standups" | Same publisher as rejected card; redundant |
| Medium/kodaps ADHD developer tips | Anecdotal tips, redundant with Talk Python card |
| get-alfred.ai, strongerhabits, hushpod, goalsandprogress attention-residue explainers | Secondary popularizations of Leroy 2009; primary is paywalled instead |
| vocal.media, minagi, zenexmachina "myth of multitasking" | Low-authority explainers of Rubinstein |
| Collewet and Sauermann (journal) vs IZA | Same work; IZA DP carded |
| Tether (arXiv 2509.01946) | LLM ADHD tool prototype, "not yet evaluated by target users": no evidence of efficacy |
| attexis CBT RCT (medRxiv 2025), A self-guided internet intervention protocol, ISCAP 2025 paper | Clinical interventions or protocols without a task-management mechanism; preprint/protocol status |
| OpenAlex adapter auto-cards (capacity-01..05) | Abstract-only stubs, unreviewed; sit in claude-plugins hooks dir |
| Machine-learning burnout detection SLR (OpenAlex) | Duplicative of Tulili on topic; not fetched |
| SPACE secondary explainers (getdx, swarmia, space-framework.com) | Vendor content; Azure/primary preferred |

Real-cut rule: one source rejected (ScienceWorks). Lowest keeps: Liebel 2024 and ESEM 2018 WIP (weighted average about
7.0); lowest borderline included: Agile principle 8 (about 5.3) and Talk Python (about 5.2).
