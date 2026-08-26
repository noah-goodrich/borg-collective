---
name: borg-switch
description: >
  Switch to a different project's tmux window. Use when the user says "switch to X",
  "go to X", "jump to X", or wants to change projects.
---

If the user named a specific project: run `borg switch <name>` with the Bash tool.
If no project was named: run `borg link --local --all`, show the list, ask which one to switch to,
then run `borg switch <chosen>`.

`--local` is mandatory here. `borg link` sweeps its sources for live state, and `--all` is the widest
breadth in the system — every registered repository. All this call needs is a list of names, which
comes straight off the registry, so without `--local` it buys the most expensive read borg can do to
produce something no network call can change.

After switching, confirm: "Switched to <project>." No further commentary needed.
If the switch fails (project not found or no tmux window), show the error and suggest
running `borg link` to see available projects.
