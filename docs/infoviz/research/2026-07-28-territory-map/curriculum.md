Generated: 2026-07-28

# Infoviz Reading Course: Seven Tracks, One Question Per Book

Companion to analysis.md (the territory map). This is the standalone course: per subfield, the 3-6 canon
sources, why each earns its slot, the order to read them in, and the question to hold in your head while
reading. Tracks are ordered by relevance to the program goal (complex operational information that passes an
ELI10 readability test), matching the relevance map in analysis.md section 3.

**First read, per the territory map's recommendations:** Stephen Few, *Information Dashboard Design*,
Chapter 1 (the single-screen definition and the 13 mistakes), paired the same week with the free Google SRE
"Monitoring Distributed Systems" chapter at sre.google. Few gives you the design constraint; the SRE chapter
shows the same constraint derived independently from pager fatigue, in a domain you already live in. Every
other track hangs off the vocabulary those two establish.

A note on how to read all of this: every source below carries an evidence level on its card (1 = systematic
review, 2 = controlled experiment, 7 = expert opinion, 8 = personal story). Sixteen of the 36 are Level 7.
Respect the opinions, but do not confuse them with the experiments.

## Track 1: Dashboards & operational/monitoring UI (read first)

Track question: is this one screen, does it show exceptions, and is every interrupt urgent AND actionable?

1. **Few, *Information Dashboard Design* (2006/2013).** Read first because it defines the artifact: a
   dashboard fits on a single screen, monitorable at a glance, or it has "transgressed the boundaries of a
   dashboard." Everything later in the track builds on or argues with this. Hold: which of the 13 mistakes
   is my current status page committing?
2. **Budiu / NN/G, "Information Foraging" (2019, free).** The cognitive why underneath Few's what: users
   satisfice, and scent (titles, hierarchy, above-the-fold content) decides where they look. Hold: where
   does my layout leak scent?
3. **Ewaschuk / Google SRE, "Monitoring Distributed Systems" (2016, free).** The same glanceable-exception
   logic derived from production incident response, plus the alert/dashboard boundary and the four golden
   signals. Hold: which of my alerts would fail the urgent-actionable-user-visible test?
4. **Tariq et al., "Alert Fatigue in Security Operations Centres" (ACM Computing Surveys, 2025).** The
   Level 1 evidence that the alert-triage boundary is still an open research problem at industry scale.
   Hold: where does the science actually stop?
5. **Brownlow, "Dashboards are Dead" + "3 Years Later" (2020/2023).** The contrarian close: even a
   well-designed dashboard fails when asked to do storytelling, lookup, and analysis at once. Hold: what
   jobs is my dashboard being asked to do, and which should move elsewhere?

## Track 2: Perception & graphical cognition (read second)

Track question: what does a human eye actually register in one glance, and for which 30% of people does the
standard advice not hold?

1. **Ware, *Information Visualization: Perception for Design* (preface + Ch. 1-2).** The most readable entry
   point; frames why perception science matters before you hit the primary papers. Hold: which of my design
   habits have a perceptual mechanism behind them, and which are just habits?
2. **Cleveland & McGill, "Graphical Perception" (1984).** The foundational experiment: position beats length
   beats angle beats area beats volume. Paywalled; the ranking and design are summarized on the card, and
   the next read re-verifies it. Hold: which channel carries my most important number?
3. **Heer & Bostock, "Crowdsourcing Graphical Perception" (2010, free).** The modern replication with far
   larger samples, plus new results on area judgment and gridlines. Hold: where did the 1984 ranking hold,
   and where did it crack?
4. **Simons & Chabris, "Gorillas in Our Midst" (1999, free).** The half of perception the encoding papers
   assume away: without attention, half your viewers miss the gorilla. Hold: what on my dashboard depends on
   somebody happening to look?
5. **Davis et al., "The Risks of Ranking" (2022, free on arXiv).** The live debate: up to 30% of people
   deviate from the average-observer ranking. Hold: who is my actual audience, and what if they are not
   "best with the Bar"?

## Track 3: Visual encoding & the grammar of graphics (read third)

Track question: table or chart, and does the loudest channel carry the most important attribute?

1. **Bertin, *Semiology of Graphics*, via the Sluis retrospective (free).** The 1967 ground floor: two
   planar variables, six retinal variables. Hold: which variables am I already using without naming them?
2. **Munzner, *Visualization Analysis and Design* (What-Why-How chapters; free slides and videos at the
   book site).** Bertin modernized into marks and channels, plus the expressiveness and effectiveness
   principles. Hold: does my encoding imply an order the data does not have?
3. **Wickham, "A Layered Grammar of Graphics" (2010, free).** Theory becomes a tool: data, mappings, geoms,
   scales, facets. Hold: can I describe my chart as a sentence in this grammar?
4. **Remshard & Queenborough, tables vs. charts (2023, free on PMC).** The practical fork you will hit
   weekly: tables for precision and lookup, charts for pattern. Hold: what is the reader's task, precisely?
5. **Elavsky, "Minimalism and the absurdity of the data-to-ink-ratio" (2025, free).** The stress test: read
   last so the clean-minimal instinct built by 1-4 gets challenged with the Bateman evidence. Hold: when
   does stripping ink start excluding readers?

## Track 4: Narrative & explanatory visualization (read fourth)

