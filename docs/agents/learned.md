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

## Moved from CLAUDE.md 2026-10-30

History moved verbatim out of the Architecture Rules bullets. The rules stay in CLAUDE.md.

- Prior decisions live in `.borg/checkpoints/` and `docs/plans/assimilated/` — grep them before
  assuming something is undocumented. **`.borg/knowledge/` was removed from this list 2026-09-28 and
  its 1106 tracked files were NOT deleted.** It is the decommissioned cairn service's export (see
  the dotfiles `.gitignore`, which says so outright), and no code path has ever read it — so naming
  it here was a promise to every agent that nothing kept. Retiring a store means deleting the
  PROMISE, not the data: the files stay, greppable by anyone who wants them, and the reader census
  (`docs/state-census.md`) now stops caring about them because nothing claims anything about them.
  The full argument is in `docs/plans/directives/assets/2026-09-28-state-audit-adversarial.md`.
- **Schema evolution is ALWAYS expand → migrate → contract, everywhere, no exceptions.** Add the new
  form and accept both; migrate every existing instance; only then remove the old form or tighten the
  validator. Never the other order. Done this way a schema change cannot produce a regression,
  because no artifact is ever read by rules it was not written to satisfy — which is the whole reason
  it is a rule and not a preference. The tell that it was skipped: existing, untouched data suddenly
  failing validation with no write in between. When that happens the temptation is to weaken the
  validator, and weakening it is how two validators come to disagree in the first place (AC7 exists
  to end exactly that). "Additive first" is also why a port lands as a NEW path before any caller is
  repointed: `borg_core/manifest/shell.write_manifest` shipped 2026-09-01 accepting the strict
  validator while `coordinator.py` and `gather.py` still used the old one — that commit was the
  expand phase, and repointing them is the contract phase, which may not happen until the **57**
  shorthand ref occurrences in `merge-tree/test_coordinator.py` have been migrated to satisfy the
  stricter rules (that sequence has since run to the end: fixtures migrated, `coordinator.py` repointed,
  `merge-tree/programs.py` deleted, 2026-10-12). **Migrate only what the SURVIVING validator rejects.** An artifact that fails only
  the validator being deleted needs no migration at all — it is resolved by the contraction. The
  first draft of this rule listed `warehouse-rollout.json`'s `kind: "review"` as a prerequisite; it
  is clean under `core.validate` and fails only merge-tree's `GATE_KINDS` closure, which borg_core
  removed on purpose. "Migrating" it would have meant rewriting data BACKWARD to satisfy a dying
  rule, and five oracles pin that literal string. Direction matters: expand→migrate→contract governs
  data the new rules reject, not data the old ones did.
