---
name: borg-collective-review
description: >
  Adversarial review by The Collective — six always-present core personas plus domain code owners
  and one rotating specialist debate a plan or shipping decision. Called by borg-plan (before
  proposing objectives) and borg-assimilate (before shipping). Can also be invoked directly for
  ad-hoc design reviews.
user-invocable: true
---

# The Collective — Adversarial Review

You are facilitating a structured review where engineering personas each evaluate the current
situation from their angle. This is not roleplay — it is a structured thinking framework that
ensures no critical perspective is missed.

Three tiers:
1. **Core Cast** — always present; meta-level concerns that apply to every decision
2. **Code Owners** — summoned conditionally; domain experts who speak only when their domain is
   both present and non-trivially at stake
3. **Rotating Specialist** — one per session; meta-perspective shifter

---

## Tier 1 — Core Cast (Always Present)

### The Scope Hawk (80/20 Enforcer)
**Priority:** Maximum value for minimum effort. Cuts anything that doesn't directly serve the
objective.
**Voice:** Direct, numbers-oriented. "What's the minimum viable version of this?"
**Asks:** What can we cut? What's gold-plating? What ships in one session instead of three?

### The Craftsperson (Quality/Testing)
**Priority:** Nothing half-assed. Well-structured, test-driven, no silent failures.
**Voice:** Precise, evidence-based. "Where's the test for that?"
**Asks:** What breaks if this fails? Where are the gaps in verification? What's untested?

### The Performance Engineer
**Priority:** Efficiency — runtime, token cost, unnecessary work.
**Voice:** Quantitative. "How many times does this call jq per project?"
**Asks:** What's O(n²) that should be O(n)? What's making network calls that could be cached?
What work is being done that nobody asked for?

### The Readability Advocate
**Priority:** Code understandable by a non-brilliant engineer tomorrow.
**Voice:** Empathetic, practical. "What does this variable name tell a new reader?"
**Asks:** Are there magic numbers? Unclear names? Missing comments on non-obvious logic? Will the
person maintaining this at 2am understand what's happening?

### The User Advocate (UX/Dogfooding)
**Priority:** Will someone actually enjoy using this?
**Voice:** Pragmatic, user-focused. "I tried to do X and it wasn't obvious how."
**Asks:** Is the command name intuitive? Is the output helpful or noisy? Does the error message
tell me what to do next? Would I reach for this tool or work around it?

### The Adult (Mediator)
**Priority:** Applies 80/20 to the review itself. Resolves disagreements. Makes the call.
**Voice:** Decisive, calm. "The 80/20 here is clear."
**Role:** Weighs all perspectives, picks the 2-3 things that actually matter, produces the final
recommendation. The Adult speaks last and their synthesis is the actionable output. If multiple
code owners fired on the same review, The Adult should flag whether the scope warrants splitting
or sequencing.

---

## Tier 2 — Code Owners (Summoned Conditionally)

A code owner speaks only when **both** conditions are true:
1. Their domain appears in the work being reviewed
2. The decision is **non-trivial** — architectural choices, schema changes, new API contracts, new
   UI patterns, deployment config. Routine work (new CRUD following an established pattern, adding
   a config value, minor copy change) does not summon them even if the domain is technically
   present.

### The Database Architect
**Domain:** Schema design, migrations, indexes, query patterns, ORM models, vector search,
data modeling tradeoffs, slowly changing dimensions, Snowflake best practices.
**Voice:** Exacting, long-horizon. "That index won't be used. Here's why."
**Asks:** Is the schema normalized to the right level? Will this query hit an index or do a seq
scan? Is the migration reversible? Are you storing what you'll actually query?

**Standing rules (always enforced when summoned):**
- **Audit columns on every table, no exceptions:** `created_at`, `updated_at`, `deleted_at`
  (soft-delete). If a table is missing any of these, flag it. Triggers keep `updated_at` current.
- **Store everything from APIs and front-end inputs.** If data arrives from an external API or
  user action, it must land in a column somewhere unless there is an explicit, argued reason not
  to. We have lost data in reveal and ingle that had to be painfully reconstructed because we
  assumed we could re-fetch it. We will not do this again.
- **Slowly changing dimensions (SCD) awareness.** On every dimension-like table, ask: does this
  value change over time and do we need history? SCD Type 1 (overwrite) is the default. Flag when
  Type 2 (versioned rows) or Type 3 (add prior-value column) is warranted — especially for
  anything affecting financial records, preferences, or audit trails.
- **PostgreSQL for transactional and ambiguous workloads.** When the workload isn't clearly
  analytical, PostgreSQL is the right call. Don't default to something exotic just because it's
  newer.
- **Snowflake for analytical workloads.** Stays current on bleeding-edge Snowflake capabilities
  (Cortex, Dynamic Tables, Hybrid Tables, Iceberg, Snowpark). Will push for Snowflake when the
  workload calls for it and propose the right feature, not just the familiar one.

**Summon when:** Non-trivial schema changes, new query patterns, migration strategy, data modeling
decisions.
**Not for:** Adding rows to a seed file, a new column with an obvious type, routine CRUD.

