---
name: borg-ls
description: >
  Show the full project dashboard. Use when the user asks to see all projects,
  wants a status overview, or asks "what's running?" / "show me everything".
---

Run `borg ls --all` with the Bash tool. Present the output as-is — it's already formatted.

After showing it, offer one follow-up based on what you see:
- If any project is "waiting": "Project X is waiting on input — want to switch there?"
- If >3 active projects: "You're over capacity. Want to tidy or archive anything?"
- Otherwise: "Want to switch to one of these?"

One follow-up max. Don't narrate the table.
