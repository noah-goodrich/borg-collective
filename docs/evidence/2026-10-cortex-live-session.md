# Evidence: a live Cortex session with borg hooks (2026-10-22)
*Dated 2026-10-22. Cortex Code CLI 1.2.14, then 1.2.18 (updated mid-run; 1.2.14 kept for rollback). Interactive TUI on a trial account. Evidence for AC5 of `docs/plans/directives/2026-10-15-borg-in-cortex.md`.*

**tl;dr** Hooks fire in a live Cortex session and borg state flips as designed. Appearance on the board was NOT observed, so AC5 of the parent directive stays unticked.

## What was observed

- **Hook events fire.** SessionStart, UserPromptSubmit, Stop and Notification all reached the registered borg hooks, on both versions. The recorded payloads carry `hook_event_name`, `session_id`, `cwd`, `transcript_path` and `permission_mode`.
- **Status flipped to idle after Stop.** The borg state for the session read idle once Stop fired.
- **Status flipped to waiting on a permission prompt.** The state read `waiting`, with the reason text of the prompt.
- **The integrated plan flow worked on 1.2.18.** Entering plan mode, the model loading the borg-plan skill, writing a borg-shaped plan, exiting plan mode, and the accepted plan landing as `PROJECT_PLAN.md`, solo and in team mode. The mechanism is in `docs/plans/directives/2026-10-22-borg-plan-in-cortex-plan-mode.md`; the repository hooks that now implement it are covered by bats, not by this note.

## What was NOT observed

- **Appearance on the board.** The run used isolated borg state, so the session was never in the registry the board reads. Nothing here says the session shows on the board with its badge, and nothing says it does not.
- **Unprompted plan-mode entry.** Not reproduced in two tries (a refactor on 1.2.14, a redesign on 1.2.18).

## What it settles

Of the three observations AC5 names, two are observed (status flips, waiting state with a reason). The third, appearance on the board, is open, so the parent AC5 stays unticked until a run against the real registry records it.
