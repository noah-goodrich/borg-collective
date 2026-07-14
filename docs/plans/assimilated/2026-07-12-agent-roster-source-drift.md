# Directive: Reconcile the tiered agent roster — source-of-truth drift

*Filed: 2026-07-12 · Status: OPEN · Gated by: nothing*
*Found by: a troth session, while cleaning a stray `feat/tiered-agent-roster` branch out of troth's ref namespace.*

## Why

The intended flow is **borg-collective (source) → claude-plugins (distro, read-only copy)**. For the
agent roster that flow is inverted: five agent definitions live **only in the claude-plugins distro** and
have **no copy in the borg-collective source**.

Confirmed 2026-07-12:

| agent file          | claude-plugins (distro) | borg-collective (source) |
|---------------------|-------------------------|--------------------------|
| `borg-grunt.md`     | present                 | **MISSING**              |
| `borg-scout.md`     | present                 | **MISSING**              |
| `ROUTING.md`        | present                 | **MISSING**              |
| `borg-researcher.md`| present                 | **MISSING**              |
| `borg-reviewer.md`  | present                 | **MISSING**              |
| `borg-nanoprobe.md` | present                 | present (only one)       |

- Distro path: `claude-plugins/borg-collective/agents/`
- Source path: `borg-collective/agents/` (has only `borg-nanoprobe.md`)
- Origin: the roster was authored **directly in the distro** — claude-plugins commit
  `236ea49 feat(agents): tiered roster (grunt/scout + effort pins) + per-type cost attribution (#22)`.
  The agent `.md` files first appear there, not in this source repo.

**Severity is consistency, not imminent loss.** `scripts/sync-plugin.sh` is **skills-only and additive**
(`cp` per-skill for skills already present in the distro; no `--delete`, no `rm`, never touches `agents/`),
so it will NOT delete these agents. The exposure is that the source repo is no longer canonical for
agents, so any future "rebuild/restore from source" or source-side agent edit would silently drop or
diverge from the live roster.

## What to do

Pick ONE model and make source + distro agree, then document it:

1. **If borg-collective is meant to own agents (matches the stated model):**
   - Back-port the 5 files distro → source: copy `claude-plugins/borg-collective/agents/{borg-grunt,
     borg-scout,ROUTING,borg-researcher,borg-reviewer}.md` into `borg-collective/agents/`.
   - Extend the sync tooling to cover `agents/` (today `sync-plugin.sh` handles only `skills/*/SKILL.md`).
     Mirror its additive, existing-targets-only style; do NOT add `--delete` unless you intend a true
     mirror.
   - Add a check to `scripts/check-plugin-version.sh` (or a new drift check) asserting the two `agents/`
     dirs match.

2. **If the distro is intentionally the home for agents:** document that in `sync-plugin.sh`'s header note
   (it already carves out hooks/lib as distro-curated) and delete the lone stale
   `borg-collective/agents/borg-nanoprobe.md` from source so the half-populated dir stops implying source
   ownership.

Recommend option 1 — it restores the stated source→distro invariant.

## Not doing here

This was filed from a troth session; no borg-collective files were changed beyond adding this directive.
