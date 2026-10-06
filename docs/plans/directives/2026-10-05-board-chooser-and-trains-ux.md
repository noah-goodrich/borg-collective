# Directive: The board, the chooser and the trains — borg UX for deciding where focus goes
*Filed: 2026-10-05*

This directive is INPUT to `2026-08-11-viz-3-cross-repo-chains.md`, not a competing spec. It supplies four mocks, a build order and one measured gate; viz-3 stays the single spec for the board and chains surface (2026-10-03 rulings). Screen 3 needs train data that only the directive `2026-10-04-personal-pr-stack-stamper` produces, so it is built last and only after the stamper exists.

## Decisions (Noah, 2026-10-05)

- The four mocks below are a good first pass, and all four get built.
- Build order (picked by Claude, per Noah): 1) screen 2, `borg next` as a chooser that also recommends; 2) screen 1, the board; 3) screen 4, the drone arrival brief; 4) screen 3, trains in one repo, once the stamper produces train data.
- `borg next` SHOULD recommend, but only if the recommendation is relevant most of the time: "borg next recommending sounds great, if it can make relevant recommendations most of the time." Today its ranking (pinned +200, waiting +100, active +50, idle +10) rarely matches what is top of mind, so the recommendation is gated by the measurement in "The recommendation gate" below.
- Workflow these screens follow: Ghostty → `borg init` → queen session → `/borg-link` → `!drone up X` → work in the drone.

## Relationship to the backlog

