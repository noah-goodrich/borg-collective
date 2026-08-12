# recon migration ledger (C6)

Per-command status against `PROJECT_PLAN.md`'s Part 3 (Python core migration, strangler pattern).
One row per `borg.zsh` top-level `case` arm, migrated / not-migrated / deliberately-staying-shell.

| Command | Status | Reason |
|---|---|---|
| `recon` | **Migrated** | Pattern-setter (C5). `borg_core/recon/{core,shell,cli}.py`, 96% coverage. `lib/recon.sh`, `lib/recon.zsh`, `tests/recon.bats` deleted 2026-08-12 once both `tests/recon.bats` and `tests/cli_contract.bats` passed unchanged against the Python port (testing-discipline gate satisfied). |
| `add`, `rm` | **Migrated** | `borg_core/registry/{core,shell,cli}.py`, 97% coverage. `cmd_add`/`cmd_rm` deleted from `borg.zsh` 2026-08-12. Sequenced ahead of `link`/`next` because `link` collides with the independent, unstarted `2026-08-11-link-unification-and-layout.md` directive (porting today's `cmd_link` now would likely be thrown away once that lands), and `scan` — despite the plan's "registry CRUD, pure logic" framing lumping it with `add`/`rm` — is actually a multi-source discovery engine wrapping `claude.zsh`/`coco.zsh`/`desktop.zsh` and an LLM-summarizer subprocess, none of which are ported; it deserves its own migration pass, not a bundled third item. |
| all other arms (`link`, `next`, `scan`, `pin`/`unpin`, `nanoprobes`, `spend`, `watch`, `switch`, `focus`, `init`, hooks, etc.) | **Not yet migrated** | `link` blocked on the link-unification directive landing in zsh first; `scan` is its own multi-source track (see above); `next`, then `nanoprobes`/`spend`/`watch`; `switch`/`focus`/`init` last (tmux-interactive). |
| `hooks/*.sh` (all 9) | **Deliberately staying shell** | Measured: Python startup floor ~41ms vs zsh/bash ~27ms; two `PostToolUse` hooks fire on every agent tool call (~250/session) — seconds of added latency for zero benefit. See `PROJECT_PLAN.md` "The measured boundary: hooks stay shell." |
| `drone.zsh` (all commands) | **Deliberately staying shell** | 1,044 lines of container/tmux orchestration — least logic, most shell affinity. Out of scope per `PROJECT_PLAN.md` Scope Boundaries. |

## Deviations from `PROJECT_PLAN.md` recorded here (not re-litigated elsewhere)

- **C1/C2 layer naming.** The plan describes a `domain`/`usecase`/`infrastructure` three-layer
  package. The shipped `recon` migration uses a two-file layout (`core.py` = pure logic,
  `shell.py` = I/O), which `pyproject.toml`'s `[tool.clean-arch] module_map` maps onto the same
  Silent Core Rule / DI enforcement the plan wants. Functionally equivalent for one command; if a
  second `borg_core/<command>` ships without collapsing to the same two-file pattern, revisit
  whether the plan's three-layer naming should be updated to match or the code should be
  restructured to match the plan.
- **`typer` dropped, not lazily imported.** The plan's C3 assumed `typer` as the CLI framework
  (lazily imported to keep the ~12ms import cost off the hot path). An adversarial review found
  `typer` was declared only in the `dev` dependency group, never provisioned by `install.sh`, and
  `cmd_recon`'s dispatch had no fallback — so a real install would `ModuleNotFoundError` on `borg
  recon`. Fixed 2026-08-12 by replacing `typer` with stdlib `argparse` in `cli.py`, removing the
  runtime dependency entirely rather than adding install-time provisioning. C3's verify command
  (`typer` absent from `sys.modules`) is now vacuously true.
- **Timeout enforcement changed.** `lib/recon.sh`'s `_recon_timeout` only applied `timeout <secs>`
  when the `timeout` binary was present (absent on stock macOS); `shell.py:run_adapter` always
  applies `subprocess.run(..., timeout=...)`. This is a real, intentional improvement (bounded
  fan-out now actually bounds a hung adapter everywhere), not a regression — flagged unstated by
  the adversarial review, recorded here, and now covered by
  `test_run_adapter_timeout_is_failed_track` in `test_shell.py`.
- **Concurrency scheduling mechanism differs.** `lib/recon.sh` batched adapters in groups of
  `max_tracks`, blocking on `wait` between batches; `shell.py:fanout` uses a
  `ThreadPoolExecutor`, a true sliding-window pool. Same concurrency bound, different scheduling —
  left as-is (an improvement, not a regression), now covered by
  `test_fanout_bounds_concurrency_to_max_tracks`.
- **Left unfixed (cosmetic/low-risk, noted not resolved):**
  - Digest tie-break order: shell used jq's `group_by` (alphabetical project order for equal
    urgency); `core.py`'s `merge_by_project` preserves first-encountered (adapter-submission)
    order. Deterministic in both, untested by either suite, cosmetic only — not fixed to avoid
    speculative behavior change with no test pinning the "correct" order.
  - Adapter listing order (`--adapters`/`--list`): shell used filesystem (`find`) order,
    arbitrary; `shell.py:discover_adapters` explicitly sorts. Cosmetic display-order-only
    improvement, left as-is.
  - `Makefile`'s `make lint` silently falls back to plain `pylint` (no clean-architecture plugin)
    if the dev group isn't installed locally. CI always installs the dev group first, so this
    never triggers there; left as-is since hard-failing `make lint` for a missing optional plugin
    on an uninstalled local machine is a bigger behavior change than this bounded fix cycle scope
    covers.

## `add`/`rm` migration — findings from adversarial review (2026-08-12)

An independent 3-lens review (parity / bugs / scope, each finding re-verified by a skeptical
second pass) raised 12 findings, 11 confirmed real, deduplicated to 7 distinct issues. Six were
fixed before merge; one was confirmed real but is an accepted, track-wide precedent, not a new
regression:

- **Fixed — BLOCKER: `last_activity` timezone.** The original `cmd_add` wrote `last_activity` via
  `stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%SZ"`, which on BSD formats in **local time** — the trailing
  `Z` is a literal character, not a UTC conversion. The first draft of `file_mtime_iso` computed
  genuine UTC via `datetime.fromtimestamp(mtime, tz=timezone.utc)`, which is correct in isolation
  but is a real, silent data-value divergence: the sole downstream reader, `lib/reaper.sh`'s
  `_borg_should_reap`, parses the field with `date -j -u` (forcing UTC interpretation), so the
  original's write-side mislabel and read-side mislabel cancelled into a correct staleness
  calculation by accident. Fixing only the write side breaks that cancellation on every non-UTC
  machine. Reverted to `time.strftime("%Y-%m-%dT%H:%M:%SZ", time.localtime(mtime))`, deliberately
  reproducing the bug, with the reasoning recorded in `shell.py`'s docstring. Pinned by
  `test_file_mtime_iso_uses_local_time_not_utc`, which fails if this regresses back to real UTC.
- **Fixed — argparse diverged from zsh's zero-flag `$1`-only reads.** `cmd_add`/`cmd_rm` never had
  a flag surface — extra positional args were silently ignored, and a value like `-h`/`--help` was
  just literal data (a project name to look up), not a flag. The first draft used `argparse`
  subparsers, which hard-fails on extra positional args (exit 2, no registration/removal) and
  auto-intercepts `-h`/`--help` (prints help, exit 0, skips the command entirely) — both confirmed,
  real divergences. Fixed by dropping `argparse` for this module in favor of direct `argv`
  indexing (`cli.py`'s `main()`), which is the more faithful port for a genuinely zero-flag
  command, not a step backward. `borg_core.recon.cli` correctly keeps `argparse` — `recon` has a
  real flag surface (`--since`, `--json`, etc.) that benefits from it.
- **Fixed — `read_registry()` crashed on malformed JSON.** No parity requirement pinned this (it
  was never a tested, documented contract), but an unhandled `json.JSONDecodeError` traceback is a
  worse failure mode than the original's jq-based graceful degradation. Wrapped in a `ValueError`
  with a clear message, caught in `cli.main()` and surfaced via the normal `_die` path (clean
  message, exit 1) instead of a raw traceback. Deliberately does NOT silently degrade to an empty
  registry — a subsequent write could then overwrite a corrupted-but-recoverable file.
- **Fixed — `claude_encode_path` over-stripped trailing slashes.** Used `str.rstrip("/")` (strips
  all trailing slashes) where zsh's `${1%/}` strips exactly one. Narrow edge case (only reachable
  via a raw, nonexistent path with 2+ trailing slashes), fixed to a single-slash strip for exact
  parity.
- **Fixed — TOCTOU race in `claude_latest_session_id`.** `max(jsonl_files, key=lambda p:
  p.stat().st_mtime)` had no guard against a file vanishing between the `glob()` and the `stat()`
  (e.g. a concurrent transcript rotation), inconsistent with `file_mtime_iso`'s own `except
  OSError` a few lines below in the same file. Extracted a `_mtime_or_epoch` helper that returns
  `0.0` instead of raising.
- **Not fixed — colored `▸`/`ERROR:` output dropped.** Real, confirmed byte-level difference from
  the original's ANSI-styled `info()`/`die()` output. Left as-is: this is the same, already-shipped
  convention `borg_core.recon.cli._die` established (also bare, unstyled) — a track-wide,
  intentional simplification for the whole Python-CLI surface, not a regression introduced by this
  migration.
