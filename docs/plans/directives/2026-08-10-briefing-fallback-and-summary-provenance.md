# Directive: Fix `borg link --brief` — silent fallback, field collapse, and summary provenance

*Filed: 2026-08-10 · Status: OPEN*
*Found while running `borg link --brief` from an orchestrator session on the work machine (macOS, v0.8.9).*
*Companion evidence: the observed output is reproduced verbatim below — re-run the command to confirm.*

## Why this exists

`borg link --brief` is documented as the "LLM narrative briefing". On this machine it has never produced a
narrative. It silently prints the non-LLM fallback instead, and the fallback prints the wrong field. Three
independent defects stack up, and the outer two hide the inner one.

Observed output (abridged — 8 active projects, all 8 identical):

```
  borg-collective        [idle, just now]
    Claude is waiting for your input
  warehouse-permissions  [idle, just now]
    Claude is waiting for your input
  ai-data-engineer       [idle, 9d ago]
    Working on: What's up buttercup? | Next: make** before the multi-day
    build kicks off. **The two open decisions (from the checkpoint):**
  dbt                    [idle, 11d ago]
    Claude needs your permission
```

Every line there is wrong in a different way. Taken at face value it says four projects are blocked on the
user right now. None are — there are no live tmux windows except `orchestrator` and `borg-collective`.

## The three defects

### 1. The LLM call fails, and the failure is invisible

`_borg_print_briefing` (`borg.zsh:1573`) runs:

```zsh
briefing=$(_borg_timeout 20 claude -p "$briefing_prompt" \
    --model claude-haiku-4-5-20251001 --no-session-persistence --bare 2>/dev/null) || claude_rc=$?
```

Reproduce the failure directly:

```zsh
claude -p "say ok" --model claude-haiku-4-5-20251001 --no-session-persistence --bare
# → Not logged in · Please run /login     (exit code 0)
```

The headless `claude` CLI has no usable credentials here even though the interactive session is authenticated.
On macOS the Claude Code OAuth token is Keychain-only, so a non-interactive subprocess does not inherit it.

The guard at `borg.zsh:1577` correctly catches this (it explicitly tests for `*"Not logged in"*` because the
CLI exits 0 on auth failure). The bug is not the detection — it is that detection is **silent**. `stderr` is
sent to `/dev/null`, `claude_rc` is never surfaced, and the fallback is printed with no marker. The user
cannot tell a degraded briefing from a real one, so a permanently dead LLM path looks like a working feature.

That is the whole reason defects 2 and 3 survived: nobody could see which code path they were reading.

### 2. Empty `summary` collapses the field list and shifts every later field left

`borg.zsh:1516` reads five tab-joined fields in one `read`:

```zsh
IFS=$'\t' read -r proj_status last_activity summary waiting_reason project_path <<< \
    "$(echo "$registry" | jq -r --arg p "$name" \
        '.projects[$p]
         | [.status // "unknown", .last_activity // "", .summary // "",
            .waiting_reason // "", .path // ""]
         | join("\t")')"
```

Tab is an **IFS whitespace** character. A run of IFS whitespace delimits as one field, so when `summary` is
empty the field list shifts left by one:

| variable | intended | actual when `summary` is empty |
| --- | --- | --- |
| `summary` | `.summary` | `.waiting_reason` |
| `waiting_reason` | `.waiting_reason` | `.path` |
| `project_path` | `.path` | *empty* |

Empirical confirmation, not theory: `warehouse-permissions` has `summary: null` in `registry.json` and
`waiting_reason: "Claude is waiting for your input"` in `.borg/state.json`, and that `waiting_reason` string
is what got printed as its summary. The four projects that printed a real summary
(`ai-data-engineer`, `analytics-engineer-ai-overseer`, `claude-marche`, `segment-transforms`) are exactly the
four with a non-empty `summary` — no collapse, no shift.

**The second-order consequence is worse than the display bug.** `project_path` lands empty, so the checkpoint
block at `borg.zsh:1530-1538` never fires, and the latest checkpoint is dropped from the LLM payload for every
project with an empty summary. The briefing prompt asks Haiku to source `Last:` and `Next:` from the checkpoint.
So even with defect 1 fixed, the narrative would be built from the thinnest possible input for most projects.

Recommended fix — swap the delimiter for a non-whitespace one, keeping the single-`jq`-call design:

