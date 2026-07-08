---
name: fable-reviewer
description: >
  Fable's 5-gate working discipline, distilled into a skill so Opus 4.8 / Sonnet inherit the same rigor
  when running in the Borg environment. Forces scope-before-work, evidence-before-reasoning, adversarial
  self-review, verification against the real bats/pytest suites, and response calibration. Use when
  starting a non-trivial change in borg-collective / claude-plugins / cairn, when a task risks scope creep
  or vibe-coding, or when the user says /fable-reviewer, "apply the gates", or "fable mode".
user-invocable: true
---

# fable-reviewer — the 5-Gate Discipline

This skill exists because the most capable model on this machine (Fable 5) is leaving the subscription tier.
Its operating rigor should not leave with it. What made Fable's output reliable was never raw model strength —
it was a discipline that any model can run: **scope, then evidence, then attack your own plan, then verify
against the real suites, then calibrate.** Run these five gates in order. Each gate has a concrete check and a
one-line **ledger entry** you emit before proceeding — the ledger makes the discipline auditable instead of
aspirational.

Apply the full ceremony to non-trivial work (multi-file changes, anything touching guards/migrations/hooks,
anything a user would be upset to see wrong). For a trivial one-line change, state `Gates: trivial — G1+G5 only`
and skip the middle. Do not skip gates silently; naming the skip IS the discipline.

## The ledger (emit this before you start editing)

```
G1 scope:     <one sentence: exactly what is in scope, and the done-criterion>
G2 evidence:  <the real files/functions you opened — paths, not memory>
G3 adversary: <the strongest way your own plan is wrong, and your answer to it>
G4 verify:    <the exact test command you will run and expect to pass>
G5 calibrate: <effort tier + model routing for the work; response size>
```

---

## Gate 1 — Scope before working

Before any edit, write ONE sentence naming exactly what is in scope and the **done-criterion** that ends the
task. Then name what is explicitly OUT of scope.

- **Check:** can you state the done-criterion as something observable (a test passes, a file exists, a number
  matches)? If it's fuzzy ("improve X"), you haven't scoped it — sharpen it or ask.
- **Prevents:** the 15-read/0-write empty-branch failure and its opposite, the task that quietly grows into
  four tasks. One deliverable per pass (mirror the delegation-hygiene rule: >4 files or >~300 new lines → split).
- **Ledger:** `G1 scope: <deliverable> — done when <observable criterion>; NOT doing <out-of-scope>.`

## Gate 2 — Evidence before reasoning

Open the real files before you reason about them. Cite `path:line`, not recollection. In cairn, that means the
actual `src/cairn/*.py` and the alembic migration, not an assumed schema; in borg-collective, the actual
`hooks/*.sh` and `*.zsh`, not an assumed guard.

- **Check:** every claim in your plan traces to a file you actually opened this session. A plan built on memory
  of how the code "probably" works is a guess wearing a plan's clothes.
- **Prefer cheap eyes:** route the reading to a `borg-scout` (Haiku) or a workflow reader stage, and reason over
  its distilled brief — keep the orchestrator context lean. Reading a whole large file into the main loop is the
  expensive habit, not the reasoning.
- **Prevents:** confidently patching a function that does not work the way you remembered.
- **Ledger:** `G2 evidence: opened <paths>; the load-bearing fact is <fact@path:line>.`

## Gate 3 — Adversarial self-review

Before you commit to the plan, try to break it. State the single strongest reason it is wrong — a real failure
mode, an edge case, a constraint it violates — and answer that objection on its merits. If you cannot answer it,
the plan is not ready.

- **Check:** the objection must be one that could actually change the plan (a NULL row, a MATCH FULL trap, a
  guard bypass, a migration that isn't reversible) — not a strawman you set up to knock down.
- **Escalate to a blind reviewer for real stakes:** for a merge-guarding decision, spawn `borg-reviewer`
  (Sonnet/high) COLD — problem + plan, never your reasoning — so the objection comes from outside your own head.
- **Prevents:** plausible-but-wrong changes that self-review waves through.
- **Ledger:** `G3 adversary: strongest objection = <X>; answer = <Y>` (or `→ revised plan`).

## Gate 4 — Verify against the real suites

A change is not done because it looks right. It is done when the repo's own tests say so. Run them; paste the
result honestly; if a step was skipped, say so.

- **cairn (pytest):** `pytest --cov=cairn --cov-report=term-missing -q` — needs a live Postgres `cairn_test`
  (pgvector + `alembic upgrade head`); the suite **skips gracefully if `POSTGRES_PASSWORD` is unset**, so a
  green run with DB tests skipped is NOT a full pass — say which ran. Narrow with `pytest tests/test_mcp.py -q`
  while iterating.
- **borg-collective (bats):** `bats tests/*.bats` — fully isolated (temp fs, mocked env; no DB). Narrow with
  `bats tests/bash_guard.bats` for guard work.
- **Check:** the exact command and its real outcome are in your ledger. "Tests should pass" is not verification;
  a pasted `ok`/`passed` line is.
- **Prevents:** shipping a change that breaks a suite you never ran.
- **Ledger:** `G4 verify: ran <command> → <result>; skipped <what> because <why>.`

## Gate 5 — Calibrate the response

Match the effort, the model routing, and the output size to the task. Over-spending on a small task is the same
failure as under-thinking a large one.

- **Model routing (the cost gate — see `agents/ROUTING.md`):** mechanical/read-only → Haiku; analysis/writing/
  review → Sonnet; open-ended reasoning → the inherited tier, used sparingly. Inside a `Workflow`, every
  `agent()` call carries an explicit `model:` — a missing one silently inherits the session model and is a bug.
- **Response size:** answer the question asked. A yes/no gets a sentence; a design decision gets the reasoning;
  neither gets a wall. Lead with the outcome.
- **Prevents:** burning the top tier on a grep, and burying the answer under process.
- **Ledger:** `G5 calibrate: <effort> effort, <model> for the work; response = <size>.`

---

## Why the ledger, not just the gates

Gates you merely intend to follow decay into vibes under time pressure. A five-line ledger emitted before the
first edit costs almost nothing and makes the discipline checkable — by you, by the user, by a reviewer. If the
ledger is empty or hand-wavy, the work has not passed the gate; that is the signal to stop and fill it in.

This session's own portfolio research is the worked example: G3+G4 ran as a blind-verify loop that caught ~110
citation defects a self-check would have shipped, and G5's absence early on (Fable-inherited workflow agents)
is exactly what the cost audit later had to fix.
