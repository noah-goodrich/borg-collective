# Source: Artima interview: Tracer Bullets and Prototypes (Hunt and Thomas)

**Full citation:** Bill Venners, interviewing Andy Hunt and Dave Thomas. "Tracer Bullets and Prototypes." Artima Developer, 2003-04-21. https://www.artima.com/intv/tracer.html. Accessed 2026-10-13.
**URL:** https://www.artima.com/intv/tracer.html
**Date accessed:** 2026-10-13
**Evidence level:** 7 (expert interview, original authors)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | The authors of The Pragmatic Programmer explaining their own concept. |
| 2 | Evidence Quality | 3/10 | Reasoning and analogy, no data. |
| 3 | Currency | 5/10 | 2003; the concept is timeless so a bonus is applied. |
| 4 | Intent | 8/10 | Educational interview. |
| 5 | Bias & Objectivity | 7/10 | Authors advocate their own idea. |
| 6 | Logic & Coherence | 8/10 | Clear contrast: tracer code is kept, prototypes are thrown away. |
| 7 | Corroboration | 8/10 | Reflected in Matt's article and the book's wide adoption. |
| 8 | Intellectual Honesty | 7/10 | Explains the trade-off versus 'specifying the system to death'. |
| 9 | Specificity | 7/10 | Concrete skeleton-application and database example. |
| 10 | Relevance | 8/10 | Origin of the term Matt applies to tickets. |

**Score band:** borderline (weighted average about 6.75). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings

- The software analogue of firing artillery by calculation is specifying everything up front; tracer bullets instead produce something early to adjust aim.
- A skeleton application has one thin line of execution end to end, then features are added one use case at a time.
- Prototypes are for learning and 'designed to be thrown away'; tracer code is kept, which is why Matt separates /prototype from tracer-bullet tickets.
- The original framing is explicitly against up-front specification, which sits in tension with writing a PRD before slicing.

## Verified Quote(s)

**Location reference:** Section 'Building Prototypes', response to the question about management turning a prototype into a tracer bullet.

> Prototypes are designed to be thrown away.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Foundational source for the term; borderline on currency, kept for provenance.

**Redundancy check:** Primary origin text; Matt's article is derivative of it.

**Perspective category:** Practitioner
