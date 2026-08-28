# Directive: A bad row must not cost the whole manifest
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Filed: 2026-08-27*

**tl;dr** — One invalid field anywhere in a manifest makes `shell._load_manifest` drop the entire file, so a typo in
row 3 silently deletes rows 1 through 14 from the grid. Degrade the ROW instead: keep what validates, report what did
not, and never let a single bad field erase work that parses fine.

## Why this exists

Found while building AC4. `manifest_core.GATE_KINDS` is `{"decision", "verification"}`, so a row declaring
`"kind": "review"` fails validation — and the failure is not scoped to that row. Measured on the AC2 fixtures by
adding exactly one such gate to `auth-hardening.json`:

```
before:  declared 12 refs   (auth-hardening 7 + warehouse-rollout 5)
after:   declared  5 refs   + warning: invalid manifest -- rows[2]: gate.kind must be one of
                              ['decision', 'verification'], got review; rows[2]: gate.resolved_by is required
```

**Seven rows disappeared from `▸ CHAINS` because of one word in one field.** The document is not silent — the
warning renders — but the failure mode is exactly backwards from what a front door should do: the page keeps its
confident frame and quietly stops containing most of the project.

This is the same class as the defects AC2 and AC4 kept turning up, arriving from the validator side: the check is
correct about the row and wrong about the blast radius, and nothing about the rendered page tells a reader that the
manifest they are looking at is a seventh of itself.

**It also makes a shipped feature unreachable.** AC4 routes an unrecognized `gate.kind` to a third group, `unsure`,
rather than guessing yours-or-mine — a deliberate decision recorded in
`2026-08-27-ac4-next-and-yours-vs-mine.md` §1/D2. No valid manifest can produce that row, because the validator
rejects the file first. The branch ships dead-but-tested. Fixing the blast radius is what makes it live.

## Solution

Validation stays exactly as strict about what a row must contain. What changes is what happens next:

- **A row that fails validation is DROPPED, not the file.** The surviving rows load, rank, render and route normally.
- **The warning names the row and what it cost**, in the shape the grid already uses for degraded sources —
  `manifest auth-hardening: 1 of 8 rows dropped (rows[2]: gate.kind ...)`. A reader must be able to tell "this project
  has 7 rows" from "this project has 8 rows and I am showing you 7".
- **A manifest whose rows ALL fail is still dropped whole**, with the existing message. There is no page to render and
  nothing is gained by pretending otherwise.
- **Structural failures stay fatal to the file**: unparseable JSON, a missing/duplicate `program` id, `rows` not being
  a list. Those are not row-level facts and there is no partial answer to give.

**`manifest_core.gates()` already reads through the tolerant `_rows()` while `validate` reads the raw list** — that
asymmetry is documented in `gates()`' own docstring as deliberate ("reporting must never crash on data validation has
already condemned"). This directive extends the same principle one layer out, to loading.

## Non-goals

- Widening `GATE_KINDS`. A `review` kind is still not a thing the router understands; it routes to `unsure`, which is
  the point. If the vocabulary should grow, that is a separate decision with its own reasons.
- Silently accepting bad rows. Dropping a row without a named warning would trade a loud wrong answer for a quiet one.
- Touching `validate`'s rules, messages, or strictness. Only the caller's response to them changes.

## Alternatives considered

**Leave it; the warning is rendered.** Rejected. The warning says the manifest is invalid, not that the page is now
missing 7 of 12 refs, and `▸ CHAINS` renders its "no manifest declares work here" placeholder as though the repository
simply had none. A reader cannot distinguish "nothing declared" from "everything hidden by one typo".

**Fail the whole `borg link` invocation on an invalid manifest.** Rejected outright — this runs on every hot path in
the tree, and a hand-edited JSON file must never be able to take out the front door.

**Validate on write instead (in `/borg-plan` and friends).** Worth doing and does not replace this: the file can be
hand-edited afterwards, and AC5 has not shipped, so nothing writes manifests but hands today.

## Acceptance criteria

- [ ] A manifest with one invalid row renders every other row; `declared` counts the survivors.
- [ ] The warning names the manifest, the dropped-row count, and the validator's own message.
- [ ] A manifest whose every row fails is still dropped whole, with the existing message.
- [ ] Structural failures (bad JSON, missing id, non-list `rows`) still drop the file.
- [x] ~~A pytest case asserts the AC4 `unsure` group renders from a real manifest — the branch stops being dead.~~

  > **AMENDED 2026-08-27, by building it. THIS CRITERION CANNOT BE SATISFIED BY THIS CHANGE, and the
  > claim above ("fixing the blast radius is what makes it live") is wrong.** Row-level degradation
  > drops the offending row — which is precisely the row that would have routed to `unsure`. The two
  > outcomes are mutually exclusive: either the bad row is dropped (and `unsure` is unreachable) or it
  > is kept (and the file was not degraded). Making `unsure` live requires a DIFFERENT change —
  > widening `GATE_KINDS`, or demoting an unrecognized `kind` from a validation error to a router
  > concern — and this directive names the first of those as an explicit non-goal.
  >
  > **What shipped instead is the invariant `unsure` actually protects**, which is better than what
  > was asked for: `test_the_router_covers_every_gate_kind_the_validator_admits` asserts
  > `GATE_KINDS ⊆ _GATE_ROUTING`. The group is a DIVERGENCE GUARD — the validator and the router
  > admit the same two kinds today, so they coincide; the day someone adds a third to the validator
  > and forgets the router, a `.get(kind, default)` would silently pick a side. The subset assertion
  > catches that, and `unsure` catches the window before it is noticed. Asserted as a subset rather
  > than equality because the router knowing a kind the validator has not admitted is the safe
  > direction.
  >
  > Whether `unsure` should be reachable at all is a live question for the owner, not one this
  > directive settles.
  >
  > **CLOSED 2026-08-28. The owner took the second option this amendment named** — demote an
  > UNRECOGNIZED, NON-EMPTY `gate.kind` from a row-scoped validation error to a router concern, so the
  > row survives loading and routes to `unsure`. `GATE_KINDS` was NOT widened (this directive's
  > non-goal holds); it is now the declared vocabulary the router must never fall behind, and nothing
  > else. An EMPTY or MISSING `kind` stays a validation error and still costs its row: `_route("")`
  > means "no gate" and returns `mine`, so a row that HAS a gate would be routed by the rule for rows
  > that do not — and if the author meant a decision, `mine` is the plan's own named risk arriving
  > with nothing mis-set. (This clause used to justify itself by quoting `mine`'s heading, *"nothing
  > is blocking these"*. That heading was itself false about `verification` gates and was corrected on
  > 2026-08-28; the reason above never rested on it.) `gate.blocked_by` and `gate.resolved_by`
  > stay required and stay fatal. `tests/fixtures/link/manifests/warehouse-rollout.json` gained
  > `acme/warehouse#78` (`kind: "review"`) so the group is pinned end to end by
  > `link-grid-orchestrator.golden` and by
  > `test_an_unrecognized_kind_reaches_unsure_through_the_real_loader`, not just by a unit test that
  > hands `_route` a string. The subset guard survives under its corrected name,
  > `test_the_router_covers_every_declared_gate_kind`.
- [ ] Both grid goldens are unchanged by this directive alone, since no fixture carries an invalid row.
