---
name: borg-brief
description: >
  Show the cairn knowledge brief for a project. Use when the user asks for context,
  background, or history on a project, or says "brief me on X" / "what do we know about X".
---

If the user named a project: run `borg brief <name>` with the Bash tool.
If no project named: run `borg brief` (defaults to current directory's project).

Present the output as-is. If the brief is empty or cairn has no data, say so clearly
and suggest running `borg refresh <project>` to generate a summary from the transcript.
