# borg-link rationale (editor history only)

This file is never read at runtime. `SKILL.md` does not send the model here, so nothing in it can change what `/borg-link` does; it is the design history and the longer wording that `SKILL.md` was shortened from, kept so the reasons survive the 8 KiB budget on the router. Edit an instruction in `SKILL.md` or the references file that owns it, and update the reasoning here.

Why the split exists: `SKILL.md` loads in full on every `/borg-link` call in every scope, so a repository page paid for the Queen view and the fallback it never used. `SKILL.md` is now the router plus the repository page, `references/queen-view.md` is read only when `scope.kind == "orchestrator"`, and `references/fallback.md` only when the Step 1 command fails.

## Doorways S3: the board is painted, not re-rendered (2026-10-19)

**Two rules are reversed, for the board only:** "Answer; do not re-render" (the old SKILL.md opening) and "never re-render the CLI's table" (its Guardrails). Until now `/borg-link` piped a jq projection of `borg link --json` to the model and the model wrote new prose each run, so the CLI's layout never reached the screen and a prose page could not be contract-tested (directive `docs/plans/assimilated/2026-10-18-doorways-one-screen-board.md`, AC3, tracking issue #439). Now the skill injects the CLI's own page and the model reproduces it in ONE fenced block with plain lines below that only restate the page (WAITING ON YOU and NEXT, no verdict of its own). Questions about the board ("why is X blocked?") still get prose answers from the `--json` projection, which moved to `references/questions.md` unchanged. The painted page is only worth showing because S2 (AC2) made it one screen: 50 lines live and at most 98 columns (`render.PAGE_COLUMNS`; the 2-column code-block gutter of the TUI takes the other 2 of 100).

**Evidence.**
- Experiment X1 (`docs/research/2026-10-18-terminal-output/evaluation.md`, section 4): a fenced block keeps exact alignment at 80 and 100 columns in the fullscreen TUI, and skill `!` injection is hidden from the user while the model can reproduce it. So injecting the page and having the model paste it shows the user the CLI's text.
- Cost: the paint path makes no Bash call, which is one full-context re-read fewer per run (the link-up-prepare directive measured those turns at a median 350k-token context). The page is about 50 lines, against a jq projection of about 30 KB.

**Why the injected line is shaped as it is.**
- `NO_COLOR=1` turns off colour AND the OSC-8 links (`cli._page` strips both with `picture.plain`), so the injected text has zero escape bytes; `borg_core/link/test_screen_contract.py` pins that for both scopes, with the 100-column bound.
- A non-zero exit inside injection aborts the whole skill in Claude Code, and Claude never sees the skill. The command ends in `|| echo BORG-LINK-UNAVAILABLE`, so it always exits 0 and a failure prints a marker line that the skill's Fallback section handles. `2>&1` is explicit although Claude Code merges stderr for the default shell, so the Bash fallback and Cortex see the same text.
- `$ARGUMENTS` is substituted into the injected command (a repository name, `--overview`, `--full`). Injected commands are permission-checked like any Bash call, so an argument that smuggles in another command fails closed instead of running; `allowed-tools` pre-approves only `borg link` and `echo`.
- Cortex Code expands no dynamic injection (`docs/plans/directives/2026-10-15-borg-in-cortex.md`, AC4). The model there sees the unexpanded injection line between the page markers, and the Fallback says what to do: ONE Bash call that prints the same page.
- No other line of SKILL.md may contain the injection syntax, because Claude Code would run it: the prose names it without writing it, and `tests/skill_borg_link.bats` counts the lines.
- The router shrank from 8,143 to under 3 KB because the whole `--json` path (Step 1, the version gate, the compass rules, the repository page recipe) moved to `references/questions.md`, read only when the user asks a question. The painted page needs none of it.

## The marker is not the mode decision, and the jq whitelist

