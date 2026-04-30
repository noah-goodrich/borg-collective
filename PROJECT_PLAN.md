# Project Plan: borg store-secret command
*Established: 2026-04-30*

## Objective
Add `borg store-secret <NAME>` to borg.zsh — prompt for the secret with `read -s`, store in the
macOS Keychain via `security add-generic-password`, idempotently patch
`~/.config/dotfiles/zsh/secrets.zsh` (registry comment row + `_keychain_export` line), reload the
shell config, and print a truncated verification. Replaces the manual `/dev-tools:store-secret`
skill workflow with a single CLI invocation.

## Acceptance Criteria
- [ ] `borg store-secret FOO_BAR` prompts hidden, stores via `security add-generic-password`,
      prints success.
  - Verify: run interactively, then `security find-generic-password -s FOO_BAR -a $USER -w` returns
    the value.
- [ ] Re-running the same command updates the keychain entry but does NOT duplicate the entries in
      `secrets.zsh`.
  - Verify: run twice with different values; `grep -c "_keychain_export FOO_BAR"
    ~/.config/dotfiles/zsh/secrets.zsh` returns `1`.
- [ ] Refuses cleanly without a TTY using `[[ -t 0 ]]` guard, with an actionable error message.
  - Verify: `echo '' | borg store-secret X` exits 1 and prints "must be run from an interactive
    terminal" (or similar).
- [ ] New bats test file exercises the `secrets.zsh` patcher against fixture files only — no live
      keychain access.
  - Verify: `bats tests/store_secret.bats` passes.
- [ ] Existing bats suite still green; `cmd_help` lists the new command.
  - Verify: `bats tests/` all pass; `borg help` output includes `store-secret`.
- [ ] Failure modes print next-action messages.
  - Verify: spoof `security` missing → "are you on macOS?"; remove `secrets.zsh` →
    "expected file at ~/.config/dotfiles/zsh/secrets.zsh; set BORG_SECRETS_FILE to override".

## Scope Boundaries
- NOT building: `--force`, `--file`, `--batch`, or any other flags. Single happy path only.
- NOT building: Linux / `secret-tool` / KDE wallet / any non-Darwin backend.
- NOT building: companion `list-secrets` or `rm-secret` commands.
- If done early: Ship. Don't expand.

## Ship Definition
1. Commit to `main` on `borg-collective` (single commit covering borg.zsh + tests + help text).
2. Manual smoke test storing one real secret end-to-end.
3. `bats tests/` all green locally.
4. `borg help` output verified.
5. Dotfiles-side change (anchor markers added to `secrets.zsh` on first run) committed separately
   in `~/.config/dotfiles`.

## Timeline
Target: this session.
Estimated effort: 1–1.5 hours (one session). Most of the time is in the secrets.zsh patcher and
its tests; the keychain calls and CLI dispatch are short.

## Risks
- **secrets.zsh format drift.** The patcher parses a specific structure (registry comment table at
  top + `_keychain_export` block). Mitigation: add anchor markers (`# BEGIN/END _keychain_export
  block`) on first run, and bail with a clear error if the expected structure isn't present.
  Don't silently append at EOF.
- **Cross-repo edit confusion.** borg.zsh edits a file in `~/.config/dotfiles`, a separate repo.
  Mitigation: a block comment at the top of `cmd_store_secret` explaining the contract and pointing
  at the expected secrets.zsh structure.
- **TTY-only requirement easy to miss in tests.** bats can't easily simulate an interactive TTY.
  Mitigation: factor the patcher into its own helper and test it in isolation against fixture
  files; smoke-test the full command interactively.