Track question: what are the three solid points, and do the words live on the chart or beside it?

1. **Segel & Heer, "Narrative Visualization" (2010, free).** The shared vocabulary: seven genres, visual and
   structural tactics, and the author-vs-reader control spectrum. Hold: who controls the pacing of my
   explanation, and did I choose that?
2. **Cairo, *The Truthful Art* (2016).** The values ceiling: truthful, then functional, then beautiful.
   Hold: am I about to make something engaging at accuracy's expense?
3. **Schwabish, "Three Ways to Annotate Your Graphs" (2018, free).** The single most reusable ELI10
   technique in the corpus: direct labels, active titles, on-chart detail. Hold: does my title state the
   finding or just the axes?
4. **Storybench, NYT climate scrollytelling interview (2022, free).** Theory applied end-to-end: sketch
   first, pair paragraphs with visuals, cut to three solid points. Hold: what would I cut from my current
   explainer to protect three takeaways?
5. **Kosara, "The Scrollytelling Scourge" (2016, free).** The contrarian gut-check, read last so you adopt
   scroll-driven narrative only where it earns its cost. Hold: does continuous scroll fit my discrete steps?

## Track 5: Interaction & exploration (read fifth)

Track question: would a well-designed static view beat this interactive one for the actual task?

1. **Shneiderman, "The Eyes Have It" (1996).** The Mantra and the seven tasks; the vocabulary every later
   source assumes. Hold: which of the seven tasks does my design actually serve?
2. **Craft & Cairns, "Beyond Guidelines" (2005, free).** Read immediately after: the Mantra is widely cited
   and never validated. Hold: how much weight was I about to put on it?
3. **Cockburn, Karlson & Bederson, overview+detail / zooming / focus+context review (2008, free).** The
   mechanism layer, with documented failure modes per technique. Hold: which family fits my task, and what
   is its known failure mode?
4. **Nielsen, "Progressive Disclosure" (2006, free).** The applied pattern closest to daily dashboard work,
   with the two-level ceiling. Hold: did I classify anything frequently needed as secondary?
5. **Mosca, Ottley & Chang, "Does Interaction Improve Bayesian Reasoning with Visualization?" (2021, free
   on arXiv).** The falsification check: interaction can significantly detract. Hold: what is my evidence
   that this widget helps?

## Track 6: Network, hierarchy & graph visualization (read sixth; first if a DAG project is live)

Track question: which representation family fits this graph's size, density, and task?

1. **Shneiderman, "Tree Visualization with Tree-Maps" (1992, free).** The most intuitive alternative to
   node-link trees, born from a full 80MB disk. Hold: what does area buy me, and what does it cost?
2. **Laubheimer / NN/G, "Treemaps" (2019, free).** The immediate critique: area is not preattentive, small
   categories drown. Hold: is my comparison task precise or approximate?
3. **Ghoniem, Fekete & Castagliola, node-link vs. matrix (2004/2005, free).** The landmark experiment:
   past ~20 vertices, matrices win most tasks except path-finding. Hold: how big is my graph, really?
4. **Kosara, "Graphs Beyond the Hairball" (2012, free).** The plain-language bridge: change representation
   family instead of patching the hairball. Hold: am I tuning a layout when I should switch families?
5. **Holten, "Hierarchical Edge Bundles" (2006).** The leading clutter fix for compound graphs, and its
   costs. Hold: do I need cluster structure more than path tracing?
6. **Burch et al., empirical-evaluation survey (2021, free).** The capstone: what replicated, what split by
   task, what remains open. Hold: which of my beliefs from reads 1-5 just got complicated?

## Track 7: The field itself (read anytime; a fine hour-zero orientation)

Track question: whose advice is this, and what evidence level does it rest on?

1. **Makulec, "Starting Out in Data Visualization Today" (2022, free).** The field's own map of itself and
   its canon; independently confirms the cross-school picks in this course. Hold: what does the field think
   a newcomer needs?
2. **Munzner, "A Nested Model for Visualization Design and Validation" (2009, free).** The academic
   vocabulary: four nested levels, upstream errors cascade. Hold: at which level is my current design
   mistake living?
3. **Cairo, *How Charts Lie* (2019).** The practitioner counterweight: charts are visual arguments, and
   context beats rules. Hold: where does my chart argue rather than report?
4. **Bateman et al., "Useful Junk?" (2010, free).** The experiment that complicated minimalism: equal
   accuracy, better recall for embellished charts. Hold: which field "rules" are actually contested?
5. **Few, "Why Most Dashboards Fail" (2007, free).** Read last, with the rigor lens from 2-4 switched on:
   an unhedged claim from consulting practice, useful and unproven at once. Hold: can I now spot the
   difference between a finding and a strong opinion?

## Suggested pacing

One track every two weeks fits around a full-time job: the papers are short and the books are skimmable at
the chapter level. Tracks 1 and 2 are the load-bearing pair; if the program gets cut short, finishing those
two plus Schwabish's annotation piece (Track 4, read 3) still delivers most of the ELI10 payoff. Free
sources are marked; the paywalled items (Cleveland & McGill, Ware's interior chapters, Holten's full text,
the Munzner and Cairo books) all have card-level summaries in the sources directory that carry the
load-bearing claims with verified quotes.
