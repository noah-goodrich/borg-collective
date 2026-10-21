# Directive: One owned next list, read from the checkpoints
*Filed: 2026-10-20 · Status: Accepted 2026-10-20 · Owner: Noah*

**tl;dr** — On 2026-10-20 three checkpoints written that morning listed 9 distinct items waiting on Noah, and `borg next`, `borg link` and the arrival brief all said nothing waited on him, because no screen reads the checkpoint's Blockers section. One reader turns each checkpoint's wait list and Next Session list (repositories and the Queen) into owned rows, every "next" surface reads those rows, and the repository page shows them whole.

- Plan-slug: `2026-10-20-one-owned-next-list`

## Problem

Measured 2026-10-20, about six hours after the three checkpoints (borg-collective, ingle, the Queen) were written:

- **The checkpoints named 9 distinct items for Noah.** The Queen's listed 5 under "These wait on Noah" and borg-collective's 3. ingle's Blockers named 3 that only Noah can clear, 2 of them also on the Queen's list. The oldest was a credential rotation open for 18 days.
- **Every screen said nothing.** `borg next` returned 0 rows plus "+15 agent tasks · +2 stale drafts". The page printed "— nothing waits on you" and "next  nothing is ready  borg next". The arrival brief printed the same next line. `borg next` then logged "declined".
- **YOU has two sources.** `nextpick.core.work_items` marks a row YOU only for a session waiting at a prompt or a mergeable PR (`_pr_row`). A checkpoint contributes one row, the first block of `## 5. Next Session` (`checkpoint_next_step`), only when the repository has no PR row and no plan row, with owner `—`. Nothing reads `## 4. Blockers` except recon's contradiction check (`recon/core.py::extract_checkpoint_blockers`).
- **"Agent tasks" counts rows nobody owns.** `cap_rows` counts every non-YOU row as an agent task; 6 of the 15 that morning had owner `—`.
- **A stale plan outranks a fresh checkpoint.** `_plan_rows` runs before the checkpoint regardless of age. ingle's row read "Fix 1 works on real Postgres" (owner AGENT) while its same-day checkpoint said the import was blocked on a file copy only Noah can make.
- **NEXT reads manifests only.** `render._next_section` tallies stack manifests (0 of 82 refs ready). `render.next_action` falls back to "nothing is ready", and the arrival brief's owner (`arrival.py::_next`) appears only when `next_action` derives one, so the "next + owner" promised by `2026-10-18-arrival-brief-on-sessionstart` Solution item 2 never shows an owner here.
- **The Queen's checkpoints feed no screen.** `$BORG_ORCHESTRATOR_ROOT/.borg/checkpoints` held the 5-item list.
- **The repository page spends its lines elsewhere.** 8 lines of IN FOCUS fields (Source, Path, Session ID, tmux window), 3 checkpoint filenames, and a 20-line checkpoint excerpt with every long line cut at `PAGE_COLUMNS` (98) by `render._fit_text`.

The model half of the failure, the borg-link skill repeating "Nothing is waiting on you" under an excerpt that said "These wait on Noah", is Phase 1b of `2026-10-03-evals-for-everything.md`.

## Solution

