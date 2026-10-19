# Terminal output, doorways and native features

Date: 2026-10-18. Claude Code 2.1.300, Cortex Code 1.2.14, tmux 3.6a.

**tl;dr:** The page you see when you run `/borg-link` is model prose, rewritten from JSON every time. The careful CLI layout never reaches you, and the CLI page is 803 lines and contradicts itself in two places. Fix that by making the CLI text the board, painting it verbatim inside Claude, and putting each rung of the output ladder on a terminal surface we measured today. Native Claude Code features replace parts of borg (live messaging, the "what is running" list), but not the guard, the worktrees, the Queen or checkpoints. Agent teams are not ready.

## 1. Verdict

- **Keep everything in the terminal.** Only rungs 1 and 2 of Karpathy's ladder (plain text, diagram) survive in a terminal. Rungs 3 and 4 (HTML, video) leave it, so we drop them.
- **The board must be deterministic text, not model prose.** Prose cannot be contract-tested, costs tokens on every call and can drift.
- **Fix trust before format.** Two screens disagree with each other today (section 3). A screen that contradicts itself costs more than any layout flaw.
- **Each rung gets a measured surface.** Glance: statusline and tmux. Arrival: SessionStart `systemMessage`. Choose: AskUserQuestion previews. Board: a fenced block. Detail: the nvim side pane (section 4).
- **Use native features where the experiments passed.** That covers live session pings (X8) and the running-session list (X4). Keep borg's guard, worktrees, Queen, checkpoints and vinculum log (section 5).

## 2. What the articles say, checked

- Karpathy's post (X, 2026-10-02) is advice, not research. It names a four-rung ladder: ASD-STE100 text, then a diagram, then an HTML page, then an explainer video. Medium posts that call it "research" embellish it.
- ASD-STE100 is a real standard (Issue 9, 2025). It has about 900 approved words and caps sentences at 20 words for procedures and 25 for descriptions. It puts one instruction in each sentence and prefers active voice. Evidence that it helps is old and weak. Karpathy himself suggests going "80% of the way".
- The stronger evidence for status screens is older and general:
  - Few: one screen, read at a glance.
  - Nielsen: people scan, and the inverted pyramid lets them stop anywhere.
  - Leroy: a ready-to-resume note reduces attention residue.
  - Mark: interruptions add stress.
- ADHD evidence on switching cost is mixed. The safe claim is "keep what must be held in mind small", not a number.
- No study measures the cost of switching from terminal to browser. Your rule rests on your own experience plus indirect evidence. That is enough to design to.
- Caveat: all three Medium posts and asd-ste100.org returned HTTP 403. The research worked from the post itself (via a mirror) and from secondary sources.

## 3. The doorways today, judged

What is good, and stays:

- WAITING ON YOU comes last, where the eye lands.
- Each row has an owner and a ready glyph.
- There is exactly one `next` line.
- The chooser runs through AskUserQuestion inside Claude.
- PR refs are OSC-8 links.

What fails:

1. **You never see the CLI page in Claude.** `/borg-link` pipes a jq projection of `--json` to the model, which writes its own prose. The tool call shows collapsed.
2. **The board is not one screen.** `borg link --overview` is 803 lines. STACKS and QUEUED take 93% of it, and 264 lines run past 80 columns.
3. **The screens contradict each other.**
   - The overview prints `NEXT nobody looked` directly above a filled WAITING ON YOU.
   - The repository page says `nothing waits on you`, while `borg next` lists #436 and #437 for that repository.
