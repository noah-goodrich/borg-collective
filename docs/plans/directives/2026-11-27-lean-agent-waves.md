# Directive: Lean agent waves: the same PRs for 30% of the cost
*Filed: 2026-11-27*

- Plan-slug: `2026-11-27-lean-agent-waves`
- Status: locked 2026-11-27

tl;dr: One two-day multi-agent wave (borg-collective session e414a487, Nov 25-27) opened 14 PRs for about $58.48, or $4.18 per PR. 37% of that was agents rewriting their whole context to the prompt cache after idling past its 5-minute lifetime. This directive stops agents from waiting, starts fresh agents instead of waking stale ones, and takes routine ship steps out of agent turns. The gate is 30% of the per-PR baseline ($1.25). The levers in this directive are estimated to reach about 40%, so meeting the gate may need the two levers listed under Non-Goals; that trade-off was accepted when the plan was locked.

## Problem

Prices are the token-cost skill's table, with Opus 4.6+ and Sonnet 4.6 rates standing in for 5.5, which it lacks. Main-loop cache writes are priced at the 1-hour rate (2x input) and agent cache writes at the 5-minute rate (1.25x). Transcripts show the main loop wrote only 1-hour cache (732k tokens) and agents only 5-minute cache (5.86M tokens). The gates below use ratios to this baseline, not dollars.

| Measure                   | Value                    |
|---------------------------|--------------------------|
| Requests                  | 780 (59 main, 721 agent) |
| Cost                      | $58.48                   |
| Main loop (Opus)          | $14.50 (25%)             |
| Agents (Sonnet, 1 Haiku)  | $43.98 (75%)             |
| PRs opened                | 14 (5 merged, 9 open)    |
| Cost per PR               | $4.18                    |
| Cache reads               | about $24 (41%)          |
| Cold rewrites (>40k)      | $21.54 (37%)             |
| Agent requests per PR     | about 52                 |
| Agent context per request | about 115k on average    |

Cold rewrites by cause, using the gap since the same transcript's previous request:

| Cause                           | Count | Cost  |
|---------------------------------|-------|-------|
| Woken after hours or days       | 11    | $8.76 |
| Idle 7-25 min after a tool call | 21    | $7.17 |
| Waiting on CI                   | 11    | $4.57 |
| Compaction or first request     | 2     | $1.04 |

- **Woken:** six agents got SendMessage two days after a usage limit stopped them. Each rewrote 89k-157k on its first request.
- **Idle after a tool call:** 11 of the 21 followed a local test run, and eight agents ran the full coverage suite on one machine at once. The gap is measured from one request's start to the next, so it also includes generation time and any API retries. AC1 replaces this with measured tool-call durations.
- **Waiting on CI:** agents polled `gh pr checks` in `until`/`sleep` loops of up to 590 seconds.

Approximate request cost by activity: tests 22%, grep/sed reads 22%, `gh` 14%, git 13%, CI polling 9%, orchestration 13%, other 7%. Requests that made several tool calls were booked to one of them, so treat these as approximate.

How the code produces this today:
- `lib/borg/resume-prompt.sh:207-213` tells the Queen to SendMessage errored or orphaned agents, and to re-spawn only if one is unreachable. Nothing checks idle time or context size. The hook prints guidance; the Queen model makes the call.
- `agents/borg-nanoprobe.md:111-119` has the agent push and open the PR with `gh pr create`, or with the declared Prefer-tool. CI gating inside the agent came from Queen briefs.
- `Makefile:31-35`: `make test` runs the full pytest suite under coverage with a 90% floor. Nothing runs only the tests for changed files (`eval-changed` at `Makefile:261` does this for evals).
- `borg spend` (`borg.zsh:3189`) reads `token-spend.jsonl`, which is written at SessionEnd, so a live session shows $0.
- `borg_core/manifest/cli.py:429` `resolve` is read-only: it picks a manifest and does not repair `.stacks` merge conflicts. Agents fixed those by hand with `git checkout --theirs` and re-adding their row.

## Solution

1. **Live cost report.** `borg spend --session <id>` reads a session's main and subagent transcripts while it runs. It reports cost (5-minute and 1-hour cache writes priced separately), requests, PRs opened, cold rewrites by cause from measured tool-call durations, requests per PR, and average agent context.
2. **Agents never wait.**
   - The nanoprobe pushes, opens the PR, returns the PR number and head SHA, and ends. It never polls CI.
   - It runs `make test-changed` and leaves the full suite to CI.
   - It does one PR per spawn, and hands back with a progress note at 40 tool calls.
   - The Queen runs one batched `borg pr gate` for the wave as a background command. It wakes once per wave, inside its 1-hour cache, and spawns a fresh nanoprobe for any CI fix.
3. **Fresh spawn, not wake.** The resume path reads each stopped agent's last timestamp and last context size from `subagents/agent-<id>.jsonl`. An agent idle more than 5 minutes with more than 60k context gets a definite instruction to spawn fresh from `borg probe brief <id>`: the original task, branch, commits since base, PR state and the latest progress note. Smaller or recent agents still get SendMessage.
4. **`borg probe ship <worktree>`.** One command adds the stack row, commits, pushes, and opens or reuses the PR through the REST API, or through the declared Prefer-tool when one replaces `gh pr create`. If a rebase hits a `.stacks/*.json` conflict, it takes main's version and re-adds this PR's row. It prints the PR number and SHA.

## Acceptance criteria

- [ ] AC1. Live report as described in Solution 1.
  - Verify: `python3 -m pytest borg_core/spend` passes against an archived, trimmed fixture with hand-computed totals. PR detection parses PR-create output and is cross-checked against `gh pr list`. Run on e414a487, it reports $58.48 (within 2%) and a 37% cold share (within 2 points).
