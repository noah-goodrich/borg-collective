# Directive: A `--json`-side width check so a manifest cannot silently blow `PICTURE_BUDGET`
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: 2026-08-26-ac2-topological-grid-renderer*
*Filed: 2026-08-27*

**tl;dr** — `PICTURE_BUDGET = 68` is a compile-time constant asserted against two fixture manifests and measured
against one golden. A manifest whose short refs run long in three columns exceeds it, and nothing notices until a human
sees a wrapped picture in a 70-column fzf pane. Add a check on the `--json` side, where impurity is allowed.

## Why this exists

Filed verbatim from AC2's own §8 residual-risk section, which states the boundary honestly:

> `PICTURE_BUDGET = 68` is asserted against two fixture manifests and measured against one golden. A future manifest
> whose short refs run long in three columns exceeds it, and nothing in this commit notices until someone authors one
> [...] the picture's width is a compile-time constant because `render.py` is unconditionally pure, and the guard is a
> measurement over the shapes that exist today, not a proof over the shapes that could.

The measured headroom is real but thin, and it is headroom over *today's* manifests, not a bound:

| manifest | widest picture row |
|---|---|
| fixture (`auth-hardening` + `warehouse-rollout`) | 65 columns |
| live `ingle-t1-cutover` | 46 |
| live `viz-program` | 30 |
| **budget** | **68** |
| fzf preview pane (`borg.zsh:267`, `right:70:wrap`) | 70 |

Case B15 measures the widest golden row and compares it to the number parsed out of `borg.zsh:267`. P22 raises a
fixture ref past the budget and asserts it fails. Both are guards over authored fixtures. Neither sees a manifest a
user writes tomorrow.

The failure mode is not a crash. It is a picture that wraps in the fzf preview — the per-keypress hot path — turning a
topology into visual noise at exactly the moment it is meant to be scanned.

## Solution

Emit the computed width on the `--json` side and check it there.

- `render.py` and `picture.py` stay **unconditionally pure**. That is load-bearing: it is what lets
  `picture-fork.expected` and `picture-crossing.expected` be hand-authored oracles that do not come from the
  implementation they check. The check does not go in either module.
- `cli.py` (already the impure boundary — it owns `BrokenPipeError` for the same reason) computes the widest row and
  surfaces it. Two candidate shapes, to be decided when built:
  1. a `grid.picture_width` integer on the document, which `--json` consumers and a bats case can both assert against
     `PICTURE_BUDGET`; or
  2. a `▸ SIGNALS` warning when the measured width exceeds the budget, so the human sees *why* the page looks wrong
     instead of just seeing it wrong.

Shape (1) is testable without a human; shape (2) is honest at the moment of failure. They are not exclusive.

## Non-goals

- Making the budget dynamic from `$COLUMNS`. The picture is byte-compared in goldens; a terminal-dependent width makes
  every golden non-reproducible, which is the failure `--local` and the fixture harness exist to prevent.
- Truncating or eliding a too-wide picture. Deciding what to drop is a design question, not a guard.
- Raising `PICTURE_BUDGET`. 68 against a 70-column pane is the arithmetic; the pane is the constraint.

## Alternatives considered

**Assert the budget inside `picture.py`.** Rejected — it would either raise on a real user manifest (taking out the fzf
preview and `drone status`, the two paths that swallow failure silently) or need a logging side effect, and either one
ends the purity that makes the hand-authored oracles meaningful.

**Add more fixture manifests.** Rejected as the primary fix: it widens the sample, it does not bound the shape. Worth
doing anyway as a cheap complement.

## Acceptance criteria

- [ ] The widest picture row is computed on the `--json`/`cli.py` side and is observable without reading ANSI output.
- [ ] A pytest case builds a manifest that exceeds `PICTURE_BUDGET` and asserts the check fires; the mutation that
      turns it red is deleting the check.
- [ ] `picture.py` and `render.py` import nothing new — verified by the clean-architecture linter, not by eye.
- [ ] `PICTURE_BUDGET` is still `68` and `borg.zsh:267` is still `right:70:wrap`.
