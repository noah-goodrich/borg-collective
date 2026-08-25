# Source: Clean Code for AI Agents (AkitaOnRails)

**Full citation:** Akita, Fabio. "Clean Code for AI Agents." AkitaOnRails.com. April 20, 2026.
**URL:** https://akitaonrails.com/en/2026/04/20/clean-code-for-ai-agents/
**Date accessed:** 2026-08-12
**Evidence level:** 7 (Expert Opinion/Thought Leadership — an experienced practitioner's argued opinion, no
controlled measurement)
**Research topic area:** Practitioner discourse on agent-ready codebases

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 7/10 | Fabio Akita is a long-running, widely followed independent practitioner voice in the Ruby/software-engineering community (blogging since the mid-2000s, large YouTube following) — real practitioner standing, not an anonymous or institutional byline. |
| 2 | Evidence Quality | 5/10 | Personal reasoning and worked examples, not measured data; the token/context-window mechanism he invokes is plausible and later corroborated empirically by the SonarSource study, but this piece itself presents no numbers. |
| 3 | Currency | 9/10 | Published April 2026, directly addresses the current Claude-Code/Codex era of agentic coding. |
| 4 | Intent | 8/10 | Personal blog, no product being sold; genuine technical argument aimed at fellow developers. |
| 5 | Bias & Objectivity | 7/10 | Presents a clear, confidently-argued thesis; not adversarial toward alternative views but doesn't seriously entertain a counter-position either. |
| 6 | Logic & Coherence | 8/10 | Clear causal chain from file/function size to tool-call truncation risk to agent reasoning quality. |
| 7 | Corroboration | 8/10 | Directly corroborated by NimblePros and Böckeler's "more structure helps" framing, and empirically by the SonarSource minimal-pair study's token/revisitation findings. |
| 8 | Intellectual Honesty | 6/10 | Asserts the thesis confidently with limited hedging; does acknowledge agents won't do this by default and require explicit written rules. |
| 9 | Specificity | 9/10 | Gives concrete, actionable numbers (under 500 lines, ideally 200-300; small-function-per-tool-call reasoning) and concrete naming examples. |
| 10 | Relevance | 10/10 | Directly named as a required lead for this track; core "clean code re-ranked for AI agents" thesis. |

**Score band:** keep

## Bias Guard Check
- [x] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings
- Argues that in 2026, "the AI agent is the new compiler" — the primary reader of most code is now an agent,
  so clean-code heuristics should be re-ranked by what reduces an agent's token cost and context-window
  pressure, not by what reduces human cognitive load.
- Keeping files under roughly 500 lines (ideally 200-300) is framed as a technical requirement, not a style
  preference, because it lets an agent "grab the whole unit of meaning in one call."
- Small functions are reframed from a readability nicety into "a technical obligation," since a small
  function "fits in a single tool call without truncation."
- Distinctive, greppable naming (e.g., `UserRegistrationValidator`) is argued to matter more for agents than
  humans because agents rely heavily on search-based navigation rather than IDE "go to definition."
- Explicitly argues these behaviors are NOT default agent behavior — "No LLM does any of this by default...
  You need to WRITE these rules" — positioning explicit written conventions as necessary scaffolding.

## Verified Quote(s)

**Location reference:** Quotes 1-2 are in the body sections on file size and function size
(early-to-middle of the article). Quote 3 is in "Instructing the agent to write clean code," one of the
last two sections (~76% through the article) — corrected 2026-08-12; the original card mislocated it as
being in the same early section as quotes 1-2.

> "A short file (keep it under 500 lines, ideally 200-300) fits in a single read."

> "For an agent, that recommendation became a technical obligation. A small function fits in a single tool
> call without truncation."

> "no LLM does any of this by default. [...] You need to WRITE these rules. The agent reads, the agent
> follows." (corrected 2026-08-12: the omitted middle is Akita's concrete failure-mode list — "No
> dependency injection. 80-line functions. No tests, or tests that mock the wrong thing. Duplicated logic
> because it's faster. 2000-line files because 'everything's in one place'." — originally spliced out
> with no ellipsis mark; now honestly marked as a cut rather than presented as continuous.)

**Access status:** live

## Inclusion Decision
**Decision:** Core
**Rationale:** One of two named track leads, and the clearest single practitioner statement of the "more
explicit structure helps agents" thesis with concrete, actionable thresholds — a load-bearing source for
this track's central question.
**Redundancy check:** Distinct from NimblePros (which argues at the macro-architecture/CI-enforcement level)
and from Böckeler (framework-level, institutional) — Akita's contribution is the file/function-granularity
mechanism (token budget, tool-call truncation) that the others don't cover in this much detail.
**Perspective category:** Practitioner

---
