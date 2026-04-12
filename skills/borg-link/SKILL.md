---
name: borg-link
description: >
  Project intelligence — the neural link to the collective. No args = overview of all projects
  with directives and recent ships. With a project name = deep dive with registry, debrief,
  plan, directives, assimilated history, and cairn knowledge. Works on the host and inside a
  drone container by reading the bind-mounted files directly. Use when the user asks for
  status, overview, briefing, "what's going on", or project details.
user-invocable: true
---

# Borg Link — Neural Link to the Collective

Read the borg data files directly. Do **not** shell out to `borg link` — it may not be in
PATH (you may be inside a drone container where only the data is mounted).

## The data contract

For every project `P` in the registry:

| Source                   | Path                                                   |
| ------------------------ | ------------------------------------------------------ |
| Registry                 | `~/.config/borg/registry.json` (key = `P`)             |
| Debrief                  | `~/.config/borg/debriefs/P.md`                         |
| Project plan             | `<P.workspace>/PROJECT_PLAN.md`                        |
| Directives (backlog)     | `<P.workspace>/docs/plans/directives/*.md`             |
| Assimilated (shipped)    | `<P.workspace>/docs/plans/assimilated/*.md`            |
| Cairn knowledge          | `cairn search P` (skip silently if `cairn` not in PATH)|

### Resolving `<P.workspace>`

The registry stores *host* paths (e.g. `/Users/noah/dev/cairn`), which do **not** resolve
inside a drone container where the same workspace is bind-mounted to a different path
(typically `/workspace`). Use this rule instead:

1. Walk up from `$PWD` looking for a `.borg-project` marker file. If found, read its single
   line — that's the *current project name* — and the directory containing the marker is
   the *current workspace*. This works both on the host and inside a drone.
2. For the **current project**, always use the resolved workspace from step 1 — never the
   registry's `path` field, which may be a host path.
3. For **other projects**, use the registry's `path` field. On the host it resolves; inside
   a drone it usually doesn't, and that's fine — skip workspace-dependent reads (directives,
   assimilated, PROJECT_PLAN.md) and show only registry + debrief for those projects.
4. If no `.borg-project` marker is found (e.g. orchestrator session at `~`), there is no
   current project — fall back to registry paths for everyone.

Registry and debriefs are always reachable because `~/.config/borg/` is bind-mounted into
every drone. Cairn is host-only for now. Degrade silently — do not print "file not found"
errors for workspace files that a drone can't see.

## Modes

- **No argument → overview** of all projects
- **Project name → deep dive** on one project
- **`--brief` / `--refresh`** → host-only (they need the CLI's LLM pipeline). If asked for
  these inside a container, tell the user to run `borg link --brief` / `borg link --refresh`
  from the host.

## Step 1 — Resolve the current project (marker walk)

```
Bash: dir="$PWD"; while [[ "$dir" != "/" ]]; do
        [[ -f "$dir/.borg-project" ]] && { echo "WORKSPACE=$dir"; echo "PROJECT=$(cat "$dir/.borg-project")"; break; }
        dir=$(dirname "$dir")
      done
```

If this prints a `PROJECT` and `WORKSPACE`, that's your current project and its resolved
workspace root. Remember both — you'll use `WORKSPACE` whenever the current project needs a
workspace path. If the walk produces nothing, there's no current project (orchestrator
session case).

## Step 2 — Read the registry

```
Bash: jq '.projects | to_entries | map({name: .key, path: .value.path,
          status: .value.status, last: .value.last_activity,
          summary: .value.summary})' ~/.config/borg/registry.json
```

## Step 3 — Deep dive on project `P`

First decide the workspace path for `P`:
- If `P == current project`, use `WORKSPACE` from Step 1.
- Otherwise, use the registry's `path` field.
- Before reading any workspace file, check it exists (`test -e`). If it doesn't, skip that
  step silently — do not print an error. This is the normal case for non-current projects
  inside a drone.

Then:

1. Print the header: name, resolved workspace path, status, last active, summary.
2. Read `~/.config/borg/debriefs/P.md` if it exists. Show the first ~20 lines as "Last
   Debrief." (Always reachable — `~/.config/borg/` is mounted in drones.)
3. Read `<workspace>/PROJECT_PLAN.md` if it exists. Extract the Objective line and the count
   of `- [ ]` / `- [x]` checklist items for a Progress line.
4. Glob `<workspace>/docs/plans/directives/*.md`. For each file, the H1 is the title. Print
   as "Directives: N pending" with a bullet list.
5. Glob `<workspace>/docs/plans/assimilated/*.md`, newest first. Take the top 3. The H1 is
   the title; `Shipped:` field has the date. Print as "Recently assimilated."
6. If `cairn` is in PATH, run `cairn search P --project P --max 5`. Otherwise skip silently.

Inside a drone, for a project that isn't the current one, steps 3–5 will usually be skipped
because `<workspace>` (the host path from the registry) isn't reachable. That's expected
behavior, not an error.

## Step 4 — Overview (no argument)

1. Resolve the current project per Step 1 (may be empty).
2. Read the registry per Step 2.
3. Render a table: project, status, last-active, summary. Sort: pinned first, then status
   priority (waiting > active > idle > archived), then last-active DESC.
4. For each project, resolve its workspace path with the same rule (current project →
   `WORKSPACE`, others → registry `path`). If the resolved workspace exists, collect its
   directives and newest assimilated files. Aggregate into two lists with project-name
   prefixes:
   - `Directives: N pending` → `- [project] title`
   - `Recently assimilated` (newest 3 globally) → `- [project] title (YYYY-MM-DD)`
5. Skip per-project cairn lookups in overview mode — too expensive.
6. If a project's workspace isn't reachable (common inside drones for every project except
   the current one), omit its directives and assimilated entries but still show its
   registry row.

## When to use

- User asks "what's going on?" / "show me everything" → overview
- User asks about a specific project → deep dive
- User asks for a briefing or morning summary → overview (or suggest `borg link --brief` on
  the host for the LLM narrative)
- User says summaries look stale → suggest `borg link --refresh` on the host

## Presentation

Plain text, terse. Mirror the CLI's output style (section headers, bullet lists). No tables
unless the output is meant to be scanned across many projects.
