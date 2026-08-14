---
name: borg-link
description: >
  Project intelligence — the neural link to the collective. No args = overview of all projects
  with directives and recent ships. With a project name = deep dive with registry, latest
  checkpoint, plan, directives, and assimilated history. Runs the `borg link` engine and
  synthesizes its output; falls back to reading the bind-mounted borg files directly only when
  the engine cannot run. Use when the user asks for status, overview, briefing, "what's going
  on", or project details.
user-invocable: true
---

# Borg Link — Neural Link to the Collective

You are the synthesis layer on top of the `borg link` engine. The engine does the mechanical
read, the sort, the staleness overlay and the rendering; you do the thinking. Explain like the
reader is 10: plain language first, jargon only if it earns its place. Terse. Most-urgent-first.
Hard-wrap all output at 120 characters.

## What this is (one breath)

One `borg link --json` call returns the whole board: every project's live status, how long since
each was touched, what's queued (directives), what shipped (assimilated), and whether you're over
capacity. With a project name the same call also returns a `focus` block for the deep dive. Your
job is to turn that into an answer, not to re-render it.

## Step 1 — Run the engine

Overview:

```bash
bash -c 'set -o pipefail; borg link --json | jq ".directives |=
  (group_by(.project) | map({project: .[0].project, n: length, titles: [limit(5; .[].title)]}))"'
```

Deep dive:

```bash
bash -c 'set -o pipefail; borg link --json <project> | jq "{version, generated_at, capacity, total_projects, focus}"'
```

One call serves both — `borg link --json <project>` returns the full overview document PLUS
`focus`. Never make two calls for a deep dive.

**Why the jq.** Neither pipe enumerates a field, so anything the document gains later passes
through untouched. Overview: collapses the one uncapped array (directives, ~121 items live) from
27,298 bytes raw to ~13,935. Deep dive: drops the 20-project `projects` map, the full `order`, and
the uncapped cross-project arrays the skeleton never reads, from 31,136 bytes raw to ~4,661 — an
85% cut. If `jq` is missing, drop the pipe and read the raw document.

**Mode selection.** To decide the mode, run the MARKER-WALK block below — it is the only
pre-approved way to detect the current project; do not write an ad hoc find/ls command. Marker
found + no argument → deep dive on that project. No marker + no argument → overview. An explicit
project name → deep dive regardless of CWD.

<!-- MARKER-WALK-BEGIN -->
```
Bash: dir="$PWD"; while [[ "$dir" != "/" ]]; do
        [[ -f "$dir/.borg-project" ]] && { echo "WORKSPACE=$dir"; echo "PROJECT=$(cat "$dir/.borg-project")"; break; }
        dir=$(dirname "$dir")
      done
```
<!-- MARKER-WALK-END -->

**Version gate — read `.version` first.**
- `== 2` → proceed silently.
- `> 2` → proceed, but say in one line that this skill was written against v2 and newer fields
  may go unreported.
- `< 2` or absent → STOP. Tell the user their borg install is older than this skill
  (`total_projects` is missing, so the empty-registry vs all-archived branch cannot be rendered
  correctly). Do NOT fall back on a version mismatch.

**Flags that are NOT in the JSON path.** `--brief` (LLM narrative) and `--refresh` (regenerate
summaries) are still zsh and host-only. If the user asks for either, tell them to run
`borg link --brief` / `borg link --refresh` from the host — do not attempt them yourself.

**`--all`.** `borg link --json --all` includes archived projects. Needed only when the user asks
*which* projects are archived; the count alone is `total_projects - (.order | length)`.

If the Step 1 command fails, go to `## Fallback` below — the trigger lives there, verbatim.

## Step 2 — Reconcile (add judgment to the mechanical pass)

The engine already sorted, already applied the staleness overlay, already counted capacity. Go
one level deeper:

- **Capacity is a finding, not a field.** `capacity.over_limit` true → lead with it and name which
  projects are eating the budget (the `waiting` and `active` rows, in `.order`).
- **Contradiction check on the deep dive.** Compare `focus.checkpoint_head` and
  `focus.plan.objective` against `focus.entry.status` / `focus.entry.relative_activity`. When a
  checkpoint claims in-flight work on a project that `relative_activity` shows has gone idle, name
  the disagreement plainly and recommend the fix, the way `/borg-recon` does. Use judgment on
  `relative_activity` — there is no fixed day threshold in the data.
- **Empty summaries are the normal case, not an error.** `summary` is null on nearly every project
  until someone runs `--refresh`. Degrade in this order: `summary` → `waiting_reason` →
  `relative_activity` → `focus.checkpoint_head`. Never print "(no summary)" for a whole column; if
  the board has no summaries, say so once and suggest `borg link --refresh` on the host.
- **Collapse, don't transcribe.** 121 directives across 9 projects is a number plus the top few
  titles, not a list.

## Step 3 — Synthesize

Overview skeleton:

```
## The collective — <N> projects, <A> need attention   (limit <L>)   ← the capacity line, only if it bites
### ● <project>  [<status>]  · <relative_activity>
<one plain-language line: what this project is mid-way through, from summary/waiting_reason/checkpoint>
Queued: <n> directives (top: <title>, <title>)          ← omit the line when n is 0
> <contradiction or capacity note>                       ← only when this project has one
...
Recently shipped: <title> (<project>, <ship_date>)       ← the global newest-3, one line each
Hidden: <total_projects - (order|length)> archived — run `borg link --all` to see them.   ← omit when 0
```

Deep-dive skeleton:

