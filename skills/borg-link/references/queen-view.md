## Queen view (`scope.kind == "orchestrator"` only)

This file is the cross-repository overview. `references/questions.md` sent you here because `scope.kind == "orchestrator"`; its Step 1 pipe, version gate, host-only flags, `.compass` rules and guardrails still apply. It is for the Queen session and for nothing else: never use it to render a repository or a worktree.

**Compass, Queen view only:**
- In the Queen view give the tally of the active ones and lead with `late`.
- **Parking due**: `.compass.parking[]` items with `due == true` wait on the user, so list them last in WAITING ON YOU as "parking: `<text>` (look again `<look>`, seen `<seen>`)". The Queen view only; the repository page has no parking rows.

**`--all`.** `borg link --json --all` includes archived repositories. Needed only when the user asks
*which* repositories are archived; the count alone is `total_projects - (.order | length)`.

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
- `.grid.picture_width` is the widest `▸ STACKS` picture row this document would draw, in VISIBLE
  columns (SGR and OSC-8 bytes excluded). Compare it to `PICTURE_BUDGET` (68). Over budget means the
  topology will wrap in a narrow pane and should be reported as a manifest problem — a ref is long
  or a level is too wide — not as a rendering bug. The human page says the same thing in
  `▸ SIGNALS`; this is the machine-readable half, so you never have to measure ANSI output.
- `.grid.manifests` is an **array** of manifest blocks, each carrying `id` (the manifest's slug),
  `desc`, `repos`, `nodes`, `gates` and `ready`, and the pipe drops each block's `path` and `levels`. A block
  with `done: true` is finished history (every row merged or closed), collapsed to `id`, `desc`, `repos` and
  `rows` (its row count): at most one line from `desc` and `rows`, or nothing. Never route it, read readiness
  from it, or list it under WAITING ON YOU. The other blocks carry:
  - `desc` is the manifest author's own one-line statement of what the whole project is for. Prefer
    it over inventing a summary out of row titles — it is their sentence, not yours.
  - `repos` is the sorted, deduplicated `owner/repo` list the manifest's **rows** name — the work,
    not everything it merely references (an apex or an `after:` pointer contributes nothing). Two or
    more entries means the project spans repositories, which is usually the single most useful fact
    about it and belongs in the one-line summary.
  - `.nodes` is an **object keyed by ref**, not an array. Each node carries `title`, `state`/`state_source`, `next`, `level` (topological rank), `seq` (declaration order — the
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
  `{project, item, next_step, owner:"YOU", ref, url, age, waiting_reason}`; `url` is the PR's address, empty
  on session rows); `.waiting.hidden_lines` is the chooser's own `+N more decisions` / `+N agent tasks` /
  `+N unowned` / `+N stale drafts` text; `.waiting.next` is the first row of the work list before the cap
  (`{project, next_step, detail, owner}`, or null), which the page's NEXT line and the arrival brief fall back to;
  `.waiting.degraded` is a note when the sweep or rows failed (say it once). Under
  `--local` there is no sweep, so no PR rows. Then add every `yours` manifest decision (the
  `gates[].kind == "decision"` routing above) whose ref is not already a row. Print the block LAST, one line
  per item: the repository, the `next_step` (as a markdown link to `url` when it is non-empty, e.g.
  `[merge #7](url)`), the `item`, and `unblocks N` (`len(.nodes[ref].children)`) for manifest items; then
  the `hidden_lines` verbatim. No age
  invention. **It is ALWAYS present**: with no rows and every manifest `known`, print the single line
  `nothing waits on you`; if a manifest with refs is `unlooked` and nothing else qualified, say "nobody
  looked" instead. `.waiting` is ADDITIVE (absent in `--porcelain`), so `DOCUMENT_VERSION` stays 2.
### Queen view — reconcile (add judgment to the mechanical pass)

The engine already sorted, already applied the staleness overlay, already counted capacity. Go
one level deeper:

- **Capacity is a finding, not a field.** `capacity.over_limit` true → lead with it and name which
  repositories are eating the budget (the `waiting` and `active` rows, in `.order`).
- **Empty summaries are the normal case, not an error.** `summary` comes from the repository's latest
  checkpoint (its tl;dr, else the first Accomplished bullet), so it is null only when the repository has
  no checkpoint. Degrade in this order: `summary` → `waiting_reason` →
  `relative_activity` → `focus.checkpoint_head`. Never print "(no summary)" for a whole column; if
  the board has no summaries, say so once and suggest `/borg-link-up` in those repositories to write a checkpoint; `--refresh` no longer fills `summary`.
- **Collapse, don't transcribe.** 121 directives across 9 repositories is a number plus the top few
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
## The collective — <N> repositories, <A> need attention   (limit <L>)   ← the capacity line, only if it bites
### ● <repository>  [<status>]  · <relative_activity>
<one plain-language line: what this repository is mid-way through, from summary/waiting_reason/checkpoint>
Queued: <n> directives (top: <title>, <title>)          ← omit the line when n is 0
> <contradiction or capacity note>                       ← only when this repository has one
...
Recently shipped: <title> (<repository>, <ship_date>)       ← the global newest-3, one line each
Hidden: <total_projects - (order|length)> archived — run `borg link --all` to see them.   ← omit when 0
```

The skeleton ENDS with the WAITING ON YOU block described above (see the `.ready` bullets). It is the
last thing the user reads.

Sort by `.order` and nothing else. If `.order` is empty and `total_projects` is 0, say "No
repositories registered — run `borg scan`." and stop. If `.order` is empty and `total_projects > 0`,
say "All <N> repositories are archived — run `borg link --all`." and stop. Those are two different
sentences and getting them backwards is the known trap.

### Queen view — guardrails

- Read `.order` for display order. Never derive order from `.projects`' keys — jq's `keys` sorts
  alphabetically and would silently reorder the board.
- Never branch "no repositories" off `(.order | length)`. `total_projects` is the unfiltered count; an
  all-archived registry emits `order: []` with a non-zero `total_projects`.
- `pinned` and `display_name` are OPTIONAL ABSENT keys, not null-valued ones. Treat missing as
  absent.
- An empty `.order` with exit 0 is a SUCCESS, not a failure. Never fall back on it.
