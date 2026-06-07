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

If borg reports a capacity warning (too many active projects), surface that before the recommendation.

The status `borg next` prints is already reaper-corrected: a session that was active/waiting but has no live tmux
window and no recent activity is auto-downgraded to idle for the recommendation and the capacity count. Trust the
status shown — never re-describe a project as "waiting" if `borg next` printed it as idle. If the output includes a
line like "(N stale session(s) auto-downgraded to idle — run 'borg reap' to persist)", relay it once and suggest
`borg reap` to make the downgrade durable. Do not invent staleness the CLI did not report.

Keep the response to 3-5 lines. No lists unless there are multiple equally-urgent projects.
