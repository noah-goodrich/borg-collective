# Environment Variables

Every `BORG_*` name the code reads, what reads it, what it does, and its default. Derived by grepping
`borg.zsh`, `drone.zsh`, `install.sh`, `lib/`, `hooks/`, `bin/`, `borg_core/`, `merge-tree/`, and
`evals/`.

Most of these have a sensible default and are never set by hand. The ones you are most likely to
want are marked **tunable**; the ones marked **test seam** exist so a test can replace a subprocess
or a clock and should not be set in a real shell.

User-facing configuration belongs in `~/.config/borg/config.zsh`, which `borg.zsh` sources at
startup. See the [Cheatsheet](cheatsheet.md) for the short list of everyday settings.

---

## Read this first: a shell variable is not an environment variable

**This has already shipped a completely dead command.**

`borg.zsh` assigns its entire configuration surface *without* `export`:

- `BORG_DIR` and `BORG_CONFIG` in `borg.zsh`
- `BORG_MAX_ACTIVE`, `BORG_SESSION_WARN_HOURS`, `BORG_WORK_*`, `BORG_CORTEX_WAKES` in `borg.zsh`
- `BORG_REGISTRY` and `BORG_LOCK` in `lib/registry.zsh`
- `BORG_TMUX_SESSION` in `lib/tmux.zsh`
- `BORG_REAP_STALE_HOURS` in `lib/reaper.sh`

An in-process zsh function sees all of them. A `python3 -m borg_core...` **child process sees none of
them.** `borg recon` read `BORG_REGISTRY` from the environment with no fallback and died with
`no registry at ` on every real invocation except `--adapters` — non-functional from the migration
until 2026-08-13.

Two rules follow:

1. **Route every Python dispatch through `_borg_py`** (defined just above the `case` block in
   `borg.zsh`). It re-exports the config surface by name so the child inherits it, with defaults
   applied *in the wrapper*.
2. **The Python side resolves its own defaults anyway** (`borg_core/paths.py`), because a module
   invoked directly has no wrapper.

And one consequence that keeps biting: **a variable passed through `_borg_py` arrives as the empty
string when it is unset.** `int("")` raises. Any reader on that path must treat unset, empty, and
non-numeric identically. `borg_core/link/shell.py`'s `sweep_timeout` and `sweep_window_days` do this
correctly; `borg_core/recon/shell.py`'s `_int_env` exists for the same reason, and a bare
`int(os.environ.get(...))` is a bug waiting for someone to `export BORG_RECON_MAX_TRACKS=` and clear
it.

Why no test caught the original failure: every test reaching the Python core puts `BORG_REGISTRY` in
the environment *itself*. When a test supplies the value the production path is supposed to derive,
it proves nothing about production.

---

## Core paths and identity

