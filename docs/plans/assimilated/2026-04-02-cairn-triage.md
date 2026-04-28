# Project Plan: Cairn Triage
*Established: 2026-04-02*
*Shipped: 2026-04-28 — committed to main*

## Objective
Triage cairn to decide whether to fix or drop it. Cairn is the optional PostgreSQL + pgvector
knowledge graph that borg hooks attempt to use for cross-session knowledge persistence.

## Context
- Repo exists at `~/dev/cairn` with a `pyproject.toml` defining `cairn = "cairn.cli:app"`
- Install method: `pip install -e '.[dev]'` (documented in devcontainer.json postCreateCommand)
- `cairn` is not currently in PATH on the host — never been installed outside the devcontainer
- Borg hooks have graceful degradation (warn + skip when cairn unavailable)
- Split from prior plan (2026-04-02-ship-skill-and-cairn-triage.md)

## Acceptance Criteria

- [x] Diagnose why `cairn` is not in PATH (repo exists at ~/dev/cairn, postgres is running)
- [x] Document: is cairn a pip install? A built binary? What's the install path?
- [x] Either fix cairn installation so `cairn` CLI works, or document decision to drop it
- [x] If fixed: verify `cairn search`, `cairn record`, and `cairn health` work end-to-end
- [x] If dropped: remove cairn references from borg hooks/skills, simplify to checkpoints-only

## Scope Boundaries
- This is diagnosis + decision, not a rewrite
- If cairn needs significant work beyond install/config, that's a separate plan

## Ship Definition
- Decision documented (fix or drop) with rationale
- If fixed: cairn CLI works, borg hooks use it successfully
- If dropped: cairn refs cleaned from hooks/skills, committed and merged

## Risks
- Cairn may require Python venv setup that isn't documented
- Postgres may need schema migrations or config that's only in the devcontainer

## Resolution
**Decision: Fix.** cairn is a shell script client (`~/.config/dotfiles/zsh/bin/cairn`) wrapping
the FastAPI service at `cairn-api:8767`. Not a pip install — it's a curl/jq wrapper managed via
dotfiles.

**Root cause of PATH gap:** Claude Code runs hooks in a stripped environment that excluded
`~/.config/dotfiles/zsh/bin`. Fixed by prepending dotfiles bin + common system paths in both
`hooks/borg-link-down.sh` and `hooks/borg-link-up.sh`.

**Additional work shipped:**
- Auto `cairn record session` on every session stop (borg-link-up.sh) with `timeout 5` guard
- `cairn-hits.log` TSV instrumentation in borg-link-down.sh for 4-week keep-or-kill window
- Keep-or-kill review scheduled: remote agent fires 2026-05-26
- 156 API tests added to cairn repo, 86% coverage
- SQLAlchemy CAST bug fixed in cairn search/db
- Cross-container reachability verified (reveal, cairn containers)
- 3 cairn.bats tests updated to use PATH-isolated env for "cairn absent" scenarios

**Follow-ons:**
- `git init` the cairn repo (no version control on API source or migrations)
- Verify ingle container SessionStart banner is clean (no code change needed)
