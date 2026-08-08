---
id: multi-repo-shim-sync-on-new-record-kind
project: cairn
domain: cli
tags:
- cli
- shim
- dotfiles
- record-kinds
- cross-repo
preconditions: []
steps:
- Identify the new record kind endpoint in the service (e.g., `POST /record/document`).
- Add the matching `case` branch to `cli/cairn` (cairn repo), mirroring existing sibling
  cases.
- Add the identical `case` branch to `~/.config/dotfiles/zsh/bin/cairn` (dotfiles
  repo).
- 'Test end-to-end: run `cairn record document <args>` and confirm a row appears in
  the DB.'
- 'Open and merge PRs in both repos (cairn #29, dotfiles #6 in this instance).'
- Verify the on-PATH shim is the updated version (source dotfiles or open a new shell).
pitfalls:
- The dotfiles shim is the one actually on PATH; updating only the repo shim has no
  effect until dotfiles is also updated and reloaded.
- 'Forgetting either file results in silent failures: the service endpoint works but
  the CLI returns `unknown record kind`.'
- There is no automated test that the two shims stay in sync — divergence is only
  caught when a record kind is exercised.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260714-0405-cairn
superseded_by: null
created_at: '2026-07-14 04:06:54.528940+00:00'
updated_at: '2026-07-14 04:06:54.528941+00:00'
---

# multi-repo-shim-sync-on-new-record-kind

## description

When a new record kind is added to the cairn service API, two shim files must be updated in sync: the canonical `cli/cairn` in the cairn repo, and the on-PATH copy at `~/.config/dotfiles/zsh/bin/cairn` in the dotfiles repo.
