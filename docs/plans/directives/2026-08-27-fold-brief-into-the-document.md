# Directive: Fold `--brief` onto the document — AC1's last two truth levels
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: 2026-08-10-briefing-fallback-and-summary-provenance*
*Filed: 2026-08-27*

**tl;dr** — `borg link --brief` never reaches `borg_core.link.cli`. It re-derives its own view from the registry, never
sweeps, and never sees a manifest — so one verb answers the same question two ways. Point the narrative at the
document `borg link` already builds, and delete the second derivation rather than fixing it.

## Why this exists

**This is the one thing standing between AC1 and a tick.** Both of AC1's verify clauses already pass — `borg help` is
net shorter, and two consecutive runs write no cache artifact — and the box is deliberately left unticked in
`PROJECT_PLAN.md` because the stated goal ("one front door, always a clean read") is not met while one flag answers
from somewhere else. `cli.py`'s own comment names it: *the failure class AC1 exists to kill*.

Measured: **zero `gh` subprocesses on the `--brief` path, against one batched call on every other arm.**
`_borg_link_dispatch` (`borg.zsh:3118`) calls `_borg_print_briefing` directly and returns before any Python runs.

**What `--brief` reads instead.** `_borg_print_briefing` is 177 lines that re-implement a board from the registry:
`status`, `last_activity`, `summary`, `waiting_reason`, `path` per project, plus the newest checkpoint file. Every one
of those is already a field on the document, computed once, with the staleness overlay applied — and the document
additionally carries `grid`, `scope`, `focus`, `directives`, `assimilated` and `capacity`, none of which the narrative
can currently see.

**The consequence is not cosmetic.** The narrative summarizes `summary` strings, which are null on nearly every project
until someone runs `--refresh`, and `waiting_reason`, which the 2026-08-10 directive documented rendering as *"four
projects blocked on you right now"* when none were. The document's `grid` carries per-node provenance
(`swept` / `fetched` / `declared` / `unknown`) and AC4's `ready` set — derived fact the LLM could summarize instead of
hand-typed registry text.

## What is already done, so this directive does not re-file it

The parent directive's Phases 1 and 2 have shipped and were verified while writing this:

- **Phase 1 (make the failure loud)** — `claude`'s stderr goes to `$BORG_DIR/briefing-stderr.log`, and
  `fallback_reason` distinguishes timeout (`rc 124`), the `Not logged in` string (which exits **0**, so the string
  match is the only signal), any other non-zero exit, and empty output. `borg doctor` checks `claude -p`.
- **Phase 2 (field collapse)** — the `0x1f` delimiter is in place; `tests/briefing.bats` carries 12 cases.

**Phase 3 (summary provenance) is explicitly SUBSUMED by this directive, not skipped.** Its open question was whether
`summary` should be trusted as an input. Once the narrative reads the document, the question dissolves: the grid has
provenance per node, so the LLM can be told what was observed versus what somebody typed.

## Solution

`--brief` becomes a PRESENTATION MODE OF THE DOCUMENT, not a parallel path.

1. **`_borg_link_dispatch`'s `--brief` arm builds the document first** — the same `_borg_py borg_core.link.cli --json`
   call every other arm makes, with `--local` honoured exactly as elsewhere and no new opt-down.
2. **The LLM payload is derived from that JSON**, not from a second registry walk. `_borg_print_briefing`'s 177 lines
   of jq collapse to a prompt built over fields that already exist.
3. **The fallback stops being a hand-rolled table.** When the narrative is unavailable — timeout, not-logged-in,
   non-zero, empty — print the **normal human document**, prefixed by the existing one-line `fallback_reason`. That is
   strictly more information than today's registry table, it is the page the user would have got anyway, and it means
   the fallback path can never again drift from the real one. **This is the single biggest simplification in the
   change and the reason to prefer it over patching the existing fallback.**
4. **`--brief` keeps its name and its contract**: a narrative for a human, at the document's breadth and scope.

## Non-goals

- Fixing headless `claude` auth. The parent directive already rules this out — a credential question, not a briefing
  question, and possibly unanswerable on macOS given the Keychain-only token. Report it accurately and move on.
- Making `--brief` cheap by adding `--local` to its arm. Named and rejected in the parent: `--local` would make the
  un-swept answer *cheap* and still leave it un-swept — the same lie with a smaller bill, and harder to find because
  the two arms would then agree about cost and disagree only about truth.
- Changing what `--refresh` does, or retiring `summary`. Both are separable.
- `/borg-recon`, the SECOND un-folded human digest (parent Phase 5b). It is a skill rather than a command and does not
  block AC1's verify clauses; file it separately if it still matters after this lands.

## Alternatives considered

**Leave it; `borg help` declares the difference.** Rejected — that is the current state, and a declared inconsistency is
still an inconsistency. AC1's whole subject is that one command has one answer.

**Delete `--brief`.** Considered seriously, on the same evidence that retired `borg watch`: shell history shows zero
typed `borg link --brief` invocations. Rejected for now because unlike `watch`, `--brief` has a live consumer path
(`borg init`'s morning briefing) and a filed directive full of analysis that assumes it exists. Worth revisiting if the
fold turns out to cost more than the narrative is worth — the honest test is whether anyone reads it after it starts
telling the truth.

**Rewrite `_borg_print_briefing` in place, keeping the registry walk.** Rejected: it preserves the second derivation,
which is the actual defect. Every field it reads is already on the document.

## Acceptance criteria

- [ ] `borg link --brief` spawns the same sweep as `borg link` — asserted by subprocess count, not by reading code.
- [ ] The narrative prompt is built from the document; no second registry walk survives in `_borg_print_briefing`.
- [ ] When the narrative fails, the human document renders, prefixed by the existing `fallback_reason` line.
- [ ] A bats case forces each `fallback_reason` branch and asserts the document renders under each.
- [ ] `tests/briefing.bats`'s 12 cases still pass or are consciously rewritten — none silently deleted.
- [ ] `PROJECT_PLAN.md`'s AC1 ticks, with the un-tick rationale replaced by the evidence that it now holds.
