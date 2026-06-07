# Directive: Reaper staleness age is off by the local timezone offset

*Filed: 2026-06-06*
*Source: borg-collective-review (Devil's Advocate) during PR #39 assimilation*

## Problem
`_borg_should_reap` (`lib/registry.zsh:218`) parses `state.json` `last_activity` timestamps — which
are written in UTC with a trailing `Z` (e.g. `2026-06-06T17:48:57Z`) — using BSD `date` **without
the `-u` flag**:

```
epoch_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last" +%s 2>/dev/null) || return 0
```

`date -j -f` without `-u` interprets the input string as **local** wall-clock time, not UTC. The
resulting epoch is off by the machine's UTC offset. On Mountain (UTC-6/-7) the computed age is ~6–7h
*less* than the true age, so a session is only reaped after ~18–19h of inactivity instead of the
intended 12h (`BORG_REAP_STALE_HOURS`). The error is silent and machine-/season-dependent (DST).

The bash twin `_borg_should_reap` in `lib/borg-hooks.sh` should be checked for the same bug and kept
in sync.

## Why it wasn't caught
The reaper shipped with no dedicated tests (added in PR #39). The new `tests/reap.bats` deliberately
avoids a TZ-sensitive boundary (it uses years-old / clearly-fresh timestamps), so it passes on any
machine but does not exercise the offset.

## Acceptance Criteria
- [ ] `_borg_should_reap` (zsh, `lib/registry.zsh`) parses `Z` timestamps as UTC — add `-u` to the
      `date -j -f` call, or normalize before comparing. Age must be correct regardless of the host
      timezone or DST.
- [ ] The bash twin in `lib/borg-hooks.sh` gets the identical fix; the two stay in sync.
- [ ] `tests/reap.bats` gains a boundary test that would fail under the buggy parse: an activity
      `BORG_REAP_STALE_HOURS + 1`h in the past reaps, and one `BORG_REAP_STALE_HOURS - 1`h in the
      past is kept — computed from a UTC `now` so the assertion is TZ-independent.
- [ ] `bats tests/` green.

## Scope Boundaries
- NOT changing: the default 12h threshold or the reap predicate's logic (live-window / missing-last
  behavior). This is a timestamp-parsing correctness fix only.
- NOT changing: how `last_activity` is written (already correct UTC `Z`).
