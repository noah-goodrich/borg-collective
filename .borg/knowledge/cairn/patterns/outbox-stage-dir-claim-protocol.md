---
id: outbox-stage-dir-claim-protocol
project: cairn
domain: architecture
tags:
- cairn
- outbox
- atomicity
- posix
- fsync
- o_excl
preconditions: []
steps:
- Assert outbox root is on local POSIX fs (not NFS/overlay) at startup
- Build full entry in memory including body_sha256 computed from in-memory payload
- Write pending/<id>.json.tmp, fsync, atomic os.replace to pending/<id>.json (FIRST
  action, before any external call)
- Claim entry by creating <id>.lock with O_EXCL; write monotonic lease deadline into
  JSON (never file mtime)
- Attempt delivery to cairn API
- 'On success: move to done/<id>.json'
- 'On failure: increment failures, update last_error/next_run_at, release lock'
- 'On repeated failure: move to dead-letter/<id>.json'
pitfalls:
- Never use file mtime for lease tracking — clock skew makes it unsafe for mutual
  exclusion
- NFS and overlay filesystems do not guarantee O_EXCL atomicity — must assert local
  POSIX fs at startup
- Must write outbox entry BEFORE any FS body write or API call — any other ordering
  creates a crash window
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.267155+00:00'
updated_at: '2026-06-16 10:27:03.267156+00:00'
---

# outbox-stage-dir-claim-protocol

## description

Filesystem outbox with four-stage atomicity: pending/ → inflight (O_EXCL lockfile + monotonic lease in JSON) → done/ | dead-letter/
