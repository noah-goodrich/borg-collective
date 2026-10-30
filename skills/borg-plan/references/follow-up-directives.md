## Follow-Up Directives During an Active Plan

When the developer requests a new directive *while a `PROJECT_PLAN.md` already exists* in the
repository root (i.e. we are mid-plan, not starting from scratch), write the directive file to
`docs/plans/directives/<date>-<slug>.md` with a `*Parent plan: <plan-slug>*` italic metadata line
immediately below the H1 heading.

`<plan-slug>` is the filename of `PROJECT_PLAN.md`'s eventual archived copy — the basename
*without* the `.md` extension and without a leading path. **Read it from the plan's `- Plan-slug:`
annotation; never compute it.** The helper Step 0.75 uses is the one to use here:

```
source lib/promote-next.sh && _borg_plan_declared_slug PROJECT_PLAN.md
```

If the annotation is missing, the plan predates it — add it and confirm the value with the developer
before filing the directive. A computed slug writes a `*Parent plan:*` line no gate will ever match,
which is exactly how nine directives came to be invisible to the check meant to find them. Example:

```
# Directive: <title>
*Parent plan: 2026-04-14-reveal-mvp-supabase-flyio*
*Filed: <date>*
```

The slug must survive the plan moving from `directives/` → `assimilated/`. Store only the slug
(filename without extension), not a filesystem path. If there is no active `PROJECT_PLAN.md`,
omit the `*Parent plan:*` line — independent directives carry no lineage.
