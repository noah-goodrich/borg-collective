# Source: Snowflake, "Cortex Code CLI plugins"

**Full citation:** Snowflake Inc. "Cortex Code CLI plugins." Snowflake Documentation, User Guide > Cortex Code. Footer "© 2026 Snowflake, Inc."; no last-updated date.
**URL:** https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-plugins
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, plugin packaging

## Verified Quote(s)

**Location:** page intro, definition of a CoCo CLI plugin.

> a self-contained package that bundles skills, subagents, slash commands, hooks, and MCP servers

**Location:** manifest section.

> CoCo accepts manifests at either `.cortex-plugin/plugin.json` or `.claude-plugin/plugin.json`.

**Location:** plugin skills section.

> Plugin skills are tagged with their origin so you can see them in `/skill list`.

**Location:** installation section (followed by the path `~/.snowflake/cortex/plugins/`).

> Plugins installed with `cortex plugin install` are written to:

## Key finding

Cortex Code now documents a plugin format that accepts a `.claude-plugin/plugin.json` manifest, so a Claude Code plugin directory is at least loadable in principle. The page describes origin tagging for skills but no `plugin-name:item` namespace, which matches our measurement that agents register by bare `name:`.

**Relation to measured facts:** Partly updates the GIVEN "Cortex has no plugin namespace": true per this page, but Cortex does now document plugins as a packaging unit. Whether 1.2.24 implements `cortex plugin install` was not checked.

**Access status:** live
