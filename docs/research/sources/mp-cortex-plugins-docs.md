# Source: Snowflake docs, Cortex Code CLI plugins

**Full citation:** Snowflake Inc. "Cortex Code CLI plugins." Snowflake Documentation. https://docs.snowflake.com/user-guide/cortex-code/cortex-code-plugins. Living page, observed 2026-10-13.
**URL:** https://docs.snowflake.com/user-guide/cortex-code/cortex-code-plugins
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Cortex Code CLI plugin packaging and Claude Code plugin compatibility

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Vendor documentation for its own plugin system. |
| 2 | Evidence Quality | 8/10 | Directory layouts, discovery order, and install sources are explicit, though behavior with Claude-only manifest keys is untested. |
| 3 | Currency | 9/10 | Current for the 1.1.x line; registry and marketplace flows are recent additions per the changelog. |
| 4 | Intent | 8/10 | Instructional. |
| 5 | Bias & Objectivity | 7/10 | Vendor page; does not state limits of the `.claude-plugin` fallback. |
| 6 | Logic & Coherence | 9/10 | Clear layout, discovery order, and command tables. |
| 7 | Corroboration | 8/10 | Changelog entries (registry-backed install, plugin reload) corroborate; no independent third-party test found. |
| 8 | Intellectual Honesty | 7/10 | Silent on what Claude plugin features are not supported. |
| 9 | Specificity | 9/10 | Exact paths and command forms. |
| 10 | Relevance | 9/10 | Matt's repo ships as a Claude/Codex/Copilot plugin; this shows what Cortex would accept. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A Cortex plugin accepts a manifest at `.cortex-plugin/plugin.json` or `.claude-plugin/plugin.json`, with `.cortex-plugin` winning if both exist.
- Plugins are discovered from, among others, the managed registry under `~/.snowflake/cortex/plugins/` and project directories `.cortex/plugins/` and `.claude/plugins/`.
- `cortex plugin install` accepts a marketplace name, GitHub shorthand (`owner/repo`, `github:owner/repo@branch`), or a Git URL, so a GitHub-hosted plugin repo is installable without a marketplace listing.
- A plugin bundles skills, subagents, slash commands, hooks, and MCP servers (per the overview page), mirroring the Claude Code plugin shape.

## Verified Quote(s)

**Location reference:** Section on the plugin manifest (paragraph beginning "CoCo accepts manifests"), the discovery-order list (item 5 "Project plugins"), and the install sources table (row "GitHub shorthand"). Quotes taken from the page's markdown rendering at the card URL (append .md).

> CoCo accepts manifests at either `.cortex-plugin/plugin.json` or `.claude-plugin/plugin.json`. If both are present, `.cortex-plugin` wins.

> **Project plugins.** `.cortex/plugins/` and `.claude/plugins/` in the current working directory.

> `cortex plugin install` accepts three kinds of sources:

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Shows Cortex deliberately reads the Claude plugin manifest path, the key fact for whether a Claude-format plugin repo could be installed there.

**Redundancy check:** Adds plugin-packaging detail the extensibility page lacks; not dominated.

**Perspective category:** Institutional
