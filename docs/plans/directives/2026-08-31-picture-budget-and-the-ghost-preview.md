# Directive: `PICTURE_BUDGET`'s justification has lapsed — decide the number, then bury the ghost
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: 2026-08-27-retire-unused-link-surfaces (assimilated 2026-08-31)*
*Filed: 2026-08-31*

**tl;dr** — `PICTURE_BUDGET = 68` is 70 minus two columns of border for an fzf preview pane that no longer exists.
The pane, `borg watch` and `drone status` were all retired on 2026-08-27; three shipped surfaces still advertise
`drone status` as a live command, and the constant they justified still says 68. **The comment sweep is the easy
half. The real question is whether 68 is still the right number now that the only thing that ever produced it is
gone.**

## Why this exists

`picture.py` states the provenance itself:

> The widest a picture row may be, in VISIBLE columns. 68 rather than 80 came from the fzf preview pane: AC2/S3
> sized it at 70, leaving two columns of slack for the pane's own border.

That pane is gone. `cmd_switch`'s `fzf` call now passes `--query`, `--prompt`, `--header`, `--delimiter` and
`--with-nth` and no preview flag at all; `grep -c -- '--preview-window' borg.zsh` is 0, which `tests/cli_contract.bats`
asserts by name in *"the widest picture row fits PICTURE_BUDGET and no preview-window flag survives"*. So the check
is executable and its subject is imaginary. `picture.py` already concedes the point in the same comment — *"the
number stays 68 on its own merits"* — but "on its own merits" is asserted there, not argued, and nobody has been
asked the question since the constraint disappeared.

**The measured headroom, re-derived from the directive that stamped `grid.picture_width`:**

| manifest | widest picture row |
|---|---|
| `link-grid-orchestrator.golden` | 61 |
| `link-grid-repository.golden` | 61 |
| live `ingle-t1-cutover` | 46 |
| live `viz-program` | 30 |
| **budget** | **68** |

Seven columns of headroom over the widest thing that exists, against a bound derived from a pane. Both halves of that
sentence are now unanchored: the bound has no consumer and the headroom has no rule.

### The citation sweep, enumerated