**The `.borg-project` marker is NOT the mode decision.** It never was a reliable one: linked worktrees never get a marker, so a marker walk sent them into the overview. The engine resolves scope from the cwd (or from an explicit repository name, which wins), and you believe it. The marker is read only in the `## Fallback`, where the engine cannot run. Do not write an ad hoc find/ls to detect the repository.
The repository-scope arm of the jq is a whitelist on purpose. `--json` stays registry-wide on every call (`order`, `projects`, `directives`, `assimilated`, `grid`), and `focus` carries a plan and directives, which are repository-level. Its checkpoint list, head and `entry.summary` were read across the whole repo group until 2026-10-13 and are now the directory's own, but an older engine still sends the union. The repository page reads its own directory itself and may use none of that, so the pipe never lets it reach you. The one thing added to the whitelist is `compass`, cut down to this repository's own slice: the leg, this repository's `{destination, on_leg}` and the one destination it maps to. The Queen arm leaves the whole block in place.

## Why the jq

**Why the jq.** The Queen arm (`.directives |= (...)`) does not enumerate a field — it transforms one
key in place, so anything the document gains later passes through untouched. It collapses the one
uncapped array (directives, ~121 items live) from 27,298 bytes raw to ~13,935. `-c` drops the pretty-print whitespace, which costs context and tells a model reader nothing, and the named `del()` removes eight per-repository fields the Queen view never reads (`claude_session_id`, `path`, `repo`, `clock_divergence`, `tmux_session`, `source`, `notify_origin`, `last_activity`); it names what to drop rather than what to keep, so a field the document gains later still passes through. The same arm also names, with `del()`, the `.grid` and `.compass` fields no instruction in `queen-view.md` reads: per manifest `path` and `levels` (the nodes already carry `level`), per node `ref` (the object key is the ref), `why`, `order`, `lane` and `gate` (the manifest's `gates[]` is what routing reads), `.compass.today`, and per destination `domain`, `definition`, `target`, `next_waypoint` and `due` (`state` and `status` carry the tally). `.compass.parking` is filtered to the due items, the only ones the view lists. On a board measured at 45,690 bytes of Queen output this removed 14,948 bytes (to 30,742), nearly all of it `.grid.manifests` (23,744 to 14,443). AC2 added `desc`, `repos` and three topology keys per node to each manifest. S7 then collapses a finished stack: a manifest with at least one node whose every node `state` is `merged` or `closed` (the two terminal members of `manifest_core`'s `STATE_*` set; `open` is the only other declarable state) becomes `{id, desc, repos, rows, done: true}`. Finished stacks are history, shipped work reaches the Queen view through `assimilated`, and they are the part that grows, one row per merged PR (10 of 11 manifests, 35 of 36 nodes and 11,825 bytes on the measured board). `gates` is dropped with them: WAITING ON YOU takes manifest decisions only from a manifest's ready set (`render._ready_rows`), a ready ref is by definition `open`, so a manifest with no open node can carry no live decision. A manifest with zero nodes is not done and passes through, as does any manifest with one open (or unknown-state) node, with every key it has. Every field not named still passes through, and a read field is never dropped to hit a budget. The repository arm is
the opposite: an explicit whitelist, and a field the document gains later is invisible until it is
added there. That is the point of it — it keeps registry-wide data off a page that must be about one
directory. If `jq` is missing, drop the pipe and read the raw document, and still render only what the
scope allows.

## Original wording of the opening and Step 1 prose (before the split)

You are the synthesis layer on top of the `borg link` engine. The engine does the mechanical
read, the sort, the staleness overlay and the rendering; you do the thinking. Explain like the
reader is 10: plain language first, jargon only if it earns its place. Terse. Most-urgent-first.
Do not hard-wrap output; the terminal soft-wraps.

## What this is (one breath)

One `borg link --json` call returns the whole board: every repository's live status, how long since each was touched, what's queued (directives), what shipped (assimilated), and whether you're over capacity. **Scope decides which part of it you present**, and `scope.kind` is the engine's answer, not yours: in the Queen session (`scope.kind == "orchestrator"`, the session at `BORG_ORCHESTRATOR_ROOT`) you give the cross-repository overview, the Queen view. Anywhere else (`scope.kind == "repository"`: a repository, a linked worktree registered on its own, or an explicit repository name) you give a page about exactly that one directory and nothing else. Your job is to turn the document into an answer, not to re-render it.

