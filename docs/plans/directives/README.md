# `docs/plans/directives/` — Metadata Line Conventions

This directory holds filed-but-not-yet-in-flight work: candidate directives waiting to be
promoted to `PROJECT_PLAN.md` at the project root (via `borg start <slug>`), executed, then
archived to `docs/plans/assimilated/`. Two italic metadata lines, both placed immediately below
the `# Directive: <title>` H1 heading, govern how directives relate to each other and to the
promotion lifecycle. Neither line is required — a directive with no metadata line is a plain
top-level candidate.

## `*Parent plan: <plan-slug>*`

Marks a directive as a **child** of a plan that is (or was) in flight, rather than a standalone
top-level candidate. Written by `borg-plan`'s "Follow-Up Directives During an Active Plan" flow
when a new directive is filed while `PROJECT_PLAN.md` already exists in the project root.

- `<plan-slug>` is the parent plan's eventual archived filename, without the `.md` extension and
  without a leading path (e.g. `2026-04-14-reveal-mvp-supabase-flyio`).
- Consumed by `borg-assimilate` Step 0.75 ("Check for Un-Resolved Child Directives"): before a
  plan ships, the assimilate flow greps `docs/plans/directives/*.md` for `^\*Parent plan:
  <this-plan's-slug>\*` and blocks shipping until every match is either shipped itself or moved
  to `docs/plans/severed/`.
- Also consumed by `borg-assimilate` Step 4c ("Chained Auto-Promotion", see below): a directive
  carrying `*Parent plan:*` is never counted as a top-level candidate for auto-promotion.

```
# Directive: <title>
*Parent plan: 2026-04-14-reveal-mvp-supabase-flyio*
*Filed: <date>*
```

## `*Next: <slug>*`

Marks a directive as the designated successor in a hand-wired chain — e.g. when one large
directive is manually decomposed into several smaller, independently-shippable files at filing
time. Written by whoever files the chain (a plan, a decomposition pass, a developer editing the
file directly).

- `<slug>` is the *next* directive's filename without the `.md` extension and without a leading
  path — the literal stem `cmd_start` resolves against `docs/plans/directives/<slug>.md`, not a
  human-readable short form.
- Consumed by `borg-assimilate` Step 4c: when the plan that just shipped carries a `^\*Next:
  <slug>\*` line and `docs/plans/directives/<slug>.md` exists, that directive is auto-promoted
  immediately (`borg start <slug>`) regardless of how many other top-level candidates exist. A
  pointer to a nonexistent slug is treated as absent — it falls through to the ordinary
  candidate-count branch rather than crashing or blocking.
- Independent directives (not part of any chain) simply omit this line — no `*Next:*` line means
  no chained-promotion signal, and Step 4c falls back to counting top-level candidates.

```
# Directive: <title>
*Filed: <date>*
*Next: 2026-08-11-viz-2-spine-generator*
```

## Why both live here

`*Parent plan:*` has been live in production since `borg-plan`'s "Follow-Up Directives" section
shipped, but was never written down anywhere central — only discoverable by reading the skill
file. `*Next:*` is new as of the chained-auto-promotion mechanism
(`docs/plans/directives/2026-08-12-chained-auto-promotion.md`). Both conventions are read by
`borg-assimilate` (`skills/borg-assimilate/SKILL.md`, Steps 0.75 and 4c) and exercised by
`tests/promote_next.bats` against `lib/promote-next.sh`.
