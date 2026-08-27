# Directive: Retire `borg watch`, `drone status`, and `borg switch`'s preview pane
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Filed: 2026-08-27*

**tl;dr** — Three `borg link` consumers have zero typed invocations in six months of shell history, and between them
they justify the `--local` opt-down's urgency, a `grep` against the human document, and a whole filed directive. Delete
them. `borg switch` keeps its picker and loses only the preview.

## Why this exists

Measured over `~/.zsh_history`, **2026-03-07 → 2026-08-25** (2650 timestamped entries):

| command | typed invocations in ~6 months |
|---|---|
| `borg switch` (the only caller of the fzf preview) | **0** |
| `borg watch` | **0** |
| `drone status` | **0** |
| `borg link` (typed at a shell) | **0** |
| `borg next` | 1 |
| `drone up` | 15 |

**What that measurement does NOT cover, stated so nobody over-reads it.** The tmux hotkey `Ctrl+Space >` runs
`borg next --switch` without touching shell history. The `/borg-link` skill runs `borg link --json` inside Claude
sessions, which is the real and constant consumer — `borg link` scoring 0 here means nobody TYPES it, not that nobody
runs it. A second machine keeps its own history file. So this is evidence about human-typed usage of three specific
commands, and on that narrow question it is unambiguous.

**What they cost while unused.** These three are named, in comments and in tests, as *the hot loops* — the reason
`--local` is urgent, the reason `--deep` is discussed, the reason the `Status:` line's position is load-bearing:

- `drone.zsh:964` runs `borg link --local "$wname"` once per tmux window and extracts its status column with
  `grep -m1 'Status:'` out of the **human** page.
  `docs/plans/directives/2026-08-27-drone-status-off-the-human-document.md` was filed this morning to move it onto
  `--porcelain`. Deleting the command closes that directive for free.
- `borg.zsh:266` re-executes `borg link --local {1}` on **every cursor move** in the picker.
- `borg.zsh:2202`'s `cmd_watch` re-renders the whole overview every 5s in a `while true` loop.

## Two corrections to claims made while scoping this

**`--deep` is NOT freed by deleting the preview.** An earlier reading of this held that the fzf preview was the last
caller passing `--deep`, so removing it would let the argument leave the parser. **False.**
`_borg_link_dispatch` (`borg.zsh:3107-3115`) sets `_link_py_args=(--deep)` for **any** positional invocation — every
`borg link <project>`, including `drone link` and the skill's fallback path. The preview is one caller of that arm, not
the arm's only reason to exist. `--deep` stays exactly as it is, and cli_contract's B16 keeps pinning it.

**`cmd_watch` is asserted to SURVIVE by an existing test.** `tests/cli_contract.bats:3567` lists it alongside
`_borg_read_directives` and `cmd_ls` in the survivor half of the nine-deleted-helpers case. That case must move
`cmd_watch` from the survivor list into the deleted list — it is a real assertion, not a comment, and it goes red on a
correct deletion.

## Solution

Delete `cmd_watch` (`borg.zsh:2202`) and its `watch)` dispatch arm (`borg.zsh:3204`). Delete `cmd_status`
(`drone.zsh:933`) and its `status)` arm (`drone.zsh:1405`). Delete the `--preview` and `--preview-window` lines from
`cmd_switch` (`borg.zsh:266-267`), keeping the picker itself.

**`borg switch` survives on purpose.** The picker is a fuzzy list of project names that routes to a tmux window; the
preview is a 70-column render of a document the user is one keystroke away from anyway. Deleting the pane removes the
per-keypress subprocess and leaves the useful half.

Tests, comments and help text that name these three, all of which must be revisited rather than mass-deleted:

| file | what changes |
|---|---|
| `tests/cli_contract.bats:3567` | `cmd_watch` moves to the deleted list (see correction above) |
| `tests/cli_contract.bats:2741` | `drone status extracts the session status, not a pull request title` — goes |
| `tests/cli_contract.bats:3119` | `drone status can still extract Status: from the deep dive` — goes |
| `tests/cli_contract.bats:2925` | parses `--preview-window` out of `borg.zsh` for the picture-width gate — needs a new bound, see below |
| `tests/cli_contract.bats:879` | the `cmd_watch` no-`--once` note — goes |
| `tests/link_sweep.bats` | `drone status triggers zero adapter and zero gh subprocesses` — goes |
| `borg.zsh` help / `drone.zsh:19` help / `CLAUDE.md` | the command tables |
| `docs/plans/directives/2026-08-27-drone-status-off-the-human-document.md` | move to `docs/plans/severed/` — closed by deletion, not by work |

**`PICTURE_BUDGET` loses its empirical bound and that must not pass silently.** `cli_contract.bats:2925` currently
measures the widest golden picture row against the number parsed out of `borg.zsh:267`'s `right:70:wrap`. Delete the
preview and there is no pane to compare against. `PICTURE_BUDGET = 68` should become the assertion's own bound rather
than being dropped — otherwise this directive quietly retires the only check that the picture fits anything. That
interacts with `docs/plans/directives/2026-08-27-json-side-picture-width-check.md`; whichever lands second should read
the other.

## Non-goals

- Deleting `borg switch`. Only its preview pane.
- Removing `--local`. Its correctness argument (a clean read, no unattended network cost) is independent of which
  callers are hot, and `/borg-link`'s own guidance still uses it.
- Removing `--deep` from the parser. See the correction above.
- Touching `borg next` or the `Ctrl+Space >` hotkey, which is the routing path that IS used.

## Alternatives considered

**Keep them, they cost nothing when unused.** Rejected — they are not inert. They are cited as live justification in
comments and tests across `borg.zsh`, `drone.zsh` and both bats suites, so every future change to `borg link`'s cost
model has to reason about three consumers that nobody runs. The `grep -m1 'Status:'` scrape is a standing correctness
hazard for a column no one reads.

**Fix `drone status` onto `--porcelain` as already filed, and keep it.** Rejected as the primary path: it is real work
to harden an output surface with zero measured use. If the table is wanted later, rebuild it on `--porcelain` from the
start.

**Keep the preview, drop the other two.** Partial yes if the picker's preview turns out to be used via a path history
cannot see — but `borg switch` itself scored 0, and the preview cannot run without it.

## Acceptance criteria

- [ ] `cmd_watch`, `drone`'s `cmd_status`, and the two `--preview*` lines are gone; `whence -w cmd_watch` fails.
- [ ] `borg switch` still lists projects and still switches tmux windows.
- [ ] `PICTURE_BUDGET` still has an executable upper bound that is not the deleted pane width.
- [ ] `2026-08-27-drone-status-off-the-human-document.md` is in `docs/plans/severed/` with a line saying deletion
      closed it.
- [ ] `--deep` is still in the parser and B16 is still green.
- [ ] Both suites green; `borg help` and `CLAUDE.md` no longer advertise the three surfaces.
