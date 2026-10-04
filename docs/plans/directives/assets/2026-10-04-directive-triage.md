# Directive triage — 2026-10-04

Scope: every file in `docs/plans/directives/` except `README.md` and `assets/`: 31 markdown directives plus one companion JSON (`2026-08-18-program-manifests-stack.json`). Applied the shipped-unarchived rubric of `2026-08-20-directive-state-deriver.md` by hand: merged PRs (`gh pr list --state merged`), the artifacts on main, git log, checkpoint and CLAUDE.md mentions, and later rulings (#238, One Front Door, State Hygiene). Slugs below drop the date prefix. Nothing was deleted. `viz-3` is not moved: `PROJECT_PLAN.md` points `*Next:*` at it. No directive was SUPERSEDED with direct evidence, so `severed/` is untouched.

| slug                        | class       | evidence               |
|-----------------------------|-------------|------------------------|
| usage-guardian-build        | NEEDS NOAH  | live-cap run, arming   |
| cairn-decommission          | PARTIAL     | 25 of 32 ticked        |
| briefing-fallback           | PARTIAL     | 4 of 8 ticked          |
| attention-routing           | KEEP        | hooks unchanged        |
| link-unification-layout     | PARTIAL     | L1,L2 ticked; #137/#138 |
| viz-3-cross-repo-chains     | KEEP        | Next: target; 0 of 9   |
| chained-auto-promotion      | PARTIAL     | AC1-3,5 ticked; #151   |
| deployed-artifact-drift     | KEEP        | no check exists        |
| severed-in-link-document    | NEEDS NOAH  | way back undecided     |
| program-manifests-edge      | NEEDS NOAH  | #158 + PM11 gated      |
| program-manifests-stack     | NEEDS NOAH  | json; follows parent   |
| comms-delivery-surfaces     | KEEP        | no borg show; 1 of 10  |
| communication-program       | KEEP        | umbrella; kids open    |
| directive-state-deriver     | KEEP        | D1-D4 absent           |
| security-audit-remediation  | SHIPPED     | #161; AC1-7            |
| orchestrator-drone-handoff  | KEEP        | hail lacks section     |
| auto-memory-gate            | NEEDS NOAH  | gate now PASS          |
| project-to-repository-rename | KEEP        | no inventory           |
| retire-mt-programs          | KEEP        | programs.py live       |
| retire-the-line-pin         | KEEP        | no ban, no CI          |
| shim-architecture           | PARTIAL     | 1 of 7 ticked          |
| refuse-the-manifest         | KEEP        | salvage still live     |
| structured-storage          | NEEDS NOAH  | its own Q6             |
| session-load-eval           | KEEP        | no evals/session-load  |
| link-up-criteria            | SHIPPED     | #198; AC1-9            |
| extension-loader            | SHIPPED     | #206                   |
| worktree-identity           | PARTIAL     | Option A shipped #233  |
| evals-for-everything        | NEEDS NOAH  | #251/#253 vs status    |
| retire-merge-tree-board     | KEEP        | filed 10-03; R1-R5     |
| setup-symlink               | SHIPPED     | #261                   |
| scope-120-column-rule       | NEEDS NOAH  | #260 vs global file    |
| stop-hook-warnings          | NEEDS NOAH  | AC5 manual render      |

## Moved to `assimilated/` (SHIPPED)

- security-audit-remediation: SA1-SA6 landed in PR #161 (commit b776819, which carried the fix with the filing). Evidence on main: `borg.zsh` version floors (gh 2.97.0; `gh --version` here is 2.98.0), `hooks/bash-guard.sh` gh/docker allowlists with `tests/bash_guard.bats` cases for `gh pr merge`, `gh repo delete`, `docker rm`, `skills/borg-link-up/SKILL.md` "Quoting external text (SA3)", `hooks/borg-link-down.sh` SA3 line, `hooks/tool-count-nudge.sh` (no `/tmp`), `borg.zsh` SA5 stdin path, `merge-tree/app/requirements.txt` exact pins. AC7 rests on the commit's recorded bats pass.
- link-up-criteria-reconciliation: PR #198 "evidence-gated plan-state deriver, writer, and the link-up wiring (AC1-AC9)" merged 2026-09-15. `borg_core/planstate/` with `test_evidence.py`, `test_write.py`, `test_security.py`; `skills/borg-link-up/SKILL.md` has the step, the "If absent, skip" guard and `## Criteria Reconciled`. AC5 caveat: the literal "assimilate unchanged" verify clause was true of #198 only; later PRs edited the assimilate skill for other reasons and none weakened it. Because `borg_core/planstate/test_evidence.py` opened this file by path (and skips silently when absent), that path and the `docs/planstate.md` links and one docstring were repointed in the same PR.
- extension-loader-and-prefer-tool: PR #206 (commit 1ae5274) shipped `borg_core/extensions/`, `docs/extensions.md`, the `prefer-tool` type with `requires`, the `hooks/borg-prefer-tool-log.sh` oracle with `tests/prefer_tool_log.bats`, and the skill hook points. CLAUDE.md documents it as shipped. The file carried no checkboxes, so none were ticked.
- borg-setup-replaces-claude-md-symlink: PR #261 (2026-10-04) shipped `lib/claude-md.zsh` and `tests/claude_md.bats` (8 cases), the exact code and tests the file names. No checkboxes.

## Partial: boxes ticked or status note added (evidence cited in the file)

- link-unification-and-layout: ticked L1, L2 (`skills/borg-link/SKILL.md` runs `borg link --json` and has `## Fallback`; `python3 -m borg_core.link.cli --json` yields `projects` and `generated_at`). L3 and L5 not evidenced.
- chained-auto-promotion: ticked AC1, AC2, AC3, AC5 (Step 4c at `skills/borg-assimilate/SKILL.md`; README carries both metadata lines; `tests/promote_next.bats` has 20 cases, 2 dangling; the two fixed strings are present). AC4 deferred and now moot; AC6 not re-run.
- shim-architecture: ticked the "documented once" criterion (CLAUDE.md "THE SHIM LAYER"; `shim:` cases in `tests/prose_contracts.bats`). The rest wait on the `borg reconcile` verb and `merge-tree/programs.py`.
- worktree-identity-and-apex-stacks: status note only (no checkboxes). Option A shipped in #233.
- cairn-decommission and briefing-fallback: already carry accurate status notes and ticks from earlier reconciliations; re-verified, unchanged. For briefing-fallback, tab-IFS `read` loops still exist (`bin/borg-notifyd`, `bin/borg-cortex-watch`), so that criterion stays open.

## Kept untouched, with the reason

- attention-routing: `hooks/tool-count-nudge.sh` still counts raw calls and `pre-commit-remind.sh` is unconditional. The #258/#259/#263 systemMessage work fixed delivery, not the nudges.
- viz-3: `*Next:*` target of `PROJECT_PLAN.md`; State Hygiene is its gate.
- deployed-artifact-drift-check: no drift check exists in `borg.zsh`, `scripts/` or `tests/`.
- comms-delivery-surfaces: no `borg show` verb; `borg chain` exists but AC2 names `borg chains`; only AC4 ticked, as filed.
- communication-program: umbrella; both children are open.
- directive-state-deriver: `resolve_since` still passes relative forms through (`borg_core/recon/core.py`), no classifier module. This report is a manual run of it.
- orchestrator-drone-handoff: the `== ORCHESTRATION MODEL ==` block at `borg.zsh` has no drone section.
- project-to-repository-rename: no site inventory exists; `.borg-project` decision not recorded.
- retire-merge-tree-programs: `merge-tree/programs.py` still exists and the board-retirement directive lists it as live.
- retire-the-line-pin: no ban in CLAUDE.md Style Rules and no CI step.
- refuse-the-manifest: `borg_core/manifest/shell.py` `_drop_invalid_rows` still salvages; the assimilated degrade file has no pointer to it.
- session-load-eval: no `evals/session-load/`.
- retire-the-merge-tree-browser-board: filed 2026-10-03, inventory only.

## Questions for Noah (NEEDS NOAH)

1. usage-guardian-build: Phase 1, the sweep and the dispatch guard are built but ship OFF, and the one live-cap validation never ran. Arm and validate, or sever the remainder and call the built parts done?
2. severed-in-link-document: `borg link` still renders no severed section (way 1) and `borg sever` has no readback (way 2). Which way, or is the record itself the deliverable and the file should be archived?
3. program-manifests-as-borg-edge-source: PM1-PM10 shipped as #158 and were later renamed to chains and ported into `borg_core`; PM11 hook wiring was gated on attention-routing. Archive as shipped with PM11 severed, or keep PM11 alive? The companion `-stack.json` moves with whatever you choose.
4. auto-memory-gate-measures-the-wrong-thing: `~/.local/state/borg/memory-gate.log` shows FAIL from 2026-08-12 and PASS (ratio 0.600) on 2026-10-04, while the file argues the numerator cannot see the dominant path. Fix the numerator, retire the gate, or accept PASS? Cairn's last two criteria wait on this.
5. structured-storage: the file says to sever it if question 6 has no measurable answer. Is there one?
6. evals-for-everything: header says Phase 1 awaits your go, but #251 (Phase 0 spike) and #253 (coverage ledger and selector) merged on 2026-10-04. Is it in flight, and should the status line change?
7. scope-the-120-column-rule: #260 and #265 merged, but the global `~/.claude/CLAUDE.md` still states the old 120 rule (W2), and W7/W8 live in other repos. Accept as done and archive?
8. stop-hook-warnings-are-invisible: ACs 1-4 and 6 have bats coverage (`tests/lifecycle.bats`, including the dedupe cases). AC5 is a manual look: did the `systemMessage` warning actually render in a real Stop? If yes, archive.
9. Also decide (not blocking): attention-routing is still wanted? The Stop-hook channel fix partly overlaps its A1/A2. And chained-auto-promotion AC4 is moot: archive it as shipped with AC4 withdrawn?

## Counts

SHIPPED 4 (moved), SUPERSEDED 0, PARTIAL 6 (2 unchanged, 4 annotated), KEEP 13, NEEDS NOAH 9 (includes the companion JSON). Total 32 files, of which 31 are markdown directives.
