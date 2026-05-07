# Directive: Complete the SessionStart hook PATH

*Filed: 2026-05-07 — Tier P2 — Estimated: <1 hour*

## Why this exists

`hooks/borg-link-down.sh:20` prepends a hardcoded PATH list to the env passed to the
SessionStart hook. The list currently includes `~/.config/dotfiles/zsh/bin` but omits
`/opt/homebrew/bin` and `~/.local/bin`. Tools installed via Homebrew or `pipx` are
invisible to subagent processes spawned by the hook chain — this is why the
"CAIRN UNAVAILABLE" message appears even though cairn would be installable via
`pipx` (see the cairn restoration directive at
`cairn/docs/plans/directives/2026-05-07-cairn-restoration.md`).

This is a one-line fix that benefits every Homebrew- and pipx-installed CLI, not
just cairn. `borg-link-up.sh:17` builds PATH the same way and needs the same fix.

## What changes

`hooks/borg-link-down.sh:20` — extend the PATH prefix to include, in addition to the
existing entries:

- `/opt/homebrew/bin`
- `/opt/homebrew/sbin`
- `$HOME/.local/bin`

Mirror the change in any sibling hook that constructs PATH. Audit confirmed
`hooks/borg-link-up.sh:17` builds PATH identically and needs the same edit;
`hooks/borg-notify.sh`, `hooks/bash-guard.sh`, `hooks/notify.sh`,
`hooks/pre-commit-remind.sh`, and `hooks/tool-count-nudge.sh` should be re-checked
during implementation in case they grow PATH construction later.

Order matters: place the brew and pipx entries in the same relative order a healthy
interactive zsh PATH uses (brew before system, `~/.local/bin` near the front), so a
brew-installed `jq` is preferred over a hypothetical `/usr/bin/jq` rather than the
other way around.

## Acceptance criteria

- [ ] `borg-link-down.sh` PATH prefix includes `/opt/homebrew/bin`,
      `/opt/homebrew/sbin`, and `$HOME/.local/bin` in addition to existing entries
- [ ] `borg-link-up.sh` PATH prefix mirrors the same change
- [ ] Audit of `hooks/*.sh` confirms no other hook builds PATH (or, if any do, they
      receive the same update in this directive)
- [ ] From a fresh orchestrator session, `which jq` resolves to `/opt/homebrew/bin/jq`
      (or wherever brew installed it) and a pipx-installed binary at
      `~/.local/bin/<name>` resolves correctly
- [ ] With cairn installed via `pipx` on the host, a fresh orchestrator session no
      longer prints "⚠ CAIRN UNAVAILABLE" — the cairn restoration directive's
      cross-project dependency clears

## Out of scope

- Refactoring PATH construction into a shared helper. If the duplication grows past
  these two hooks, file a follow-up; for now, two-line mirrored edits are simpler
  than a shared `lib/hook-path.sh`.
- Changing how `drone exec` builds container PATH. Different concern; container
  PATH is set by the devcontainer, not by host hooks.
- Cairn installation itself. That's owned by the sibling directive in the cairn
  repo (`2026-05-07-cairn-restoration.md`); this directive only ensures the binary
  is *visible* once installed.

## Risks

- **Order-of-precedence regressions.** Placing `/opt/homebrew/bin` after `/usr/bin`
  means a system tool would shadow the brew version. Mirror the order from a
  healthy interactive `.zshrc` PATH — brew front, system after.
- **`$HOME` expansion in PATH strings.** Bash expands `$HOME` inside double-quoted
  PATH assignments; `~` does not expand inside quotes. The existing line already
  uses `${HOME}` correctly — keep that form for the new entries.
- **Hook PATH drift over time.** If future hooks introduce new tool dependencies
  (e.g. `gh`, `op`), they may add another path. Keep the hook PATH narrow and
  intentional rather than mirroring the full interactive PATH — this is a
  least-privilege boundary, not a convenience layer.

## References

- Sibling directive (cairn install + cross-project dependency):
  `cairn/docs/plans/directives/2026-05-07-cairn-restoration.md`
- Hook that prints "CAIRN UNAVAILABLE": `hooks/borg-link-down.sh:151-156`
- Hooks that build PATH today: `hooks/borg-link-down.sh:20`, `hooks/borg-link-up.sh:17`
