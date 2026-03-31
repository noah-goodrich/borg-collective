---
name: checkpoint-enhanced
description: >
  Summarize session work and define a concrete next-session entry point.
  Use when ending a session, before a break, or when switching projects.
  Produces a structured checkpoint that eliminates context-rebuild time.
disable-model-invocation: true
---

# Enhanced Checkpoint

Summarize this session with exactly these five sections:

## 1. Goal
What was the original objective of this session? One sentence.

## 2. Accomplished
What was completed? List concrete deliverables (files created, bugs fixed, features shipped). Be specific.

## 3. Ready to Commit
Which files are changed and ready to commit right now? If nothing, say so.

## 4. Blockers
What prevented completion? List specific issues, missing information, or dependencies. If none, say "No blockers."

## 5. Next Session
What should the next session focus on first? Be specific enough that someone returning after 2 days
knows exactly where to start. Include the exact file and function if applicable.
