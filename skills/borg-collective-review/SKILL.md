---
name: borg-collective-review
description: >
  Adversarial review by The Collective — six core personas plus one rotating specialist debate a
  plan or shipping decision. Called by borg-plan (before proposing objectives) and borg-assimilate
  (before shipping). Can also be invoked directly for ad-hoc design reviews.
user-invocable: true
---

# The Collective — Adversarial Review

You are facilitating a structured review where six engineering personas plus one rotating specialist
each evaluate the current situation from their angle. This is not roleplay — it is a structured
thinking framework that ensures no critical perspective is missed.

## The Core Cast (Always Present)

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
**Asks:** What's O(n^2) that should be O(n)? What's making network calls that could be cached?
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
recommendation. The Adult speaks last and their synthesis is the actionable output.

## The Rotating Specialist (One Per Session)

Before starting the review, select ONE specialist from the pool based on what's being reviewed.
If no specialist fits strongly, default to The Devil's Advocate.

### The Security Auditor
**Select when:** Touching auth, APIs, secrets, user data, environment variables, file permissions.
**Asks:** What's exposed? What's the trust boundary? Could this leak credentials? What happens if
the input is malicious?

### The Ops Engineer
**Select when:** Touching CI/CD, deployment, infrastructure, monitoring, error handling.
**Asks:** What happens when this fails in production? How do we know it broke? Can we roll back?
What's the blast radius?

### The Devil's Advocate (Default)
**Select when:** No other specialist fits, or when the team seems too aligned.
**Asks:** Why are we building this at all? What if our assumptions are wrong? What's the
argument against this entire approach? Is there a simpler way nobody mentioned?

### The Historian
**Select when:** Refactors, rewrites, "v2" work, or touching code with a long history.
**Asks:** Why was it built this way originally? What failed last time we tried this? What context
are we missing from the original decision?

## How to Run the Review

### Input Context
Read whatever is relevant before starting: codebase, PROJECT_PLAN.md, git diff, test results,
the proposed plan, the shipping checklist. Each persona needs context to give specific feedback,
not generic advice.

### Discussion Format

Present each persona's analysis in first person, 2-4 sentences each. Be specific — reference
actual code, actual files, actual numbers. No generic advice. No hand-waving.

```
## The Collective Review

**Rotating specialist this session:** [Name] — [why selected]

**The Scope Hawk:** "[specific analysis of scope and effort]"

**The Craftsperson:** "[specific analysis of quality and testing gaps]"

**The Performance Engineer:** "[specific analysis of efficiency concerns]"

**The Readability Advocate:** "[specific analysis of code clarity]"

**The User Advocate:** "[specific analysis of usability and developer experience]"

**[Rotating Specialist]:** "[specific analysis from their angle]"

**The Adult:** "[synthesis — the 2-3 things that actually matter, and the decision]"
```

### Rules
- Each persona MUST reference specific code, files, or numbers. No hand-waving.
- The Adult's synthesis is the actionable output. The other voices are inputs.
- If all personas agree, say so briefly and move on. Disagreement is where the value is.
- The rotating specialist brings the outsider perspective — they should challenge groupthink.
- Total review should be 20-30 lines. This is a focused exercise, not an essay.
- When invoked by borg-plan: personas analyze the codebase and situation before objectives.
- When invoked by borg-assimilate: personas evaluate the deliverable before shipping.
- When invoked directly: personas analyze whatever context the developer provides.
