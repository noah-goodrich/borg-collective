# Phase 3.5 — Independent Citation Verification Report

**Synthesis agent ID:** a04a6912dfd5143ce (Track A source-card drafting subagent; card-drafting work
was split across parallel track subagents, including ab7765818a88a83b6 and ada98faf16a2489da — this
report cites the first as the canonical synthesis ID).

**Verifier agent ID:** a8fe87c01d2802e09 (Round 1 verification subagent, run with no shared context
from the source-drafting agents or each other). Three further independent rounds followed, each its
own fresh subagent: Round 2 under a2c9189a18f55c336, Round 3 under adc0b29ccf0a1b0f2 and
a285c3430abbdf3a4 (two parallel full-corpus passes), plus a fourth and final direct-verification pass
performed by the orchestrating session itself using raw `curl`/Python exact-substring checks rather
than agent relay, after the agent-based passes kept finding (and occasionally introducing) errors.

**This report does not follow the single-sample happy path.** It documents four rounds because the
first three rounds found real problems, including two outright fabricated quotes and one fix (my own)
that introduced a new fabricated word. That history is the actual finding here and is preserved rather
than summarized away.

## Final ledger (read this first; per-round detail follows below)

| Metric | Value |
|---|---|
| Sample size | 21 of 21 cards (100%) — every card checked at least once across rounds 1-4 |
| Failed | 0 |
| Failure count | 0 |
| Cumulative defects found and corrected across rounds 1-3 | 7, including 2 fabricated quotes |
| Band | <=5% |

Final failure count: 0 (state after correction, confirmed by direct exact-substring re-check against
freshly-fetched raw source content for every corrected card in Round 4). Failure-rate band: <=5% in the
final state; individual round bands were >10%, >5%-10%, and >10% before correction, detailed below.

The 0 above is the state AFTER remediation, confirmed by direct exact-substring re-check against
freshly-fetched raw source content for every corrected card (Round 4). It is not a claim that the first
pass was clean — the per-round history below shows exactly the opposite, on purpose.

## Round 1 — sample of 7 (33%), systematic (every 3rd file, offset 1)

6 verified, 1 failed (`empirical-vertical-slicing-agent-navigation.md`, wrong section location — quote
itself was genuine). Failure rate 14.3% — gate FAILS (threshold ≤5%).

## Round 2 — fresh, non-overlapping sample of 7 (33%), systematic (every 3rd file, offset 2)

4 verified, 3 failed:
- `empirical-nimblepros-clean-architecture-guardrails.md` — **fabricated quote**, does not exist on the
  cited page.
- `practitioner-fowler-harness-engineering.md` — **fabricated quote** plus two mis-sectioned real quotes.
- `mechanical-enforcement-repocompliancebench.md` — mislocated (Section 1 vs. claimed Section 4.1),
  resolving a disagreement with Round 1's more lenient pass on the same card.

Failure rate 42.9%. Both fabricated cards were regenerated from real, independently-fetched source
content (not repaired in place) and self-verified by their author agent via direct substring check.

## Round 3 — full remaining corpus (21 of 21 cards, not a sample), two parallel agents

Purpose: given actual fabrication was found twice, a sampled gate no longer provided adequate
confidence — every card got checked at least once.

11 verified, 7 more issues surfaced (all real text, no further fabrication from whole cloth, but real
defects): 2 mislocations on cards never previously sampled
(`context-eng-anthropic-effective-context-engineering.md`,
`context-eng-formal-architecture-descriptors.md` — the latter also had a truncated quote and a wrong
publication date), 1 still-mislocated card despite an earlier "fix"
(`context-eng-jeremydmiller-codebase-is-the-prompt.md`), 1 case where the Round-2 fabrication fix itself
introduced a **new** fabricated word ("representations," never checked against the real source —
`empirical-formal-architecture-descriptors.md`), 1 splice+mislocation on a card never previously sampled
(`practitioner-akita-clean-code-ai-agents.md`), 1 cosmetic quote-mark mismatch
(`practitioner-furdak-vsa-claude-skill.md`), and 1 fresh unmarked-truncation find on a card never
previously sampled (`practitioner-nimblepros-clean-architecture.md`).

## Round 4 — direct final correction pass (orchestrating session, not a subagent)

Given the pattern across Rounds 1-3 (errors entering during agent-to-agent relay, including the
verifier's own repair introducing a new one), the final round abandoned agent delegation for this step.
The orchestrating session fetched every flagged source directly (`curl` with browser headers where
needed to clear bot protection; `WebFetch` with an explicit verbatim-text request as a fallback for one
site that fully blocks `curl`), extracted the real text with Python HTML-stripping + entity-decoding,
and checked every corrected quote as a literal exact substring before considering it fixed. All 7 cards
flagged as still-defective after Round 3 were corrected and individually confirmed with a passing
substring match against freshly-fetched raw content:

| File | Defect fixed | Self-check (same-actor, not blind — see note below) |
|---|---|---|
| context-eng-anthropic-effective-context-engineering.md | mislocation (2 skipped paragraphs) | confirmed |
| context-eng-formal-architecture-descriptors.md | wrong date, mislocation, truncated quote | confirmed |
| context-eng-jeremydmiller-codebase-is-the-prompt.md | mislocation (opening vs. second paragraph) | confirmed |
| empirical-formal-architecture-descriptors.md | fabricated word from the Round-2 fix, removed | confirmed |
| practitioner-akita-clean-code-ai-agents.md | unmarked splice + mislocation | confirmed |
| practitioner-furdak-vsa-claude-skill.md | quote-mark type mismatch | confirmed |
| practitioner-nimblepros-clean-architecture.md | unmarked truncation + quote-mark + mislocation | confirmed |

Note: "confirmed" here means the orchestrating session, the same actor that made the correction,
re-checked the corrected quote as an exact substring against freshly-fetched raw content. That is a
real check, not a rubber stamp, but it is not blind third-party review, so this report deliberately
avoids labeling it with the same word used for the independent Round 1-3 outcomes. Treat these 7 cards
as corrected-and-self-confirmed, distinct from a card that passed an independent review round untouched.

## Final state

All 21 cards in the corpus have now been checked at least once by an independent pass, and every
identified defect has been corrected and directly re-checked for an exact substring match against
freshly-fetched source content. **Two cards were rewritten from scratch** (fabricated quotes replaced
with real ones); **five cards had targeted corrections** (location references, ellipsis marking,
quote-mark fidelity, one publication date). Every one of those 7 corrections counts as a failure in the
round it was found, per this report's own rule that a corrected card is never recorded as verified — the
Round 4 re-check confirms the fix landed, it does not retroactively upgrade the original finding.

**Headline finding stress-tested separately and explicitly:** `empirical-constraint-decay-clean-
architecture.md` (the −9.1±1.6pp Clean Architecture penalty, the single most load-bearing result in this
research) was verified with extra scrutiny in Round 3 — paper existence, author/date/venue, the exact
figure in Table 3(a), and the controlled (not correlational) nature of the manipulation were all
confirmed directly against the arXiv HTML. It holds up with no caveats.

**Honest assessment of what this process revealed, independent of this research's actual conclusions:**
LLM-drafted "verified" citations — even when the drafting agent is explicitly instructed to fetch and
check — are not reliably verified on the first attempt, and a single round of independent re-verification
is not sufficient either; this corpus needed four rounds, including one round where the *correction*
itself introduced a new error. Anyone treating a single citation-verification pass (by any actor,
including a supposedly independent one) as sufficient confidence should treat that as optimistic.
