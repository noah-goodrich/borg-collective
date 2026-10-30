# Criteria Reconciliation

Read only when the prepared document says `PLAN` is a path (not `none`). Moved verbatim from SKILL.md.

The gate is **mechanical, not judged**: the engine reads the plan's `Evidence:` annotations, resolves each against the real filesystem / git / `gh` / test runner, and returns `pass`, `fail` or `unknown` per criterion. **You do not decide what is met.** Let the engine flip what it proved and report what it did — never second-guess a verdict, never supply one of your own.

**If absent, skip.** `PLAN: none` means nothing to reconcile: do not run the engine, do not emit a `## Criteria Reconciled` section, do not mention it in the checkpoint, and do not say "no plan found" anywhere. The step is a SILENT no-op.

`--apply` implies the derive and reports it, so one invocation both writes and tells you what it wrote. Run it **once per link-up**. If it fails or times out, do NOT retry and do NOT flip anything by hand — write one line in §4 Blockers naming the failure and move on.

Read the verdicts from the JSON the Bash call printed:

- **`pass`** — the engine already flipped `- [ ]` to `- [x]` and stamped `*(flipped by link-up: <evidence>)*`. Write nothing to the plan file yourself: the literal `flipped by link-up` has exactly one writer, and that writer is not you.
- **`fail`** and **`unknown`** — NEVER flipped, by the engine or by you. `unknown` means the pin rotted or could not be checked (missing path, no annotation, degraded `gh`, suite timeout); it is not a regression. Both go into the checkpoint as a NAMED proposal carrying the engine's own `evidence` line and the command that would apply it once the evidence is real.
- A criterion resting only on this session's belief that it finished is never written. No partial credit, no "probably met".

Append the conditional appendix after §5:

```markdown
## Criteria Reconciled

**Flipped** (`pass` — applied by the engine):
- AC6 — <criterion text> — *(flipped by link-up: <evidence>)*

**Proposed, not flipped** (`fail` / `unknown`):
- AC8 — <criterion text> — unknown: <engine evidence line>
  - Apply, once the evidence resolves, with:
    `python3 -m borg_core.planstate.cli <plan> --json --apply`
```

Omit an empty subsection rather than printing "none". Omit the whole section when the engine did not run or returned no criteria.

**Cost and recursion guard.** An `Evidence: pytest:<path>` or `bats:<path>` annotation makes the engine fork a real suite, so a reconciliation can cost minutes. Run the engine against `PROJECT_PLAN.md` ONLY. Never point it at a directive under `docs/plans/directives/`: those carry their own `Evidence:` annotations, including ones covering the engine itself. Every suite is bounded by `BORG_PLANSTATE_SUITE_TIMEOUT`; a timeout resolves to `unknown`, which proposes and never flips. Never let an evidence suite invoke `/borg-link-up`, `borg link`, or this skill. One invocation, no retry loop, ever.

**Assimilate is still the gate.** A link-up flip is bookkeeping, not authorization. `/borg-assimilate` evaluates every criterion independently at ship time, may disagree with anything flipped here, and may un-flip it. A `*(flipped by link-up: ...)*` annotation is NOT sufficient evidence at ship time and must never be offered to assimilate as if it were. Flipping every box does not ship a plan.
