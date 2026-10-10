# S2 search log - re-entry, resumption and handoff (2026-10-04)

Tooling note: the general web-search budget ran out after the first batch of queries (about 8 web queries), so most discovery ran through the scholarly adapter (OpenAlex) with one topic tag per query (a repeated tag overwrites the adapter's numbered output, which cost one re-run). Falsification coverage came from the adapter plus the two pre-exhaustion web queries.

## Queries (adapter unless marked WEB)

| Subtopic | Query | Outcome |
|---|---|---|
| Handoff outcomes | WEB: I-PASS handoff bundle Starmer NEJM 2014 medical errors preventable adverse events | Found Starmer 2014; WUSTL OA PDF and NEJM page 403 |
| Handoff outcomes | Changes in medical errors after implementation of a handoff program | Starmer 2014, 2013 JAMA-era papers, Horwitz editorial |
| Handoff outcomes | I-PASS implementation fidelity multicenter handoff study written handoff | Starmer 2022 (32 hospitals) and nursing QI |
| Handoff outcomes | I-PASS handoff nurses pediatric intensive care implementation results | Starmer 2022, Aiss 2025 nursing QI |
| Handoff content | handoff communication structure content what to include illness severity action list situation awareness contingency | Heilman 2016, Shahid 2018 SBAR narrative review |
| Handoff content | WEB: AHRQ TeamSTEPPS I-PASS mnemonics handoff toolkit | Found I-PASS mnemonic PDF (Starmer 2012), MHS IV |
| Falsification | WEB: I-PASS handoff no significant improvement study failed to reduce adverse events | Orthopaedic I-PASS 2022 null on clinical outcomes |
| Falsification | systematic review standardized handoff tools effectiveness | Rosenthal 2017, Abraham 2013, Patel 2024 mnemonics review, Tarter 2026 |
| Falsification | handoff standardization no improvement null result patient outcomes | Mostly QI theses; no new keeper |
| Falsification | WEB: standardized handoff tools checkbox ritual compliance without information transfer ethnography handover critique | Found ritual and socio-technical ethnography papers (paywalled or 403) |
| SBAR | SBAR communication tool effectiveness systematic review | Muller 2018 BMJ Open, Yun 2023, Kosim 2025, Rasiya 2026 |
| Resumption theory | Resumption strategies for interrupted programming tasks | Parnin and Rugaber 2009, Monk 2004 |
| Resumption theory | Altmann Trafton memory for goals activation-based model | Hodgetts and Jones 2006, Ratwani and Trafton 2007; 2002 Wiley paper 403 |
| Resumption theory | Trafton Altmann preparing to resume interrupted task goal suspension cues | Ratwani 2006, Labonte 2021, Perry 2020 |
| Resumption cues | Evaluating cues for resuming interrupted programming tasks | Parnin and DeLine 2010, Altmann and Trafton 2004, Schneegass 2021 |
| Interruption software work | Iqbal Horvitz disruption and recovery of computing tasks field study | Borst 2015, Moon 2016; Iqbal and Horvitz 2007 itself not indexed |
| Task context tooling | Mylyn task context Kersten Murphy using task context to improve programmer productivity | Kersten and Murphy 2015 AI Magazine, Cruz 2017 |
| Developer practice | task resumption developer notes context switching resumption cue | John and Ruiz 2015, Meyer 2020, Abad 2017, Cruz 2017 |
| Developer practice | WEB: developer getting back into context after interruption notes TODO technique | Programmer, Interrupted (Parnin 2013); several SEO blogs |

## Kept cards (10)

See sources/s2-*.md.

## Triage-outs (cut or not carded)

| Source | Reason |
|---|---|
| Parnin and Rugaber 2009 (ICPC abstract; 2011 SQJ version Springer redirect) | Redundant with Parnin 2013 numbers; abstract-only; 2011 version behind Springer wall |
| Kersten and Murphy 2015 AI Magazine abstract | Generic abstract with no reported effect size; Mylyn productivity result not visible; would be a reject on evidence quality and specificity |
| Muller 2018 SBAR systematic review (BMJ Open) | Good (moderate evidence, low-quality studies) but superseded by MHS IV 2025 for current grade; redundant |
| Rosenthal 2017 standardized handoff tool review | Redundant with MHS IV and Abraham 2013; abstract says mixed outcomes and no mortality effect |
| Horwitz 2013 JAMA editorial | Useful quote ("almost no evidence suggests that improvements in handoffs reduce the rate of subsequent errors") but it is the commentary on the 2013 Starmer paper, pre-dates the evidence base; snapshot is an introduction fragment |
| Borst 2015 "What makes interruptions disruptive" | Computational model plus lab; supports "interrupt at low problem-state moments" but the timing point is already carried by Parnin 2013 and Altmann and Trafton; Academic slot already full |
| Ratwani and Trafton 2007 | Conference fragment; errors follow resumption but redundant |
| Monk 2004 frequent vs infrequent interruptions | Counterintuitive result (faster resumption with more frequent interruptions) but VCR task, not transferable |
| Radovic 2026, Labonte 2021, Perry 2020, Moon 2016, Yin 2014, Puente 2017, Yang 2011 | Off-topic or lab-only; not relevant to re-entry content |
| Shahid 2018 SBAR narrative review | Narrative review asserting SBAR is "reliable and validated"; weaker than systematic reviews |
| Patel 2024 perioperative mnemonics review, Tarter 2026 EMS review, Rasiya 2026 nurses ISBAR review | Setting-specific; adds nothing beyond MHS IV |
| Aiss 2025 nursing I-PASS QI, Gagnier 2016, Mueller 2023, Lakhani 2025 | Single-site QI process outcomes; Heilman retained as the lone frontline voice |
| Content-mill developer-productivity blogs (augmentcode, cubic, guvi, focusbreaks, neurobeatx, pomodorian, locu) | Uncited numbers (15-minute recovery), SEO, product sales intent; rejected |
| Hacker News thread item 35459333 | Not fetched; forum anecdote, would be Level 8 at best |
| ResearchGate: "Examination of current handover practice: Evidence to support changing the ritual" | HTTP 403; contrarian ethnography worth chasing (see paywalled-candidates) |
| ScienceDirect socio-technical ethnographic handover paper | Not fetched (paywall) |
