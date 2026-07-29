# Citation Verification Report — InfoViz Territory Map Source Cards

**Synthesis agent ID:** phase0-discovery-fleet-wf
**Verifier agent ID:** independent-citation-verifier-icv-20260728
**Date:** 2026-07-28
**Card corpus:** /Users/noahgoodrich/dev/infoviz/docs/research/sources (36 cards)

## Sample

**Sample size:** 11 of 36 cards (30.6%; protocol minimum = ceil(36 x 0.30) = 11).
**Selection method:** deterministic seeded random sample — Python `random.seed(20260728)` then
`random.sample()` over the alphabetically sorted filename list; first-and-only draw taken, no re-rolls.
Reproducible: any party re-running the same seed over the same file list gets the identical sample.

**Sampled cards:**

1. field-cairo-how-charts-lie.md
2. field-munzner-nested-model.md
3. interaction-shneiderman-eyes-have-it.md
4. narrative-cairo-truthful-art.md
5. narrative-segel-heer-2010.md
6. networks-ghoniem-nodelink-vs-matrix.md
7. networks-kosara-hairball-critique.md
8. operational-few-dashboard-design.md
9. operational-nng-information-foraging.md
10. perception-simons-chabris-1999-gorillas.md
11. perception-ware-information-visualization.md

## Method

For each card: (1) fetched the card URL fresh (curl with browser UA; pdftotext for PDFs; WebFetch as a
second attempt where curl failed); (2) searched the fetched content for every "## Verified Quote(s)" block
character-for-character after tolerated normalization only (smart-vs-straight quotes, dash variants,
whitespace collapse, PDF line-break hyphenation); (3) confirmed the quote is attributed to the card URL's
host; (4) confirmed the stated location reference (section-level). No synthesis or analysis document was
read; only the source cards and the live sources. Stale downloads found in the shared scratchpad from a
prior session were ignored — all verification ran against this session's fresh fetches.

## Per-Card Outcomes

| # | Card | URL host | Fetch | Quotes | Outcome | Notes |
|---|------|----------|-------|--------|---------|-------|
| 1 | field-cairo-how-charts-lie.md | eagereyes.org | live (200) | 3/3 exact | verified | All three quotes verbatim in the review body; card correctly credits them to the review, not the book. |
| 2 | field-munzner-nested-model.md | cs.ubc.ca | live (200, PDF) | 2/2 exact | verified | Q1 verbatim in Abstract; Q2 verbatim in Section 1 Introduction (para position within off-by-one tolerance). |
| 3 | interaction-shneiderman-eyes-have-it.md | ieeexplore.ieee.org | blocked (HTTP 202, empty body; WebFetch also empty) | n/a | inaccessible | Card explicitly flags "Access status: cached/partial" with paywall/bot-gate explanation, so protocol outcome is inaccessible, not failed. Mantra quote is corroborated by the card's named secondary sources but could not be independently re-verified against the primary URL. |
| 4 | narrative-cairo-truthful-art.md | coolinfographics.com | live (200) | 2/2 exact | verified | Both quotes verbatim inside Cairo's interview answers. Note: Q2 ("as simple as possible, but not simpler") is introduced on the page by Cairo as "that old maxim commonly attributed to Einstein" — the card omits that provenance nuance, but the quote is genuinely present in Cairo's answer at the card URL. |
| 5 | narrative-segel-heer-2010.md | vis.stanford.edu | live (200, PDF — better than the card's cached/partial TLS-mismatch claim) | 2/2 exact (Q2 with unmarked truncation) | verified | Q1 verbatim. Q2 wording is character-for-character but the source sentence continues (", in some cases allowing the visualization to function in place of a written story."); the card ends it with a period and no ellipsis. Words are verbatim, location (abstract, sentences 1-2) correct — not a paraphrase. |
| 6 | networks-ghoniem-nodelink-vs-matrix.md | www-sop.inria.fr | live (200, PDF) | 2/2 exact | verified | Abstract quote verbatim on p.1; conclusion quote verbatim immediately under the "5 CONCLUSION" heading. |
| 7 | networks-kosara-hairball-critique.md | eagereyes.org | live (200) | 3/3 exact | verified | Q1 is the first sentence under the "Hairballs" heading; Q2 within the Hairballs section; Q3 under "The Graph Beyond the Graph" — all three location refs exactly right. |
| 8 | operational-few-dashboard-design.md | public.magendanz.com | live (200, full-text PDF scan) | 4/4 exact | verified | Definition quote sits directly after "Here's my definition, which originally appeared in Intelligent Enterprise magazine" — matching the card's location claim precisely. "Cute gauges" quote verbatim near Figure 1-1 (Ch. 1 material). Bracketed ellipsis in the card correctly marks omitted text. |
| 9 | operational-nng-information-foraging.md | nngroup.com | live (200) | 2/2 exact | verified | Q1 verbatim in the opening animal-foraging/information-foraging terminology table (Scent row). Q2, which the card cautiously labels "paraphrase-adjacent," is in fact verbatim in the body ("the scent is given by the title, images, and..."). Author (Raluca Budiu) and date (November 10, 2019) match the page exactly. |
| 10 | perception-simons-chabris-1999-gorillas.md | chabris.com | live (200, PDF) | 3/3 exact | verified | All quotes character-for-character, including the odd "change direction" (the fetched PDF's own text reads "change direction," so the card transcribed the artifact faithfully). Both Results quotes are in the Results section as claimed (printed p. 1068). Note: the card's "p. 526 / p. 533 of the PDF pagination" numbers correspond to nothing in the 17-page PDF (printed pp. 1059-1074) — page refs are wrong, but the section + paragraph descriptions are correct, which passes the protocol's section-level location test. |
| 11 | perception-ware-information-visualization.md | api.pageplace.de | live (200, publisher preview PDF) | 3/3 exact | verified | Q1/Q2 verbatim on the page stamped "Page xxi" under "PREFACE TO THE FIRST EDITION"; Q3 verbatim on "Page xxiv" in the Chapter 5 synopsis — both match the card's location refs. Note: the preview's typesetting stamps read 2004, suggesting the preview is 2nd-edition front matter while the card cites the 3rd ed. (2012); front-matter text is shared across editions and the domain attribution is correct, so this is a metadata nuance, not a quote failure. |

## Aggregate Counts

| Outcome | Count |
|---------|-------|
| verified | 10 |
| failed | 0 |
| inaccessible | 1 |
| **sampled** | **11** |

## Failure Rate

failure rate = failed / (verified + failed) = 0 / (10 + 0) = **0.0%**

**Band: <=5%**

## Verifier Observations (non-scoring)

- Quote fidelity in this sample is unusually high: 24 of 24 checkable quote strings matched
  character-for-character after tolerated normalization, including faithful transcription of a source-side
  typo (Simons & Chabris "change direction").
- Two cards carry defensible but imperfect location metadata (Simons & Chabris page numbers; Ware edition
  ambiguity). Neither meets the protocol's failure bar (wrong section / wrong host), but both are worth a
  cleanup pass.
- One card (Segel & Heer) under-claims access: the URL flagged as TLS-broken fetched live over plain HTTP
  in this session, so its quotes are now verified against the primary PDF, not just the cached snippet.
