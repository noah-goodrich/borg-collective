# Evidence: a live Cortex session with borg hooks (2026-10-22)
*Dated 2026-10-22. Cortex Code CLI 1.2.14, then 1.2.18 (updated mid-run; 1.2.14 kept for rollback). Interactive TUI on a trial account. Evidence for AC5 of `docs/plans/directives/2026-10-15-borg-in-cortex.md`.*

**tl;dr** Hooks fire in a live Cortex session and borg state flips as designed. Appearance on the board was NOT observed, so AC5 of the parent directive stays unticked.

## What was observed

- **Hook events fire.** SessionStart, UserPromptSubmit, Stop and Notification all reached the registered borg hooks, on both versions. The recorded payloads carry `hook_event_name`, `session_id`, `cwd`, `transcript_path` and `permission_mode`.
- **Status flipped to idle after Stop (read directly on 1.2.14 only).** The borg state.json for the session read idle once Stop fired. It was not re-read on 1.2.18.
- **Status flipped to waiting on a permission prompt (read directly on 1.2.14 only).** The state read `waiting`, with the reason text of the prompt.
- **The integrated plan flow worked.** Solo on 1.2.18: entering plan mode, the model loading the borg-plan skill, writing a borg-shaped plan, the gate passing with no block, and the accepted plan landing as `PROJECT_PLAN.md`. Team mode on 1.2.14 (not run on 1.2.18): the gate blocked a chat-style plan, passed after borg-plan loaded, the plan was promoted, and the team plan file stayed native (the gap this change closes). The mechanism is in `docs/plans/assimilated/2026-10-22-borg-plan-in-cortex-plan-mode.md`; the repository hooks that now implement it are covered by bats, not by this note.

## What was NOT observed

- **Appearance on the board.** The run used isolated borg state, so the session was never in the registry the board reads. Nothing here says the session shows on the board with its badge, and nothing says it does not.
- **Unprompted plan-mode entry.** Not reproduced in two tries (a refactor on 1.2.14, a redesign on 1.2.18).

## What it settles

Of the three observations AC5 names, two are observed (status flips, waiting state with a reason). The third, appearance on the board, is open, so the parent AC5 stays unticked until a run against the real registry records it.

## Post-merge live check (2026-10-23)

After #461 merged, `borg setup` was run on 2026-10-22 and `~/.snowflake/cortex/hooks.json` carried the three plan-mode entries (PostToolUse `EnterPlanMode|enter_plan_mode`, PreToolUse `ExitPlanMode|exit_plan_mode`, PostToolUse `ExitPlanMode|exit_plan_mode`). The installed hook copies were byte-identical to `hooks/`. The owner then ran one real interactive plan-mode session (real account, fresh session, throwaway git repository with no `PROJECT_PLAN.md`; the task was a Streamlit-in-Snowflake query-performance app). The installed Cortex reads v1.2.18 on 2026-10-23; the session's conversation file records no version.

- `cortex-plan-debug.log` shows `inject emitted` at 2026-10-22T22:00:29Z and `PASS` (the gate passed) at 2026-10-23T03:07:32Z.
- `plan-promote-debug.log` shows the plan promoted to `docs/plans/PROJECT_PLAN.md` at 2026-10-23T03:36:33Z, after the owner accepted the plan.
- The promoted file starts with the auto-promoted header comment and carries a Plan-slug line, Acceptance Criteria with Verify lines, and Scope Boundaries as NOT building lines.

Not shown: the logs hold only inject, gate PASS and promote, so they do not show the model loading the skill, and no block-and-retry happened in this run. Appearance on the board was still not observed, so AC5 of the parent directive stays unticked.
