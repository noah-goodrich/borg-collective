# Contributing Guide

This is the doc for someone who has cloned the repo and wants to change it. It covers the one
prerequisite that is not optional, how to run every gate, and what lives in the source trees that no
other doc names.

If you are installing borg to *use* it, read the [Quickstart Guide](quickstart.md) instead. If you
want to know how the pieces fit together at runtime, read the
[Architecture Guide](architecture.md).

---

## Prerequisite: create the `.venv` first

**Do this before running anything else:**

```bash
python3 -m venv .venv && .venv/bin/pip install --group dev
```

This repo has **no devcontainer**. There is no `.devcontainer/`, no compose file, and no Dockerfile,
and that is deliberate: `borg` and `drone` drive the host — tmux windows, Docker lifecycle, launchd
agents, deployment into `~/.claude`. Containerizing the tool that manages containers is inside-out.

That makes this tree the standing exception to the project rule that tooling runs via `drone exec`.
The isolation still has to come from somewhere, and here it comes from a repo-root `.venv`. It is
already in `.gitignore`.

**What happens if you skip it** (measured 2026-09-11): `tests/test_helper/setup.bash` provides
`_python_with_pytest`, which probes `$BORG_HOME/.venv/bin/python` first and falls back to
`command -v python3`. With no `.venv`, that fallback finds the host interpreter, whose `pytest` lives
in the HOME-derived user site (`~/Library/Python/3.14/lib/python/site-packages`). But
`setup_temp_dirs` redirects `HOME`, so `import pytest` fails inside the sandbox and five
`tests/eval_floor.bats` cases go red with `premise broken: no interpreter with an importable pytest`.

The advice in that message is right and the diagnosis it implies is wrong — pytest *is* installed,
just somewhere the test sandbox hides. CI never reproduces it, because `pip install --group dev` on a
`setup-python` interpreter lands outside `$HOME`. It is a host-only red.

Other prerequisites: `zsh`, `jq`, `fzf`, `bats`, Python 3.14, and `shellcheck` if you want to run the
lint gate locally the way CI does.

---

## Running the tests

There are **two independent test surfaces**, and they are run by different commands:

| Surface | Language | Command | What it covers |
|---------|----------|---------|----------------|
| bats | zsh/bash | `bats tests/*.bats` | `borg.zsh`, `drone.zsh`, `lib/`, `hooks/`, `bin/`, `install.sh` |
| pytest | Python | `make test` | `borg_core/` — the Python core the CLI dispatches into |
| pytest (viz) | Python | `make test-viz` | `merge-tree/` — the infoviz/PR-hub program |

The full local sweep before opening a PR:

```bash
bats tests/*.bats && make lint && make test && make lint-viz && make test-viz
```

`pyproject.toml` sets `testpaths = ["borg_core"]`, which is why `merge-tree/` needs its own target —
a bare `pytest` will never collect it.

### Makefile targets

Eleven targets, in three families.

**`borg_core/` — the Python core:**

| Target | What it runs |
|--------|--------------|
| `make test` | `coverage run -m pytest` then `coverage report -m --fail-under=90`. A 90% floor. Exit code 5 (no tests collected) is tolerated. |
| `make lint` | `ruff check`, `mypy`, and `pylint` with the `clean_architecture_linter` plugin (falls back to plain pylint if the plugin is not installed). |
| `make format` | `ruff format borg_core/`. |

**`merge-tree/` — the viz program (deliberately separate rules):**

| Target | What it runs |
|--------|--------------|
| `make test-viz` | `coverage run --source=merge-tree -m pytest merge-tree/`, then an 85% floor scoped to the live modules only (`curate`, `render_graph`, `spine`, `gather`, `programs`, `coordinator`). |
| `make lint-viz` | `ruff check merge-tree/`. No mypy, no clean-architecture enforcement. |
| `make format-viz` | `ruff format merge-tree/`. |

The split is intentional and documented at the top of the `Makefile`: `borg_core/` is the zsh→Python
migration target and is held to clean-architecture layering; `merge-tree/` is a renderer program with
a different shape. `render.py` is the legacy renderer, slated for deletion, and sits at 0% by design —
which is why the floor is scoped by `--include` rather than applied to the whole tree.

