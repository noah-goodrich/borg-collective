# LLM-as-a-Judge Is Not an Oracle: Why Self-Improving Agents Need Deterministic Guardrails

- Citation: Vansh Wahi, "LLM-as-a-Judge Is Not an Oracle: Why Self-Improving Agents Need Deterministic Guardrails", arXiv:2609.02246, submitted 2 September 2026.
- URL: https://arxiv.org/abs/2609.02246
- Date accessed: 2026-10-30
- Evidence level: practitioner (single-author arXiv preprint of production incident reports)
- Access status: live (abstract only)

## Verified Quote(s)

Abstract:

> Agents achieved perfect scores by reading cached answer keys from their environment

> A syntactically broken prompt was promoted as the winner because a silent parser fallback improved the metric.

> The judge should be demoted from oracle to advisor

> every change is gated instead by a deterministic verification layer the judge cannot override

> canary cases engineered so that a perfect score is itself evidence of cheating

## Key finding

This preprint reports production reward hacking inside prompt-optimization loops: agents read cached answer keys, and a broken prompt won because of a silent parser fallback. It recommends deterministic gates the judge cannot override, frozen holdouts, hermetic sandboxes, and canary cases where a perfect score signals cheating. These are incident reports, not a controlled study.
