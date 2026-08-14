# Directive: severed plans are invisible to every status surface

## What was dropped

The `/borg-link` skill's `Cancelled (N)` deep-dive section, and its data-contract row pointing at
`<workspace>/docs/plans/severed/*.md`, are dropped from the Phase 4 rewrite entirely — both the
CLI-consuming primary path and the drone-container fallback. No compromise glob of
`docs/plans/severed/` was added to either path.

## Why

`borg link` (the `borg_core/link/` engine and its `render.py`) has never rendered a severed
section: `grep -rn severed borg_core/ borg.zsh` returns zero hits, and `grep -n Cancelled
borg_core/link/render.py` returns zero hits. The pre-Phase-4 skill was the *only* surface showing
severed plans, and it disagreed with the CLI on every project holding severed plans. A6's headline
claim is one engine, one truth — carrying forward a skill-only section with no CLI ancestor would
recreate the exact CLI/skill divergence this port exists to eliminate.

## Evidence

- `grep -rn severed /Users/noah/dev/borg-collective/borg_core/ /Users/noah/dev/borg-collective/borg.zsh`
  → zero hits.
- `grep -n Cancelled /Users/noah/dev/borg-collective/borg_core/link/render.py` → zero hits.
- Real severed-plan counts, verified by count at the time of this directive: **24 severed plans go
  dark** — 4 in `borg-collective`, 16 in `ingle`, 2 in `reveal`, 2 in `reveal-data-consistency`.
  `borg sever` becomes a filing action with no readback until one of the two ways back below lands.

## Two ways back

1. Add `focus.severed` to the `borg link --json` document, plus a Cancelled section to the
   deep-dive renderer in `borg_core/link/render.py`. This is a `DOCUMENT_VERSION` 2 → 3 bump and
   its own phase — explicitly not part of A6.
2. Accept that `borg sever` is a filing action with no readback, and that severed plans are
   discoverable only by direct filesystem inspection (`ls <workspace>/docs/plans/severed/`), not
   through any status surface.
