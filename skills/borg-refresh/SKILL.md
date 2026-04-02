---
name: borg-refresh
description: >
  Regenerate project summaries from session transcripts. Use when the user says
  "refresh summaries", "update context", or wants current summaries regenerated.
---

If the user wants all projects refreshed: run `borg refresh --all` with the Bash tool.
If a specific project named: run `borg refresh <name>`.
Default is LLM-powered (Haiku). If the user wants fast extraction instead, add `--no-llm`.

Show which projects were updated. If any failed (no transcript found), note them.