- **viz-3 (`2026-08-11-viz-3-cross-repo-chains`) — this directive is SUBORDINATE.** X1 (three tiers, tier 1 is the awaiting-you filter) and X9 (awaiting-you tier in the landing region, absent when empty) own the ordering and the tier. Screen 1's WAITING ON YOU block is a mock of X9 and screen 3 is a mock of X3 and X5; AC4 below supersedes X9's empty-state clause ("absent, not empty"), and X9's other clauses stand; anywhere else, a mock that disagrees with an X criterion is the one that is wrong. X2 (value ÷ effort) is not touched here; the chooser does not rank by effort.
- **link-unification L3 (`2026-08-11-link-unification-and-layout`) — defers to it.** L3 puts the answer in the last 3-5 lines before the prompt, so the WAITING ON YOU block lands at the bottom of the page, not the top as the mocks draw it for readability. Where the mock and L3 disagree about position, L3 wins.
- **link-unification L4 — idle collapse is REJECTED here.** L4's "idle projects collapse to a count line" was withdrawn; the first draft of screen 1 revived it as a `17 quiet` row. That row is removed. Nothing in this directive collapses projects.
- **attention-routing A2 (`2026-08-11-attention-routing`, moved to severed/ by noah-goodrich/borg-collective#266) — not revived.** This directive adds no hook signal and no channel; waiting items come from `borg link`'s existing routing.
- **comms-delivery S6 (`2026-08-20-comms-delivery-surfaces`) — defers to it.** S6 decides which status surfaces adopt the house grammar. These mocks use the ratified glyphs and must go through S6's adoption, not around it; this directive adds no surface S6 has not inventoried except the chooser, which S6 should list.
- **#262 (`docs/pm-capabilities-build-adopt-outsource`) — reconciled, with one override.** #262 specifies a one-row-per-invocation `borg next` ranking log (top 3 with rank, score, status, and whether it ran under `--switch`), keeps `cmd_next`'s ranking unchanged, and keeps `borg next` non-interactive. This directive REUSES that log (one append, not a second) and adds the recommendation fields below to it. It OVERRIDES #262's "non-interactive, ranking unchanged" for the chooser only, on Noah's 2026-10-05 decision above: the chooser is a new interactive path, `--switch` and its Ctrl+Space > hotkey stay exactly as they are, and `cmd_next`'s ranking is unchanged until the gate passes. #262 names no file for the log; if it lands first under another name, adopt that name and put the fields in it.
- **#257 (communication research) — defers to it.** The glyph grammar and the "next → owner → unblocks" sentence shape are provisional until #257's channel decision lands; a conflict there changes the mocks, not the other way round.

## Data available at each stage

Screens 1, 2 and 4 are built before the stamper, so they use only data that exists today. Owner is the render-time routing `borg link` already computes (`▸ NEXT`: yours / mine / unsure); no owner is stored anywhere. Per item, the owner is that row's routing. The per-project counts on screen 1 are the number of that project's `▸ NEXT` rows in each routing bucket, and a project with no routed rows shows dashes. Trains appear only once the stamper exists, and then only in screen 3 and as an added column in screens 1, 2 and 4. The mocks below are illustrative: the data is made up and is not a snapshot of real state, and a mismatch between two mocks is a defect in the mocks, not a requirement.

## 1. Queen session — `/borg-link` (the board)

Renderer: this is a change to `render.SECTIONS` in `borg_core/link/render.py`, which is X9's wiring. Adding or moving a section turns the spine test red on purpose; the goldens are regenerated in the same commit. When nothing waits, X9 says the block is absent, but CLAUDE.md's renderer rule is "no branch on scope, mode or emptiness": every section always exists. This directive keeps the renderer rule. The section is always present and prints one line, `nothing waits on you`, when empty. AC4 supersedes X9's "absent when empty", and viz-3 carries a dated 2026-10-06 note on X9 saying so. The load bar from the first draft is dropped: no measure of "load" was ever defined.

```
BORG ── Tue 6 Oct 09:15 ───────────────────────────────────
 PROJECTS            yours mine unsure  touched
 borg-coll              3    1     –    now
 ingle                  1    –     –    10d
 dotfiles               1    –     –    2h
 ...every other registered project, one row each
───────────────────────────────────────────────────────────
 WAITING ON YOU (4)                    age  unblocks
 ▶ ship State Hygiene   borg-coll      now  /borg-assimilate
 ▶ run install.sh       dotfiles       2h   table rule+hook
 ▶ pick #257 channel    borg-coll      1d   paste /tui
 ▶ answer triage Qs     borg-coll      1h   archives 4
───────────────────────────────────────────────────────────
 ● ready  ○ open  yours/mine/unsure = routing, computed per run
```

## 2. `borg next` — a chooser

Host: bare `borg next` run where both stdin and stdout are a TTY (`-t 0 && -t 1`), such as the queen session's terminal, a tmux pane, or `tmux display-popup -E 'borg next'`. A `!borg next` run from inside Claude has no TTY, so it never gets the chooser. When either stream is not a TTY, `borg next` keeps today's output: one `Next up: <project>` block for the top-ranked project, or `All clear` when nothing ranks. A `--pick <n>` flag selects row n without a prompt; it is the non-interactive seam, for tests and for scripting.

`borg next --switch` (Ctrl+Space >) picks the top project and switches to it, and it is unchanged. Only its empty-registry branch is pinned in `tests/cli_contract.bats` today; AC1's first commit adds the populated-fixture case. The chooser is the new interactive path, entered by `borg next` on a terminal; it lists candidates and the user opens one. The line marked ▸ is the gated recommendation (Decision 3): it is NOT drawn until the gate below passes, and in shadow mode it is only logged.

```
WHERE COULD YOUR FOCUS GO?
───────────────────────────────────────────────────────────
 # project · item      next step          owner   ready
 1 borg · hygiene      /borg-assimilate   yours   ● now
 2 borg · research     merge #252         mine    ● now
 3 borg · comms        paste /tui         yours   ● 5m
 4 borg · triage       answer triage Qs   yours   ● 1h
 5 dotfiles · install  run install.sh     yours   ● 2h
 6 ingle · session     reply to session   yours   ○ 10d
───────────────────────────────────────────────────────────
 ▸ suggested: 1 borg · hygiene    (shown only after the gate)
 sort: [a]ge [o]wner [r]eady [p]roject   ⏎ open  d drone
```

Column sources. The `next step`, `owner` and `ready` cells come from the grid's ready set (`grid.ready_refs`) and the `▸ NEXT` routing, and only for a project that has a manifest. A project with no manifest still gets a row, with those three cells blank. The mock's cell text is drawn for readability.

## 3. One repo, several trains — `/borg-link borg-collective`

Built last, and only once the stamper's render-time train derivation exists (no cache, no persisted file); borg cannot tell trains apart inside one repo today: 3 manifests exist across 20 registered repos, 2 of them in borg-collective, and nothing groups PRs into trains. It is the mock of viz-3's X3 and X5 and defers to them. Glyphs are the ratified set from `borg_core/link/picture.py`: ✔ merged, ● ready, ○ open, ◌ draft, ✗ closed.

```
borg-collective ── 4 trains ───────────────────────────────
 HYGIENE   AC1━AC2━AC3━AC4━AC5━AC6━ship
           ✔   ✔   ✔   ✔   ✔   ✔   ●  YOU: /borg-assimilate
 RESEARCH  #252━━#262       #257
           ●     ○          ◌
           #262 needs #252 merged first
           YOU: paste /tui → picks the channel
 TRUTH     shim━stamper━manifests━board
           ✔    ○       ○         ○
           decided 10/4: build the stamper
 FIXES     #267━#268━#272━install.sh
           ✔    ✔    ✔    ●  YOU
───────────────────────────────────────────────────────────
 ✔ merged  ● ready  ○ open  ◌ draft  ✗ closed
```

## 4. After `!drone up` — arrival brief in the drone

Channel: `drone up` prints it to the new window's shell pane after the window opens and before Claude starts. It is a presentation of the same `borg link <project> --json` document, in the way `--brief` is, not a second read. Before the stamper it shows the project, not a train: "last time" and "since then" come from the latest checkpoint and git, which exist today. The train name appears in the header once the stamper exists.

```
▸ borg-collective ─────────────────────────────────────────
 last time   AC6 ticked (#264), 6/6 criteria met
 next        /borg-assimilate              owner: yours
 watch out   byline check pending
 since then  4 PRs merged (#264 #267 #268 #272) · tree clean
```

## Which sheet taught what

- **Feelings wheel** → coarse at the centre, finer outward. Board → project → step.
- **Four Horsemen + antidotes** → each problem next to its fix. Every blocker line names its unblock step.
- **NVC script** → one fixed sentence shape. Every step reads "next → owner → what it unblocks".
- **Colour and position** → meaning before reading. Owner columns and the ratified glyphs.
- **Window of tolerance** → the "you are here" load band was dropped with the load bar (undefined measure); it may return as its own directive if a measure is defined.

## The recommendation gate (pre-registered 2026-10-05)

The numbers here are fixed before any data exists; changing one after seeing data requires a dated note in this file.

- **Shadow mode first.** On each chooser invocation borg computes its suggestion and appends a row, but does not show the ▸ line. The chooser is otherwise identical.
- **A chooser invocation** is either an interactive run on a TTY or a `borg next --pick <n>` run. A `--pick` run is logged exactly like an interactive one, with `opened` set to row n and `opened_after_s` set to 0. That is what lets bats, which has no TTY, drive AC2. A bare non-TTY `borg next` without `--pick`, and `borg next --switch`, are not chooser invocations. They still log a row, with `chooser: false`, because #262's log records every `borg next` run.
- **Log file.** `${XDG_STATE_HOME:-~/.local/state}/borg/next-recs.jsonl`, one fail-open JSONL row per `borg next` run of any kind (#262's log). The append happens in the Python core and calls `borg_core/retention.py::rotate_log` first. The bash `_borg_rotate_log` would not work here: it lives in `lib/borg-hooks.sh`, and `borg.zsh` sources only `lib/*.zsh`. It is the same append #262 specifies for `cmd_next`; the fields are: `ts`, `session` (chooser invocation id), `shown` (bool, false in shadow mode), `top3` (project, rank, score, status, as in #262), `rec` (project and item suggested), `opened` (the project and item the user opened, or null), `opened_after_s` (seconds from chooser start to open, or null), `active` (the project whose tmux window had focus when the chooser started, found by matching `borg_tmux_current_window` against each registry entry's `tmux_window`, or its name when that is unset; null from the queen session or outside tmux), `switch` (bool, true for the `--switch` path), `chooser` (bool, true only for a chooser invocation as defined above). On a row with `chooser: false`, `shown` is false and `rec`, `opened` and `opened_after_s` are null.
- **Followed means:** the user opens the suggested row in the same chooser invocation. Anything else (a different row, or nothing) is not followed. Nothing records window switches made after the chooser exits, so there is no later-window branch.
- **Threshold:** follow rate >= 60% over >= 20 rows with `chooser: true`. Below 60% at 20 sessions, the suggestion is not shown and the ranking is rebuilt; the check is re-run each further 20 sessions.
- **Only after the gate passes** is the ▸ suggested line shown (first, as drawn in screen 2), and the same follow rate keeps being logged with `shown: true`.
- **Falsification note:** a high follow rate in shadow mode can be the ranking merely naming the already-active project, which the user would open anyway. Read the rate alongside #262's finding that rank 1 is mostly a project whose session status is already active; a rate that does not exceed "opens the project whose window had focus", computed from each row's `active` field, is not evidence of relevance.

## Acceptance criteria

- [ ] AC1 — The chooser (`borg next` on a terminal) lists candidate rows with project, next step, owner and readiness, using only data available without the stamper (the `next step`, `owner` and `ready` cells filled from the grid's ready set and the `▸ NEXT` routing where a manifest exists, blank otherwise), and `borg next --switch` behaves exactly as before.
  - Verify: `tests/cli_contract.bats` pins only the empty-registry branch of `next --switch`, so the FIRST commit adds a characterisation case: `borg next --switch` against a populated fixture registry, with the window target asserted. It lands green on unchanged code. The chooser commit must keep it green unchanged. A second case drives the chooser through `--pick 1` against the fixture and finds one row per candidate: a project with a manifest carries an owner of yours, mine or unsure, and a project without one carries blank next step, owner and ready cells.
- [ ] AC2 — Shadow mode appends one well-formed row per chooser invocation and displays no suggestion.
  - Verify: after one `borg next --pick 1` run against a fixture (the non-TTY chooser invocation), `tail -1 "${XDG_STATE_HOME:-$HOME/.local/state}/borg/next-recs.jsonl" | jq -e '.chooser == true and .shown == false and has("rec") and has("opened") and has("active")'` exits 0, and the chooser output contains no `suggested` line.
- [ ] AC3 — The ▸ suggested line is shown only when the gate is satisfied.
  - Verify: a unit test over a fixture log with 19 sessions at 100% follow shows no line, 20 sessions at 55% shows no line, and 20 sessions at 60% shows the line.
- [ ] AC4 — The WAITING ON YOU block is wired through `render.SECTIONS`, is always present, and prints one `nothing waits on you` line when empty (renderer rule kept; AC4 supersedes X9's empty-state clause).
  - Verify: against an empty fixture, `borg link` prints the WAITING ON YOU section header and the `nothing waits on you` line after the WAITING ON YOU header; against a populated fixture, the lines between that header and the next section header (or the end of the output) are the waiting items, one per fixture item. The assertion is by section header, not by a fixed line offset from the end. The spine test and goldens are regenerated in the same commit.
- [ ] AC5 — Screen 3 renders trains only from the stamper's render-time derivation and uses the ratified glyphs.
  - Verify: against a fixture with no keys and no rows, `/borg-link <repo>` prints no train rows; against a stamped fixture, an open PR with unmerged parents renders `○` and a merged PR renders `✔`.
- [ ] AC6 — Full bats suite and the macOS contract leg stay green.
  - Verify: `make test` and the CI contract lane pass.

## Ship definition and boundaries

Each screen ships as its own PR in the stated order; screens 1 and 2 may not wait on the stamper. This directive adds no new edge source and no persisted chain file (viz-3 X7). It does not rank by effort or deadline (viz-3 X2, X4). If a mock turns out to need a graph layout, stop and take it to viz-3's risk note rather than growing the picture here.
