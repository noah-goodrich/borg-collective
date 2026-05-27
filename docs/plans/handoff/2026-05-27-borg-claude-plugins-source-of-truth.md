# Handoff — borg-collective ↔ claude-plugins source-of-truth for skill files

**Created:** 2026-05-27
**Resolved:** 2026-05-27
**For:** borg + Claude Code CLI continuation

## Decision

**`~/dev/borg-collective/` is the source of truth.** `claude-plugins` distributes the
publishable subset — it never originates skill edits.

This was established in the original Dispatch session (`f9ef8d07`, 2026-05-24) that created
the plugin. The session instruction was explicitly "Extract the **publishable layer** of
`~/dev/borg-collective/`" — borg-collective was named as the source repo, and the things to
exclude (CLI machinery, registry, research docs, private paths) defined the privacy boundary.

## Model

```
borg-collective/skills/          ← edit here (source of truth, private)
        │
        │  promote: manual copy when skill is ready to distribute
        ▼
claude-plugins/borg-collective/skills/    ← publishable subset only
        │
        │  build-plugins.sh
        ▼
dist/borg-collective.plugin      ← distributed via marketplace
```

## Privacy boundary

The following never cross to claude-plugins:
- CLI machinery (`borg.zsh`, `drone.zsh`, hooks that depend on `borg`/`drone` at runtime)
- Research docs, checkpoints, directives (personal project state)
- Skills with private paths, JIRA configs, or work-machine-specific behavior
- Anything flagged in `PRIVACY-AUDIT-2026-05-23.md` in claude-plugins

## Follow-on work

- The `2026-05-27-borg-cairn-coordination.md` directive in `claude-plugins/docs/plans/directives/`
  had the edit direction backwards ("edit in claude-plugins, incubate in borg-collective"). It has
  been corrected in the same batch as this doc.
- `borg setup` copies skills from `borg-collective/skills/` to `~/.claude/skills/` — this is
  already correct. The installed copies at `~/.claude/skills/` are what Claude Code loads at
  runtime; the claude-plugins copy is only read when someone installs via the marketplace.