| Variable | Read by | Purpose | Default |
|----------|---------|---------|---------|
| `BORG_DIR` | `borg.zsh`, `drone.zsh`, `lib/registry.zsh`, every hook, `bin/borg-cortex-watch`, `bin/memory-hits-report`, `borg_core/paths.py` | The config directory. Registry, config, cortex-wake state, desktop sessions, memory-gate verdict. | `${XDG_CONFIG_HOME:-$HOME/.config}/borg` |
| `BORG_REGISTRY` | `lib/registry.zsh`, hooks, `bin/borg-notifyd`, `borg_core/paths.py` | Path to `registry.json`. | `$BORG_DIR/registry.json` |
| `BORG_CONFIG` | `borg.zsh` | The sourced user config file. Derived, not an override. | `$BORG_DIR/config.zsh` |
| `BORG_LOCK` | `lib/registry.zsh` | Registry lock file for atomic writes. Derived. | `$BORG_DIR/.registry.lock` |
| `BORG_HOME` | `borg.zsh`, `install.sh`, `tests/test_helper/setup.bash` | Directory containing `borg.zsh` — the source tree, used to locate `lib/`, `hooks/`, `skills/`, and the repo-root `.venv`. | the script's own directory |
| `BORG_ROOT` | `install.sh`, `scripts/build-plugin.sh` | The install path of the borg source tree, exported by the installer. Same value as `BORG_HOME`; the two-name split is deliberate — see `BORG_ORCHESTRATOR_ROOT`. | `$BORG_HOME` |
| `BORG_ORCHESTRATOR_ROOT` | `borg.zsh`, `drone.zsh`, `lib/borg-hooks.sh`, `lib/registry.zsh`, `borg_core/link/shell.py`, `scripts/build-plugin.sh` | The **workspace** root where projects live. A session whose `$CWD` exactly equals this is the orchestrator session and writes nothing to the registry. | `$HOME/dev` |
| `BORG_TMUX_SESSION` | `lib/tmux.zsh`, `drone.zsh`, `lib/borg-hooks.sh`, `borg_core/registry/shell.py` | The tmux session name borg manages. | `borg` |
| `BORG_BIN` | `install.sh` | Where the `borg` symlink is written. | `$BIN_DIR/borg` (`~/.local/bin/borg`) |
| `BORG_VERSION` | `borg.zsh` | The version string printed by `borg version`. Assigned, never overridden. | the literal in `borg.zsh` |
| `BORG_DESKTOP_DIR` | `lib/desktop.zsh` | Where Claude Desktop session JSON is read from. Derived. | `$BORG_DIR/desktop` |
| `BORG_SECRETS_FILE` | `borg.zsh` (`borg store-secret`) | The `secrets.zsh` file patched with new keychain exports. | `$HOME/.config/dotfiles/zsh/secrets.zsh` |
| `BORG_IMAGE_REGISTRY` | `borg.zsh` (`borg image`) | Container registry to tag/push/pull against. `borg image push`/`pull` die without it. | unset |
| `BORG_STILLPOINT_SUPABASE_DIR` | `borg.zsh`, `hooks/borg-supabase-guard.sh` | Checkout holding the shared-local Supabase config. | `$HOME/dev/stillpoint` |
| `BORG_PROJECT_NAME` | `lib/drone-hooks.zsh` (exported *to* borg-hooks) | Set by drone when running a project's `pre-up.sh`/`post-down.sh`. Not an input. | n/a |
| `BORG_MACHINE` | `merge-tree/gather.py` | Machine label stamped onto gathered rows so a cross-machine hub can attribute them. | `""` |

**Tunable, everyday:**

| Variable | Read by | Purpose | Default |
|----------|---------|---------|---------|
| `BORG_MAX_ACTIVE` | `borg.zsh`, `hooks/borg-link-down.sh`, `borg_core/link/shell.py` | Capacity warning threshold — how many projects may be `active` before borg complains. | `3` |
| `BORG_SESSION_WARN_HOURS` | `borg.zsh` | Hours before a running session is flagged as long. | `2` |
| `BORG_WORK_HOURS` | `borg.zsh` | Work/life boundary window, e.g. `09:00-18:00`. Empty disables the check. | unset (empty) |
| `BORG_WORK_DAYS` | `borg.zsh` | Days the work boundary applies to. Empty disables. | unset (empty) |
| `BORG_WORK_PROJECTS` | `borg.zsh` | Comma-separated projects treated as work, e.g. `api-service,internal-tools`. | unset (empty) |
| `BORG_REAP_STALE_HOURS` | `lib/reaper.sh`, `borg.zsh`, `borg_core/link/shell.py` | Hours after which an active/waiting status is reaped to idle, and a nanoprobe worktree is considered stale. | `12` |
| `BORG_NO_REAP` | `lib/registry.zsh`, `borg_core/link/shell.py` | Any non-empty value suppresses the reap overlay on a registry read. Used internally to avoid recursion. | unset |
| `BORG_WORKTREE_STATE_DIR` | `lib/reaper.sh` | Root under which nanoprobe worktrees live and are reaped from. | see `lib/reaper.sh` — currently a hardcoded absolute path, not `$HOME`-derived (see Known drift) |
| `BORG_MERGE_TREE_DIR` | `merge-tree/{gather,render,render_graph,spine}.py`, `merge-tree/app/` | Machine-local state directory for the PR hub: `data.json`, `annotations.local.json`, `index.html`. Never in the repo. | `~/.local/state/borg/merge-tree` |

---

## Recon and adapters

