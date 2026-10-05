# Directive: Personal-repo PR trains — derived at render time, published by hand
*Filed: 2026-10-04 · Revised: 2026-10-05 after two reviews on noah-goodrich/borg-collective#271*

This is a directive, not a plan. It becomes `PROJECT_PLAN.md` only through `borg start` once accepted, so that no tooling (`manifest.cli resolve`, `/borg-link-up`) aims at it while it is on hold.

## Objective

borg derives which PRs form a train, and in what order, from keys the PR author already writes. It derives at render time, in the same clean read `borg link` already does, with no cache. `borg link` shows the full train for every registered repo. On repos this machine publishes for, a person can write one stable pointer line into each PR body, after a check against GitHub.

## Why

- **Execution in personal repos has no source of truth.** Rows reach `.borg/chains/*.json` only when `/borg-link-up` runs `add-row` (whose documented form exited 2 until noah-goodrich/borg-collective#272). As a result, 2 of 3 manifests on this machine are empty.
- **Triage questions arrived without provenance.** Nothing linked a PR to the directive and criterion it serves.
- **Capture must be derived, never volunteered.** This is cairn's lesson (CLAUDE.md, Learned). Both reviews kept that half of the original plan.

## Standing rules this directive keeps

- **One Front Door AC1, "No cache, ever — a clean read every time"** (pinned in `tests/link_sweep.bats`), and **viz-3 X7 plus ruling 2**: chain data derives from `.borg/chains/*.json` plus the live sweep. There is no new persisted file and one edge source. Trains are a *view* computed from those two inputs, never stored.
- **The 2026-09-22 lifecycle split:** `/borg-plan` creates manifests, `/borg-link-up` adds rows, and nothing here creates a manifest.
- **Publication is never automatic.** The noah-goodrich/borg-collective#266 triage withdrew PM11 in favour of this directive, so the rule is restated here as this directive's own: rendering and auditing run unprompted, and anything that writes to GitHub runs only when a person types it. No hook may trigger it.
- **Projection into other systems is out of scope and outside borg.** borg runs no outbound adapter. Anything that consumes `borg link --json` sits outside borg, is run by its own owner, and exports only the repos that owner declares. The recon adapter tier is inbound only, and `borg link`'s own sweep runs it, so it must never host a consumer of `borg link`.

## Definitions

- **Membership key:** anchored lines in a PR body, matched the way `- Plan-slug:` is: `- Train: <manifest-stem>/<lane>` and, optionally, `- After: <owner/repo#N>`. Only those lines are read; free text is never copied anywhere.
- **Trusted author:** for a same-repo head (not a fork), a PR whose `author_association` is OWNER, MEMBER or COLLABORATOR. Org-owned repos have no OWNER-authored PRs, so MEMBER must count. A key on any other PR, including every fork PR, is ignored and named once in `▸ SIGNALS`.
- **Train:** for one `<stem>/<lane>`, the union of the manifest rows in that lane and the open or recently merged trusted-author PRs that carry the key. A lane named only by keys is valid. Lane validation (`core.lanes()`, `cli._unknown_lane`) governs `add-row`, never membership. A key naming a stem with no manifest is ignored and named in `▸ SIGNALS`.
- **Order:** every declared edge counts, whether it is a row's `after` or a key's `- After:`. Members with no declared edge are ordered by PR number (creation order), and that rule is stated rather than inferred. A non-default base branch *proposes* an edge, shown as a proposal and never used for order. "Step k of n" is the member's position in that order.
- **Publisher:** the machine-local allowlist `${XDG_CONFIG_HOME:-~/.config}/borg/trains.allow` (one `owner/repo` per line) gates *publishing only*. Deriving and rendering run for every registered repo on every machine. A repo worked from two machines appears in exactly one machine's allowlist.

## Acceptance Criteria

- [ ] **AC1 — Pure derivation.** `borg_core/train/core.py` turns manifest rows plus swept PR facts into trains under exactly the Definitions above: key parsing, the trusted-author gate, order and proposals. It does no I/O, and an AST import-walk test pins that purity.
  - Verify: pytest cases cover:
    - an org repo's MEMBER-authored PR joins;
    - an outsider's key and a fork PR's key are ignored;
    - a key-only lane forms a train;
    - `- After:` and row `after` both order;
    - PR-number tie-break;
    - base-branch proposal is never used for order;
    - unknown stem is reported.
  - Evidence: `pytest:borg_core/train/test_core.py`
- [ ] **AC2 — The sweep carries the key, parsed and nothing else.** The GitHub adapter's items gain optional, parsed `train` and `after` fields, plus `author_association` and `is_cross_repository`. They never carry the body. This is an additive item-schema change (expand first). Under `--local`, trains report "unlooked", as `.ready` already does.
  - Verify: bats for the adapter through a `gh` stub; the fixture body contains free text that must not appear anywhere in the adapter output.
  - Evidence: `bats:tests/recon_adapter_github_train.bats`
- [ ] **AC3 — `borg link` draws trains at render time.** CHAINS renders trains from the live grid with the ratified glyphs and render-time routing, and writes no file. `tests/link_sweep.bats`'s no-cache assertions stay green unchanged. A repo with no keys and no rows renders byte-identically to before.
  - Verify: a hand-authored golden for a two-lane fixture that has a key-only member; a byte-identity test for a fixture with no trains.
  - Evidence: `pytest:borg_core/link/test_trains.py`
- [ ] **AC4 — `borg train publish` writes one pointer line, by hand, after a clean check.**
  - **Line:** `Train <stem>/<lane> · step k of n · borg link <repo>`, between whole-line `<!-- borg:train:begin -->` / `<!-- borg:train:end -->` markers outside fences.
  - **Markers:** on the first publish there is no pair yet, so the block is inserted at the top. That is the one case where zero pairs is expected. It refuses on several pairs or unbalanced markers.
  - **Check:** it refuses for a repo not on the allowlist. It runs `borg_core/reconcile` over every member, key-only members included, and refuses on any finding, `unresolved` included, naming each one. A degraded `gh` publishes nothing and says so.
  - **Idempotent:** a run with no change makes no `gh pr edit`.
  - Verify: pytest on the pure marker splicer; bats proves the second publish makes zero edits, a contradiction or unresolved fixture refuses with zero edits, and an unlisted repo refuses.
  - Evidence: `bats:tests/train_publish.bats`
- [ ] **AC5 — Capture nudge, wired.** An optional PostToolUse hook on `gh pr create` only nudges, through a JSON `systemMessage`, when a trusted author's PR in a repo that has a manifest carries no `- Train:` key. `/borg-link-up` proposes the key line for the current PR. A wiring test like `tests/dispatch_guard.bats` proves the registration.
  - Evidence: `bats:tests/train_hook.bats`
- [ ] **AC6 — Nothing breaks.** `make test && make test-bats && make lint` are green. This criterion is a conjunction, so it deliberately carries no Evidence pin and reads unknown until `/borg-assimilate` checks it.

Every pinned file above is new. None exists on `main`, so no box can tick before its own work lands.

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

- **Sweep cost.** The adapter now reads PR bodies to parse two keys. Mitigation: parse in the adapter and keep the fields bounded; AC2's bats asserts that no body text leaks.
- **Few keys at first.** Nothing has keys until authors write them. Mitigation: the AC5 nudge plus the `/borg-link-up` proposal.
- **An empty allowlist looks like a bug.** It is fail-closed, so a missing file means nothing publishes. Mitigation: `borg doctor` prints the allowlist path and count, and `publish` names the file when it refuses.