```
## <project>  ·  <status>  ·  <relative_activity>
<two lines, plain language: where this project actually is right now>
Plan: <focus.plan.objective>  —  <met>/<total> criteria met     ← omit the whole line when plan is null
Latest checkpoint (<focus.checkpoints[0]>): <the 2-3 things that matter from checkpoint_head>
Queued: <n> directives — <up to 5 titles>
Shipped recently: <title> (<ship_date>)
> <contradiction between the checkpoint's claims and the live status>
```

Sort by `.order` and nothing else. If `.order` is empty and `total_projects` is 0, say "No
projects registered — run `borg scan`." and stop. If `.order` is empty and `total_projects > 0`,
say "All <N> projects are archived — run `borg link --all`." and stop. Those are two different
sentences and getting them backwards is the known trap.

## Fallback — direct file reads (the drone-container path)

**Trigger — this is the whole condition. Do not paraphrase it, and do not fall back for any other
reason.**

Capture every branch input in one call (no `$()`, per repo rule):

```bash
bash -c 'borg link --json >/tmp/borg-link.out 2>/tmp/borg-link.err
echo "rc=$?"
wc -c </tmp/borg-link.out
grep -c "not in registry" /tmp/borg-link.err
head -3 /tmp/borg-link.err'
```

On `rc=0`, read `.version` from `/tmp/borg-link.out` with `jq .version /tmp/borg-link.out`.

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

- `not in registry` is the CLI telling you the project genuinely does not exist
  (`borg link: project '<name>' not in registry. Run: borg add [path]`). Falling back there would
  hand-roll a page for a project that isn't real. Report the CLI's message and stop.
- Every other non-zero exit means the engine could not answer — `borg` is not on PATH (the drone
  case), the registry is unreadable, or the CLI crashed. On ALL of these stdout is **zero bytes**:
  never parse partial output, never branch on stderr shape beyond the two substring checks above.
- The condition is about what the engine did, not where you are. Do not try to detect "am I in a
  container" — a broken or absent borg install on the host lands in exactly the same place.

**`has_live_window` is `null` here — never `false`.** Inside a drone there is no tmux server, so
`tmux list-windows` fails exactly the way it fails when a window is merely absent. No-tmux and
no-window are indistinguishable. Therefore: set `has_live_window: null` (unknown) for every
project, do not run the tmux probe at all, and **apply NO staleness downgrade** — report the
`status` you read from `state.json` / the registry as-is. A fallback that reads unknown liveness
as "no window" marks every active and waiting project stale; the whole board goes idle and the
reading is worthless.

**Say you are degraded, once, at the top**, carrying the captured error, location-agnostic:
"degraded mode — the borg link engine could not produce a document (<first line of captured
stderr, when non-empty>); statuses are un-reaped and may be stale. Run `borg doctor` to check the
install."

**Where the data is.** Registry at `${XDG_CONFIG_HOME:-$HOME/.config}/borg/registry.json` —
derive the path, never hardcode `~/.config/borg` (`BORG_DIR`, `BORG_REGISTRY` and a non-default
`XDG_CONFIG_HOME` all move it). Per-project volatile status at `<workspace>/.borg/state.json`,
overlaid on the registry row. Checkpoints at `<workspace>/.borg/checkpoints/*.md`, plan at
`<workspace>/PROJECT_PLAN.md`, directives at `<workspace>/docs/plans/directives/*.md`, assimilated
at `<workspace>/docs/plans/assimilated/*.md`. Test every path with `test -e` before reading and
degrade silently — a missing file is the normal case here, not an error.

**Resolving `<workspace>`.**

1. Walk up from `$PWD` looking for a `.borg-project` marker file (the MARKER-WALK block above).
   If found, read its single line — that's the *current project name* — and the directory
   containing the marker is the *current workspace*. This works both on the host and inside a
   drone.
2. For the **current project**, always use the resolved workspace from step 1 — never the
   registry's `path` field, which may be a host path.
3. For **other projects**, use the registry's `path` field. On the host it resolves; inside a
   drone it usually doesn't, and that's fine — skip workspace-dependent reads (checkpoints,
   directives, assimilated, PROJECT_PLAN.md) and show only the registry row for those projects.
4. If no `.borg-project` marker is found (e.g. orchestrator session at `~`), there is no current
   project — fall back to registry paths for everyone.

The registry is bind-mounted into every drone **started by `drone up`** (the `borg` compose
profile), not into every container — test for the file, don't assert it.

**What the fallback does NOT do:** no writes of any kind (the registry mount is read-write inside
a drone; `borg reap` on the host is what persists downgrades), no `--brief`, no `--refresh`, no
capacity warning derived by hand, and no attempt to reproduce the CLI's column widths. It answers
the question in prose; it does not imitate `borg link`'s frame.

## Guardrails

- Read `.order` for display order. Never derive order from `.projects`' keys — jq's `keys` sorts
  alphabetically and would silently reorder the board.
- Never branch "no projects" off `(.order | length)`. `total_projects` is the unfiltered count; an
  all-archived registry emits `order: []` with a non-zero `total_projects`.
- `pinned` and `display_name` are OPTIONAL ABSENT keys, not null-valued ones. Treat missing as
  absent.
- An empty `.order` with exit 0 is a SUCCESS, not a failure. Never fall back on it.
- No raw dumps. Every line is a synthesized takeaway. Never paste the JSON, and never re-render
  the CLI's table — if the user wants the table, they should run `borg link`.
- Read-only in spirit: this skill never writes `registry.json` or any `state.json`. Note the one
  unavoidable exception: `borg link --json` with no project runs the CLI's Claude Desktop
  pre-pass, which merges into the registry — that is the CLI's normal behavior, not something to
  work around.
- One `borg link --json <project>` call is both the overview and the deep dive. Do not call
  twice.
