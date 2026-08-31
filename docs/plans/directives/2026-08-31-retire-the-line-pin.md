# Directive: Retire `file:NNN` from prose, repo-wide, and fail on new ones
*Parent plan: (none — a cross-cutting convention, not a feature)*
*Filed: 2026-08-31*

**tl;dr** — A `file:NNN` pin in a comment or a document is a fact that nothing re-derives and nothing fails on. Line
pins produced a defect in **every** review round on 2026-08-27/28, and each fix introduced a fresh wrong number. The
repo has already ratified anchoring locally, in `tests/cli_contract.bats`. Generalize it, and add the only CI check
that can actually help — one that refuses NEW pins, since no check can tell a stale pin from a live one.

## Why this exists

**The pins rot, and so do the corrections.** `borg.zsh:3111` was cited at four sites as the `--deep` caller; it
matched neither `main` nor the branch that "corrected" it to `:3064`; a later pass wrote `:3182`. None of the three
was right when it was written. On the current tree those lines hold, respectively, a `BORG_ORCHESTRATOR_ROOT`
assignment, a help-text `echo` about channel subscriptions, and a comment about an argparse arm. The thing they were
all pointing at is one `grep` away: `_link_py_args=(--deep)`.

**Two dead pins are cited 17 times in live source right now.** Re-derive with
`grep -rEon 'borg\.zsh:266|drone\.zsh:964' --include='*.py' --include='*.zsh' --include='*.bats' .`:

- **`borg.zsh:266`** — 6 citations (`cli.py` ×2, `core.py` ×2, `test_cli.py`, `cli_contract.bats`), all describing
  the fzf preview's per-keypress `borg link` call. That line is now blank.
- **`drone.zsh:964`** — 11 citations (`cli.py` ×3, `render.py` ×3, `core.py` ×2, `test_cli.py`, `test_render.py`,
  `cli_contract.bats`), all describing `cmd_status`'s per-tmux-window loop. That line is now a `sed` substitution
  inside a scaffold template.

`drone.zsh:964` was cited as "`cmd_status`'s per-tmux-window loop". `drone.zsh` has no `cmd_status` at all any more,
and the file is 1359 lines. Every one of those citations is a sentence a reader is invited to verify and cannot.

**The scale, measured.** Excluding `docs/plans/` and `.borg/`, live source and test files carry **157 lines bearing
110 distinct `file:NNN` pins** (the `-o` form below prints 170 matches, since a line may carry more than one):

```zsh
grep -rEo '[a-zA-Z_/.-]+\.(zsh|py|bats|sh):[0-9]+' \
    --include='*.py' --include='*.zsh' --include='*.bats' --include='*.sh' \
    --exclude-dir=.git --exclude-dir=__pycache__ .
```

**The same failure has a second form: counts embedded in prose.** `tests/briefing.bats` was recorded as "15 cases" in
two places and invalidated by the very commit that added the sixteenth; `PROJECT_PLAN.md` carried the same number.
Pytest pass counts ("919 passed") were written into commit messages and directives and were stale within a day. A
count and a line number are the same defect: a derived value transcribed into prose, where nothing re-derives it and
nothing goes red when it drifts.

**It has already been ratified locally.** `tests/cli_contract.bats` says so in its own comments: *"every numeric
pointer at this file in the tree has since been re-anchored by @test name"*, and its Phase 3 block replaces a
`grep -c` verification with three definition-anchored and runtime-anchored checks, for reasons it spells out. That is
the convention. It is currently one file's habit.

## Solution

**1. State the rule where conventions live.** In `CLAUDE.md`'s Style Rules: no `file:NNN` in prose — comments,
docstrings, directives, commit messages, PR bodies. Anchor instead by, in order of preference:

- **the verify command** — `grep -c -- '--preview-window' borg.zsh` is 0 — which is checkable and self-updating;
- **a symbol or a quoted line** — `_link_py_args=(--deep)`, `_borg_session_mode` — which `grep` relocates for free;
- **a test-case name** — `contract: the widest picture row fits PICTURE_BUDGET ...` — which the suite itself keeps
  honest, because renaming a case without updating the reference turns something red.

Same rule for derived counts: state what the cases cover, not how many there are, and give the command
(`grep -c '^@test' tests/briefing.bats`) if the number is genuinely wanted.

**2. Convert the 17 dead citations.** `borg.zsh:266` → the `cmd_switch` `fzf` invocation by name, or delete the
clause since the preview is gone. `drone.zsh:964` → delete; the command it names does not exist.