1. **One reader.** Extend `recon/core.extract_checkpoint_blockers` into a pure `checkpoint_owned_items(text)` returning `[{text, owner}]`. Items under a `Waits on you:` lead-in (new form) or a "These wait on <name>:" lead-in (legacy form) in `## 4. Blockers` get owner YOU; `## 5. Next Session` items get AGENT. "No blockers." yields none. The shell reads the whole newest checkpoint (newest by name, `link/core.order_checkpoints`), since Blockers sits past the 20 lines `read_latest_checkpoint_head` reads.
2. **Rows.** `work_items` emits wait items as YOU rows and Next Session items as AGENT rows. A checkpoint newer than `PROJECT_PLAN.md` replaces `_plan_rows`. `cap_rows` counts `—` rows as "unowned".
3. **The Queen.** The Queen scope reads the newest checkpoint under `$BORG_ORCHESTRATOR_ROOT/.borg/checkpoints`; its items appear under the label `queen`. The Queen session still writes nothing to the registry.
4. **Surfaces.** When no manifest ref is ready, NEXT and `render.next_action` fall back to the first Next Session item and its owner. WAITING ON YOU and the arrival brief already derive from nextpick rows and `next_action`, so all three agree by construction.
5. **Page.** The repository page shows fewer things, whole (chosen by Noah 2026-10-20 over wrapping every line):

    ```
    ▸ IN FOCUS  borg-collective · main · idle · now
      Last time: shipped v0.9.10 (doorways board)
        and v0.9.11 (arrival brief).

      Waits on you
      1 Required checks on main: decide.
      2 Native Agent(...) deny rules as a second
        guard layer: decide.

      Next · AGENT
      1 Evals, due 2026-11-15: renew the nanoprobe
        and verify waivers.
      +3 more  borg link --full
    ```

    Each item wraps at `PAGE_COLUMNS` with a hanging indent and is capped by whole items. Source, Path, tmux window, Session ID, the checkpoint filenames and the Goal/Accomplished excerpt leave the page and stay on the `--json` document. The Compass line is omitted when no leg is chosen. Arrival brief lines wrap the same way. Queen board table rows keep their cut.
6. **Template, expand step.** `skills/borg-link-up/SKILL.md` asks for a `Waits on you:` list under Blockers (`Waits on you: none` when empty). The legacy parse stays until a later contract directive.
7. **Housekeeping.** Tick AC8 of `2026-10-18-arrival-brief-on-sessionstart.md` (confirmed via the Queen relay 2026-10-20: startup rendered in borg:1 and in the ingle drone, resume confirmed by Noah), then assimilate it once AC4 here lands.

## Acceptance criteria

- [ ] AC1 — Checkpoint wait items become YOU rows; Next Session items become AGENT rows; the link-up template asks for the new list.
  - Verify: pytest writes fixture checkpoint files (new form, legacy form, "No blockers.") to a tmp dir and reads them through `nextpick.shell`, never by passing `checkpoint_steps` in. A `tests/prose_contracts.bats` case pins the template's `Waits on you:` line.
- [ ] AC2 — The Queen's checkpoint feeds the Queen scope.
  - Verify: pytest with `BORG_ORCHESTRATOR_ROOT` at a tmp dir holding a checkpoint: its wait items are YOU rows in `borg next --rows --json` and in the Queen page's WAITING ON YOU; the registry file is byte-identical before and after.
- [ ] AC3 — A checkpoint newer than `PROJECT_PLAN.md` beats the plan's unchecked criterion.
  - Verify: pytest with both orders of plan mtime and checkpoint timestamp.
- [ ] AC4 — Surfaces agree and carry an owner. No surface prints "nothing waits on you" or "nothing is ready" while the document holds a YOU row or a checkpoint next step; NEXT falls back to the first Next Session item; the arrival brief's next line always carries an owner; `—` rows count as "unowned".
  - Verify: one fixture document rendered through the page, `borg next --line` and the arrival brief in `borg_core/link/test_screen_contract.py`; the six "agent tasks" pins (nextpick `test_core`, `test_cli`; link `test_render`, `test_cli`, `test_screen_contract`) change in the same commit.
- [ ] AC5 — The repository page shows fewer things, whole, on one screen.
  - Verify: a 300-character wait item renders whole across wrapped lines; the existing one-screen height test passes; `test_the_repository_page_cuts_free_text_with_an_ellipsis_and_keeps_every_other_line_whole` is narrowed to the Queen board's table rows.
- [ ] AC6 — Live, and nothing breaks.
  - Verify: on Noah's machine `borg next --rows --json` lists the newest checkpoints' wait items as YOU rows (output pasted in the PR); `make test && make test-bats && make lint` is green; `borg next --line` median stays under 20 ms.