| Variable | Read by | Purpose | Default |
|----------|---------|---------|---------|
| `BORG_RECON_ADAPTER_PATH` | `borg_core/recon/shell.py` | Colon-separated adapter search path, `PATH`-style. Any executable named `recon-adapter-<source>` on it registers that source. | `$BORG_DIR/recon/adapters:<repo>/lib/recon/adapters` — config dir shadows the repo dir |
| `BORG_RECON_LIB_DIR` | `borg_core/recon/shell.py` | Directory holding the shipped reference adapters. Set by the zsh shim. | the repo's own `lib/` |
| `BORG_RECON_MAX_TRACKS` | `borg_core/recon/shell.py` | Concurrency bound on the adapter fan-out. Clamped to a minimum of 1. | `8` |
| `BORG_RECON_TRACK_TIMEOUT` | `borg_core/recon/shell.py` | Per-track timeout in seconds. **Not clamped** — `0` genuinely means "no patience at all", and that is deliberate. | `30` |
| `BORG_SYNC_TARGET_PATH` | `merge-tree/coordinator.py` | Colon-separated search path for a discovered `borg-sync-target-*` executable. Exactly one target is dispatched to, never a fan-out. | `~/.config/borg/sync-targets` |

---

## Timeouts and degradation

These govern whether `borg link` **degrades a row** rather than hanging. The docs discuss the
degradation; these are the knobs behind it.

| Variable | Read by | Purpose | Default |
|----------|---------|---------|---------|
| `BORG_LINK_SWEEP_TIMEOUT` | `borg_core/link/shell.py` | Seconds the adapter sweep may take before rows fall back to what the manifest declares. Chosen against measurement: the batched-GraphQL adapter sweeps all 14 repos in 2.30s, so this is >4x the slowest observed real sweep. | `10` |
| `BORG_LINK_FETCH_TIMEOUT` | `borg_core/link/shell.py` | Seconds the targeted `gh api graphql` fetch may take. | `10` |
| `BORG_LINK_SWEEP_WINDOW_DAYS` | `borg_core/link/shell.py` | How far back the sweep's since-mark reaches. `borg link` resolves its own mark rather than reusing recon's since-ladder, so a render never advances recon's mark. | `90` |
| `BORG_GIT_TIMEOUT` | **nothing** | Historical. `borg_core/manifest/shell.py` now uses a `GIT_TIMEOUT_SECONDS = 5` module constant and reads no environment variable. The name survives only in a test comment. | n/a — not live |

Unset, empty, and non-numeric all take the default for the three live variables here. That is the
`_borg_py` empty-string rule above, not defensive padding.

---

## Usage Guardian

The Usage Guardian is `bin/borg-usage-watch` (a launchd poller that samples `claude -p "/usage"`) plus
`hooks/borg-dispatch-guard.sh` (a `PreToolUse` veto on new Agent/Workflow dispatch). The 85% sweep and
92% hard stop are documented elsewhere; these are their knobs. All are read by `bin/borg-usage-watch`
unless noted.

### Thresholds and cadence

| Variable | Purpose | Default |
|----------|---------|---------|
| `BORG_USAGE_CHECKPOINT_PCT` | Session usage % at which the checkpoint sweep fires. | `85` |
| `BORG_USAGE_HALT_PCT` | Session usage % at which dispatch is halted. Also read by `hooks/borg-dispatch-guard.sh`. | `92` |
| `BORG_USAGE_WEEK_WARN_PCT` | Weekly-quota % at which a warning fires. | `90` |
| `BORG_USAGE_FAST_PCT` | Usage % above which the poller switches to the fast interval. | `70` |
| `BORG_USAGE_BASE_INTERVAL` | Normal sampling interval, seconds. launchd wakes the script every 60s; the script decides whether this invocation samples. | `120` |
| `BORG_USAGE_FAST_INTERVAL` | Sampling interval once above `BORG_USAGE_FAST_PCT`, seconds. | `60` |
| `BORG_USAGE_UNKNOWN_ALERT_COUNT` | Consecutive unparseable samples before alerting. | `3` |

### Enablement

| Variable | Read by | Purpose | Default |
|----------|---------|---------|---------|
| `BORG_USAGE_HALT_ENABLED` | `hooks/borg-dispatch-guard.sh` | `1` arms the >=92% dispatch veto. The hook exits 0 immediately otherwise — **default-OFF**. | `0` |
| `BORG_USAGE_HALT_TTL_SEC` | `hooks/borg-dispatch-guard.sh` | How old the newest sample may be and still authorize a halt. Past this the guard fails open. | `300` |
| `BORG_USAGE_SWEEP_ENABLED` | `bin/borg-usage-watch` | `1` arms the 85% checkpoint sweep's tmux writes. **Default-OFF.** | `0` |
| `BORG_USAGE_SWEEP_CMD_TEXT` | `bin/borg-usage-watch` | The command text sent into each pane by the sweep. | `/borg-link-up` |
| `BORG_USAGE_WATCH` | `install.sh` | `0` skips installing the `borg-usage-watch` launchd agent. | `1` |

