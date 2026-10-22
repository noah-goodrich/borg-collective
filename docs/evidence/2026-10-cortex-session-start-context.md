# Evidence: SessionStart additionalContext does not reach Cortex's model (2026-10-22)
*Dated 2026-10-22. Cortex Code CLI 1.2.18 (measured), 1.2.14 (consistent with the earlier observation). Evidence for AC6 of `docs/plans/directives/2026-10-15-borg-in-cortex.md`.*

**tl;dr** SessionStart `additionalContext` does not reach the model in Cortex. PostToolUse `additionalContext` does. Nothing borg needs the model to know can ride on SessionStart there.

## What was observed (1.2.18)

Three questions asked in fresh interactive sessions with no tools allowed, each a yes/no or token answer:

- **Canary.** A hook returned an `additionalContext` carrying a unique canary token at SessionStart. Asked for the token, the model answered NONE.
- **borg's real text.** With the real borg SessionStart hook installed, asked whether its context contained "WORKFLOW REQUIREMENT" or "Active directives", the model answered NO.
- **Control.** A phrase placed in a `RULES.md` file the CLI loads was asked about the same way. The model answered YES, so the question and method can see context that does arrive.

Version 1.2.14 is consistent with the parent directive's earlier observation (the injected text visible in the UI, the model answering as if it had never seen it, no trace in the saved history).

## The contrast

PostToolUse `additionalContext` reaches the model: after the EnterPlanMode hook returned it, the model loaded the borg-plan skill unprompted. A PreToolUse `exit 2` message also reaches it (as `[Hook] Blocked: <message>`).

## What it settles

The arrival brief and the "run /borg-plan" nudge are invisible to Cortex's model. This directive builds nothing to replace them (see its scope boundaries); the plan-mode hooks use PostToolUse and PreToolUse because those are the channels that arrive.
