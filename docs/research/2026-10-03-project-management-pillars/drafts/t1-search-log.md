# T1 (pillars) search log

**Date:** 2026-10-03
**Track:** T1 — how frameworks decompose project management and where they agree (RQ1)
**Engine:** WebSearch (all queries); pages fetched with curl/WebFetch and read as text; PDFs via pdftotext.

## Queries

| # | Query | Engine | Date | Framing | Results used |
|---|-------|--------|------|---------|--------------|
| 1 | PMBOK Guide Seventh Edition 12 principles 8 performance domains list PMI | WebSearch | 2026-10-03 | factual | becomeaprojectmanager.com (names; rejected), ricardo-vargas.com (read, not carded) |
| 2 | PRINCE2 seven themes seven principles seven processes official overview | WebSearch | 2026-10-03 | factual | prince2.com ILX blog (read) |
| 3 | PMBOK Guide 8th edition released 2025 changes principles performance domains PMI official announcement | WebSearch | 2026-10-03 | factual (recency) | learningtree.com (read, cut), PMA (carded) |
| 4 | pmi.org PMBOK Guide Eighth Edition announcement ... (allowed_domains pmi.org) | WebSearch | 2026-10-03 | factual (primary) | pmi.org/standards/pmbok snippet only (HTTP 403 to fetch); PMI facts + FAQ PDFs (carded) |
| 5 | PMI press release PMBOK Guide Eighth Edition released November 2025 "48,000 data points" | WebSearch | 2026-10-03 | factual (primary) | no primary press release found; trainer pages only |
| 6 | critique of PMBOK body of knowledge project management theory Winter Smith Morris Cicmil | WebSearch | 2026-10-03 | contrarian | Winter et al. 2006 (carded, abstract); scielo critical review (cut, no abstract text) |
| 7 | Winter Smith Morris Cicmil 2006 "Directions for future research..." abstract | WebSearch | 2026-10-03 | contrarian | Manchester Research Explorer abstract (carded) |
| 8 | is project management methodology evidence that PMBOK PRINCE2 certification does not improve project success empirical study | WebSearch | 2026-10-03 | FALSIFICATION | only low-quality comparison papers surfaced; none carded |
| 9 | project management body of knowledge criticized "one size fits all" empirical evidence practitioners ignore PMBOK tools usage survey | WebSearch | 2026-10-03 | FALSIFICATION | arXiv 2506.02214 (carded); no usage-survey found |
| 10 | Eveleens Verhoef "The rise and fall of the Chaos report figures" IEEE Software | WebSearch | 2026-10-03 | FALSIFICATION | VU author PDF (carded) |
| 11 | "Eveleens" "Verhoef" Chaos report figures pdf ... | WebSearch | 2026-10-03 | FALSIFICATION | cs.vu.nl PDF located |
| 12 | Serrador Pinto "Does Agile work" quantitative analysis ... | WebSearch | 2026-10-03 | evaluative | APM 2-page summary read (cut; secondary) |
| 13 | comparison PMBOK PRINCE2 Scrum Kanban common elements knowledge areas mapping systematic literature review | WebSearch | 2026-10-03 | evaluative | only trainer comparisons; none carded (no neutral mapping study found) |
| 14 | PRINCE2 7 what's new practices replace themes people sustainability digital data PeopleCert | WebSearch | 2026-10-03 | factual | prince2.com v7 page (carded); lumifywork, purplegriffon, projex snippets (corroboration only) |
| 15 | PRINCE2 criticism bureaucratic overhead small projects failure study | WebSearch | 2026-10-03 | FALSIFICATION/contrarian | only blog-grade pros/cons; no failure study; none carded |
| 16 | Scrum Guide 2020 changes what's new Schwaber Sutherland removed prescriptive | WebSearch | 2026-10-03 | factual | scrumguides.org/revisions.html fetched (not carded); InfoQ Q&A snippet |
| 17 | Scrum criticism empirical evidence does Scrum improve outcomes study teams | WebSearch | 2026-10-03 | evaluative/contrarian | Verwijs and Russo (carded) |
| 18 | Kanban evidence study WIP limits effect on cycle time empirical software teams | WebSearch | 2026-10-03 | evaluative | ACM WIP study (HTTP 403; covered by track T3/T5 cards) |
| 19 | Kanban vs Scrum which for small team experience report switched from Scrum to Kanban | WebSearch | 2026-10-03 | experiential | Agile Alliance, Caktus, Mind the Product snippets (not fetched; overlaps T3) |
| 20 | Poppendieck Lean Software Development seven principles eliminate waste amplify learning decide as late as possible | WebSearch | 2026-10-03 | factual | secondary pages only; led to #21 |
| 21 | Poppendieck "Principles of Lean Thinking" pdf eliminate waste amplify learning build integrity in see the whole | WebSearch | 2026-10-03 | factual | 2002 paper (read, superseded) and InfoQ ch.2 (carded) |
| 22 | lean software development criticism limitations Poppendieck waste metaphor manufacturing not software | WebSearch | 2026-10-03 | FALSIFICATION | Springer lit review (not fetched; abstract-level only) |
| 23 | Ron Jeffries "Developers Should Abandon Agile" ronjeffries.com | WebSearch | 2026-10-03 | contrarian | ronjeffries.com (carded) |
| 24 | Shape Up methodology experience after one year problems criticism small team not Basecamp | WebSearch | 2026-10-03 | experiential/contrarian | fnune.com (carded); Shape Up forum 'disappointing' post (read, not carded) |
| 25 | Shape Up Ryan Singer book review pros cons appetite betting table | WebSearch | 2026-10-03 | evaluative | review snippets only (circuit-breaker depends on leadership; shapers vs delivery teams) |
| 26 | solo developer project management Scrum kanban one person team what works experience | WebSearch | 2026-10-03 | experiential | HN item 21905423 (carded, rejected); scrum.org forum (HTTP 403) |
| 27 | PMI Pulse of the Profession 2025 project success rates performance report | WebSearch | 2026-10-03 | evaluative | Pulse 2025 PDF read (cut, tangential) |

