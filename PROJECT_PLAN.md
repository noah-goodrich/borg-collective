# Project Plan: Cairn Triage
*Established: 2026-04-02*

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

- [ ] Diagnose why `cairn` is not in PATH (repo exists at ~/dev/cairn, postgres is running)
- [ ] Document: is cairn a pip install? A built binary? What's the install path?
- [ ] Either fix cairn installation so `cairn` CLI works, or document decision to drop it
- [ ] If fixed: verify `cairn search`, `cairn record`, and `cairn health` work end-to-end
- [ ] If dropped: remove cairn references from borg hooks/skills, simplify to debriefs-only

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
