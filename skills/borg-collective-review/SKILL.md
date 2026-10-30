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


## The personas

Read `references/personas.md` (relative to this skill's base directory) before Step 2 and before presenting the review: it holds the Tier 1 Core Cast, Tier 2 Code Owners (with their summon rules) and Tier 3 Rotating Specialists.

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
