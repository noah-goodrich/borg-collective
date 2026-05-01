# Directive: Directive Orphan Prevention
*Established: 2026-05-01*

## Objective

Close the structural gap that allowed two reveal directives
(`2026-04-25-attempt-persistence-and-detail.md`,
`2026-05-01-user-submission-context-pipeline.md`) to be orphaned when the parent MVP plan
shipped. Add directive ↔ plan back-links, auto-surface active directives at session start,
and nudge directive reconciliation at session end when commits happened.

## Context

In reveal, the MVP `PROJECT_PLAN.md` was correctly assimilated on 2026-05-01 with all 8
acceptance criteria genuinely met. But two directives spawned *during* MVP execution as
follow-ups did not ship with the plan:

- `2026-04-25-attempt-persistence-and-detail.md` — schema tables shipped, worker code that
  populates them was never written. Zero references in `worker/main.py`.
- `2026-05-01-user-submission-context-pipeline.md` — form + schema shipped, but the
  prompt-builder wiring that *is* the directive is missing.

The pattern across the prior 3 sessions: each session executed its narrow handoff doc and
never re-opened `docs/plans/directives/`. The MVP got assimilated cleanly because it really
*was* done. Assimilation didn't check sibling directives, and the directives had no back-link
to the plan they were follow-ups to. Standing work floated free.

This is not a `PROJECT_PLAN.md` visibility problem — it's a directive visibility + linkage
problem.

## Acceptance Criteria

- [ ] **Directives carry a `Parent plan:` italic-metadata line.** Matches existing reveal
      directive convention (italic lines just under the H1, not YAML frontmatter). Format:
      `*Parent plan: <plan-slug>*` where `<plan-slug>` is the assimilated plan's filename
      without the `.md` extension (e.g. `2026-04-14-reveal-mvp-supabase-flyio`). Slug, not
      path, so the link survives the plan moving between `directives/`, `assimilated/`, and
      `severed/`. Absent on independent directives, present on directives spawned during a
      plan's execution.
  - Verify: `2026-04-25-attempt-persistence-and-detail.md` and
    `2026-05-01-user-submission-context-pipeline.md` (already back-linked manually on
    2026-05-01) carry the line; greppable via `grep -l '^\*Parent plan:' docs/plans/`.

- [ ] **`/borg-plan` records `parent_plan` when spawning directives mid-plan.** When the active
      `PROJECT_PLAN.md` exists and the user requests a follow-up directive, the new directive
      file is written with `parent_plan` pointing at it.
  - Verify: with a plan in `docs/plans/directives/PROJECT_PLAN.md`, ask `/borg-plan` to spawn a
    follow-up; confirm new file's frontmatter contains `parent_plan`.

- [ ] **`/borg-assimilate` blocks on un-resolved children.** Before archiving the plan,
      enumerate directives with `parent_plan` matching the plan path. If any are still in
      `docs/plans/directives/` (not yet shipped or severed), refuse to ship and list them.
  - Verify: with a fake child directive present, `/borg-assimilate` exits with a clear
    "un-resolved child directives:" message and does not move the plan.

- [ ] **`borg-link-down` injects active directives at session start.** If
      `<project>/docs/plans/directives/` is non-empty, the hook injects each filename plus its
      `## Objective` line (or first non-frontmatter heading) into session-start context,
      alongside the latest checkpoint.
  - Verify: in reveal with two directives present, session start context includes both
    filenames and objective summaries.

- [ ] **`borg-link-up` directive nudge at session end.** When the session is ending and
      commits were made, the hook surfaces a "Directive reconciliation?" prompt for any
      directive whose scope or key-files section mentions a path touched by those commits.
      Surface only — does not auto-update the directive.
  - Verify: in a project with a directive listing `worker/main.py`, a session that commits
    `worker/main.py` produces a checkpoint nudge naming the directive.

- [ ] **No regression on plan-less projects.** Projects with no `docs/plans/directives/`
      directory continue to work without nudges or errors.
  - Verify: a fresh project with no plans dir has no checkpoint nudges fire.

## Scope Boundaries

- **NOT** auto-checking off acceptance criteria. The model can't reliably judge "done";
  surface, don't decide.
- **NOT** building a directive graph DB. Frontmatter + filenames is enough.
- **NOT** changing the `severed/` workflow — already explicit.
- **NOT** retroactively back-linking the orphaned reveal directives. Do that as a one-time
  manual fix in the reveal session, not as part of this directive.
- **NOT** adding parent_plan to assimilated directives — they're done; back-linking them is
  archaeology.

## Ship Definition

- `skills/borg-plan/SKILL.md` updated: emits `parent_plan` when a plan is active.
- `skills/borg-assimilate/SKILL.md` updated: child-directive check before archive.
- `hooks/borg-link-down.sh` updated: directive injection alongside checkpoint.
- `hooks/borg-link-up.sh` updated: post-commit directive-touch nudge.
- Manual test: in a sandbox project, exercise the full lifecycle (plan → directive → commit →
  link-up nudge → assimilate-blocked → ship directive → assimilate-allowed).
- Borg version bump and release.

## Timeline

Target: 1 focused session. The hook edits are small; the bulk of the work is the
`/borg-assimilate` child-detection logic and updating both skills' `SKILL.md`.

## Risks

1. **`parent_plan` mismatch when plans move.** A plan moves from `directives/` to
   `assimilated/` on ship — children's `parent_plan` paths would break. Resolve by storing
   `parent_plan` as a slug (`mvp-plan`) plus a date, not a filesystem path. Then both
   directives' check and the assimilator's check resolve via glob.

2. **Directive-injection bloat at session start.** A project with many active directives
   could push a lot of text into context. Keep injection to filename + objective line only;
   never inject full directive bodies.

3. **False-positive nudges.** A directive that lists `src/` would match almost any commit.
   Match against the directive's `## Key Files` section specifically (which lists exact paths
   in convention), not freeform body text.

4. **Severance escape hatch must stay easy.** If a child directive becomes irrelevant,
   `git mv directives/foo.md severed/foo.md` plus a one-line "why severed" should be enough
   to unblock assimilation. Don't gate severance on additional ceremony.

## Key Files

```
skills/borg-plan/SKILL.md                ← edit: emit parent_plan when plan is active
skills/borg-assimilate/SKILL.md          ← edit: child-directive check before archive
hooks/borg-link-down.sh                  ← edit: inject active directives at session start
hooks/borg-link-up.sh                    ← edit: post-commit directive-touch nudge
docs/plans/directives/<existing>         ← reference: example directive frontmatter shape
```
