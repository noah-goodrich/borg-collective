---
id: borg:checkpoint:cairn:20260714-0416-cairn
source: borg
doc_type: checkpoint
project: cairn
slug: 20260714-0416-cairn
title: null
metadata: {}
tags: []
status: active
filed_date: null
shipped_date: null
fs_path: null
body_sha256: db197c8496c0966372542cfd00bc4528184e2aa301ffe76e9523f6a0028dc39b
captured_at: '2026-07-14 04:16:49.701128+00:00'
deleted_at: null
created_at: '2026-07-14 04:16:49.706513+00:00'
updated_at: '2026-07-14 04:16:49.706519+00:00'
---

# borg:checkpoint:cairn:20260714-0416-cairn

## body

## 1. Goal

Land the gated hand-off from the prior checkpoint (ship #26, deploy cairn 0.5.1, reconcile the
synthetic-session guard #75) — which expanded into debugging why checkpoint writes were failing,
reconciling claude-plugins' uncommitted work, removing an orphaned branch, and finally handing the
remaining plugin-guard deploy off to the borg-collective drone.

## 2. Accomplished

- **Corrected a wrong mental model:** `release/0.5.0` was an orphaned duplicate bump (remote gone);
  `main` is truth. Deleted the orphaned local branch.
- **cairn #27** — refreshed `docs/schema.snapshot.sql` for migration 006 (`call_log_id`); greened
  `main`'s drift-check, which had been RED since #22 dropped the snapshot refresh. **Merged.**
- **cairn #26** — assimilate usage-ledger plan, merged clean on the now-passing gate. **Merged.**
- **cairn #28** — release 0.5.1; rebuilt + redeployed the shared `cairn-api` image from `main`.
  Result: `/ready` **200**, `/health` **0.5.1**, `alembic current` **006 (head)**, `/stats/usage`
  clean (~2% artifact gone, no synthetic `/` rows). **Merged + deployed.**
- **Root-caused the failed checkpoint writes:** host `cairn` is a shell shim; the documents store
  (`service.record_document` / `POST /record/document`, v0.2) shipped without a matching `record
  document` CLI case → `unknown record kind: document`. Fixed **both** drifted shims —
  **cairn #29** (canonical `cli/cairn`) + **dotfiles #6** (on-PATH `~/.config/dotfiles/zsh/bin/cairn`).
  Verified live end-to-end (`Recorded document: <id>`, row confirmed + cleaned). **Both merged.**
- **Reconciled claude-plugins "foreign" uncommitted work** — identified it as **stale
  `build-plugin.sh` output**, not precious. Stashed (safety net), rebuilt from borg-collective `main`.
- **borg-collective #75** — fixed the SC2317 lint failure on the synthetic-session guard, **merged.**
- **borg-collective #76** — bumped `VERSION` 0.8.6 → 0.8.8, resolving the plugin/CLI drift
  (claude-plugins had shipped plugin 0.8.7 while VERSION stuck at 0.8.6). **Merged.**
- **claude-plugins PR #33** — clean plugin rebuild (0.8.8, full guard + lint fix); **#32 closed**.
- **Memory:** added `project_cairn_cli_shim_drift`; updated `project_cairn_deploy_migration_ordering`
  with the 006-vs-005 recurrence + the "no v0.5.x tags → local-build only" discovery.

## 3. Ready to Commit

Nothing outstanding for cairn — working tree clean on `main`. `/simplify` verdict was clean this
session (the only hand-written code, the shim `document)` case, mirrors its sibling record cases; no
reusable helper exists). Cross-repo state: dotfiles/borg-collective on `main`; claude-plugins on
`chore/rebuild-plugin-0.8.8` (pushed, PR #33 open). A `git stash` ("stale build output pre-rebuild")
sits in claude-plugins as a droppable safety net.

## 4. Blockers

**claude-plugins PR #33 is blocked on pre-existing red CI** — the `borg-link-down` project-mode
JSON-assembly bug (`jq parse error … column 88`, bats tests 12/14/15), red on `main` since #30/#31.
Orthogonal to the guard. Handed off to the borg-collective drone (checkpoint
`borg-collective/.borg/checkpoints/2026-07-13-2141.md` + directive
`docs/plans/directives/2026-07-13-finish-plugin-guard-deploy.md`). The drone's running session
predates the handoff, so it needs a kickoff keystroke (or a session restart to auto-load it).

## 5. Next Session

The cairn-side work is **done**; the live thread is now in **borg-collective**:

1. **Kick the borg-collective drone** — switch to its tmux window and tell it: *read
   `.borg/checkpoints/2026-07-13-2141.md` and finish it* (fix the `borg-link-down` JSON bug, rebuild,
   green + merge claude-plugins #33, then deploy `claude plugin update borg-collective` + `borg setup`).
   Or restart the session so SessionStart auto-loads the handoff.
2. **Verify pollution stopped** after the plugin deploys: `curl -fsS http://localhost:8767/stats/usage`
   (no `/`/`""` rows) and `docker exec dev-postgres psql -U dev -d cairn -tA -c "select count(*) from
   call_log where query='/' and created_at > now() - interval '30 min';"` → expect 0.
3. **Optional cleanup:** `git -C /Users/noah/dev/claude-plugins stash drop`; prune the ~18 stale
   merged local branches in cairn; push a `v0.5.1` tag to fire `publish-image.yml` so the GHCR image
   becomes pullable (0.5.x deploys have been local-build only — no tags exist).
