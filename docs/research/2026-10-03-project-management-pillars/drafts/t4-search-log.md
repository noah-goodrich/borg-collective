# T4 (feedback) search log

Date of all queries: 2026-10-03. Engine "WebSearch" = Claude web search; "OpenAlex adapter" = scholarly-adapter.sh
(backend openalex). Adapter runs wrote their auto-cards to a scratch directory, not to this corpus, except the first
query (see note at bottom).

## Queries

| # | Query | Engine | Framing | Results used |
|---|-------|--------|---------|--------------|
| 1 | Tannenbaum Cerasoli 2013 debriefs meta-analysis performance improvement 25% | WebSearch | factual | cebma.org PDF (card) |
| 2 | Google SRE book postmortem culture learning from failure blameless | WebSearch | factual | sre.google chapter (card) |
| 3 | Klein pre-mortem prospective hindsight 30% increase identify reasons for outcomes | WebSearch | factual | hbr.org (card), USC mirror (context) |
| 4 | post-mortems don't prevent recurrence incident review action items never completed research | WebSearch | falsification | odd.fyi lead only; vendor blogs triaged out |
| 5 | retrospectives effectiveness empirical study agile teams do retrospectives improve outcomes | WebSearch | evaluative | leads to Lehtinen, Stålesen/Dølvik, arXiv 2007.08265 (not carded) |
| 6 | agile retrospectives are useless waste of time critique | WebSearch | falsification/contrarian | Corry on martinfowler.com (card) |
| 7 | watermelon project status reporting green outside red inside research | WebSearch | experiential | all vendor/PM blogs; triaged out |
| 8 | Goodhart's law software metrics gaming measurement dysfunction empirical | WebSearch | factual | Thomas & Uminsky arXiv (triaged); vendor blogs out |
| 9 | risk register effectiveness criticism project risk management lightweight alternative evidence | WebSearch | evaluative/contrarian | niksilver.com (card) |
| 10 | definition of done quality gates Scrum Guide commitment increment | WebSearch | factual | scrumguides.org (card) |
| 11 | Learning from incidents post-incident reviews do not reduce recurrence Allspaw blameless critique Safety-II | WebSearch | falsification | odd.fyi (card), ACL Allspaw (card) |
| 12 | project post-mortem reviews software organizations study learning actually applied Dingsøyr postmortem review | WebSearch | evaluative | Dingsøyr papers identified (paywalled) |
| 13 | Snow Keil optimistic pessimistic biasing software project status reporting study | WebSearch | factual | leads (MIT Sloan article blocked) |
| 14 | Keil Robey "Blowing the whistle on troubled software projects" escalation reporting bad news | WebSearch | factual | paywalled list |
| 15 | Hacker News retrospectives are theater nothing changes solo developer weekly review | WebSearch | experiential | HN item 28352828 (card, rejected) |
| 16 | Bevan Hood "What's measured is what matters" targets and gaming English public health care system | WebSearch | factual | LSE eprints (card) |
| 17 | Cox "What's wrong with risk matrices" Risk Analysis 2008 | WebSearch | contrarian | paywalled list |
| 18 | US Army A Leader's Guide to After-Action Reviews TC 25-20 four questions | WebSearch | factual | TC 25-20 mirror (card) |
| 19 | Gary Klein premortem project failure prospective hindsight Mitchell Russo Pennington 1989 30 percent original | WebSearch | factual | paywalled list |
| 20 | Lehtinen Mantyla problem causes software projects retrospective Recurring opinions productive improvements 13% | WebSearch | evaluative | Lehtinen Springer (blocked), arXiv 2502.03570 (not carded) |
| 21 | agile retrospectives effectiveness team learning | OpenAlex adapter | evaluative | leads only |
| 22 | postmortem reviews software projects organizational learning | OpenAlex adapter | factual | Desouza/Dingsøyr 2005 lead |
| 23 | after action review effectiveness team learning | OpenAlex adapter | factual | Tannenbaum record, hospice AAR lead |
| 24 | project risk management practice effectiveness empirical | OpenAlex adapter | evaluative | Rabechini 2013 (card) |
| 25 | project status reporting bias software projects | OpenAlex adapter | factual | Snow & Keil 2002 (card), Anandasivam 2009 lead |
| 26 | Goodhart law performance measurement dysfunction | OpenAlex adapter | factual | Bevan & Hamblin 2008 lead |
| 27 | retrospective meetings agile software teams improvement | OpenAlex adapter | evaluative | Matthies 2019 lead |
| 28 | What is wrong with risk matrices Cox | OpenAlex adapter | contrarian | Elmontsri 2014 lead (Cox not indexed) |

Gaps not searched: pre-registered null/Goodhart for developer-productivity metrics (DORA/SPACE) and quality-gate
effectiveness evidence (e.g. DoD adoption studies) fell outside this pass; no source for either is cited.

## Triage-out list

| Source | Reason |
|--------|--------|
| incident.io, hyperping, Atlassian, upstat, itoc360 and similar postmortem guides | Vendor content marketing; restate SRE book; unsourced statistics |
| TeamRetro "178 Agile statistics" page | Vendor stats page; unsourced figures (e.g. 24% responsiveness, 20% balanced performance) |
| Watermelon-status blogs (Cascade, Pragmatic Coders, Cultivated, Medium, Substack, etc.) | Vendor or opinion pieces with no evidence; mechanism covered by Snow & Keil |
| MIT Sloan "The Pitfalls of Project Status Reporting" | Blocked by Cloudflare to the fetcher; could not verify quotes |
| Thomas & Uminsky 2020, arXiv 2002.08512 | Fetched (abstract verified) but AI-specific, lower authority than Bevan & Hood; superseded for Goodhart evidence |
| Bevan & Hamblin 2008 ambulance targets | Adapter abstract only; narrower than Bevan & Hood 2006 |
| Anandasivam & Premm 2009 (survey, n = 91) | Abstract only via adapter; overlaps Snow & Keil; thin |
| Desouza, Dingsøyr, Awazu 2005 postmortems; Dingsøyr 2007 | Abstract only / paywalled; no outcome evidence |
| Matthies 2019 ICSE-Companion; Milani/Storey 2025 (arXiv 2502.03570, n = 19) | Doctoral-symposium abstract and tiny survey; retro-data-use topic only |
| Elmontsri 2014 and Capogna/Bull 2022 risk-matrix pieces | Abstract-level adapter hits; mild critiques; Cox 2008 is the real source but paywalled |
| Hospice AAR poster (BMJ SPCare 2025) | Conference abstract; single-site; healthcare |
| Lehtinen 2017 (Springer) and Aalto theses | Fetcher blocked; moved to paywalled list; 13% figure unverified |
| Etsy Debriefing Facilitation Guide | Blocked (JavaScript challenge) |
| Wikipedia risk register / premortem pages, Medium premortem posts | Tertiary or marketing |
| Hacker News thread 28352828 | Carded but band reject; illustration only |

## Notes

- The first adapter call omitted `--out`, so it wrote 5 auto-generated "retrospectives-0N" cards and 4 snapshots into
  /Users/noah/dev/borg-collective/docs/research/{sources,snapshots}/ (untracked). My cleanup was denied by the
  permission classifier, so those files remain for the operator to delete. None of them are part of this corpus.
