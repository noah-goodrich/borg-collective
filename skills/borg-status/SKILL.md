---
name: borg-status
description: >
  Show detailed status for a specific project: path, status, session ID, summary, cairn brief.
  Use when the user asks for details on a project or says "status of X" / "what's going on with X".
---

If the user named a project: run `borg status <name>` with the Bash tool.
If no project named: run `borg status` (defaults to current directory's project).

Present the output as-is. If the project isn't in the registry, say so and suggest `borg scan`
to auto-discover it or `borg add` to register it manually.
