# Directive: Alert-Layer Remediation — Give Borg a Non-Interrupting Channel
*Filed: 2026-08-10*

Independent work — no parent plan. Filed as a directive because `PROJECT_PLAN.md` is still occupied by the
Story-Lens P1 fix pending the merge of PR #104.

## Objective
Stop borg's advisory hooks from interrupting sessions they cannot inform, by (a) building a non-interrupting
channel for subcritical signal and (b) conditioning the two unconditional nudges on real state. Fix the
`borg ls` defects that make it unusable as the destination for that signal.

## Why — the evidence, not the annoyance
Derived from `docs/infoviz/research/2026-08-10-dashboards-operational/04-empirical-test.md`, which applied the
Phase-2 D-rules to borg's own surfaces. The findings, in leverage order, are reproduced as the work items below.

The load-bearing citations:
- **D4 / Google SRE:** an interrupt must be urgent, actionable, human-judgment-requiring, and user-visible —
  all four. And the loophole-closer: *"If a page merely merits a robotic response, it shouldn't be a page."*
- **D7 / Tariq et al. (ACM CSUR 2025, Level 1):** alert fatigue is documented and unsolved, and two of its four
  primary causes are properties of tooling rather than staffing — **High False-alarm Rate** and **Disconnected
  and Overloaded Dashboards**. Borg exhibits both.
- **D5:** borg has exactly **one** in-session delivery channel (`additionalContext`), so every signal it emits
  is by construction an interrupt. This is why the nudge problem is structural, not incidental.

Live evidence: during the single session that produced the Phase 2 research, `pre-commit-remind` fired **five
times** and `tool-count-nudge` **twice**. In every case the correct response was one already taken.

## Scope note — what is NOT broken
The three blocking guards (`bash-guard`, `borg-supabase-guard`, `borg-dispatch-guard`) **pass D4 cleanly** and
must not be touched. Their correct response varies with the alert, which is exactly what D4 exists to permit.
This directive is about the two advisory nudges and the display, not about borg's guard rails.

## Acceptance Criteria

- [ ] C1 — A non-interrupting channel exists: subcritical signal is written to a session-scoped log rather than
      injected into context, and is readable on demand.
  - Verify: a hook writing to the new channel produces no `additionalContext` in its JSON output
    (`... | jq -e '.hookSpecificOutput.additionalContext' ` exits non-zero), and the signal is retrievable via
    the surfacing command from C2.
- [ ] C2 — That channel is surfaced where a human will actually look, not pushed. `borg ls` (or an explicit
      subcommand) shows the accumulated subcritical signal for the current session.
  - Verify: run a session that triggers ≥1 subcritical event, then confirm the surfacing command displays it.
- [ ] C3 — `tool-count-nudge` no longer fires on a raw call count. It either fires on a condition that
      distinguishes a healthy session from a thrashing one, or it is retired to the C1 channel.
  - Verify: `grep -n 'COUNT >= 75' hooks/tool-count-nudge.sh` returns nothing; the replacement trigger is
    documented in the hook header comment.
- [ ] C4 — `pre-commit-remind` fires only when it has reason to believe `/simplify` has not run for the code
      being committed. Preserve the existing `PROJECT_PLAN.md` conditional — it is already the right pattern.
  - Verify: a commit in a session where `/simplify` has run produces no reminder; a commit touching code with
    no `/simplify` run does produce one.
- [ ] C5 — `borg ls` answers "what needs you?" above the fold: live/active projects sort **first**, and the
      top-of-output region leads with the answer rather than decoration.
  - Verify: `borg ls | head -12` contains the most-recently-active project.
- [ ] C6 — `borg ls` summarizes instead of enumerating: idle projects collapse to a count line, and the
      directive-title extraction no longer emits `---` for horizontal rules or frontmatter delimiters.
  - Verify: `borg ls | sed 's/\x1b\[[0-9;]*m//g' | grep -c -- '^    - .*---$'` returns 0; idle projects are not
    printed one-per-line.
- [ ] C7 — After C5 and C6, re-measure against D1. Record the new line count in the PR body whether or not it
      fits one screen; if it still doesn't, say so rather than quietly moving the goalposts.
  - Verify: `borg ls | wc -l` — baseline is **83**.
- [ ] C8 — Regression: full bats suite passes, and every touched hook still exits 0 on malformed/empty stdin.
  - Verify: `bats tests/*.bats` exits 0; `echo '' | hooks/<name>.sh; echo $?` returns 0 for each touched hook.

## Scope Boundaries
- NOT touching the three blocking guards. They pass D4.
- NOT touching the seven silent/lifecycle hooks. They do not consume in-session attention.
- NOT building an interrupt-rate ledger or fatigue metric. D7 says the budget is real and unmeasured; measuring
  it is a separate, larger piece of work and is explicitly deferred.
- NOT redesigning `borg ls` beyond C5-C7. Sort order, summarization, and the extraction bug only — no new
  columns, no new views.
- If done early: ship, don't expand.

## Ship Definition
PR opened against main, CI green, `borg ls` line count recorded in the PR body, all touched hooks verified
fail-open on bad input.

## Timeline
Target: one session. C1/C2 are the real work; C3-C6 are small once the channel exists.

## Risks
- **C3 is the hard one, and it may not have a good answer.** "Distinguishes a healthy session from a thrashing
  one" is easy to state and hard to compute from hook-visible state. If no honest signal exists, the correct
  outcome is to **retire the nudge to the C1 channel**, not to invent a proxy that fails D6 the same way the
  call count does. Retiring it is a success, not a failure.
- **C4 depends on observability that may not exist.** If a hook genuinely cannot tell whether `/simplify` ran,
  fall back to conditioning on "this session edited code files" — weaker, but still a real condition rather than
  the current unconditional fire.
- **Hooks are fail-open by contract and silent when they break.** Every hook touched here runs on every session
  on this machine. C8's malformed-stdin check is not ceremony; a hook that crashes on bad input degrades
  silently, which is exactly the failure mode `borg-link-down.sh` already hit once (see CLAUDE.md, Learned).
- **C5 changes muscle memory.** Reversing the sort order changes a display used daily. It is the right call per
  D2, but expect a brief adjustment period and don't mistake that for the change being wrong.