### State and logs

| Variable | Read by | Purpose | Default |
|----------|---------|---------|---------|
| `BORG_USAGE_SAMPLES` | `bin/borg-usage-watch`, `hooks/borg-dispatch-guard.sh` | The JSONL sample ledger. | `${XDG_STATE_HOME:-$HOME/.local/state}/borg/usage-samples.jsonl` |
| `BORG_USAGE_LOG` | `bin/borg-usage-watch` | Poller log. | `${XDG_STATE_HOME:-$HOME/.local/state}/borg/usage-watch.log` |
| `BORG_USAGE_GUARDIAN_STATE` | `bin/borg-usage-watch` | Guardian state file (last fire, transitions). | `$BORG_CONFIG_DIR/usage-guardian.json` |
| `BORG_CONFIG_DIR` | `bin/borg-usage-watch` | This script's own config-dir resolution; parallel to `BORG_DIR`, not an alias for it. | `${XDG_CONFIG_HOME:-$HOME/.config}/borg` |
| `BORG_USAGE_FORCE_PROBE_FILE` | `bin/borg-usage-watch` | Touch-file that forces a probe on the next wake regardless of cadence. | `<state dir>/usage-watch.force-probe` |
| `BORG_USAGE_PROBE_TRANSCRIPT_DIR` | `bin/borg-usage-watch` | Where the probe's own throwaway transcripts land, so they can be pruned. | `$HOME/.claude/projects/-` |
| `BORG_USAGE_PROBE_RETAIN_MIN` | `bin/borg-usage-watch` | Minutes of probe transcripts to retain before pruning. | `60` |

### Test seams

Set only by tests. Each replaces a subprocess or the clock so the poller can be exercised without
tmux, `ps`, or a real `claude`.

| Variable | Replaces | Default |
|----------|----------|---------|
| `BORG_USAGE_CLAUDE_BIN` | the `claude` binary the probe invokes | `claude` |
| `BORG_USAGE_PANE_CMD` | the per-pane tmux query | unset (real tmux) |
| `BORG_USAGE_PANES_CMD` | the pane **lister** | unset (real tmux) |
| `BORG_USAGE_SENDKEYS_CMD` | `tmux send-keys` | unset (real tmux) |
| `BORG_USAGE_SENDKEYS_DELAY` | seconds between the text send and the Enter send | `0.5` |
| `BORG_USAGE_PROC_CMD` | the process-inspection command | unset (real `ps`) |
| `BORG_USAGE_NOW_EPOCH` | `date +%s`, in the poller and in `hooks/borg-dispatch-guard.sh` | unset (real clock) |

---

## Memory gate

The auto-memory read instrument: `hooks/borg-memory-read-log.sh` logs reads, `bin/memory-hits-report`
computes reads/session against a pre-registered `< 0.2` null, and `bin/borg-memory-gate` delivers the
verdict through a channel that interrupts. All four are read by `bin/borg-memory-gate` unless noted.

| Variable | Purpose | Default |
|----------|---------|---------|
| `BORG_MEMORY_GATE_LOG` | The gate's own run log. | `${XDG_STATE_HOME:-$HOME/.local/state}/borg/memory-gate.log` |
| `BORG_MEMORY_GATE_VERDICT_FILE` | Verdict file written on a FAIL transition. Also **read by `hooks/borg-link-down.sh`**, which surfaces it loudly at SessionStart. | `$BORG_DIR/memory-gate-verdict.json` |
| `BORG_MEMORY_GATE_STATE` | Last-known PASS/FAIL state, so only *transitions* notify. | `$BORG_DIR/memory-gate-state.json` |
| `BORG_MEMORY_GATE_REPORT_BIN` | Path to the `memory-hits-report` executable. | `command -v memory-hits-report`, else empty |

---

## Escape hatches and opt-outs

