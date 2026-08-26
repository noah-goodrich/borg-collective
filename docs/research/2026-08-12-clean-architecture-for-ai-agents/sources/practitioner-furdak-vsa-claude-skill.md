# Source: Vertical Slice Architecture for Claude Code — dotnet-vsa-webapi Explained (Vladyslav Furdak)

**Full citation:** Furdak, Vladyslav. "Vertical Slice Architecture for Claude Code: dotnet-vsa-webapi
Explained." furdak.net. March 16, 2026.
**URL:** https://www.furdak.net/articles/dotnet-vsa-webapi-skill
**Date accessed:** 2026-08-12
**Evidence level:** 8 (Anecdotal/Personal Experience — a single practitioner's direct hands-on report
building and using an agent skill, no measurement)
**Research topic area:** Practitioner discourse on agent-ready codebases

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 4/10 | Individual .NET developer/blogger with no apparent major institutional affiliation or broad name recognition beyond his own site; a genuine practitioner voice but a minor one. |
| 2 | Evidence Quality | 4/10 | Personal experience report describing a skill he built for Claude Code, with no measurement of outcomes vs. a layered-architecture baseline. |
| 3 | Currency | 8/10 | Published March 16, 2026, current and specifically framed around Claude Code as the target agent. |
| 4 | Intent | 6/10 | Promotes his own open-source `dotnet-vsa-webapi` skill to a degree, but reads as a genuine technical write-up rather than a hard sales pitch. |
| 5 | Bias & Objectivity | 5/10 | One-sided advocacy for vertical slice architecture; does not seriously engage the Clean Architecture counter-position. |
| 6 | Logic & Coherence | 7/10 | Reasonably coherent mechanism: organizing by use case rather than technical layer reduces the chance an agent "improves" unrelated code while making one change. |
| 7 | Corroboration | 7/10 | Independently corroborates Miller's much higher-authority vertical-slice argument, arrived at via a different route (a Claude-Code-specific skill rather than a general framework essay) — meaningful because it's independent, not because either source alone is strong. |
| 8 | Intellectual Honesty | 4/10 | Pure advocacy piece; does not acknowledge trade-offs or scenarios where vertical slices might underperform layered architecture. |
| 9 | Specificity | 8/10 | Tied to a concrete, real, usable artifact (a published Claude Code skill), not just abstract argument. |
| 10 | Relevance | 9/10 | Directly on-topic and specifically names Claude Code (this org's own agent) as the target, making it unusually directly applicable. |

**Score band:** borderline

## Bias Guard Check
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [x] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

(Noted per the guard: kept despite low authority/objectivity scores specifically because it independently
corroborates Miller's contrarian claim from a different, hands-on angle — a real Claude Code skill, not
just essay-level argument — which is valuable even though the source itself is a minor, one-sided voice.)

## Key Findings
- Argues `dotnet-vsa-webapi` is "especially good" for agentic development because it "forces the agent to
  think in terms of use cases, not technical layers," aligning the codebase's organizing principle with how
  an agent is typically instructed (by feature/task, not by architectural layer).
- Claims vertical slice organization makes it easier for an agent to find the right place to make a change,
  add a new use case, and keep changes local — three properties framed as directly reducing agent error
  surface.
- Identifies a specific agent failure mode this structure is meant to prevent: "when making one change, the
  tool also starts 'improving' everything around it" — i.e., scope creep during autonomous edits, which
  feature-local code is argued to contain better than a layered structure would.
- Lists concrete claimed benefits: fewer unnecessary abstractions, fewer layers for the sake of layers, less
  "magic," more transparency, more local changes, and better code readability.
- Unlike Miller's essay-level argument, this source is tied to a shipped, usable artifact — a Claude Code
  skill readers can install and run directly — giving it a hands-on, boots-on-the-ground character distinct
  from purely argumentative pieces in this track.

## Verified Quote(s)

**Location reference:** Body of the article, sections explaining why the skill targets agentic development
specifically.

> "It is especially good because it forces the agent to think in terms of use cases, not technical layers."

> "This is especially important in agentic development because it reduces a typical AI problem: when making
> one change, the tool also starts "improving" everything around it at the same time."

> "fewer unnecessary abstractions; fewer layers for the sake of layers; less magic; more transparency; more
> local changes; better code readability."

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** Kept at borderline specifically as independent, tool-level corroboration of Miller's
higher-authority contrarian claim — a real Claude-Code-targeted skill built on vertical-slice principles,
not just an essay arguing the same point.
**Redundancy check:** Overlaps substantially with Miller in conclusion, but adds a distinct evidentiary
form (a shipped, installable skill rather than argument alone) and is the only kept source naming Claude
Code specifically as its target agent; named as this track's lowest-scoring kept source per the REAL-CUT
rule and defended above rather than back-filled with a stronger substitute.
**Perspective category:** Boots-on-the-ground

---