**Most of the source-side citations were already corrected**, in PR
[#176](https://github.com/noah-goodrich/borg-collective/pull/176) and its neighbours — `cli.py`, `grid.py`,
`shell.py`, `render.py`, `picture.py`, `core.py`, `proc.py`, `recon/shell.py`, `tests/cli_contract.bats` and
`tests/link_sweep.bats` all now name the trio in the past tense with the retirement date. That work is done and this
directive must not re-do it. Re-derive the current state with:

```zsh
grep -rn "fzf preview\|drone status\|borg watch\|cmd_watch\|--preview" \
    --exclude-dir=.git --exclude-dir=__pycache__ --exclude-dir=.borg .
```

**Three shipped surfaces still describe `drone status` as a command a user can run**, which is a different and worse
category than a stale code comment, because a user reads these:

| surface | what it says |
|---|---|
| `README.md` | a `drone status` row in the command table — *"Show all drones (container + session state)"* |
| `docs/cheatsheet.md` | a `drone status` line — *"Show all drones"* |
| `install.sh` | prints `drone status           Show all active drones` in the post-install banner |

`./drone.zsh status` exits 1 with `unknown command 'status'`. `docs/six-pager.md` also names it, in a dated release
note about what v0.7 added — that one is history and stays.

**And two directives still argue from the trio as live**, which matters because directives are read as current
intent: `2026-08-25-link-front-door-hardened-spec.md` (its B1 is *"The fzf preview is `deep`, not `porcelain`"*, and
its B4/B5 audit call sites inside `cmd_watch` and `drone status` loops) and `2026-08-20-comms-delivery-surfaces.md`
(which exempts `borg watch` and `drone status` as delivery surfaces). Both are open directives whose scope must be
re-read against a tree that no longer has those commands.

## Solution

Two steps, in this order, because the second is cheap and the first is the reason to do it.

**1. Answer the number.** Pick one and record the reasoning where `PICTURE_BUDGET` is defined:

- **Keep 68.** Defensible: it is the bound every manifest that exists has been measured against, both goldens and
  both `.expected` oracles are byte-compared at that width, and changing it regenerates fixtures for no observed
  gain. If this is the answer, the comment must say *"kept because moving it costs fixture churn and buys nothing
  measured"* — a maintenance argument, honestly labelled — and stop implying a width constraint no consumer has.
- **Re-derive it from a real consumer.** The surviving readers of the picture are a terminal (`borg link`,
  `drone link`) and a Claude session reading `--json`. A terminal argument gives 80 minus the section indent; the
  `--json` consumer has no width at all. If a number can be derived from something that exists, derive it.
- **Retire the bound and keep only the measurement.** `grid.picture_width` is already stamped and already asserted
  two independent ways. A `▸ SIGNALS` line that reports the width without a pass/fail is honest; a threshold nobody
  can justify is the thing this repo files under "a check pointed at the wrong thing reads as a pass".

**2. Bury the ghost.** Delete the `drone status` rows from `README.md`, `docs/cheatsheet.md` and `install.sh`.
Re-scope or sever the two directives that argue from the trio — B1 in the hardened spec is answering a question about
a flag that no longer exists, and `comms-delivery-surfaces`' exemption list should name the surfaces that survive.

## Non-goals

- **Reinstating any of the three retired surfaces.** The usage measurement that retired them stands.
- **Making the budget dynamic from `$COLUMNS`.** Named and rejected by the width-check directive and the reason is
  unchanged: the picture is byte-compared in goldens, and a terminal-dependent width makes every golden
  non-reproducible.
- **Putting the comparison inside `picture.py`.** That module is unconditionally pure and the two hand-authored
  `.expected` oracles depend on it staying that way. Whatever number wins, it is still compared at `cli.py`.
- **Re-sweeping the source comments that PR [#176](https://github.com/noah-goodrich/borg-collective/pull/176) already
  corrected.** They are correct. Touching them again is churn.

## Alternatives considered

**Just delete the stale prose and leave 68 alone.** This is the tempting scope and it is rejected as the whole
answer, though it IS half of it. A constant whose only recorded justification has been deleted is not a maintenance
problem, it is an unowned decision: the next person to hit the bound has no basis on which to move it, so they will
either bend the picture to fit a number nobody chose or raise it arbitrarily. Deciding costs one paragraph now.

**Raise it to 80 while we are here.** Rejected without the decision above. 80 is as unjustified as 68 until someone
names the consumer it comes from, and raising it silently regenerates two goldens and two hand-authored oracles —
paying the fixture churn for a number chosen the same way the old one was.

**Fold this into the open hardened-spec directive, since B1 is about the same flag.** Rejected: that directive is
large and mostly still live, and burying a "should this constant exist" question inside it is how the question stays
unanswered for another month. It should be re-scoped by this work, not host it.

## Acceptance criteria

- [ ] `PICTURE_BUDGET`'s comment states a justification that is true on the current tree — either a named live
      consumer with its width, or an explicit "kept for fixture stability, no width consumer exists" — and does not
      derive the number from the retired pane.
- [ ] `grep -rn 'drone status' README.md docs/cheatsheet.md install.sh` returns nothing, and `borg doctor` /
      `drone` help output is unchanged (they were already clean).
- [ ] `docs/six-pager.md`'s dated release note is UNTOUCHED. It is history, and rewriting history to match the
      present is how a repo loses the record of what it decided.
- [ ] `2026-08-25-link-front-door-hardened-spec.md`'s B1 and `2026-08-20-comms-delivery-surfaces.md`'s exemption
      list are each either amended in place with the retirement recorded, or severed with the reason — not left
      arguing from three deleted commands.
- [ ] If the number changes: both grid goldens and both `.expected` oracles regenerate in ONE reviewed commit, and
      the `.expected` pair is hand-edited rather than regenerated, per the rule that makes them oracles.
- [ ] `make test`, `make lint` and `bats tests/` all exit 0.
