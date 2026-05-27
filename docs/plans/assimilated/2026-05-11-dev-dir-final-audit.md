# Directive: Final ~/dev Audit — Unaudited Non-Project Directories
Shipped: 2026-05-27

*Filed: 2026-05-11*
*Spawned from the Track F cleanup arc — the major cleanup is complete
(~9.78G reclaimed, 33→13 entries in ~/dev), but four directories remain
that aren't borg-managed projects and haven't been audited.*

## Objective

Audit four remaining `~/dev/` directories that survived the Track F
cleanup but aren't tracked as projects in `~/.config/borg/registry.json`.
Decide KEEP / ARCHIVE / DELETE for each, then act.

## Context

After cleanup arc on 2026-05-10/11:
- ~/dev/ went from 33 entries → 13
- 9.78G reclaimed
- snowflake-projects, snowfort-old, snowfort-scaffold-bak, wayfinderai-waypoint,
  wallpaper-kit, medium-mcp-server, SnowDDL, snowflake-examples all
  archived or trashed
- Stray top-level files moved to `~/Documents/old-repos/dev-strays/`

Four directories remain that are NOT in the borg registry and need a
similar pass:

1. **`~/dev/claude-plugins/`** (660K, last commit 2026-04-18)
   - Git repo, remote `git@github.com:noah-goodrich/claude-plugins.git`
   - Likely Noah's plugin development scratch space
   - Untracked: whether it's still active or superseded by stillpoint-labs
     repos / borg-collective itself
2. **`~/dev/cortex-handoffs/`** (104K, last activity 2026-04-14)
   - Not a git repo
   - 2 files only
   - Likely handover/notes scratch space for Cortex Code CLI work
3. **`~/dev/reveal-design-system/`** (6.4M, last activity 2026-05-01)
   - Not a git repo (per pre-audit inventory)
   - 65 files
   - Should this content live inside `reveal-site/` or `reveal/`?
   - Likely a design-token / component-library staging area
4. **`~/dev/snowflake_assets/`** (102M, last activity 2026-03-02)
   - Not a git repo
   - 66 files, but 102M of bulk
   - Snowflake artifacts (logos? sample data? quickstart clones?)
   - Likely the most reclaim-worthy candidate after the cleanup arc

## Acceptance Criteria

- [ ] **`claude-plugins`**: git status checked; if clean and remote-backed,
      delete local clone (re-cloneable). If has unique local work, push
      then archive on GitHub.
- [ ] **`cortex-handoffs`**: 2 files inspected; if stale handover notes,
      move to `~/Documents/old-repos/` and trash. If still load-bearing,
      keep with a TODO to move into a real home.
- [ ] **`reveal-design-system`**: contents inspected; either move into
      `reveal-site/src/components/` (if it's a component library) or
      `reveal-site/docs/design-tokens/` (if it's design tokens), or
      tarball + trash if pre-pivot dead code.
- [ ] **`snowflake_assets`**: 102M inspected; subdir sizes broken down;
      delete obvious clones (sample data, downloads), tarball anything
      that looks unique, trash the rest.
- [ ] All decisions executed; ~/dev/ down to the 9 active project
      directories registered in `~/.config/borg/registry.json` plus
      whatever survives the audit.

## Scope Boundaries

- **NOT** auditing the 9 registered projects. They're all active.
- **NOT** touching `~/.claude/`, `~/.config/dotfiles/`, or other
  outside-of-`~/dev/` locations.
- **NOT** re-archiving anything already in `~/Documents/old-repos/`.

## Key Files

```
~/dev/claude-plugins/             ← audit
~/dev/cortex-handoffs/            ← audit
~/dev/reveal-design-system/       ← audit
~/dev/snowflake_assets/           ← audit
~/.config/borg/registry.json      ← reference (project allowlist)
~/Documents/old-repos/            ← archive destination
```

## Risks

- **reveal-design-system content may belong in reveal-site/reveal.** Don't
  delete blindly — if there are design tokens or components in active
  use, they need to move into the right project, not be trashed.
- **snowflake_assets bulk is probably reclaimable** but should be
  inspected (102M is significant; could be Snowflake quickstart clones
  like the sfquickstarts dir already trashed).
- **claude-plugins might be borg-collective-adjacent.** If it overlaps
  with what borg-collective already ships, the right move may be merging
  the unique work into borg-collective, not archiving.

## Estimated Effort

One focused 30-45 min session. All inspection is read-only; final actions
are mechanical (`mv` to trash, `tar`, `gh repo archive`, or content
moves into the right project).

## Reference

Cleanup arc that preceded this directive: see session checkpoint
`.borg/checkpoints/2026-05-11-*.md` for the full context on what was
archived and what was preserved.