Direct fetches of primaries (no search): scrumguides.org/scrum-guide.html; kanbanguides.org (2025.5 and 2020.12);
basecamp.com/shapeup chapters 1, 3, 7, 8; PMI facts and FAQ PDFs.

## Triage-out list

| Source | Reason |
|--------|--------|
| becomeaprojectmanager.com "Significant Changes in the PMBOK Guide's Seventh Edition" (2022) | Exam-prep blog; est. weighted score ~4.3 (reject). Used only to read the names (see below); not carded |
| Learning Tree PMBOK 8 article | Training vendor, secondary; est. ~5.0; redundant with the PMA card (same 6/7/40/5 counts) |
| Poppendieck "Principles of Lean Thinking" (2002 paper) | Read in full; scored borderline (~5.5) but superseded by the 2006 chapter; kept as a cited claim in that card |
| HN Ask HN solo devs (item 21905423) | Carded but REJECT band (~4.5): anonymous anecdote; the run's deliberate real cut |
| Serrador and Pinto APM summary | Two-page secondary summary of a paywalled paper; tangential to decomposition; listed as paywalled candidate |
| PMI Pulse of the Profession 2025 | Self-reported survey n=2,254; tangential (business-acumen skills, not decomposition); the '31% successful' snippet was not found in the PDF text |
| scielo.org.co PMBOK critical review (Spanish) | No abstract/body text recovered in fetch |
| Scrum.org forum "One man Scrum Team" | HTTP 403; HN thread used instead |
| ACM "An empirical study of WIP in kanban teams" | HTTP 403; handled by T3/T5 tracks |
| Shape Up forum 'My experience ... disappointing' (2023) | Thin single post; overlaps fnune.com; kept out to avoid redundancy |
| prince2.com ILX older blog (principles/themes/processes) | Superseded by ILX V7 page |
| Wikipedia and generic trainer pages (asana, monday, knowledgehut, etc.) | Not minimally credible / redundant |
| ricardo-vargas.com PMBOK 7 domains podcast | Page text only says domains have 'no sequence'; no list; thin |

## Real-cut and marginal-keep note (rubric rule)

- Cut: HN solo-dev thread (reject), plus the triage list above.
- Lowest `keep`: Kanban Guide 2025 (weighted ~7.05, barely over the 7.0 bar; defended: primary, current, free).
- Lowest `borderline` retained: Jeffries, PMA PMBOK 8, and PRINCE2 V7 (each ~5.1); all kept only as gap-fill / sole
  accessible source, documented in each card.

## Facts read but not carded (trade source, treat as unverified against PMI)

The PMBOK 7 name lists below come from becomeaprojectmanager.com (2022), which scored reject as a source; they match
Ricardo Vargas and other trainer snippets but were NOT confirmed from the standard (paywalled):

- 12 principles: Stewardship, Team, Stakeholders, Value, Systems Thinking, Leadership, Tailoring, Quality, Complexity,
  Risk, Adaptability and Resiliency, Change.
- 8 domains: Stakeholders, Team, Development Approach and Life Cycle, Planning, Project Work, Delivery, Measurement,
  Uncertainty.
- PMBOK 6's 10 knowledge areas: Integration, Scope, Schedule, Cost, Quality, Resources, Communications, Risk,
  Procurement, Stakeholders.

## Method caveats

- PMI.org HTML pages return HTTP 403 to automated fetches; only its PDF assets were readable.
- A small-model WebFetch summary mislabeled the kanbanguides.org/english page as May 2025; the page actually served
  the 2020.12 text. Quotes in cards were therefore taken from curl text of the versioned 2025.5 URL and machine
  checked against the fetched text (all card quotes pass a whitespace-normalized exact-substring check).
