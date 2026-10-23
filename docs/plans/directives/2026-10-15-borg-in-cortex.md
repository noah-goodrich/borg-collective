# Directive: borg works inside Cortex Code CLI
*Established: 2026-10-15*

- Plan-slug: `2026-10-15-borg-in-cortex`

Filed as a directive because `PROJECT_PLAN.md` holds another plan; see Promotion Trigger. Three slices, one PR each: S1 registers the hooks where Cortex reads them and teaches the plan-promote hook Cortex's tool names (this PR, with this plan of record), S2 repairs session discovery and records the live check, S3 keeps the link-up checkpoint name collision-proof.

## Objective

borg works inside Cortex Code CLI the way it works inside Claude Code: hooks fire, sessions show on the board, the checkpoint stays collision-proof. A validation run on 2026-10-15 against Cortex Code CLI 1.2.14 found that almost none of this holds today, and that one cause explains most of it. `borg setup` registers its eight hooks into `~/.snowflake/cortex/settings.json`, which Cortex does not read for hooks. Its loader reads `~/.snowflake/cortex/hooks.json`, `~/.claude/settings.json`, `~/.cortex/settings.json`, and a project's `.claude` or `.cortex` settings and settings.local files; the bundled Cortex documentation (`HOOKS.md`, `CONFIGURATION.md`) names `hooks.json` as the hooks location, and the loader log of every session agrees. So no borg hook has ever fired in Cortex. Registered in a place Cortex reads, SessionStart, Stop, Notification and the PreToolUse allow path all ran, so the hook scripts themselves are Cortex-compatible. The research report is kept outside this repository; its findings are restated here so the plan stands alone.

## Decision

Register the Cortex copies in `~/.snowflake/cortex/hooks.json`, never in `~/.claude/settings.json`. Cortex also loads `~/.claude/settings.json`, but the borg plugin already registers the same hooks there for Claude Code, so a second registration would double-fire. The hooks.json shape is the one Cortex documents and the same one `_borg_register_hook` already writes: an `hooks` object keyed by event name, each event a list of `{matcher, hooks: [{type, command, timeout}]}` groups. `borg setup` also removes the stale entries it previously wrote into `~/.snowflake/cortex/settings.json` (that file is still read for permissions, so every other key stays).

Cortex names its tools in lowercase (`bash`, `read`, `edit`, `write`, `grep`, `glob`, `task`, `skill`, `ask_user_question`, `exit_plan_mode`, `python_repl`, `bash_output`). A hook that cases on a capitalised tool name never matches there. S1 fixes the one registered hook that does (`borg-plan-promote.sh`); the other hooks that name tools are either not registered for Cortex or already read the command rather than the tool name.

*Correction, 2026-10-22 (the paragraph above is left as written).* The 2026-10-22 battery on Cortex 1.2.14 and 1.2.18 found that hook payloads use Claude-style tool names (`Bash`, `Read`, `Write`, `EnterPlanMode`, `ExitPlanMode`); the lowercase names are Cortex's own tool names, which do not appear in hook input. The lowercase handling added in S1 is therefore harmless but is not the reason the hooks work. See `docs/evidence/2026-10-cortex-session-start-context.md` and `docs/plans/assimilated/2026-10-22-borg-plan-in-cortex-plan-mode.md`.

## Acceptance Criteria

- [ ] **AC1: `borg setup` registers the eight Cortex hooks where Cortex reads them.** `~/.snowflake/cortex/hooks.json` carries SessionStart `borg-link-down.sh`, Stop `borg-link-up.sh`, Notification `notify.sh` and `borg-notify.sh`, PreToolUse `pre-commit-remind.sh`, `bash-guard.sh` and `borg-plan-promote.sh`, and SubagentStop `borg-nanoprobe-log.sh`, pointing at the copies under `~/.snowflake/cortex/hooks/`. A second run changes nothing (byte-identical file). The stale entries written earlier into `~/.snowflake/cortex/settings.json` are removed and every other key of that file, including a user's own hooks, is untouched; a user's own entries already in `hooks.json` survive. Nothing is registered into `~/.claude/settings.json`. (this PR)
  - Verify: `bats tests/cortex_hooks.bats`.
  - Evidence: `bats:tests/cortex_hooks.bats`
- [ ] **AC2: `borg-plan-promote.sh` accepts Cortex's lowercase tool names.** `edit` and `write` behave exactly like `Edit` and `Write`; behaviour under Claude Code names is unchanged. (this PR)
  - Verify: `bats tests/plan_promote.bats` (the lowercase cases sit beside the capitalised ones).
  - Evidence: `bats:tests/plan_promote.bats`
