# Source: Stephen Few — "Information Dashboard Design"

**Full citation:** Few, Stephen. *Information Dashboard Design: The Effective Visual
Communication of Data* (1st ed. O'Reilly Media, 2006; 2nd ed. retitled *Information
Dashboard Design: Displaying Data for At-a-Glance Monitoring*, Analytics Press, 2013).
**URL:** http://public.magendanz.com/Temp/Information%20Dashboard%20Design.pdf (full-text
scan of the 1st edition, cross-checked against publisher/reviewer pages:
https://www.oreilly.com/library/view/information-dashboard-design/0596100167/ and
https://www.amazon.com/Information-Dashboard-Design-At-Glance/dp/1938377001)
**Date accessed:** 2026-07-28
**Evidence level:** 7 (Expert Opinion / Thought Leadership — grounded in perceptual
psychology but this specific text is a practitioner synthesis, not a formal study)
**Research topic area:** Dashboards & operational/monitoring UI — canonical design theory

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 8/10 | Few founded Perceptual Edge and has consulted on dashboard design for two decades; this is the most-cited dashboard design text in the practitioner canon, but he is not an academic and the book is not peer-reviewed. |
| 2 | Evidence Quality | 6/10 | Draws on visual-perception and cognitive-psychology research (preattentive attributes, working-memory limits) but the "13 mistakes" taxonomy itself is derived from Few's own consulting observations, not a controlled study. |
| 3 | Currency | 7/10 | Published 2006/2013; screen resolutions and BI tooling have changed, but the core claim (perceptual/cognitive limits on at-a-glance monitoring) is a timeless principle, earning a partial bonus. |
| 4 | Intent | 6/10 | Educational in framing, but Few runs a paid consultancy and sells related training/books — a clear indirect commercial interest. |
| 5 | Bias & Objectivity | 6/10 | Strongly prescriptive ("gauges and meters are usually mistakes") with limited engagement with dissenting design philosophies; still cites concrete counter-examples of bad practice rather than strawmanning. |
| 6 | Logic & Coherence | 8/10 | Each of the 13 mistakes is argued from a specific perceptual or cognitive mechanism (e.g., single-screen requirement tied to working-memory span), not just assertion. |
| 7 | Corroboration | 8/10 | The single-screen/at-a-glance definition is echoed independently by NN/g's UX research and by SRE-community dashboard practice (see companion cards in this set). |
| 8 | Intellectual Honesty | 7/10 | Acknowledges dashboards are "a form of presentation, not a specific type of information or technology" and that display-mechanism choice is context-dependent, but rarely flags where his own prescriptions might fail. |
| 9 | Specificity | 8/10 | Concrete, named taxonomy (13 mistakes, specific figures/screenshots of real BI products: Business Objects, Treasury Board of Canada). |
| 10 | Relevance | 10/10 | This is the origin text for "dashboard" as a design category and for glanceability as a design constraint — directly on-topic. |

**Score band:** keep (weighted average ≈ 7.15)

## Bias Guard Check

- [x] Neutral / no strong reaction — the "single screen, at-a-glance" definition is
  widely adopted and not itself controversial; scored on its stated merits.

## Key Findings

- Few's canonical definition: a dashboard must fit entirely on one screen and be
  monitorable "at a glance" — anything requiring scrolling or screen-switching has
  "transgressed the boundaries of a dashboard."
- Dashboards should show abbreviated summaries/exceptions, not full operational detail,
  because "you cannot monitor at a glance all the details needed to achieve your
  objectives."
- Display mechanisms (gauges, meters, traffic lights) should be chosen for communication
  clarity, not visual novelty — "cute displays lose their spark in a matter of days and
  become just plain annoying."
- Names 13 recurring dashboard-design failure modes, the first and most load-bearing of
  which is exceeding the single-screen boundary.
- Frames dashboard design as "more science than art" — an argument for treating
  glanceability as an engineerable, perceptually-grounded constraint rather than a taste
  question.

## Verified Quote(s)

**Location reference:** Chapter 1, section defining "dashboard" (original Intelligent
Enterprise magazine definition, reproduced early in Ch. 1; verified against full-text PDF
scan, surrounding "Exceeding the Boundaries of a Single Screen" material in Ch. 3 section
3.1).

> A dashboard is a visual display of the most important information needed to achieve
> one or more objectives; consolidated and arranged on a single screen so the
> information can be monitored at a glance.

> A dashboard fits on a single computer screen. The information must fit on a single
> screen, entirely available within the viewer's eye span so it can all be seen at once,
> at a glance. If you must scroll around to see all the information, it has transgressed
> the boundaries of a dashboard.

> An effective dashboard is the product not of cute gauges, meters, and traffic lights
> [...] but rather of informed design: more science than art, more simplicity than
> dazzle. It is, above all else, about communication.

**Access status:** live (full-text scan fetched and searched directly; quotes verified
character-for-character against the PDF; cross-checked title/edition against publisher
and Amazon listings)

## Inclusion Decision

**Decision:** Core
**Rationale:** This is the origin point for "dashboard" as a design category and for
glanceability as an explicit constraint (single-screen, at-a-glance). Every later source
in this subfield (SRE monitoring philosophy, NN/g information-scent research, the
"death to dashboards" contrarians) argues either from or against this definition, making
it the anchor text for the curriculum.

**Redundancy check:** Not redundant — no other keeper source in this set supplies the
formal taxonomy of dashboard-design failure modes or the canonical single-screen
definition; other sources apply, extend, or rebut it.

**Perspective category:** Practitioner