4. **The `borg next` card is noise.** It names one repository, then lists 3 of its 46 directives. It does not show the 4 decisions that `--rows` holds.
5. **The vocabulary is open-ended.** It mixes waiting, idle and active; YOU, YOURS, MINE and UNSURE; `nobody looked` and `nothing waits`; leg and compass; `<<<`. Two arrows (▸ and ▶) carry different meanings, and there is no legend.
6. **Neither command has `--help`.** `borg next --help` runs `borg next`.
7. **Nothing reaches you on arrival.** SessionStart today sends `additionalContext` to the model only. The arrival-brief directive (#437) fixes this.

Plan status:

- Option E (Doorways) is Proposed and not design-reviewed.
- The arrival brief is Proposed, in #437.
- The board-chooser directive is in progress, with AC5 (trains) open.
- viz-3 has met 0 of its 9 criteria.
- Nothing planned needs a browser.

## 4. Proposal: the ladder on terminal surfaces

Measured in X1 (fullscreen TUI, captured with tmux at 80 and 100 columns):

| Surface          | Result                       |
|------------------|------------------------------|
| fenced block     | exact alignment, any width   |
| markdown table   | grid; records under 80 cols  |
| Mermaid          | not rendered, raw text       |
| glyphs ✔●○◌✗▸▶   | one cell each                |
| AskUser preview  | box 42 cols inside, beside   |
| statusline       | 2 lines, color, always on    |
| `!cmd` output    | shown verbatim, model sees   |
| skill `!` inject | hidden; model reply only     |
| hook block       | verbatim, no model call      |

Notes:

- When previews show, option descriptions are hidden. Only labels show.
- A hook that blocks a prompt prints its text under a fixed "operation blocked by hook" header.
- `!cmd` also triggers a model reply.

The ladder, one surface per rung:

| Rung     | Surface                   | Cortex      |
|----------|---------------------------|-------------|
| 0 glance | statusline + tmux status  | tmux only   |
| 1 arrive | SessionStart systemMessage| works       |
| 2 choose | AskUserQuestion preview   | no preview  |
| 3 board  | fenced block, CLI text    | works       |
| 4 detail | nvim side pane            | works       |

Rung 0: one line, always visible, zero model cost. For example, `▶ merge #436 · borg-collective · 4 waiting`. Cortex has no configurable statusline, so the tmux status line carries rung 0 in both CLIs.

Rung 1: the arrival brief from #437, four lines.

Rung 2: in the `/borg-next` chooser, each option preview is a card:

- at most 6 lines and 42 columns;
- the label is a verb plus a ref;
- the last line is the exact command.

Cortex has no previews, so there the card shrinks to a one-line description.

Rung 3, the board, has the biggest change. The CLI renders a one-screen page: at most 40 lines and 100 columns, STACKS and QUEUED collapsed to counts, and a legend line. `/borg-link` injects that text with skill `!` preprocessing. The model pastes it verbatim in a fenced block, then adds at most 2 lines of verdict below it. That costs about 1k output tokens and one request fewer than today. Questions about the board ("why is #85 blocked?") still get prose answers.

Rung 4: full stacks, directives and docs open in the nvim side pane (`borg show`, comms-delivery S1).

Diagrams (Karpathy's rung 2) are box-drawing inside fenced blocks: vertical, at most 68 columns (`PICTURE_BUDGET`). Never emit Mermaid.

Writing rules. Enforce them with a screen-contract test on the CLI text, not by asking the model:

1. Verdict first in documents, last in chat and on the board.
2. Exactly one action line, imperative, holding the literal command.
3. Status words come from a closed list: ready, blocked, waiting, review, done.
4. At most 20 words per line.
5. At most 6 glyphs, each with one meaning, defined in a legend line.
6. Every blocked row names an owner and the step that unblocks it.
7. The board ends with one "pick up here" resume line.
8. You never need a URL to act. Links are extras.

## 5. Native features versus borg

| Component      | Test | Verdict                     |
|----------------|------|-----------------------------|
| dispatch guard | X3   | keep; add native deny layer |
| vinculum       | X8   | native for live pings only  |
| nanoprobe wt   | X4a  | keep                        |
| registry: live | X4b  | adopt `claude agents --json`|
| agent teams    | X7   | do not adopt yet            |
| Cortex plugin  | X9   | fix 3 errors, then test     |

- **X3, dispatch guard.** Native settings match borg on 8 of 12 cases. Settings can deny named values, but cannot express an allowlist, "deny when the field is missing" (untyped spawns), or pins on Workflow `agent()`.
  - Proposal: add these deny rules as a second layer, which still works when the hooks are off: `Agent(model:opus…)`, `Agent(effort:xhigh|max)`, and `Agent(subagent_type:general-purpose|Explore|Plan)`. This is a global settings change, so it needs your OK.
- **X8, messaging.** Delivery, the reply and the idle notice all worked, with about 8 s to act. A burst of 5 messages all arrived, and a `-p` worker received messages too.
  - Gaps: a message to a session that is not running fails at send time and is not queued. There is no durable log, no channels, and no reach into containers, which matters for drones.
- **X4a, worktrees.** Native worktrees work when launched from a parent that is not a git repo. But the WorktreeCreate hook receives only a name and a cwd, so it cannot tell which repo a subagent is for. WorktreeRemove never fires for subagents. Headless `/batch` committed in the main checkouts.
- **X4b, agent view.** `claude agents --json --all` reports working, blocked (with `waitingFor`) and done, plus cwd, session id and name, for both background and interactive sessions. It has no last activity, PR, summary, tmux window or pinned flag.
  - Use it as the source of live status, and keep the registry for repository facts.
- **X7, agent teams.** Teammates run as tmux panes. A two-teammate toy task passed all 16 of its tests in about 2 minutes.
  - This build has no shared task-list tool. The lead then claimed it had used one, and took the claim back when asked.
  - Teammates share one cwd and branch, and the team is gone when the session exits.
  - The toy task cost 1.7M cache reads.
  - It replaces nothing borg does. Re-check when agent teams reach GA.
- **X9, Cortex plugin.** `cortex plugin validate` fails on three errors:
  - the YAML `description: >` blocks in borg-grunt.md and borg-scout.md;
  - the `StopFailure` hook event, which Cortex does not know.
  All 18 skills pass. Fix the three errors, then test a real load. That would let one plugin serve both CLIs.

Not run yet (wave 2):

- E6: `claude plugin eval` on a borg skill (300k to 600k tokens per skill).
- E5: resume parity.
- E4: the usage sensor via statusline `rate_limits`.
- E8: single agent versus multi-agent.
- Cortex rendering, which spends Snowflake credits.

Your weekly Claude limit was at 75% during X1, with a reset on Oct 20. Wave 2 should wait for the reset.

## 6. Tests and evals

| Layer            | Size         | Measure        | Verdict  |
|------------------|--------------|----------------|----------|
| Python borg_core | 2303 tests   | 95.1% cov      | strong   |
| bats             | 2434 cases   | 2433 ok        | broad    |
| shell functions  | 517          | ~33% named     | blind    |
| mutation sample  | 20 mutants   | 17 killed      | strong   |
| evals            | 22 ledger    | 3 skills real  | weak     |
| CI gate          | 5 jobs       | 0 required     | advisory |

- **Python is strong.** Line coverage is 95.4% and branch coverage 94.1%, against a floor of 90.
  - The 0% modules (`census/cli.py`, `checkpoint/cli.py`, `extensions/cli.py`, `watch/cli.py`, `watch/shell.py`) run only as bats subprocesses, which coverage cannot see. Their coverage is unmeasured, not missing.
  - `summarize.py` is not measured.
  - The `watch` package is at 52%.
- **Bats is broad but black-box.** The full run takes 12 minutes. The one failure came from the audit's own venv name, not from the repo.
  - About 33% of shell functions are named by any test. That understates real coverage, because hooks and `drone.zsh` are tested from outside.
  - Files no test references: `lib/resume-doctor.sh`, `lib/borg-sync.zsh`, `lib/colors.zsh`, `scripts/sync-plugin.sh` and two plists.
- **Mutation kill rate is 85%.** `nextpick` killed 7 of 7. One survivor is a real gap: `suggest_full_ref` accepts a ref number that is not a digit.
- **Evals are the weak layer.**
  - Every model-behavior case skips in `make eval`, so no skill or agent behavior is tested in CI.
  - Only 3 skills have evals: borg-plan, borg-link-up and borg-assimilate. The other 19 ledger items are waivers, and no agent has an eval.
  - `claude plugin eval` is not used.
  - You asked about an eval hook: there is none that runs locally on edit or commit. The `eval-changed` CI check runs on PRs only.
  - The evals-for-everything directive meets AC 1, 2, 3, 7 and 8; AC 4 is partial; AC 5, 6 and 9 are not met.
  - **Deadline:** the waivers for borg-nanoprobe and borg-verify expire on 2026-11-15. After that, `eval_ledger.bats` turns main red.
- **CI is advisory.** Main has no branch protection and no required checks.
  - The macOS lane runs `cli_contract.bats` only, which is 209 of 2434 cases.
  - The last 40 runs: 37 passed. 2 failures were the viz gate catching a bad ref, and 1 was a flake (`checkpoint_prepare.bats:288`).
- **Test-quality hazards.**
  - Bats has 211 bare `[[ ]]` lines and no bats-assert. Under macOS bash 3.2, a failing `[[ ]]` in the middle of a test does not fail the test.
  - `tests/README.md` and `tests/MUTATION_DECISION.md` cite stale counts.
- There is no devcontainer for borg-collective, so the audit ran on the host.

Full audit: [test-audit.md](test-audit.md).

## 7. Next steps, in 80/20 order

1. Fix the two contradictions: NEXT versus WAITING ON YOU, and the repository page versus `borg next`.
2. Make the board one screen: collapse STACKS and QUEUED to counts, add a legend, close the vocabulary, and add a screen-contract test.
3. Make `/borg-link` paint the CLI board verbatim, with a 2-line verdict below it.
4. Glance rung: a statusline script plus a tmux status segment.
5. Merge #437, then build the arrival brief.
6. Fit the chooser cards to the 42-column preview.
7. Fix the 3 Cortex validation errors, then test a load.
8. Add native deny rules as a second guard layer. This needs your OK because it touches global settings.
9. Make the CI jobs required checks on main. This is a repository setting and changes how merges work, so it is your call.
10. Add `claude plugin eval` suites for borg-link and borg-next (E6), and settle the 2026-11-15 waiver expiry before it turns main red.
11. Replace bare `[[ ]]` in bats with `[ ]` or bats-assert, fix `suggest_full_ref`, and refresh the stale test docs.

## Non-goals

- HTML pages, video and web dashboards.
- Replacing the Queen, checkpoints or the guard hooks.
- Adopting agent teams.

## Alternatives considered

- **Web artifact board:** rejected. It breaks flow, and the August HTML attempts failed review.
- **Keep the model-prose board:** rejected for the board path. It cannot be tested and it drifts.
- **A hook that blocks a trigger word to paint the board:** it works with no model call. But it labels the output "operation blocked", so keep it only as a fallback.
- **Mermaid diagrams:** they do not render in the TUI.

## Sources

- [output-principles.md](output-principles.md): the articles and their evidence.
- [landscape.md](landscape.md): what changed since July, and the experiment list.
- [cortex-parity.md](cortex-parity.md): Cortex parity.
- [test-audit.md](test-audit.md): the full test and eval audit behind section 6.

The raw captures and experiment transcripts were not committed, because they carry private-repository details.
