# The reader census

Every `.borg/<name>` store referred to by executable code (`borg_core/`, `lib/`, `hooks/`, `bin/`,
`merge-tree/`, root `*.zsh`) or by a surface that makes promises to an agent (`CLAUDE.md`, and every
markdown file under `skills/` and `agents/`) must appear here and must name a reader.

**The agent-facing surfaces are in scope because of a real miss.** The first version of this gate
read `CLAUDE.md` alone, and `agents/borg-nanoprobe.md` was at that moment telling every nanoprobe to
treat `.borg/knowledge/` markdown as *"authoritative prior art"* — a live promise, stronger than the
one being retired from `CLAUDE.md` in the very same change, and completely invisible. A gate that
reads one rules file while agents and skills carry their own retires a promise in one place and
leaves it in two others. The gate is `python3 -m borg_core.census.cli`, run by `tests/state_census.bats`.

## Why this file exists

Ten of sixteen `.borg/` subdirectory names in this tree had no code reader. One of them,
`.borg/knowledge/`, is the decommissioned cairn service's own export, and `CLAUDE.md`'s Architecture
Rules still told every agent to grep it for prior decisions two months after the teardown.

Two independent measurements say what that is worth. Cairn — Postgres with pgvector — was retired
after measuring 0.4% cross-project restatement. Auto-memory — markdown on a filesystem — currently
reads 0.129 reads/session against a pre-registered 0.2 bar. Same failure, opposite engines: **a
store nothing reads is a write-only store, whatever it is built on.** So the gate is not about
storage. It is about whether anything is obliged to read what we write.

## The three states

| state | meaning | verdict |
| --- | --- | --- |
| referenced by code, no reader | something writes it and nothing consumes it | **FAIL** |
| named in `CLAUDE.md`, no reader | a false promise to every agent that reads the rules | **FAIL** |
| on disk only — no writer, no reader, named nowhere | inert historical data | **PASS** |

The third state needs no row and no machinery: a name referenced nowhere is never discovered. That
is deliberate, and it is what `.borg/knowledge/` becomes once the instruction to grep it is gone —
its 1106 tracked files stay exactly where they are, and the gate stops caring, because nothing
promises anything about them any more. Retiring a store means deleting the *promise*, not the data.

## What the gate proves, and what it does not

It proves every referenced store names a reader, that the named file exists, and that the file
actually mentions the store. So a new store cannot land without someone writing down where it is
read, and a reader cannot be renamed or deleted without the declaration going stale and failing.

It does **not** prove the named reader performs a read rather than a write. Telling those apart
mechanically across zsh, bash and Python is not tractable, and a gate that claimed to would be the
kind of overclaim this repo has paid for more than once. This is a ratchet, not a proof.

## The census

`kind` is `store` when the reader contains the literal token; `dynamic` when the reader builds the
path from a variable or constant, so no literal exists to match and the mention check is waived
explicitly; or `prose` for a token that only ever appears inside an explanation and names nothing on
disk; or `retired` for a store whose name now survives only in a note explaining that it was
retired. A `retired` row is an escape hatch and is named as one: the gate cannot tell a historical
note from a live instruction, so nothing stops a future edit from marking a real promise `retired`
to silence a failure. What the row buys is that doing so is a deliberate line in a reviewed file
rather than a silent omission, and its note must point at the argument. A `dynamic` row must still name its reader and say in the note where the path is built — the
alternative was pointing the reader column at whatever file happens to hold the literal, which here
would be a *test* file, and naming a test as a store's reader to satisfy a gate is exactly the
wallpapering this census exists to prevent.

| store | kind | reader | note |
| --- | --- | --- | --- |
| `.borg/checkpoints` | store | `borg_core/link/shell.py` | union-read across a repo group; also `hooks/borg-link-down.sh` |
| `.borg/state` | store | `lib/registry.zsh` | `state.json`; also read by three hooks and `borg_core/link/shell.py` |
| `.borg/chains` | dynamic | `borg_core/manifest/shell.py` | path joined from `CHAINS_DIRNAME`, never a literal |
| `.borg/programs` | dynamic | `borg_core/manifest/shell.py` | pre-rename spelling, joined from `LEGACY_DIRNAME` |
| `.borg/skill-extensions` | dynamic | `borg_core/extensions/shell.py` | `layer_paths` joins `.borg / kind`, so no literal exists |
| `.borg/agent-extensions` | dynamic | `borg_core/extensions/shell.py` | same `layer_paths` join, agent side |
| `.borg/skills` | store | `hooks/borg-link-up.sh` | project-local skills; also `hooks/borg-link-down.sh` |
| `.borg/knowledge` | retired | - | cairn's export, 1106 tracked files KEPT; the promise to grep it was deleted from CLAUDE.md 2026-09-28. See `docs/plans/directives/assets/2026-09-28-state-audit-adversarial.md` |
| `.borg/elsewhere` | prose | - | not a store: a path in `merge-tree/test_coordinator.py`'s fixture for a manifest OUTSIDE the manifest dir |
| `.borg/anything` | prose | - | not a store: a docstring example in `borg_core/manifest/shell.py` naming a path that is never opened |

