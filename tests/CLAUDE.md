# tests/ rules

Rules owned by this directory, moved verbatim from the top-level CLAUDE.md.

- **A redirected `HOME` also silently deletes the test sandbox's git identity, and macOS won't tell
  you**: `setup_temp_dirs()` in `tests/test_helper/setup.bash` redirects `HOME`, which means
  `~/.gitconfig` is gone by construction for every bats case — but `recon_adapter_github.bats`'s
  "a linked worktree is swept" case needs `git commit` to work (a worktree needs a commit to point
  at). This passed on macOS for weeks because git auto-derives an identity from getpwuid plus a
  resolvable hostname and commits anyway with a warning (author lands as
  `Noah <noah@MacBook-Pro-4.local>`); measured in a Linux container the hostname has no domain and
  git refuses outright (`fatal: unable to auto-detect email address`, rc=128) — and CI's ubuntu lane
  runs exactly this suite. Fix: export `GIT_AUTHOR_NAME`/`_EMAIL`, `GIT_COMMITTER_NAME`/`_EMAIL`,
  and `GIT_CONFIG_NOSYSTEM=1` in `setup_temp_dirs()` — env vars, not a written `.gitconfig`, because
  the harness redirects both `HOME` and `XDG_CONFIG_HOME` and a file means picking the right one and
  staying right as either changes; env vars beat every config layer with no path resolution. Same
  family as the `XDG_CONFIG_HOME` leak above and "a shell variable is not an environment variable"
  below it in this list: the sandbox is incomplete in a way the dev machine silently papers over,
  which is exactly why it was invisible where it was being tested.
- **A test's PREMISE can depend on the dev platform, not just its environment — and the macOS lane
  structurally cannot catch it**: four failures, one class, all found together on one PR. (1) pytest
  (unlike bats) never redirects `HOME`, so two `borg_core/manifest/test_shell.py` tests that shell to
  `git commit` passed on Noah's machine (global `~/.gitconfig` supplies an identity) and died with
  rc=128 on a bare GitHub runner (no identity at all) — fixed with an autouse `borg_core/conftest.py`
  fixture exporting the same `GIT_AUTHOR_*`/`GIT_COMMITTER_*`/`GIT_CONFIG_NOSYSTEM=1` values the bats
  harness uses, so the two suites can't drift. (2) `test_proc.py` built a "binary output" fixture with
  `printf 'ok-\xff-end'` inside a `#!/bin/sh` script — hex `\xNN` is a bash-ism; macOS `/bin/sh` is
  bash-in-sh-mode and understands it, Linux `/bin/sh` is dash and does not, so the "invalid UTF-8"
  test was asserting on a string that was never binary. Fixed with the POSIX octal form `\377`, which
  both shells agree on — verified in `debian:stable-slim`. (3) A bats test hid `gh` for a "gh not
  installed" test case via `PATH="/usr/bin:/bin"`, which assumes `gh` lives outside those directories
  — true on macOS (Homebrew → `/opt/homebrew/bin`), false on `ubuntu-latest`, which preinstalls `gh` at
  `/usr/bin/gh`. Fixed by deriving an ALLOWLIST bin dir from the adapter's own source (only the
  binaries it actually calls, symlinked in) instead of guessing which directories a binary isn't in —
  and that allowlist has to include `bash` itself, since the adapter's `#!/usr/bin/env bash` shebang
  makes `env` search the very PATH under test to find the interpreter. In all three cases the
  `contract-macos` lane is structurally incapable of catching the bug, because it is the one platform
  where the false premise holds — it is not a weaker check, it is checking a different fact. The
  transferable rule: when a test fixture depends on a shell built-in's behavior, a system path's
  contents, or an ambient identity, verify the ASSUMPTION on the CI platform, not just the assertion
  on your own machine — reproduce it in a container matching the runner (including the binary you're
  trying to hide) before trusting a green run.