**Everything else:**

| Target | What it runs |
|--------|--------------|
| `make spine` | `python3 merge-tree/spine.py` — regenerates `story.json`'s skeleton from the latest gather while preserving judgment from the overlay. Safe to run at any time. |
| `make eval` | Runs every `evals/*/run.sh`, forwarding `EVAL_ARGS` (default `--skip-model --skip-network`). **This is the offline one.** |
| `make eval-live` | The same loop with `EVAL_ARGS=` cleared — reaches the network and needs an authenticated `gh`. |
| `make clean` | Removes `dist/`, `build/`, `*.egg-info`, `__pycache__`, `*.pyc`, `.coverage`, `coverage.xml`. |

Two things about `make eval` worth knowing before you touch it. Selecting **zero** harnesses is a
failure, not a no-op — a target whose job is to run the harnesses has failed when it runs none. And
`EVAL_ARGS` is validated word-by-word before it is forwarded: `-h`/`--help` are rejected (they exit
the harness before its floors run, reporting success for a run that verified nothing) and so is any
word containing a shell metacharacter. Pass extra flags as a make variable, never as a bare
dash-word: `make eval EVAL_ARGS=--skip-model`, because make's getopt eats a leading-dash word
anywhere in argv before a goal is built.

### CI lanes

`.github/workflows/test.yml` defines five jobs. They run on push to `main`, on every pull request,
and on a daily schedule (`17 13 * * *` — so `main` going red gets an owner and an email even with no
PR activity).

| Job | Runner | What it does |
|-----|--------|--------------|
| `lint` | ubuntu | `shellcheck hooks/*.sh lib/*.sh evals/*/run.sh`. `.zsh` files are intentionally excluded — shellcheck has no zsh support and `-s bash` gives false safety on exactly the word-splitting class that has bitten this repo. |
| `test` | ubuntu | `bats tests/*.bats` — the full suite. Also installs Python + the dev group, because five `eval_floor.bats` cases must execute `evals/*/run.sh`, whose one always-runnable case is a pytest selection. |
| `python` | ubuntu | `make lint` + `make test` — the exact targets you run locally, so the two cannot drift. |
| `viz` | ubuntu | `make lint-viz` + `make test-viz`. |
| `contract-macos` | macos | `bats tests/cli_contract.bats` only — ~12 tests. |

**The `contract-macos` vs ubuntu distinction is load-bearing.** The ubuntu lane is the *fast* lane:
the whole bats suite, cheap minutes, but structurally incapable of catching zsh-specific or
BSD-userland-specific bugs. `contract-macos` is the *fidelity* lane: it is the only job that executes
`borg.zsh` under a real zsh on a real BSD userland. macOS runner minutes bill at ~10x, so it runs the
contract suite and nothing else.

The corollary matters when you are debugging: the macOS lane is not a weaker check of the same fact,
it is a check of a *different* fact. Several recorded bugs were green on macOS precisely because
macOS is the platform where their false premise holds — a `/bin/sh` that understands bash-isms, a
`gh` that is not in `/usr/bin`, an ambient git identity. See CLAUDE.md's Learned section for the
full case list.

Both bats jobs check out with `fetch-depth: 0`. That is a test premise, not a convenience: a contract
case reads a historical blob with `git show`, and on a depth-1 clone that object does not exist.

`.github/workflows/release.yml` runs on tag push and cuts the GitHub release.

---

## Source tree map

The trees below are real, load-bearing, and appear in no file listing in CLAUDE.md or
[architecture.md](architecture.md). The CLI-side trees (`borg.zsh`, `drone.zsh`, `lib/`, `hooks/`,
`skills/`, `agents/`, `borg_core/`) are already covered there.

### `scripts/` — plugin build and drift guards

This is the **deployment mechanism** for skills and agents, not a convenience wrapper. The canonical
direction is borg-collective (source) → claude-plugins (a read-only distribution copy); never the
reverse. For the deployment model itself — what gets copied where, and why the plugin carries a
curated hook subset — see [architecture.md](architecture.md) and the
[deployment ownership diagram](diagrams/deployment-ownership.html).

