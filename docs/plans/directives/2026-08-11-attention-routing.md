# Directive: Attention Routing — Give Subcritical Signal Somewhere Else to Go
*Filed: 2026-08-11*

Independent project. Carved out of `2026-08-10-link-unification-and-attention-routing.md` (now severed). This is
the **hook** half; the display half is `2026-08-11-link-unification-and-layout.md`.

## Objective
Stop borg's advisory hooks interrupting sessions they cannot inform. Build a non-interrupting channel for
subcritical signal, then condition the two unconditional nudges on real state — or retire them.

## Why
Phase-2's **D5** finding: borg has exactly **one** in-session delivery channel (`additionalContext`), so every
signal it emits is by construction an interrupt. That is why the nudge problem is structural rather than a
tuning issue — with a single channel, **D4** would have to hold for every signal, which is infeasible.

Measured in the session that produced this analysis: `pre-commit-remind` fired **five times** and
`tool-count-nudge` **twice**. In every case the correct response was one already taken. Google SRE, verbatim:
*"If a page merely merits a robotic response, it shouldn't be a page."*

And **D7** (Tariq et al., ACM CSUR 2025 — the one Level-1 source in the track) names two of its four primary
causes of alert fatigue as properties of *tooling* rather than staffing: **High False-alarm Rate** and
**Disconnected and Overloaded Dashboards**. Borg exhibits both.

## What is NOT broken — do not touch it
The three blocking guards — `bash-guard`, `borg-supabase-guard`, `borg-dispatch-guard` — **pass D4 cleanly.**
Their correct response varies with the alert, which is exactly what D4 exists to permit. A blocked `rm -rf` and a
blocked `supabase db reset` demand different actions. Leave them alone.

The seven silent/lifecycle hooks do not consume in-session attention. Also out of scope.

## Sequencing
Prefer landing `2026-08-11-link-unification-and-layout.md` first, so the C1 channel has a surface to be read
from. Not a hard block — the channel can be readable by an explicit subcommand in the interim.

## Acceptance Criteria

- [ ] A1 — A non-interrupting channel exists: subcritical hook signal is written to a session-scoped log rather
      than injected into context.
  - Verify: a hook writing to the channel produces no `additionalContext`
    (`... | jq -e '.hookSpecificOutput.additionalContext'` exits non-zero), and the signal is retrievable.
- [ ] A2 — That channel is surfaced where a human will actually look — in `borg link`'s output or via an explicit
      subcommand. Pull, not push.
  - Verify: run a session that triggers ≥1 subcritical event, then confirm the surfacing command displays it.
- [ ] A3 — `tool-count-nudge` no longer fires on a raw call count. It either fires on a condition that
      distinguishes a healthy session from a thrashing one, or it is **retired to the A1 channel. Retiring it is
      a success, not a failure.**
  - Verify: `grep -n 'COUNT >= 75' hooks/tool-count-nudge.sh` returns nothing; the replacement trigger is
    documented in the hook header.
- [ ] A4 — `pre-commit-remind` fires only when it has reason to believe `/simplify` has not run for the code
      being committed. **Preserve the existing `PROJECT_PLAN.md` conditional** — it is already the right pattern
      and the only conditional the hook currently has.
  - Verify: a commit in a session where `/simplify` has run produces no reminder.
- [ ] A5 — Regression: full bats suite passes, and every touched hook exits 0 on empty/malformed stdin.
  - Verify: `bats tests/*.bats` exits 0; `printf '' | hooks/<name>.sh; echo $?` returns 0 per touched hook.
  - Not ceremony: hooks are fail-open by contract and silent when they break. `borg-link-down.sh` already hit
    exactly this failure mode once (CLAUDE.md, Learned).

## Scope Boundaries
- NOT touching the three blocking guards. They pass D4.
- NOT touching the seven silent/lifecycle hooks.
- NOT building an interrupt-rate ledger or a fatigue metric. D7 says the budget is real and unmeasured; measuring
  it is a larger, separate piece of work.
- NOT porting any hook to Python. Measured: Python's floor is ~41 ms vs zsh's ~27 ms, and these fire on every
  tool call. See `2026-08-11-python-core-and-toolchain.md`.
- If done early: ship, don't expand.

## Ship Definition
PR against main, CI green, all touched hooks verified fail-open on bad input.

## Timeline
One session. A1/A2 are the real work; A3/A4 are small once the channel exists.

## Risks
- **A3 may not have a good answer.** "Distinguishes a healthy session from a thrashing one" is easy to state and
  hard to compute from hook-visible state. If no honest signal exists, **retire the nudge** rather than invent a
  proxy that fails D6 the same way a call count does.
- **A4 depends on observability that may not exist.** If a hook genuinely cannot tell whether `/simplify` ran,
  fall back to conditioning on "this session edited code files" — weaker, but still a real condition rather than
  an unconditional fire.
- **Every hook here runs on every session on this machine.** A crash degrades silently. A5 is the guard.
- **Retiring both nudges is a legitimate outcome.** If that happens, the honest read is that the advisory-nudge
  idea was wrong, not that the directive failed.
