---
name: borg-search
description: >
  Search the cairn knowledge graph for lessons, decisions, or patterns across projects.
  Use when the user asks to search knowledge, find past decisions, or look something up.
---

Run `borg search "<query>"` with the Bash tool, where <query> is what the user wants to find.
If no query given, ask for one before running.

Present results directly. If no results: say so and suggest a broader search term.
If cairn is unavailable, say so — don't silently return empty results.