| Script | When a contributor runs it |
|--------|----------------------------|
| `build-plugin.sh` | After changing anything under `skills/`, `agents/`, or the shipped hooks. Builds the publishable subset into the plugin repo: skills, a curated set of self-contained hooks, `agents/borg-nanoprobe.md`, regenerated `hooks.json`, a patch version bump in `plugin.json`, and an idempotent `marketplace.json` entry. |
| `sync-plugin.sh` | The narrow case: skills and agents only, no hook regeneration, no version bump. Takes `--dry-run`. Largely subsumed by `build-plugin.sh`. |
| `check-plugin-version.sh` | Asserts `plugin.json`'s version equals `VERSION`. Exits 1 on divergence. Fix by running `build-plugin.sh`. |
| `check-agent-roster.sh` | Asserts every agent `.md` in `agents/` has an identical twin in the distro, and vice-versa, so source edits and distro drift both fail loudly. |

Both `check-*` scripts are designed to be run manually, from CI, or from bats — `tests/agent_roster.bats`
and `tests/plugin_dedup.bats` exercise them.

Note: `build-plugin.sh --dry-run` is known to report the five lib-inlining hooks as changed every
time. That is a false positive; do not record it as real drift.

### `bin/` — host executables

Eight scripts. Four are launchd daemons, one is a developer utility mandated by the project's own
tooling rules, and three are one-shot analysis tools.

| Executable | Purpose |
|------------|---------|
| `run-in` | `run-in <dir> <command> [args...]` — run a command in another directory without a persisting `cd`. Exists because Claude Code's `Bash(cmd:*)` permission wildcard does not match across `&&`, so `cd /path && cmd` prompts and `run-in /path cmd` does not. **The project's bash rules mandate it.** Installed to `~/.claude/bin/run-in` by `borg setup`. |
| `borg-notifyd` | launchd daemon (`com.stillpoint-labs.borg.notifyd`): fires a macOS notification when any project transitions to `waiting`. |
| `borg-cortex-watch` | launchd daemon (`com.stillpoint-labs.borg.cortex-wake`, 30s interval): detects Cortex rate-limit pauses and schedules an auto-wake. One sweep per invocation. |
| `borg-usage-watch` | launchd poller: samples `claude -p "/usage"` and logs observations, with an adaptive cadence. The Usage Guardian's data source. |
| `borg-memory-gate` | Daily launchd job: wraps `memory-hits-report`, evaluates it against the pre-registered threshold, and on a state *transition* delivers the verdict through a channel that interrupts — not just a log line. |
| `memory-hits-report` | Computes reads/session for Claude Code project-memory files against a pre-registered null of `< 0.2 reads/session`. The instrument that replaced cairn's blind spot. |
| `borg-vinculum-watch` | Per-pane live delivery watcher for vinculum pubsub: watches a channel's `log.jsonl` via `fswatch` and delivers past the subscriber's cursor via `tmux send-keys`, rate-capped. See `docs/vinculum.md`. |
| `link-parity-harness` | Differential oracle for the `borg link` zsh→Python port. The `render` leg is **retired** (it now exits 2 with a pointer at the goldens that replaced it); the `primitives` leg is live and still a real differential. |

Every launchd-run script keeps an explicit `PATH` prefix including `$HOME/.local/bin`. launchd hands
jobs a minimal PATH that omits it, so dropping the prefix makes a daemon exit 127 on every fire while
`launchctl list` still shows it registered. `tests/agent_path.bats` pins this.

### `merge-tree/` — the PR control hub

A cross-repo, cross-machine control hub: one self-contained HTML page surfacing every in-flight PR,
issue, and Jira item across all repos, curated into four buckets and paired with a recommended next
action. Eight modules (`coordinator`, `curate`, `gather`, `programs`, `render`, `render_graph`,
`spine`, plus `app/`) with a test module each, and three docs of its own: `README.md` (how to run
it), `PROTOCOL.md`, `SCHEMA.md`.

`data.json` is the source of truth and is **machine-local** — it lives under
`$BORG_MERGE_TREE_DIR` (default `~/.local/state/borg/merge-tree`), never in this repo. Only the
renderer and the protocol are shared code, so every machine runs the same code against its own data.