- [x] **AC3: Session discovery reads the directory current Cortex writes, so Cortex sessions show on the board with their badge.** `lib/coco.zsh` looks where Cortex 1.2.14 stores sessions (the validation found `conversations/` holding one JSON and one history file per session, carrying a working directory), not the `projects/` directory and `session-log.md` it assumes today. (S2)
  - Verify: bats over a fixture directory in the current layout.
  - Evidence: `bats:tests/coco_sessions.bats` (7 cases green on 2026-10-15: found by cwd, newest wins, subagent skipped, malformed skipped, absent directory silent, scan registers source coco)
- [ ] **AC4: The link-up checkpoint keeps a collision-proof name in Cortex.** Cortex expands no dynamic injection and sets no `CLAUDE_SESSION_ID`, so the skill's fallback path writes a checkpoint name without the session suffix, which reopens the two-worktrees collision the suffix closes. The name must carry a session-derived suffix in Cortex too. (S3)
  - Verify: bats over the name verb with Cortex's session id supplied the way Cortex provides it.
  - Evidence: `bats:tests/cortex_checkpoint_name.bats`
- [ ] **AC5: A live Cortex session on a real machine flips status, shows a waiting state on a permission prompt and appears on the board.** Checked by hand after S1 and S2 are installed, and recorded in a dated note with the Cortex version. (S2 or S3)
  - Verify: the note exists, names the version, and states each of the three observations.
  - Evidence: `path:docs/evidence/2026-10-cortex-live-session.md`
- [x] **AC6: Whether SessionStart `additionalContext` reaches the model in Cortex is settled and documented with the version.** The validation saw the injected text in the UI but the model answered as if it had never seen it, and the saved history held no trace of it, so the question is open; the answer, with the evidence, goes in a dated note. (S2 or S3)
  - Verify: the note exists and states the version and the observation.
  - Evidence: `path:docs/evidence/2026-10-cortex-session-start-context.md`

## Testability

- Registration is a function in `borg.zsh` that takes the Cortex directory, so `tests/cortex_hooks.bats` calls it after sourcing `borg.zsh`, with `HOME` and `XDG_CONFIG_HOME` pointed at a temporary directory. `borg setup` itself is never run by a test.
- The plan-promote cases extend the existing `tests/plan_promote.bats` with lowercase variants of the existing Edit and Write cases.
- AC3 and AC4 pin to bats files that later slices create. Until then the engine reports them `unknown`, which is the honest state. AC5 and AC6 are hand checks and pin to the notes.

## Slices (one PR each, merged on the owner's word)

| Slice | Content                        | Can start       |
| ----- | ------------------------------ | --------------- |
| S1    | AC1, AC2: hooks.json, tools    | now             |
| S2    | AC3, AC5: discovery, live note | AC3 done; AC5 by hand |
| S3    | AC4, AC6: checkpoint name      | after S1 merges |

## Scope Boundaries

- NOT building: `drone cortex` changes (a plain launcher with no hook or discovery dependency).
- NOT building: a change to `borg cortex-resume` or to the limit-text pattern `borg-cortex-watch` matches.
- NOT building: any registration into `~/.claude/settings.json`; the plugin owns that file's borg hooks.
- If done early: ship, don't expand.

## Ship Definition

Each slice: PR opened, CI green, the owner's word, squash-merged. After S1 merges, run `borg setup` once on a machine with Cortex installed and confirm `~/.snowflake/cortex/hooks.json` holds the eight hooks; that real run is the one thing the tests deliberately do not do.

## Timeline

Target: S1 on 2026-10-15, S2 and S3 within the week.

## Risks

- Cortex's own documentation is inconsistent about the hooks location: the desktop documentation names `settings.json`, the CLI bundle and its loader log name `hooks.json`. The loader log is the deciding evidence for the CLI, and the live check in AC5 is what would catch a wrong call.
- Hooks are snapshotted at Cortex session start, so a session already open when `borg setup` runs keeps the old (empty) set until it restarts.
- The hook command paths are written as absolute paths. Cortex's documentation recommends them, and the validated working registration used them; a literal `$HOME` in a command string is only safe if Cortex runs it through a shell, which was not verified.
- Cortex is a fast-moving CLI (it auto-updated twice during validation). The file layout and tool names recorded here are those of 1.2.14.

## Promotion Trigger

`PROJECT_PLAN.md` holds another plan. This directive is executed in place from `docs/plans/directives/` and is assimilated on its own when AC1 to AC6 are ticked; it does not displace that plan.
