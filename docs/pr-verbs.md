# borg pr: gate and merge-train

Two named verbs replace the recurring ad-hoc `gh pr checks | ...` and merge pipelines. Both shell out to `gh` with argv lists, print one human summary line to stderr, print JSON to stdout when `--json` is given or stdout is not a TTY, and carry the verdict in the exit code. Code: `borg_core/gh/`.

## borg pr gate <n> [--repo R] [--wait] [--timeout S] [--json]

Reads the check rollup and reports `{n, head, state, verdict, checks:{pass, fail, pending, cancelled_no_runner}, failing}`.

- 0 green (all checks succeeded, skipped or neutral)
- 1 failing (including a job cancelled after it started)
- 2 pending, or `--wait` reached its ceiling (default 1800 seconds)
- 3 cancelled without ever getting a runner (needs a rerun, not a fix)
- 64 usage or `gh` error

## borg pr merge-train <n...> [--repo R] [--method squash] [--dry-run] [--yes]

Per PR, in the order given: update-branch (rebase) if behind, wait for checks, rerun a runner-less cancellation at most once, then `gh pr merge --squash --delete-branch --match-head-commit <head>`. It stops at the first problem and later PRs are not touched. The stdout report is a list of `{n, action, result, head}` entries (merge entries also carry `merge_sha`), where `action` is one of `update-branch`, `wait`, `rerun`, `merge`.

- 0 every PR merged
- 1 a check is failing
- 2 checks still pending at the timeout
- 3 cancelled without a runner a second time
- 4 merge conflict (the PR is named on stderr)
- 5 the head moved between the gate and the merge; `--match-head-commit` refused, so re-gate
- 64 usage or `gh` error, or stdin is not a TTY and `--yes` was not given

`--dry-run` prints the plan and issues no mutating `gh` call.

## Who may run merge-train

`merge-train` merges. Only a human or the orchestrator main loop may run it. Workflow agents and nanoprobes must never call it: merge steps inside workflows are refused, and the authority to merge is not theirs. There is no `BORG_AGENT_CONTEXT` variable in this repo, so the rule is enforced by documentation, the verb help, and the non-TTY `--yes` requirement rather than by a refusal. `gate` is read-only and safe for any caller.
