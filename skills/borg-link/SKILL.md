---
name: borg-link
description: >
  Project intelligence — the neural link to the collective. Scope decides the page. In the Queen
  session (the orchestrator, at BORG_ORCHESTRATOR_ROOT) it is the cross-repository overview with
  directives and recent ships. Anywhere else (a repository or a linked worktree, or an explicit
  project name) it is a page about exactly that one directory: identity, live session and status,
  its own latest checkpoint, its own waiting row and its next action. Runs the `borg link`
  engine and synthesizes its output; falls back to reading the bind-mounted borg files directly
  only when the engine cannot run. Use when the user asks for status, overview, briefing,
  "what's going on", or project details.
user-invocable: true
---

# Borg Link — Neural Link to the Collective

You are the synthesis layer on top of the `borg link` engine. The engine does the mechanical
read, the sort, the staleness overlay and the rendering; you do the thinking. Explain like the
reader is 10: plain language first, jargon only if it earns its place. Terse. Most-urgent-first.
Do not hard-wrap output; the terminal soft-wraps.

## What this is (one breath)

One `borg link --json` call returns the whole board: every project's live status, how long since each was touched, what's queued (directives), what shipped (assimilated), and whether you're over capacity. **Scope decides which part of it you present**, and `scope.kind` is the engine's answer, not yours: in the Queen session (`scope.kind == "orchestrator"`, the session at `BORG_ORCHESTRATOR_ROOT`) you give the cross-repository overview, the Queen view. Anywhere else (`scope.kind == "repository"`: a repository, a linked worktree registered on its own, or an explicit project name) you give a page about exactly that one directory and nothing else. Your job is to turn the document into an answer, not to re-render it.

Vocabulary: a *repository* is the git repo; a *worktree* is a linked checkout registered on its own, and each carries a project. "Queen" is the user-facing name for the orchestrator session; the contract names (`scope.kind` value `orchestrator`, `BORG_ORCHESTRATOR_ROOT`, every `--json` key) are unchanged.

## Step 1 — Run the engine, then branch on `scope.kind`

ONE call serves every scope. Run it once, with the project name appended only when the user gave one:

```bash
bash -c 'set -o pipefail; borg link --json [<project>] | jq "if .scope.unregistered == true
  then {version, generated_at, scope}
  elif .scope.kind == \"orchestrator\"
  then (.directives |= (group_by(.project) | map({project: .[0].project, n: length,
    titles: [limit(5; .[].title)]})))
  else (.scope.repository as \$r | {version, generated_at, scope,
    entry: (.focus.entry | del(.summary)),
    waiting: {rows: [.waiting.rows[] | select(.project == \$r and .item == \"session\")],
      degraded: .waiting.degraded}})
  end"'
```

Then branch, and only on this:

- `.scope.unregistered == true` → the **hint page**: the directory is neither the Queen root nor inside any registered path (the engine's own page for it says so and offers two commands). Say in two short lines that this directory is not a registered repository, that `borg add` registers it, and that `borg link --overview` (or `/borg-link` in the Queen session) gives the Queen view. Do not render the board, and do not present the overview in its place. Nothing else follows.
- `.scope.kind == "orchestrator"` → the **Queen view**. Follow `## Queen view` below.
- `.scope.kind == "repository"` → the **repository page**. Follow `## Repository scope` below. Stop reading the Queen view sections; they do not apply.

**The `.borg-project` marker is NOT the mode decision.** It never was a reliable one: linked worktrees never get a marker, so a marker walk sent them into the overview. The engine resolves scope from the cwd (or from an explicit project name, which wins), and you believe it. The marker is read only in the `## Fallback`, where the engine cannot run. Do not write an ad hoc find/ls to detect the project.

The repository-scope arm of the jq is a whitelist on purpose. `--json` stays registry-wide on every call (`order`, `projects`, `directives`, `assimilated`, `grid`), and `focus` carries a plan and directives, which are repository-level. Its checkpoint list, head and `entry.summary` were read across the whole repo group until 2026-10-13 and are now the directory's own, but an older engine still sends the union. The repository page reads its own directory itself and may use none of that, so the pipe never lets it reach you.

**Version gate — read `.version` first.**
- `== 2` → proceed silently.
- `> 2` → proceed, but say in one line that this skill was written against v2 and newer fields
  may go unreported.
- `< 2` or absent → STOP. Tell the user their borg install is older than this skill
  (`total_projects` is missing, so the empty-registry vs all-archived branch cannot be rendered
  correctly). Do NOT fall back on a version mismatch.

**Flags that are still host-only.** `--refresh` (regenerate summaries) is zsh. `--brief` is now a
presentation mode of THIS SAME DOCUMENT — it makes the same `--json` call, hands the result to
`claude -p` for a narrative, and re-renders the document when that fails — but the `claude -p` half
keeps it host-only. If the user asks for either, tell them to run `borg link --brief` /
`borg link --refresh` from the host. You already have the document; you never need `--brief` to
narrate it.

**`--all`.** `borg link --json --all` includes archived projects. Needed only when the user asks
*which* projects are archived; the count alone is `total_projects - (.order | length)`.

If the Step 1 command fails, go to `## Fallback` below — the trigger lives there, verbatim.

## Queen view (`scope.kind == "orchestrator"` only)

Everything from here to `## Repository scope` is the cross-repository overview. It is for the Queen session and for nothing else: never use it to render a repository or a worktree.

**`grid` is the sweep's product, and the Queen view reads it.** `borg link --json` sweeps its sources
for live PR state — that is what the call costs, and ignoring the only key the sweep produces would
mean paying for a network round trip and then rendering the same overview as before it existed. Read it:

- `.grid.warnings` is a plain list of sentences. If it is non-empty, say so in one line before the
  briefing (e.g. "the GitHub sweep did not run: <first warning>"), then carry on with what the
  manifest declares. Never render the grid as a table; AC2 owns the rendering.
- `.grid.sources[].status` is `ok`, `degraded` or `failed`. `degraded` means a source was never
  actually reached (missing/unauthenticated `gh`, offline, rate-limited) or had its items rejected —
  treat the states below it as declared, not observed.
- `.grid.unresolved` out of `.grid.declared` is how many refs NOBODY answered for — neither the
  sweep nor the targeted fetch. A high ratio is not an error; those states came from the manifest.
- `.grid.fetch` covers AC3's targeted fetch: `.attempted` (bool, whether a fetch was even tried),
  `.status` (`ok`, `degraded`, `failed`, or `skipped`), `.requested` (refs asked about) and
  `.resolved` (refs that came back with a usable answer). As with `.grid.sources[].status`,
  `failed` and `degraded` mean the states below them are DECLARED rather than OBSERVED — treat
  them the same way.
- `.grid.picture_width` is the widest `▸ CHAINS` picture row this document would draw, in VISIBLE
  columns (SGR and OSC-8 bytes excluded). Compare it to `PICTURE_BUDGET` (68). Over budget means the
  topology will wrap in a narrow pane and should be reported as a manifest problem — a ref is long
  or a level is too wide — not as a rendering bug. The human page says the same thing in
  `▸ SIGNALS`; this is the machine-readable half, so you never have to measure ANSI output.
- `.grid.manifests` is an **array** of manifest blocks, each carrying `id` (the manifest's slug),
  `path`, `desc`, `repos`, `levels`, `nodes` and `gates`. AC2 added `desc`, `repos`, and three
  topology keys per node:
  - `desc` is the manifest author's own one-line statement of what the whole project is for. Prefer
    it over inventing a summary out of row titles — it is their sentence, not yours.
  - `repos` is the sorted, deduplicated `owner/repo` list the manifest's **rows** name — the work,
    not everything it merely references (an apex or an `after:` pointer contributes nothing). Two or
    more entries means the project spans repositories, which is usually the single most useful fact
    about it and belongs in the one-line summary.
  - `.nodes` is an **object keyed by ref**, not an array. Alongside `state`/`state_source`/`lane`/
    `next`/`gate` each node now carries `level` (topological rank), `seq` (declaration order — the
    row's index as the author wrote it; a declared ref that is not a row sorts past every real one),
    and `parents`/`children` (ordering edges only, both endpoints inside the declared set, sorted by
    `(seq, ref)`).
  - **Use the topology for judgment, not for drawing, and never for readiness.** `parents`/
    `children` tell you the shape — what a row waits on, what waits on it, whether the project is
    one chain or a fork. They do NOT tell you what is ready to start: `state_source` is `declared`
    (a hand-typed `"status"` field nobody verified) at least as often as it is swept or fetched, so
    "every parent merged" can rest entirely on prose. Report what the manifest declares and name the
    provenance. **Never derive readiness yourself from `parents`/`children`** — read `.ready`, two
    bullets down, which AC4 put on the wire for exactly this reason and which already applies the
    provenance gate. (This used to read "`ready` is deliberately absent from the wire … do not
    reconstruct it". That was true until AC4 shipped `ready`, and because it is phrased as a
    PROHIBITION an agent reading top-down suppressed the entire `.ready` answer before reaching the
    bullet that documents it.)
  - Still never render a picture. `borg link` draws it, and the `n1`-style handles it prints are
    generated at render time — they are not on the wire, so there is nothing to echo.
- **`.ready` is AC4's answer to "what can I pick up right now", and it is THREE-STATE.** Each manifest
  block carries `{state: "known"|"unlooked", refs: [...]}`, and each node carries a matching `ready`
  boolean plus a `draft` boolean.
  - `state: "unlooked"` means **nothing on the page was resolved** — not that nothing is ready. It is
    what every `--local` render returns. Say "nobody looked", never "nothing is ready"; the two are
    different facts and `.grid.unresolved` will agree with you.
  - `state: "known"` with an empty `refs` genuinely means nothing is startable right now.
  - A ref in `refs` is open, every parent has merged, **and every one of those states was swept or
    fetched** — a declared state can never put a ref here, which is the whole reason AC4 shipped a
    provenance gate first. `draft` rows are excluded: a draft PR is `open` but not startable.
- **Routing, when the user asks what's theirs.** Read `gates[].kind` off the same manifest block:
  `decision` → **theirs** (a person must decide), `verification` → **the agent's** (anyone can run
  it), **ungated → the agent's** (nothing is blocking it). Any other kind is deliberately *neither* —
  report it as unrouted rather than guessing, and name the kind. Do not invent a fourth rule, and do
  not treat `rows[].next` as membership: it is the author's emphasis for ordering among rows that are
  already ready, never a reason to include one that isn't.
- **WAITING ON YOU is the board's last block, and you surface it too (inside Claude first).** It reads
  the top-level `.waiting` key, which is `borg next`'s own YOU rows (decided 2026-10-09: link and next
  share one router for "what's mine"). `.waiting.rows[]` are the rows the chooser shows (at most 5, each
  `{project, item, next_step, owner:"YOU", ref, age, waiting_reason}`); `.waiting.hidden_lines` is the
  chooser's own `+N more decisions` / `+N agent tasks` / `+N stale drafts` text; `.waiting.degraded` is a
  note when the sweep or rows failed (say it once). Under `--local` there is no sweep, so no PR rows. Then
  add every `yours` manifest decision (the `gates[].kind == "decision"` routing above) whose ref is not
  already a row. Print the block LAST, one line per item: the project, the `next_step`, the `item`, and
  `unblocks N` (`len(.nodes[ref].children)`) for manifest items; then the `hidden_lines` verbatim. No age
  invention. **It is ALWAYS present**: with no rows and every manifest `known`, print the single line
  `nothing waits on you`; if a manifest with refs is `unlooked` and nothing else qualified, say "nobody
  looked" instead. `.waiting` is ADDITIVE (absent in `--porcelain`), so `DOCUMENT_VERSION` stays 2.

**Why the jq.** The Queen arm (`.directives |= (...)`) does not enumerate a field — it transforms one
key in place, so anything the document gains later passes through untouched. It collapses the one
uncapped array (directives, ~121 items live) from 27,298 bytes raw to ~13,935. The repository arm is
the opposite: an explicit whitelist, and a field the document gains later is invisible until it is
added there. That is the point of it — it keeps registry-wide data off a page that must be about one
directory. If `jq` is missing, drop the pipe and read the raw document, and still render only what the
scope allows.

### Queen view — reconcile (add judgment to the mechanical pass)

The engine already sorted, already applied the staleness overlay, already counted capacity. Go
one level deeper:

- **Capacity is a finding, not a field.** `capacity.over_limit` true → lead with it and name which
  projects are eating the budget (the `waiting` and `active` rows, in `.order`).
- **Empty summaries are the normal case, not an error.** `summary` comes from the project's latest
  checkpoint (its tl;dr, else the first Accomplished bullet), so it is null only when the project has
  no checkpoint. Degrade in this order: `summary` → `waiting_reason` →
  `relative_activity` → `focus.checkpoint_head`. Never print "(no summary)" for a whole column; if
  the board has no summaries, say so once and suggest `/borg-link-up` in those projects to write a checkpoint; `--refresh` no longer fills `summary`.
- **Collapse, don't transcribe.** 121 directives across 9 projects is a number plus the top few
  titles, not a list.
- **`scope` decides the page; it does not filter the document.** `{kind: repository|orchestrator,
  repository, local}` records which repository the invocation resolved to. In the Queen view
  `scope.kind` is `orchestrator`, so `order` and `projects` are the whole board and that is what you
  present. `order` and `projects` stay registry-wide on EVERY `--json` call, in both scopes, so never
  present scope as a filter applied to them, and never carry them onto the repository page — that
  page reads a whitelist for exactly this reason.

### Queen view — synthesize

Skeleton:

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

The skeleton ENDS with the WAITING ON YOU block described above (see the `.ready` bullets). It is the
last thing the user reads.

Sort by `.order` and nothing else. If `.order` is empty and `total_projects` is 0, say "No
projects registered — run `borg scan`." and stop. If `.order` is empty and `total_projects > 0`,
say "All <N> projects are archived — run `borg link --all`." and stop. Those are two different
sentences and getting them backwards is the known trap.

## Repository scope (`scope.kind == "repository"`)

This page is about exactly ONE directory: `.entry.path`, the directory the engine resolved. It is the directory of a repository or of a linked worktree registered on its own (borg-probes is a worktree of borg-collective; each carries its own project). Say what is true of THIS directory and stop.

**Never render, even though `--json` carries it:** the registry-wide board (`order`, `projects`, capacity, other projects), any other worktree or repository, and every repo-level section: plan, QUEUED/SHIPPED (`directives`, `assimilated`), chains and the `grid`, repository PRs. The Step 1 pipe already withheld them; if you ran without the pipe, ignore them anyway. A page that blends the repository's other checkouts into this directory's page is the exact defect this scope exists to prevent.

**Read in this order, then write the page.**

1. **Identity.** `.entry.path` plus branch and worktree relationship, from git on that path (one call):

```bash
bash -c 'git -C "<entry.path>" rev-parse --abbrev-ref HEAD; git -C "<entry.path>" rev-parse --path-format=absolute --git-dir --git-common-dir; git -C "<entry.path>" rev-parse --short HEAD'
```

The first line is the branch; when it is `HEAD` the checkout is detached, so write `detached at <short sha>` using the fourth line (the short sha) instead of a branch name. The two paths on the next two lines are equal for a main checkout; when they differ this directory is a linked worktree, and the worktree-of path is the common dir without its trailing `/.git` (`.entry.repo` is the same common dir as the registry recorded it). If git fails (the path is missing or not a repository), print the path and say identity is unavailable. Do not look the parent up in the registry.

2. **Session and status**, all from `.entry`: `status`, `relative_activity`, `waiting_reason` when present, `has_uncommitted_changes`, `has_live_window` when present (null or absent means unknown, not false), and `tmux_window`. One or two plain lines.

3. **This directory's own checkpoints, read by you from `<entry.path>/.borg/checkpoints` and from nowhere else.** An older engine's `focus.checkpoints`, `focus.checkpoint_head` and `entry.summary` are read across every checkout of the repository, so they describe other worktrees too; the pipe drops them either way and you must not reconstruct them. List the directory, newest filename first (a NAME sort, the same as the engine's):

```bash
bash -c 'ls -1 "<entry.path>/.borg/checkpoints" 2>/dev/null | grep "[.]md$" | sort -r | head -3'
```

Read the newest file with the Read tool at `<entry.path>/.borg/checkpoints/<newest>`. The summary is its tl;dr, else its first Accomplished bullet; give the 2-3 things that matter. The "recent" line is the up-to-3 names from the listing. An empty listing or a missing directory is the normal case for a fresh worktree: say "no checkpoint here yet" and suggest `/borg-link-up` in this directory. Never fall back to a checkpoint from another directory.

4. **This directory's waiting row**, from `.waiting.rows`. The engine labels EVERY waiting row with this directory's project name, including the repository's open-PR rows (`merge #N`, `fix #N CI`), which belong to the whole repository and show up identically on every worktree page. The pipe therefore kept only the directory's own session row (`item` is `session`, `ref` null). If you ran without the pipe, keep only that row and drop every row with a `ref`. Print it as the `next_step`, the `item` and `age`. `.waiting.degraded` is a note when the sweep failed; say it once. Add nothing else to the block: no PR rows, no manifest decisions, no `hidden_lines`, no other project's rows. With no session row print `nothing waits on you here`.

5. **Next action, one line.** The session row's `next_step`; else, when `status` is `waiting`, the `waiting_reason`; else the newest checkpoint's own next-steps line; else "nothing pending here". If the checkpoint claims in-flight work but `relative_activity` shows this directory has gone idle, name that disagreement in the same line and recommend the fix, the way `/borg-recon` does. Use judgment on `relative_activity` — there is no fixed day threshold in the data.

**Skeleton:**

```
## <entry.path>  ·  <status>  ·  <relative_activity>
Branch <branch>  ·  worktree of <worktree-of path>   ← "main checkout" when the two git paths are equal; "detached at <short sha>" when detached
<one or two lines: the live session, uncommitted changes, waiting_reason>
Checkpoint (<newest filename>): <the 2-3 things that matter>
Recent: <up to 3 filenames>                            ← omit when there are none
For the overview of every repository, run /borg-link in the Queen session.
Waiting: <next_step> — <item> (<age>)                  ← or `nothing waits on you here`
Next: <one line>
```

The ORDER is the engine's own page order, not a choice: identity, session and checkpoints first, then the Queen pointer, then the waiting row, and the page ENDS on the `Next:` line (link-unification L3: the answer is the last thing the eye lands on). The pointer line is verbatim and appears exactly once, BEFORE the waiting row; nothing follows the `Next:` line. One scope, one pointer: do not add a second one, a menu, or a count of other worktrees. The Version gate, `--refresh`/`--brief` redirects and the Fallback apply here exactly as above.

## Fallback — direct file reads (the drone-container path)

**Trigger — this is the whole condition. Do not paraphrase it, and do not fall back for any other
reason.**

The probe must re-run the SAME command Step 1 used, including the repository argument if there was
one. `RepositoryNotFound` is only raised when a repository name is passed (in `_focus`,
`borg_core/link/cli.py`); an argument-less overview call can never hit the `not in registry` row, so
a probe that drops the argument makes that row unreachable. If Step 1's failing call was the overview
(no repository), that row simply won't fire for it — that is correct, not a bug.

Capture every branch input in one call (no `$()`, per repo rule). Substitute `<project>` with the
same argument (or nothing, for an overview) that Step 1 used:

```bash
bash -c 'borg link --json <project> >/tmp/borg-link.out 2>/tmp/borg-link.err
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

1. Walk up from `$PWD` looking for a `.borg-project` marker file with the MARKER-WALK block below. This
   is the ONLY place the marker is read: the engine is gone, so there is no `scope.kind` to believe,
   and the marker stands in for it. If found, read its single line — that's the *current project
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

2. For the **current project**, always use the resolved workspace from step 1 — never the
   registry's `path` field, which may be a host path. Marker found means a repository-scope page: the
   Repository scope rules apply (identity, session and status from `state.json`, the checkpoints in
   `<workspace>/.borg/checkpoints` only, the Queen pointer line, the next action last) and no other
   project is shown.
3. Marker found: do NOT read other projects at all; the page is about this workspace alone. The
   registry's `path` for another project resolves on the host and usually not inside a drone, and
   either way it is out of scope.
4. If no `.borg-project` marker is found (e.g. the Queen session at `~`), there is no current
   project — fall back to registry paths for everyone, and skip workspace-dependent reads that do not
   resolve (checkpoints, directives, assimilated, PROJECT_PLAN.md), showing the registry row only.

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
- One `borg link --json [<project>]` call serves every scope. Do not call twice.
- Scope is the engine's `scope.kind`, never the `.borg-project` marker and never your own guess from
  the cwd. The repository page names no other worktree, repository or project, and ends on the
  next-action line, after the Queen pointer.