Vocabulary: a *repository* is the git repo; a *worktree* is a linked checkout registered on its own, and each carries a project. "Queen" is the user-facing name for the orchestrator session; the contract names (`scope.kind` value `orchestrator`, `BORG_ORCHESTRATOR_ROOT`, every `--json` key) are unchanged.
**`--all`.** `borg link --json --all` includes archived repositories. Needed only when the user asks
*which* repositories are archived; the count alone is `total_projects - (.order | length)`.

If the Step 1 command fails, go to `## Fallback` below — the trigger lives there, verbatim.

## Step 1 — Run the engine, then branch on `scope.kind`

ONE call serves every scope. Run it once, with the repository name appended only when the user gave one:
```

Then branch, and only on this:

- `.scope.unregistered == true` → the **hint page**: the directory is neither the Queen root nor inside any registered path (the engine's own page for it says so and offers two commands). Say in two short lines that this directory is not a registered repository, that `borg add` registers it, and that `borg link --overview` (or `/borg-link` in the Queen session) gives the Queen view. Do not render the board, and do not present the overview in its place. Nothing else follows.
- `.scope.kind == "orchestrator"` → the **Queen view**. Follow `## Queen view` below.
- `.scope.kind == "repository"` → the **repository page**. Follow `## Repository scope` below. Stop reading the Queen view sections; they do not apply.

## Original wording of the compass, version gate and host-only flags

