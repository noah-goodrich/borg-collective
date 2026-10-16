# Directive: the usage probe recognises a usage-billed account
*Established: 2026-10-16*

- Plan-slug: `2026-10-16-usage-probe`

tl;dr: an account billed by usage has no session limit, and its `/usage` prints a cost summary instead of "Current session: N% used". The probe, the poller and `borg doctor` treat that as a parse failure today. Make it a named state, `unmetered`, that is reported as INFO and logged once, and keep every real parse failure a failure. One PR, refs #424.

Filed as a directive because `PROJECT_PLAN.md` holds another plan; see Promotion Trigger.

## Problem

A machine signed in to Claude Code with a usage-billed Enterprise seat prints only this from `claude -p /usage`: a "Total cost" line, duration lines, a code-changes line and a token-usage line. There is no header and no "Current session" line, because there is no session limit to report. `lib/borg/resume-probe.sh` and `bin/borg-usage-watch` both require "Current session: N% used", so on that account:

- `borg doctor` shows `resume-probe` as FAIL, "could not parse".
- `usage-watch.log` gains a "could not parse session_pct" warning on every pass, hundreds a day.
- Every usage sample has a null `session_pct` and `status:"error"`.
- The guardian's failure streak climbs, and limit-class resumes fail closed forever.

On a usage-billed seat there is no session limit to hit or resume from. That is a valid state, not a parse failure. `docs/upgrading.md` also claimed that `install.sh` clears both RESUME FAIL rows, which is false for such an account.

## The change

- A named probe result, `unmetered`, detected by the shape of the output: a "Total cost:" line and no "Current session:" line. No `claude auth status` call per pass.
- `borg_resume_probe` prints the word `unmetered` and returns 0 (cached for the TTL like a percentage). Callers test for the word before treating the answer as a number.
- `bin/borg-usage-watch` writes one row per pass as before, with `status:"unmetered"` and null readings, resets the failure streak, and logs the state only on entry and exit, not every pass.
- The resume gate treats `unmetered` as "no limit": no headroom gate, and a limit-class record is handed to the user (`notify_only`, reason `unmetered_account`) instead of being injected or deferred forever. Every non-limit class is unchanged.
- `borg doctor` shows `resume-probe` as INFO, saying the account is usage-billed with no session limit and that limit-class resumes and the guardian's limit thresholds do not apply.
- `docs/upgrading.md` corrects the "clears both rows" claim.

Readers of `usage-samples.jsonl` need no change: the dispatch guard and the resume gate's guard check both require `status:"ok"` before reading a percentage, and the poller's cadence check reads a percentage only from an `ok` row, so an `unmetered` row means base cadence and an open guard. A new status value, not a new field, so no reader sees an unexpected key.

## Non-Goals

- No cost-based limit (a spend ceiling) for usage-billed accounts.
- No call to `claude auth status` on the poll path; reading `subscriptionType` stays a possible doctor-time detail.
- No change to any non-limit resume path, to the guardian thresholds on a metered account, or to VERSION; the release is a separate PR.

## Acceptance criteria

- [x] **AC1: The probe names the unmetered state.** A cost-style `/usage` yields `unmetered` with exit 0; a subscription `/usage` still yields the session percent; garbage or empty output still fails with "could not parse".
  - Verify: `bats tests/resume_probe.bats`.
  - Evidence 2026-10-16: merged as 7ef78f6 (https://github.com/noah-goodrich/borg-collective/pull/430), green on main at 62df38d: `bats:tests/resume_probe.bats`.
- [x] **AC2: The poller logs an unmetered account once, not every pass, and keeps its row per pass.** The row has `status:"unmetered"` and null readings; no WARNING and no failure streak; a return to a metered reading is logged once; garbage output is still `parse_failed`.
  - Verify: `bats tests/usage_watch.bats`.
  - Evidence 2026-10-16: merged as 7ef78f6 (https://github.com/noah-goodrich/borg-collective/pull/430), green on main at 62df38d: `bats:tests/usage_watch.bats`.
- [x] **AC3: The resume gate treats unmetered as no limit.** A limit-class record is not injected and does not fail closed with a growing `probe_fails`; a non-limit record resumes as before.
  - Verify: `bats tests/resume_gate.bats`.
  - Evidence 2026-10-16: merged as 7ef78f6 (https://github.com/noah-goodrich/borg-collective/pull/430), green on main at 62df38d: `bats:tests/resume_gate.bats`.
- [x] **AC4: `borg doctor` shows INFO for an unmetered account and still FAILs a real probe failure.**
  - Verify: `bats tests/doctor.bats`.
  - Evidence 2026-10-16: merged as 7ef78f6 (https://github.com/noah-goodrich/borg-collective/pull/430), green on main at 62df38d: `bats:tests/doctor.bats`.
- [x] **AC5: `docs/upgrading.md` no longer claims install clears both RESUME FAIL rows on every account.**
  - Verify: `grep -n "usage-billed" docs/upgrading.md`.
  - Evidence 2026-10-16: merged as 7ef78f6 (https://github.com/noah-goodrich/borg-collective/pull/430), green on main at 62df38d: `path:docs/upgrading.md`.

## Ship Definition

PR opened, CI green, the owner's word, squash-merged. On a usage-billed machine, run `borg doctor` once and confirm `resume-probe` reads INFO.

## Risks

- The unmetered shape is a single anchor line ("Total cost:"). If a future Claude Code prints that line on a metered account too, the session line still wins, because the unmetered branch applies only when no session line is present.
- A usage-billed seat with an organisation spend cap would not show a session line either; limit-class resumes would be handed to the user rather than retried. That is the safe side of the unknown.

## Promotion Trigger

`PROJECT_PLAN.md` holds another plan. This directive is executed in place from `docs/plans/directives/` and is assimilated on its own when AC1 to AC5 are ticked.
