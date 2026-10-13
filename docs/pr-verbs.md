# borg pr: gate and merge-train

Two named verbs replace the recurring ad-hoc `gh pr checks | ...` and merge pipelines. Both shell out to `gh` with argv lists, print one human summary line to stderr, print JSON to stdout when `--json` is given or stdout is not a TTY, and carry the verdict in the exit code. Code: `borg_core/gh/`.

## borg pr gate <n> [--repo R] [--wait] [--timeout S] [--json]

Reads the check rollup and reports `{n, head, state, verdict, checks:{pass, fail, pending, cancelled_no_runner}, failing}`.

- 0 green (all checks succeeded, skipped or neutral)
- 1 failing (including a job cancelled after it started)
- 2 pending, or `--wait` reached its ceiling (default 1800 seconds)
- 3 cancelled without ever getting a runner (needs a rerun, not a fix)
- 6 `gh` could not be run, timed out (120 seconds per call), or failed
- 64 usage error (bad flag, non-integer PR, unknown verb)

## borg pr merge-train <n...> [--repo R] [--method squash] [--dry-run] [--yes]

Per PR, in the order given: update-branch (rebase) if behind, then wait until the head differs from the pre-update head and the checks for it are green (an empty check rollup counts as pending for a few polls, since checks may not have registered yet), rerun a runner-less cancellation at most once (a rerun refused because the run is still in progress is retried, not fatal), then `gh pr merge --squash --delete-branch --match-head-commit <head>`. It stops at the first problem and later PRs are not touched. The stdout report is a list of `{n, action, result, head}` entries (merge entries also carry `merge_sha`), where `action` is one of `update-branch`, `wait`, `rerun`, `merge`.

- 0 every PR merged
- 1 a check is failing
- 2 checks still pending at the timeout (`--timeout` is one deadline for the whole train, not per PR)
- 3 cancelled without a runner a second time
- 4 merge conflict, found before update-branch, by update-branch, or at merge time (the PR is named on stderr)
- 5 the head moved between the gate and the merge (`--match-head-commit` refused), or no head commit was known to pin to; re-gate
- 6 `gh` failed, or the merge was refused for another reason (for example a required check missing); the message is on stderr
- 7 the PR is closed without being merged
- 64 usage error, or stdin is not a TTY and `--yes` was not given

`--dry-run` prints the plan and issues no mutating `gh` call.

## Who may run merge-train

`merge-train` merges. Only a human or the orchestrator main loop may run it. Workflow agents and nanoprobes must never call it, because the authority to merge is not theirs. This is a rule, not a gate: nothing in the code refuses an agent. There is no `BORG_AGENT_CONTEXT` variable in this repo, agents run without a TTY, and `--yes` is a documented flag, so the non-TTY `--yes` requirement is a speed bump against accidents, not a barrier. The prohibition has to live in the agent-facing rules and skills. `gate` is read-only and safe for any caller.
