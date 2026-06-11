# Flow-to-test traceability matrix

Each row maps a major observable behaviour to the BATS suite(s) that exercise it.
"Smoke" = `cli_smoke.bats` (CLI entry points, help, error paths).

| Flow | Covering suite(s) |
|------|-------------------|
| `borg next` / priority scoring | `cli_smoke.bats` (help/command-list smoke), `reap.bats` (session-reap predicate that feeds scoring) |
| `borg switch` / fzf picker dispatch | `cli_smoke.bats` (help/command-list smoke) |
| Lifecycle hook link-down (`borg-link-down.sh`) | `lifecycle.bats` (start hook: sets active, injects context, resolves project, orchestrator mode) |
| Lifecycle hook link-up (`borg-link-up.sh`) | `lifecycle.bats` (stop hook: sets idle, uncommitted-change tracking, orchestrator mode guard) |
| Session notify hook | `lifecycle.bats` (notify hook in orchestrator mode guard), `session_mode.bats` |
| Orchestrator-mode separation | `session_mode.bats`, `lifecycle.bats` (orchestrator-mode tests) |
| Plugin hook de-dup (`_borg_unregister_hook`) | `plugin_dedup.bats` (B2: remove matching, preserve co-located, no-op when absent) |
| Plugin build self-containment (`build-plugin.sh`) | `plugin_dedup.bats` (B1: idempotent, no borg-hooks.sh source refs, hooks.json structure) |
| Nanoprobe log (`borg-nanoprobe-log.sh`) | `nanoprobe.bats` (append to agents.jsonl, required fields, evidence gate scoring) |
| Nanoprobe worktree reaper (`borg reap-worktrees`) | `reap_worktrees.bats` (stale predicate, age-expired, merged-branch, uncommitted-changes guard) |
| Session reaper (`_borg_should_reap` / `borg_reap_overlay`) | `reap.bats` (keep/reap predicates, overlay filter) |
| Registry CRUD | `registry.bats`, `state.bats` |
| Morning briefing (`borg link --brief`) | `briefing.bats` |
| cairn integration | `cairn.bats` |
| Claude session discovery | `claude.bats` |
| Drone lifecycle hooks (pre-up / post-down) | `drone_hooks.bats` |
| Supabase scaffold (`drone scaffold --supabase`) | `scaffold_supabase.bats` |
| Plan auto-promote (`borg-plan-promote.sh`) | `plan_promote.bats` |
| Bash guard (borg-guard.sh) | `bash_guard.bats` |
| Secret store | `store_secret.bats` |

## Coverage gaps

- `borg next --switch` (the tmux window-jump path) has no dedicated integration test; tmux
  interaction is not currently stubbed. The command is smoke-tested via help output only.
- `borg switch` fzf picker interaction is not exercised (requires a tty + fzf); untestable in
  headless BATS. Covered by manual smoke test after each release.