**Reading `.compass`** (the owner's plain-file map; additive, so the version gate below is unchanged and an engine that predates it simply has no `.compass` (on the repository page `found` is null), which you say nothing about):
- `.compass.found` false → one line, "no map at `<map_dir>`", and move on. Never invent a leg, a destination or a date.
- `.compass.leg.text` is today's leg; a null `leg` means none was chosen. Each destination's `state` is `on-track`, `at-risk`, `late` or `undated` for an active one, else its status (`done`, `killed`, `frozen`, `proposed`). In the Queen view give the tally of the active ones and lead with `late`.
- **Off route**: `.compass.repositories[<name>]` is `{destination, on_leg}`. A repository whose destination is not on the leg is off route, said as "off route: `<repository>` is not on today's leg", and only when a leg exists. A repository with no destination is simply unmapped, never off route.
- **Parking due**: `.compass.parking[]` items with `due == true` wait on the user, so list them last in WAITING ON YOU as "parking: `<text>` (look again `<look>`, seen `<seen>`)". The Queen view only; the repository page has no parking rows.
- A non-empty `.compass.warnings` is a map file the reader skipped; say so once.

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

## Original wording of the repository page, with its why-clauses

## Repository scope (`scope.kind == "repository"`)

This page is about exactly ONE directory: `.entry.path`, the directory the engine resolved. It is the directory of a repository or of a linked worktree registered on its own (borg-probes is a worktree of borg-collective; each carries its own project). Say what is true of THIS directory and stop.

**Never render, even though `--json` carries it:** the registry-wide board (`order`, `projects`, capacity, other repositories), any other worktree or repository, and every repo-level section: plan, QUEUED/SHIPPED (`directives`, `assimilated`), stacks and the `grid`, repository PRs. The Step 1 pipe already withheld them; if you ran without the pipe, ignore them anyway. A page that blends the repository's other checkouts into this directory's page is the exact defect this scope exists to prevent.

**Read in this order, then write the page.**

1. **Identity.** `.entry.path` plus branch and worktree relationship, from git on that path (one call):

```bash
git -C "<entry.path>" rev-parse --abbrev-ref HEAD
git -C "<entry.path>" rev-parse --path-format=absolute --git-dir --git-common-dir
git -C "<entry.path>" rev-parse --short HEAD
```

The first line is the branch; when it is `HEAD` the checkout is detached, so write `detached at <short sha>` using the fourth line (the short sha) instead of a branch name. The two paths on the next two lines are equal for a main checkout; when they differ this directory is a linked worktree, and the worktree-of path is the common dir without its trailing `/.git` (`.entry.repo` is the same common dir as the registry recorded it). If git fails (the path is missing or not a repository), print the path and say identity is unavailable. Do not look the parent up in the registry.

2. **Session and status**, all from `.entry`: `status`, `relative_activity`, `waiting_reason` when present, `has_uncommitted_changes`, `has_live_window` when present (null or absent means unknown, not false), and `tmux_window`. One or two plain lines.

3. **This directory's own checkpoints, read by you from `<entry.path>/.borg/checkpoints` and from nowhere else.** An older engine's `focus.checkpoints`, `focus.checkpoint_head` and `entry.summary` are read across every checkout of the repository, so they describe other worktrees too; the pipe drops them either way and you must not reconstruct them. List the directory with the Glob tool on `<entry.path>/.borg/checkpoints/*.md` (or Read the directory), then sort the names newest first yourself (a NAME sort, the same as the engine's) and keep the first 3. A missing directory is an empty listing.

Read the newest file with the Read tool at `<entry.path>/.borg/checkpoints/<newest>`. The summary is its tl;dr, else its first Accomplished bullet; give the 2-3 things that matter. The "recent" line is the up-to-3 names from the listing. An empty listing or a missing directory is the normal case for a fresh worktree: say "no checkpoint here yet" and suggest `/borg-link-up` in this directory. Never fall back to a checkpoint from another directory.

4. **This directory's waiting row**, from `.waiting.rows`. The engine labels EVERY waiting row with this directory's name, including the repository's open-PR rows (`merge #N`, `fix #N CI`), which belong to the whole repository and show up identically on every worktree page. The pipe therefore kept only the directory's own session row (`item` is `session`, `ref` null). If you ran without the pipe, keep only that row and drop every row with a `ref`. Print it as the `next_step`, the `item` and `age`. `.waiting.degraded` is a note when the sweep failed; say it once. Add nothing else to the block: no PR rows, no manifest decisions, no `hidden_lines`, no other repository's rows. With no session row print `nothing waits on you here`.

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

## Original wording of the guardrails

## Guardrails

- Read `.order` for display order. Never derive order from `.projects`' keys — jq's `keys` sorts
  alphabetically and would silently reorder the board.
- Never branch "no repositories" off `(.order | length)`. `total_projects` is the unfiltered count; an
  all-archived registry emits `order: []` with a non-zero `total_projects`.
- `pinned` and `display_name` are OPTIONAL ABSENT keys, not null-valued ones. Treat missing as
  absent.
- An empty `.order` with exit 0 is a SUCCESS, not a failure. Never fall back on it.
- No raw dumps. Every line is a synthesized takeaway. Never paste the JSON, and never re-render
  the CLI's table — if the user wants the table, they should run `borg link`.
- Read-only in spirit: this skill never writes `registry.json` or any `state.json`. Note the one
  unavoidable exception: `borg link --json` with no repository runs the CLI's Claude Desktop
  pre-pass, which merges into the registry — that is the CLI's normal behavior, not something to
  work around.
- One `borg link --json [<repository>]` call serves every scope. Do not call twice.

## Original Queen intro line

Everything from here to `## Repository scope` is the cross-repository overview. It is for the Queen session and for nothing else: never use it to render a repository or a worktree.
- Scope is the engine's `scope.kind`, never the `.borg-project` marker and never your own guess from
  the cwd. The repository page names no other worktree, repository or project, and ends on the
  next-action line, after the Queen pointer.

## Former frontmatter description wording

This sentence was cut from the SKILL.md description to stay under the 8 KiB budget:

Runs the `borg link` engine and synthesizes its output; falls back to reading the bind-mounted borg files directly only when the engine cannot run.
