# Directive: One-call inputs for the link-up turn
*Established: 2026-10-14*

- Plan-slug: `2026-10-14-link-up-prepare`

Filed as a directive because `PROJECT_PLAN.md` holds another plan; see Promotion Trigger. Two slices, one PR each: S1 builds the host command and this plan of record, S2 rewrites `skills/borg-link-up/SKILL.md` to use it.

## Objective

Cut the `/borg-link-up` turn from eight API requests to three with no functional change. Measured 2026-10-14: a link-up turn is a median 8 requests at a median 350k-token context, and every tool call costs one request that re-reads the whole context, so cost is (tool calls + 1) x context x cache-read price. One host command prints every mechanical input the skill needs. The skill pulls it in at load through dynamic context injection, which runs shell before the model sees the skill and so costs zero requests. The model then makes one combined Bash call (manifest add-row, then the planstate engine), one Write, and one closing reply.

## Decision

A decision-design study (three blind reviews) chose this over the alternatives. The inputs are mechanical, so a command computes them; the model keeps only the work that needs judgment (writing the checkpoint). The command is `borg checkpoint-prepare [--session <id>] [--cwd <dir>]`.

## The command contract (S1)

- Prints one plain-text document to stdout and ALWAYS exits 0, even when every input is missing or a subcommand fails. Failures become field values, never exit codes, because a non-zero exit during injection aborts the whole skill invocation.
- Writes nothing anywhere: no plan apply, no manifest row, no checkpoint file, no state. It reads the manifest through the read-only `resolve` verb and runs `git status` with `--no-optional-locks`.
- Hard total wall-clock budget of about 20 seconds. Every subprocess runs under a short timeout clamped to the remaining budget; `gh` gets at most 10 seconds. A subprocess that does not answer becomes a field value, not a hang.
- Hard output cap of 24,576 bytes. Each extension body is cut at 6,144 bytes with a `[TRUNCATED: ...]` marker line inside its fence; `git status` is limited to 60 lines (each at most 200 characters) with a marker; if the whole still exceeds the cap the per-body limit shrinks until it fits.
- Quoted data. Anything that originates outside this repository's own code is data, not instruction. Multi-line text (extension bodies, git output) is printed between fence lines. Single-line text (a refusal reason, a prefer-tool value) is printed as a JSON string, in double quotes with escapes, so it cannot span lines.

### Fixed output format (v1)

Fields appear in this order. The header names are fixed and pinned by `tests/checkpoint_prepare.bats` and `borg_core/checkpoint/test_prepare.py`.

| #  | Header                 | Value                                |
| -- | ---------------------- | ------------------------------------ |
| 1  | `borg checkpoint-prepare v1` | first line, no colon           |
| 2  | `PROJECT_ROOT:`        | absolute path                        |
| 3  | `CHECKPOINT_PATH:`     | absolute path, does not exist yet    |
| 4  | `PLAN:`                | absolute path or `none`              |
| 5  | `GIT_STATUS:`          | fenced block, or `unavailable: ...`  |
| 6  | `MANIFEST_RESOLVE:`    | stem, or `refused: "<reason>"`       |
| 7  | `PR_REF:`              | `owner/repo#N <url>` or `none: ...`  |
| 8  | `PREFER_TOOL:`         | one line per hook, or `none`         |
| 9  | `EXTENSION_<HOOK>_*`   | three hooks, three lines each        |
| 10 | `STATUS:`              | `ok` or `fallback: <reason>`         |

- PROJECT_ROOT follows the rule the skill text uses today: the git toplevel of `--cwd` (default: the current directory), else the directory holding `PROJECT_PLAN.md`, else the cwd.
- CHECKPOINT_PATH is `<root>/.borg/checkpoints/<stem>.md`. The stem comes from the same code `borg checkpoint-name` uses (`borg_core.checkpoint`), with `--session` passed through and the same fallbacks when it is absent. The skill's existence loop runs on the host: `-2`, `-3` and so on are appended until the printed path does not exist.
- PLAN is `PROJECT_PLAN.md` or `docs/plans/PROJECT_PLAN.md` under the root, whichever exists first.
- MANIFEST_RESOLVE is the stem `python3 -m borg_core.manifest.cli resolve` prints at exit 0, else `refused: "<first stderr line>"` (no manifest declared, ambiguous, and so on).
- PR_REF is derived from `gh pr view --json number,url` for the current branch. The owner and repository come from the validated URL. When there is no `gh`, no PR, a detached HEAD or a timeout it reads `none: "<reason>"`.
- PREFER_TOOL is the resolved prefer-tool precedence for the `borg-link-up` subject from `borg_core.extensions` (the machine layer wins for prefer-tool, the repository layer wins for prose). Each line reads `PREFER_TOOL: hook=<hook> layer=<layer> status=<status> prefer="<value>" instead_of="<value>"`.
- Extension headers are `EXTENSION_01_CONTEXT`, `EXTENSION_02_OUTPUT`, `EXTENSION_03_FOLLOWUP`, each with three lines: `<header>_MACHINE:`, `<header>_REPOSITORY:` (each `<path>` followed by a fenced body, or `not present`) and `<header>_PRECEDENCE:` (a one-line note from the existing extensions code).
- STATUS is `ok`, or `fallback: <reason>` when an internal step failed and was caught; the reason is one line.

