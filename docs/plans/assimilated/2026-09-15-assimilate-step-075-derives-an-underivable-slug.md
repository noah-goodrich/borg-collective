# Directive: `/borg-assimilate` Step 0.75 derives a slug nothing can derive

*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Filed: 2026-09-15 · Status: Accepted 2026-09-16 · Owner: Noah*
*Shipped: 2026-09-16 — implemented by [#203](https://github.com/noah-goodrich/borg-collective/pull/203)
and [#205](https://github.com/noah-goodrich/borg-collective/pull/205); recorded by
[#202](https://github.com/noah-goodrich/borg-collective/pull/202)*

> **ASSIMILATION NOTE (2026-09-16).** Shipped before this record merged, which is why the record is
> archived on arrival. The fix landed in two parts from the other machine:
> [#203](https://github.com/noah-goodrich/borg-collective/pull/203) found the derivation in THREE
> places (this directive named one and explicitly cleared Step 4c — that was too narrow), and
> [#205](https://github.com/noah-goodrich/borg-collective/pull/205) converged them onto the ratified
> `- Plan-slug:` annotation after a first draft deleted the gate's blocking action entirely.
>
> **THE PARENT LINE ON THIS FILE WAS WRONG AND IS THE REASON IT IS WORTH READING.** It was authored
> with the `design-doc` skill's `*Filed: … · Parent: <file>*` status line, but Step 0.75 greps for
> `^\*Parent plan: <slug>\*`. So this directive — the one ABOUT a gate that could not see its own
> children — was itself invisible to that gate, and `_borg_promote_next_candidates` counted it as a
> TOP-LEVEL auto-promotion candidate. Two other files are still in that state:
> `2026-08-20-comms-delivery-surfaces.md` and `2026-08-20-directive-state-deriver.md`, both children
> of `2026-08-20-communication-program`. The general defect — a sanctioned authoring tool writing a
> convention the gate does not read — is NOT fixed here and needs its own directive.
>
> Verified against `main` at `2b48779` before archiving: AC1 `grep -c 'slugified-objective'` = **0**;
> AC2 refuses with rc 1 naming `- Plan-slug:` on a plan without one, and returns the child when one
> is present; AC3 the gate lists **nine** on this repository; AC4 lint 10.00/10, bats 799, pytest 1148.

**tl;dr** — `/borg-assimilate`'s child-directive gate computes the parent-plan slug from the Objective line,
which produces a 268-character string matching zero directives, and a zero-match is specified to proceed
**silently**. Make the gate read the slug that is now declared in `PROJECT_PLAN.md` instead of deriving one.

## Problem

Step 0.75 exists to refuse assimilation while un-resolved child directives are outstanding. Its rule, verbatim
from `skills/borg-assimilate/SKILL.md:52-54`: *"compute it as `<established-date>-<slugified-objective>` using
the `*Established:*` date and `## Objective` text."*

Run against this repository's own plan, that rule yields:

```
derived  : 2026-08-24-make-borg-link-the-single-front-door-that-answers-from-a-clean-read-of-...   (268 chars)
declared : 2026-08-24-one-front-door-link-derived-fact-surface
match    : False
```

**The declared slug is not derivable from anything.** The title fails too —
`2026-08-24-one-front-door-borg-link-as-the-derived-fact-surface` — because the real slug drops `borg` and
`as-the`. It was chosen by hand, which is the normal and correct way to name an archive file, and no rule
operating on the document's prose can recover it.

**The failure is silent by specification.** `SKILL.md:70`: *"If no matches are found, proceed to Step 1 without
comment — do not mention the check."* Zero matches is indistinguishable from a clean board. Measured today:
**12** directives carry a `*Parent plan:*` line and **9** name this plan. The gate should stop on nine and
instead passes without printing a word.

**It has been masked by a model being smarter than its instruction.** The last three checkpoints all report
`/borg-assimilate` as blocked at Step 0.75 by these directives, so the block is real in practice — a model reads
`*Parent plan:*` lines and recognises them by eye rather than executing the literal derivation. That is the worst
shape for a defect: the mechanism is broken, the outcome looks right, and it stops looking right precisely when
someone finally automates it.

## Solution

Read the slug; do not derive it. `PROJECT_PLAN.md` now carries a machine-readable annotation immediately under
its status line:

```markdown
- Plan-slug: `2026-08-24-one-front-door-link-derived-fact-surface`
```

Step 0.75 becomes: read the annotation, scan `docs/plans/directives/*.md` for `^\*Parent plan: <slug>\*`, stop on
any match. **A missing annotation is reported, never derived around** — the fallback is what produced this bug,
and a gate that cannot identify its own plan must say so rather than pass.

The annotation and its single writer are AC5.9 of
`docs/plans/directives/2026-09-12-ac5-lifecycle-skills-author-manifests.md`. This directive is that criterion's
second consumer and it is why the annotation is worth having beyond `resolve`.

## Non-Goals

- **NOT** changing what Step 0.75 does on a match. The refusal text, the ship-or-sever instruction, and the
  ignore-list for `assimilated/` and `severed/` are correct and stay byte-for-byte.
- **NOT** touching Step 4c. It reuses Step 0.75's *scan* idiom but derives no slug — it matches on the
  **absence** of a `^\*Parent plan:` line and on an explicit `^\*Next:*` pointer. It does not carry this defect,
  and checking that was the point of naming it.
- **NOT** resolving the nine outstanding directives. They are nine judgment calls and they are Noah's. This
  directive fixes the gate that is supposed to surface them.
- **NOT** a slug for every historical plan. Prospective plus this repository's own plan, which is already done.

## Alternatives Considered

**Improve the derivation — truncate, stopword-strip, fuzzy-match.** No. It cannot work in principle: the declared
slug drops two words the title contains and reorders nothing, so recovering it requires guessing which words a
human considered load-bearing. Fuzzy matching a gate is worse than no gate, because a near-miss would silently
bind a directive to the wrong parent.

**Derive from the filename the plan will eventually have.** No. That file does not exist until assimilation
archives it, which is the step this gate runs before. The dependency is circular, and it is the circularity that
produced the prose fallback in the first place.

**Scan every `*Parent plan:*` value and stop if any are outstanding, ignoring which plan they name.** Rejected,
though it is the closest call here. It fixes the silent pass with no annotation and no new concept — but it also
blocks assimilating plan A because plan B has open children, and the measurement above shows that is live today:
three of the twelve name something other than this plan, including `2026-04-14-reveal-mvp-supabase-flyio`, a
different repository's plan entirely. Correct outcome, wrong reason, and it would be wrong the first time two
plans are in flight.

**Do nothing; the model recognises the directives anyway.** Rejected by this repo's own record. `CLAUDE.md`'s
cairn lesson is that discipline does not survive contact, and `reference_test_supplies_derived_value` names this
exact shape: when something other than the production path supplies the answer, the production path is never
exercised. The gate is currently passing on a model's eyesight.

## Acceptance criteria

- [x] **AC1 — Step 0.75 reads `- Plan-slug:` and never derives.** The `<established-date>-<slugified-objective>`
      fallback is deleted from `SKILL.md`, not merely deprioritised.
    - Verify: `grep -c 'slugified-objective' skills/borg-assimilate/SKILL.md` is 0, and the step names the
      annotation.
- [x] **AC2 — A missing annotation stops the gate with a named reason.** Not a pass, not a derivation.
    - Verify: a fixture plan with no annotation produces a refusal naming `- Plan-slug:`; a fixture plan with one
      and a matching child produces the existing block text unchanged.
- [x] **AC3 — The gate fires on this repository, today.** Nine directives, named.
    - Verify: running Step 0.75 against this repo lists all nine files and refuses. It must fail before the fix
      and pass after — a gate proven only in the passing direction is the defect being fixed.
- [x] **AC4 — Nothing else moves.** `make test` green at its floor, `make lint` 10.00/10, `bats tests/` green.

## Risks

- **This makes `/borg-assimilate` refuse where it previously passed, on the first run after it lands.** That is
  the entire point, and it will read as a regression to whoever hits it. The refusal text already says what to do
  (ship it or `git mv` it to `severed/` with a one-line why), so the mitigation is that the message is good, not
  that the surprise is avoidable.
- **One writer, and it is a prompt.** The annotation is written by `/borg-plan` at `02-output` — a model
  following instructions, which is exactly the "model volunteers a value" surface AC5's rulings kept narrowing.
  The difference that makes it acceptable: a wrong slug here fails LOUD under AC2 (no match, named refusal),
  where the current derivation fails silent. Loud-and-wrong is recoverable.

## Decisions requested

1. **Is a missing `- Plan-slug:` a refusal or a warning?** This directive proposes refusal, on the grounds that a
   gate which cannot identify its plan has no business reporting a clean board. The cost is that every existing
   plan without the annotation stops assimilating until someone adds one line. Only this repository's plan has it
   today.
