# Directive: Personal-repo PR trains — derived at render time, published by hand
*Filed: 2026-10-04 · Revised: 2026-10-06 after three reviews on noah-goodrich/borg-collective#271*

This is a directive, not a plan. It becomes `PROJECT_PLAN.md` only through `borg start` once accepted, so that no tooling (`manifest.cli resolve`, `/borg-link-up`) aims at it while it is on hold.

## Objective

borg derives which PRs form a train, and in what order, from rows derived from PR events plus an anchored key the PR author declares. It derives at render time, in the same clean read `borg link` already does, with no cache. `borg link` shows each train for every registered repo, as a lower bound wherever the membership lookup could not be completed (see Completeness). On repos this machine publishes for, a person can write one stable pointer line into each PR body, after a check against GitHub.

## Why

- **Execution in personal repos has no source of truth.** Rows reach `.borg/chains/*.json` only when `/borg-link-up` runs `add-row` (whose documented form exited 2 until noah-goodrich/borg-collective#272). As a result, 2 of 3 manifests on this machine are empty.
- **Triage questions arrived without provenance.** Nothing linked a PR to the directive and criterion it serves.
- **Rows are derived from PR events; membership is declared by an anchored key.** The key is written by the author, or by `/borg-link-up` on the author's behalf, so it is the one volunteered part, and the AC5 nudge is its only bound. Cairn's lesson (CLAUDE.md, Learned) is why everything else is derived from artifacts the agent already produces. All three reviews kept that half of the original plan.

## Standing rules this directive keeps

- **One Front Door AC1, "No cache, ever — a clean read every time"** (pinned in `tests/link_sweep.bats`) is kept, and so is **viz-3 ruling 2** (one edge source).
- **viz-3 X7 is AMENDED, not kept as written.** X7 said chain data derives from the manifests "plus the live sweep". This directive adds a second live input, the membership search, so X7 now reads "plus live GitHub state" (dated note in viz-3, 2026-10-06). Its other clauses still hold: there is no new persisted file, and trains are a *view* computed from those inputs, never stored.
- **The 2026-09-22 lifecycle split:** `/borg-plan` creates manifests, `/borg-link-up` adds rows, and nothing here creates a manifest.
- **Publication is never automatic.** The noah-goodrich/borg-collective#266 triage withdrew PM11 in favour of this directive, so the rule is restated here as this directive's own: rendering and auditing run unprompted, and anything that writes to GitHub runs only when a person types it. No hook may trigger it.
- **Projection into other systems is out of scope and outside borg.** borg runs no outbound adapter. Anything that consumes `borg link --json` sits outside borg, is run by its own owner, and exports only the repos that owner declares. The recon adapter tier is inbound only, and `borg link`'s own sweep runs it, so it must never host a consumer of `borg link`.

## Definitions

- **Membership key:** anchored lines in a PR body, matched the way `- Plan-slug:` is: `- Train: <manifest-stem>/<lane>` and, optionally, `- After: <owner/repo#N>`. Only those lines are read; free text is never copied anywhere.
- **Trusted author:** for a same-repo head (not a fork), a PR whose `author_association` is OWNER, MEMBER or COLLABORATOR. Org-owned repos have no OWNER-authored PRs, so MEMBER must count. A key on any other PR, including every fork PR, is ignored and named once in `▸ SIGNALS`.
- **Train:** for one `<stem>/<lane>`, the union of the manifest rows in that lane and the open or recently merged trusted-author PRs that carry the key, as found by the membership search (see Completeness). An open member counts at any age. "Recently merged" means `mergedAt` within the sweep window, `grid.DEFAULT_SWEEP_WINDOW_DAYS` (resolved through `link.shell.sweep_window_days()`), and the membership search returns `mergedAt` where the recon sweep does not. A lane is *declared* when a manifest row carries it, the same set `cli._unknown_lane` checks. A lane comes to exist with its first row, and adding one to a manifest that already has rows requires `add-row --new-lane`. A `- Train:` key naming an undeclared lane is ignored and named in `▸ SIGNALS` (the key and the PR), never rendered as a one-member train: a mistyped lane would otherwise fork a second train and leave the real one a member short, the defect `_unknown_lane` exists to stop on the `add-row` side. A *key-only member* is a trusted-author PR that carries a key for a declared lane and has no row. A key naming a stem with no manifest is ignored and named in `▸ SIGNALS`.
- **Completeness:** train membership has ONE source. It is a single targeted search for the `- Train:` key in PR bodies, scoped to the repo, returning each candidate's number, state, `mergedAt` and `updatedAt` (a GraphQL `search`, because `gh search prs --json` exposes no `mergedAt`). `publish` uses it, and so does `borg link` whenever it is not `--local`. The recon sweep is not used for membership. It still supplies PR state for manifest rows, and its 30-PR cap no longer bounds membership. The search only nominates candidates. Each hit's body, `authorAssociation` and `isCrossRepository` come back inline in the same GraphQL response, so confirmation is a parse in the shell layer, not a second round trip. Every hit must match the anchored key exactly, never fuzzily, and the body is discarded after the parse. Search indexing can lag, so a key edited moments ago may appear only on the next run. A degraded or truncated search makes `publish` refuse, and makes `borg link` show that repo's train count as a lower bound (`n+`) with one `▸ SIGNALS` line. Under `--local` no search runs, so keyed membership is unknown: `borg link` shows the declared rows only, and one `▸ SIGNALS` line says keyed members were not looked up. The invariant, stated truthfully: against the same GitHub state, `publish`'s "step k of n" equals the count a non-local `borg link` shows when its search completes; the degraded and `--local` cases above are the signalled exceptions. **Cost, stated by case:**
- **Manifest with fetchable refs:** the targeted fetch runs, and the search rides as an alias in that same batched GraphQL request, so there is no extra `gh` call.
- **Manifest with no fetchable refs** (only `link` rows, say): `shell.start_fetch` forks nothing today ("NO REFS MEANS NO SUBPROCESS"), so the search is ONE new `gh api graphql` call.
- **No manifest:** no search, so no call. Every fixture without `.borg/chains` stays fork-free.
- **Order:** there is one edge source, the manifest. Manifest rows follow the grid's own order: topological level, then declaration order, including the edges that consecutive rows in a lane imply (`_stacked_edges`, where an explicit `after` replaces the lane edge into that row), so a lane renders in one order everywhere on the page. Key-only members follow the rows, ordered by PR number, and that rule is stated rather than inferred. A key's `- After:`, like a non-default base branch, is a *proposal*: `borg link` shows it and never uses it for order until it is recorded as a manifest row's `after`, which `add-row --after <ref>` does in one command. "Step k of n" is the member's position in that order. This keeps viz-3 ruling 2, "There is one edge source, `.borg/chains/*.json`", and keeps it truthfully: a key never adds an edge.
- **Publisher:** the machine-local allowlist `${XDG_CONFIG_HOME:-~/.config}/borg/trains.allow` (one `owner/repo` per line) gates publishing and the publish nudge (AC5), while deriving and rendering run for every registered repo on every machine. A repo worked from two machines appears in exactly one machine's allowlist.
- **Wire and surface:** the new member fields (`train`, `after`, `author_association`, `is_cross_repository`) and any new node fields are additive on the `--json` wire, so `DOCUMENT_VERSION` stays 2 (CLAUDE.md: a bump happens only when a pre-existing key narrows). `borg train` is a new top-level verb: it gets a line in `cmd_help`'s command list in `borg.zsh`, above `help`, and a case in `tests/cli_contract.bats` proving that `borg help` names it. The case named "contract: borg help is net one command shorter than at plan start (AC1)" asserts an exact `COMMANDS` count, so the expected count in it moves from 27 to 28 in the same change.

## Acceptance Criteria

- [ ] **AC1 — Pure derivation.** `borg_core/train/core.py` turns manifest rows plus confirmed membership facts into trains under exactly the Definitions above: key parsing, the trusted-author gate, order and proposals. It does no I/O, and an AST import-walk test pins that purity. `borg_core/manifest/cli.py`'s `add-row` gains an `--after <ref>` flag, so a proposal is accepted in one command: it appends the ref to the row's `after` list, idempotently, validated like an `after` entry (a full `owner/repo#N`, never the row's own ref), in the same append-or-update the verb already does.
  - Verify: pytest cases cover:
    - an org repo's MEMBER-authored PR joins;
    - an outsider's key and a fork PR's key are ignored;
    - a key-only member joins a declared lane's train;
    - a mistyped lane yields the `▸ SIGNALS` line and no new train;
    - a proposed `- After:` is shown but does not reorder, and accepting it with `add-row --after` reorders;
    - a mixed lane orders its rows by the grid, then its key-only members by PR number;
    - base-branch proposal is never used for order;
    - unknown stem is reported.
  - This criterion carries no Evidence pin: its Verify spans `borg_core/train/test_core.py` and the manifest CLI tests, so it reads unknown until `/borg-assimilate` checks it.
- [ ] **AC2 — The membership search carries the key, parsed and nothing else.** The one membership search (see Completeness) returns, per confirmed member, the parsed `train` and `after` fields, plus `author_association`, `is_cross_repository`, number, state, `mergedAt` and `updatedAt`. It never carries the body. The recon adapter's items are unchanged. This is additive (expand first).
  - Verify: bats through a `gh` stub; the fixture body contains free text that must not appear anywhere in the output, and a search hit whose body does not match the anchored key exactly is dropped.
  - Like AC6, this criterion carries no Evidence pin: it is a conjunction (the leak check and the membership search), so no single file covers it, and a pin would tick the box early. It reads unknown until `/borg-assimilate` checks it.
- [ ] **AC3 — `borg link` draws trains at render time.** CHAINS renders trains from the live grid with the ratified glyphs and render-time routing, and writes no file. `tests/link_sweep.bats`'s no-cache assertions stay green. Its exact `gh`-call counts stay unchanged for every case without a manifest and every case whose manifest has fetchable refs, because the search rides the targeted fetch there. Any case whose manifest declares lanes but no fetchable refs gains exactly one call, and that count is updated in the same commit with a one-line comment naming this criterion (see Completeness, cost by case). A repo with no keys and no rows renders byte-identically to before. A non-local run takes keyed members from the membership search, a `--local` run shows declared rows only with a `▸ SIGNALS` line, and a degraded search shows a lower bound `n+` with a `▸ SIGNALS` line (see Completeness).
  - Verify: a hand-authored golden for a two-lane fixture that has a key-only member; a byte-identity test for a fixture with no trains; a stub search with a keyed PR beyond the sweep's 30-PR horizon is counted; `--local` shows rows only, with the signal; a degraded search shows `n+` with the signal.
  - This criterion carries no Evidence pin: its Verify spans more than one file, so it reads unknown until `/borg-assimilate` checks it.
- [ ] **AC4 — `borg train publish` writes one pointer line, by hand, after a clean check.**
  - **Line:** `Train <stem>/<lane> · step k of n · borg link <repo>`, between whole-line `<!-- borg:train:begin -->` / `<!-- borg:train:end -->` markers outside fences.
  - **Markers:** on the first publish there is no pair yet, so the block is inserted at the top. That is the one case where zero pairs is expected. It refuses on several pairs or unbalanced markers.
  - **Check:** it refuses for a repo not on the allowlist. It takes membership from the same targeted search `borg link` uses (see Completeness), each hit confirmed by the exact-match parse of its inline body, and refuses when that search is degraded or truncated. A keyed PR merged before the sweep window is listed in the report as outside the window and is not counted. Reconcile runs on rows only: key-only members have no row, so they are checked by the exact-match parse, and `borg_core/reconcile` covers the rows, refusing on any finding and naming each one. `unresolved` refuses only for a ref of a kind this machine can resolve (the `_resolvable_kinds` predicate `add-row` uses: github, or a discovered recon adapter). Rows of other kinds, `link` or any kind with no resolver, are listed in the report and excluded from the refusal. A degraded `gh` publishes nothing and says so.
  - **Idempotent:** a run with no change makes no `gh pr edit`.
  - Verify: pytest on the pure marker splicer; bats proves the second publish makes zero edits, a contradiction or unresolved github fixture refuses with zero edits, an unlisted repo refuses, a lane holding a `link` row still publishes, a degraded or truncated search refuses, a keyed PR beyond the sweep's 30-PR horizon is counted by both `publish` and `borg link` on the same stub, so the published `n` equals the count `borg link` shows, and a keyed PR merged before the window is reported but not counted.
  - This criterion carries no Evidence pin: its Verify spans the splicer's pytest file and the bats file, so it reads unknown until `/borg-assimilate` checks it.
- [ ] **AC5 — Capture nudge, wired.** An optional PostToolUse hook on `gh pr create` only nudges, through a JSON `systemMessage`, when a trusted author's PR in a repo that has a manifest and is on the allowlist carries no `- Train:` key. The allowlist scope is restored deliberately: a nudge asks a person to write a key, so it is limited to repos this machine publishes for, while rendering still runs for every registered repo. `/borg-link-up` proposes the key line for the current PR. A wiring test like `tests/dispatch_guard.bats` proves the registration.
  - This criterion carries no Evidence pin: it covers the hook and the `/borg-link-up` skill, so it reads unknown until `/borg-assimilate` checks it.
- [ ] **AC6 — Nothing breaks.** `make test && make test-bats && make lint` are green. This criterion is a conjunction, so it deliberately carries no Evidence pin and reads unknown until `/borg-assimilate` checks it.

No criterion carries an Evidence pin. A pin ticks the whole box when its file passes, so one is kept only where a single file covers the whole criterion, and none does.

## Scope Boundaries

- NOT building: any cache or persisted train file, an apex issue, a deploy train, or a stored owner.
- NOT building: projection into other systems (see "Standing rules").
- NOT building: the `merge-tree` repoint (owned by `2026-08-31-retire-merge-tree-programs-into-borg-core`).
- NOT building: manifest creation outside `/borg-plan`.
- If done early: ship, don't expand.

## Ship Definition

Per criterion: PR opened, CI green, `/borg-verify` PASS, merged. After that, this repo's allowlist entry goes live, one real train is published by hand, and `borg link` is checked against it by eye.

## Timeline

About five sessions of about two hours:
1. AC1.
2. AC2.
3. AC3.
4. AC4.
5. AC5 and AC6, plus a buffer.

## Risks

- **Search cost.** Each non-local `borg link` runs one search per repo that has a manifest. Bodies come back inline, so there is no per-hit fetch, and the search adds a `gh` call only where no targeted fetch runs (see Completeness). Mitigation: parse the two keys in the search path and keep the fields bounded; AC2's bats asserts that no body text leaks.
- **Few keys at first.** Nothing has keys until authors write them. Mitigation: the AC5 nudge plus the `/borg-link-up` proposal.
- **An empty allowlist looks like a bug.** It is fail-closed, so a missing file means nothing publishes. Mitigation: `borg doctor` prints the allowlist path and count, and `publish` names the file when it refuses.
