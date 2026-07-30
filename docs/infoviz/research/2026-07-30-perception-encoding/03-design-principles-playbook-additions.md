# Design Principles Playbook — Phase 1 Additions (Perception & Encoding Effectiveness)

**Date:** 2026-07-30
**Status:** proposed additions for Noah's review; not yet merged into a canonical accreting playbook file
(none found yet in the Phase-0 corpus — recommend the orchestrator create
`docs/infoviz/playbook.md` in borg-collective when integrating, so future phases append rather than
re-derive).

Each rule: the house rule, then the evidence it's traced to, then its confidence/caveat.

---

**P1 — Put the most important number on the highest-ranked channel available: position on a shared scale
first, then length, then angle, then area, then color/shading last.**
Evidence: Cleveland & McGill (1984) ranking, position > length ≈ angle > area > volume > color, replicated at
scale by Heer & Bostock (2010). [Cleveland & McGill 1984; Heer & Bostock 2010]
Confidence: high for population-level design defaults. Caveat: this is a strong prior, not a universal law —
see P2.

**P2 — For high-stakes or accessibility-sensitive displays, never rely on channel choice alone; pair the
top-ranked channel with a redundant cue (direct label, exact value on hover/print).**
Evidence: Davis et al. (2022/2023) found ~30% of viewers deviate from the "average observer" ranking the
Cleveland-McGill rule assumes. [Davis et al. 2022]
Confidence: high that individual variance exists; moderate on the specific 30% figure generalizing beyond the
tested task set — treat as directional, not a universal constant.

**P3 — An anomaly that must be noticed needs to visually stand out from its neighbors, not merely be present
and "visible."**
Evidence: Simons & Chabris (1999) — 46% of attentionally-loaded observers missed a fully visible, unexpected
event; detection depended on dissimilarity from attended items, not on raw visual salience or spatial
proximity to what's already being watched. [Simons & Chabris 1999]
Confidence: high (Level 2 controlled experiment, extremely widely replicated). Caveat: "make it pop" is a
directional design principle here, not a specific pixel/color spec — that specification work is downstream.

**P4 — Match the highest-salience channel to the most important attribute in the data; don't let a
low-priority attribute accidentally grab the loudest channel (Munzner's "effectiveness principle"). Don't
imply an order the data doesn't have (Munzner's "expressiveness principle").**
Evidence: Munzner, *Visualization Analysis and Design* (2014), marks/channels framework, operationalizing the
Cleveland-McGill ranking as a design rule. [Munzner VAD 2014, via Romanowski review 2023]
Confidence: high — this is the field's standard teaching framework, directly derived from P1's evidence base.

**P5 — Ask "does the reader need to look up an exact number, or spot a trend?" before choosing table vs.
chart. Default to a table for precision/lookup tasks; default to a chart for comparison/trend/pattern
tasks.**
Evidence: Remshard & Queenborough (2023) — tables for "specific information, precise numerical values, or
ranks," charts for "comparisons, predictions, or perceiving patterns and trends." [Remshard & Queenborough
2023]
Confidence: high, peer-reviewed, task-based (not aesthetic) framing.

**P6 (STANDING REQUIREMENT — Noah-flagged) — Visualizations of hierarchical/complex operational data should
support navigable multi-level / semantic zoom: an overview by default, with zoom/filter into a level of
detail, and full detail only on demand.**
Evidence chain:
- The requirement's classic articulation is Shneiderman's Mantra: "Overview first, zoom and filter, then
  details-on-demand." [Shneiderman 1996] — but this is Level-7 expert opinion; Craft & Cairns (2005) found "no
  reasonably obvious studies that have validated Shneiderman's recommendations" as a complete prescription,
  while explicitly not claiming it's wrong ("For most designers, the Mantra works"). [Craft & Cairns 2005]
- The *zooming* mechanism specifically (as opposed to the Mantra as a whole) has strong Level-1 evidence:
  Cockburn, Karlson & Bederson's systematic review (2008) confirms zoom-based techniques work but are "easy to
  do badly" — the failure mode is cognitive discontinuity between pre- and post-zoom states, mitigated by
  animated/smooth transitions. No single technique (overview+detail, zooming, focus+context, cue-based)
  dominates for every task; task type should drive the choice. [Cockburn, Karlson & Bederson 2008]
- Recent (2025-2026) domain-specific work applying semantic zoom to large hierarchical/network structures
  (software architecture "cities," supply-chain flow networks) reports improved task performance and reduced
  navigation time for smooth macro↔detail zoom versus flat, all-at-once layouts — current corroboration for
  this exact use case, though only verified via search summaries, not full-text fetch. [arXiv 2510.00003,
  2025; arXiv 2604.08823, 2026 — flagged for follow-up full-text verification]

**Confidence:** the *requirement itself* (build multi-level/semantic zoom) is well-supported at the mechanism
level (Level 1 review + current 2025-2026 domain studies), even though the umbrella "Mantra" it's usually cited
under is Level 7 and formally unvalidated as a complete prescription. Practical implication: justify the zoom
requirement to stakeholders by citing the mechanism-level evidence (Cockburn et al.) and the 2025-2026
domain studies, not by citing Shneiderman's 1996 mantra alone as if it were proven — and always spec animated/
smooth transitions, since jumpy zoom is the documented failure mode.

**P7 — Don't treat "minimalism"/data-ink reduction as an unqualified virtue; strip ink only up to the point it
stops helping, and watch for accessibility exclusion.**
Evidence: Elavsky (2025) — pushing the data-ink ratio to its logical extreme produces imperceptible charts,
showing the ratio alone can't be the design criterion; cites Bateman et al. (CHI 2010, not yet independently
verified — see paywalled must-reads) showing embellished charts had no worse comprehension accuracy and
significantly better multi-week recall than minimalist ones. [Elavsky 2025; Bateman et al. 2010, secondhand]
Confidence: moderate — the critique of literal data-ink-ratio-as-law is well-argued and cites real experimental
evidence, but that underlying experiment (Bateman et al.) has not yet been independently read in this program;
treat P7 as directionally right but re-verify Bateman et al. directly before treating it as fully load-bearing.

---

## Open items for Phase 2+

- Read Cleveland & McGill (1984) and Bateman et al. (2010) first-hand (both currently paywalled/secondhand) —
  see Paywalled must-reads in the findings synthesis.
- Track 1 (Dashboards/operational) is the curriculum's own recommended "read first" — worth doing as Phase 2
  regardless of this sub-project's sequencing choice, since it's the applied layer these principles feed into.
- The 2026 arXiv channel-pair-separability paper and the two 2025-2026 semantic-zoom papers were found via
  WebSearch only (not fetched/verified in full) — good candidates for a dedicated "what's new since Phase 0"
  sweep in a later phase.
