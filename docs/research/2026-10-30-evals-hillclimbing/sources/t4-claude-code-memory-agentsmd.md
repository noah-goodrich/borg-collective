# Source: Anthropic, "How Claude remembers your project" (Claude Code memory docs)

**Full citation:** Anthropic. "How Claude remembers your project." Claude Code Docs. No date shown; page references Claude Code versions up to v2.1.281.
**URL:** https://code.claude.com/docs/en/memory
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, AGENTS.md handling and context injection

## Verified Quote(s)

**Location:** heading "AGENTS.md", first paragraph.

> Claude Code can read [`AGENTS.md`](https://code.claude.com/docs/en/glossary#agents-md) as your project instructions, so a repository already set up for other coding agents works without adding a `CLAUDE.md`, an import, or a setting.

Note: quote taken from the page's markdown rendering; the rendered page shows `AGENTS.md` as link text.

**Location:** heading "When Claude Code reads AGENTS.md", first sentence.

> By default, Claude reads `AGENTS.md` only when you have no `CLAUDE.md` in your working directory or above it.

**Location:** heading "AGENTS.md", version note.

> Reading `AGENTS.md` directly requires Claude Code v2.1.277 or later.

## Key finding

Claude Code now reads AGENTS.md natively, but only when no CLAUDE.md exists on the path (default setting), and only from v2.1.277. An eval fixture's instruction file therefore loads differently by vendor, version and the presence of a CLAUDE.md, so the case must pin which instruction files exist and the harness must record which ones each CLI actually loaded.

**Access status:** live
