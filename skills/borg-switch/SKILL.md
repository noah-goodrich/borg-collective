---
name: borg-switch
description: >
  Switch to a different project's tmux window. Use when the user says "switch to X",
  "go to X", "jump to X", or wants to change projects.
---

If the user named a specific project: run `borg switch <name>` with the Bash tool.
If no project was named: run `borg ls --all`, show the list, ask which one to switch to,
then run `borg switch <chosen>`.

After switching, confirm: "Switched to <project>." No further commentary needed.
If the switch fails (project not found or no tmux window), show the error and suggest
running `borg ls` to see available projects.
