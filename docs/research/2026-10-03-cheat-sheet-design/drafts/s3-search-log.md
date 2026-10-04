# S3 search log (amount and layering) - 2026-10-04

Snapshot paths in S3 adapter-style cards are relative to docs/research/2026-10-03-cheat-sheet-design/ (drafts/adapter/snapshots/).

## Blocker
The session WebSearch budget (200 calls, shared with the sibling tracks) ran out after 8 web searches in this track. Remaining discovery used the scholarly adapter (OpenAlex), the OpenAlex and Europe PMC REST APIs, and direct WebFetch/curl on known URLs. Consequences: no government plain-language / BLUF doctrine source (e.g. plainlanguage.gov, military BLUF guidance) was retrieved; no search for Szaszi rebuttal to Maier 2022; no "single recommendation vs ranked list" primary study was found (gap).

## Web searches run
| # | Query | Result used |
|---|-------|-------------|
| 1 | Scheibehenne Greifeneder Todd 2010 meta-analytic review choice overload | unige record -> card |
| 2 | Hagger 2016 multilab preregistered replication ego depletion | UU portal -> card |
| 3 | Chernev Bockenholt Goodman 2015 choice overload moderators | Wiley 403; abstract via OpenAlex -> card |
| 4 | Cockburn Karlson Bederson review overview+detail | gatech PDF -> card |
| 5 | Eppler Mengis 2004 information overload | abstract only (unisg) -> paywalled list |
| 6 | Glockner 2016 irrational hungry judge effect revisited | open PDF -> card |
| 7 | Weinshall-Margel Shapard 2011 overlooked factors | PNAS 403 -> paywalled list |
| 8 | Jachimowicz 2019 defaults meta-analysis | IDEAS abstract -> card |
| 9 | Maier 2022 no evidence for nudging | PMC -> card |
| - | Falsification (ego depletion replication failure; choice overload does not exist) | covered by queries 2, 6, 9 and adapter queries below; two further falsification searches were blocked by the budget |

## Scholarly adapter queries (OpenAlex)
- multisite preregistered paradigmatic test of the ego-depletion effect -> Vohs 2021 (card), Dang 2025 (card)
- ego depletion meta-analysis publication bias -> Carter and McCullough (cut), Hagger duplicate
- plain language writing comprehension bottom line up front -> all off-topic (education / Swedish thesis)
- progressive disclosure user interface evaluation -> transparency-in-AI papers (cut; use NN/g instead)
- single recommendation versus ranked list recommender choice overload -> Dean et al., Willemsen 2016, Loepp 2023, cognitive-demand EEG paper
- recommender systems number of recommendations choice difficulty satisfaction list length -> Willemsen 2016 (card)
- highlighted top recommendation default effect recommendation list user choice -> off-topic
- choice overload conceptual review and meta-analysis assortment size moderators -> reviews (cut)
- executive summary placement conclusion first comprehension readers memo -> off-topic education
- information overload knowledge workers email interruptions productivity field study -> Arnold 2023 (card) and 2024 qualitative/email papers (cut)
- decision fatigue question validity ego depletion decision making replication -> Maier 2025 review (card), Inzlicht and Friese 2019 (cut)

## Direct fetches
Shneiderman 1996 (UMD PDF), NN/g progressive-disclosure, inverted-pyramid, Morkes and Nielsen 1997, Iyengar and Lepper via Europe PMC, arXiv 2212.03931, Danziger 2011 abstract via Europe PMC (PNAS 403).

## Triage-outs (cuts)
| Source | Why cut |
|--------|---------|
| Swedish plain-language comprehension thesis (OpenAlex) | Student thesis, 18-19 year olds, null on plain language; low authority, off-population |
| Inzlicht and Friese 2019, past/present/future of ego depletion | Commentary; redundant with Hagger/Vohs |
| Carter and McCullough 2014, publication bias and the limited strength model | Redundant with Hagger/Vohs/Glockner |
| NN/g Inverted Pyramid (Schade 2018) | Non-independent restatement of Morkes and Nielsen guidance |
| Loepp 2023 multi-list interfaces mini-review | No outcome data on list size; says user studies are few and conflict |
| Choice overload hospitality/tourism SLR, haptic-input paper, ease-of-justification fruit/candy paper | Domain-specific or tangential moderators |
| Transparency "progressive disclosure" papers (Springer/IUI) | Different meaning (algorithmic transparency) |
| Cognitive-demand EEG choice overload paper | Lab, 6-24 options, tangential |
| Dang 2025 (kept as Contrarian) / Iyengar 2000 / Dean (kept) | Kept as lowest-scoring keeps; borderline includes are Shneiderman 1996, NN/g progressive disclosure, Morkes and Nielsen, Romero 2024 |