```zsh
IFS=$'\x1f' read -r proj_status last_activity summary waiting_reason project_path <<< \
    "$(echo "$registry" | jq -r --arg p "$name" '... | join("")')"
```

`0x1F` is safe as a delimiter precisely because `_borg_registry_write` (`lib/registry.zsh:29`) strips
`\000-\010\013\014\016-\037` from every registry write, so a unit separator can never appear inside a stored
value. Adjacent non-whitespace delimiters produce empty fields, which is the behaviour this code assumed.

Then grep for the same pattern elsewhere before closing:

```zsh
grep -rn "IFS=\$'\\\\t' read" /Users/noahgoodrich/dev/borg-collective
```

Known other sites: `lib/registry.zsh:169` (2 fields, currently masked by a `[[ -z "$ppath" ]] && continue`
guard) and `borg.zsh:1602`. Both are latent rather than active — fix or annotate, do not leave silent.

### 3. `summary` is the user's first prompt, not a summary

`summarize.py:207-210` builds the field as *"Working on: first substantive user message"*. That is why the
registry says `Working on: What's up buttercup?` for `ai-data-engineer` and `Working on: /clear clear` for
`segment-transforms`. The `Next:` half is a truncated tail that keeps its raw markdown, producing
`Next: make** before the multi-day build kicks off. **The two open decisions...` mid-sentence.

This field feeds `borg ls` and `borg link` too, so it is not briefing-local. A greeting is not a goal, and a
severed sentence is not a next action.

## Phase 1 — Make the failure loud (~20 min, do this first)

Smallest change, largest gain: it converts every future instance of this class of bug from invisible to
obvious.

1. Capture the `claude` invocation's stderr to a variable or a log under `$BORG_DIR` instead of `/dev/null`.
2. When the fallback path is taken, print one dim line above it naming the reason, e.g.
   `(narrative unavailable: claude not logged in — showing registry fallback)`. Distinguish at minimum:
   non-zero exit, timeout, and the `Not logged in` case.
3. Add `claude -p` reachability to `borg doctor` so the dead narrative path is caught by a health check
   rather than by reading output and noticing it looks thin.

Do **not** attempt to fix headless `claude` auth as part of this directive. That is a credential question,
not a briefing question, and it may have no clean answer on macOS given the Keychain-only token. Report it
accurately and move on.

## Phase 2 — Fix the field collapse (~30 min)

1. Apply the `0x1f` delimiter fix at `borg.zsh:1516`.
2. Verify `project_path` is populated by confirming the checkpoint block now fires — the LLM payload should
   contain a `--- latest_checkpoint (...) ---` section for every project that has one on disk.
3. Sweep the other `IFS=$'\t' read` sites.
4. Add a `tests/briefing.bats` case with a fixture project whose `summary` is null and whose
   `waiting_reason` is set, asserting the fallback does **not** print the `waiting_reason`. This is the
   regression that must not come back; it is invisible without a test.

Note for whoever picks this up: `tests/briefing.bats` was previously green against a stale `borg briefing`
subcommand while the real `link --brief` path was untested. Confirm the new test actually exercises the
production path.

## Phase 3 — Fix summary provenance (~1h, needs a decision first)

Open question to settle before coding, because it changes the shape of the fix: **should `summary` be
derived from the checkpoint instead of the transcript?** Checkpoints are the artifact the agent already
produces, and the repo's own hard-won lesson is that derived capture works where volunteered capture does
not. The first user message is neither — it is a transcript accident.

Options, in the order I'd try them:

1. **Derive from the latest checkpoint** — take its Accomplished / Next Session sections. Highest fidelity,
   and the briefing already reads that file anyway.
2. **Keep the transcript heuristic but fix the obvious failures** — skip greetings, slash commands, and
   sub-N-word messages when choosing the "first substantive" message; strip markdown and never cut
   mid-sentence.
3. **Drop `summary` from the fallback entirely** and print only `status` + relative time. Honest and empty
   beats confident and wrong.

Option 1 is the right answer if checkpoints are reliably present; option 3 is the correct interim if they
are not. Do not ship option 2 alone — it treats the symptom.

## Phase 4 — Decide whether `waiting_reason` should be user-facing at all (GATED)

