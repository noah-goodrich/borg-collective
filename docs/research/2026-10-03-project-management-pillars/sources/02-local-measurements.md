# Local measurements (personal machine, borg-collective repo only), taken 2026-10-03

Every number below was produced by the command beside it, run from the main checkout. Only borg-collective's own
public artifacts are named. Aggregates over other registered projects are reported unnamed. None of this is a
benchmark; it is a baseline for the next run. `python3 - <<EOF` bodies are summarized, not pasted; the follow-up
directive should turn each into a tested function (see README, section 5).

## Directive / plan lifecycle (files under `docs/plans/`)

- **Open directives (dated .md)** — Value: 28; How: `ls docs/plans/directives/20*.md \| wc -l`
- **Assimilated (shipped) plans** — Value: 60; How: `ls docs/plans/assimilated \| wc -l`
- **Severed (retired)** — Value: 8 (7 dated + 1 audit note); How: `ls docs/plans/severed \| wc -l`
- **Ship : sever among closed** — Value: 60 : 8 (about 88% : 12%); How: counts above
- **Assimilated with BOTH `Established/Filed` and `Shipped` dates** — Value: 32 of 60; How: regex on first 1500 bytes
- **Lead time (Established to Shipped), those 32** — Value: median 1.5 d, mean 5.8 d, p90 17 d, 9 same-day; How:
  python date diff
- **Assimilated plans with no parseable `Shipped:` line** — Value: 27 of 60 (45%); How: regex
- **Open directive age by filename date** — Value: median 41 d; 23 of 28 older than 30 d; max 87 d; How: python,
  `today` = 2026-10-03
- **Acceptance-criteria boxes checked, open directives** — Value: 35 of 156 (22%); How: `^\s*- \[x\]` vs `- \[ \]`
- **Acceptance-criteria boxes checked, assimilated** — Value: 266 of 349 (76%); 83 unchecked boxes inside "shipped"
  plans; How: same
- **`Verify:` lines vs checkbox criteria, all plans** — Value: 335 vs 551 (ratio 0.61, crude: counts lines, does not
  pair them); How: grep
- **Assimilated plans with a Retro/Lessons/Learned heading** — Value: 0 of 60; How: regex `^## (Retro\|Lessons\|...)`
- **Assimilated plans that say scope grew** — Value: 1 of 60; How: `grep -il 'scope (expanded\|grew\|creep)'`

Reading: 45% of shipped plans carry no ship date, so **lead time is only half-captured** and the half that exists is
survivor-biased (plans that remembered to record it). The 76% checked rate on shipped plans fits the 2026-08-20 audit's
finding that boxes under-report completion (see Prior art).

## PR / git history (`gh`, public repo)

- **PRs total / merged / closed-unmerged** — Value: 239 / 227 / 11 (1 open); Command: `gh pr list --state all --limit
  1000 --json number,state,mergedAt`
- **Merge latency (createdAt to mergedAt)** — Value: median 0.74 h, p90 74 h; Command: `gh pr list --state merged
  --limit 1000 --json createdAt,mergedAt --jq '...'`
- **Merged PRs by month (2026)** — Value: Mar 4, Apr 15, May 17, Jun 20, Jul 36, Aug 67, Sep 56, Oct 12 (partial);
  Command: `--jq 'map(.mergedAt[0:7])\|group_by(.)'`
- **Merged PR titles starting `fix`** — Value: 63 of 227 (28%); zero titles containing "revert"; Command: `--jq` regex
  on `.title` (proxy, not a change-fail rate)
- **Commits** — Value: 673 total; weekly peaks 65 to 83 in ISO weeks 33, 35, 36, 38, 40; Command: `git log
  --format=%ad --date=format:%G-W%V \| sort \| uniq -c`
- **Closed-unmerged share** — Value: 11 of 238 closed (4.6%); Command: `gh pr list --state closed`

Reading: throughput rose roughly 4x from spring to late summer; median PR is tiny and fast (consistent with "ship
small"). The tail (p90 74 h) is where WIP hides. `fix`-titled share is a crude instability proxy; DORA's real
metrics (change fail rate, rework) need deploy or incident data borg does not hold.

## Spend (`~/.claude/token-spend.jsonl`, API-equivalent dollars, not billing)

- **Records / span** — Value: 817 session records, 2026-05-26 to 2026-10-02
- **Total est. cost** — Value: about $95k (all projects, all sessions on this machine)
- **borg-collective share** — Value: about $15.6k across 81 sessions (16%)
- **Subagent share of cost** — Value: 20.7% (all projects)
- **Records by end_reason** — Value: 528 other, 147 clear, 123 backfill, 19 prompt_input_exit
- **Records by month** — Value: Apr 1, May 91, Jun 124, Jul 521, Aug 66, Sep 10, Oct 4

Two defects make this unusable for cost-per-shipped-unit today: (1) **September has 10 records against 56 merged
PRs in the same repo**, so the hook is not capturing (or ts is not session time for the backfill rows; 123 are
`backfill`, and the July spike of 521 looks like one); (2) the token-cost skill's "measured ~4% subagents" disagrees
with the 20.7% here. Whichever is right, **cost per shipped criterion cannot be computed until the capture gap is
explained.** Command: `jq -s 'group_by(.project) | map({project:.[0].project, cost:(map(.est_cost_usd)|add)})'
~/.claude/token-spend.jsonl`.

## State-root instruments (`~/.local/state/borg/`)

- `agents.jsonl`: 19 rows; 17 of 19 `zero_commit: true`; 9 of 19 `evidence_found: true`; 17 have empty
  `agent_type`. Mostly this session's own helper agents, so a sample of one session, not a rate.
- `memory-hits.log`: 25 lines; `memory-gate-verdict.json`: **FAIL**, ratio 0.050 reads/session against the
  pre-registered threshold of < 0.2 (checked 2026-10-02). The gate is working; what it reports is that Claude Code
  project memory is barely read.
- `prefer-tool.jsonl`: absent on this machine (not instrumented or no bypass has been logged).
- `usage-samples.jsonl`: 38,703 lines (usage guardian input; the richest time series on the machine).
- Registry: 20 projects in `~/.config/borg/registry.json`; the entries carry no `status` field (status is held in
  per-project `.borg/state.json`), so **WIP over capacity is not recoverable from the registry alone.** Capacity is
  `BORG_MAX_ACTIVE`, default 3, and breaching it prints a warning (borg.zsh `active_count > BORG_MAX_ACTIVE`).
- Checkpoints in this repo: 128 files; by month Apr 24, May 21, Jun 9, Jul 14, Aug 37, Sep 22, Oct 1.
  `## Criteria Reconciled` appears in 4 of them (the planstate reconciliation, shipped recently).

## Prior art inside the repo (reuse, do not redo)

- `docs/research/2026-08-20-project-completion-audit/analysis.md` (10 projects, 367 directives, 381 checkpoints):
  started work finishes at 87%; mid-plan stalls 6.7%; 97% of checkpoints restate plan position by hand; 47% of the
  non-backlog open board (36 of 76) was already shipped but unrecorded; 27% of criteria checked vs about double real
  completion. Its rubric (14-day activity window) is the spec for `borg_core/planstate`.
- `docs/plans/directives/2026-10-03-evals-for-everything.md`: behavior evals for skills/agents; separate concern
  (does a skill behave) from this study (does the PM system deliver), but the coverage-ledger idea transfers.
