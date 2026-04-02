---
name: borg-next
description: >
  Show what project needs attention most urgently. Use when the user asks
  "what should I work on?", "what's next?", or wants to know priorities.
---

Run `borg next` with the Bash tool. Then:

1. State the top project and why it's urgent (status: waiting/active/idle, last activity).
2. If status is "waiting", quote the waiting_reason so the user knows what's blocking.
3. Ask: "Want me to switch to it?" — if yes, run `borg next --switch`.

If borg reports capacity warning (too many active projects), surface that before the recommendation.
Keep the response to 3-5 lines. No lists unless there are multiple equally-urgent projects.
