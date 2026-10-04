# C1 search log (job aids and visual design) - 2026-10-03

Adapter: scholarly-adapter.sh search ... --topic c1 --limit 5 --out <drafts/adapter> (OpenAlex). Adapter-emitted cards live
under drafts/adapter/sources/c1-0*.md and are drafts only; none were kept as final cards (results were off-topic or low
relevance; titles listed below).

## Queries (varied framing; F = falsification)
Cognitive load / chunking / recognition:
1. adapter: "cognitive load theory critique falsifiability" (F) - returned unrelated papers (relational emergence, Popper); cut.
2. WebSearch: "cognitive load theory criticism de Jong 2010 food for thought instructional science" (F) - kept de Jong 2010.
3. WebSearch: "Cowan 2001 magical number 4 in short-term memory reconsideration of mental storage capacity" - kept.
4. WebSearch: "Nielsen Norman Group recognition rather than recall usability heuristic" - kept NN/g heuristic 6.
5. WebSearch: "working memory deficits ADHD meta-analysis Kofler 2018 OR Martinussen 2005" - kept Kofler 2020.
Multimedia / dual coding / pictures:
6. adapter: "multimedia learning principles meta-analysis" - adapter cards (overview of research, cueing meta-analysis) not
   carded; WebSearch "Mayer multimedia learning principles meta-analysis effect sizes..." - kept Mayer-corpus meta-analysis 2025.
7. WebSearch: "dual coding theory Paivio critique evidence pictures aid memory limitations" (F) - kept Higdon 2025.
8. WebSearch: "Carney Levin 2002 Pictorial illustrations still improve students' learning from text" - paywalled candidate.
9. WebSearch: "patient education handouts readability layout effectiveness systematic review pictograms" - kept Wang and Voss 2021.
Checklists / job aids:
10. adapter: "surgical safety checklist effectiveness systematic review" - adapter cards (effectiveness of implementation, paediatric
    checklists) not carded; superseded by primary sources below.
11. WebSearch: "Haynes 2009 surgical safety checklist reduce morbidity mortality NEJM pubmed" - kept Haynes 2009.
12. WebSearch: "Urbach 2014 Introduction of surgical safety checklists in Ontario no significant reduction NEJM" (F) - kept.
13. WebSearch: "checklist fatigue box-ticking ethnography why checklists fail operating theatre qualitative study" (F) - kept
    Thomassen 2010, Fourcade 2012; Weiser and Haynes 2018 found via the Urbach result list.
14. adapter: "job aids performance support effectiveness" - returned maternal-health/navy job-aid papers; none fit; cut.
15. WebSearch: "Rossett job aids performance support when to use job aid vs training" - Rossett handbook paywalled; summary
    only (not cited as evidence).
Pre-attentive / colour:
16. WebSearch: "Few Tapping the Power of Visual Perception preattentive attributes perceptualedge" - kept Few 2004.
17. WebSearch: "color coding interface visual search benefit and harm too many colors study" (F) - results seen (Christ 1975,
    2022 Frontiers colour-coding, arXiv colour schemes); not fetched; Christ 1975 listed as paywalled candidate.
Handout design:
18. WebSearch: "CDC Clear Communication Index scoring criteria ..." - kept CDC Index user guide 2019.

## Triage-outs (cuts)
- Fusco et al. 2025, "Visual Perception and Pre-Attentive Attributes in Oncological Data Visualisation" (PMC12292122, read):
  redundant with Few; oncology-visualisation scope. Used only as a corroboration note in the Few card.
- redasadki.me blog "Mayer's research proves text works better" (fetched, JSON-LD only): practitioner opinion, low authority; cut.
- Jelacic et al. 2023 aviation-style checklists in the OR (PMID 37879776): off-topic for design features; cut.
- Adapter outputs for "job aids" (Navy maintenance job aids, antenatal counseling, health worker performance): domain mismatch; cut.
- Adapter output "Measuring cognitive load ... metrics" and "Popper as self-vaccination": irrelevant; cut.
- Wikipedia / Medium / UX blog pages from search results: tertiary, not fetched.
- Springer pages (de Jong, Carney and Levin, Thomassen original) and the CDC PDF host returned blocks to automated fetch;
  alternative open copies (Twente portal, PMC, fetch-tool PDF) used.

## Honest gaps
- Chunking in printed aids: only Cowan abstract and the CDC seven-item rule; no experiment tying chunk counts to sheet comprehension.
- Colour-coding benefit/harm: search results seen but no primary study fetched; claims limited to Few and a corroborating review.
- Job-aid theory (Rossett) not read from primary text; Gawande's Checklist Manifesto and Ware's book not accessed.
- Several cards rest on abstracts only (flagged cached/partial).