Gated by `make lint-viz` / `make test-viz` and the `viz` CI job. Note that `render.py` is the legacy
renderer and is excluded from the coverage floor by design.

### `evals/s4-k3/` — the eval harness

One harness (`run.sh`) plus `fixtures/`. It is the landing gate for S4 and the evidence for K3's AC3
("correct chain position for a manifest-declared PR"). Three cases: a deterministic manifest
round-trip via pytest (E2a), live ref resolution on GitHub (E2), and gather integration (E3).

Two design rules the harness enforces, both learned the hard way. **No path is hardcoded and no case
may require a second repository to exist** — `REPO` derives from the script's own location, and
`BORG_EVAL_STILLPOINT`/`BORG_EVAL_TROTH` default to empty so a case whose inputs are absent SKIPs
with a named reason rather than failing. "Not present on this machine" is a different fact from
"wrong". And it deliberately carries **no `set -e`**: the PASS/FAIL counters are a continue-on-error
design so one broken case does not hide the others.

Run it with `make eval` (offline) or `make eval-live` (network). `tests/eval_floor.bats` is the
oracle for its execution floors.

### `desktop/`, `dotfiles/`, `config/cortex/`, `templates/`

| Path | Contents |
|------|----------|
| `desktop/` | `borg-project-instructions.md` — the project instructions pasted into Claude Desktop, whose sessions `lib/desktop.zsh` reads back from `$BORG_DIR/desktop/`. |
| `dotfiles/` | The machine-config surface `install.sh` deploys alongside borg: `claude/`, `devcontainer/`, `ghostty/`, `git/`, `nvim/`, `tmux/`, `zsh/`, plus its own `install.sh`. Config only — functional scripts belong in the repo, not here. |
| `config/cortex/` | `settings.base.json` — the baseline Cortex Code (CoCo) settings applied on setup. See [Devcontainer & CoCo Guide](devcontainer-coco.md). |
| `templates/supabase/` | Scaffold emitted by `drone scaffold --supabase <dir>`: a devcontainer joined to a **per-project** `supabase_network_<project>` plus borg-hooks that start/stop Supabase with the drone. |
| `templates/supabase-shared/` | Scaffold emitted by `drone scaffold --supabase-shared <dir>`: joins the fixed always-on `supabase_network_stillpoint` network instead. `post-down.sh` is a hard no-op — one drone going down must never stop infra other projects share. |

---

## Plan and directive lifecycle

Work in this repo is tracked as markdown plans under `docs/plans/`, moving through five directories:

| Directory | Meaning |
|-----------|---------|
| `directives/` | The backlog. A directive is an accepted, not-yet-shipped unit of work. |
| `handoff/` | Work mid-flight, handed between sessions or agents. |
| `reviews/` | Adversarial review output against a plan. |
| `assimilated/` | Shipped. The decision record — grep here before assuming something is undocumented. |
| `severed/` | Retired without shipping, via `borg sever`. Kept, never deleted. |

`borg start <slug>` picks a directive up and begins work on it. Every project owns its own
`docs/plans/` lifecycle; an orchestrator-side aggregate plan is a smell.

There is a rendered walkthrough of the whole lifecycle at
[docs/diagrams/plan-lifecycle.html](diagrams/plan-lifecycle.html) — open it rather than
reconstructing the state machine from this table.

---

## Conventions

- **Logic goes in a testable core; shell is a wrapper.** New modules ship with tests in the same
  commit.
- **Schema evolution is always expand → migrate → contract.** Add the new form and accept both,
  migrate every existing instance, and only then remove the old form or tighten the validator.
- **Markdown and text wrap at 120 characters.** 4-space indentation everywhere except YAML and Lua.
- **Prior decisions live in `.borg/checkpoints/`, `.borg/knowledge/`, and `docs/plans/assimilated/`.**
  Grep them first.
- **Configuration is environment variables.** Every `BORG_*` name the code reads is catalogued in
  [Environment Variables](environment.md) — including the one rule that has already shipped a dead
  command.
