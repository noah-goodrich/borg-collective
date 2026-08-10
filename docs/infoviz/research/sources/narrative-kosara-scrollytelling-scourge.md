# Source: Kosara, "The Scrollytelling Scourge" (2016)

**Full citation:** Kosara, Robert. "The Scrollytelling Scourge." eagereyes.org. May 25, 2016.
**URL:** https://eagereyes.org/blog/2016/the-scrollytelling-scourge
**Date accessed:** 2026-07-28
**Evidence level:** 7 (Expert Opinion / Thought Leadership — an argued critique from a recognized
practitioner-researcher, not an empirical study of scrollytelling's effects)
**Research topic area:** Narrative & explanatory visualization — live debate over scroll-driven
narrative structure vs. discrete stepper navigation

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 8/10 | Robert Kosara is a former Tableau Research scientist and co-author (with Jock Mackinlay) of the peer-reviewed "Storytelling: The Next Step for Visualization" (IEEE Computer, 2013); he writes eagereyes.org as a long-running, widely-read practitioner/research blog in the InfoVis community, but this specific post is an unreviewed personal blog opinion, not a peer-reviewed artifact. |
| 2 | Evidence Quality | 3/10 | The post is argument-from-experience and design critique, not backed by a formal usability study or data in this specific piece — it names named failure patterns (scroll-jacking, missing progress indicators) but does not cite measured reader outcomes. |
| 3 | Currency | 7/10 | Published 2016 (pre-2020 tier by strict date), but the underlying critique of continuous-scroll interaction mismatched to discrete narrative steps is a design-principle argument that has aged well — corroborated by a 2023 ACM ECCE empirical paper on scrollytelling's cognitive costs (see Corroboration below), earning a partial timeless-principle allowance. |
| 4 | Intent | 8/10 | Independent professional opinion/field advancement on a personal research blog, no commercial angle; written to push back on a design trend the author sees as harming readers, not to sell a product. |
| 5 | Bias & Objectivity | 6/10 | (Scored harder per bias guard — I find this critique persuasive.) The post is explicitly one-sided advocacy for steppers over scrolling and does not seriously steelman cases where scrollytelling demonstrably outperforms a stepper; it does concede "if you absolutely have to use scrolling" there's a right way to do it, which is a partial acknowledgment. |
| 6 | Logic & Coherence | 7/10 | (Scored harder per bias guard.) The argument (continuous scroll input mismatched to discrete narrative steps causes disorientation and split attention) is internally consistent and mechanistically plausible, though it rests on assertion more than demonstrated data within this piece. |
| 7 | Corroboration | 7/10 | Corroborated by the 2023 ACM ECCE paper "The Impact of Scrollytelling on the Reading Experience of Long-Form Journalism" (dl.acm.org/doi/fullHtml/10.1145/3605655.3605683), and by the broader industry "peak scrollytelling" backlash discourse referenced across multiple practitioner outlets (Nightingale, Storybench). |
| 8 | Intellectual Honesty | 6/10 | (Scored harder per bias guard.) Kosara names a caveat path ("if you absolutely have to use scrolling, read... Mike Bostock's How to Scroll") rather than claiming scrolling is never acceptable, but the post's overall tone is more polemical than hedge-everything academic writing. |
| 9 | Specificity | 8/10 | Names concrete, checkable failure modes: scroll-jacking, no length/progress indicator, no ability to jump between steps, and the specific mismatch between continuous scroll and discrete narrative steps. |
| 10 | Relevance | 9/10 | Directly targets the exact live-debate axis the brief asks for (scrollytelling as a genre/technique within narrative visualization) and is the most commonly cited contrarian counterpoint to scrollytelling boosterism in secondary sources found during this research (e.g. Nightingale's "Past, Present, and Future of Scrollytelling"). |

**Score band:** borderline (weighted average sits in the 5.9-6.3 range once Authority 25% and
Evidence Quality 20% are weighted against a single-author, non-empirical blog post; included
anyway as the corpus's designated Contrarian voice and the clearest concrete articulation of the
scrollytelling live debate — see Inclusion Decision).

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings

- Kosara's central mechanical objection: scrolling is a continuous input, but narrative steps are
  discrete — the mismatch is what causes disorientation, not scrollytelling's visuals per se.
- Named failure modes: "scroll-jacking" (the page hijacking natural scroll momentum), no
  indication of how long a piece is, and no way to jump directly to a specific step.
- A specific attention-cost claim: readers must choose between watching animated graphics and
  reading overlaid scrolling text, and often can't do both — "read the text, and you miss the
  graphics."
- Kosara's prescribed alternative is a stepper (explicit next/previous or click-through controls)
  rather than scroll-triggered progression, arguing this preserves clear navigation.
- Coda recommendation is a two-tier hedge: use Mike Bostock's documented scroll-implementation
  guidance if scrolling is unavoidable, "but even better: don't" — leaving room for scrollytelling
  done carefully rather than banning it outright.

## Verified Quote(s)

**Location reference:** Body text of the 2016-05-25 eagereyes.org post, in the paragraphs
discussing scroll-jacking and the text/graphics attention conflict.

> I do not want your stupid website to interfere with the scrolling because your little
> JavaScript thinks that I'm scrolling too fast

> Text scrolls over the animated graphics, and you have to watch the action while scrolling or
> you'll miss it. Try to read the text, and you miss the graphics

> If you absolutely have to use scrolling, read - and heed - Mike Bostock's *How to Scroll*. But
> even better: don't.

**Access status:** live (fetched directly from eagereyes.org at evaluation time; quotes verified
in-place).

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Named as the designated Contrarian card for this corpus per the brief's
perspective-diversity requirement. It scores borderline on the weighted rubric (Authority 8 but
Evidence Quality only 3, and it is a single unreviewed blog post), so it is included deliberately
as the corpus's weakest keep, not because it clears the bar cleanly — its real value is naming the
live debate (scroll vs. stepper) concretely enough for a future deep-dive, corroborated by an
independent 2023 empirical paper.

**Redundancy check:** Not redundant with the Storybench NYT card — that card shows scrollytelling
practiced well by a newsroom; this card is the field's sharpest naming of when and why it fails,
giving the curriculum both sides of the same technique.

**Perspective category:** Contrarian
