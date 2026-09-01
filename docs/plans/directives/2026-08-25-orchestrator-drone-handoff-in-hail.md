# Directive: Teach the orchestrator hail the drone-handoff sequence

## Why (the recurring failure)

2026-08-25, Noah: "I think you've forgotten what drones are again. How do we make it so you don't keep
forgetting how drones work?" — the orchestrator wrote handoff checkpoints into two project repos and declared a
spin-out complete while both drone Claude sessions sat idle, never told about the work. This is a REGRESSION
CLASS, not a one-off: the orchestrator's system prompt (the hail) documents spawning background nanoprobes but
never documents the drone model, so every fresh orchestrator session re-derives it — and sometimes derives it
wrong. A memory file now exists in the orchestrator's memory dir (`feedback_drone_handoff_mechanics`), but
memory is per-machine, recall-dependent, and model-independent behavior belongs in the prompt.

## The change

Add a short **"Drone handoffs"** section to the orchestrator hail template (wherever the `== ORCHESTRATION
MODEL ==` block is generated) stating:

1. A drone is a LIVE Claude session in the project's tmux window (`borg` session, window = project name).
2. Checkpoint/directive files are the handoff PAYLOAD, not the handoff. A running session never re-reads
   checkpoints (SessionStart fires only at session start).
3. The full sequence: write `<project>/.borg/checkpoints/<ts>.md` → `drone up <project>` → `drone claude
   <project>` (idempotent) → `tmux send-keys -t borg:<project> "<kickoff>" Enter` — kickoff names what the
   drone now owns, points at the checkpoint, carries any deltas newer than the file, and asks for a pickup
   confirmation.
4. Project-scoped work goes to the project drone; the orchestrator keeps cross-repo watching, external
   surfaces, and synthesis only.

## Acceptance criteria

- [ ] The orchestrator hail (system-prompt template) contains the drone-handoff sequence above.
- [ ] `borg setup` / whatever regenerates the hail ships the change to this machine.
- [ ] The wording fits the existing hail's register and stays under ~15 lines.

## Notes

- Complements, does not replace, the existing nanoprobe guidance (nanoprobes = background subagents for
  single tasks; drones = persistent interactive project sessions).
- Related orchestrator-memory entries: feedback_drone_handoff_mechanics, feedback_orchestrator_stay_unblocked,
  feedback_strike_work_dedicated_drone.

Filed: 2026-08-25, from 1:orchestrator (Noah's instruction).