| Variable | Read by | Purpose | Default |
|----------|---------|---------|---------|
| `BORG_BASH_GUARD_DISABLE` | `hooks/bash-guard.sh` | **Any non-empty value disables the destructive-pattern hard block entirely.** The guard exits without inspecting the command. Setting this in a shell profile or a project env file silently removes the only automated protection against destructive Bash calls — set it for a single invocation, never persistently. | unset |
| `BORG_NO_SPEND_RECORD` | consumed by the token-cost SessionEnd hook; **set** by `bin/borg-usage-watch` on its internal `claude -p "/usage"` poll | Suppresses a spend record for that invocation, so a poller running every 120s does not flood `~/.claude/token-spend.jsonl` with zero-cost rows. | unset |
| `BORG_NO_SESSION_HOOKS` | `hooks/borg-link-down.sh`; set by `bin/borg-usage-watch` alongside the above | `1` makes the SessionStart hook exit immediately, so the poller's headless session does not flip registry status or inject context. | unset |
| `BORG_DEBUG` | `borg.zsh`, `drone.zsh` | Any non-empty value enables `dbg()` output on stderr. | unset |
| `BORG_CONTAINER_MARKER` | `hooks/bash-guard.sh` | Path whose existence means "we are inside a container", enabling install-verb pre-approval. When unset the hook probes `/.dockerenv` and `/run/.containerenv`. | unset |
| `BORG_PATH_PREFIX` | `borg.zsh` | Prepended to the `PATH` borg builds. Primarily a test seam for stubbing `tmux` and friends. | unset |
| `BORG_DRONE_EXTRA_PATH` | `drone.zsh` | Same idea for drone: prepended to `PATH`. | unset |

---

## Test and eval seams

Do not set these in a working shell.

| Variable | Read by | Purpose | Default |
|----------|---------|---------|---------|
| `BORG_LINK_SWEEP_FIXTURE` | `borg_core/link/shell.py` | Replaces the whole adapter sweep with a recorded fixture. Returns before any fork. | unset |
| `BORG_LINK_FETCH_FIXTURE` | `borg_core/link/shell.py` | Replaces the `gh api graphql` fetch with a recorded fixture. Read *after* `fetch_query`, which never forks, so the "seam first" property holds. | unset |
| `BORG_UPDATE_GOLDEN` | the golden-file suites | Regenerates golden fixtures. **It cannot rewrite `picture-fork.expected` / `picture-crossing.expected`** — those are hand-authored oracles, deliberately outside its reach, and must stay that way. Also must never be used to freeze one machine's network state as an oracle. | unset |
| `BORG_EVAL_REPO` | `evals/s4-k3/run.sh` | The repository under eval. | derived from the script's own location |
| `BORG_EVAL_STILLPOINT` | `evals/s4-k3/run.sh` | Optional second repository. Absent means the dependent cases **SKIP with a named reason**, never FAIL. | unset (empty) |
| `BORG_EVAL_TROTH` | `evals/s4-k3/run.sh` | Optional third repository, same contract. | unset (empty) |
| `BORG_CORTEX_STATE` | `borg.zsh`, `bin/borg-cortex-watch` | Overrides the Cortex wake-state file. Note the asymmetry: this is the **override**, and `BORG_CORTEX_WAKES` is the derived value `borg.zsh` computes from it. | `$BORG_DIR/cortex-wakes.json` |
| `BORG_CORTEX_WAKES` | `borg.zsh`, forwarded by `_borg_py` | The resolved Cortex wake-state path. Derived from `BORG_CORTEX_STATE`; setting this directly is not honored by `bin/borg-cortex-watch`. | `$BORG_DIR/cortex-wakes.json` |

---

## Names that look like environment variables and are not

These appear in a grep but are shell-locals or arrays, and setting them in your environment does
nothing:

- `_BORG_SECRET`, `_BORG_VERIFY` — function-locals in `borg store-secret`, holding a keychain secret
  and its read-back verification. Deliberately `local` and `unset` on every exit path.
- `_BORG_COLOR_PALETTE` — the fixed tmux color array in `lib/colors.zsh`. Use the registry's per-project
  `color` field (`borg color`) instead.
- `_BORG_MARKER_WALK` — an inlined shell snippet in `hooks/bash-guard.sh`.
- `_BORG_RECON_RETIRED_LEAD` — removed; the retirement message now lives in `borg_core/recon/cli.py`.

---

## Known drift

Noted while cataloguing, not fixed here:

- `BORG_GIT_TIMEOUT` is documented in a test comment as a live override but `borg_core/manifest/shell.py`
  uses a module constant. The variable is read by nothing.
- `lib/reaper.sh`'s `BORG_WORKTREE_STATE_DIR` default is a hardcoded absolute path under one user's home
  rather than `${XDG_STATE_HOME:-$HOME/.local/state}/borg/worktrees`. Every sibling script in the tree
  derives its default; this is the one that does not.