- [ ] AC7 — The cap shares its slots across repositories, so the Queen's wait items show when one repository has five or more.
  - Verify: `test_cap_rows_six_a_and_two_queen_shows_a1_a2_a3_q1_q2_in_original_order_overflow_three` and its siblings in `borg_core/nextpick/test_core.py`; `test_queen_rows_show_when_one_repository_has_six_you_rows_ac7` through `item_rows` and `--rows --json` in `borg_core/nextpick/test_cli.py`; `test_the_queen_page_waiting_on_you_shows_queen_rows_when_one_repository_has_six_you_rows` in `borg_core/link/test_screen_contract.py`.

## Testability

- **Reader:** `checkpoint_owned_items` is pure text in, dicts out, in `borg_core/recon/core.py` beside the function it extends. The file read is a thin `shell.py` wrapper, tested against tmp files.
- **Rows and labels:** `work_items` and `cap_rows` are pure (`borg_core/nextpick/core.py`). The passing test before any refactor is today's suite; the six "agent tasks" pins are the only expected edits.
- **Page and brief:** `render.py` and `arrival.py` stay pure; the document carries the rows.
- **Coverage to confirm in PR 1:** whether `nextpick.shell.checkpoint_next_steps` has a test that reads a real file. If not, PR 1 adds one before changing it. The Queen-scope checkpoint read is new code.

## Non-Goals

- Dispatching AGENT rows automatically. The "+N agent tasks" still wait for Noah to start them; dispatch needs per-repository authorization and its own directive.
- A cleanup flow for stale drafts.
- Dropping the legacy "These wait on <name>:" parse. That is the contract step, after link-ups write the new form.
- Merging the three owner vocabularies (nextpick `YOU/AGENT/—`, recon `yours/mine/unsure`, arrival `yours|mine`).
- Wrapping the Queen board's table rows.
- Removing keys from `borg link --json`. The page drops fields; the document keeps them.

## Alternatives Considered

- **Wrap every line and keep every field.** Rejected by Noah 2026-10-20: the 20-line excerpt wraps to about 40 lines and breaks the one-screen rule Doorways set in #438 and #440.
- **A `recon-adapter-checkpoint` feeding the recon fan-out.** Rejected: nextpick reads recon items as PRs (`_pr_row`), so a non-PR item needs the same nextpick change plus one more adapter process per sweep.
- **An instruction or memory telling the model to check the checkpoint.** Kept only as a stopgap until this ships. Capture that depends on someone remembering is the cairn failure.
- **Parse the legacy prose alone.** Rejected: model-written wording varies ("Noah's call", "waiting on Noah"), and only the template line makes new checkpoints parse reliably.

## Ship definition

- Each PR merges with CI green, gated on `gh pr checks --json bucket` (the exit code is unreliable).
- After the last PR: release bump, plugin mirror through `scripts/build-plugin.sh`, `claude plugin update`, `borg setup`, then AC6 on the installed build.
- One tracking issue carries the PR checklist.

## Timeline

Target 2026-11-01, three PRs at about one session each:

- PR 1: reader, rows, Queen, freshness, labels and the template (AC1-AC3); this directive and the AC8 tick ride along.
- PR 2: surfaces and the arrival brief's owner (AC4).
- PR 3: page and brief wrapping (AC5), then the live check (AC6).
- PR 4: the cap shares its slots across repositories (AC7), added on Noah's word "pr 4" on 2026-10-21 after the live check showed the Queen's rows pushed off by one repository's five.

## Risks

- **Legacy wording.** The legacy match will miss other phrasings. ingle's 2026-10-20 checkpoint already does: it names Noah inside each Blockers bullet with no lead-in, so its items surface only after its next link-up writes the new form.
- **Height budget.** Busy repositories could push the page past one screen. The whole-item cap decides, and the height test catches it.
- **Statusline path.** Reading 18 whole checkpoints is about 100 KB; it must stay off the `borg next --line` path that tmux calls.
