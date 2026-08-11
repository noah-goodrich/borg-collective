# Infoviz Learning Program — Phase 1 Findings Synthesis

**Date:** 2026-07-30
**Sub-project:** Graphical perception & encoding effectiveness (Cleveland-McGill → Heer/Bostock → Davis et al. →
Bertin → Munzner → Wickham), plus the overview-first/zoom mantra (Shneiderman → Craft & Cairns →
Cockburn/Karlson/Bederson) as the evidence base for Noah's standing multi-level/semantic-zoom requirement.

## Phase-1 design record (stated per Step 1)

**Why this sub-project, not Track 1 (Dashboards):** the curriculum.md sequences Track 1 (Few + Google SRE) as
"read first" for *operational* framing, but explicitly calls Tracks 1+2 "the load-bearing pair" and states
"every other track hangs off the vocabulary those two establish." The user's brief defaults to graphical
perception/encoding unless the inventory "clearly sequences a different first" track — the inventory does not;
it sequences dashboards first for practical/operational reasons, not because perception is less foundational.
Tracks 2 (Perception) + 3 (Encoding) together are the literal Cleveland-McGill → Munzner → Bertin → Ware core
named in the brief, so that pairing is this sub-project. Track 5's Shneiderman/Cockburn material is pulled in
because Noah flagged multi-level/semantic zoom as a standing requirement and the evidence for it lives there.

**Six questions this sub-project answers:**
1. Which visual channel (position, length, angle, area, color, etc.) should carry the most important number in
   a chart, and how strong is the evidence for that ranking?
2. Has the 1984 ranking held up under modern, larger-sample replication — and where has it cracked?
3. Does one ranking apply to everyone, or do individuals vary enough that "the average observer" is a
   misleading design target?
4. What is the theoretical vocabulary (Bertin's retinal variables → Munzner's marks/channels → Wickham's
   grammar layers) for describing *why* a channel choice works, not just that it does?
5. When does a table beat a chart outright, regardless of channel choice?
6. What is the evidence basis for overview-first/zoom/details-on-demand (the "Mantra") as a design requirement
   for multi-level/semantic-zoom navigation, and how solid is that evidence really?

**Sources used** (all pulled from the Phase-0 corpus at
`borg-collective:docs/infoviz/research/sources/*.md`, cross-checked against 2026 web search where noted):
Cleveland & McGill 1984 [pre-2020], Heer & Bostock 2010 [pre-2020], Davis et al. 2022/2023 [2020-2023],
Ware *Information Visualization* 3rd ed. 2012 [pre-2020], Simons & Chabris 1999 [pre-2020], Bertin 1967/1983
(via Sluis 2016 retrospective) [pre-2020], Munzner *VAD* 2014 (via Romanowski 2023 review) [2020-2023],
Munzner "Nested Model" 2009 [pre-2020], Wickham "Layered Grammar" 2010 [pre-2020], Remshard & Queenborough
2023 [2020-2023], Elavsky 2025 [2024-2026], Shneiderman "Eyes Have It" 1996 [pre-2020], Craft & Cairns 2005
[pre-2020], Cockburn/Karlson/Bederson 2008 [pre-2020]. Supplemented with two 2026-era WebSearch passes
(below) to check for anything materially newer than the Phase-0 corpus.

---

## Findings

### 1. The channel-effectiveness ranking (the core claim)

Cleveland & McGill's 1984 JASA paper established, via controlled psychophysics experiments, a ranking of
"elementary perceptual tasks" by decoding accuracy: **position (common scale) > position (non-aligned scale) >
length ≈ direction ≈ angle > area > volume ≈ curvature > shading/color saturation**
(borg-collective card `perception-cleveland-mcgill-1984.md`, summarizing Cleveland, W.S. & McGill, R.,
*JASA* 79(387), 1984, pp. 531-554, https://www.tandfonline.com/doi/abs/10.1080/01621459.1984.10478080 —
paywalled; ranking corroborated via secondary summary since primary text is behind a paywall). This is the
theoretical basis for the now-common design advice "prefer bar/dot charts (position/length) over pie charts
(angle) or 3D/volume encodings" for quantitative comparison.

**Practical takeaway:** if a chart has one number that matters most, put it on a shared position/length scale
(bar height, dot position on an axis) rather than angle, area, or color saturation.

### 2. Modern replication mostly held, with one crack

