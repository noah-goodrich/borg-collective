# Directive: Finish the cairn-pollution plugin-guard deploy

*Filed: 2026-07-13 · Status: ASSIMILATED (shipped 2026-07-14) · Gated by: pre-existing red claude-plugins CI*
*Found by: a cairn session that shipped the cairn-side fixes and rebuilt the plugin, but hit unrelated
red CI on the plugin PR and handed the remainder here.*

## Assimilation note (2026-07-14)

Shipped. All "Done when" criteria met: claude-plugins CI green, PR #33 merged, plugin 0.8.7 → 0.8.8
installed, cairn `call_log` shows **0** synthetic `project='/'` rows in the last 24h (and none in
`/stats/usage`).

**Root cause was NOT what step 1 predicted.** The `additionalContext` JSON was already assembled
correctly via `jq -n --arg`. The real bug: the cairn-hits.log metric append was
`printf ... >> "$BORG_DIR/cairn-hits.log" 2>/dev/null` — and bash opens a redirect target *before*
applying the same-command `2>/dev/null`, so a missing `$BORG_DIR` leaked
`<hook>: line N: <path>: No such file or directory` to **stderr**. `bats run` merges stderr into
`$output`, splicing that line ahead of the JSON; `jq` then failed at "column 88" (the 87-char CI hook
path + `: line`). `$BORG_DIR` was absent under CI because the bats setup overrides `HOME` but not
`XDG_CONFIG_HOME`, and the hook recomputes `BORG_DIR` from `${XDG_CONFIG_HOME:-$HOME/.config}`.
Fix: brace-group the redirect so `2>/dev/null` covers the open (borg-collective #77 → claude-plugins
#33). Regression test added in `tests/lifecycle.bats`.

Full context + step-by-step in the handoff checkpoint: `.borg/checkpoints/2026-07-13-2141.md`.

## Why

The `usage-watch` launchd poller (cwd `/`) fires SessionStart hooks that write synthetic `query='/'`
rows into cairn's `call_log` — 80% of the ledger was this pollution. #75 landed the full guard
(`BORG_NO_SESSION_HOOKS` mute + `CWD` empty/`"/"` guard) into `hooks/borg-link-down.sh` on `main`, and
VERSION is bumped to 0.8.8 (#76). The plugin rebuild is open as **claude-plugins PR #33**
(`chore/rebuild-plugin-0.8.8`), but it inherits **pre-existing red CI** — the guard can't go live until
that's fixed and the plugin is reinstalled.

## What to do

1. **Fix the project-mode JSON bug** in `hooks/borg-link-down.sh` — `additionalContext` output is
   malformed JSON when plan/uncommitted fixtures are present (`jq parse error … column 88`). Fails
   claude-plugins `borg-link-down.bats` tests 12/14/15 (red on `main` since #30/#31). Assemble the
   context via `jq --arg`/`-Rs`, not printf interpolation. Add a regression test.
2. **Rebuild** (`scripts/build-plugin.sh`) and update **claude-plugins PR #33**.
3. **Green CI → merge #33.** Do NOT merge over red — fix the root cause.
4. **Deploy:** `claude plugin update borg-collective` (→ 0.8.8) + `borg setup` (poller-side mute).
5. **Verify** no new `query='/'` rows arrive in cairn's `call_log` after a poller cycle
   (`curl -fsS http://localhost:8767/stats/usage`).

## Done when

claude-plugins CI is green, PR #33 merged, the 0.8.8 plugin is installed, and cairn's `call_log` shows
no new synthetic `/` rows.