- [ ] AC2. The nanoprobe brief and the Queen's orchestration text (`borg.zsh:1966`) carry the rules in Solution 2, and `make test-changed` exists.
  - Verify: a bats contract test asserts the built `agents/borg-nanoprobe.md` has the rules and no `gh pr checks` instruction. On a branch touching one `borg_core` module, `make test-changed` runs only that module's tests.
- [ ] AC3. The resume path follows Solution 3. The decision is a pure function of idle minutes and context tokens, and the hook prints its result for each agent.
  - Verify: a unit test covers all four cases of idle (above or below 5 minutes) by context (above or below 60k). A bats test shows `resume-prompt.sh` prints the spawn instruction for an idle, large agent fixture and SendMessage for a recent, small one.
- [ ] AC4. `borg probe ship` works as Solution 4 describes and is idempotent: a second run prints the same PR and opens no duplicate.
  - Verify: pytest with a temporary bare remote and a stubbed `gh api`, including a `.stacks` conflict case and a Prefer-tool case.
- [ ] AC5. The next wave of 5 or more PRs, measured with AC1, meets every gate:
  - cost per merged PR at most $1.25 (30% of $4.18)
  - agent cold rewrites at most 10% of cost
  - zero CI-wait rewrites
  - median agent requests per PR at most 26
  - average agent context at most 75k
  - The Queen's overhead and the median PR diff size are reported alongside, so splitting PRs can't game the per-PR gate.
  - Verify: the `borg spend --session <id>` output, recorded under Decisions.
- [ ] AC6. Nothing regresses: `make test` (coverage at least 90%), `make test-bats` and the resume_hook bats suite pass, the #480 trigger suites pass on the rebuilt plugin, and a wave still ends with /borg-verify PASS and `borg pr merge-train`.
  - Verify: CI green on every PR, plus `borg pr merge-train --dry-run <n>` on one PR.

## Testability

- **AC1:** the core is a pure function from parsed usage records to a report, in `borg_core/spend/`, tested with fixtures. The CLI is a thin shell around it.
- **AC3:** the decision is a pure function from (idle minutes, context tokens) to wake or spawn, with unit tests. `resume-prompt.sh` only gathers the two inputs and formats the result. Existing test coverage of the `resume-prompt.sh` SendMessage path is unknown; measure it before refactoring.
- **AC4:** the core plans the steps (row, commit, push, PR, conflict repair) as data and is tested without git. Shell and `gh` calls are a thin layer, tested against a temporary remote.
- **AC2:** text and Makefile changes, covered by a contract test and one `make test-changed` run.
- **New modules ship with tests in the same commit**, per this repository's CLAUDE.md.

## Non-Goals

- A saved borg-wave workflow. Follow-up, once AC5 shows what cost remains.
- Haiku scouts in place of Sonnet grep/sed exploration (22% of request cost). This is one of the two levers likely needed to reach the 30% gate. Adding it means a scope change.
- A context ceiling for the Queen main loop (25% of cost). This is the other lever likely needed for 30%.
- Moving the main loop off Opus.
- A cap on concurrent agents. It spreads cost across windows and does not reduce it.
- Changing the SessionEnd token-cost writer.

## Alternatives Considered

- **Concurrency cap or wave scheduler.** It would have prevented the Nov 27 morning wipeout, but total cost stays the same. `borg-dispatch-guard` (off by default) already blocks new dispatch at 92% usage or more.
- **Serialize full-suite runs with a lock.** It fixes contention, but agents would wait longer and pay more cold rewrites. Changed-file tests plus CI is cheaper.
- **A Workflow for every wave.** It gives a fresh context per PR and resume through `resumeFromRunId`. But workflow scripts cannot run shell, so CI gates still need an agent. Deferred until after AC5.
- **Compact before waking.** It still pays a rewrite of the compacted context, plus the compaction itself.
- **Haiku for whole nanoprobes.** Cheaper per token, but implementation needs judgment. The ship verb takes the mechanical steps out of agents instead.

## Ship definition

Each AC lands as its own PR. Each PR passes CI, gets a /borg-verify PASS and merges through `borg pr merge-train`. Agent, skill and hook changes are rebuilt with `scripts/build-plugin.sh` and committed in claude-plugins with a VERSION bump. AC5 is measured on the first real wave after AC1-AC4 merge.

## Risks

- **Changed-file tests let regressions through to CI,** which means extra fix spawns. AC1 reports the CI first-pass rate.
- **A fresh spawn loses reasoning the old agent never wrote down.** The 40-tool-call progress note and `borg probe brief` must carry it.
- **The checked-out claude-plugins branch is live config for every session,** so a bad brief breaks all agents at once. AC6 runs the #480 trigger suites on the rebuilt plugin.
- **Open PRs #551, #553 and #554 touch the same agent, hook and plan files.** Merge them first, or rebase onto them.
- **The price table lacks 5.5 rows.** The gates are ratios to a baseline priced with the same table.
- **The 30% gate may not be met with these levers alone** (estimate: about 40%). If it isn't, either change scope to add the Non-Goals levers or file a follow-up directive.

## Scope changes

None yet.

## Decisions

- 2026-11-27: Independent directive, with no parent plan. The active evals plan (`2026-10-30-evals-and-description-hillclimb`) is unrelated.
- 2026-11-27: AC5 gates on 30% of the per-PR baseline, accepting the risk above.
- 2026-11-27: Thresholds for AC3: idle more than 5 minutes and context more than 60k. Hand-back budget: 40 tool calls.
- 2026-11-27: Baseline re-priced with 1-hour main-loop cache writes: $58.48, up from $55.74 at 5-minute pricing.