## Where each file under the config dir lives (AC4)

The census above lists what READS a store. This one lists WHERE each file under
`${XDG_CONFIG_HOME:-~/.config}/borg` lives after AC4 A2b. The rule: a file a human edits, or one that is
configuration in the strict sense, stays config-side; a file only borg writes and nobody hand-edits is machine-local
operational state and lives under the state root, `${XDG_STATE_HOME:-~/.local/state}/borg`. The move shipped as
expand → migrate → contract: readers accept both locations (the state root wins when both exist) before any writer
moved, and a pre-move history is carried across on the first write, so nothing is stranded.

The explicit environment overrides (`BORG_CORTEX_STATE`, `BORG_MEMORY_GATE_VERDICT_FILE` and their siblings) still win
over both locations; the table describes only the defaults.

| file (relative to the config dir) | where | why |
| --- | --- | --- |
| `cortex-wakes.json` | MOVED | written only by `borg-cortex-watch`; nobody hand-edits it |
| `memory-gate-state.json` | MOVED | `borg-memory-gate`'s last-delivered transition record |
| `memory-gate-verdict.json` | MOVED | written and cleared by `borg-memory-gate`; `borg-link-down.sh` reads both |
| `usage-guardian.json` | MOVED | `borg-usage-watch` sweep state |
| `pr-watch-snapshot.json` | MOVED | `borg-pr-watch` machine-written snapshot |
| `pr-watch-delta.md` | MOVED | `borg-pr-watch` output, regenerated every run |
| `pr-watch.log` | MOVED | a log; logs are never configuration |
| `recon/last-run` | MOVED | the recon since-mark marker, machine-written |
| `devcontainer-hashes/<project>.hash` | MOVED | `drone` change-detection cache, safe to delete |
| `briefing-*-stderr.log` (4 files) | MOVED | captured stderr of the `--brief` stages; diagnostics only |
| `plan-promote-debug.log` | MOVED | debug log of `borg-plan-promote.sh` |
| `memory-hits.log` | MOVED | append-only read log of `borg-memory-read-log.sh` |
| `agents.jsonl` | MOVED | nanoprobe lifecycle log from `borg-nanoprobe-log.sh` |
| `prefer-tool.jsonl` | MOVED | bypass log of `borg-prefer-tool-log.sh` |
| `registry.json`, `.registry.lock` | STAYS | hand-edited AND operational; readers use `BORG_REGISTRY`, no gain moving |
| `config.zsh` | STAYS | hand-edited configuration (capacity limits, boundaries) |
| `extensions/**` | STAYS | the user's own prose and adapters; the machine layer of extension precedence |
| `claude-settings.local.json` | STAYS | hand-edited permission exceptions (`break-glass`) |
| `cortex-settings.local.json` | STAYS | hand-edited, the Cortex Code twin of the above |
| `launchd-prefix` | STAYS | human-edited; the one file that brands every LaunchAgent on the machine |
| `desktop/*.json` | STAYS | an inbox Claude Desktop writes; borg only reads it, so it is not ours to relocate |
| `.cairn-last-write`, `cairn-hits.log` | STAYS | cairn leftovers, retired by `borg tidy --cairn-leftovers` (PR #244) |

### The third location

`${XDG_DATA_HOME:-~/.local/share}/borg` holds the launchd stdout/stderr logs (`cortex-wake.log` and friends, written by
the agents `install.sh` loads) and `vinculum/`. This change does not touch it. It is a candidate to fold into the state
root later: XDG places logs under state, and two machine-local roots beside the config dir is one more than the
reader needs to know about. It is deferred because the log paths are baked into the installed plists at `install.sh`
time, so moving them means a reinstall and a bootout/bootstrap of every agent, a different blast radius from this
change, which only moved files that borg itself opens at run time.
