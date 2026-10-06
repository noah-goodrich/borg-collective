# Directive triage — 2026-10-04

Scope: every file in `docs/plans/directives/` except `README.md` and `assets/`: 31 markdown directives plus one companion JSON (`2026-08-18-program-manifests-stack.json`). Applied the shipped-unarchived rubric of `2026-08-20-directive-state-deriver.md` by hand: merged PRs (`gh pr list --state merged`), the artifacts on main, git log, checkpoint and CLAUDE.md mentions, and later rulings (#238, One Front Door, State Hygiene). Slugs below drop the date prefix. Nothing was deleted. `viz-3` is not moved: `PROJECT_PLAN.md` points `*Next:*` at it. No directive was SUPERSEDED with direct evidence in the first pass. Noah then decided the nine open questions on 2026-10-04; those decisions are recorded below and applied in the same PR (#266), so the table shows final classes.

| slug                        | class       | evidence               |
|-----------------------------|-------------|------------------------|
| usage-guardian-build        | KEEP        | arm, tune later        |
| cairn-decommission          | PARTIAL     | 25 of 32 ticked        |
| briefing-fallback           | PARTIAL     | 4 of 8 ticked          |
| attention-routing           | SEVERED     | superseded by #257     |
| link-unification-layout     | PARTIAL     | L1,L2 ticked; #137/#138 |
| viz-3-cross-repo-chains     | KEEP        | Next: target; 0 of 9   |
| chained-auto-promotion      | SHIPPED     | AC4 withdrawn; AC6 green |
| deployed-artifact-drift     | KEEP        | no check exists        |
| severed-in-link-document    | KEEP        | one count line         |
| program-manifests-edge      | SHIPPED     | #158; PM11 withdrawn   |
| program-manifests-stack     | SHIPPED     | json; moved with parent |
| comms-delivery-surfaces     | KEEP        | no borg show; 1 of 10  |
| communication-program       | KEEP        | umbrella; kids open    |
| directive-state-deriver     | KEEP        | D1-D4 absent           |
| security-audit-remediation  | SHIPPED     | #161; AC1-7            |
| orchestrator-drone-handoff  | KEEP        | hail lacks section     |
| auto-memory-gate            | KEEP        | accept PASS 0.600      |
| project-to-repository-rename | KEEP        | no inventory           |
| retire-mt-programs          | KEEP        | programs.py live       |
| retire-the-line-pin         | KEEP        | no ban, no CI          |
| shim-architecture           | PARTIAL     | 1 of 5 ticked          |
| refuse-the-manifest         | KEEP        | salvage still live     |
| structured-storage          | SEVERED     | Q6 unanswerable        |
| session-load-eval           | KEEP        | no evals/session-load  |
| link-up-criteria            | SHIPPED     | #198; AC1-9            |
| extension-loader            | SHIPPED     | #206                   |
| worktree-identity           | PARTIAL     | Option A shipped #233  |
| evals-for-everything        | KEEP        | in flight; #251/#253   |
| retire-merge-tree-board     | KEEP        | filed 10-03; R1-R5     |
| setup-symlink               | SHIPPED     | #261                   |
| scope-120-column-rule       | SHIPPED     | #260/#265 + 5 PRs      |
| stop-hook-warnings          | KEEP        | AC5: Noah watching     |

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

## Decisions (Decided by Noah 2026-10-04)

1. usage-guardian-build: KEEP. Arm the sweep and the dispatch guard with current thresholds to collect near-cap data; tune later. No code defaults changed here: arming is a machine-local config step.
2. severed-in-link-document: KEEP as the decision record. No severed section; `borg link` shows one count line (e.g. "3 severed this month"); the files remain for manual review. Implementation is a separate PR, tracked as criterion SV1 in the file.
3. program-manifests-as-borg-edge-source (+ companion stack.json): PM11 withdrawn (superseded by the personal-repo stamper plan); moved to `assimilated/` as shipped via #158 (PM1-PM10). The json moved with it.
4. auto-memory-gate-measures-the-wrong-thing: accept the 2026-10-04 PASS (0.600; 11 of 12 reads from one project) and keep watching; revisit if it falls below 0.2. Left in place: the numerator investigation, re-nag policy and suite criteria are still open.
5. structured-storage-for-borg-generated-artifacts: SEVERED. Its own question 6 has no measurable answer; State Hygiene resolved the concrete problems.
6. evals-for-everything: status line changed to in flight (Phase 0 #251 and ledger/selector #253 shipped; Phase 1 evals next).
7. scope-the-120-column-rule: moved to `assimilated/` as shipped (#260, #265, claude-plugins#62/#63, dotfiles#20/#21/#22; live 2026-10-04).
8. stop-hook-warnings-are-invisible: left open; note "AC5: Noah watching for the live render".
9. attention-routing: SEVERED, superseded by the #257 communication research (how borg communicates). chained-auto-promotion: AC4 withdrawn (the viz chain was retired by #238); AC6 re-run green (`make test-bats`), so moved to `assimilated/`.
10. Next plan: the personal-repo PR-stack stamper (shim-architecture directive section 4), the source of truth for personal/stillpoint repos. It replaces program-manifests PM11.

Moves this round (all `git mv`, nothing deleted): program-manifests-as-borg-edge-source, program-manifests-stack.json, scope-the-120-column-rule and chained-auto-promotion to `docs/plans/assimilated/`; structured-storage and attention-routing to `docs/plans/severed/` (each with a front-matter Reason). The stack.json path was repointed in `docs/research/2026-08-31-plugin-coexistence/recommendation.md` and `docs/plans/assimilated/2026-09-12-ac5-lifecycle-skills-author-manifests.md`; the directives README now points at the assimilated chained-auto-promotion file. No test or Python module opens any moved file by path.

## Counts

Final: SHIPPED 8 files moved over both passes (7 markdown plus the companion json), SEVERED 2, PARTIAL 5 (2 unchanged, 3 annotated), KEEP 17, NEEDS NOAH 0. Total 32 files; 22 remain in `docs/plans/directives/`.
