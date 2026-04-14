---
name: borg-checkpoint
description: >
  Summarize session work and define a concrete next-session entry point.
  Use when ending a session, before a break, or when switching projects.
  Produces a structured checkpoint that eliminates context-rebuild time.
  Saves the checkpoint to disk at <project>/.borg/checkpoints/<timestamp>.md.
disable-model-invocation: true
---

# Enhanced Checkpoint

Summarize this session with exactly these five sections:

## 1. Goal
What was the original objective of this session? One sentence.

## 2. Accomplished
What was completed? List concrete deliverables (files created, bugs fixed, features shipped). Be specific.

## 3. Ready to Commit
Which files are changed and ready to commit right now? If nothing, say so. If you have
not run /simplify on the changed files this session, recommend doing so now before
committing and list the specific files to review.

## 4. Blockers
What prevented completion? List specific issues, missing information, or dependencies. If none, say "No blockers."

## 5. Next Session
What should the next session focus on first? Be specific enough that someone returning after 2 days
knows exactly where to start. Include the exact file and function if applicable.

## Save to disk

After displaying the checkpoint, save it to `<project-root>/.borg/checkpoints/<YYYY-MM-DD-HHMM>.md`.

To determine `<project-root>`: use the directory that contains `PROJECT_PLAN.md`, or the git root
(run `git rev-parse --show-toplevel`), or the current working directory if neither applies.

Create the directory if it does not exist. Use the Write tool. The file content should be the full
five-section checkpoint exactly as displayed above (no additional wrapper or header). Echo the saved
path at the end of your response so the developer can `cat` it later.