### Fence delimiters

A fenced block is the line `----- BEGIN QUOTED DATA: <HEADER> -----`, the body, then `----- END QUOTED DATA: <HEADER> -----`. A body line that begins with either delimiter prefix is printed with a leading backslash, so a body can never close its own fence.

## Acceptance Criteria

- [ ] **AC1: The verb prints the ten fields, exits 0 always, and never writes.** In a real temporary repository with no plan, no manifest, no extensions and `gh` hidden, the output carries every field in order and the exit code is 0; a failed internal step yields `STATUS: fallback: ...` and still exit 0; the printed checkpoint path does not exist and advances to `-2` when the base name exists; a before and after listing of the repository (names and mtimes) is identical. (this PR)
  - Verify: `bats tests/checkpoint_prepare.bats`; `pytest borg_core/checkpoint/test_prepare.py`.
  - Evidence: `bats:tests/checkpoint_prepare.bats`
- [ ] **AC2: Time and size are bounded, with markers.** The total output stays at or under 24,576 bytes even with a huge extension body, each body is cut at 6,144 bytes with a `TRUNCATED` marker, `git status` is limited to 60 lines with a marker, and every subprocess runs under a timeout clamped to the 20-second budget. (this PR)
  - Verify: the pure assembler's truncation cases in pytest; the huge-body case in bats.
  - Evidence: `pytest:borg_core/checkpoint/test_prepare.py`
- [ ] **AC3: External strings are fenced as quoted data.** Extension bodies and git output sit between fence lines that a body cannot forge; single-line external text is a JSON string. (this PR)
  - Verify: the fence-escape and JSON-quote cases in pytest; the both-layers-present case in bats.
  - Evidence: `pytest:borg_core/checkpoint/test_prepare.py`
- [ ] **AC4: The skill loads the verb through dynamic injection, fails open, and keeps a fallback.** `skills/borg-link-up/SKILL.md` injects `borg checkpoint-prepare` with a fail-open wrapper (`|| true`), declares the command in `allowed-tools`, and keeps a short paragraph for the case where the injected block is missing. (S2)
  - Verify: prose-contract bats on the SKILL.md text.
  - Evidence: `bats:tests/skill_borg_link_up_prepare.bats`
- [ ] **AC5: The skill's turn is three requests.** One combined Bash call (manifest add-row, then the planstate engine, each with a per-command marker and an explicit timeout), one Write with no separate display of the body, and one closing reply that carries the tl;dr, the path, the Ready-to-Commit line and the Blockers line. (S2)
  - Verify: prose-contract bats; one transcript measurement of requests per link-up turn, before and after, in the S2 PR.
  - Evidence: `bats:tests/skill_borg_link_up_prepare.bats`
- [ ] **AC6: Every honesty rule and the three extension hook points survive verbatim.** No rule in the current SKILL.md is dropped or reworded; the prose-contract tests that pin them are repointed, never deleted. (S2)
  - Verify: the existing prose-contract tests stay green.
  - Evidence: `bats:tests/skill_borg_link_up_prepare.bats`
- [ ] **AC7: The Stop hook's no-checkpoint nudge says to checkpoint before the session goes idle, while its cache is warm.** (S2)
  - Verify: a bats case on the hook's output text.
  - Evidence: `bats:tests/skill_borg_link_up_prepare.bats`

## Testability

- The document is built by a pure assembler (`borg_core/checkpoint/prepare.py`, on the clean-arch Domain list) from already-read facts, so field order, fencing, truncation, the fallback status and the collision loop are pytest cases on literals. The impure reads (git, gh, the filesystem, the manifest and extensions code) sit in `borg_core/checkpoint/prepare_shell.py`; `borg.zsh` carries a one-line arm.
- The bats file runs the real verb in a temporary git repository, with `gh` hidden by an allowlist `PATH` rather than a guess about where `gh` lives.
- AC4 to AC7 pin to a bats file that S2 creates. Until then the engine reports them `unknown`, which is the honest state.

## Slices (one PR each, merged on Noah's word)

| Slice | Content                             | Can start       |
| ----- | ----------------------------------- | --------------- |
| S1    | AC1 to AC3: the verb, this plan     | now             |
| S2    | AC4 to AC7: SKILL.md and hook text  | after S1 merges |

## Scope Boundaries

- NOT building: any change to what a checkpoint contains.
- NOT building: an earlier-checkpoint nudge, a fresh-context writer, or a finalize verb.
- If done early: ship, don't expand.

## Ship Definition

Each slice: PR opened, CI green, Noah's word, squash-merged. After S2 merges, one transcript measurement of a link-up turn confirms three requests.

## Timeline

Target: S1 and S2 on 2026-10-14 and 2026-10-15.

## Risks

- A non-zero exit or a timeout during injection aborts the whole skill invocation, so the verb must never fail; the wrapper in S2 adds `|| true` as a second layer.
- Output past the Bash tool's inline ceiling arrives as a file path plus preview, which would force a Read. The 24 KB cap keeps the document inline.
- Injected text is plain text and never re-scanned, but the model still reads it. Fencing keeps extension and git text recognisable as quoted data.

## Promotion Trigger

`PROJECT_PLAN.md` holds another plan. This directive is executed in place from `docs/plans/directives/` and is assimilated on its own when AC1 to AC7 are ticked; it does not displace that plan.
