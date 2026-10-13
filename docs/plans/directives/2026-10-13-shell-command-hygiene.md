# Directive: shell command hygiene: stop tripping the dangerous-removal check

*Filed: 2026-10-13 · Status: Approved in outline (2026-10-13, Noah): live A/B, convention rewrite, named verbs, upstream report (text shown before posting). Slice details below are proposed; decisions D1-D8 carry defaults. Revised 2026-10-13 after blind review (see Review disposition).*

## tl;dr

- Claude Code 2.1.288 (2026-10-02) added a built-in check for shell `-c` scripts that might remove files. When a raw-text prefilter fires and the parser cannot judge the script, the user gets a canned prompt that hooks, allow rules, bypass mode and auto mode cannot approve. Subagents and workflows get a flat denial. 197 denials in 30 days, about 93% in subagents and workflows, weekly count 26 then 50 then 121. Only 21% of the denied scripts contain an rm word at all; the share that were genuine removals is NOT established (the earlier 16% / 84% split came from a regex label that mislabels heredoc bodies and is withdrawn until hand-verified).
- Borg is a major cause: `config/claude/CLAUDE.md` (the source of `~/.claude/borg-managed.md`) tells every session and every subagent to wrap pipelines in `bash -c '...'`. 42% of all Bash calls in the last 30 days (7413 of 17667) were `-c` wrapped. The official permission docs say allow rules are already matched per subcommand of `|`, `&&`, `;` and `||`, so the wrapping appears never to have been needed for permissions (to be confirmed in default mode by slice A2) and now exposes scripts to the check.
- The live A/B on 2.1.296 (16 commands, one headless session, auto permission mode) found exactly one denial: the wrapped awk pipeline with a dollar sign inside nested quotes. Its plain form ran. That supports only "unwrapping fixes the awk case". It does not show that unwrapping is safe in default or subagent mode, and B1/B3 did NOT reproduce. Slice A2 re-runs the A/B in default mode with a subagent before the convention change merges.
- Plan: C1 rewrites the convention in this repo (a stand-alone, ship-first deletion of the wrap-in-`bash -c` guidance; merge gated on A2), A2 re-runs the A/B in default mode, C2 does the same in the public dotfiles repo, V1 and V2 replace the recurring ad-hoc pipelines with named `borg` verbs (merge-train first), U1 drafts an upstream report (drafted only; posting needs Noah's OK).
- HARD RULE: nothing here weakens, hides or routes around the check for genuine removals. Real deletions use literal paths. No wrapper scripts that smuggle removals, no letter obfuscation of executed removals, no hook allow on removals.

## Ground truth this design stands on

### The check (as reverse-engineered from the 2.1.288 bundle and 30 days of denials)

- Scope: a command that passes a script to a shell with `-c` (`bash -c`, `sh -c`, `zsh -c`).
- Stage 1, raw-text prefilter, fires on any of: B1 brace-like text such as `{a,b}` or `{0,50}`; B2 a standalone `rm` word; B3 a `$` at command position.
- Stage 2, only when the prefilter fired: the script parser tries to judge the script. It cannot for `$(...)`, loops, unresolved variables, heredocs, scripts over 2000 characters, aliases or IFS tricks.
- Stage 3, only when stage 2 gave up: a heuristic token scan decides "possible removal". If yes, the canned prompt appears: "This command passes a shell -c script that runs rm, and Claude Code could not check the script for dangerous removals".
- The prompt is bypass-immune. Subagents and workflows have nobody to ask, so they get a denial.
- The message says "runs rm" even when the script contains no such letters; 125 of the 197 denials had no `rm` letters at all.

### Measured (30 days of transcripts, subagents and workflows included)

- 197 denials, about 93% in subagents and workflows. Weekly: 26, 50, 121. 41 of 197 (21%) contain an rm word; 125 contain none. Whether each denied script was a genuine removal was not hand-labelled, so no false-positive rate is claimed.
- Cutoff: first denial in the transcripts is 2026-10-03, consistent with 2.1.288 (2026-10-02). The cutoff is inferred from the denial corpus only; the release notes were not checked.
- 17667 Bash calls; 7413 (42%) were `-c` wrapped; 7410 of those from subagent and workflow heavy traffic.
- Why they were wrapped: pipe 77%, newline or semicolon 86%, redirect 47%, `&&` or `||` 38%, leading env assignment 37%, loop 12%. About 720 (10%) needed no pipe, loop, env or redirect at all.
- Evidence: `scratchpad/rm-check/proposal.md`, `denials.tsv`, `rule-excerpts.txt`, `inventory.tsv` (session scratchpad, not committed).

### A/B on Claude Code 2.1.296 (one headless haiku session, n=1 per cell)

| Shape | Wrapped | Plain |
|-------|---------|-------|
| 1 grep `x{0,50}` | ran | ran |
| 2 awk `substr($0,1,3)` | DENIED | ran |
| 3 `D=/bin; $D/echo hi` | ran | ran |
| 4 `echo $(echo hi)` | ran | ran |
| 5 for loop echoing rm word | ran | ran |
| 6 jq `{a, b: .a}` | ran | ran |
| 7 quoted heredoc naming rm | ran | ran |
| 8 control echo | ran | ran |

- Reading: 15 of 16 ran. The single denial is shape 2 wrapped, and removing the wrapper fixed it. No plain form drew any denial.
- B1 and B3 are unconfirmed on 2.1.296 (possible fixes since 2.1.288, or the simple fixtures parsed). The convention rewrite does not depend on them: it removes the wrapper, which is the common factor.
- Caveats: n=1, one model, simple fixtures, a top-level headless session, and permissionMode auto (`ab/stream.jsonl` line 5), so the auto-mode classifier handled the plain forms. Allow-rule matching, compound-command prompts and the "shell-operators", "too-complex" and "semantics" ask kinds (which subagents cannot answer) were not exercised. No `cd X && ... | ...` chain, multi-line `$(...)` plus loop, heredoc into an interpreter, or `VAR=x cmd` pipeline was tried, and B1 plus B3 were never combined in one script. Slice A2 closes these gaps.
- Raw data: `scratchpad/rm-check/ab/results.tsv` and `stream.jsonl`.

### Docs fact

- The official permissions documentation (page URL to be cited in the PR and the upstream draft before either is used; it is not recorded in the evidence folder) states that allow rules are matched against each subcommand of a compound command (`|`, `&&`, `;`, `||`). The old borg table ("`command1 | command2` becomes `bash -c '...'`") encoded a belief that the wildcard does not cross operators. That belief is true for one rule matching the whole line, but irrelevant: each subcommand is checked on its own against the allowlist.

### Version pin

- Applies to Claude Code 2.1.288 and later. Re-verify on each new minor version; `borg doctor` already surfaces the installed version.

### Where borg prescribes the wrapper today (Grep at filing time)

- `config/claude/CLAUDE.md:16-18` (the three-row table), `:21` ("`bash -c` is in the global allowlist. Use it for pipelines"), `:43` (Subagent Rules). This file is the source of `~/.claude/borg-managed.md`, which every session and every dispatched subagent reads.
- No `agents/*.md` or `skills/*/SKILL.md` hit for `bash -c` at filing time; C1 re-runs the Grep and also looks for paraphrases ("compound commands", "wrap in bash").
- `config/claude/settings.base.json:14-15` and `config/cortex/settings.base.json:14-15` allowlist `Bash(bash -c:*)` and `Bash(zsh -c:*)`. Kept (D3).
- `tests/*.bats` use `bash -c` as a test harness. That is test code, not guidance, and is out of scope.
- The user-global `dotfiles/claude/code/CLAUDE.md:22-27` carries the same table (slice C2, separate repo).

## Decisions (defaults stated; override in a word)

| # | Question | Default |
|---|----------|---------|
| D1 | Drop `bash -c` convention | Yes |
| D2 | Where verbs live | `borg_core/gh` |
| D3 | Drop `Bash(bash -c:*)` | No, defer |
| D4 | merge-train agent use | Humans/main loop only |
| D5 | Upstream report | Draft only |
| D6 | Verb output | JSON + human line |
| D7 | V2 verb choice | `borg wf summary` |
| D8 | Kill-switch env var | Rejected |

- D1: Rewrite the convention to "plain commands by default". Default yes (already approved in outline).
- D2: Package name. Default `borg_core/gh/` (the verbs are about GitHub PR state; the stdlib-only `subprocess` wrapper around `gh` mirrors `registry/cli.py` and `extensions/cli.py`). Alternative `borg_core/pr/`. If you prefer a different name, say so before V1 starts; renaming later costs a rewire of `borg.zsh` and the tests.
- D3: Keep `Bash(bash -c:*)` and `Bash(zsh -c:*)` in the allowlists for now. Dropping them would turn every leftover wrapped call into a hard prompt before the convention has had time to propagate. Revisit on the trigger in Deferred.
- D4: `borg pr merge-train` merges. It must never be called by a workflow agent or a nanoprobe; only a human or the main loop invokes it. Documented in the verb help, the skill text that mentions it, and enforced softly by a refusal when `BORG_AGENT_CONTEXT` is set, if such a variable exists (V1 checks; otherwise doc-only). This follows the standing finding that merge steps inside workflows refuse.
- D5: The upstream report is drafted and shown to Noah. Posting to `anthropics/claude-code` happens only after explicit OK, after C1 has shipped so the report can say what the workaround cost.
- D6: Every verb prints one human summary line to stderr or a table when stdout is a TTY, and JSON when `--json` or when stdout is not a TTY. Exit codes carry the verdict so callers need no parsing.
- D7: V2 targets the cluster with the best count-to-effort ratio that is not already a one-liner. Default `borg wf summary` (447 calls reading workflow task output). The test and lint cluster (3019 calls) is the largest but varies per project; it is the next candidate after `borg wf summary`, not before.
- D8: The undocumented environment kill switch for the check is rejected. It is a bypass of a safety control, not a fix; see HARD RULE.

## Slices

| Slice | Title | Repo | Depends |
|-------|-------|------|---------|
| C1 | Convention rewrite | borg-collective | - |
| C2 | Convention rewrite | dotfiles | - |
| V1 | `borg pr gate`, `merge-train` | borg-collective | - |
| V2 | Next verb: `borg wf summary` | borg-collective | V1 |
| U1 | Upstream report draft | scratch | A2 |
| A2 | Default-mode A/B (gates C1 merge) | scratch | - |

C1 stands alone and ships first: it is a deletion of guidance, with no dependency on any verb, classifier or guard. Its PR may be opened at once but merges only after A2 reports (see A2). C2, V1 and A2 are independent and can proceed in parallel. V2 reuses the V1 package skeleton. U1 is text only.

### C1 Convention rewrite (this repo)

Files: `config/claude/CLAUDE.md` (source of `borg-managed.md`), any `agents/*.md`, `skills/*/SKILL.md`, `docs/*.md` that prescribe the wrapper (re-Grep at start), `tests/shell_hygiene_contract.bats` (new). Run `borg setup` afterwards to regenerate `~/.claude/borg-managed.md`; do not hand-edit the generated file.

New rule text, in substance:

- Run plain commands. Pipes, `&&`, `;` and `||` are matched per subcommand by allow rules, so `cmd1 | cmd2` needs no wrapper.
- Use `run-in /path cmd` or `git -C /path` instead of `cd`.
- Prefer the Read and Grep tools over `cat`, `grep`, `find`.
- Slice output with `jq` expressions or tool-side truncation instead of `| head` where a JSON source allows it.
- Leading env assignment: use `env VAR=val cmd` (the `env` prefix is a plain command).
- Use `bash -c` only for genuine control flow (loops, conditionals) that cannot be a plain command. If a command is denied by the removal check, restructure it as a plain command or use a tool (Grep, Read); never respell, split or script a command to get past the check.
- Genuine deletions use literal paths, never variable targets, so the check can judge them. Do not obfuscate or respell the removal word for any reason. No guidance in this repo recommends a bracketed or otherwise respelled removal word.
- Long heredocs of data (code or docs) belong in the Write tool followed by a short command on the file. This advice is for content that is data only; it is never offered for anything that executes a removal.
- Subagent Rules section: same substance, one line each, because subagents are where 93% of the denials land.

Tests (prose contract, bats):

- Fails if `config/claude/CLAUDE.md` contains the old rule text: a table row mapping a pipe, an env prefix or `&&` chain to `bash -c`, or the sentence "Use it for pipelines and compound commands", or the Subagent Rules line "Use `bash -c '...'` for pipelines".
- Passes if the file contains the new anchors: "matched per subcommand", "literal paths", "genuine control flow".
- Fails if any `agents/*.md` or `skills/*/SKILL.md` instructs wrapping pipelines in `bash -c`.
- Passes if both settings.base.json files still list `Bash(bash -c:*)` (D3 guard; flipping D3 changes the test in the same PR).
- Fails if the convention text or any skill/agent file recommends a bracket-spelled or otherwise respelled removal word, or file indirection for a removal.
- The test file itself must not contain a standalone removal word in any `bash -c` script of its own.

### C2 Convention rewrite (dotfiles repo, PUBLIC)

Repo `/Users/noah/.config/dotfiles`, file `claude/code/CLAUDE.md` lines about 22-27 (the table and the "global allowlist" bullet), plus a Grep of `claude/code/` for other copies. Separate PR in that repo. Public repo hygiene: generic wording, no project codenames, no infrastructure detail in the PR body or commit message. Same substance as C1; a link to nothing private. No bats there; verification is the C1 prose contract mirrored as a Grep in the PR description, and a fresh session check that `~/.claude/CLAUDE.md` still imports `borg-managed.md`.

### V1 Verbs: `borg pr gate` and `borg pr merge-train`

Files: `borg_core/gh/__init__.py`, `core.py` (pure logic: rollup classification, state machine), `shell.py` (thin `subprocess` wrapper around `gh`), `cli.py` (argparse, JSON, exit codes), `test_core.py`, `test_shell.py`, `test_cli.py`; wiring in `borg.zsh` via `_borg_py borg_core.gh.cli` plus a `pr` case and help text. Same layout as `borg_core/registry` and `borg_core/extensions`. Stdlib only.

`borg pr gate <n> [--repo R] [--wait] [--json]`:

- Reads `gh pr view <n> --json statusCheckRollup,headRefOid,mergeStateStatus,state`.
- Exit codes: 0 green (all required checks succeeded or skipped), 1 failing, 2 pending, 3 cancelled without ever getting a runner (conclusion cancelled and no `startedAt`; distinct because it needs a rerun, not a fix).
- JSON: `{n, head, state, verdict, checks:{pass, fail, pending, cancelled_no_runner}, failing:[names]}`.
- `--wait` polls with a bounded interval and a hard ceiling (`--timeout`, default 1800 seconds), exits 2 on timeout.

`borg pr merge-train <n...> [--repo R] [--method squash] [--dry-run]`, per PR in the given order:

1. `gh pr update-branch <n> --rebase` if behind. A conflict stops the whole train with exit code 4 and reports the PR.
2. Wait for checks via the gate logic. A failing check stops the train with exit code 1.
3. A job cancelled without ever getting a runner is rerun once (`gh run rerun --failed`); a second occurrence stops with exit code 3.
4. Merge with `gh pr merge <n> --squash --delete-branch --match-head-commit <head>`. A head that moved since the gate stops with exit code 5 (re-gate required).
5. JSON report: `[{n, action, result, head}]`, `action` in `update-branch|wait|rerun|merge`.
- Usage or `gh` errors exit 64. Timeout exits 2.
- Safety: refuses to run when stdin is not a TTY unless `--yes` is given; the help states that workflow agents and nanoprobes must not call it (D4). `--dry-run` prints the plan and calls no mutating `gh` command.

Tests (pytest, fake `gh` executable on PATH, driven by a scenario file):

- Gate classification for each exit code, including cancelled-without-runner versus cancelled-after-start.
- Train happy path (two PRs, order preserved, head pinned in the merge call).
- Conflict stops the train and later PRs are untouched.
- Rerun happens once, then stops.
- Head moved between gate and merge refuses.
- `--dry-run` makes zero mutating calls (asserted from the fake's call log).
- `borg.zsh` wiring: a bats smoke that `borg pr gate --help` exits 0 and `borg help` lists `pr`.

### V2 Next verb(s) from the inventory

Only clusters with real counts qualify. Candidates, from the inventory (count, average characters):

- `borg wf summary <output|task-id> [--json]`: workflow task output digest, 447 calls, 301 chars average (246 multi-step ones average 1465). Default pick (D7). Returns `{status, agents, errors[], results truncated}`.
- `borg pr status <n...>`: PR state polling, 1975 calls. Overlaps V1 internals; cheap once `core.py` exists. Second pick.
- `borg wait pid|run|pr <id> [--timeout S]`: bounded wait loops, 931 calls. Removes `until`/`for` loops entirely, which are the case most likely to trip the check. Third pick.
- Not proposed as verbs: test and lint runs (3019 calls) vary per project and belong to `drone exec`; heredoc file authoring and python scripts belong to the Write tool and files in the scratchpad; transcript forensics (603) stays ad hoc until it recurs.

Deliverable for V2 itself: `borg wf summary` plus tests (fixtures of real task output shapes, sanitized), following the V1 layout. The other two are filed as follow-up issues, not built here.

### A2 Default-mode A/B (verification gate for C1)

Purpose: show whether dropping the wrapper is safe where the 93% of denials occur, and state the result per ask kind. Runs where Noah expects prompts; prompts that appear on screen are recorded, not answered by the script.

- Permission mode `default`, the real merged allowlist, run once as a top-level session and once inside a subagent (or workflow agent), so the non-interactive path is exercised.
- Shapes, each wrapped and plain: `cd X && ... | ...` chains; multi-line script with `$(...)` plus a loop; heredoc piped to `python3`; `VAR=x cmd` leading a longer pipeline; the single-pipe, `;` and lone-loop shapes from the first run as controls; and the B1+B3 combination (a `grep -E` with `{0,50}` or an awk `substr($0,...)` together with a `$VAR` or `$(...)` in one script).
- At least 3 runs per cell. Record per cell: ran, prompted (ask kind), or denied (message).
- Output: a table in `scratchpad/rm-check/ab2/` plus a paragraph per ask kind (shell-operators, too-complex, semantics, removal check).
- Gate: if plain forms are denied or prompt in the subagent context where the wrapped form ran, C1 is narrowed (keep wrapper guidance for those shapes, with the evidence) before merge; if not, C1 merges as written. The claim "retire the convention" is limited to what A2 shows.
- No genuine removal is used as a fixture; shapes that mention the removal word as text only, as in the first run.

### U1 Upstream report draft

Draft at `scratchpad/rm-check/upstream-draft.md` (outside the repo, generic and public: no personal paths, no project codenames). Content:

- Title: dangerous-removal check for shell `-c` scripts fires on scripts with no removal and gives subagents no recourse.
- Repro: the A/B shapes, leading with the wrapped awk `substr($0,...)` pipeline versus its plain form, with the exact commands or the stream log attached; A2 results added; version note (denial reproduced on 2.1.296; the brace and command-position-variable triggers are from reading 2.1.288 and did not reproduce). Re-run on the latest version before posting. No false-positive percentage is quoted unless hand-verified labels exist; the draft says what was counted (denials, share without an rm word).
- Asks: a distinct "could not check" message (not "runs rm"); no firing on quantifiers like `x{0,50}` or `$0` inside quoted arguments; a non-interactive path for subagents (for example fail closed with a reason the model can act on, or honor an explicit allow rule for scripts the parser can judge); keep the check for genuine removals.
- References closed anthropics/claude-code#96300.
- Status in this directive: DRAFT ONLY. Posting needs Noah's OK (D5).

## Acceptance criteria

Each line is checked by the named evidence; "Evidence:" is what the reviewer runs or reads.

1. `config/claude/CLAUDE.md` no longer instructs wrapping pipelines, env prefixes or `&&` chains in `bash -c`, and states the per-subcommand matching fact. Evidence: `tests/shell_hygiene_contract.bats` green; Grep of the file for the old table rows returns nothing.
2. The regenerated `~/.claude/borg-managed.md` carries the new text. Evidence: `borg setup` then Read of the file; diff against the source.
3. Both `settings.base.json` files still allowlist `Bash(bash -c:*)` and `Bash(zsh -c:*)`. Evidence: the D3 guard test in the same bats file.
4. No `agents/*.md` or `skills/*/SKILL.md` prescribes the wrapper. Evidence: bats assertion plus the C1 Grep output pasted in the PR.
5. The dotfiles `claude/code/CLAUDE.md` carries the same substance, in its own PR, with generic wording. Evidence: the PR diff; `gh repo view --json visibility` confirms public handling was applied.
6. `borg pr gate` returns 0, 1, 2, 3 for green, failing, pending, cancelled-without-runner. Evidence: pytest cases against the fake `gh`.
7. `borg pr merge-train` stops with distinct exit codes on conflict (4), moved head (5), repeated runner loss (3), failing checks (1); reruns a never-started job exactly once; always passes `--match-head-commit`. Evidence: pytest call-log assertions.
8. `borg pr merge-train --dry-run` makes no mutating call. Evidence: pytest call-log assertion.
9. Workflow agents are told not to call `merge-train`. Evidence: the verb help text and the doc line, asserted by a bats grep.
10. `borg wf summary` digests a real workflow output fixture to status, agent count and errors. Evidence: pytest on sanitized fixtures.
11. The upstream draft exists, is generic (no personal paths or project codenames), leads with the awk repro, and is NOT posted. Evidence: Grep of the draft for `/Users/` and project names returns nothing; `gh issue list -R anthropics/claude-code --author @me` shows nothing new.
12. Outcome metric, observed after C1 ships and propagates (about one week): the weekly count of rm-check denials, from re-running the same transcript forensics, falls well below the 121 per week baseline. Evidence: re-run of `scan.py` over the new week; number recorded in this directive's follow-up note. This is the revisit trigger for the Deferred list.
13. No genuine-removal path is weakened. Evidence: Grep of the diff for new hooks, wrapper scripts or allow rules touching removals returns nothing; review checklist item.
14. `bats tests/` and `pytest borg_core/` pass. Evidence: CI green on each PR.
15. A2 has run in default mode, top-level and in a subagent, with at least 3 runs per cell including the chain, loop, heredoc, env-prefix and B1+B3 shapes, and C1 merges only after its result is recorded. Evidence: `scratchpad/rm-check/ab2/` table linked from the C1 PR.
16. Convention text and any future deny reason never advise respelling a removal word or routing a removal through a file. Evidence: the C1 bats assertion; for any future guard, a negative test that every genuine removal, including the obfuscation variants (quoted-letter forms, brace expansion, `$'...'`, `xargs`, `find -delete`, `env`/`sudo`/`command` wrappers, `$cmd` at command position), passes through with exit 0 and no JSON.

## Deferred

- The `borg_core` shell-shape classifier and a bash-guard log/deny step (a mirror of minified code with a version canary). Cost versus the alternative: simply stopping the wrapping (C1) is the 80/20 option, since the corpus shows almost no denials when no prefilter branch fires, and the upstream report may fix the rest. This work is gated: build a log-only measurement first, and only proceed if it shows a meaningful remaining rate after C1 propagates. Constraints if built: deny reasons say "unwrap, or use Grep/Read" only, never a respelling or file-indirection suggestion; genuine removals and any doubt pass through untouched (exit 0, no JSON); criterion 16 negative test is mandatory.
- Dropping `Bash(bash -c:*)` and `Bash(zsh -c:*)` from the allowlists. Revisit with the classifier, or when the weekly denial count is near zero and the remaining wrapped calls are measurably pure legacy.
- The undocumented environment kill switch: rejected (D8), not deferred.
- `borg pr status`, `borg wait`, `borg ci failed`, `borg worktree`, `borg status --json`, `borg send`, `borg transcript query`: filed as follow-ups once V1 and V2 land, in count order.

Revisit trigger: after C1 has been live a week, re-run the forensics. If weekly denials are still above about 20 and most come from wrapped scripts, build the classifier; if they come from plain commands, the problem is upstream and U1 carries it.

## Risks

- The mechanism was inferred from a bundle and transcripts, not documented. A/B n=1 per cell on 2.1.296; B1 and B3 did not reproduce. Mitigation: the rewrite removes the wrapper (the observed common factor) rather than depending on any one trigger; A2 tests default and subagent mode before merge; the outcome metric (criterion 12) measures reality.
- Plain commands still hit the allowlist per subcommand. A pipeline whose second stage is not allowlisted now prompts where `bash -c` used to sail through under `Bash(bash -c:*)`. That is the allowlist working as designed, but expect a short burst of new prompts. Mitigation: D3 keeps the wrapper permitted during the transition; add missing stage commands to `settings.base.json` deliberately.
- `Bash(bash -c:*)` is a broad rule. Keeping it (D3) preserves a permissive pattern; the rewrite lowers its use, the classifier or removal comes later.
- Subagents copy habits from the briefs they receive. Existing dispatch prompts, skills and memory notes that quote the old rule keep teaching it. Mitigation: C1 greps skills and agents; the Subagent Rules block is regenerated into every brief.
- `merge-train` is a mutating verb. Mitigation: TTY or `--yes` requirement, `--match-head-commit`, one rerun only, distinct exit codes, no use by agents (D4).
- Fake `gh` tests can drift from real `gh` JSON. Mitigation: fixtures are copied from real `gh pr view --json` output with identifiers sanitized; one manual dry-run against a real PR before merging V1.
- Public-repo leakage in C2. Mitigation: generic wording, checked against the public-repo hygiene checklist before opening the PR.
- A new Claude Code release may fix, move or tighten the check. The version pin and the metric make that visible; the guidance ("plain commands, tools over shell") stays correct either way.

## Review disposition (blind review, 2026-10-13)

| # | Severity | Finding | Disposition |
|---|----------|---------|-------------|
| 1 | blocker | Directive not at the stated path | Declined as a content defect, accepted as a process note |
| 2 | major | A/B ran in auto mode; ask kinds and chain shapes untested | Accepted: slice A2, criterion 15 |
| 3 | major | n=1, B1+B3 not combined, claim too strong | Accepted: A2 reps and B1+B3 cell, claims softened |
| 4 | major | Evasion-adjacent guidance | Accepted (already partly dropped): criterion 16 |
| 5 | minor | Upstream draft accuracy | Accepted: 84% withdrawn, cites and repro added |
| 6 | minor | Simpler option missed | Accepted: C1 stands alone, guard gated |

- 1: The directive exists on branch `plan/shell-hygiene` (PR 363, file `docs/plans/directives/2026-10-13-shell-command-hygiene.md`). The reviewer looked at a worktree path that had been reaped after the first push; the worktree is not the source of truth, the pushed branch is. So the merge-train safety and the slice and acceptance review can now proceed against the branch; nothing in the finding changes the design. The merge-train section already specifies `--match-head-commit`, a conflict stop (exit 4), a single rerun of runner-less cancellations only, and no use by workflow agents (D4); a reviewer should check those against V1 on the branch.
- 2 and 3: accepted. See A2. The convention change stays conditional on A2; the claim is limited to "unwrapping fixed the one reproduced denial" until A2 reports.
- 4: the `[r]m` spelling advice and the "keep the script free of brace text and `$` at command position" tuning advice are removed; the directive never recommended them, but the earlier proposal did and the C1 rule text had a tuning line. Heredoc-to-Write advice is scoped to data. Any deny reason, if a guard is ever built, says only "unwrap, or use Grep/Read". Negative test is criterion 16.
- 5: the 84% figure is withdrawn: it rested on a regex label already flagged as unreliable (31 "real removals" including heredoc bodies). Stated facts now: 197 denials, 21% contain an rm word. The per-subcommand docs claim is flagged for a URL citation before use (no URL is in the evidence folder). The "hooks, allow rules, bypass mode or auto mode cannot approve it" line is softened in the upstream draft to what was observed. The cutoff is stated as inferred.
- 6: accepted. C1 is independent and first; the classifier and guard are deferred and gated on a log-only measurement.
