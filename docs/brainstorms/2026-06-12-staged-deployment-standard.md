I'll assemble the final decision document. This is a formatting/synthesis task using the provided material, so I'll produce the markdown directly.

# Staged-Deployment Standard for a Solo, AI-Orchestrated Developer — Phase 6 Brainstorm Decision

*Date: 2026-06-12 | Tracks: 3 | Options: 7*

---

## Problem Definition

Design a single cross-project **staged-deployment standard** for a solo, AI-orchestrated developer whose AI "nanoprobes" can trigger deploys. It ships **first in reveal** (Fly.io backend + Next.js/Vercel frontend + Postgres), then **ingle/troth** (Supabase + Next.js). Enforcement is via a shared **`/borg-deploy` skill** that reads a per-repo **`deploy.yml`**.

The developer originally asked for **four components**:

1. Dependency-ordered rollout + health gate
2. Auto-rollback on a failed health check
3. A **full, long-lived staging environment** with local → staging → prod gates
4. Progressive / preview rollout

### Constraints (in tension)

- **Low cognitive load (ADHD)** — gates must be rare and high-signal; decision fatigue is a real failure mode.
- **Don't over-engineer** — three apps, one operator; nothing heavier than necessary.
- **Safe-by-default** — an AI agent must **not** be able to footgun prod.
- **One uniform standard** across heterogeneous stacks (Fly / Vercel / Supabase / Postgres).

**The core tension:** the literal "full 4-component standard" (especially component 3, long-lived staging) pulls **against** low-cognitive-load + don't-over-engineer + safe-by-default. Component 3 in particular is the contradiction this document must resolve on evidence, not omission.

---

## Research Summary

### Track 1 — Platform primitives (deep-research; 25/25 claims verified against primary docs)

- **Native today:** Fly `bluegreen`/`canary` gives a single-service, health-gated rollout (needs ≥1 healthcheck; **halts the deploy and keeps old machines on failure**). Vercel preview deploys + `vercel promote` (staging/promotion) and **Rolling Releases 1–99%** (progressive; Pro/Ent). Supabase per-PR preview branches + merge-triggered migration promotion (Pro).
- **MUST-BUILD:** auto-rollback on a **failed POST-deploy** health check is native on **none** of the four (build it: health probe / Checks API → `vercel rollback` or `fly deploy --image <prev>`). Cross-service **ordering** (deploy A, wait healthy, then dependent B) lives in CI (GitHub Actions `needs:`), not in any single platform.
- **Cost floor:** progressive rollout (Vercel Rolling Releases) and Supabase branching are paid tiers.

### Track 2 — Orchestration conventions

