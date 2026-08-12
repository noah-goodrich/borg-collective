# recon migration ledger (C6)

Per-command status against `PROJECT_PLAN.md`'s Part 3 (Python core migration, strangler pattern).
One row per `borg.zsh` top-level `case` arm, migrated / not-migrated / deliberately-staying-shell.

| Command | Status | Reason |
|---|---|---|
| `recon` | **Migrated** | Pattern-setter (C5). `borg_core/recon/{core,shell,cli}.py`, 96% coverage. `lib/recon.sh`, `lib/recon.zsh`, `tests/recon.bats` deleted 2026-08-12 once both `tests/recon.bats` and `tests/cli_contract.bats` passed unchanged against the Python port (testing-discipline gate satisfied). |
| all other arms (`link`, `next`, `scan`, `add`, `rm`, `pin`/`unpin`, `nanoprobes`, `spend`, `watch`, `switch`, `focus`, `init`, hooks, etc.) | **Not yet migrated** | Sequencing per `PROJECT_PLAN.md` "Sequencing after C5": `link` next (biggest win), then `next`, then registry CRUD, then `nanoprobes`/`spend`/`watch`; `switch`/`focus`/`init` last (tmux-interactive). |
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
