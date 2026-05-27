# Directive: Per-Project State Migration

Shipped: 2026-05-27

*Filed: 2026-05-11*
*Blocked on: `2026-05-11-orchestrator-mode-separation.md` (Directive A).*
*Status: STUB — not yet ready to plan in detail. Promote to full directive
once Directive A ships.*

## Objective

Move ephemeral session-state fields out of `~/.config/borg/registry.json` and
into per-project `<project>/.borg/state.json` files. Registry shrinks to a
pure discovery index (name, path, source, tmux pointers, summary, pinned,
archived). State files own the volatile data and are written by the
per-project hooks installed in Directive A.

## Why This Is Separate

The Collective Review (2026-05-11) flagged that bundling this with Directive A
mixes a bug fix (orchestrator-mode separation) with a multi-file refactor that
touches every registry consumer in `borg.zsh:2538`. Splitting lets Directive A
ship in one session and lets this work be planned with its own acceptance
criteria, migration path, and version-bump release notes.

## Scope (Sketch)

Fields to move from `registry.json` → `<project>/.borg/state.json`:
- `status` (`active` / `idle` / `waiting`)
- `last_activity` (ISO8601 timestamp)
- `claude_session_id`
- `has_uncommitted_changes` (boolean)
- `waiting_reason` (notification message)
- `notify_origin` (`host` / `container`)

Fields that stay in `registry.json`:
- `path`
- `source` (`cli` / `scan` / `drone`)
- `tmux_session`, `tmux_window`
- `summary`
- New: `archived` (boolean)
- New: `pinned` (boolean)

Consumers in `borg.zsh` that read `status` / `last_activity` / etc. must
swap to fan-reading `<project>/.borg/state.json`. Same for the `/borg-link`
skill.

## Cutover Plan (Per Collective Review — Option C)

The Migration Engineer recommended Option C: just flip it. The data being
moved is ephemeral session state — losing one session's worth across a
single upgrade is annoying for the first post-upgrade session and meaningless
after that.

- `BORG_VERSION` bumps with a breaking-on-disk note in release notes.
- `borg setup` on upgrade: drops the moved fields from `registry.json`,
  writes empty `<project>/.borg/state.json` files for every registered
  project (just the schema scaffold, no historical data).
- First post-upgrade session for each project re-populates state.json via
  the normal hook writes.
- Document the one-session degradation in the upgrade output.

## Hard Criteria (To Sharpen When Planning Begins)

- [ ] `<project>/.borg/state.json` is added to per-project `.gitignore`
      automatically by `borg setup` (with a one-time scan-and-amend for
      projects where `.borg/` is already tracked). **Non-negotiable** — the
      file's `last_activity` mutates every session and would churn the git
      index constantly.
- [ ] Atomic write: same tmp-then-mv pattern `_borg_registry_write` uses, to
      survive concurrent sessions in the same project.
- [ ] Hook safety: failure to write state.json must not break the session
      (same lenient pattern current registry writes use).
- [ ] Backwards-compat read in `borg.zsh`: if `state.json` is missing,
      treat as `status=idle, last_activity=null` — don't crash.
- [ ] Release notes call out the version-bumped breaking change.
- [ ] All bats coverage for `borg ls`, `borg next`, `borg switch` continues
      to pass against the new data layout.

## Timeline (Estimate)

2-3 sessions, ~4-6 hours total. Largest chunk is the consumer rewrite in
`borg.zsh` (status/last_activity used in `cmd_ls`, `cmd_next`, `cmd_status`,
`cmd_hail`, and several internal helpers).

## Next Step

Wait for Directive A to ship. Then re-read this stub and promote to a full
directive with concrete file edits and verification commands.