**3. Add the check that can actually work — a ban on NEW pins, not a validity test.** This is the part to get right,
because the obvious check does not work and measuring it is what makes that clear. A pin-resolves check (does the
file exist, does it have at least N lines?) run over the current tree catches **one** real staleness —
`drone.zsh:1405`, past EOF — and three false positives from illustrative `lib/foo.sh:10`-style examples in
documentation. It cannot detect `borg.zsh:266` pointing at a blank line or `drone.zsh:964` pointing at a `sed`
template, which are the actual failures. **A pin cannot be validated, only forbidden.** So the check is a grep for
the FORM, scoped to lines a change ADDS:

```zsh
git diff --unified=0 origin/main...HEAD -- '*.py' '*.zsh' '*.bats' '*.sh' '*.md' \
  | grep -E '^\+' | grep -Eq '[a-zA-Z_/.-]+\.(zsh|py|bats|sh):[0-9]+'
```

Diff-scoped rather than tree-wide because a tree-wide gate would be red on day one against 110 pins, and a gate that
is red on arrival gets suppressed rather than obeyed. An escape hatch (`# line-pin-ok:` with a reason) keeps the
genuinely-immovable case from forcing a bad workaround, and every use of it is greppable.

**This very file is the first case that needs the hatch**, and saying so is part of the design rather than an
awkwardness: the pins quoted above are the EVIDENCE — a directive about rotten pins has to name them — while the ban
is on pins used as POINTERS. If the check cannot express that difference, the hatch is how it is expressed, and a
reviewer reads the reason.

## Non-goals

- **Rewriting the 110 existing pins in one pass.** Most sit in assimilated plans and checkpoints, which are historical
  records; a pin in a shipped 2026-05 plan describes a tree that no longer exists and rewriting it would be
  falsifying the record. Convert LIVE source, comments and OPEN directives. Leave history alone.
- **Touching `.borg/checkpoints/`.** Session memory, by definition written at a moment in time.
- **Banning `file:NNN` in ephemeral output** — a `grep -n` result in a terminal, a review comment on a specific diff
  line. The defect is a pin that gets COMMITTED, where it outlives the tree it described.
- **Building a tool that rewrites pins into anchors automatically.** The right anchor is a judgement about what the
  sentence is claiming, and a mechanical rewrite would produce anchors as wrong as the pins.

## Alternatives considered

**A CI check that resolves every pin (file exists, has ≥ N lines).** Measured against the current tree and rejected
on the measurement: 1 true positive, 3 false positives, and blind to both of the pins that are cited 17 times.
It would deliver near-zero signal while creating the impression that pins are checked — which is strictly worse than
no check, and is the exact failure mode this repo files under "a check pointed at the wrong thing does not fail, it
reads as a pass".

**Keep pins but require an anchor alongside** (`` `_link_py_args=(--deep)` (borg.zsh:3272) ``). Tempting, and
rejected: the anchor is then load-bearing and the number is decoration that rots anyway, so a reader gets a
contradiction and has to work out which half to believe. Two facts where one will do, one of which is guaranteed to
go wrong.

**Rely on review to catch stale pins.** This is the status quo. It produced a defect in every review round on
2026-08-27/28, and — the detail that settles it — the *fixes* produced fresh wrong numbers, twice. Review is the
mechanism that has already been measured failing at this.

**Do nothing; pins are only comments.** Rejected. They are cited as evidence in commit messages, in directives, and
in test comments that justify why an assertion exists. `drone.zsh:964`-as-`cmd_status`'s-loop justified a paragraph
about `--local`'s urgency in three modules for a command that had been deleted.

## Acceptance criteria

- [ ] `CLAUDE.md`'s Style Rules names the ban and the three anchor forms, in preference order, with the same
      treatment for counts embedded in prose.
- [ ] `grep -rEon 'borg\.zsh:266|drone\.zsh:964' --include='*.py' --include='*.zsh' --include='*.bats' .` returns
      nothing: every one of the 17 citations is either re-anchored by symbol/test name or deleted along with the
      claim it supported.
- [ ] A CI step fails a change that ADDS a `file:NNN` to a tracked `.py`/`.zsh`/`.bats`/`.sh`/`.md` file, with a
      documented `# line-pin-ok:` escape that requires a reason. **Verified by mutation**: a branch adding one pin
      goes red, and the same branch with the pin re-anchored goes green.
- [ ] The check is diff-scoped and is confirmed green on `main` as-is — a gate that is red on arrival is a gate that
      gets disabled.
- [ ] `docs/plans/assimilated/` and `.borg/checkpoints/` are untouched by the conversion pass, confirmed by
      `git diff --stat`. The historical record is not edited to match the present tree.
- [ ] `make test`, `make lint` and `bats tests/` all exit 0.
