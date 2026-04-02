---
name: borg-hail
description: >
  Show the morning briefing / project dashboard. No args = full dashboard with all projects
  (LLM-generated morning briefing). With a project name = detailed status + cairn knowledge
  for that project. Use when the user asks for context, status overview, or says "brief me"
  / "what's going on" / "hail".
---

If the user named a project: run `borg hail <name>` with the Bash tool.
If no project named: run `borg hail` (shows full dashboard across all projects).

Present the output as-is. If cairn has no data for a specific project, say so and
suggest running `borg refresh <project>` to generate a summary from the transcript.