`hooks/borg-notify.sh:17,46` stores Claude Code's Notification `.message` verbatim as `waiting_reason`. The
stock strings are `Claude is waiting for your input` and `Claude needs your permission`. Those describe the
*harness*, not the project — they carry no per-project information, which is why all eight rows read alike.

Worse, they are never cleared. `dbt` still carries `Claude needs your permission` 11 days after the fact,
with no live session. A stale transport-level string presented as current project state is actively
misleading — it is what made the output read as "four projects blocked on you right now".

Do not start this phase until Phases 1-3 are done. It is a data-model question (should `waiting_reason` be
cleared on status change, be excluded from all human-facing output, or be replaced by the notification's
`tool_name` where present) and it will be much easier to reason about once the display path is honest.

## Phase 5 — `--brief` is now a second, un-swept truth level of `borg link` (filed 2026-08-26, **CLOSED 2026-08-27**)

**CLOSED.** Fixed exactly as the last paragraph of this phase specifies: the narrative is now routed through the
Python document. `_borg_print_briefing` builds it once with `_borg_py borg_core.link.cli --json`, projects that JSON
into the prompt with one `jq`, and re-renders the same bytes through a new `--render-document` seam when the narrative
is unavailable. The registry walk is deleted, not patched. Spec and rationale:
`docs/plans/directives/2026-08-27-fold-brief-into-the-document.md`. Evidence is a subprocess count in
`tests/link_sweep.bats` (`sweep: link --brief sweeps exactly as link does, counted rather than read`), which is the
verification this directive's own acceptance criterion asked for.

**Phase 3 is SUBSUMED, not skipped**, on this phase's own reasoning: the grid carries provenance per node, so the
prompt now tells the model what was observed (`swept` / `fetched`) versus what somebody typed (`declared`), and
`summary`'s trustworthiness stops being the question. **Phase 4 stays open** and is unaffected.

**One acceptance criterion below is superseded rather than met** — see the note on the `--- latest_checkpoint ---`
line. The rest of this section is left as filed, for the record of what the defect was.



*Filed by S4 of the one-front-door plan (`docs/plans/directives/2026-08-25-link-front-door-hardened-spec.md`).
S4 is recording this gap, not closing it: the fix is a rewrite of `_borg_print_briefing`, which this
directive owns.*

S3 of that plan folded the recon fan-out into `borg link`, so every other shape of the command now answers
from a live sweep of GitHub state joined onto the manifests. **`--brief` does not.** Its dispatch arm in
`_borg_link_dispatch` calls `_borg_print_briefing` directly and never reaches `borg_core.link.cli`, so it
never sweeps, never reads a manifest, and never sees a `grid`. Measured: zero `gh` subprocesses on the
`--brief` path against one batched call on every other arm.

That makes `borg link` and `borg link --brief` two different answers to the same question from the same
command — which is precisely the failure class AC1 exists to eliminate ("one front door, always a clean
read"). It is worse than the defects above, not milder: those make the briefing *look* wrong, this makes it
*be stale* while looking authoritative. AC1's own scope call left it out because fixing it is a rewrite of
`_borg_print_briefing` (~250 lines of zsh) that collides head-on with Phases 1-3 here, and doing it inside
the sweep fold would have meant re-deciding the fallback semantics in the same commit as the network change.

Two things are declared rather than hidden in the meantime: `borg help` states `--brief` is
"registry-only; never sweeps", and the dispatch arm carries the same note in a comment.

**Do NOT "fix" this by adding `--local` to the `--brief` arm.** `--local` would make the un-swept answer
*cheap*; it would still be un-swept. That is the same lie with a smaller bill, and it would also make the
gap harder to find, because the two arms would then agree about cost and disagree only about truth.

The real fix belongs with Phase 1's decision: route the narrative through the Python document, so the
briefing's input is the same `grid` the overview renders, and the LLM summarizes derived fact instead of
registry `summary` strings. That subsumes Phase 3's provenance question — a swept `grid` has provenance per
node (`swept` / `declared` / `unknown`) and does not need `summary` to be trustworthy.

### 5b — `/borg-recon` is the SECOND un-folded human digest (filed 2026-08-26, NOT FIXED)

`--brief` is not the only human surface that answers "what changed?" from outside `borg link`'s document.
AC1 retired the `recon` VERB but deliberately kept the ENGINE, because `borg recon --json` has real machine
consumers — and one of those consumers, `skills/borg-recon/SKILL.md`, is itself a **human-facing briefing**
invoked as `/borg-recon`. So `borg help` now says recon retired because "there is nothing a human still
needs it for", while a skill three lines below renders the by-project digest AC1 retired.

It is a worse shape than `--brief` in one specific way: the two surfaces do not merely disagree, one of
them **mutates state the other is asserted never to touch**.

- `borg link` — window: a fixed 90 days (`grid.DEFAULT_SWEEP_WINDOW_DAYS`, overridable via
  `BORG_LINK_SWEEP_WINDOW_DAYS`). Writes `$BORG_DIR/recon/last-run`: **never**, and that is pinned twice, by
  `borg_core/link/test_grid.py` and by `tests/link_sweep.bats`'s AC1 cache case.
- `/borg-recon` → `borg recon --json` — window: recon's since-ladder (explicit > newest checkpoint mtime > last-run
  marker > 24h). Writes `$BORG_DIR/recon/last-run`: **yes, and it ADVANCES the marker.**