Heer & Bostock (2010, CHI, open access, https://vis.stanford.edu/papers/crowdsourcing-graphical-perception)
replicated Cleveland & McGill's core spatial-encoding and luminance-contrast findings using ~hundreds of
Mechanical Turk subjects and found results that "match previous work, are consistent with theoretical
predictions" — but explicitly noted at least one divergence: "Cleveland & McGill also did not find angle to
perform worse [...]" where the MTurk replication did. They also extended the program to rectangular-area
judgment (relevant to treemaps/cartograms) and chart-size/gridline effects the 1984 paper never tested. A 2026
WebSearch pass found no full-scale re-replication superseding Heer & Bostock since 2010, but did surface an
active 2026 line of work on channel *pair separability* in symbol maps (arXiv 2602.20022, "Studying the
Separability of Visual Channel Pairs in Symbol Maps") — evidence the topic is still being actively
re-examined in 2026, not settled and shelved.

### 3. The ranking is a population average, not a universal law — Davis et al.'s live debate (2020s)

Davis, Pu, Ding, Hall, Bonilla, Feng, Kay & Harrison, "The Risks of Ranking: Revisiting Graphical Perception to
Model Individual Differences in Visualization Performance," *IEEE TVCG* / VIS 2022, published 2023
(https://arxiv.org/abs/2212.10533) — re-ran Cleveland & McGill's own experimental paradigm with Bayesian
multilevel regression to model individual-level rather than only average-observer effects. Headline finding:
**"as much as 30% of people are likely not 'best with the Bar'"** — i.e., roughly a third of viewers may not
perform best with the encoding the canonical ranking would recommend as universally optimal. Crucially, the
paper does **not** reject the canonical ranking — it states its results "largely agree with canonical rankings
of these visualization types" at the population level, and instead argues the field should stop reporting only
average-observer rankings and start reporting full individual-level distributions. This is corroborated
independently by PubMed (https://pubmed.ncbi.nlm.nih.gov/37015487/) and a 2024 web summary characterizing it
as a "notable replication and extension... using Bayesian multilevel regression" — confirming this is treated
as a live, credible complication of the canon, not a fringe claim, as of 2024-2026.

**Practical takeaway:** design for the population-level ranking as a strong prior, but do not assume it holds
for every viewer — for high-stakes or accessibility-sensitive displays, pair the "best" channel with a
redundant secondary cue (e.g., direct labels) rather than relying on channel choice alone.

### 4. Attention gates perception before channel-ranking even applies

Simons & Chabris, "Gorillas in Our Midst," *Perception* 28(9), 1999, pp. 1059-1074
(http://www.chabris.com/Simons1999.pdf) — the famous "invisible gorilla" experiment. In a controlled,
randomized, n=192 study, only 54% of observers doing an attention-demanding task (counting basketball passes)
noticed a fully visible, unexpected event in the same visual field; detection dropped further under harder
task load (64% "Easy" vs. lower "Hard" — exact Hard-condition percentage not independently re-extracted here,
flagged as a minor gap). Two design-relevant findings: (a) detection depends on how visually similar the
unattended anomaly is to the actively monitored items, not on raw visual salience; (b) spatial proximity to
attended locations did *not* reliably help — "observers attend to objects and events, not spatial positions."
This is a distinct mechanism from Cleveland-McGill's channel-decoding-accuracy question: it addresses whether
a viewer notices the datum at all, not how accurately they read it once looked at. Both mechanisms matter for
dense operational displays and are commonly conflated in casual dashboard-design discussion — this is worth
flagging explicitly in the playbook.

### 5. The vocabulary layer: Bertin → Munzner → Wickham

- **Bertin** (*Sémiologie Graphique*, 1967/1983, accessed via Sluis retrospective,
  https://karlsluis.medium.com/before-tufte-there-was-bertin-63af71ceaa62) established two planar variables
  (x/y position) plus six "retinal variables" that can layer on top of position: size, value (lightness),
  texture/pattern, color (hue), orientation, shape. This is the pre-computational ancestor of every later
  channel taxonomy, but the framework was "never implemented as a computer program" and doesn't anticipate
  interactive/dynamic visualization — a 50+-year-old gap the field has filled with later work, not Bertin
  himself.
- **Munzner**'s What-Why-How framework (*Visualization Analysis and Design*, 2014; accessed via Romanowski
  2023 review, https://www.datarocks.co.nz/post/data-viz-bookshelf_visualization-analysis-design-tamara-munzner,
  and Munzner's own nested-model paper, *IEEE TVCG* 15(6), 2009,
  https://www.cs.ubc.ca/labs/imager/tr/2009/NestedModel/NestedModel.pdf) modernizes Bertin's variables into
  "marks" (points/lines/areas — the geometric primitives) and "channels" (position/color/size/shape — how
  marks appear), plus two governing principles: **expressiveness** (show all and only the information in the
  data; do not imply false order on unordered data) and **effectiveness** (match channel salience to attribute
  importance — put the most important attribute on the most perceptually salient channel, which is precisely
  Cleveland-McGill's ranking operationalized as a design rule). Munzner's separate nested-model paper adds the
  structural warning most relevant to a systems-minded audience: **"an upstream error inevitably cascades to
  all downstream levels"** — a wrong task/data abstraction cannot be fixed by good visual-encoding work later.
- **Wickham**'s "A Layered Grammar of Graphics" (*JCGS* 19(1), 2010, pp. 3-28,
  https://vita.had.co.nz/papers/layered-grammar.html), the theoretical basis for ggplot2, turns the taxonomy
  into a compositional grammar: data, aesthetic mappings, geoms, stats, scales, coordinate systems, facets —
  each an independent, combinable layer rather than a pick-one-of-N chart-type menu. Its practical proof is a
  decade-plus of dominance in R (ggplot2) plus direct ports to Python (plotnine), Kotlin (Lets-Plot), Julia
  (Gadfly) — the grammar generalizes across language ecosystems, not just one tool.

### 6. Tables beat charts for precision/lookup, not pattern-spotting

Remshard & Queenborough, *Ecology and Evolution* 13(7), e10062, 2023 (open access,
https://pmc.ncbi.nlm.nih.gov/articles/PMC10346464/): "tables are advantageous when the purpose is to extract
specific information, precise numerical values, or ranks," while "charts encode data values as position,
length, size, or color, and support readers when making comparisons, predictions, or perceiving patterns and
trends." This is a clean task-based fork, not a taste preference: ask "does the reader need to look up an
exact number, or spot a trend?" before picking table vs. chart.

### 7. The minimalism/data-ink counter-case (contrarian, load-bearing for the playbook)

Elavsky, "Minimalism and the absurdity of the data-to-ink-ratio," frank.computer, April/May 2025
(https://www.frank.computer/blog/2025/04/data-to-ink.html) — argues Tufte's data-ink ratio, taken literally,
is "a rough heuristic and not even remotely a real, working 'theory' of any kind," and cites Bateman et al.
(CHI 2010) as controlled evidence that embellished ("chartjunk") charts produced **no worse comprehension
accuracy and significantly better 2-3-week recall** than minimalist charts — directly contradicting the naive
assumption that decoration always harms comprehension. Note: Bateman et al. itself was not independently
re-fetched in the Phase-0 pass or this one — flagged below as a should-verify-directly item, since the claim
is currently resting on Elavsky's citation of it plus independent secondary summaries, not a first-hand read.

### 8. The zoom mantra: influential, unvalidated as a whole, but its mechanisms are well-studied

Shneiderman's "Eyes Have It" (1996 IEEE VL, https://ieeexplore.ieee.org/document/545307 — paywalled, quote
corroborated via secondary sources) proposed **"Overview first, zoom and filter, then details-on-demand"** —
the Mantra — alongside a seven-task taxonomy (overview, zoom, filter, details-on-demand, relate, history,
extract). This is Level-7 (expert opinion), explicitly a synthesis of Shneiderman's own design experience, not
an experiment. Craft & Cairns, "Beyond Guidelines" (IV'05, 2005,
https://faculty.cc.gatech.edu/~john.stasko/8001/craft05.pdf), reviewed the literature citing the Mantra and
found **"no reasonably obvious studies that have validated Shneiderman's recommendations"** as a whole — but
explicitly do not claim it's wrong: **"For most designers, the Mantra works."** This is a call for evidence,
not a rebuttal.

Where the *mechanisms* that implement the Mantra are concerned, the evidence is much stronger: Cockburn,
Karlson & Bederson's ACM Computing Surveys review (2008, Level 1 systematic review,
https://faculty.cc.gatech.edu/~stasko/7450/Papers/cockburn-surveys08.pdf) aggregates dozens of controlled
studies across four technique families — **overview+detail** (spatial separation), **zooming** (temporal
separation, i.e., semantic zoom), **focus+context** (fisheye-style, no separation), and **cue-based**
(brushing/highlighting) — and finds **no single technique dominates across tasks**: fisheye views let people
read text faster, but overview+detail produced better document comprehension in one cited study (Hornbaek et
al.); real shipped interfaces got this wrong (Apple's Mac OS X Dock fisheye magnification measurably harmed
targeting performance despite looking appealing). Documented failure modes per family: overview+detail costs
screen real estate; zooming "is easy to do badly" and creates cognitive load from temporal discontinuity
unless transitions are animated; focus+context distortion impairs relative spatial judgment.

A 2026 WebSearch pass found active current work applying semantic zoom specifically to multi-level/hierarchical
domains: "Semantic Zoom and Mini-Maps for Software Cities" (IEEE VISSOFT, Sept 2025, arXiv 2510.00003) and
"Semantic Zooming and Edge Bundling for Multi-Scale Supply Chain Flow Visualization" (arXiv 2604.08823,
2026) — both report improved task performance / reduced navigation time for zoom-driven macro↔detail
representation switching versus flat node-link layouts, corroborating (with modern domain-specific
experiments) that the *zooming* family in Cockburn et al.'s taxonomy remains an active, evidence-backed pattern
for exactly Noah's multi-level/semantic-zoom use case — while still carrying the "easy to do badly" caveat.

**Practical takeaway for Noah's standing zoom requirement:** the Mantra itself is unvalidated as an end-to-end
prescription, but its *zooming* mechanism specifically (not overview+detail or focus+context) has direct,
current (2025-2026) empirical support for hierarchical/multi-level domains, conditional on smooth
transitions/animation to avoid the documented cognitive-discontinuity failure mode.

---

## Evidence gaps and uncertainties

- Cleveland & McGill (1984) itself is paywalled; this synthesis relies on the Phase-0 card's secondary-summary
  ranking, not a first-hand read of the original methodology and discussion sections. Flagged as a paywalled
  must-read below.
- Ware's *Information Visualization* interior chapters (the actual preattentive-processing content, not just
  front matter) are paywalled/print-only; only the preface and TOC were independently verified.
- Bateman et al. (2010, CHI) — the controlled study underpinning the "chartjunk isn't always harmful" claim —
  was not independently fetched in this pass or the Phase-0 pass; it is cited via Elavsky's blog post and
  secondary summaries only. Should be read first-hand before it becomes load-bearing for a playbook rule.
- Simons & Chabris "Hard condition" detection percentage was not independently re-extracted (only the "Easy:
  64%" figure and the aggregate "54%" were verified against the fetched PDF).
- No full re-replication of Cleveland & McGill's original ranking newer than Heer & Bostock (2010) was found;
  the 2026 "channel pair separability" paper (arXiv 2602.20022) addresses a related but distinct question and
  was not read in full — flagged as a lead for a future deep-dive, not verified content here.
- The semantic-zoom 2025-2026 papers found via WebSearch (arXiv 2510.00003, arXiv 2604.08823) were read only
  via search-result summaries, not fetched and verified in full — treat as directional corroboration, not
  verified primary claims, pending a dedicated fetch.

## Paywalled must-reads

- **Cleveland, W.S. & McGill, R. (1984), "Graphical Perception," JASA 79(387), pp. 531-554.**
  https://www.tandfonline.com/doi/abs/10.1080/01621459.1984.10478080 — Why it matters: this is the origin
  experiment for the entire channel-ranking research program; every other source in this synthesis replicates,
  teaches from, or contests it. Access: university library JSTOR/JASA access, or the original 1984 print
  volume via ILL.
- **Ware, C., *Information Visualization: Perception for Design*, 3rd/4th ed., Morgan Kaufmann/Elsevier.**
  Interior chapters (3-7: color/lightness perception, preattentive processing, pattern/object perception) —
  Why it matters: the fullest practitioner-facing synthesis of the vision-science literature into design rules;
  only front matter was verified here. Access: publisher (Elsevier/ScienceDirect) or university library.
- **Shneiderman, B. (1996), "The Eyes Have It," IEEE VL '96, pp. 336-343.**
  https://ieeexplore.ieee.org/document/545307 — Why it matters: the founding statement of the Mantra and
  seven-task taxonomy that every zoom/focus+context/progressive-disclosure paper since cites as ancestor; only
  corroborated via secondary quotation here, not fetched live (IEEE Xplore gate). Access: IEEE Xplore
  subscription or university library.
- ~~**Bateman, S. et al. (2010), "Useful Junk?" CHI 2010** — cited secondhand via Elavsky, not yet independently
  verified.~~ **RESOLVED 2026-08-10.** Read first-hand. Free full text is mirrored at
  https://sites.stat.columbia.edu/gelman/communication/Bateman2010.pdf (DOI record:
  https://dl.acm.org/doi/10.1145/1753326.1753716). Reading it **downgraded P7** rather than confirming it: the
  study is n=20 total with the load-bearing multi-week recall result resting on an **n=10** subgroup, using 14
  charts by a single artist, and the authors explicitly decline to generalize. See the revised P7 in
  `03-design-principles-playbook-additions.md`. Standing lesson: a claim this program had been citing
  secondhand for months was both freely available and weaker than assumed.

## Sources index

| # | Title | URL | Date | Tier |
|---|-------|-----|------|------|
| 1 | Cleveland & McGill, "Graphical Perception" | https://www.tandfonline.com/doi/abs/10.1080/01621459.1984.10478080 | 1984 | pre-2020 (paywalled) |
| 2 | Heer & Bostock, "Crowdsourcing Graphical Perception" | https://vis.stanford.edu/papers/crowdsourcing-graphical-perception | 2010 | pre-2020 |
| 3 | Davis et al., "The Risks of Ranking" | https://arxiv.org/abs/2212.10533 | 2022/2023 | 2020-2023 |
| 4 | Davis et al., PubMed record | https://pubmed.ncbi.nlm.nih.gov/37015487/ | 2023 | 2020-2023 |
| 5 | Ware, *Information Visualization* (preview) | https://api.pageplace.de/preview/DT0400.9780080478494_A23516753/preview-9780080478494_A23516753.pdf | 2012 | pre-2020 (paywalled interior) |
| 6 | Simons & Chabris, "Gorillas in Our Midst" | http://www.chabris.com/Simons1999.pdf | 1999 | pre-2020 |
| 7 | Sluis, "Before Tufte, there was Bertin" | https://karlsluis.medium.com/before-tufte-there-was-bertin-63af71ceaa62 | 2016 | pre-2020 |
| 8 | Romanowski, review of Munzner *VAD* | https://www.datarocks.co.nz/post/data-viz-bookshelf_visualization-analysis-design-tamara-munzner | 2023 | 2020-2023 |
| 9 | Munzner, "A Nested Model" | https://www.cs.ubc.ca/labs/imager/tr/2009/NestedModel/NestedModel.pdf | 2009 | pre-2020 |
| 10 | Wickham, "A Layered Grammar of Graphics" | https://vita.had.co.nz/papers/layered-grammar.html | 2010 | pre-2020 |
| 11 | Remshard & Queenborough, tables vs. charts | https://pmc.ncbi.nlm.nih.gov/articles/PMC10346464/ | 2023 | 2020-2023 |
| 12 | Elavsky, "Minimalism and the absurdity of the data-to-ink-ratio" | https://www.frank.computer/blog/2025/04/data-to-ink.html | 2025 | 2024-2026 |
| 13 | Shneiderman, "The Eyes Have It" | https://ieeexplore.ieee.org/document/545307 | 1996 | pre-2020 (paywalled) |
| 14 | Craft & Cairns, "Beyond Guidelines" | https://faculty.cc.gatech.edu/~john.stasko/8001/craft05.pdf | 2005 | pre-2020 |
| 15 | Cockburn, Karlson & Bederson, overview+detail/zoom/focus+context review | https://faculty.cc.gatech.edu/~stasko/7450/Papers/cockburn-surveys08.pdf | 2008 | pre-2020 |
| 16 | "Semantic Zoom and Mini-Maps for Software Cities" | https://arxiv.org/abs/2510.00003 | 2025 | 2024-2026 (search summary only) |
| 17 | "Semantic Zooming and Edge Bundling for Multi-Scale Supply Chain Flow Visualization" | https://arxiv.org/html/2604.08823v1 | 2026 | 2024-2026 (search summary only) |
| 18 | "Studying the Separability of Visual Channel Pairs in Symbol Maps" | https://arxiv.org/pdf/2602.20022 | 2026 | 2024-2026 (search summary only, not fetched) |
