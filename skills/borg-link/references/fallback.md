## Fallback — direct file reads (the drone-container path)

**Trigger — this is the whole condition. Do not paraphrase it, and do not fall back for any other
reason.**

The probe must re-run the SAME command Step 1 used, including the repository argument if there was
one. `RepositoryNotFound` is only raised when a repository name is passed (in `_focus`,
`borg_core/link/cli.py`); an argument-less overview call can never hit the `not in registry` row, so
a probe that drops the argument makes that row unreachable. If Step 1's failing call was the overview
(no repository), that row simply won't fire for it — that is correct, not a bug.

Run the engine once more as a plain command. Substitute `<repository>` with the same argument (or nothing, for an overview) that Step 1 used:

```bash
borg link --json <repository>
```

The tool result shows the exit status, stdout and stderr; no redirect or capture is needed. Call the exit status `rc` below, and check stderr for `not in registry` or `jq:`.

On `rc=0`, read `.version` from the JSON it printed.

| what you saw                    | what to do                                                              |
| -------------------------------- | ------------------------------------------------------------------------ |
| `rc=0`, `.version == 2`          | CLI path. Never fall back.                                                |
| `rc=0`, `.version > 2`           | CLI path. Note the version skew in one line.                              |
| `rc=0`, `.version < 2` or absent | STOP. borg is older than this skill. Do not fall back.                   |
| `rc != 0`, stderr has `not in registry` | STOP and report it. Do not fall back.                              |
| `rc != 0`, stderr has `jq:`      | Engine may have answered; only the local pipe failed. Re-run Step 1      |
|                                   | WITHOUT the jq pipe. Fall back only if that also fails.                  |
| `rc != 0`, anything else (`command not found` / `rc=127`, a `borg link: ...` line, a traceback) | **FALL BACK.** |

Why each row:

- `not in registry` is the CLI telling you the repository genuinely does not exist
  (`borg link: repository '<name>' not in registry. Run: borg add [path]`). Falling back there would
  hand-roll a page for a repository that isn't real. Report the CLI's message and stop.
- Every other non-zero exit means the engine could not answer — `borg` is not on PATH (the drone
  case), the registry is unreadable, or the CLI crashed. On ALL of these stdout is **zero bytes**:
  never parse partial output, never branch on stderr shape beyond the two substring checks above.
- The condition is about what the engine did, not where you are. Do not try to detect "am I in a
  container" — a broken or absent borg install on the host lands in exactly the same place.

**`has_live_window` is `null` here — never `false`.** Inside a drone there is no tmux server, so
`tmux list-windows` fails exactly the way it fails when a window is merely absent. No-tmux and
no-window are indistinguishable. Therefore: set `has_live_window: null` (unknown) for every
repository, do not run the tmux probe at all, and **apply NO staleness downgrade** — report the
`status` you read from `state.json` / the registry as-is. A fallback that reads unknown liveness
as "no window" marks every active and waiting repository stale; the whole board goes idle and the
reading is worthless.

**Say you are degraded, once, at the top**, carrying the captured error, location-agnostic:
"degraded mode — the borg link engine could not produce a document (<first line of captured
stderr, when non-empty>); statuses are un-reaped and may be stale. Run `borg doctor` to check the
install."

**Where the data is.** Registry at `${XDG_CONFIG_HOME:-$HOME/.config}/borg/registry.json` —
derive the path, never hardcode `~/.config/borg` (`BORG_DIR`, `BORG_REGISTRY` and a non-default
`XDG_CONFIG_HOME` all move it). Per-repository volatile status at `<workspace>/.borg/state.json`,
overlaid on the registry row. Checkpoints at `<workspace>/.borg/checkpoints/*.md`, plan at
`<workspace>/PROJECT_PLAN.md`, directives at `<workspace>/docs/plans/directives/*.md`, assimilated
at `<workspace>/docs/plans/assimilated/*.md`. Test every path with `test -e` before reading and
degrade silently — a missing file is the normal case here, not an error.

**Resolving `<workspace>`.**

1. Walk up from `$PWD` looking for a `.borg-project` marker file with the MARKER-WALK block below. This
   is the ONLY place the marker is read: the engine is gone, so there is no `scope.kind` to believe,
   and the marker stands in for it. If found, read its single line — that's the *current repository
   name* — and the directory containing the marker is the *current workspace*. This works both on the
   host and inside a drone.

<!-- MARKER-WALK-BEGIN -->
```
Bash: dir="$PWD"; while [[ "$dir" != "/" ]]; do
        [[ -f "$dir/.borg-project" ]] && { echo "WORKSPACE=$dir"; echo "PROJECT=$(cat "$dir/.borg-project")"; break; }
        dir=$(dirname "$dir")
      done
```
<!-- MARKER-WALK-END -->

2. For the **current repository**, always use the resolved workspace from step 1 — never the
   registry's `path` field, which may be a host path. Marker found means a repository-scope page: the
   Repository scope rules apply (identity, session and status from `state.json`, the checkpoints in
   `<workspace>/.borg/checkpoints` only, the Queen pointer line, the next action last) and no other
   repository is shown.
3. Marker found: do NOT read other repositories at all; the page is about this workspace alone. The
   registry's `path` for another repository resolves on the host and usually not inside a drone, and
   either way it is out of scope.
4. If no `.borg-project` marker is found (e.g. the Queen session at `~`), there is no current
   repository — fall back to registry paths for everyone, and skip workspace-dependent reads that do not
   resolve (checkpoints, directives, assimilated, PROJECT_PLAN.md), showing the registry row only.

The registry is bind-mounted into every drone **started by `drone up`** (the `borg` compose
profile), not into every container — test for the file, don't assert it.

**What the fallback does NOT do:** no writes of any kind (the registry mount is read-write inside
a drone; `borg reap` on the host is what persists downgrades), no `--brief`, no `--refresh`, no
capacity warning derived by hand, and no attempt to reproduce the CLI's column widths. It answers
the question in prose; it does not imitate `borg link`'s frame.