So running `/borg-recon` changes what the NEXT `borg recon --json` sees, on a window `borg link` does not
share. Two answers to one question, one with a persistent side effect on the other's inputs.

**S4 declared this rather than fixing it**, matching the `--brief` scope call above: `borg help` and
`docs/cheatsheet.md` no longer advertise `/borg-recon` as "the morning link-up" — both now title it
"cross-source synthesis over `borg recon --json` (`borg link` is the front door)". The skill itself is
unchanged and still works; only its billing as the default human entry point is gone.

The fix is the same shape as Phase 5's: once `borg link`'s document is the single input, `/borg-recon`
becomes a synthesis layer over THAT document (contradictions, Yours-vs-Mine, kickoff batch) rather than a
parallel sweep with its own mark. Do that after Phase 5, not before — they share the routing decision.

## Acceptance criteria

- [x] `borg link --brief` prints an explicit reason line whenever it falls back to the non-LLM path
- [x] `borg link --brief` answers from the same swept document as `borg link` — no second truth level
      (Phase 5; verify by a bats case counting `gh` subprocesses on the `--brief` path against the
      overview's, in the `tests/link_sweep.bats` fixture where a sweep genuinely runs)
      — **MET 2026-08-27** by exactly that case, `sweep: link --brief sweeps exactly as link does, counted rather
      than read`: one `pullRequests(first:` plus one `issueOrPullRequest(number:` on each arm, side by side on one
      fixture. Four further cases force each `fallback_reason` branch and assert the document renders under each.
- [ ] `/borg-recon` synthesizes `borg link`'s document rather than running its own sweep on its own mark
      (Phase 5b; verify that a `/borg-recon` run leaves `$BORG_DIR/recon/last-run` unchanged, the mirror of
      the AC1 cache case's existing assertion for `borg link`)
- [x] `borg doctor` reports headless `claude -p` reachability
- [x] A project with a null `summary` and a set `waiting_reason` never displays the `waiting_reason` as its
      summary — covered by a `tests/briefing.bats` case that exercises `link --brief` (re-pointed at the document
      2026-08-27; the field-shift MECHANISM is gone with the `read` loop, the SEMANTIC claim is still asserted)
- [~] The LLM payload includes `--- latest_checkpoint ---` for every active project that has one on disk
      — **SUPERSEDED 2026-08-27, consciously.** The document carries `checkpoint_head` for the FOCUSED repository
      only, so the folded payload does too. Widening the wire to a per-project head is a v2→v3 bump with four coupled
      `skills/borg-link/SKILL.md` edits; re-reading checkpoints in zsh would reinstate the second derivation Phase 5
      just deleted. The replacement input is the grid's per-node provenance and READY set, which is the trade this
      phase's own closing paragraph argues for. Re-file it against the wire if the narrative measurably suffers.
- [ ] No `IFS=$'\t' read` site in the repo can silently shift fields on an empty value
- [ ] `borg ls` and `borg link` no longer surface a raw user greeting or a mid-sentence fragment as a summary
- [ ] Full bats suite green

## Non-goals

- Fixing headless `claude` authentication on macOS. Report it; do not chase it here.
- Rewriting the briefing prompt or its output format. The prompt is fine; its input is not.
- Touching the reaper. Status staleness is already handled correctly — `borg reap` downgraded 6 phantom
  `waiting` projects the same session this was found, and that path worked exactly as designed.
