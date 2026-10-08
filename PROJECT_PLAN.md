# Project Plan: `borg next` as a chooser
*Established: 2026-10-06*

- Plan-slug: `2026-10-06-borg-next-chooser`

Screen 2 of `docs/plans/directives/2026-10-05-board-chooser-and-trains-ux.md` (its AC1 to AC3 and AC6). That directive stays filed for screens 1, 3 and 4. Each screen ships as its own plan, per its ship definition.

## Objective

`borg next` on a terminal becomes a chooser. It lists every candidate with its next step, owner and readiness, and opens the one you pick. Every `borg next` run is logged, so a recommendation can earn its place by measured follow-through. `borg next --switch` and Ctrl+Space > stay exactly as they are.

## Acceptance Criteria

- [ ] **AC1 — `--switch` unchanged; the chooser lists candidates.** The first commit adds a characterisation case: `borg next --switch` against a populated fixture registry, with the window target asserted. It lands green on unchanged code and stays green, unchanged, through every later commit. `borg next --pick 1` against the same fixture lists one row per candidate. A project with a manifest carries an owner of yours, mine or unsure; one without carries blank cells. The chooser runs only when `-t 0 && -t 1`; otherwise `borg next` prints today's output.
  - Verify: `bats tests/next_chooser.bats`; `git diff` of the characterisation case between its first commit and the final head is empty.
- [ ] **AC2 — Every `borg next` run appends one row to `next-recs.jsonl`.**
  - **Location:** `<paths.state_root()>/next-recs.jsonl`, written from the Python core after `retention.rotate_log`, and fail-open.
  - **Fields:** those listed in the directive (`ts`, `session`, `shown`, `top3`, `rec`, `opened`, `opened_after_s`, `active`, `switch`, `chooser`), plus `scripted`, which is true for `--pick` runs so scripted picks never count as your choices.
  - **Non-chooser rows:** `chooser: false` rows carry `shown: false` and null `rec`, `opened` and `opened_after_s`.
  - Verify: pytest on the pure row builder; bats, with `XDG_STATE_HOME` set explicitly in setup, asserts one well-formed row each for `--pick 1`, `--switch`, and a non-TTY bare run.
- [ ] **AC3 — The suggestion is shown only once it has been earned.** The gate is a follow rate of at least 60% over at least 20 rows with `chooser: true` and `scripted: false`. Below that, the suggestion is computed and logged with `shown: false` and never drawn.
  - Verify: pytest over fixture logs: 19 rows at 100% shows nothing; 20 at 55% shows nothing; 20 at 60% shows it; 20 scripted rows at 100% shows nothing.
- [ ] **AC4 — Nothing breaks.** `make test && make test-bats && make lint` are green. `borg help` is unchanged, since no command is added.
  - Verify: the three make targets; the help-count case in `tests/cli_contract.bats` stays at its current value.

### Scope change, 2026-10-08 (Noah: "I'd rather make the rows match the mock and fix whatever underlying issues are causing the disconnect right now.")

In a smoke test, the shipped chooser listed one row per project, with next step, owner and ready all blank. The cells were blank because they were read from manifests, and only 2 of 16 projects have any manifest rows. The mock shows one row per piece of work, each with an owner and readiness. These criteria close that gap with data borg already sweeps live, and no manifest backfill.

- [ ] **AC5 — The sweep sees every open PR and its readiness.** `recon-adapter-github` includes every OPEN PR in a swept repo whatever the since-mark. Today stillpoint-labs/ingle#394 is open and missing. Each item gains additive fields `draft`, `checks` (`pass`, `fail`, `pending` or `none`), `mergeable` and `review_decision`.
  - Verify: bats through a `gh` stub: an open PR last updated before the since-mark is present; the four new fields map from the stub's GraphQL; merged and closed PRs still honour the since-mark.
- [ ] **AC6 — Rows are work items with an owner and readiness.** A pure `nextpick` function builds one row per actionable item:
  - **Waiting session:** "reply to session", owner YOU, ready ✔ with its age.
  - **Open PR, not draft, checks pass, mergeable, no changes requested:** "merge #N", owner YOU, ready ✔.
  - **Checks pending:** "#N CI", owner AGENT, ready "… run".
  - **Checks fail:** "fix #N CI", owner AGENT, ready ✗.
  - **Draft:** "finish #N", owner AGENT, ready ◌.
  - **Changes requested:** "address review #N", owner AGENT.
  - **Active `PROJECT_PLAN.md` with an unchecked criterion and no open PR:** that criterion's name, owner AGENT, ready ○.
  - **Fallback:** a project with none of the above but with a checkpoint next step gets one row with that step, owner "—".

  Owner is decided by these rules, never by PR author, since every PR is authored as Noah. The item column is the PR title (short) or plan name until trains exist. Projects with no rows are listed in `quiet`. The ranking stays `cmd_next`'s project order, and items within a project follow the rule order above.
  - Verify: pytest for every rule, including a project with several items and a quiet project.
- [ ] **AC7 — The skill and the terminal view both show item rows.** `borg next --rows --json` emits item rows; `/borg-next` and the TTY chooser render them in the mock's columns (project · item, next step, owner, ready) with quiet projects collapsed; `--open` opens the item's project.
  - Verify: bats on `--rows --json` against fixtures; a smoke run of `/borg-next-preview` on the real registry shows at least one YOU row and one AGENT row.

## Scope Boundaries

- NOT building: the board (screen 1), the arrival brief (screen 4), or trains (screen 3).
- NOT building: any change to `cmd_next`'s ranking weights. The chooser shows today's order.
- NOT building: a window-switch observer. "Followed" means opening the suggested row in the same invocation.
- If done early: ship, don't expand.

## Ship Definition

Two PRs, each opened, CI green, `/borg-verify` PASS, and merged:
1. The characterisation case, the pure core (ranking rows, log row builder, gate), and logging for every run in shadow mode.
2. The interactive chooser and the gate.

After PR 2: a manual smoke run in a tmux pane, then `/borg-assimilate`.

## Timeline

Two sessions of about two hours, one per PR.

## Risks

- **Chooser latency.** The columns come from the `borg link --json` sweep, which takes about 1 to 3 s on the network. Mitigation: only the interactive chooser pays for it, never `--switch` or a non-TTY run; `--local` skips the network.
- **Moving ranking into Python could reorder ties.** Mitigation: the characterisation case pins the `--switch` target, and a pytest pins the core's order against the existing jq on a tie-heavy fixture.
- **Log growth.** Every `borg next` run, including Ctrl+Space >, appends a row. Mitigation: rotation at the 1 MiB cap.
