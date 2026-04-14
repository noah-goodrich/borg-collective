# Project Plan: Borg Collective v0.7.1 — Versioned Settings Base
*Established: 2026-04-14*

## Objective

Make `borg setup` the single source of truth for `permissions.allow` in both Claude Code and
Cortex settings, by union-merging a versioned base from dotfiles into the live settings files —
additive only, never clobbering machine-local additions.

## Acceptance Criteria

- [ ] **Dotfiles base updated** — `dotfiles/claude/code/settings.json` contains the full canonical
  `permissions.allow` list (including `cortex`, `zsh -c`, `bats`, `shellcheck`, `shasum`,
  `run-in`); machine-specific fields (`model`, `enabledPlugins`) removed from it;
  `__DOTFILES_DIR__` placeholder substituted with actual path during `borg setup`.
  - Verify: `jq '.permissions.allow | length' ~/.config/dotfiles/claude/code/settings.json` ≥ 95;
    `jq 'has("enabledPlugins")' ~/.config/dotfiles/claude/code/settings.json` → `false`.

- [ ] **`borg setup` union-merges permissions** — reads base, adds any missing entries to
  `~/.claude/settings.json` in a single jq call; never removes existing entries; idempotent.
  - Verify: add a fake entry `"Bash(fake-test:*)"` to live settings, run `borg setup`, confirm it
    persists; confirm all base entries present: `jq '.permissions.allow | length' ~/.claude/settings.json` ≥ 95.

- [ ] **Cortex base created and applied** — `dotfiles/cortex/settings.base.json` created with the
  same `permissions.allow` list; `borg setup` union-merges it into
  `~/.snowflake/cortex/settings.json`.
  - Verify: `jq '.permissions.allow | length' ~/.snowflake/cortex/settings.json` ≥ 95 after
    `borg setup`.

- [ ] **Machine-local overlay template** — `borg setup` generates
  `~/.config/borg/claude-settings.local.json` if missing, pre-populated with `model` and
  `enabledPlugins` from the current live settings (so existing config isn't lost). Same for
  Cortex: `~/.config/borg/cortex-settings.local.json` with `cortexAgentConnectionName`, `theme`.
  - Verify: delete both local files, run `borg setup`, confirm both regenerated with correct fields.

- [ ] **Regression** — existing hooks still registered; bats tests green; shellcheck clean.
  - Verify: `jq '.hooks.SessionStart' ~/.claude/settings.json` shows `borg-start.sh`;
    `bats tests/*.bats` passes; `shellcheck hooks/*.sh lib/borg-hooks.sh` clean.

## Scope Boundaries

- NOT managing `model`, `enabledPlugins`, `extraKnownMarketplaces` content via borg — these stay
  in the machine-local overlay file, not the versioned base.
- NOT syncing settings across machines automatically — pull dotfiles, run `borg setup`.
- NOT full JSON deep-merge of hooks — hook registration stays with `_borg_register_hook` as-is.
- If done early: ship. Do not expand scope.

## Ship Definition

1. All criteria above verified green.
2. `bats tests/*.bats` and `shellcheck` pass.
3. `/simplify` run on changed files.
4. Dotfiles repo: `dotfiles/claude/code/settings.json` updated, `dotfiles/cortex/settings.base.json`
   created — committed and pushed to `git@github.com:noah-goodrich/dotfiles.git`.
5. Borg-collective: committed to main, pushed, VERSION bumped to `0.7.1`, Homebrew formula updated.
6. `borg setup` run on this machine to verify the merge works end-to-end.
7. PROJECT_PLAN.md archived to `docs/plans/assimilated/2026-04-14-v0.7.1-versioned-settings.md`.

## Timeline

1 session × ~2 hours. Three files change: `borg.zsh` (cmd_setup), `dotfiles/claude/code/settings.json`
(strip machine fields), `dotfiles/cortex/settings.base.json` (new). Plus two machine-local template
generators.

## Risks

- `borg setup` writing to `~/.claude/settings.json` — must be additive only. A bug that truncates
  or overwrites the file kills hooks for the session. Test with the fake-entry idempotency check
  before calling it done.
- `__DOTFILES_DIR__` substitution — the placeholder is already in the dotfiles settings.json. Need
  to ensure the substitution happens before the merge, not after (otherwise jq sees a raw string
  with `__DOTFILES_DIR__` and the marketplace path breaks).
- Cortex settings structure may differ from Claude's — verify `jq` path `.permissions.allow` works
  in Cortex settings.json before assuming parity.
