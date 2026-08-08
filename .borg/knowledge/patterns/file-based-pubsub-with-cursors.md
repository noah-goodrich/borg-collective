---
id: file-based-pubsub-with-cursors
project: borg-collective
domain: architecture
tags:
- pubsub
- ipc
- append-only
- cursor
- fswatch
- tmux
preconditions: []
steps:
- Create channel directory at `$XDG_DATA_HOME/borg/vinculum/<channel>/`
- Append JSON-encoded messages to `log.jsonl` (use `jq` for encoding, never hand-roll)
- Each subscriber maintains a cursor file recording the last-read line offset
- On `pull`, read from cursor to end of log, update cursor atomically
- On `sub`, spawn a per-pane `borg-vinculum-watch` process that uses `fswatch` to
  watch `log.jsonl`
- Watcher filters self-echo (messages from the current pane) before forwarding via
  `tmux send-keys`
- Apply rate cap (e.g. 30 msg/60s) in the watcher to prevent tmux input flooding
- Ensure the watcher binary is symlinked into `$BIN_DIR` by `install.sh` so `sub`
  can find it by bare name
pitfalls:
- Omitting the `install.sh` symlink causes `sub` to silently succeed (spawns nothing)
  — watcher not on PATH
- Hand-rolling JSON escaping in shell will corrupt messages containing quotes or backslashes
  — always use `jq`
- Cursor logic inlined at multiple callsites drifts; extract `_read_cursor`/`_write_cursor`
  helpers to prevent
- A string variable holding '0' is truthy in shell `${var:+...}` expansion — use `((
  var ))` for boolean guards
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260630-2202-borg-collective
superseded_by: null
created_at: '2026-06-30 22:03:12.818013+00:00'
updated_at: '2026-06-30 22:03:12.818014+00:00'
---

# file-based-pubsub-with-cursors

## description

Implement durable fan-out messaging between processes using only the filesystem: an append-only JSONL log per channel, per-subscriber cursor files, and fswatch for live delivery
