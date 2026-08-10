---
name: pane
description: >
  Split the current tmux pane in a given direction. Use when the user says "split the pane",
  "open a pane to the right/left/top/bottom", or wants a new terminal pane in the current window.
---

If the user named a direction (top, bottom, left, or right): run `drone pane <direction>` with
the Bash tool.
If no direction was named: ask which direction (top, bottom, left, or right), then run
`drone pane <chosen>`.

After the pane opens, confirm: "Opened a pane to the <direction>." No further commentary needed.
If it fails (invalid direction or not inside tmux), show the error as-is.
