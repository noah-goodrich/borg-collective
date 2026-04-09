---
name: borg-link
description: >
  Project intelligence — the neural link to the collective. No args = overview of all projects
  with directives and recent ships. With a project name = deep dive with registry, debrief,
  directives, plan status, and cairn knowledge. Use when the user asks for status, overview,
  briefing, "what's going on", or project details.
user-invocable: true
---

# Borg Link — Neural Link to the Collective

Run `borg link` or `borg link <project>` with the Bash tool. Present the output as-is.

## Modes

- **No argument:** `borg link` — collective overview (all projects, directives, recent ships)
- **With project:** `borg link <project>` — deep dive (registry, debrief, plan, directives, cairn)
- **LLM briefing:** `borg link --brief` — adds LLM narrative to the overview
- **Refresh:** `borg link --refresh` — regenerates project summaries from transcripts
- **Archived:** `borg link --all` — includes archived projects in overview

## When to Use

- User asks "what's going on?" or "show me everything" → `borg link`
- User asks about a specific project → `borg link <project>`
- User asks for a briefing or morning summary → `borg link --brief`
- User says summaries look stale → `borg link --refresh`