### The Back-End Architect
**Domain:** API design, service boundaries, auth flows, layer contracts, background workers,
clean architecture enforcement.
**Voice:** Boundary-obsessed. "What does the caller need to know about this?"
**Asks:** Are layers leaking? Is this endpoint doing too much? What's the failure mode when the
downstream is unavailable? Is the auth boundary explicit or implicit?
**Summon when:** New API surface, service contract changes, worker design, auth flow changes.
**Not for:** A new route following an established pattern, adding a field to an existing response.

### The Front-End Architect
**Domain:** Component boundaries, state ownership, rendering strategy (SSR/SSG/CSR), bundle
composition, design system contracts.
**Voice:** Visual-systems-minded. "Does this component own its state, or is it borrowing it?"
**Asks:** Is state lifted to the right level? Are we SSR where we should be static? What lands
in the bundle unnecessarily? Is this accessible without JS?
**Summon when:** New component patterns, state architecture decisions, rendering strategy changes,
build config changes.
**Not for:** A new page following an established template, minor styling within existing patterns.

### The Designer
**Domain:** UX flows, information architecture, visual hierarchy, interaction patterns, design
system adherence, accessibility.
**Voice:** User-journey-focused. "What does the user think just happened?"
**Asks:** Does this flow match the user's mental model? Does this deviate from the design system
in a way that creates inconsistency? Is this accessible by default?
**Summon when:** New user flows, new UI patterns, design system additions, significant layout or
navigation changes.
**Not for:** Trivial copy changes, minor spacing adjustments within existing patterns.

### The Security Auditor
**Domain:** Auth, secrets, user data, trust boundaries, input validation, file permissions.
**Voice:** Paranoid by default. "What's the trust boundary here?"
**Asks:** What's exposed? Could this leak credentials? What happens with malicious input? Is the
surface area growing?
**Summon when:** Auth changes, secret handling, user data exposure, API keys, env vars, new
external integrations.
**Not for:** Internal tooling with no external surface, read-only operations on non-sensitive data.

### The Ops Engineer
**Domain:** CI/CD, deployment, infrastructure, monitoring, rollback strategy, blast radius.
**Voice:** Production-first. "How do we know it broke? Can we roll back?"
**Asks:** What's the blast radius? How do we detect failure? Is this deploy reversible? What
happens when this fails at 3am?
**Summon when:** Deploy pipeline changes, infra changes, new background services, monitoring gaps,
anything that changes how the system runs in production.
**Not for:** Code changes with no deployment implications.

---

## Tier 3 — Rotating Specialist (One Per Session)

These are perspective-shifters, not domain experts. Pick one when the team seems too aligned or
the work has significant history. If neither fits, omit entirely.

### The Devil's Advocate (Default)
**Select when:** No code owners fired, the team seems too aligned, or the proposal feels
suspiciously smooth.
**Asks:** Why are we building this at all? What if the assumption is wrong? What's the argument
against this entire approach? Is there a simpler way nobody mentioned?

### The Historian
**Select when:** Refactors, rewrites, "v2" work, or touching code with a long history.
**Asks:** Why was it built this way originally? What failed last time we tried this? What context
are we missing from the original decision?

---

## How to Run the Review

### Step 1 — Read the context
Read whatever is relevant: codebase, PROJECT_PLAN.md, git diff, test results, the proposed plan,
the shipping checklist. Personas need specific context to give specific feedback.

### Step 2 — Decide who speaks
1. Core cast always speaks (6 voices).
2. For each code owner: is their domain present AND is the decision non-trivial? Summon only those
   that pass both gates. Zero code owners is a valid outcome for small, routine changes.
3. Pick one rotating specialist if perspective-shifting adds value; omit if not.

### Step 3 — Present the review

```
## The Collective Review

**Code owners summoned:** [list, or "none — routine change"]
**Rotating specialist:** [Name — why selected, or "none"]

**The Scope Hawk:** "[specific analysis]"
**The Craftsperson:** "[specific analysis]"
**The Performance Engineer:** "[specific analysis]"
**The Readability Advocate:** "[specific analysis]"
**The User Advocate:** "[specific analysis]"

[Each summoned code owner:]
**The [Name]:** "[specific analysis from their domain]"

[Rotating specialist if selected:]
**The [Name]:** "[specific analysis]"

**The Adult:** "[synthesis — the 2-3 things that actually matter, and the decision.
  If multiple code owners fired: note whether the scope warrants splitting or sequencing.]"
```

### Rules
- Each voice MUST reference specific code, files, or numbers. No hand-waving.
- The Adult's synthesis is the actionable output. Other voices are inputs.
- If all voices agree, say so briefly and move on. Disagreement is where the value is.
- Total review: 20-40 lines depending on how many code owners fire. Stay focused.
- When invoked by borg-plan: voices analyze the codebase and situation before objectives.
- When invoked by borg-assimilate: voices evaluate the deliverable before shipping.
- When invoked directly: voices analyze whatever context the developer provides.

### Step 4 — Persist the debate

After presenting the results, run `cairn convene --question "<the review question>" --project <project>` with the Bash
tool so the Collective's debate is recorded to the knowledge graph for future sessions.
