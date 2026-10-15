---
name: borg-switch
description: >
  Switch to a different repository's tmux window. Use when the user says "switch to X",
  "go to X", "jump to X", or wants to change repositories.
---

If the user named a specific repository: run `borg switch <name>` with the Bash tool.
If no repository was named: run `borg link --local --all --overview`, show the list, ask which one to switch to,
then run `borg switch <chosen>`.

`--overview` is mandatory here. Anywhere but the Queen's root, `borg link` is a page about the ONE directory
you are standing in and lists no other repository; `--overview` forces the Queen's cross-repository view from
any cwd, and that is the only page that has the list.

`--local` is mandatory here. `borg link` sweeps its sources for live state, and `--all` is the widest
breadth in the system — every registered repository. All this call needs is a list of names, which
comes straight off the registry, so without `--local` it buys the most expensive read borg can do to
produce something no network call can change.

After switching, confirm: "Switched to <repository>." No further commentary needed.
If the switch fails (repository not found or no tmux window), show the error and suggest
running `borg link --overview` to see available repositories.
