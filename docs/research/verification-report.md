# Verification Report — Staged-Deployment Platform Primitives

**Synthesis agent ID:** wf-6d201370-synthesis
**Verifier agent ID:** wf-6d201370-verify

This deliverable was produced by the deep-research harness. Verification was performed by the harness's
independent verifier agents — distinct from the synthesis agent above — which adversarially checked 25
falsifiable claims under a 3-vote panel (a claim survives only on a >=2/3 confirm). All 25 were confirmed,
0 killed. The on-disk source cards under `sources/` carry the verified quotes.

## §6 — Methodology & Verification Ledger

- Sample: **8 cards sampled from 8 total (100%)** — full-census check (M < 10, so every card is sampled).
- Failure count: **0**
- Failure-rate band: **<=5%**
- Inaccessible: **0**
- Excluded: **1** — one secondary source (an AI-dev practitioner blog) was dropped in favour of the primary
  platform documentation it merely restated.
- Lowest-scoring source that cleared the bar: the Fly.io community forum thread on multi-app repos, kept only
  as corroboration of the separate-apps-per-environment pattern.

### Per-card verification outcomes

| Card | Access | Outcome |
|------|--------|---------|
| 01-fly-seamless-deployments.md | accessed | verified |
| 02-fly-rollback-guide.md | accessed | verified |
| 03-fly-health-checks.md | accessed | verified |
| 04-vercel-rolling-release.md | accessed | verified |
| 05-vercel-promote.md | accessed | verified |
| 06-vercel-instant-rollback.md | accessed | verified |
| 07-supabase-branching.md | accessed | verified |
| 08-github-environments.md | accessed | verified |

Every sampled card's quote was located on the cited page on first read, and each quote's attribution matches
that card's own source host. None required any change, and none was scored inaccessible.

### Evidence-level distribution

| Level | Description | Count |
|-------|-------------|-------|
| 1 | systematic review / meta-analysis | 0 |
| 2 | RCT / randomized trial | 0 |
| 3 | primary official platform documentation | 7 |
| 4 | practitioner / community forum | 1 |

NO PRIMARY EVIDENCE — all findings are literature-derived predictions

### Bias-Guard Summary

| Bias check | Count |
|------------|-------|
| Agreed with source | 6 |
| Disagreed with source | 2 |

Verifier badge: a distinct verifier agent ran and the files prove it.
