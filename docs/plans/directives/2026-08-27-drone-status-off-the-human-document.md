# Directive: Move `drone status` off the human `borg link` document onto `--porcelain`
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: 2026-08-26-ac2-topological-grid-renderer*
*Filed: 2026-08-27*

**tl;dr** — `drone.zsh:964` builds its status column by grepping `Status:` out of the *human* `borg link` document,
once per tmux window. It is correct today only because AC2 put `▸ IN FOCUS` above every wire-sourced line — an ordering
invariant, not a contract. Move the read to `borg link --porcelain`, which is a machine surface with a stable TSV.

## Why this exists

```zsh
raw=$(borg link --local "$wname" 2>/dev/null) || true
borg_status=$(echo "$raw" | grep -m1 'Status:' | sed 's/.*Status:[[:space:]]*//' | tr -d '\n') || true
```

That is a human-facing, ANSI-coloured, seven-section page being screen-scraped for one field. The AC2 spec's Q6
established that the extraction survives the redesign, and it does — `_focus_section` reuses the same
`_label("Status:", status)` call character for character, and IN FOCUS renders as section 2 of 7, above `▸ REPOSITORIES`
and above `▸ CHAINS`.

**But the reason it survives is positional.** Post-AC2 the page carries two classes of text the renderer does not
control: board summaries (free text out of checkpoint debriefs) and PR titles off the wire. A PR titled
`fix: Status: line in drone`, or any summary containing `Status:`, poisons `grep -m1` and renders a stranger's PR title
as a session status — a wrong answer under a confident header. The AC2 fixtures already ship the adversarial case:
`tests/fixtures/link/sweep-acme.json` carries the deliberately poisoned title
`"chore(auth): Status: normalise the rollout report"`.

So the guarantee is: *the poisoned text exists, and is currently rendered below the line we grep.* Any future change to
section order, any new section above IN FOCUS, any decision to surface a headline PR in the header — and the column
starts lying, silently, in a loop that runs once per window and swallows every failure with `2>/dev/null || true`.

## Solution

Read `borg link --porcelain` and pick the field by position, not by text search.

- `render.porcelain` was untouched by AC2 (`link-porcelain.golden` did not move) and is the surface that exists for
  exactly this consumer.
- Field extraction becomes `awk -F'\t'`, so no text a PR author or a checkpoint can write is ever a delimiter.
- Watch the one trap the AC2 spec already recorded: `link --porcelain <project>` must NOT forward the positional
  (`borg.zsh:3098-3100`) — porcelain narrows nothing and forwarding it would build a focus block and die. The consumer
  therefore filters the full listing itself.

## Non-goals

- Changing `render.porcelain`'s output shape. If the needed field is absent, that is a separate directive.
- Touching `borg.zsh:266`'s fzf preview or `borg.zsh:2225`'s watch redraw. Both render the human document *for a human*,
  which is correct.
- Deleting the `Status:` line or reordering the spine. IN FOCUS stays section 2 on its own merits.

## Alternatives considered

**Scrub `Status:` out of wire-sourced text before rendering.** Rejected in the AC2 spec itself: a blanket source-text
grep cannot distinguish the label from a PR title that contains it, and every scrubbing rule is a new way to mangle a
legitimate title.

**Leave it; the ordering invariant holds.** Rejected. It is undocumented at the call site, unasserted as an ordering
property, and the failure is silent in a per-window loop. `tests/link_sweep.bats` asserts the loop spawns zero
subprocesses; nothing asserts the field it extracts is the field it meant.

## Acceptance criteria

- [ ] `drone.zsh:964` reads `borg link --porcelain` and extracts by field position, not `grep`.
- [ ] A bats case renders a project whose summary and whose swept PR title both contain the literal `Status:`, and
      asserts the status column shows the session status — the case must be red against the current `grep -m1`.
- [ ] `tests/link_sweep.bats`'s `drone status triggers zero adapter and zero gh subprocesses` stays green.
- [ ] `link-porcelain.golden` does not move.
