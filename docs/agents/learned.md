# Learned

Entries moved verbatim from the top-level CLAUDE.md. Hook-owned entries live in hooks/CLAUDE.md and test-owned ones in tests/CLAUDE.md.

- **Cairn decommission (2026-08)**: cairn (a Postgres+pgvector knowledge-graph service) was retired
  after a research pass found its sole differentiating claim — cross-project semantic recall —
  measured at 0.4% restatement, indistinguishable from a null baseline; same-project restatement
  (17%) was real but already served by checkpoints. See `~/dev/cairn/docs/research/README.md` for
  the full evidence base and `docs/plans/directives/2026-08-08-cairn-decommission-and-unconditional-block.md`
  for the teardown. The transferable lesson: build capture that derives from an artifact the agent
  already produces (checkpoint mining worked); never build capture that asks the agent to
  volunteer (four shipped, tested, exposed voluntary-write surfaces produced one real row in five
  months). `borg-memory-read-log.sh` now instruments the replacement (Claude Code project memory)
  so the same blind spot can't recur unnoticed.
- **tmux zoom is a toggle**: `resize-pane -Z` toggles zoom on/off. If a helper zooms a pane and
  the caller also zooms it, the second call unzooms. Apply zoom in exactly one place — the final
  caller, not intermediate helpers.
- **Notifications must not steal focus**: macOS notifications should only activate the target app
  on click (`-activate`), never on fire. Unsolicited focus changes interrupt whatever the user is
  doing.
- **devcontainer postStartCommand vs postCreateCommand**: `drone` runs BOTH. `run_post_create_command`
  executes `postCreateCommand` ONCE — sentinel-guarded by `/tmp/.drone-created`, so one-time deps
  (pip/npm install, chmod) run on first create and are skipped thereafter. `run_post_start_command`
  executes `postStartCommand` on EVERY start (per-start symlinks: zshrc, .p10k, workspace symlink).
  So per-start setup belongs in `postStartCommand`; one-time dependency install belongs in
  `postCreateCommand`. (Earlier docs said drone never ran `postCreateCommand` — that is now stale;
  it is invoked from the `drone up`/start paths in `drone.zsh`.)
- **`claude plugin install` takes a marketplace name, not a file path**: the correct syntax is
  `claude plugin install <name>@<marketplace>`, not `claude plugin install <file>.plugin`. The
  local marketplace (`noah-local`) resolves from the plugins source directory, not `dist/`.
- **`borg.zsh` sources only `lib/*.zsh`, not `lib/*.sh`**: helpers intended for both the CLI and
  bash hook scripts must be defined in two places — `lib/borg-hooks.sh` (bash, sourced by hooks)
  and `lib/<name>.zsh` (zsh, picked up by the CLI glob). Check the source path before writing a
  shared helper.
- **Don't track copy success via mtime deltas**: if a helper function copies a file and you need
  to know whether it acted, return a status code or accept a callback — don't read before/after
  mtime from outside the helper. That's leaky and adds syscalls. Simplest: just log
  unconditionally or restructure so the caller does the condition check itself.
- **A shell variable is not an environment variable — the zsh→Python boundary loses every config var**:
  `borg.zsh` assigns its whole config surface without `export` (`BORG_DIR` :24, `BORG_MAX_ACTIVE`/
  `BORG_CORTEX_WAKES` :43-48, `BORG_REGISTRY` in `lib/registry.zsh:15`, `BORG_TMUX_SESSION` in
  `lib/tmux.zsh:5`, `BORG_REAP_STALE_HOURS` in `lib/reaper.sh:11`). An in-process zsh function sees all of
  them; a `python3 -m borg_core...` child sees none. This shipped: `borg recon` read `BORG_REGISTRY` from the
  environment with no fallback and died with `no registry at ` on **every** real invocation except
  `--adapters`, which returns before the check — the command was non-functional from the migration until
  2026-08-13. Two rules follow. (1) Route every Python dispatch through `_borg_py` (defined just above the
  `case` block in `borg.zsh`) so the child gets the config surface, with defaults applied *in the wrapper* —
  an exported-empty `BORG_REAP_STALE_HOURS` makes `int("")` raise, so an unset var must arrive as its default
  or not at all. (2) The Python side still resolves its own defaults (`borg_core/paths.py`), because a module
  invoked directly has no wrapper. **Why no test caught it**: every test reaching the Python core puts
  `BORG_REGISTRY` in the environment *itself* — `tests/test_helper/setup.bash` exports it, the pytest suites
  monkeypatch it — so the inheritance path was the one line no test ever executed. Same shape as the
  usage-watch and memory-gate blind spots below: **when a test supplies the value the production path is
  supposed to derive, it proves nothing about production.**
