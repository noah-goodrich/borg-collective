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
