---
name: borg-refresh
description: >
  Regenerate project summaries from session transcripts. Use when the user says
  "refresh summaries", "update context", or wants current summaries regenerated.
---

Run `borg scan` with the Bash tool. This discovers new projects AND refreshes all summaries.
Add `--llm` for LLM-powered summaries (Haiku). Default is fast extraction.

Show which projects were updated. If any failed (no transcript found), note them.
