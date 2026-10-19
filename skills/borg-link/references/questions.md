# Questions about the board (read only when SKILL.md sends you here)

SKILL.md sent you here because the user asked a question about the board ("why is X blocked?", "what is waiting on me?", "which repositories are idle?") instead of asking to see it. You answer in prose from the engine's `--json` document. Explain like the reader is 10: plain, terse, most-urgent-first. Output rules and the host-only flags (`--refresh`, `--brief`, `--full`) are in SKILL.md. Do not paste the page: showing the page is the paint path's job.

`scope.kind` is the engine's answer: `orchestrator` (the Queen session, at `BORG_ORCHESTRATOR_ROOT`) gets the Queen view; `repository` (a repository, a linked worktree, or an explicit repository name) gets a page about exactly that one directory. Answer the question; the Queen view and the repository page below say which facts exist in each scope.

## Step 1 — Run the engine, then branch on `scope.kind`

ONE call serves every scope: run it once, never twice, with the repository name appended only when the user gave one:

```bash
borg link --json [<repository>] | jq -c 'if .scope.unregistered == true
  then {version, generated_at, scope}
  elif .scope.kind == "orchestrator"
  then (.directives |= (group_by(.project) | map({project: .[0].project, n: length,
    titles: [limit(5; .[].title)]}))
    | del(.projects[] | .claude_session_id, .path, .repo, .clock_divergence, .tmux_session,
      .source, .notify_origin, .last_activity)
    | del(.grid.manifests[]? | .path, .levels, (.nodes[]? | .ref, .why, .order, .lane, .gate))
    | del(.compass.today, (.compass.destinations[]? | .domain, .definition, .target, .next_waypoint, .due))
    | (.grid.manifests[]? | select((.nodes // {}) | length > 0
      and all(.[]; .state == "merged" or .state == "closed")))
      |= {id, desc, repos, rows: (.nodes | length), done: true}
    | if .compass.parking then .compass.parking |= map(select(.due)) else . end)
  else (.scope.repository as $r | (.compass // {}) as $c
    | ($c.repositories[$r] // {}) as $m | {version, generated_at, scope,
    entry: (.focus.entry | del(.summary)),
    compass: {found: $c.found, map_dir: $c.map_dir, leg: ($c.leg | if .text? then .text |= .[:200] else . end),
      repository: $m, destinations: [$c.destinations[]?
        | select(.id == $m.destination)]},
    waiting: {rows: [.waiting.rows[] | select(.project == $r and .item == "session")],
      degraded: .waiting.degraded}})
  end'
```

Then branch, and only on this:

- `.scope.unregistered == true` → the **hint page**: say in two short lines that this directory is not a registered repository, that `borg add` registers it, and that `borg link --overview` gives the Queen view. Render no board or overview; read no references file.
- `.scope.kind == "orchestrator"` → the **Queen view**: Read `references/queen-view.md` (relative to this skill's base directory) and follow it. Read it ONLY in this scope.
- `.scope.kind == "repository"` → the **repository page**: follow `## Repository scope` below. Read no references file.

If the Step 1 command fails, Read `references/fallback.md` (relative to this skill's base directory); its trigger is the whole condition. Read it only then.

Scope is the engine's `scope.kind`, never the `.borg-project` marker or your guess from the cwd; run no ad hoc find/ls. If `jq` is missing, drop the pipe and render only what the scope allows.

**Version gate — read `.version` first.** `== 2` → proceed silently. `> 2` → proceed, and say in one line this skill targets v2 and newer fields may go unreported. `< 2` or absent → STOP: tell the user their borg install is older than this skill; do NOT fall back on a version mismatch.

**`.compass`** (additive; absent on an older engine: say nothing): `found` false → one line "no map at `<map_dir>`"; never invent a leg, destination or date. `leg.text` is today's leg (null: none). A destination's `state` is `on-track`, `at-risk`, `late` or `undated` if active, else its status. **Off route**: with a leg, a repository whose `repositories[<name>]` (`{destination, on_leg}`) is off the leg reads "off route: `<repository>` is not on today's leg"; no destination is unmapped, never off route. A non-empty `warnings` is a skipped map file: say so once.

## Repository scope (`scope.kind == "repository"`)

This page is about exactly ONE directory: `.entry.path`, the directory the engine resolved. Say what is true of THIS directory and stop.

**Never render:** the registry-wide board (`order`, `projects`, capacity), any other worktree or repository, and every repo-level section: plan, QUEUED/SHIPPED, stacks and `grid`, repository PRs.

**Read in this order, then write the page.**

1. **Identity**, from git on `.entry.path` (one call):

```bash
git -C "<entry.path>" rev-parse --abbrev-ref HEAD
git -C "<entry.path>" rev-parse --path-format=absolute --git-dir --git-common-dir
git -C "<entry.path>" rev-parse --short HEAD
```

The first line is the branch (`HEAD` = detached: write `detached at <short sha>` from the fourth line). The two paths are equal for a main checkout; if they differ this is a linked worktree, whose worktree-of path is the common dir minus its trailing `/.git`. If git fails, print the path and say identity is unavailable. Never look the parent up in the registry.

2. **Session and status**, from `.entry`: `status`, `relative_activity`, `waiting_reason` if present, `has_uncommitted_changes`, `has_live_window` if present (null or absent = unknown, not false), `tmux_window`.

3. **This directory's own checkpoints**, read by you from `<entry.path>/.borg/checkpoints` and nowhere else (do not reconstruct `focus.checkpoints`, `focus.checkpoint_head` or `entry.summary`). Glob `*.md` there, NAME-sort newest first, keep 3. Read the newest: its tl;dr, else its first Accomplished bullet, gives the 2-3 things that matter; "Recent" is the up-to-3 names. Empty or missing is normal in a fresh worktree: say "no checkpoint here yet" and suggest `/borg-link-up`. Never use another directory's checkpoint.

4. **Waiting row**, from `.waiting.rows`: keep only this directory's session row (`item` `session`, `ref` null; the pipe did this, otherwise drop every row with a `ref`). Print its `next_step`, `item` and `age`; note `.waiting.degraded` once. Add nothing else (no PR rows, manifest decisions, `hidden_lines`, other repositories' rows). No session row: `nothing waits on you here`.

5. **Next action, one line.** The session row's `next_step`; else the `waiting_reason` when `status` is `waiting`; else the newest checkpoint's next-steps line; else "nothing pending here". If the checkpoint claims in-flight work but `relative_activity` shows the directory idle, name that disagreement in the same line and recommend the fix, as `/borg-recon` does (no fixed threshold).

**Skeleton:**

```
## <entry.path>  ·  <status>  ·  <relative_activity>
Branch <branch>  ·  worktree of <worktree-of path>   ← or "main checkout" / "detached at <short sha>"
<one or two lines: the live session, uncommitted changes, waiting_reason>
Checkpoint (<newest filename>): <the 2-3 things that matter>
Recent: <up to 3 filenames>                            ← omit when there are none
For the overview of every repository, run /borg-link in the Queen session.
Waiting: <next_step> — <item> (<age>)                  ← or `nothing waits on you here`
Next: <one line>
```

The ORDER is fixed and the page ENDS on `Next:`. The pointer line is verbatim, once; add no second pointer, menu or worktree count.

## Guardrails

- No raw dumps: every line is a synthesized takeaway; never paste the JSON. The page itself is painted by the skill's paint path, never retyped here.
- Read-only in spirit: never write `registry.json` or any `state.json`.