- Borrow **GitHub-native and nothing heavier**: ONE reusable workflow (`on: workflow_call`) called by a thin per-repo caller; `needs:` for ordering; a `production` GitHub Environment with **one required reviewer** as the human gate.
- **Avoid:** Argo/Flux (k8s-only); `workflow_run` / `repository_dispatch` chaining (default `GITHUB_TOKEN` won't trigger downstream — footgun + token plumbing); Dagger / Terraform-Pulumi promotion (over-engineering for three apps).
- **Caveat:** required-reviewer gating needs **public** repos on the Free plan; otherwise a paid GitHub plan (or the `trstringer/manual-approval` issue-based workaround).

### Track 3 — Solo cognitive load

- **Kill the long-lived staging environment** — it rots, drifts from prod from day one, sits 60–80% idle, and adds a serialization step with no payoff for one person.
- Use **preview-per-PR** instead (Fly preview apps / Vercel preview deploys / Supabase preview branches) — built fresh from code each PR, so no drift.
- **The single highest-value control:** ONE human "promote to prod" approval. The agent can build/test/preview freely but cannot self-promote. More gates → decision fatigue; gates must be rare and high-signal.

---

## Solution Options

### Option A — Native Dispatcher (thin wrapper, zero orchestration)

- **What:** `/borg-deploy` is a pure dispatcher. `deploy.yml` lists each service and the single native command that deploys it safely on its own platform. No CI graph, no custom controller, no rollback engine — the skill reads the per-service recipe and shells out to the platform's own health-gated deploy. The standard **is** the convention "every service must declare a self-gating native deploy command," nothing more.
- **How:** Per service, the skill reads `deploy.yml` → runs the declared command. reveal Fly backend: `fly deploy --strategy bluegreen` (requires ≥1 healthcheck; Fly halts and keeps old machines on failure = native, free rollback during deploy). reveal/ingle frontend: `vercel deploy --prod` after a `vercel deploy` preview passes Deployment Checks. Supabase: merge PR → Supabase runs the migration on promotion. Cross-service ordering is just the order of commands in the file; the nanoprobe runs them sequentially and stops on a non-zero exit. The human gate is the existing PR-merge / `--prod` confirmation.
- **Pros:**
  - Lowest possible cognitive load — one file, one command per service, nothing new to learn or maintain.
  - Maximally honest about Track 1: uses only what is native today, so almost nothing to build or debug.
  - No drift, no idle infra, no token plumbing, no GitHub-plan dependency; survives platform changes.
- **Cons:**
  - Delivers component 1 (single-service health gate) but **NOT** 2 (post-deploy auto-rollback absent for Vercel/Supabase; Fly only halts *during* deploy), **NOT** 3 (no staging), **NOT** 4 (no progressive %).
  - Cross-service ordering is "best-effort sequential" with no real health gate between A and B.
  - "Uniform" only in shape; recipes are heterogeneous, so the safety guarantee differs per platform and isn't centrally enforceable.
  - An AI nanoprobe can still self-promote to prod → **safe-by-default is NOT met.**
- **Key tradeoffs:** Minimum build and minimum cognitive load, bought by giving up the two Track-1 MUST-BUILDs (post-deploy auto-rollback, real cross-service health gate) and the one control Track 3 says matters most (a gate the agent cannot bypass). The right **floor** to measure everything against; on its own it fails safe-by-default.
- **Feasibility:** High
- **Estimate:** 1 session (deploy.yml schema + dispatcher skill; per-repo recipes are a few lines each).
- **MVP:** `deploy.yml` with an ordered `services:` list, each `{name, deploy_cmd}`; skill runs them in order, aborts on non-zero exit. Ship for reveal first.

---

### Option B — GitHub-Native Reusable Workflow + One Human Gate (preview-per-PR)

- **What:** Track 2 + Track 3 made concrete — the recommended center of gravity. ONE reusable workflow (`on: workflow_call`) lives in a shared repo; each project has a ~15-line caller passing its `deploy.yml`. `/borg-deploy` becomes a thin local mirror of that workflow for ad-hoc runs. Long-lived staging is **killed**; every PR gets a fresh preview. Production sits behind ONE GitHub Environment with ONE required reviewer — the only gate, and the thing the nanoprobe cannot self-clear.
- **How:** PR opened → reusable workflow spins a preview per service from code, runs tests + native checks. Merge to main → deploy job runs services in dependency order via `needs:` (deploy A, wait on A's healthcheck, then B). Before prod-deploy: a `production` Environment gate pauses for the single human approval. On approve → deploy with the native health-gated strategy (Fly bluegreen) **plus** a post-deploy probe step; probe failure → the MUST-BUILD rollback (`vercel rollback` / `fly deploy --image <prev>` / Supabase down-migration). Auto-rollback lives in CI, exactly where Track 1 says to build it. The nanoprobe can open PRs, trigger previews, and run the whole pipeline up to the gate, but cannot approve its own promotion.
- **Pros:**
  - Hits all four original components in their highest-value form: ordering via `needs:` (1), CI-built post-deploy auto-rollback (2), preview-per-PR as the zero-drift staging substitute (3-reframed), room to add progressive later (4).
  - Best safe-by-default story: the single required reviewer is a hard wall an agent literally cannot pass — exactly ONE high-signal gate (Track 3's core finding).
  - Genuinely uniform: same workflow, same gate, same `deploy.yml` contract; only leaf commands differ. One mental model for reveal/ingle/troth.
  - GitHub-native only — no Argo/Flux/Dagger, avoids the `workflow_run`/`repository_dispatch` token footgun.
- **Cons:**
  - Required-reviewer gate needs **public** repos on Free/Pro/Team (re-verified June 2026); private repos force a paid plan OR the `trstringer/manual-approval` workaround (less polished, no native approve button).
  - Auto-rollback + post-deploy probe are real code you own across three platforms — the genuine build cost.
  - Two surfaces of truth: the reusable workflow (CI) and the `/borg-deploy` skill (local) can drift if not kept thin.
  - More machinery than A — a caller workflow, an environment, and secrets per repo.
- **Key tradeoffs:** You own ~one workflow's worth of custom code (rollback + probe) and a GitHub-plan/repo-visibility constraint, in exchange for the only option satisfying **all** of low-cognitive-load (one gate), safe-by-default (agent can't self-promote), don't-over-engineer (GitHub-native), and a truly uniform standard. The staging tension resolves by reframing component 3 as preview-per-PR — the developer gets the **safety** they wanted from staging without the drift/idle/serialization cost.
- **Feasibility:** High
- **Estimate:** 3–4 sessions (1: reusable workflow + schema + reveal caller & gate; 2: post-deploy probe + auto-rollback for Fly+Vercel; 3: ingle/troth Supabase preview-branch + migration rollback; 4: make `/borg-deploy` mirror the workflow).
- **MVP:** reveal only: reusable workflow with `needs:`-ordered deploy, a `production` environment with one reviewer, Fly bluegreen + a single post-deploy curl probe that triggers `fly deploy --image <prev>` on failure. No progressive %, no Supabase yet. Prove the gate + rollback, then fan out.

---

### Option C — Literal Four-Component Build: Long-Lived Staging with local → staging → prod Gates

- **What:** The original ask taken literally and built honestly, so the cost is visible rather than hand-waved. A persistent staging environment exists per project (staging Fly app + Vercel staging target + a dedicated Supabase staging project/branch). `deploy.yml` encodes the promotion ladder local → staging → prod, with a gate at each hop. This is the option Track 3 argues against; it's included so the contradiction is decided on evidence, not omission.
- **How:** Push to `develop` → `deploy.yml` promotes to the long-lived staging stack (Fly staging app bluegreen, Vercel `--target staging`, Supabase staging project migration). Gate 1: a human (or a green smoke suite) approves staging. Promote to prod via the reusable workflow with a second human gate. Each environment is a real, addressable, always-on copy. Ordering and rollback work as in B, but executed twice. The nanoprobe can deploy to staging freely; both prod and staging→prod promotion are gated.
- **Pros:**
  - Literally satisfies all four components as phrased, including explicit component 3 — no reframing.
  - A stable shared URL for stakeholders/integration testing and for soak-testing migrations against prod-like data.
  - Two gates give a psychologically reassuring "belt and suspenders" against an agent reaching prod.
- **Cons:**
  - Directly contradicts Track 3: long-lived staging drifts from day one, rots, sits 60–80% idle (you pay for a third Fly app + third Supabase project continuously), and adds a serialization step with no payoff for one person.
  - **Highest** cognitive load of all options: two environments, two secret sets, two gates = the decision fatigue Track 3 warns destroys gating's value.
  - Most expensive to run and build — roughly doubles infra and deploy surface area; squarely the "over-engineering" the constraint forbids.
  - Staging green ≠ prod green (drift), so the extra gate gives **false confidence** — safety theater for a load-sensitive solo dev.
- **Key tradeoffs:** You honor the literal request and gain a persistent shared URL, at the direct cost of violating three of four governing constraints. The only option that gives component 3 as asked is also the only one the cognitive-load and over-engineering constraints rule out. Its real role: to be **consciously rejected** — or reserved for the one app that genuinely needs a shared URL.
- **Feasibility:** Medium
- **Estimate:** 5–6 sessions (stand up + maintain a third environment per stack, double the gates and secrets, plus an ongoing drift-management tax that never ends).
- **MVP:** If pursued at all: ONE long-lived staging for reveal only, reusing Option B's workflow with an added staging job and Gate 1. Do **not** replicate to ingle/troth — let one instance's evidence decide.

---

### Option D — Progressive-First with Auto-Rollback as the Safety Net (gates replaced by metrics)

- **What:** A different architectural bet: instead of gating *before* prod, deploy to prod immediately but **progressively** (1% → N%), letting an auto-rollback watchdog be the safety mechanism. Leans hard into Track 1's progressive primitives (Vercel Rolling Releases 1–99% on Pro/Ent, Fly canary) and makes the MUST-BUILD post-deploy rollback the centerpiece. Trades the human pre-gate for a machine post-gate.
- **How:** Merge → reusable workflow deploys at low traffic %: Vercel Rolling Release starts at 1–10%; Fly canary brings up a fraction. A watchdog step (Actions cron/poll or platform metrics) checks error rate / the post-deploy probe over a bake window. Healthy → auto-advance to 100%. Unhealthy → auto-rollback (`vercel rollback` / `fly deploy --image <prev>` / Supabase down-migration) + a PushNotification. Component 4 (progressive) is primary; component 2 (auto-rollback) is its safety net; ordering (1) still via `needs:`. Preview-per-PR (Track 3) still used for build-time validation. Supabase is the weak leg — no native DB traffic-split, so migrations stay forward-only/expand-contract and gated.
- **Pros:**
  - Smallest blast radius in practice: a bad release only hits 1–10% of traffic before the watchdog catches it — arguably the strongest real-world "agent can't footgun prod" guarantee, since even a self-promoted bad deploy is contained and auto-reverted.
  - Lowest human-in-the-loop friction: no approval to click for routine deploys (fits ADHD low-friction goals); the human is paged only when something is actually wrong.
  - Directly delivers components 4 + 2 in their strongest native+build form.
- **Cons:**
  - Progressive % is **paid** (Vercel Rolling Releases = Pro/Ent) — a hard cost floor, and frontend-only; Fly canary is coarser and Supabase has **no** traffic-split, so "uniform" breaks at the data layer.
  - Removing the human pre-gate weakens Track 3's single highest-value control and bets on the watchdog's metrics being trustworthy — a flaky probe either blocks good deploys or waves through bad ones.
  - The watchdog (bake-window logic, thresholds, auto-advance/revert state machine) is the **most custom code** short of full GitOps — and the hardest to debug at 2am.
  - Highest conceptual load to hold (traffic %, bake windows, thresholds), even though day-to-day friction is low — complexity hidden until it misfires.
- **Key tradeoffs:** You swap a human PRE-gate for a machine POST-gate: deploys become frictionless and blast radius shrinks to a few percent, but you must trust/maintain a metrics watchdog, pay for progressive tiers, and accept a non-uniform guarantee (the DB can't be traffic-split). Great fit for the frontend, awkward for the whole heterogeneous fleet — best layered **onto** Option B later, not as v1.
- **Feasibility:** Medium
- **Estimate:** 4–6 sessions (1–2: Option B baseline; 2–3: Vercel Rolling Release driver + bake-window watchdog; 1: Fly canary advance/revert; 1: wire PushNotification + thresholds). Excludes paid-tier signup.
- **MVP:** Vercel frontend only, on Pro: Rolling Release at 10%, one watchdog job polling the health probe for 5 min, auto-advance to 100% on green or `vercel rollback` on red, PushNotification on rollback. Backend/DB stay on Option B's gated path until proven.

---

### Option E — Declarative GitOps Manifest + Custom Promotion Controller (full custom)

- **What:** The far end of the spectrum: `deploy.yml` stops being a recipe list and becomes a declarative **desired-state manifest** (services, dependency DAG, health criteria, gate policy, rollback policy, traffic strategy, per-environment config). A custom controller — a reusable workflow plus a small reconciler script, **not** k8s/Argo/Flux — reads the manifest and drives every platform to match it. The standard becomes a mini deployment DSL all repos conform to, with one engine interpreting it.
- **How:** `deploy.yml` declares the full graph and policy once. The controller computes topological deploy order from the declared DAG (generalizing `needs:`), applies each service via its platform adapter (Fly/Vercel/Supabase plugins), evaluates declared health criteria, enforces declared gates (human or metric), and executes declared rollback policy automatically on any failure. Adding a fourth project = a new `deploy.yml`; adding a platform = one adapter. The nanoprobe edits the manifest (a PR), but the controller + the manifest's gate policy govern what reaches prod.
- **Pros:**
  - Maximum uniformity and the truest "one standard across heterogeneous stacks" — policy declared once and centrally enforced; an agent reads ONE schema everywhere.
  - Cleanest safe-by-default in theory: gate/rollback/traffic policy is data the controller enforces, so an agent literally cannot deploy outside declared policy — structural, not procedural.
  - Most extensible/future-proof: new platform = one adapter; can absorb Options B and D as policy values (`gate: human | progressive`); scales past three apps cleanly.
- **Cons:**
  - Squarely the over-engineering Track 2 **and** Track 3 warn against for three apps — you become maintainer of a bespoke deployment DSL and multi-platform reconciler, a project unto itself with no payoff at this scale.
  - Highest build cost and worst **bus-factor** for a solo dev: when the controller breaks you debug your own orchestration engine under deploy pressure — the exact 2am footgun the constraints exist to prevent.
  - High cognitive load to hold the abstraction — a second language layered over three platforms that already have their own.
  - Most of the engine duplicates what GitHub-native `needs:` + Environments give for free (Option B); marginal value over B is small until there are many more apps/platforms.
- **Key tradeoffs:** You get a single, centrally-enforced, infinitely-extensible standard — and forever maintain a custom deployment engine for a three-app solo fleet, precisely the over-engineering the constraints forbid. Right architecture for a 30-service team; wrong altitude for this developer today. Its value is as the explicit **ceiling**: it shows what full GitOps costs, so Option B's restraint is a deliberate choice. Revisit only if the fleet grows large.
- **Feasibility:** Low
- **Estimate:** 8–12+ sessions (manifest schema/DSL, reconciler, three platform adapters, gate engine, rollback engine, DAG resolver, plus ongoing engine maintenance).
- **MVP:** Resist building the controller. Ship Option B but make `deploy.yml`'s **schema** forward-compatible with this manifest (declare `dag`/`health`/`gate`/`rollback` as data even though the GitHub-native workflow interprets them). Captures 90% of the uniformity at 10% of the cost and keeps the door open if the fleet outgrows GitHub-native.

---

### Option F — Ephemeral Staging-on-Demand + Risk-Gated Promotion (preview IS the staging; the gate fires only when the diff is risky)

- **What:** The synthesis that holds both poles. It refuses to concede component 3 (the developer wanted staging) **and** refuses to concede low-cognitive-load/safe-by-default. The move: stop treating "staging" as a **place** and treat it as a **capability** — a prod-faithful validation surface you stand up on demand. Every PR builds a fresh, full-stack ephemeral environment (Fly preview app + attached throwaway Postgres OR Supabase preview branch + Vercel preview deploy) that is as prod-like as the long-lived staging would have been, but exists only while the PR is open and is rebuilt from code every time — delivering staging's validation/soak benefit with **zero drift, zero idle spend, zero serialization ceremony**. On top of that, the single human prod gate is made **conditional**: a cheap risk-classifier inspects the merged diff; if it touches migrations, infra (`fly.toml`/`Dockerfile`), secrets, or prod config, the deploy references the protected `production` Environment and pauses for ONE human approval; if it's purely application code that already passed its ephemeral-env checks and the native health-gated deploy, it flows straight to prod with no human in the loop. Auto-rollback runs on every path as the floor. This is Option B's spine with two deliberate upgrades: ephemeral env explicitly framed **as** the staging deliverable, and the gate made risk-conditional instead of always-on.
- **How:** PR opened → reusable workflow stands up the ephemeral environment per service: `fly deploy` to a `pr-<n>-<repo>` app with a fresh attached Postgres (or Supabase `create_branch`; Vercel preview). Run the **full** validation suite against it (the same smoke/integration/migration tests you'd run on long-lived staging, but against an env built fresh from THIS PR's code — no drift). PR closed/merged → env + throwaway DB torn down automatically (`superfly/fly-pr-review-apps` destroys on close; Supabase branch deleted; Vercel preview expires). On merge to main → a `classify-risk` job diffs the merge against path globs in `deploy.yml` (`risk_paths: [supabase/migrations/**, '**/fly.toml', 'Dockerfile', '**/*.env*', infra/**]`), emitting `gated: true|false`. The deploy job sets its `environment:` via expression: it references `production` (protected, one required reviewer) only when `gated == true`; otherwise an ungated `production-auto` env. Either way it deploys in dependency order via `needs:`, uses the native health-gated strategy (Fly bluegreen), runs the post-deploy probe, and on probe failure triggers the owned auto-rollback (`fly deploy --image <prev>` / `vercel rollback` / Supabase down-migration) + PushNotification. `/borg-deploy` is a thin local mirror calling the SAME classify+deploy logic, so ad-hoc nanoprobe runs obey the same gate. Net: the agent builds and previews freely, ships low-risk app changes with zero friction, and is **structurally** blocked from self-promoting anything touching dangerous surfaces.
- **Separation move:** **time** (ephemeral per-PR env replaces long-lived staging — validation benefit and no-drift/no-idle never coexist *in time*, so they stop competing) **+ condition** (the human gate is bound to a diff-risk classification, not to every deploy, so safe-by-default and low-cognitive-load are both satisfied).
- **Ideal Final Result:** Every change is validated against a prod-faithful environment that costs nothing when no PR is open and can never drift from prod (built from code each time). The agent has zero friction on the 80% of deploys that are routine app code, yet is structurally — not procedurally — unable to push a migration, infra, or prod-config change to prod without exactly one human approval. Gates are rare and fire only when they carry real signal, so there is no decision fatigue and no footgun. One uniform contract (`deploy.yml`: services, dependency order, `risk_paths`, health probe, rollback) governs reveal, ingle, and troth; only leaf commands differ.
- **Smuggled-cost check:** Holds both poles, but three deferred costs must be named or they sneak back. **(1) The ephemeral env must be prod-faithful or the staging benefit is a proxy** — a preview with a different DB engine, no seed data, or skipped secrets doesn't validate prod, it just *looks* like staging. The fidelity work (attach a real Postgres, seed representative data, run migrations forward AND test rollback) is the genuine cost; skip it and you've smuggled "staging-shaped theater" back in. Real but **bounded** (per-service setup, done once) and far cheaper than the never-ending drift tax of long-lived staging. **(2) The risk classifier is a new trust surface** — too-narrow `risk_paths` lets a dangerous change slip through ungated. Mitigation that does **not** smuggle cost: **default-DENY** (unmatched/unknown change types are treated as risky → gated), so the failure mode is "gated unnecessarily" (mild friction), not "shipped unreviewed" (footgun). The classifier is declarative path globs, not an ML judgment call — auditable and cheap. **(3) The GitHub-plan/repo-visibility constraint from B is not dissolved** — required reviewers need public repos on Free, else a paid plan or the `trstringer/manual-approval` workaround; F inherits it. None of these defers cost to "2am under deploy pressure" the way D's watchdog or E's controller do — the classifier failure is caught at classify-time (pre-deploy), and the ephemeral-env failure in CI (pre-merge). Costs are real, bounded, and surface **early** — the test for not smuggling.
- **Pros:**
  - Answers component 3 on the developer's own terms — a real, prod-faithful, addressable staging surface per PR — while killing the rot/idle/serialization Track 3 proved makes long-lived staging negative-value. The contradiction is dissolved, not conceded.
  - Resolves the deeper safe-by-default vs cognitive-load tension: the human gate fires only on genuinely risky diffs, so it stays rare and high-signal while remaining a hard structural wall the nanoprobe cannot self-clear on the changes that matter.
  - Strictly dominates Option B on the two constraints B left in tension: B gates **every** prod deploy → drift toward "approve without looking" → gate decays into theater. F gates only the dangerous ~20%, keeping each approval meaningful.
  - Default-deny means the **safe** failure mode (over-gate → mild friction) replaces the dangerous one (under-gate → footgun); safety degrades gracefully.
  - Uniform across heterogeneous stacks: one `deploy.yml` contract, one reusable workflow, one skill mirror; only leaf commands differ.
  - Inherits B's MUST-BUILD auto-rollback + post-deploy probe as the always-on floor, so even an ungated routine deploy that goes bad is auto-reverted — the agent is contained on **every** path.
- **Cons:**
  - Two genuinely new build costs over B: (a) the ephemeral env must be made prod-faithful per service (real Postgres + seed + migration-rollback test for reveal; Supabase preview branch + seed for ingle/troth), and (b) the declarative risk classifier. Neither is huge, but neither is free.
  - The standard now has a security-relevant config knob (`risk_paths`) a careless edit could weaken — it must live in a **CODEOWNERS-protected** path so the nanoprobe can't widen its own latitude by editing the very file that gates it. (Self-referential gate: the thing that decides whether to gate must itself be gated.)
  - Conditional gating is more conceptual surface than B's "always gate prod" — you hold the model "risky diff → human, safe diff → auto." Lower than C/D/E, higher than B.
  - Inherits, does not solve, B's required-reviewer public-repo/paid-plan constraint.
  - Ephemeral full-stack envs cost compute during an open PR (brief, metered) and need teardown to fire on PR-close or they silently accumulate — a cleanup job that must be verified, not assumed.
- **Key tradeoffs:** One more session than B, buying the dissolved contradiction — at the cost of owning the ephemeral-env fidelity work and a security-sensitive `risk_paths` knob that must be CODEOWNERS-protected.
- **Feasibility:** High
- **Estimate:** 4–5 sessions (1: reusable workflow + schema incl. `risk_paths` + reveal caller + both `production` gated and `production-auto` envs; 2: reveal ephemeral env = Fly preview app + attached throwaway Postgres + seed + full validation suite, with auto-teardown on PR close; 3: classify-risk job with default-DENY + dynamic `environment:` routing + CODEOWNERS-protect `deploy.yml`; 4: post-deploy probe + auto-rollback for Fly+Vercel as the always-on floor; 5: fan out to ingle/troth via Supabase preview branches + migration rollback, then make `/borg-deploy` mirror it).
- **MVP:** reveal only. Per-PR: Fly `pr-<n>` app + freshly attached Postgres + seed + run the migration and smoke suite; auto-destroy on PR close. On merge: classify-risk over `risk_paths: [supabase/migrations/**, '**/fly.toml', 'Dockerfile']` with default-DENY; if risky → `production` env (one reviewer) else → `production-auto`; both paths Fly bluegreen + one post-deploy curl probe → `fly deploy --image <prev>` on failure + PushNotification. Protect `deploy.yml` via CODEOWNERS. Prove: (a) a pure-app-code PR ships to prod with NO human click, (b) a PR that adds a migration HALTS for approval, (c) a probe failure auto-rolls-back. Then fan out.

---

### Option F2 — Variant: Promote-by-Snapshot (the one app that truly needs a shared URL gets a long-lived alias pointed at the last-approved ephemeral build)

- **What:** A narrow companion to F for the single residual need long-lived staging actually served that ephemeral-per-PR does **not**: a stable, shared URL a stakeholder or integration partner can bookmark. F's previews have per-PR URLs that churn, so if reveal genuinely needs "send someone a link that always works," this variant supplies it **without** resurrecting a drifting always-on environment. The move: keep a long-lived DNS alias (e.g. `staging.reveal.app`) that is just a **pointer**, and "promoting to staging" = repointing that alias at the most recently **approved** ephemeral build's image/deployment. There is no separate environment to maintain or drift — staging becomes a *label on a known-good artifact*, not a place where code rots.
- **How:** Reuse F entirely. Add one optional `deploy.yml` field `stable_preview_alias: staging.reveal.app`. When an ephemeral PR build passes all checks and a human (or a green suite) marks it approved, the workflow repoints the alias at THAT build: Fly `fly deploy --image <approved-image>` to a thin always-on `reveal-staging` slot, or `vercel alias set <approved-preview-url> staging.reveal.app`, or Supabase points the staging branch at the approved migration set. The alias always serves the last-approved artifact, so it is prod-like by construction and cannot drift, because it is never edited in place — only ever repointed at a fresh approved build. Apply only to reveal; do **not** replicate to ingle/troth unless the same need is proven.
- **Separation move:** **space** (separate the stable NAME from the ephemeral ARTIFACT: the long-lived thing is a pointer/alias, the running code is always a fresh approved build — so "persistent shared URL" and "no drifting environment" stop competing) **+ condition** (only the one app with a proven shared-URL need opts in via a single `deploy.yml` field).
- **Ideal Final Result:** A stakeholder can bookmark `staging.reveal.app` and it always works **and** always shows a known-good, recently-approved build — with no separate environment to keep in sync, no drift (the alias only ever points at fresh approved artifacts, never edited in place), and the cost scoped to the one app that needs it via a single opt-in field.
- **Smuggled-cost check:** Mostly holds, with one honest caveat. The "always-on slot" the alias points at (the Fly `reveal-staging` machine) **is** a small piece of standing infra — so this does **not** achieve F's literal zero-idle. But the crucial difference from Option C: that slot is never deployed to directly and never hand-edited, so it cannot **drift** — it only ever receives whole approved images, the same artifacts that passed CI. The cost that's real: one always-on machine's spend for reveal, plus the alias-repoint plumbing. The cost **avoided** (vs C): the entire drift-management tax, the second secret/env set, the second human gate, and replication to ingle/troth. The trap that would smuggle C back in: letting anyone deploy to the staging slot **directly** (bypassing repoint-to-approved-artifact) — that instantly recreates a drifting environment. Guard: the slot accepts ONLY repoint operations from the workflow, never a direct deploy. If that discipline holds, this is a pointer, not a place, and the contradiction stays dissolved. Only worth it **if** the shared-URL need is real; otherwise pure overhead — hence opt-in, reveal-only.
- **Pros:**
  - Captures the one legitimate benefit of long-lived staging (a stable shared URL) that ephemeral-per-PR genuinely cannot, without reintroducing a drifting always-on environment.
  - Scoped by a single opt-in `deploy.yml` field to the one app most likely to need it; ingle/troth stay on pure F. Lets one instance's evidence decide.
  - Cannot drift by construction: "staging" is repointed at a known-good artifact, never edited in place — eliminating the false-confidence problem that made C's extra gate safety theater.
- **Cons:**
  - Reintroduces a small amount of always-on infra (one slot/machine for reveal) — not zero-idle like pure F, so only justified by a real shared-URL need.
  - Adds alias-repoint plumbing per platform (`fly` image deploy / `vercel alias set` / Supabase branch pointer) — a thin but real new mechanism to own.
  - Requires discipline that nothing ever deploys to the staging slot directly (only repoint-to-approved); if that lapses, C's drift problem silently returns.
- **Feasibility:** High
- **Estimate:** 1 session on top of F, reveal only (add `stable_preview_alias` handling + the repoint step + a guard that the slot rejects direct deploys). Do not build unless/until a shared-URL need is actually voiced.
- **MVP:** reveal: after an ephemeral build is approved, `vercel alias set <approved-preview-url> staging.reveal.app` (frontend) and/or `fly deploy --image <approved-image>` to a `reveal-staging` slot that accepts ONLY workflow repoints. Confirm the alias always serves a known-good build and cannot be deployed to directly. Skip entirely if no one needs the bookmark.

---

## Contradiction Forge

**The contradiction:** the developer explicitly asked for component 3 — a **full long-lived staging environment** — but Track 3's verified evidence says drop it for preview-per-PR. Underneath sits the governing fight: "the full 4-component standard" vs "low cognitive load / don't over-engineer / safe-by-default." Option C is the only option that gives component 3 literally, and it is also the only option the cognitive-load and over-engineering constraints rule out. Resolving by omission (just dropping component 3) would concede the developer's stated need; resolving by C would concede three constraints. Neither is acceptable, so the forge seeks a separation.

### Resolved option: F (with F2 as a conditional, opt-in companion)

**Separation move — F:** *time + condition.*
- **Time:** the ephemeral per-PR environment replaces the long-lived one. Staging's validation/soak benefit and the no-drift/no-idle property never need to coexist *in time* — the env exists only while a PR is open and is rebuilt from code each time — so the two stop competing. This is how component 3's **benefit** is delivered while component 3's **cost** (drift, idle, serialization) is eliminated.
- **Condition:** the single human gate is bound to a **diff-risk classification** rather than to every deploy. Safe-by-default and low-cognitive-load stop competing because the gate fires only on the dangerous ~20% (migrations/infra/secrets/prod-config), staying rare and high-signal while remaining a hard structural wall.

**Separation move — F2 (conditional):** *space + condition.* Separate the stable **name** (a long-lived DNS alias) from the ephemeral **artifact** (a fresh approved build), so "persistent shared URL" and "no drifting environment" stop competing. Apply only to the one app whose shared-URL need is actually voiced.

**Ideal Final Result (F):** Every change is validated against a prod-faithful environment that costs nothing when idle and can never drift. The agent has zero friction on routine app-code deploys yet is *structurally* unable to push a migration/infra/config change to prod without exactly one human approval. Gates are rare and high-signal — no decision fatigue, no footgun. One uniform `deploy.yml` contract governs reveal, ingle, and troth; only leaf commands differ.

**Smuggled-cost verdict:** F holds both poles **without** deferring cost to 2am-under-deploy-pressure — the dispositive test. Its three deferred costs (prod-faithful env fidelity, the classifier as a trust surface, the inherited public-repo/paid-plan constraint) all surface **early**: env-fidelity failures are caught in CI pre-merge; classifier failures are caught at classify-time pre-deploy; the plan constraint is known up front. The **default-DENY** posture makes the residual failure mode "over-gated / mild friction," never "shipped unreviewed / footgun" — safety degrades gracefully. The one genuinely self-referential hazard — the nanoprobe widening `risk_paths` by editing the file that gates it — is structurally (not procedurally) closed by **CODEOWNERS-protecting `deploy.yml`**, which is a non-negotiable acceptance criterion, not a follow-up. F2's only honest caveat: it reintroduces *one* small always-on slot, so it is not zero-idle — but because that slot only ever receives whole approved artifacts and is never deployed to directly, it **cannot drift**, which is the property that made C's extra gate safety theater. F2 is worth building only if a real shared-URL need is voiced.

The contradiction is therefore **dissolved, not conceded**: the developer gets a real, prod-faithful, addressable staging surface (component 3 on their own terms) without the drift/idle/serialization that the governing constraints forbid.

---

## Council Review

**The Product Strategist** — Favors **F** as the v1 standard (F2 deferred until a shared-URL need is voiced); rejects C and E on strategic grounds; treats A as a floor, D as a later layer. The real problem isn't "deployment correctness" in the abstract — it's "the smallest standard that lets ONE AI-orchestrated solo dev ship three heterogeneous apps without an agent footgunning prod, at near-zero ongoing cognitive tax." Against that, C is a strategic miss, not just an effort miss: long-lived staging drifts from day one and sits 60–80% idle, so it delivers component 3 as a *label* while producing **false confidence** (staging-green ≠ prod-green) — safety theater that consumes attention, worse than no gate. E is rejected on Track 2's "GitHub-native and nothing heavier" mandate: it makes the developer maintainer of a bespoke DSL whose marginal value over `needs:` + Environments is near-zero at three apps, manufacturing a bus-factor-one 2am footgun. A fails the load-bearing constraint (nanoprobe can self-promote; no post-deploy auto-rollback; no real cross-service gate). D inverts Track 3's highest-value control for a watchdog that's the hardest code to debug at 2am and breaks uniformity at the Supabase layer — a later frontend-only layer, not v1. F is the product-correct center of gravity because it **dissolves** the central contradiction rather than conceding it, and crucially it prevents B's quiet failure where gating every routine deploy decays the human into rubber-stamping. F doesn't smuggle (costs surface early; default-DENY degrades gracefully); the one risk it must own structurally is the self-referential gate — CODEOWNERS-protect `deploy.yml`, in the MVP, non-negotiable. Sequencing fits solo scale: ship F's MVP on reveal, prove the three behaviors, defer ingle/troth, keep F2 strictly opt-in.

**The Technical Realist** — Favors **B** as the shippable v1 spine; endorses **F** as the right architecture **only if** its DB-fidelity cost is paid honestly (else it degrades to B). Every primitive is verified current (June 2026): Fly bluegreen halts-and-keeps-old-machines on a failed *deploy* — but it does **not** roll back a release that passed deploy-time checks then went bad, so the post-deploy probe + owned rollback genuinely is MUST-BUILD. The hardest break is the **database leg**: Supabase is forward-only with **no native down-migration**, and a destructive migration already applied to prod data is frequently **unrollable** — so "auto-rollback on every path" is real for Fly/Vercel app tiers and a *polite lie* for data. Second break: required reviewers work only on **public** repos on Free/Pro/Team; these solo app repos are almost certainly private → Enterprise bill or the `trstringer/manual-approval` bot. The gate, the load-bearing safe-by-default control, has a license dependency. Cross-service ordering via `needs:` is genuinely free and correct (avoiding `workflow_run`/`repository_dispatch` is right). F does **not** cleanly hold both poles as written: the genuinely hard part is per-PR **database** isolation+seed+migration-rollback-test — `superfly/fly-pr-review-apps` attaches an *existing shared* cluster, not a fresh throwaway DB, and leaves environments dangling on close — so F's "staging benefit at zero idle" is real for stateless tiers and aspirational for the stateful tier. F's default-DENY classifier is genuinely good, and the self-referential CODEOWNERS point is the sharpest correctness insight in the set. Practical path: ship B's MVP, treat Supabase migrations as forward-only/expand-contract and **gate** them rather than pretend to auto-roll-back, then layer F once the per-PR DB-fidelity work is scoped and budgeted as recurring.

**User Advocate** — Favors **B** as the standard and **F**'s risk-conditional gate as a fast-follow; rejects C outright; defers D, E, F2. The behavioral record overrides abstract elegance: `user_adhd_context.md` states Noah "experiences anxiety attacks when overwhelmed by too many work streams" and that "the main danger is coding forever and never delivering" — the explicit need is **shipping discipline** and preventing the "one more feature" trap AI tools enable. C is dead on arrival: its own cons admit the highest cognitive load (two environments, two secret sets, two gates), directly triggering the documented anxiety failure mode — killed for user-harm, not effort. The harder question: does forge-resolved F match *this* developer? F asks Noah to permanently hold "risky diff → human, safe diff → auto" plus a self-referential CODEOWNERS gate — exactly the conditional, stateful rule an ADHD operator loses confidence in at 2am and then distrusts, which is worse than no gate. F genuinely dissolves the staging contradiction and its default-DENY framing is right, but it is a **v1.1, not a v1**. B maps cleanest onto actual behavior: ONE flat rule ("prod needs one human approval"), the single rare high-signal gate Track 3 named highest-value, GitHub-native only, preview-per-PR killing drift, and the MUST-BUILD auto-rollback as the floor. B is also the only option whose safe-by-default guarantee is legible enough that Noah will actually **trust** it — and trust is what stops the "I'll just check it myself" re-engagement that defeats the point. A fails the non-negotiable (self-promotion). D's watchdog is the wrong trade for someone whose documented danger is overwhelm. E is the over-engineering both tracks forbid. Sequence: ship B for reveal, prove the gate+rollback feel trustworthy, then adopt F's routing **only once** B's gate demonstrably decays into rubber-stamping. F2 stays shelved until a real human voices the shared-URL need.

**The Pragmatist** — Favors **B** as the standard to ship; **F** as the deliberate v2 target. The 80/20 is B's spine reduced to its MVP: one reusable workflow with `needs:`-ordered jobs and a single `production` Environment gate. That single structural fact — backend job runs, its native health-gated strategy (Fly bluegreen, verified to require ≥1 healthcheck and halt on failure) must report healthy, and only **then** the frontend job (`needs: [backend]`) runs — **is** the core safety bet "frontend never ships before backend is healthy." That bet survives MVP reduction intact: drop progressive %, Supabase, F's classifier, ephemeral-DB fidelity, even the human reviewer, and the ordering guarantee still holds because it's `needs:` + a post-deploy probe between jobs. So ~1.5 sessions buys components 1 (ordering) and 2 (auto-rollback floor) — the two Track-1 MUST-BUILDs that Option A explicitly fails. **Kill A** (not for effort, for correctness): no health gate between services means it cannot make the ordering bet, and the nanoprobe can self-promote — fails safe-by-default outright. **Kill C** (strategy/correctness): long-lived staging drifts from day one, so the second gate manufactures false confidence, worse than no gate; C should exist only as F2's opt-in alias if a shared-URL need is voiced. On F: it genuinely holds both poles and doesn't smuggle cost into 2am — its two new costs surface early (CI pre-merge, classify-time pre-deploy), and default-DENY makes the failure mode "over-gate = mild friction." F's one honest hazard, the self-referential gate, is correctly mitigated by CODEOWNERS-protecting `deploy.yml` — a hard acceptance criterion. But F is strictly **v2**: it earns its extra session only **after** B proves the gate+rollback work, because F's conditional gate refines a problem (gate-decay-into-rubber-stamp) you can only observe once B is running. D and E are deferred over-engineering; D additionally breaks uniformity at the Supabase data layer.

### Recommender

**Ship Option B** (GitHub-native reusable workflow + ONE human prod gate + preview-per-PR) as the **v1 standard — reveal only first.** Treat **Option F's risk-conditional gate as a planned v1.1**, adopted only once B's always-on gate demonstrably decays into rubber-stamping. **Kill C. Defer D, E, and F2.**

Three of four council voices (Technical Realist, User Advocate, Pragmatist) land on B-as-v1 / F-as-fast-follow, and the one F-first vote (Product Strategist) concedes F is "one more session, buying the dissolved contradiction" — a refinement, not a different floor. Two independent pieces of project evidence break the tie toward B: **(1)** the staged-deployment memory states reveal's risk is **purely ordering**, and already prescribes Phase 1 = ordered rollout + health gate + auto-rollback, with staging/progressive as explicit Phase 2 — Noah's own prior decision matches B's MVP almost exactly. **(2)** The ADHD record: F's conditional "risky diff → human, safe diff → auto" plus a self-referential CODEOWNERS gate is exactly the stateful rule an ADHD operator distrusts at 2am — and distrust drives the "I'll just check it myself" re-engagement that defeats the standard. B is the only option whose safe-by-default guarantee is one flat, legible rule ("prod needs one human approval") that Noah will actually **trust**. B satisfies the load-bearing constraints (safe-by-default via a hard reviewer wall that fixes A's fatal flaw; low cognitive load via ONE high-signal gate; GitHub-native per Track 2; uniform across stacks) and delivers the Track-1 MUST-BUILDs (ordering via `needs:`, post-deploy auto-rollback floor). A is rejected — its own cons admit the nanoprobe can self-promote, failing the non-negotiable. C, D, E rejected (see Dissent + Recommendation).

---

## Dissent

**The strongest dissent is the Product Strategist's**, and it is recorded here non-empty by construction because it is real and correct: **Option B has a quiet failure mode** where gating **every** routine prod deploy drives the human toward "approve without looking," decaying the gate into theater. F's risk-conditional gate fixes this by firing only on the dangerous ~20% (migrations/infra/secrets). This critique is accepted as valid — and it does **not** change the v1 call; it **sets the v1.1 trigger.** Reasons:

1. **You cannot observe gate-decay until B is running.** F solves a problem measurable only *after* shipping B. Buying F's conceptual surface up front, before that evidence exists, is itself the "one more feature" over-engineering the ADHD record warns against.
2. **For this operator, F's conditional rule + self-referential gate is higher steady-state cognitive load than B's flat rule.** The User Advocate is right that an ADHD operator who loses confidence in a stateful 2am rule is worse off than with no gate.
3. **reveal's actual risk is ordering, not migration-footgunning** (per project memory) — F's marginal value (gating risky DB/infra diffs) is lowest exactly where v1 lands.

**Resolution of the dissent:** adopt F's risk-conditional routing as a **pre-planned v1.1**, gated on observed rubber-stamping, with `deploy.yml`'s `risk_paths` field **stubbed in v1** so the upgrade is purely additive. The Technical Realist's correctness dissent is also conceded in full and folded into the standard (see logged risks): the standard must **not** claim auto-rollback for the data tier.

---

## Recommendation

**Option B — GitHub-Native Reusable Workflow + One Human Gate (preview-per-PR), reveal only, as the v1 standard.**

**MVP ship — reveal only, ~1.5 sessions:**
- ONE reusable workflow (`on: workflow_call`) called by a ~15-line reveal caller.
- Jobs ordered via `needs:`, backend before frontend.
- Backend deploys with **Fly bluegreen** (requires ≥1 healthcheck; halts + keeps old machines on failed deploy).
- A single **post-deploy curl probe** after each tier; on probe failure → owned rollback (`fly deploy --image <prev>` for Fly; `vercel rollback` for the Vercel frontend).
- Production behind ONE GitHub `production` Environment with **one required reviewer** — the nanoprobe runs the entire pipeline up to the gate but cannot approve.
- Every PR gets a fresh preview (Vercel preview deploy; Fly preview app) — no long-lived staging to drift.
- `deploy.yml` schema written **forward-compatible**: declare `services`, `needs`-order, health `probe`, `rollback`, and a placeholder `risk_paths` field as data, so F's risk-conditional routing layers in later without restructuring.
- **Prove three behaviors before fanning out to ingle/troth:** (a) ordered deploy halts the frontend if the backend probe fails; (b) a bad post-deploy release auto-rolls-back on the app tier; (c) the agent cannot self-promote past the gate.
- **Explicitly NOT in v1:** progressive %, Supabase, F's classifier, ephemeral-DB fidelity work.

**Logged risks (carry into planning):**
1. **Database rollback is a lie — fold the Technical Realist's dissent into the standard now.** Supabase is forward-only with **no** native down-migration; an already-applied destructive migration on prod data is lossy-to-unrollable. The standard must **not** claim "auto-rollback on every path" for the data tier. Classify DB migrations as **forward-only / expand-contract** and **gate** them (this is precisely the `risk_paths` placeholder). The auto-rollback floor is honest for Fly/Vercel app tiers only. Write this into `deploy.yml`'s schema and `/borg-deploy` docs from day one so ingle/troth inherit the truth, not the lie.
2. **Required-reviewer plan/visibility dependency.** On Free/Pro/Team, GitHub required reviewers work only on **public** repos; reveal/ingle/troth are almost certainly private, forcing either a paid GitHub plan or the `trstringer/manual-approval` issue-based workaround. The load-bearing safe-by-default control has a licensing dependency — **resolve which path (pay vs workaround) before the MVP**, because the gate is non-optional.
3. **Two-surfaces drift.** The reusable workflow (CI) and the `/borg-deploy` skill (local mirror) can drift; keep the skill a thin caller of the same logic, and **verify preview/teardown actually fires** so envs don't silently accumulate.

**v1.1 carry-forward trigger:** when Noah notices himself approving prod **without reading the diff**, that is the signal to adopt F's risk-conditional gate — with **CODEOWNERS-protected `deploy.yml`** as a hard acceptance criterion so the nanoprobe can't widen its own latitude.

---

## Next Steps

1. **Run `/borg-plan` with this document** to build `/borg-deploy` + reveal's `deploy.yml` — scope it to Option B's MVP (reveal only, ~1.5 sessions): reusable workflow, `needs:`-ordered backend→frontend, Fly bluegreen + post-deploy curl probe + image-rollback, one `production` Environment reviewer, preview-per-PR. Lock acceptance criteria to the three provable behaviors.
2. **Before the MVP**, resolve logged risk #2: decide pay-for-paid-GitHub-plan vs `trstringer/manual-approval` workaround for the required-reviewer gate on private repos.
3. **Write `deploy.yml` forward-compatible**: include the stubbed `risk_paths` field and the forward-only/expand-contract DB-migration classification (logged risk #1) from day one, so ingle/troth inherit the honest data-tier contract and so F's v1.1 routing is additive.
4. **Keep `/borg-deploy` a thin mirror** of the reusable workflow, and verify preview teardown fires (logged risk #3).
5. **Defer** ingle/troth fan-out until reveal proves the gate + rollback; **defer** Option F (v1.1, triggered by observed rubber-stamping) and **F2** (opt-in, reveal-only, only if a stakeholder voices a shared-URL need). **Do not build** D or E.
