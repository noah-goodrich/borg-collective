# Source: Agent Skills, "Specification" and "Overview"

**Full citation:** Agent Skills project. "Specification" and "Agent Skills Overview." agentskills.io. No date shown.
**URL:** https://agentskills.io/specification
**URL (overview):** https://agentskills.io/
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation (open-standard specification originated by Anthropic)
**Track:** T4 portability, cross-vendor skill format

## Verified Quote(s)

**Location:** overview page, heading "Open development".

> The Agent Skills format was originally developed by [Anthropic](https://www.anthropic.com/), released as an open standard, and has been adopted by a growing number of agent products.

Note: the quote above is taken from the page's markdown rendering; the rendered page shows "Anthropic" as link text.

**Location:** overview page, heading "What are Agent Skills?".

> Agent Skills are a lightweight, open format for extending AI agent capabilities with specialized knowledge and workflows.

**Location:** specification, heading "`allowed-tools` field".

> Experimental. Support for this field may vary between agent implementations

**Location:** specification, heading "Progressive disclosure", item 1.

> The `name` and `description` fields are loaded at startup for all skills

**Location:** specification, heading "`name` field", constraint bullet.

> Must match the parent directory name

## Key finding

SKILL.md is an open standard whose portable core is only `name`, `description` and a Markdown body; `allowed-tools` is explicitly experimental and implementation-dependent, so tool permissions are the least portable part of a skill. Cortex documents its own `tools:` list of case-sensitive runtime IDs instead, so a skill's tool restriction does not carry across CLIs.

**Access status:** live
