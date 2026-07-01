# Staged-Deployment Platform Primitives — Native vs Build

*Deep-research deliverable, 2026-06-12. Informs the cross-project staged-deployment standard and the
`/borg-deploy` skill. Sources + verification: `sources/` + `verification-report.md`.*

## Question

For a solo, AI-orchestrated developer, which staged-deployment capabilities are already provided by native
platform primitives (so a thin `/borg-deploy` wrapper suffices) and which genuinely require custom
orchestration? Platforms: Fly.io, Vercel, Supabase, GitHub Actions/Environments. Capabilities: (1)
dependency-ordered rollout with a health gate, (2) auto-rollback on a failed post-deploy health check, (3)
staging / gated promotion, (4) progressive / preview rollout.

## Matrix

| | 1. Ordered rollout + health gate | 2. Auto-rollback on failed health check | 3. Staging / promotion | 4. Progressive / preview |
|---|---|---|---|---|
| Fly.io | Native single-service gate (`bluegreen`/`canary`, needs >=1 healthcheck) | Build — no rollback command; manual redeploy of prior image | Build (separate apps per env) | Partial (canary; no %-traffic) |
| Vercel | Deployment Checks (not wired to ordering) | Build — Instant Rollback is manual | Native (preview + `vercel promote`) | Native (Rolling Releases, 1-99%; Pro/Ent) |
| Supabase | Migration required-check | Build | Native (preview branches + merge-promote; Pro) | None |
| GitHub Actions/Env | Ordering lives here (`needs:`, reusable workflow) | The layer where you build it | Native gate (Environments + required reviewer + wait timer) | None |

## Synthesis

**Wrap (native — a thin `/borg-deploy` wrapper suffices):**

- The per-service health gate of capability 1 is native: Fly `bluegreen`/`canary` halt the deploy when a
  Machine health check fails; Vercel Deployment Checks and Supabase required migration checks gate their own
  surfaces.
- Capability 3 (staging / promotion) is native on Vercel (preview deployments + `vercel promote`) and
  Supabase (per-PR preview branches + merge-triggered migration promotion).
- Capability 4 (progressive / preview) is native on Vercel (Rolling Releases, 1-99% stages) and partial on
  Fly (canary).

**Build (genuine custom orchestration):**

- Capability 2 — automatic rollback on a FAILED post-deploy health check — is native on none of the four. All
  rollbacks are manual or deploy-time-abort only. Build it by wiring a health probe / Checks API to trigger
  `vercel rollback` or `fly deploy --image <prev>`.
- Capability 1's cross-service ORDERING (deploy A, wait for A healthy, then deploy dependent B) lives in CI —
  GitHub Actions `needs:` within one workflow, wrapping each platform's per-service gate.

## Mapping to the stacks

- **reveal** (Fly backend + Next.js/Vercel frontend + Postgres): native health-gating on Fly and native
  progressive rollout + promote on Vercel; the custom pieces are auto-rollback and the Fly-backend-then-Vercel
  ordering — the exact gap behind the "frontend 500s if it ships before the backend" risk.
- **ingle / troth** (Supabase + Next.js): native preview branching + gated migration promotion on Supabase,
  native promote/rollback on Vercel; again the only custom piece is auto-rollback.

## Caveats

- Vercel Rolling Releases and Supabase preview branching are paid-tier (Pro/Enterprise).
- The GitHub-primitive cell was the weakest in the harness run (no direct-quote claim survived there); it is
  corroborated by the separately-verified GitHub Environments documentation in `sources/08`.
- These features change often; re-verify against the primary docs in `sources/` before building.

## Open questions (carried into design)

- Canonical recipe + race-safety for custom auto-rollback on each platform.
- Whether Fly has any native staging/promotion beyond separate-apps-per-environment.
- Which layer owns the reveal ordering: Fly backend + Postgres migration + Vercel frontend promote.
